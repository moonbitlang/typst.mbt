#!/usr/bin/env python3
"""Record oracle outputs of `hayro_svg::convert` for `hayro/svg/oracle_test.mbt`.

Usage: python3 scripts/gen_hayro_svg_tests.py <oracle-binary> <pdf>[@page] ...

The oracle binary is a small Rust program that prints
`hayro_svg::convert(page, ...)` with Typst's settings for
`<oracle> svg <pdf> <page>` (see the hayro-svg port's notes). PDF paths are
recorded relative to the module root (use the `target/hayro` and
`target/devassets` symlinks). Writes `hayro/svg/testdata/expected.tsv` with
the length and FNV-1a 64 hash of each SVG.
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def fnv1a64(data):
    h = 0xCBF29CE484222325
    for b in data:
        h ^= b
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return h


def main():
    oracle = sys.argv[1]
    lines = ["# path\tpage\tlength\tfnv1a64 of hayro_svg::convert (Typst settings)"]
    for arg in sys.argv[2:]:
        path, _, page = arg.partition("@")
        page = int(page or 0)
        out = subprocess.run([oracle, "svg", path, str(page)], capture_output=True, check=True).stdout
        rel = os.path.relpath(os.path.abspath(path), ROOT) if os.path.isabs(path) else path
        lines.append(f"{rel}\t{page}\t{len(out)}\t{fnv1a64(out):016x}")
    path = os.path.join(ROOT, "hayro/svg/testdata/expected.tsv")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
