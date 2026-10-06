#!/usr/bin/env python3
"""Check that the samples of docs/edsl-guide.md are the compiled ones.

    python3 scripts/edsl_guide_check.py

A fenced block of the guide is compared with a file of the package
`doc/examples/guide` by the language named after its opening fence:

    ```moonbit   consecutive lines of guide.mbt (the compiled samples)
    ```text      consecutive lines of an expected output in guide_test.mbt
                 (the `#|` lines of an `inspect`)
    ```pkg       consecutive lines of moon.pkg

Trailing white space is ignored. A block without a language is not checked;
they are listed. Exits with 1 if a block is not found.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GUIDE = "docs/edsl-guide.md"
PACKAGE = "doc/examples/guide"
SOURCES = {"moonbit": "guide.mbt", "text": "guide_test.mbt", "pkg": "moon.pkg"}


def lines_of(path):
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return [line.rstrip() for line in f.read().split("\n")]


def expected_outputs(lines):
    """The lines of a test file with the `#|` of expected outputs removed."""
    out = []
    for line in lines:
        stripped = line.lstrip()
        out.append(stripped[2:] if stripped.startswith("#|") else line)
    return out


def blocks(lines):
    """(language, first line number, lines) of each fenced block."""
    out = []
    start = None
    for i, line in enumerate(lines):
        if not line.startswith("```"):
            continue
        if start is None:
            start = i
        else:
            out.append((lines[start][3:].strip(), start + 1, lines[start + 1 : i]))
            start = None
    if start is not None:
        sys.exit(f"{GUIDE}:{start + 1}: unclosed block")
    return out


def contains(haystack, needle):
    n = len(needle)
    return any(haystack[i : i + n] == needle for i in range(len(haystack) - n + 1))


def main():
    sources = {}
    for language, name in SOURCES.items():
        lines = lines_of(f"{PACKAGE}/{name}")
        sources[language] = expected_outputs(lines) if language == "text" else lines
    checked = 0
    unchecked = []
    failed = []
    for language, line, block in blocks(lines_of(GUIDE)):
        if language == "":
            unchecked.append(line)
        elif language not in sources:
            failed.append(f"{GUIDE}:{line}: unknown language `{language}`")
        elif not block or not contains(sources[language], block):
            failed.append(
                f"{GUIDE}:{line}: not in {PACKAGE}/{SOURCES[language]}: {block[:1]}"
            )
        else:
            checked += 1
    for message in failed:
        print(message)
    print(
        f"{checked} blocks are in {PACKAGE}, {len(failed)} are not; "
        f"not checked (no language): lines {unchecked}"
    )
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
