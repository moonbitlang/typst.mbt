#!/usr/bin/env python3
"""Engine code reads the world through the tracked world only.

    scripts/tracked_world_check.py

`library/tracked_world.mbt` records what memoized calls read of the world
(`docs/incremental-design.md`, section 5.2). That is only complete if no
engine code holds a raw `&World`. The type of `Engine.world` keeps other
packages from it; this script holds the rest:

- a raw world (`&World`, `&@library.World`) is named only where a
  compilation or an evaluation is entered (`typst/lib.mbt`) and in the two
  files that implement the tracked world;
- the raw world of a tracked world (its private field `raw`, which the
  compiler lets all of `library` read) is read in `tracked_world.mbt` only;
- `World::library` and `World::main`, which are not tracked, are called
  only where a compilation is entered.

Hosts (`doc`, `cli`, `kit`, `tests/runner`) keep their own world for what
is not compilation (diagnostics, dependencies); tests are not checked.
Exits with 1 and the offending lines if a rule is broken.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = [
    "library", "eval", "realize", "layout", "html", "bundle", "svg", "pdf",
    "render", "typst",
]
# Where a raw world may be named.
RAW_WORLD_FILES = {
    "library/tracked_world.mbt",
    "library/memo_check.mbt",
    "typst/lib.mbt",
}
RAW_WORLD = re.compile(r"&(@library\.)?World\b")
# The private field, as the tracked worlds of `library` are called.
RAW_FIELD = re.compile(r"\b(world|tracked)\.raw\b")
UNTRACKED = re.compile(r"\b(?:World::(library|main)\b|world\.(library|main)\(\))")


def sources():
    for package in ENGINE:
        for directory, _, names in os.walk(os.path.join(ROOT, package)):
            for name in sorted(names):
                if not name.endswith(".mbt"):
                    continue
                if name.endswith("_test.mbt") or name.endswith("_wbtest.mbt"):
                    continue
                path = os.path.join(directory, name)
                yield os.path.relpath(path, ROOT), path


def main():
    problems = []
    for rel, path in sources():
        with open(path, encoding="utf-8") as f:
            for number, line in enumerate(f, 1):
                code = line.split("//", 1)[0]
                if RAW_WORLD.search(code) and rel not in RAW_WORLD_FILES:
                    problems.append((rel, number, "a raw world", line))
                if (
                    rel.startswith("library/")
                    and rel != "library/tracked_world.mbt"
                    and RAW_FIELD.search(code)
                ):
                    problems.append((rel, number, "the raw world of a tracked world", line))
                if UNTRACKED.search(code) and rel not in RAW_WORLD_FILES:
                    problems.append((rel, number, "an untracked read of the world", line))
    for rel, number, what, line in problems:
        print(f"{rel}:{number}: {what}: {line.strip()}")
    if problems:
        print(f"tracked_world_check.py: {len(problems)} problems", file=sys.stderr)
        return 1
    print("tracked_world_check.py: engine code reads the world through the tracked world")
    return 0


if __name__ == "__main__":
    sys.exit(main())
