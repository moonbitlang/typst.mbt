"""Shared Rust -> MoonBit type mapping for the code generators.

A Rust type maps to a MoonBit type implementing `FromValue` + `IntoValue` with
upstream's casting semantics. Types without a port map to `Value` (accepted
unchecked); add entries here as types get ported.
"""
import re

TYPEMAP = {
    "bool": "Bool",
    "i64": "Int64",
    "f64": "Double",
    "u8": "U8",
    "u16": "U16",
    "u32": "U32",
    "u64": "U64",
    "usize": "USize",
    "i8": "I8",
    "i16": "I16",
    "i32": "I32",
    "NonZeroU32": "NonZeroU32",
    "NonZeroU64": "NonZeroU64",
    "NonZeroUsize": "NonZeroUSize",
    "NonZeroI64": "NonZeroI64",
    "Content": "Content",
    "Length": "Length",
    "Angle": "Angle",
    "Ratio": "Ratio",
    "Fr": "Fr",
    "Rel<Length>": "Rel[Length]",
    "Rel": "Rel[Length]",
    "EcoString": "String",
    "Str": "String",
    "String": "String",
    "Func": "Func",
    "Label": "Label",
    "Styles": "Styles",
    "Value": "Value",
    "Array": "Arr",
    "Dict": "Dict",
    "Args": "Args",
    "Type": "Type",
    "Alignment": "Alignment",
    "HAlignment": "HAlignment",
    "VAlignment": "VAlignment",
    "OuterHAlignment": "OuterHAlignment",
    "OuterVAlignment": "OuterVAlignment",
    "Dir": "Dir",
    "Side": "Side",
    "Axis": "Axis",
    "Spacing": "Spacing",
    "Sizing": "Sizing",
    "SyntaxMode": "@syntax.SyntaxMode",
    "Symbol": "Symbol",
    "SymbolVariant": "SymbolVariant",
    "Accent": "Accent",
    "RootedPath": "RootedPath",
    "PathOrStr": "PathOrStr",
    "BundlePath": "BundlePath",
    # foundations/array.rs, dict.rs, args.rs
    "ToArray": "ToArray",
    "ToDict": "ToDict",
    "ArgumentKey": "ArgumentKey",
    # foundations/calc.rs
    "ToAbs": "ToAbs",
    "Num": "Num",
    "DecNum": "DecNum",
    "AngleLike": "AngleLike",
    # foundations/int.rs, float.rs, str.rs (`Base`)
    "ToInt": "ToInt",
    "ToFloat": "ToFloat",
    "Base": "Base",
    "Endianness": "Endianness",
    # foundations/str.rs, text/case.rs
    "char": "Char",
    "Regex": "Regex",
    "StrPattern": "StrPattern",
    "StrSide": "StrSide",
    "Replacement": "Replacement",
    "ToStr": "ToStr",
    "UnicodeNormalForm": "UnicodeNormalForm",
    "Caseable": "Caseable",
    "Case": "Case",
}

# Generic Rust types with a MoonBit port: Rust name -> MoonBit name. A use
# `X<A, B>` maps to `X[A', B']` if every argument maps to a ported type
# (or is literally `Value`).
GENERICS = {
    "Smart": "Smart",
    "Axes": "Axes",
    # Only `Sides<Option<T>>` / `Corners<Option<T>>` are castable upstream.
    "Sides": "Sides",
    "Corners": "Corners",
    "SpecificAlignment": "SpecificAlignment",
}


def _split_generics(s):
    """Split `A, B<C, D>` at top-level commas."""
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out

def mbt_type(rust):
    """Map a Rust type to a MoonBit type, or 'Value' if unknown."""
    rust = rust.strip()
    if rust in TYPEMAP:
        return TYPEMAP[rust]
    m = re.fullmatch(r"Option<(.*)>", rust)
    if m:
        inner = mbt_type(m.group(1))
        return "Value" if inner == "Value" and m.group(1) != "Value" else inner + "?"
    m = re.fullmatch(r"Vec<(.*)>", rust)
    if m:
        inner = mbt_type(m.group(1))
        if inner == "Value" and m.group(1) != "Value":
            return "Value"
        return f"Array[{inner}]"
    m = re.fullmatch(r"(\w+)<(.*)>", rust)
    if m and m.group(1) in GENERICS:
        args = _split_generics(m.group(2))
        mapped = [mbt_type(a) for a in args]
        if any(x == "Value" and a != "Value" for x, a in zip(mapped, args)):
            return "Value"
        return f"{GENERICS[m.group(1)]}[{', '.join(mapped)}]"
    return "Value"
