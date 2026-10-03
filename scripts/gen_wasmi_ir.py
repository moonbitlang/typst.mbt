#!/usr/bin/env python3
"""Generate `wasmi/ir/op_gen.mbt` from wasmi_ir 1.0.9's `for_each_op.rs`.

The `for_each_op_grouped!` macro of wasmi_ir is the single source of truth of
Wasmi's instruction set. This script emits the MoonBit `Op` enum (one variant
per instruction, fields in upstream order), the snake-case constructors of
`r#enum.rs` (`Op::i32_add(...)`), `Op::visit_results` (visit_results.rs) and
`Op::name`.

Usage: python3 scripts/gen_wasmi_ir.py [path/to/wasmi_ir/src/for_each_op.rs]
"""

import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def find_source():
    if len(sys.argv) > 1:
        return sys.argv[1]
    pattern = os.path.expanduser(
        "~/.cargo/registry/src/index.crates.io-*/wasmi_ir-1.0.9/src/for_each_op.rs"
    )
    found = glob.glob(pattern)
    if not found:
        sys.exit("wasmi_ir-1.0.9 sources not found; pass the path explicitly")
    return found[0]


# Rust field type -> MoonBit type.
TYPES = {
    "Slot": "Slot",
    "[Slot; 2]": "FixedArray[Slot]",
    "[Slot; 3]": "FixedArray[Slot]",
    "SlotSpan": "SlotSpan",
    "FixedSlotSpan<2>": "FixedSlotSpan",
    "BoundedSlotSpan": "BoundedSlotSpan",
    "BranchOffset": "BranchOffset",
    "BranchOffset16": "BranchOffset16",
    "Const16<i32>": "Const16",
    "Const16<u32>": "Const16",
    "Const16<i64>": "Const16",
    "Const16<u64>": "Const16",
    "Const16<NonZeroI32>": "Const16",
    "Const16<NonZeroU32>": "Const16",
    "Const16<NonZeroI64>": "Const16",
    "Const16<NonZeroU64>": "Const16",
    "Const32<i64>": "Const32",
    "Const32<u64>": "Const32",
    "Const32<f64>": "Const32",
    "Const32<u32>": "Const32",
    "Const32<i32>": "Const32",
    "Const32<f32>": "Const32",
    "AnyConst32": "AnyConst32",
    "AnyConst16": "AnyConst16",
    "ShiftAmount<i32>": "ShiftAmount",
    "ShiftAmount<i64>": "ShiftAmount",
    "ShiftAmount<u32>": "ShiftAmount",
    "Sign<f32>": "Sign",
    "Sign<f64>": "Sign",
    "Offset16": "Offset16",
    "Offset8": "Offset8",
    "Offset64Lo": "Offset64Lo",
    "Offset64Hi": "Offset64Hi",
    "Address32": "Address32",
    "FuncType": "FuncType",
    "Func": "Func",
    "InternalFunc": "InternalFunc",
    "Global": "Global",
    "Memory": "Memory",
    "Table": "Table",
    "Data": "Data",
    "Elem": "Elem",
    "TrapCode": "@wasmi_core.TrapCode",
    "BlockFuel": "BlockFuel",
    "ImmLaneIdx2": "ImmLaneIdx",
    "ImmLaneIdx4": "ImmLaneIdx",
    "ImmLaneIdx8": "ImmLaneIdx",
    "ImmLaneIdx16": "ImmLaneIdx",
    "i8": "Int",
    "i16": "Int",
    "u8": "Int",
    "u16": "Int",
    "u32": "Int",
}

MOONBIT_KEYWORDS = {"type", "fn", "match", "if", "else", "let", "mut", "for"}


def parse(text):
    """Returns a list of (group, docs, snake, name, fields) where fields is a
    list of (is_result, name, rust_type, docs)."""
    ops = []
    group = None
    lines = text.split("\n")
    i = 0
    docs = []
    while i < len(lines):
        line = lines[i].strip()
        m = re.match(r"^@(\w+) \{$", line)
        if m and m.group(1) in ("default", "simd"):
            group = m.group(1)
            i += 1
            continue
        if group is None:
            i += 1
            continue
        if line.startswith("///"):
            docs.append(line[3:].strip() if line[3:4] == " " or line == "///" else line[3:])
            i += 1
            continue
        m = re.match(r"^#\[snake_name\((r#)?(\w+)\)\]$", line)
        if m:
            snake = m.group(2) + ("_" if m.group(1) else "")
            i += 1
            name_line = lines[i].strip()
            mi = re.match(r"^(\w+)\s*\{\s*(.*?)\s*\}\s*,?$", name_line)
            if mi:
                fields = []
                for part in [p.strip() for p in mi.group(2).split(",") if p.strip()]:
                    fm = re.match(r"^(@)?(\w+):\s*(.+)$", part)
                    assert fm, part
                    fields.append((bool(fm.group(1)), fm.group(2), fm.group(3).strip(), []))
                ops.append((group, docs, snake, mi.group(1), fields))
                docs = []
                i += 1
                continue
            m2 = re.match(r"^(\w+)\s*(\{)?\s*(,)?$", name_line)
            assert m2, name_line
            name = m2.group(1)
            fields = []
            if m2.group(2):
                i += 1
                fdocs = []
                while True:
                    fl = lines[i].strip()
                    if fl.startswith("}"):
                        break
                    if fl.startswith("///"):
                        fdocs.append(fl[3:].strip())
                        i += 1
                        continue
                    if fl.startswith("//") or fl == "":
                        i += 1
                        continue
                    fm = re.match(r"^(@)?(\w+):\s*(.+?),?$", fl)
                    assert fm, fl
                    fields.append((bool(fm.group(1)), fm.group(2), fm.group(3).strip(), fdocs))
                    fdocs = []
                    i += 1
            ops.append((group, docs, snake, name, fields))
            docs = []
            i += 1
            continue
        if line.startswith("}"):
            # End of a group (or the macro).
            if re.match(r"^\}\s*,?$", line) and group is not None:
                pass
        i += 1
    return ops


def field_name(is_result, name):
    if is_result:
        return name  # `result` / `results`
    if name in MOONBIT_KEYWORDS:
        return name + "_"
    return name


def main():
    src = find_source()
    text = open(src).read()
    ops = parse(text)
    names = [op[3] for op in ops]
    assert len(names) == len(set(names)), "duplicate op names"
    out = []
    w = out.append
    w("// Generated by scripts/gen_wasmi_ir.py from wasmi_ir 1.0.9's for_each_op.rs.")
    w("// Do not edit by hand.")
    w("")
    w("///|")
    w("/// A Wasmi instruction.")
    w("///")
    w("/// Wasmi instructions are composed of so-called instruction words.")
    w("/// This type represents all such words and for simplicity we call the type [`Op`], still.")
    w("///")
    w("/// Most instructions are composed of a single instruction word. An example of")
    w("/// this is [`Op::I32Add`]. However, some instructions, like the `select` instructions")
    w("/// are composed of two or more instruction words.")
    w("pub(all) enum Op {")
    for group, docs, snake, name, fields in ops:
        for d in docs:
            w(("  /// " + d).rstrip())
        if fields:
            parts = []
            for is_result, fname, fty, _ in fields:
                mty = TYPES.get(fty)
                assert mty is not None, f"unmapped type {fty} in {name}"
                parts.append(f"{field_name(is_result, fname)}~ : {mty}")
            w(f"  {name}({', '.join(parts)})")
        else:
            w(f"  {name}")
    w("}")
    w("")
    # Constructors.
    for group, docs, snake, name, fields in ops:
        w("///|")
        w(f"/// Creates a new [`Op::{name}`].")
        params = []
        args = []
        for is_result, fname, fty, _ in fields:
            fn = field_name(is_result, fname)
            params.append(f"{fn} : {TYPES[fty]}")
            args.append(f"{fn}~")
        if fields:
            w(f"pub fn Op::{snake}({', '.join(params)}) -> Op {{")
            w(f"  {name}({', '.join(args)})")
        else:
            w(f"pub fn Op::{snake}() -> Op {{")
            w(f"  {name}")
        w("}")
        w("")
    # Names.
    w("///|")
    w("/// The name of the instruction (its `Debug` variant name).")
    w("pub fn Op::name(self : Op) -> String {")
    w("  match self {")
    for group, docs, snake, name, fields in ops:
        pat = f"{name}(..)" if fields else name
        w(f'    {pat} => "{name}"')
    w("  }")
    w("}")
    w("")
    # visit_results.
    w("///|")
    w("/// Visits the result slots of the instruction (visit_results.rs), returning")
    w("/// the instruction with the slots the visitor returned.")
    w("pub fn[V : VisitResults] Op::visit_results(self : Op, visitor : V) -> Op {")
    w("  match self {")
    for group, docs, snake, name, fields in ops:
        res = [f for f in fields if f[0]]
        if not res:
            continue
        (_, rname, rty, _) = res[0]
        if rty == "[Slot; 2]":
            continue  # `ResultsVisitor for &mut [Slot; 2]` does nothing.
        others = [field_name(f[0], f[1]) for f in fields if not f[0]]
        binds = ", ".join([f"{rname}~"] + [f"{o}~" for o in others])
        w(f"    {name}({binds}) => {{")
        if rty == "Slot":
            w(f"      let {rname} = visitor.visit_result_reg({rname})")
        elif rty == "SlotSpan":
            w(f"      let {rname} = visitor.visit_result_regs({rname}, None)")
        elif rty == "BoundedSlotSpan":
            w(f"      let len = {rname}.len()")
            w(f"      let {rname} = BoundedSlotSpan::new(visitor.visit_result_regs({rname}.span(), Some(len)), len)")
        elif rty == "FixedSlotSpan<2>":
            w(f"      let {rname} = FixedSlotSpan::from_span_unchecked(visitor.visit_result_regs({rname}.span(), Some(2)))")
        else:
            raise AssertionError(f"unexpected result type {rty}")
        w(f"      {name}({binds})")
        w("    }")
    w("    _ => self")
    w("  }")
    w("}")
    w("")
    # Field accessors used where upstream mutates `&mut Op` fields in place.
    accessors = [
        # (is_result, field, rust type, getter name, setter name)
        (True, "result", "Slot", "result_slot", "set_result"),
        (False, "offset", "BranchOffset16", "branch_offset16", "set_branch_offset16"),
        (False, "offset", "BranchOffset", "branch_offset", "set_branch_offset"),
        (True, "results", "SlotSpan", "results_span", "set_results_span"),
    ]
    for want_result, fname, fty, getter, setter in accessors:
        mty = TYPES[fty]
        matching = []
        for group, docs, snake, name, fields in ops:
            for f in fields:
                if f[0] == want_result and f[1] == fname and f[2] == fty:
                    matching.append((name, fields))
        w("///|")
        w(f"/// Returns the `{fname}: {fty}` field of the instruction, if any.")
        w(f"pub fn Op::{getter}(self : Op) -> {mty}? {{")
        w("  match self {")
        for name, fields in matching:
            w(f"    {name}({fname}~, ..) => Some({fname})")
        w("    _ => None")
        w("  }")
        w("}")
        w("")
        w("///|")
        w(f"/// Returns the instruction with its `{fname}: {fty}` field replaced, if it has one.")
        w(f"pub fn Op::{setter}(self : Op, new_value : {mty}) -> Op? {{")
        w("  match self {")
        for name, fields in matching:
            others = [field_name(f[0], f[1]) for f in fields if f[1] != fname]
            binds = ", ".join(f"{o}~" for o in others)
            pat = f"{name}({binds})" if others else f"{name}(..)"
            args = ", ".join([f"{fname}=new_value"] + [f"{o}~" for o in others])
            w(f"    {pat} => Some({name}({args}))")
        w("    _ => None")
        w("  }")
        w("}")
        w("")
    path = os.path.join(ROOT, "wasmi", "ir", "op_gen.mbt")
    with open(path, "w") as f:
        f.write("\n".join(out))
    print(f"wrote {path}: {len(ops)} ops")


if __name__ == "__main__":
    main()
