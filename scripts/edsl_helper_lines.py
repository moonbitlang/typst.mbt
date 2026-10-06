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

The count is split in two, since one number hides what a library can take
away and what it cannot:

- `kit`: what the author wrote because the library has no element for it,
  and would write the same way in another document but for its constants
  (cards of equal height, a chip, a framed table, placing by coordinates,
  anchoring a label, an arrow with its head): what the kit provides;
- `own`: what the document has with any library: its colours, measures and
  scales, the styles of its text, and the functions that make a figure or
  a table of its data.

The class is the author's decision too, per top-level item: a comment line
`// helper-lines: kit` or `// helper-lines: own` gives the class of the
code after it, up to the next such line or the end of the file; a file
starts as `own`. An item that is both (a table helper with the document's
insets written into it) is counted as what it exists for.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPORT = "doc/examples/report/"
DEFAULT = {
    "before": [
        "shared.mbt",
        "before_helpers.mbt",
        "before_drawing.mbt",
        "before.mbt",
    ],
    "after": ["shared.mbt", "after.mbt"],
}
MARKER = "// helper-lines:"
CLASSES = ("kit", "own")


def code_lines(path):
    """The lines of code of a file, per class."""
    counts = {name: 0 for name in CLASSES}
    current = "own"
    using = False
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        for number, line in enumerate(f, 1):
            text = line.strip()
            if text.startswith(MARKER):
                current = text[len(MARKER):].strip()
                if current not in CLASSES:
                    sys.exit(f"{path}:{number}: unknown class `{current}`")
                continue
            if using:
                using = "}" not in text
                continue
            if text.startswith("using "):
                using = "}" not in text
                continue
            if text and not text.startswith("//"):
                counts[current] += 1
    return counts


def main():
    groups = {}
    for arg in sys.argv[1:]:
        name, _, files = arg.partition("=")
        groups[name] = files.split(",")
    if not groups:
        groups = {k: [REPORT + f for f in v] for k, v in DEFAULT.items()}
    for name, files in groups.items():
        counts = [(path, code_lines(path)) for path in files]
        total = {c: sum(n[c] for _, n in counts) for c in CLASSES}
        parts = ", ".join(
            f"{os.path.basename(p)} {n['kit'] + n['own']}" for p, n in counts
        )
        print(f"{name}: {total['kit'] + total['own']} helper lines ({parts})")
        print(
            f"  what the kit provides: {total['kit']}; "
            f"the document's own: {total['own']}"
        )
        for path, n in counts:
            if n["kit"] and n["own"]:
                print(
                    f"  {os.path.basename(path)}: "
                    f"{n['kit']} kit, {n['own']} own"
                )


if __name__ == "__main__":
    main()
