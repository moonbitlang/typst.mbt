#!/usr/bin/env python3
"""Generate MoonBit element descriptors from gen/manifest.json.

Upstream's `#[elem]` proc-macro generates field tables, constructors, set
rules and field access glue. This script generates the equivalent data tables
(`library/elems_gen.mbt`). Custom behavior lives in handwritten code:

* `<elem>_<field>_default() -> Value`  for `#[default(..)]` expressions that
  cannot be translated mechanically,
* `<elem>_<field>_parse(Engine, Args, ParseLocals) -> Value? raise SourceError` for
  `#[parse(..)]` fields,
* capability impls, wired into the element's hooks when defined:
  `<elem>_synthesize(Engine, Content, StyleChain) -> Content raise SourceError`
  (`Synthesize`), `<elem>_show_set(Content, StyleChain) -> Styles`
  (`ShowSet`) and `<elem>_local_name_key() -> String` (`LocalName::KEY`).

Any such hook that is not defined in a handwritten `library/*.mbt` file gets a
stub in `library/elems_todo_gen.mbt`, so the package always compiles; the stub
list doubles as a TODO list.

Field types are mapped through TYPEMAP (scripts/typemap.py). Types without a MoonBit port yet map to
`Value` (no validation) and are listed in the generated file header.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from typemap import mbt_type  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "library")

# MoonBit integer types (all cast from/to `Value::Int`).
INT_TYPES = ("Int64", "U8", "U16", "U32", "U64", "USize", "I8", "I16", "I32")

# Rust `Default::default()` of a mapped type, as a Value expression.
TYPE_DEFAULTS = {
    "Bool": "Bool(false)",
    "Int64": "Int(0L)",
    "Double": "Float(0.0)",
    "Content": "Content(Content::empty())",
    "Array[Content]": "Array(Arr::new())",
    "Length": "Length(Length::zero())",
    "Angle": "Angle(Angle::zero())",
    "Ratio": "Ratio(Ratio::zero())",
    "Fr": "Fraction(Fr::zero())",
    "Rel[Length]": "Relative(Rel::zero())",
    "String": 'Str("")',
    "Stroke": "Dyn(Stroke(Stroke::default()))",
    "FillRule": 'Str("non-zero")',
    "CloseMode": 'Str("smooth")',
}


def snake(ident):
    s = re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", ident)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", s)
    return s.lower()


def elem_var(ident, file=""):
    s = snake(ident)
    s = s if s.endswith("_elem") else s + "_elem"
    # Disambiguate elements with the same Rust name in different modules.
    if ident in ("UnderlineElem", "OverlineElem", "AttachElem"):
        if "/math/" in file:
            s = "math_" + s
        elif "typst-pdf" in file:
            s = "pdf_" + s
    return s


def type_default(mty):
    """Rust `Default::default()` of a mapped type as a Value expression."""
    if mty in TYPE_DEFAULTS:
        return TYPE_DEFAULTS[mty]
    if mty in INT_TYPES:
        return "Int(0L)"
    if mty.endswith("?"):
        return "None"
    if mty.startswith("Smart["):
        return "Auto"
    # `Sides::splat(None)` / `Corners::splat(None)` cast to an empty dict.
    if re.fullmatch(r"(Sides|Corners)\[.*\?\]", mty):
        return "Dict(Dict::new())"
    m = re.fullmatch(r"Axes\[(.*)\]", mty)
    if m and type_default(m.group(1)):
        d = type_default(m.group(1))
        return f"Array(Arr::from_array([{d}, {d}]))"
    if mty.startswith("Array["):
        return "Array(Arr::new())"
    return None


def float_lit(x):
    return x if "." in x or "e" in x else x + ".0"


def translate_default(rust_ty, mty, expr):
    """Translate a `#[default(expr)]` into a Value expression, or None."""
    e = expr.strip()
    if e == "":
        return type_default(mty) if mty != "Value" else None
    if e in ("true", "false") and mty == "Bool":
        return f"Bool({e})"
    if re.fullmatch(r"-?\d+", e):
        if (mty in ("Value",) + INT_TYPES or mty.startswith("NonZero")) and rust_ty in (
            "i64", "usize", "u64", "isize", "u8", "u16", "u32", "i8", "i16", "i32",
                "NonZeroUsize", "NonZeroU32", "NonZeroU64", "NonZeroI64"):
            return f"Int({e}L)"
    # `Smart::Custom(x)` and `Some(x)` have the same value as `x`.
    m = re.fullmatch(r"(?:Smart::Custom|Some)\((.*)\)", e)
    if m:
        inner = re.fullmatch(r"(?:Smart|Option)<(.*)>", rust_ty)
        if inner and (mty.startswith("Smart[") or mty.endswith("?")):
            inner_mty = mty[len("Smart["):-1] if mty.startswith("Smart[") else mty[:-1]
            return translate_default(inner.group(1), inner_mty, m.group(1))
    if e in ("NonZeroUsize::ONE", "NonZeroU32::ONE"):
        return "Int(1L)"
    m = re.fullmatch(r"NonZeroUsize::new\((\d+)\)\.unwrap\(\)", e)
    if m:
        return f"Int({m.group(1)}L)"
    if e == "Smart::Auto":
        return "Auto"
    if e == "None":
        return "None"
    m = re.fullmatch(r"Em::new\(([-\d.e]+)\)\.into\(\)", e)
    if m:
        em = f"Length::from_em(Em::new({float_lit(m.group(1))}))"
        if mty == "Length":
            return f"Length({em})"
        if mty == "Rel[Length]":
            return f"Relative(Rel::from_abs({em}))"
        if mty == "Spacing":
            return f"Length({em})"
    m = re.fullmatch(r"Abs::pt\(([-\d.e]+)\)\.into\(\)", e)
    if m:
        ab = f"Length::from_abs(Abs::pt({float_lit(m.group(1))}))"
        if mty == "Length":
            return f"Length({ab})"
        if mty == "Rel[Length]":
            return f"Relative(Rel::from_abs({ab}))"
    m = re.fullmatch(r"Ratio::new\(([-\d.e]+)\)\.into\(\)", e)
    if m and mty == "Rel[Length]":
        return f"Relative(Rel::from_ratio(Ratio::new({float_lit(m.group(1))})))"
    if e == "Rel::one()" and mty == "Rel[Length]":
        return "Relative(Rel::one())"
    if e == "Angle::zero()" and mty == "Angle":
        return "Angle(Angle::zero())"
    if ALIGN_TYPES.fullmatch(mty):
        align = translate_alignment(e)
        if align:
            return f"Dyn(Alignment({align}))"
    m = re.fullmatch(r"Dir::(LTR|RTL|TTB|BTT)", e)
    if m and mty == "Dir":
        return f"Dyn(Dir(Dir::{m.group(1)}))"
    return None


ALIGN_TYPES = re.compile(r"(Outer)?[HV]?Alignment|SpecificAlignment\[.*\]")


def translate_alignment(e):
    """Translate an alignment expression into an `Alignment` expression."""
    m = re.fullmatch(r"Alignment::([A-Z]+)", e)
    if m:
        return f"alignment_{m.group(1).lower()}"
    m = re.fullmatch(r"(?:Outer)?HAlignment::(\w+)", e)
    if m:
        return f"Alignment::H(HAlignment::{m.group(1)})"
    m = re.fullmatch(r"(?:Outer)?VAlignment::(\w+)", e)
    if m:
        return f"Alignment::V(VAlignment::{m.group(1)})"
    m = (re.fullmatch(r"(?:Outer)?HAlignment::(\w+) \+ (?:Outer)?VAlignment::(\w+)", e)
         or re.fullmatch(r"SpecificAlignment::Both\((?:Outer)?HAlignment::(\w+), (?:Outer)?VAlignment::(\w+)\)", e))
    if m:
        return f"Alignment::Both(HAlignment::{m.group(1)}, VAlignment::{m.group(2)})"
    return None


# MoonBit types with a `Fold` impl, collected from the handwritten library
# files: plain types, generic types whose impl requires `T : Fold`, and
# generic types that fold for any `T`.
def fold_impls():
    plain, needs_inner, any_inner = set(), set(), set()
    for fn in os.listdir(LIB):
        if not fn.endswith(".mbt") or fn.endswith("_gen.mbt"):
            continue
        src = open(os.path.join(LIB, fn)).read()
        for m in re.finditer(r"^pub impl(\[([^\]]*)\])? Fold for (\w+)", src, re.M):
            bounds, name = m.group(2), m.group(3)
            if bounds is None:
                plain.add(name)
            elif "Fold" in bounds:
                needs_inner.add(name)
            else:
                any_inner.add(name)
    # `impl[T : Fold] Fold for T?` is the `Option` impl.
    needs_inner.discard("T")
    return plain, needs_inner, any_inner


FOLD_PLAIN, FOLD_NEEDS_INNER, FOLD_ANY_INNER = fold_impls()


def foldable(mty):
    """Whether the MoonBit type implements `Fold`."""
    if mty in FOLD_PLAIN or mty == "Rel[Length]" and "Rel" in FOLD_PLAIN:
        return True
    if mty.endswith("?"):
        return foldable(mty[:-1])
    m = re.fullmatch(r"(\w+)\[(.*)\]", mty)
    if m:
        head, inner = m.group(1), m.group(2)
        if head in FOLD_ANY_INNER:
            return True
        if head in FOLD_NEEDS_INNER:
            if head in ("Sides", "Corners", "Margin") and inner.endswith("?"):
                inner = inner[:-1]
            return foldable(inner)
    return False


def defined_functions():
    """Names of top-level functions defined in handwritten library files."""
    names = set()
    for fn in os.listdir(LIB):
        if not fn.endswith(".mbt") or fn.endswith("_gen.mbt"):
            continue
        with open(os.path.join(LIB, fn)) as f:
            for m in re.finditer(r"^(?:pub )?fn ([a-z_][a-z0-9_]*)\(", f.read(), re.M):
                names.add(m.group(1))
    return names


def mbt_str(s):
    return json.dumps(s, ensure_ascii=False).replace("\\{", "\\\\{")


SKIP = {"SequenceElem", "StyledElem"}


def main():
    manifest = json.load(open(os.path.join(ROOT, "gen", "manifest.json")))
    defined = defined_functions()
    out = []
    todo = []
    unmapped = {}
    out.append("// Generated by scripts/elemgen.py from gen/manifest.json. Do not edit.\n")
    for e in manifest["elems"]:
        if e["ident"] in SKIP:
            continue
        var = elem_var(e["ident"], e["file"])
        fields = []
        for i, f in enumerate(e["fields"]):
            mty = mbt_type(f["ty"])
            if mty == "Value" and f["ty"] != "Value":
                unmapped[f["ty"]] = unmapped.get(f["ty"], 0) + 1
            if f["required"] or f["variadic"]:
                kind = "Required"
            elif f["synthesized"]:
                kind = "Synthesized"
            elif f["external"]:
                kind = "External"
            elif f["ghost"]:
                kind = "Ghost"
            else:
                kind = "Settable"
            # Variadic fields are typed by their item type.
            ty = mty
            if f["variadic"]:
                inner = re.fullmatch(r"Vec<(.*)>", f["ty"])
                ty = mbt_type(inner.group(1)) if inner else "Value"
            args = [
                f"(Ty::new() : Ty[{ty}])",
                f"id={i}",
                f"name={mbt_str(f['name'])}",
                f"kind={kind}",
            ]
            if f["positional"]:
                args.append("positional=true")
            if f["required"]:
                args.append("required=true")
            if f["variadic"]:
                args.append("variadic=true")
            if f["internal"]:
                args.append("internal=true")
            if kind in ("Settable", "Ghost", "External"):
                expr = translate_default(f["ty"], mty, f["default"] if f["default"] is not None else "")
                if expr is None:
                    fname = f"{var}_{snake(f['ident'])}_default"
                    if fname not in defined:
                        src = f["default"] if f["default"] is not None else f"Default::default() of {f['ty']}"
                        todo.append(
                            f"///|\n/// TODO: port `{src}` ({e['ident']}.{f['ident']}).\nfn {fname}() -> Value {{\n  None\n}}\n"
                        )
                    args.append(f"default={fname}")
                else:
                    args.append(f"default=() => {expr}")
            if f["fold"]:
                fname = f"{var}_{snake(f['ident'])}_fold"
                if fname not in defined and foldable(mty):
                    fname = f"fold_of((Ty::new() : Ty[{mty}]))"
                elif fname not in defined:
                    todo.append(
                        f"///|\n/// TODO: fold for `{f['ty']}` ({e['ident']}.{f['ident']}).\nfn {fname}(inner : Value, _outer : Value) -> Value {{\n  inner\n}}\n"
                    )
                args.append(f"fold={fname}")
            if f["parse"] is not None:
                fname = f"{var}_{snake(f['ident'])}_parse"
                # Until the custom parsing is ported, fall back to the default
                # parsing of the field.
                if fname in defined:
                    args.append(f"parse={fname}")
                else:
                    todo.append(f"// TODO: port `#[parse]` of {e['ident']}.{f['ident']} as `{fname}`.\n")
            fname = f"{var}_{snake(f['ident'])}_output"
            if fname in defined:
                args.append(f"output={fname}")
            fields.append(f"    field_of({', '.join(args)}),")
        caps = ", ".join(mbt_str(c) for c in e["capabilities"])
        kws = ", ".join(mbt_str(k) for k in e["keywords"])
        init_hook = f"{var}_init"
        init_call = f"      {init_hook}(e)\n" if init_hook in defined else ""
        if f"{var}_synthesize" in defined:
            init_call += f"      e.hooks().synthesize = Some({var}_synthesize)\n"
        if f"{var}_show_set" in defined:
            init_call += f"      e.hooks().show_set = Some({var}_show_set)\n"
        if f"{var}_local_name_key" in defined:
            init_call += f"      e.hooks().local_name = Some((lang, region) => localized_str(lang, region, {var}_local_name_key()))\n"
        out.append(
            f"///|\nlet {var}_cell : Ref[Element?] = Ref::new(None)\n\n"
            f"///|\n/// {e['doc'] or e['title']} (upstream `{e['ident']}`, {e['file']})\n"
            f"pub fn {var}() -> Element {{\n"
            f"  match {var}_cell.val {{\n"
            f"    Some(e) => e\n"
            f"    None => {{\n"
            f"      let e = Element::new(\n"
            f"        name={mbt_str(e['name'])},\n        title={mbt_str(e['title'])},\n"
            f"        docs={mbt_str(e['doc'])},\n        keywords=[{kws}],\n        capabilities=[{caps}],\n"
            f"        fields=[\n" + "\n".join("    " + x for x in fields) + "\n        ],\n      )\n"
            f"      {var}_cell.val = Some(e)\n{init_call}      e\n    }}\n  }}\n}}\n"
        )
        # Field id constants.
        for i, f in enumerate(e["fields"]):
            out.append(f"///|\npub let {var}_{snake(f['ident'])} : Int = {i}\n")
    header = "// Unmapped field types (stored untyped as `Value`):\n" + "".join(
        f"//   {n:3} {t}\n" for t, n in sorted(unmapped.items(), key=lambda x: -x[1])
    )
    with open(os.path.join(LIB, "elems_gen.mbt"), "w") as f:
        f.write(out[0] + header + "\n" + "\n".join(out[1:]))
    with open(os.path.join(LIB, "elems_todo_gen.mbt"), "w") as f:
        f.write("// Generated stubs for element hooks that are not ported yet.\n\n" + "\n".join(todo))
    print(f"{len(manifest['elems']) - len(SKIP)} elements, {len(todo)} TODO hooks, {len(unmapped)} unmapped types", file=sys.stderr)


if __name__ == "__main__":
    main()
