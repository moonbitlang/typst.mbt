#!/usr/bin/env python3
"""Generate MoonBit element descriptors from gen/manifest.json.

Upstream's `#[elem]` proc-macro generates field tables, constructors, set
rules and field access glue. This script generates the equivalent data tables
(`library/elems_gen.mbt`). Custom behavior lives in handwritten code:

* `<elem>_<field>_default() -> Value`  for `#[default(..)]` expressions that
  cannot be translated mechanically,
* `<elem>_<field>_parse(Engine, Args) -> Value? raise SourceError` for
  `#[parse(..)]` fields.

Any such hook that is not defined in a handwritten `library/*.mbt` file gets a
stub in `library/elems_todo_gen.mbt`, so the package always compiles; the stub
list doubles as a TODO list.

Field types are mapped through TYPEMAP. Types without a MoonBit port yet map to
`Value` (no validation) and are listed in the generated file header.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "library")

# Rust field type -> MoonBit type (must implement FromValue + IntoValue).
TYPEMAP = {
    "bool": "Bool",
    "i64": "Int64",
    "f64": "Double",
    "Content": "Content",
    "Option<Content>": "Content?",
    "Vec<Content>": "Array[Content]",
    "Length": "Length",
    "Angle": "Angle",
    "Ratio": "Ratio",
    "Fr": "Fr",
    "Rel<Length>": "Rel[Length]",
    "EcoString": "String",
    "Str": "String",
    "Option<EcoString>": "String?",
    "Option<bool>": "Bool?",
    "Func": "Func",
    "Label": "Label",
    "Styles": "Styles",
    "Value": "Value",
}

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


def mbt_type(rust):
    return TYPEMAP.get(rust, "Value")


def float_lit(x):
    return x if "." in x or "e" in x else x + ".0"


def translate_default(rust_ty, mty, expr):
    """Translate a `#[default(expr)]` into a Value expression, or None."""
    e = expr.strip()
    if e == "":
        return TYPE_DEFAULTS.get(mty) if mty != "Value" else None
    if e in ("true", "false") and mty == "Bool":
        return f"Bool({e})"
    if re.fullmatch(r"-?\d+", e):
        if mty in ("Int64", "Value") and rust_ty in ("i64", "usize", "u64", "isize", "NonZeroUsize"):
            return f"Int({e}L)"
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
    return None


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
                if fname not in defined:
                    todo.append(
                        f"///|\n/// TODO: fold for `{f['ty']}` ({e['ident']}.{f['ident']}).\nfn {fname}(inner : Value, _outer : Value) -> Value {{\n  inner\n}}\n"
                    )
                args.append(f"fold={fname}")
            if f["parse"] is not None:
                fname = f"{var}_{snake(f['ident'])}_parse"
                if fname not in defined:
                    todo.append(
                        f"///|\n/// TODO: port `#[parse]` of {e['ident']}.{f['ident']}.\nfn {fname}(_engine : Engine, args : Args) -> Value? raise SourceError {{\n  args.named_with({mbt_str(f['name'])}, v => v)\n}}\n"
                    )
                args.append(f"parse={fname}")
            fields.append(f"    field_of({', '.join(args)}),")
        caps = ", ".join(mbt_str(c) for c in e["capabilities"])
        kws = ", ".join(mbt_str(k) for k in e["keywords"])
        init_hook = f"{var}_init"
        init_call = f"      {init_hook}(e)\n" if init_hook in defined else ""
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
