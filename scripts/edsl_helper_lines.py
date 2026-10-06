#!/usr/bin/env python3
"""Count the helper lines of an example (docs/edsl-ports.md, section 9).

    python3 scripts/edsl_helper_lines.py                  (doc/examples/report)
    python3 scripts/edsl_helper_lines.py NAME=file,file ..

A helper line is a line of code of a top-level function or constant that
has no text or data of the document. Whether an item has text or data is
decided by its author, by the file it is in: an example keeps its helpers
in files of their own, and this script counts the lines of code in them
(not blank lines, comments, the `///|` markers, or `using` declarations,
which name what a file uses and are not code of a helper).
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORT = "doc/examples/report/"
DEFAULT = {
    "before": ["shared.mbt", "before_helpers.mbt", "before.mbt"],
    "after": ["shared.mbt", "after.mbt"],
}


def code_lines(path):
    count = 0
    using = False
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        for line in f:
            text = line.strip()
            if using:
                using = "}" not in text
                continue
            if text.startswith("using "):
                using = "}" not in text
                continue
            if text and not text.startswith("//"):
                count += 1
    return count


def main():
    groups = {}
    for arg in sys.argv[1:]:
        name, _, files = arg.partition("=")
        groups[name] = files.split(",")
    if not groups:
        groups = {k: [REPORT + f for f in v] for k, v in DEFAULT.items()}
    for name, files in groups.items():
        counts = [(path, code_lines(path)) for path in files]
        total = sum(n for _, n in counts)
        parts = ", ".join(f"{os.path.basename(p)} {n}" for p, n in counts)
        print(f"{name}: {total} helper lines ({parts})")


if __name__ == "__main__":
    main()
