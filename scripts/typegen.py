#!/usr/bin/env python3
"""Generate the native type descriptors from gen/manifest.json.

Upstream's `#[ty]` macro (typst-macros/src/ty.rs) builds a `NativeTypeData`
per type: the short name, the long name (the lowercased title), the title
and the docs. This generates the same data plus a `Type::<name>()` accessor
per type and `Type::all_native()` (`library/types_gen.mbt`).

Run `moon fmt` afterwards.
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "library")

# Accessors whose name differs from the type's short name: abbreviations
# used throughout the port, and MoonBit keywords / reserved words (which get
# a trailing underscore).
ACCESSOR_NAMES = {
    "dictionary": "dict",
    "arguments": "args",
    "function": "func",
    "type": "type_",
    "module": "module_",
}


def accessor_name(name):
    """Typst type name -> name of its `Type::<name>()` accessor."""
    return ACCESSOR_NAMES.get(name, name.replace("-", "_"))


def mbt_str(s):
    return json.dumps(s, ensure_ascii=False).replace("\\{", "\\\\{")


def mbt_since(since):
    """A manifest `since` (`"forever"`, `"unreleased"`, `"0.10.0"` or None) as
    a `since=..` argument (upstream `Option<Since>`), or `None` if absent."""
    if since is None:
        return None
    if since == "forever":
        return "since=Forever"
    if since == "unreleased":
        return "since=Unreleased"
    major, minor, patch = (int(x) for x in since.split("."))
    return f"since=Version({major}, {minor}, {patch})"


def main():
    manifest = json.load(open(os.path.join(ROOT, "gen", "manifest.json")))
    types = sorted(manifest["types"], key=lambda t: accessor_name(t["name"]))
    out = ["// Generated from gen/manifest.json (#[ty] definitions). Do not edit.\n"]
    for t in types:
        acc = accessor_name(t["name"])
        var = acc + "_type_data"
        out.append(
            f"///|\nlet {var} : NativeTypeData = NativeTypeData::new(\n"
            f"  name={mbt_str(t['name'])},\n"
            f"  long_name={mbt_str(t['title'].lower())},\n"
            f"  title={mbt_str(t['title'])},\n"
            + (f"  {mbt_since(t['since'])},\n" if t["since"] else "")
            + f"  docs={mbt_str(t['doc'])},\n"
            f"  keywords=[{', '.join(mbt_str(k) for k in t['keywords'])}],\n)\n"
        )
        out.append(
            f"///|\n/// The `{t['name']}` type (upstream `{t['ident']}`).\n"
            f"pub fn Type::{acc}() -> Type {{\n  Type({var})\n}}\n"
        )
    out.append(
        "///|\n/// All native types defined in the library, by short name.\n"
        "pub fn Type::all_native() -> Array[Type] {\n  [\n"
        + "".join(f"    Type::{accessor_name(t['name'])}(),\n" for t in types)
        + "  ]\n}\n"
    )
    with open(os.path.join(LIB, "types_gen.mbt"), "w") as f:
        f.write("\n".join(out))
    print(f"{len(types)} types")


if __name__ == "__main__":
    main()
