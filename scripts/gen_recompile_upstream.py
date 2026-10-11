#!/usr/bin/env python3
"""Generates `tests/recompile/upstream/*.json`: what the upstream binary's
`typst watch` gives, step by step, for sequences of edits after which a
recompilation is known to give something else than a compilation from
scratch.

Upstream compares modules by the identity of their inner data
(`PartialEq for Module`) and finds memoized calls by the hashes of their
arguments (comemo), a module's being its name and what it holds. So a call
that is found again can return the module of an earlier evaluation, which
`==` tells from the module of the same file evaluated now: after a change
of an imported file that leaves the hash of its module as it was (a
comment), `get() == m` is `false` in a watching process and `true` in a
fresh one, where `get() = m` captured the module. The port follows
upstream in both rules (the owner's decision of 2026-10-11), and will show
the same once its stores of memoized calls outlive a compilation.

The `recompile` stage requires a recompilation to give what a compilation
from scratch gives. It accepts one kind of difference: a step of a
sequence that is pinned here, whose pages are exactly what upstream's
watch wrote at that step (`tests/runner/recompile_pinned.mbt`;
`tests/recompile/README.md`, "As upstream's watch"). Each fixture is such
a sequence: per step the files that are written, the SVG of a fresh
`typst compile` and, where it is another, the SVG that the watching
process wrote. The documents draw boxes and no text, so that their SVG
does not depend on the fonts of a world.

Like `scripts/watch_check.py`, whose sessions this uses, it needs the
upstream binary and real file events: it is run by hand, when a scenario
is added or `UPSTREAM_REV` changes, and its output is committed.

Usage: python3 scripts/gen_recompile_upstream.py <path to upstream typst binary> [--check]
       (`--check`: compare with the committed fixtures instead of writing)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import watch_check  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tests", "recompile", "upstream")

CELL = "#let cell(on) = box(width: 10pt, height: 10pt, fill: if on { black } else { red })\n"

GETTER_MAIN = (
    "#set page(width: 60pt, height: 20pt, margin: 0pt)\n"
    '#import "a.typ" as m\n'
    "#let get() = m\n"
    + CELL
    + "#cell(get() == m)#cell(m == m)#cell(get().v == 1)\n"
)

MODULES_MAIN = (
    "#set page(width: 100pt, height: 20pt, margin: 0pt)\n"
    '#import "a.typ" as m\n'
    '#import "b.typ": held, get as theirs\n'
    "#let get() = m\n"
    "#let pick(d) = d.m\n"
    '#let s = state("s", m)\n'
    + CELL
    + "#metadata(m) <meta>\n"
    "// A getter that captured the module.\n"
    "#cell(get() == m)\n"
    "// The module as an argument, inside a dictionary.\n"
    "#cell(pick((m: m)) == m)\n"
    "// A module that another file imported and hands on.\n"
    "#cell(held == theirs())\n"
    "// The value of a state, and of a queried element.\n"
    "#context cell(s.get() == m)\n"
    "#context cell(query(<meta>).first().value == m)\n"
    "// What does not compare modules is what it was.\n"
    "#cell(get().v == 1)\n"
)

MODULES_B = '#import "a.typ" as held\n#let get() = held\n'


def module_a(comment):
    return "#let v = 1\n// comment %d\n" % comment


NAN_MAIN = (
    "#set page(width: 60pt, height: 20pt, margin: 0pt)\n"
    '#import "a.typ" as m\n'
    "#let get() = m\n"
    + CELL
    + "#cell(get() == m)#cell(m == m)#cell(get().v == m.v)#cell(m.v == m.v)\n"
)


def module_nan(comment):
    return "#let v = float.nan\n// comment %d\n" % comment


def memory_only_plugin(pages):
    """A plugin that exports its memory (of `pages` pages) and no function:
    `(module (memory (export "memory") <pages>))`. Its module is an empty
    scope, so the modules of two such plugins have one hash."""
    return (
        b"\x00asm\x01\x00\x00\x00"
        + b"\x05\x03\x01\x00" + bytes([pages])
        + b"\x07\x0a\x01\x06memory\x02\x00"
    )


PLUGIN_MAIN = (
    "#set page(width: 60pt, height: 20pt, margin: 0pt)\n"
    '#import "early.typ": p\n'
    '#import "late.typ": r\n'
    '#let q = plugin("q.wasm")\n'
    "#let early() = p\n"
    "#let late() = r\n"
    "#let mine() = q\n"
    + CELL
    + "// A plugin that the main file loads in every compilation.\n"
    "#cell(mine() == q)\n"
    "// Plugins that imported files loaded, which are not evaluated again\n"
    "// while they do not change.\n"
    "#cell(early() == p)#cell(late() == r)\n"
)


def plugin_file(name, comment):
    return '#let %s = plugin("%s.wasm")\n// comment %d\n' % (name, name, comment)


def plugin_steps():
    """`comemo::evict(10)` after every recompilation: the result of
    `Plugin::module` goes when it was not asked for in eleven of them. The
    main file changes ten times, then `early.typ` (ten evictions since its
    plugin was loaded: the module is found), then `late.typ` (eleven: the
    plugin is loaded again, as another module)."""
    steps = [
        (
            "the project",
            {
                "main.typ": PLUGIN_MAIN,
                "early.typ": plugin_file("p", 0),
                "late.typ": plugin_file("r", 0),
                "p.wasm": memory_only_plugin(1),
                "q.wasm": memory_only_plugin(2),
                "r.wasm": memory_only_plugin(3),
            },
        )
    ]
    for i in range(1, 11):
        steps.append(
            ("the main file, with nothing that matters (%d)" % i,
             {"main.typ": PLUGIN_MAIN + "// %d\n" % i})
        )
    steps.append(("a comment in early.typ, ten evictions after its plugin was loaded",
                  {"early.typ": plugin_file("p", 1)}))
    steps.append(("a comment in late.typ, eleven evictions after its plugin was loaded",
                  {"late.typ": plugin_file("r", 1)}))
    steps.append(("the main file, with nothing that matters",
                  {"main.typ": PLUGIN_MAIN + "// 11\n"}))
    steps.append(("another comment in early.typ", {"early.typ": plugin_file("p", 2)}))
    return steps


LIMIT_MAIN = (
    "#set page(width: 60pt, height: 20pt, margin: 0pt)\n"
    '#import "a.typ" as m\n'
    "// A function that reads a file and returns the module it captured: a\n"
    "// result per content of the file, under one key.\n"
    '#let get() = { let ignored = read("flag.txt"); m }\n'
    + CELL
    + "#cell(get() == m)#cell(m == m)\n"
)


def limit_steps():
    """comemo has no limit of results per key. The flag takes five
    contents, with a comment in `a.typ` at every step (a new module with
    the hash of the old one); then the first content again: the call of
    the first compilation is found, with the module of that evaluation."""
    steps = [("the project", {"main.typ": LIMIT_MAIN, "a.typ": module_a(0), "flag.txt": "0"})]
    for i in range(1, 6):
        steps.append(
            ("the flag is %d, and a comment in a.typ" % i,
             {"flag.txt": str(i), "a.typ": module_a(i)})
        )
    steps.append(("the flag is 0 again, and a comment in a.typ",
                  {"flag.txt": "0", "a.typ": module_a(6)}))
    steps.append(("the flag is 3 again", {"flag.txt": "3"}))
    return steps


# name -> (what the scenario shows, [(note, {path: text or bytes})]); the
# first step is the project, the others write the files they name.
SCENARIOS = {
    "getter": (
        "The smallest case: a function that returns the module it captured, "
        "compared with the module. A comment in the module's file changes.",
        [
            ("the project", {"main.typ": GETTER_MAIN, "a.typ": module_a(0)}),
            ("a comment in a.typ", {"a.typ": module_a(1)}),
            ("another", {"a.typ": module_a(2)}),
            ("the main file, with nothing that matters", {"main.typ": GETTER_MAIN + "\n"}),
            ("a comment in a.typ", {"a.typ": module_a(3)}),
        ],
    ),
    "nan": (
        "A module that exports `float.nan`. Its hash has the bits of the "
        "float, so the module of the file evaluated again has the hash of the "
        "one before and the getter is found, although the exported values are "
        "not `==` to themselves in either process.",
        [
            ("the project", {"main.typ": NAN_MAIN, "a.typ": module_nan(0)}),
            ("a comment in a.typ", {"a.typ": module_nan(1)}),
            ("another", {"a.typ": module_nan(2)}),
        ],
    ),
    "modules": (
        "A module through a getter, as an argument inside a dictionary and "
        "through another file that imported it, and where upstream's watch "
        "gives what a fresh compilation gives: a state's value and a queried "
        "element (their context expressions are found again as a whole), and "
        "an edit that changes what the module holds.",
        [
            ("the project", {"main.typ": MODULES_MAIN, "a.typ": module_a(0), "b.typ": MODULES_B}),
            ("a comment in a.typ", {"a.typ": module_a(1)}),
            ("another", {"a.typ": module_a(2)}),
            ("the main file, with nothing that matters", {"main.typ": MODULES_MAIN + "\n"}),
            ("a comment in a.typ", {"a.typ": module_a(3)}),
            ("a.typ as it was at first", {"a.typ": module_a(0)}),
            ("b.typ, with nothing that matters", {"b.typ": MODULES_B + "\n"}),
            ("a.typ with another binding", {"a.typ": "#let v = 1\n#let w = 2\n"}),
            ("a.typ as it was at first", {"a.typ": module_a(0)}),
        ],
    ),
    "plugin": (
        "The modules of plugins, which are memoized by the plugin's bytes "
        "(`Plugin::module`) and compare by identity. A plugin that is loaded "
        "in every compilation stays one module however long the session is; "
        "one that an imported file loaded is the module of that evaluation "
        "until its entry is evicted, ten recompilations after the last one "
        "that asked for it, and then another module than the one a kept "
        "call returns.",
        plugin_steps(),
    ),
    "limit": (
        "More results under one key than the port keeps of one compilation: "
        "a function that reads a file and returns a module it captured has "
        "one result per content of the file, and comemo keeps them all until "
        "they are old. After six contents the first comes back, and the call "
        "of the first compilation is found, with the module it returned then.",
        limit_steps(),
    ),
}


def data(content):
    return content if isinstance(content, bytes) else content.encode()


def record(binary, steps):
    """The fresh and the watched SVG of every step."""
    work = tempfile.mkdtemp(prefix="recompile-upstream-")
    args = ["main.typ", "out.svg", "--ignore-system-fonts"]
    recorded = []
    session = None
    try:
        for path, content in steps[0][1].items():
            watch_check.write(os.path.join(work, path), data(content))
        session = watch_check.Session([binary], args, work)
        session.wait_compiled(0)
        statuses = session.statuses(0)
        if not statuses or not statuses[-1].startswith("compiled successfully"):
            raise SystemExit(f"the first compilation failed: {statuses}")
        for i, (_, files) in enumerate(steps):
            if i > 0:
                # Let the watcher see one change, not half of one.
                time.sleep(0.3)
                mark = session.mark()
                for path, content in files.items():
                    watch_check.write(os.path.join(work, path), data(content))
                session.wait_compiled(mark)
                statuses = session.statuses(mark)
                # The SVG on disk is this step's only if the watching
                # process compiled and exported it.
                if not statuses or not statuses[-1].startswith("compiled successfully"):
                    raise SystemExit(f"step {i}: no successful recompilation: {statuses}")
            with open(os.path.join(work, "out.svg"), encoding="utf-8") as f:
                watched = f.read()
            fresh_path = os.path.join(work, "fresh.svg")
            done = subprocess.run(
                [binary, "compile", "main.typ", fresh_path, "--ignore-system-fonts"],
                cwd=work, stdin=subprocess.DEVNULL, capture_output=True, text=True)
            if done.returncode != 0:
                raise SystemExit(f"step {i}: {done.stderr}")
            with open(fresh_path, encoding="utf-8") as f:
                fresh = f.read()
            os.remove(fresh_path)
            if "<use" in fresh or "<text" in fresh:
                raise SystemExit(f"step {i}: the document sets text, its SVG depends on the fonts")
            recorded.append((fresh, watched))
    finally:
        if session is not None:
            session.stop()
        shutil.rmtree(work, ignore_errors=True)
    return recorded


def step_json(note, files, fresh, watched):
    step = {
        "edit": note,
        "files": {p: c for p, c in files.items() if not isinstance(c, bytes)},
    }
    # Files that are no text, as hexadecimal digits.
    binary = {p: c.hex() for p, c in files.items() if isinstance(c, bytes)}
    if binary:
        step["binary"] = binary
    step["fresh"] = fresh
    # Only where it is another: what the watching process wrote.
    step["watch"] = watched if watched != fresh else None
    return step


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    check = "--check" in sys.argv[1:]
    if len(args) != 1:
        sys.exit(__doc__)
    binary = os.path.abspath(args[0])
    version = subprocess.run([binary, "--version"], capture_output=True, text=True).stdout.strip()
    os.makedirs(OUT, exist_ok=True)
    stale = []
    for name, (what, steps) in SCENARIOS.items():
        recorded = record(binary, steps)
        if recorded[0][0] != recorded[0][1]:
            raise SystemExit(f"{name}: the first compilation of a watching process is not a fresh one")
        differing = [i for i, (fresh, watched) in enumerate(recorded) if fresh != watched]
        if not differing:
            raise SystemExit(f"{name}: upstream's watch gives what a fresh compilation gives at every step")
        fixture = {
            "generated": "by scripts/gen_recompile_upstream.py from the upstream binary. DO NOT EDIT.",
            "upstream": version,
            "what": what,
            "steps": [
                step_json(note, files, fresh, watched)
                for (note, files), (fresh, watched) in zip(steps, recorded)
            ],
        }
        text = json.dumps(fixture, indent=1, ensure_ascii=True) + "\n"
        path = os.path.join(OUT, name + ".json")
        if check:
            with open(path, encoding="utf-8") as f:
                if f.read() != text:
                    stale.append(name)
        else:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(text)
        print(f"{name}: {len(steps)} steps, watch differs from fresh at {differing}")
    if stale:
        raise SystemExit("not what the upstream binary gives: " + ", ".join(stale))


if __name__ == "__main__":
    main()
