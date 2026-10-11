#!/usr/bin/env python3
"""End-to-end check of `typst watch` (a local check, not a CI stage).

What this script checks is the command line program: that the watcher sees
a change, what the program prints and what it writes, in a handful of
scenarios with real file events and the upstream binary. That a compilation
after an edit gives exactly what a compilation from scratch gives, for
thousands of seeded edits of many documents, is checked in process by the
`recompile` stage of the differential runner (tests/recompile/README.md),
which is a CI stage and tests the engine, not this program.

    scripts/watch_check.py [--typst CMD] [--upstream BIN | --no-upstream]
                           [--only NAME] [--keep] [-v]
    scripts/watch_check.py --bench | --bench-memory [--document NAME]
                           [--binary LABEL=PATH] [--sessions N] [--edits N]

Starts `typst watch` in temporary directories, edits files, waits for the
status line of the recompilation and checks

- that the output of every recompilation is, byte for byte, what a fresh
  `typst compile` of the same files gives (a process that compiles again
  and again keeps what it computed, and must not take anything for the
  files as they are now that depends on what they were: sources, imported
  modules, data files, images, packages, fonts, ...). The one exception is
  upstream's own: the scenarios `pinned-*` replay the sequences of
  `tests/recompile/upstream`, documents that compare modules, and there
  the output must be what upstream's watch wrote, which is not a fresh
  compilation's at the steps the fixtures say (`scenario_pinned`),
- that the watcher sees the change at all (in-place writes, files replaced
  by a rename as editors do, removed and recreated files and directories,
  files that appear later), and does not recompile for files that are not
  dependencies (any more),
- with the upstream binary as the reference, that what is printed (status
  lines, diagnostics, the screen clearing of `--color always`) is the same
  after replacing timestamps, durations and the directory.

`--typst` is the command of the CLI under test, by default the native
release build (`moon build --target native --release cli`); for wasm pass
`--typst "moonrun _build/wasm/release/build/cli/cli.wasm --"`. `--upstream`
defaults to `.repos/typst/target/release/typst` if that exists.

`--bench` instead measures the first and the following compilations in
watch sessions, for both binaries and for every other build named with
`--binary LABEL=PATH` (the durations are the ones the status lines
report; PDF output, `--ignore-system-fonts`). The documents are those of
section 3 of `docs/incremental-design.md`: `bench/long.typ`, `longer.typ`
and `showcase.typ`, a touying deck and the ilm handbook of
`tests/packages/docs` (they need `.repos/typst-packages`), the projects of
`tests/recompile/docs` and the image deck of `bench/mkdeck.py`. Four edits
are measured, `--edits` times each per session, in `--sessions` sessions
per document and binary: a character appended to the main file, an edit
in the middle of it (in `long` and `longer` the body of the loop: every
heading changes), a change of an imported file that reaches the pages (of
a package's theme, a bibliography), and a comment appended to the main
file. `--bench-memory` prints the resident set size of the watching
process after 10, 50 and 200 edits instead.
"""

import argparse
import json
import os
import re
import shlex
import shutil
import statistics
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The command of the CLI under test.
PORT = None
STATUS = re.compile(
    rb"^\[\d\d:\d\d:\d\d\] (compiled (successfully in .*|with warnings in .*|with errors))$"
)
COMPILING = re.compile(rb"^\[\d\d:\d\d:\d\d\] compiling \.\.\.$")
VERBOSE = False


def log(*args):
    if VERBOSE:
        print(*args, file=sys.stderr, flush=True)


class Failure(Exception):
    pass


class Skip(Exception):
    """A scenario that the CLI under test cannot run."""


class Session:
    """A running `typst watch`."""

    def __init__(self, command, args, cwd, global_args=()):
        self.command = command
        self.cwd = cwd
        self.out = bytearray()
        self.changed = time.monotonic()
        self.lock = threading.Condition()
        self.proc = subprocess.Popen(
            command + list(global_args) + ["watch"] + args,
            cwd=cwd,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _read(self):
        while True:
            chunk = self.proc.stdout.read1(65536)
            if not chunk:
                break
            with self.lock:
                self.out += chunk
                self.changed = time.monotonic()
                self.lock.notify_all()
        with self.lock:
            self.lock.notify_all()

    def mark(self):
        with self.lock:
            return len(self.out)

    def text(self, start=0):
        with self.lock:
            return bytes(self.out[start:])

    def statuses(self, start):
        """The status messages printed since `start`."""
        found = []
        for line in self.text(start).split(b"\n"):
            m = STATUS.match(line)
            if m:
                found.append(m.group(1).decode())
        return found

    def busy(self, start):
        """Whether the last status line since `start` is "compiling"."""
        last = None
        for line in self.text(start).split(b"\n"):
            if STATUS.match(line):
                last = False
            elif COMPILING.match(line):
                last = True
        return last is None or last

    def wait_compiled(self, start, timeout=120.0, quiet=0.7):
        """Waits until a compilation that started after `start` is done and
        nothing was printed for a while (a second compilation may follow the
        first if the change arrived in pieces)."""
        deadline = time.monotonic() + timeout
        with self.lock:
            while True:
                now = time.monotonic()
                if self.proc.poll() is not None:
                    raise Failure(
                        f"`typst watch` exited with {self.proc.returncode}:\n"
                        + self.out[start:].decode(errors="replace")
                    )
                if not self.busy(start) and now - self.changed >= quiet:
                    return
                if now > deadline:
                    raise Failure(
                        "no recompilation within %.0f s; printed since the change:\n%s"
                        % (timeout, self.out[start:].decode(errors="replace"))
                    )
                self.lock.wait(0.1)

    def expect_quiet(self, start, duration=1.5):
        """Checks that nothing is printed for `duration` seconds."""
        time.sleep(duration)
        printed = self.text(start)
        if printed:
            raise Failure(
                "unexpected output:\n" + printed.decode(errors="replace")
            )

    def stop(self):
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        self.reader.join(5)


def last_cycle(text, fullscreen):
    """What the last compilation printed: from its "compiling" status (in
    fullscreen mode from the header before it) to the end."""
    lines = text.split(b"\n")
    start = None
    for i, line in enumerate(lines):
        if COMPILING.match(line):
            start = i
    if start is None:
        return text
    if fullscreen:
        start = max(0, start - 3)
    return b"\n".join(lines[start:])


def diagnostics_of(cycle):
    """The diagnostics of a compilation: what follows its status line and
    the blank line after it."""
    lines = cycle.split(b"\n")
    last = None
    for i, line in enumerate(lines):
        if STATUS.match(line):
            last = i
    if last is None:
        return cycle
    return b"\n".join(lines[last + 2 :])


def normalize(text, directory):
    """Replaces what differs from run to run."""
    text = text.replace(os.path.realpath(directory).encode(), b"<dir>")
    text = text.replace(directory.encode(), b"<dir>")
    text = re.sub(rb"\[\d\d:\d\d:\d\d\]", b"[TIME]", text)
    text = re.sub(
        rb"(compiled (?:successfully|with warnings) in) [^\n]*", rb"\1 DURATION", text
    )
    return text


def write(path, data):
    """Writes a file in place."""
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(path, mode) as f:
        f.write(data)


def replace(path, data):
    """Writes a temporary file and renames it over `path` (an atomic save)."""
    tmp = path + ".tmp~"
    write(tmp, data)
    os.replace(tmp, path)


def move_away_and_write(path, data):
    """Renames `path` away and writes a new file (vim's default)."""
    backup = path + "~"
    os.rename(path, backup)
    write(path, data)
    os.remove(backup)


def png(width, height, rgb):
    """A PNG of one color."""

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    row = b"\x00" + bytes(rgb) * width
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(row * height))
        + chunk(b"IEND", b"")
    )


def svg(color):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">'
        f'<defs><linearGradient id="g"><stop offset="0" stop-color="{color}"/>'
        '<stop offset="1" stop-color="white"/></linearGradient></defs>'
        '<rect width="20" height="20" fill="url(#g)"/></svg>'
    )


def theme(color):
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>name</key><string>Check</string>
<key>settings</key><array>
<dict><key>settings</key><dict>
<key>background</key><string>#ffffff</string>
<key>foreground</key><string>{color}</string>
</dict></dict>
<dict><key>scope</key><string>keyword</string><key>settings</key><dict>
<key>foreground</key><string>#aa0000</string></dict></dict>
</array></dict></plist>
"""


BIB = """@article{knuth, author = {Donald Knuth}, title = {%s}, journal = {J}, year = {1984}}
"""

MAIN = """#import "lib.typ": shout, total
#import "@local/pkg:0.1.0": greet
#set page(width: 12cm, height: auto, margin: 1cm, numbering: "i")
#set heading(numbering: "%(numbering)s")
#set raw(theme: "theme.tmTheme")
= Title
== Section
#shout[imported] and #greet("package").
Total: #total, note: #read("note.txt").
#let scale = %(scale)s
#let twice = x => x * scale
#let apply(f) = f(3)
Closure: #apply(twice), counter: #context counter(heading).display("A.1").
#include "chapters/one.typ"
#image("figs/dot.png", width: 1cm)
#image("figs/shape.svg", width: 1cm)
```rust
fn main() { let x = 1; }
```
%(extra)s
See @knuth. #lorem(%(words)d)
#outline()
#bibliography("refs.bib")
"""

LIB = """#import "deep/inner.typ": factor
#let data = json("data.json")
#let total = data.values.sum() * factor
#let shout(body) = [*%s* #body]
"""


class Project:
    """The files of the main scenario."""

    def __init__(self, directory):
        self.dir = directory
        self.main = {"numbering": "1.a", "scale": "2", "extra": "", "words": 12}
        os.makedirs(self.path("deep"))
        os.makedirs(self.path("chapters"))
        os.makedirs(self.path("figs"))
        self.package = self.path("packages/local/pkg/0.1.0")
        os.makedirs(self.package)
        os.makedirs(self.path("cache"))
        self.write_main()
        write(self.path("lib.typ"), LIB % "Shout")
        write(self.path("deep/inner.typ"), "#let factor = 1\n")
        write(self.path("data.json"), '{"values": [1, 2, 3]}\n')
        write(self.path("note.txt"), "first")
        write(self.path("chapters/one.typ"), "== Chapter one\nText of the chapter.\n")
        write(self.path("figs/dot.png"), png(4, 4, (200, 30, 30)))
        write(self.path("figs/shape.svg"), svg("#3050c0"))
        write(self.path("theme.tmTheme"), theme("#004488"))
        write(self.path("refs.bib"), BIB % "The Book")
        write(
            os.path.join(self.package, "typst.toml"),
            '[package]\nname = "pkg"\nversion = "0.1.0"\nentrypoint = "lib.typ"\n',
        )
        write(os.path.join(self.package, "lib.typ"), "#let greet(who) = [Hello, #who]\n")
        write(os.path.join(self.package, "other.typ"), "#let greet(who) = [Bye, #who]\n")

    def path(self, name):
        return os.path.join(self.dir, name)

    def write_main(self, how=write, **changes):
        self.main.update(changes)
        how(self.path("main.typ"), MAIN % self.main)

    def args(self):
        return [
            "--ignore-system-fonts",
            "--package-path",
            self.path("packages"),
            "--package-cache-path",
            self.path("cache"),
        ]


def compile_fresh(command, args, cwd, source, output, global_args=()):
    """`typst compile` in a new process; returns (status, stderr)."""
    result = subprocess.run(
        command + list(global_args) + ["compile", source, output] + args,
        cwd=cwd,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.returncode, result.stderr


class Runner:
    """Runs a scenario for one binary and records what it printed per step."""

    def __init__(self, name, command, keep):
        self.name = name
        self.command = command
        self.keep = keep
        self.records = []  # (step, normalized last cycle, output bytes or None)
        self.problems = []
        self.dir = None
        self.session = None
        self.fullscreen = False
        self.fresh_args = []
        self.global_args = []
        self.output = None
        self.first = True

    def start(
        self,
        args,
        output,
        fresh_args=None,
        fullscreen=False,
        source="main.typ",
        global_args=(),
    ):
        self.fullscreen = fullscreen
        self.output = output
        self.source = source
        self.fresh_args = fresh_args if fresh_args is not None else args
        self.global_args = list(global_args)
        self.first = True
        flags = [] if fullscreen else ["--no-fullscreen"]
        self.session = Session(
            self.command, [source, output] + flags + args, self.dir, global_args
        )

    def step(
        self,
        name,
        action=None,
        expect="compiled successfully",
        compare=True,
        timeout=120.0,
    ):
        """Does something and waits for the recompilation, whose status must
        start with `expect` (`quiet`: there must be none)."""
        session = self.session
        # The first step looks at everything: the initial compilation may be
        # over before it starts to look.
        start = 0 if self.first else session.mark()
        self.first = False
        log(f"[{self.name}] {name}")
        if action is not None:
            action()
        try:
            if expect == "quiet":
                session.expect_quiet(start)
                self.records.append((name, b"", None))
                return
            session.wait_compiled(start, timeout=timeout)
        except Failure as failure:
            self.problems.append(f"{name}: {failure}")
            self.records.append((name, b"<failed>", None))
            return
        cycle = last_cycle(session.text(start), self.fullscreen)
        status = session.statuses(start)[-1]
        log(f"[{self.name}]   {status}")
        if not status.startswith(expect):
            self.problems.append(f"{name}: expected `{expect}`, got `{status}`")
        produced = None
        if compare:
            produced = self.compare_with_fresh(name, status, diagnostics_of(cycle))
        self.records.append((name, normalize(cycle, self.dir), produced))

    def compare_with_fresh(self, name, status, diagnostics):
        """Compares what the watcher made of the files with a fresh
        compilation: whether it succeeds, its diagnostics, its output."""
        fresh_dir = tempfile.mkdtemp(prefix="watch-fresh-")
        try:
            fresh = os.path.join(fresh_dir, os.path.basename(self.output))
            code, stderr = compile_fresh(
                self.command, self.fresh_args, self.dir, self.source, fresh, self.global_args
            )
            failed = status.startswith("compiled with errors")
            if (code != 0) != failed:
                self.problems.append(
                    f"{name}: `{status}`, but a fresh compilation exits with {code}:\n"
                    + stderr.decode(errors="replace")
                )
                return None
            if normalize(stderr, self.dir) != normalize(diagnostics, self.dir):
                self.problems.append(
                    f"{name}: the diagnostics differ from a fresh compilation's:\n"
                    + diagnostics.decode(errors="replace")
                    + "\n--- fresh\n"
                    + stderr.decode(errors="replace")
                )
            if failed:
                return None
            produced = b""
            for entry in sorted(os.listdir(fresh_dir)):
                expected = open(os.path.join(fresh_dir, entry), "rb").read()
                watched_path = os.path.join(
                    os.path.dirname(os.path.join(self.dir, self.output)), entry
                )
                if not os.path.exists(watched_path):
                    self.problems.append(f"{name}: `{entry}` was not written")
                    continue
                watched = open(watched_path, "rb").read()
                produced += watched
                if watched != expected:
                    self.problems.append(
                        f"{name}: `{entry}` differs from a fresh compilation "
                        f"({len(watched)} and {len(expected)} bytes): stale state"
                    )
                    if self.keep:
                        shutil.copy(watched_path, watched_path + ".watched")
                        shutil.copy(os.path.join(fresh_dir, entry), watched_path + ".fresh")
            return produced
        finally:
            shutil.rmtree(fresh_dir, ignore_errors=True)

    def finish(self):
        if self.session is not None:
            self.session.stop()
            self.session = None


def scenario_main(r):
    """Every kind of dependency, changed in every way an editor saves."""
    p = Project(r.dir)
    r.start(p.args(), "out.svg")
    r.step("initial compilation")
    r.step("main file, written in place", lambda: p.write_main(words=14))
    r.step("main file, replaced by a rename", lambda: p.write_main(replace, words=16))
    r.step(
        "main file, moved away and written anew",
        lambda: p.write_main(move_away_and_write, words=18),
    )
    r.step("main file, once more in place", lambda: p.write_main(words=20))
    r.step("imported file", lambda: replace(p.path("lib.typ"), LIB % "Louder"))
    r.step(
        "file imported by an imported file",
        lambda: write(p.path("deep/inner.typ"), "#let factor = 10\n"),
    )
    r.step(
        "data file read by an imported file (json)",
        lambda: write(p.path("data.json"), '{"values": [1, 2, 3, 100]}\n'),
    )
    r.step("data file (read)", lambda: move_away_and_write(p.path("note.txt"), "second"))
    r.step(
        "included file",
        lambda: write(p.path("chapters/one.typ"), "== Chapter 1\nOther text.\n"),
    )
    r.step("image (PNG)", lambda: replace(p.path("figs/dot.png"), png(4, 4, (30, 160, 60))))
    r.step("image (SVG)", lambda: write(p.path("figs/shape.svg"), svg("#c05030")))
    r.step("syntax theme", lambda: write(p.path("theme.tmTheme"), theme("#226600")))
    r.step("bibliography", lambda: write(p.path("refs.bib"), BIB % "Another Book"))
    r.step(
        "file of a local package",
        lambda: write(os.path.join(p.package, "lib.typ"), "#let greet(who) = [Hi, #who]\n"),
    )
    r.step(
        "manifest of a local package (another entrypoint)",
        lambda: replace(
            os.path.join(p.package, "typst.toml"),
            '[package]\nname = "pkg"\nversion = "0.1.0"\nentrypoint = "other.typ"\n',
        ),
    )
    r.step("numbering pattern", lambda: p.write_main(numbering="I.1"))
    r.step("what a closure captures", lambda: p.write_main(scale="5"))

    # Diagnostics.
    r.step(
        "a warning",
        lambda: p.write_main(extra='#text(font: "No Such Font")[warned]'),
        expect="compiled with warnings",
    )
    r.step("the same warning again", lambda: p.write_main(words=21), expect="compiled with warnings")
    r.step(
        "an error",
        lambda: p.write_main(extra="#(1 +"),
        expect="compiled with errors",
    )
    r.step(
        "an error in an imported file",
        lambda: (p.write_main(extra=""), write(p.path("deep/inner.typ"), "#let factor = \n")),
        expect="compiled with errors",
    )
    r.step(
        "fixed",
        lambda: write(p.path("deep/inner.typ"), "#let factor = 3\n"),
        expect="compiled successfully",
    )

    # The set of dependencies changes.
    def add_import():
        write(p.path("chapters/two.typ"), "== Chapter two\nNew.\n")
        p.write_main(extra='#include "chapters/two.typ"')

    r.step("a new dependency", add_import)
    r.step(
        "the new dependency changes",
        lambda: write(p.path("chapters/two.typ"), "== Chapter two\nNewer.\n"),
    )
    r.step("a dependency is dropped", lambda: p.write_main(extra=""))
    r.step(
        "the dropped dependency changes",
        lambda: write(p.path("chapters/two.typ"), "== Unused\n"),
        expect="quiet",
    )
    r.step(
        "a file that never was a dependency changes",
        lambda: write(p.path("unrelated.txt"), "x"),
        expect="quiet",
    )

    # Files that go away and come back.
    r.step(
        "a dependency is removed",
        lambda: os.remove(p.path("note.txt")),
        expect="compiled with errors",
    )
    r.step("and created again", lambda: write(p.path("note.txt"), "third"))
    r.step("and changed", lambda: write(p.path("note.txt"), "fourth"))

    def replace_directory():
        shutil.rmtree(p.path("figs"))
        os.makedirs(p.path("figs"))
        write(p.path("figs/dot.png"), png(4, 4, (10, 10, 200)))
        write(p.path("figs/shape.svg"), svg("#101010"))

    r.step("a directory is removed and created again", replace_directory)
    r.step(
        "a file in the new directory changes",
        lambda: write(p.path("figs/shape.svg"), svg("#909090")),
    )
    r.step(
        "another file in the new directory changes",
        lambda: write(p.path("figs/dot.png"), png(4, 4, (250, 250, 0))),
    )
    r.step("the main file, at the end", lambda: p.write_main(words=30))


SYNTAX = """%%YAML 1.2
---
name: Check
file_extensions: [chk]
scope: source.chk
contexts:
  main:
    - match: '\\b%s\\b'
      scope: keyword.control.chk
"""

DATA = """#set page(width: 12cm, height: auto, margin: 1cm)
#set raw(syntaxes: "check.sublime-syntax", theme: "theme.tmTheme")
#let rows = csv("table.csv")
#table(columns: 2, ..rows.flatten())
YAML: #yaml("config.yaml").name, TOML: #toml("config.toml").name,
XML: #xml("doc.xml").first().children.first().
#image("figure.pdf", width: 2cm)
#image("photo.jpg", width: 2cm)
```chk
foo bar
```
"""

# Files that a scenario needs and that are made with the CLI under test.
MADE = {}


def made_pdf(command, text):
    """A PDF of a one-line document (the same bytes for every binary)."""
    if text not in MADE:
        directory = tempfile.mkdtemp(prefix="watch-made-")
        try:
            write(os.path.join(directory, "doc.typ"), text)
            code, stderr = compile_fresh(
                command,
                ["--ignore-system-fonts", "--creation-timestamp", "0"],
                directory,
                "doc.typ",
                "doc.pdf",
            )
            if code != 0:
                raise Failure("could not make a PDF:\n" + stderr.decode(errors="replace"))
            MADE[text] = open(os.path.join(directory, "doc.pdf"), "rb").read()
        finally:
            shutil.rmtree(directory, ignore_errors=True)
    return MADE[text]


def scenario_data(r):
    """Data files, a PDF and a JPEG image, a syntax definition."""
    path = lambda name: os.path.join(r.dir, name)
    page = "#set page(width: 3cm, height: 2cm, fill: %s)\n%s\n"
    write(path("main.typ"), DATA)
    write(path("check.sublime-syntax"), SYNTAX % "foo")
    write(path("theme.tmTheme"), theme("#004488"))
    write(path("table.csv"), "a,b\n1,2\n")
    write(path("config.yaml"), "name: first\n")
    write(path("config.toml"), 'name = "first"\n')
    write(path("doc.xml"), "<doc>first</doc>\n")
    write(path("figure.pdf"), made_pdf(PORT, page % ("aqua", "One")))
    photo = open(os.path.join(ROOT, "bench/glacier.jpg"), "rb").read()
    write(path("photo.jpg"), photo)
    r.start(["--ignore-system-fonts"], "out.svg")
    r.step("initial compilation")
    r.step("csv", lambda: write(path("table.csv"), "a,b\n1,2\n3,4\n"))
    r.step("yaml", lambda: replace(path("config.yaml"), "name: second\n"))
    r.step("toml", lambda: move_away_and_write(path("config.toml"), 'name = "second"\n'))
    r.step("xml", lambda: write(path("doc.xml"), "<doc>second</doc>\n"))
    r.step(
        "image (PDF)",
        lambda: replace(path("figure.pdf"), made_pdf(PORT, page % ("yellow", "Two"))),
    )
    # Another JPEG: the same picture with a comment segment after the SOI
    # marker would decode alike, so cut the scan short instead.
    r.step("image (JPEG)", lambda: write(path("photo.jpg"), photo[: len(photo) * 2 // 3] + b"\xff\xd9"))
    r.step(
        "syntax definition",
        lambda: write(path("check.sublime-syntax"), SYNTAX % "bar"),
    )
    r.step("the main file", lambda: write(path("main.typ"), DATA + "End.\n"))


def scenario_links(r):
    """A dependency that is a symbolic link."""
    if any(part.endswith(".wasm") for part in r.command):
        raise Skip("the wasm build cannot tell a symbolic link")
    path = lambda name: os.path.join(r.dir, name)
    os.makedirs(path("store"))
    write(path("store/data.txt"), "one")
    write(path("store/other.txt"), "other")
    os.symlink("store/data.txt", path("data.txt"))
    write(path("main.typ"), '#read("data.txt")\n')
    r.start(["--ignore-system-fonts"], "out.svg")
    r.step("initial compilation")
    r.step("the link's file, written in place", lambda: write(path("store/data.txt"), "two"))
    r.step(
        "the link's file, replaced by a rename",
        lambda: replace(path("store/data.txt"), "three"),
    )
    r.step("and written in place again", lambda: write(path("store/data.txt"), "four"))
    r.step("the main file", lambda: write(path("main.typ"), '#read("data.txt")!\n'))
    r.step("the link's file, once more", lambda: write(path("store/data.txt"), "five"))


def scenario_linked(r):
    """An SVG that links a PNG, exported as PNG pages: a page is exported
    again if its hash changed, and the hash of an SVG image must cover the
    images it links.

    Upstream's does not, and its `Image::new` is memoized on that hash: it
    keeps showing the first photo (`e58a63af`). So its pages are not
    compared with a fresh compilation, only its status lines with the
    port's (nor are the files of the two compared: the pixels of their PNGs
    are the same, the compressed bytes are not)."""
    path = lambda name: os.path.join(r.dir, name)
    linked = (
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="20">'
        '<image href="photo.png" width="20" height="20"/></svg>'
    )
    write(path("art.svg"), linked % 20)
    write(path("photo.png"), png(4, 4, (200, 30, 30)))
    write(
        path("main.typ"),
        "#set page(width: 4cm, height: 3cm)\n"
        '#image("art.svg", width: 1cm)\n'
        "#pagebreak()\n"
        '#box(width: 1cm, height: 1cm, fill: tiling(size: (5mm, 5mm), image("art.svg", width: 5mm)))\n',
    )
    port = r.name == "port"
    r.start(["--ignore-system-fonts"], "page-{p}.png")
    r.step("initial compilation", compare=port)
    r.step(
        "the linked image",
        lambda: replace(path("photo.png"), png(4, 4, (30, 30, 200))),
        compare=port,
    )
    r.step(
        "the linked image, written in place",
        lambda: write(path("photo.png"), png(4, 4, (30, 200, 30))),
        compare=port,
    )
    r.step(
        "the first image again",
        lambda: replace(path("photo.png"), png(4, 4, (200, 30, 30))),
        compare=port,
    )
    r.step("the SVG", lambda: write(path("art.svg"), linked % 30), compare=port)


def scenario_fullscreen(r):
    """The status of the default mode, with colors and screen clearing."""
    write(os.path.join(r.dir, "main.typ"), "= Fullscreen\nText.\n")
    r.start(
        ["--ignore-system-fonts"],
        "out.svg",
        fullscreen=True,
        global_args=["--color", "always"],
    )
    main = os.path.join(r.dir, "main.typ")
    r.step("initial compilation")
    r.step(
        "a warning",
        lambda: write(main, '= Fullscreen\n#text(font: "No Such Font")[x]\n'),
        expect="compiled with warnings",
    )
    r.step("an error", lambda: write(main, "= Fullscreen\n#(\n"), expect="compiled with errors")
    r.step("fixed", lambda: write(main, "= Fullscreen\nDone.\n"), expect="compiled successfully")


def scenario_missing(r):
    """The input does not exist when `typst watch` starts."""
    os.makedirs(os.path.join(r.dir, "project"))
    r.start(["--ignore-system-fonts"], "out.svg", source="project/main.typ")
    r.step("no input file", expect="compiled with errors")
    r.step(
        "the input file appears",
        lambda: write(os.path.join(r.dir, "project/main.typ"), "Now it is there.\n"),
        expect="compiled successfully",
    )
    r.step(
        "and changes",
        lambda: write(os.path.join(r.dir, "project/main.typ"), "And changed.\n"),
    )


def scenario_pages(r):
    """One image per page: pages that did not change are not written again."""
    main = os.path.join(r.dir, "main.typ")
    text = "#set page(width: 4cm, height: 3cm)\nOne\n#pagebreak()\nTwo %s\n#pagebreak()\nThree\n"
    write(main, text % "a")
    r.start(["--ignore-system-fonts"], "page-{p}.svg")
    r.step("initial compilation")
    times = {}

    def remember():
        for i in (1, 2, 3):
            times[i] = os.stat(os.path.join(r.dir, f"page-{i}.svg")).st_mtime_ns
        time.sleep(0.05)
        # (Replaced, not written in place: a compilation of the file while
        # it is empty would write other pages.)
        replace(main, text % "b")

    r.step("the second page changes", remember)
    for i in (1, 2, 3):
        path = os.path.join(r.dir, f"page-{i}.svg")
        rewritten = os.stat(path).st_mtime_ns != times[i]
        # Upstream exports the pages in parallel and fills its cache in the
        # order in which they finish, so it may write an unchanged page
        # again; the port exports them in order.
        if rewritten != (i == 2) and (i == 2 or r.name == "port"):
            r.problems.append(
                f"pages: page {i} was {'rewritten' if rewritten else 'not rewritten'}"
            )

    def remove_page():
        os.remove(os.path.join(r.dir, "page-3.svg"))
        replace(main, text % "c")

    r.step("an unchanged page whose file is gone is written again", remove_page)


def scenario_stdin(r):
    """Standard input cannot be watched."""
    r.start(["--ignore-system-fonts"], "out.svg", source="-")
    r.step("initial compilation", compare=False)


def scenario_html(r):
    """HTML export (without the HTTP server, which is not ported)."""
    main = os.path.join(r.dir, "main.typ")
    write(main, "= HTML\nText.\n")
    r.start(["--ignore-system-fonts", "--features", "html", "--no-serve"], "out.html",
            fresh_args=["--ignore-system-fonts", "--features", "html"])
    r.step("initial compilation", expect="compiled with warnings")
    r.step("a change", lambda: write(main, "= HTML\nOther text.\n"), expect="compiled with warnings")


PINNED = os.path.join(ROOT, "tests/recompile/upstream")


def scenario_pinned(name):
    """A sequence that is pinned to upstream's watch (`tests/recompile/
    README.md`, "As upstream's watch"): documents that compare modules,
    where a recompilation gives something else than a compilation from
    scratch, in upstream and here (a call that is found again returns the
    module of an earlier evaluation, and `==` tells it from the module of
    now). These are the only steps of this script at which the output of a
    recompilation is not compared with a fresh `typst compile`: it must be,
    byte for byte, the SVG that the fixture recorded from upstream's
    watching process (which is the fresh one where the two agree), and with
    the upstream binary at hand also what that writes now."""

    def scenario(r):
        with open(os.path.join(PINNED, name + ".json"), encoding="utf-8") as f:
            steps = json.load(f)["steps"]

        def write_files(step):
            for path, text in step["files"].items():
                write(os.path.join(r.dir, path), text.encode())
            for path, digits in step.get("binary", {}).items():
                write(os.path.join(r.dir, path), bytes.fromhex(digits))

        write_files(steps[0])
        r.start(["--ignore-system-fonts"], "out.svg")
        for i, step in enumerate(steps):
            if i == 0:
                r.step("initial compilation", compare=False)
            else:
                # Let the watcher see one change, not half of one.
                time.sleep(0.3)
                r.step(step["edit"], lambda step=step: write_files(step), compare=False)
            with open(os.path.join(r.dir, "out.svg"), encoding="utf-8") as f:
                produced = f.read()
            if produced != (step["watch"] or step["fresh"]):
                what = "upstream's watch" if step["watch"] else "a fresh compilation"
                r.problems.append(
                    f"step {i} ({step['edit']}): the page is not what {what} gives "
                    f"({PINNED}/{name}.json)"
                )
            # (For the comparison of the two binaries.)
            label, printed, _ = r.records[-1]
            r.records[-1] = (label, printed, produced.encode())

    return scenario


SCENARIOS = [
    ("main", scenario_main),
    ("data", scenario_data),
    ("links", scenario_links),
    ("linked", scenario_linked),
    ("fullscreen", scenario_fullscreen),
    ("missing", scenario_missing),
    ("pages", scenario_pages),
    ("stdin", scenario_stdin),
    ("html", scenario_html),
] + [
    ("pinned-" + entry[:-5], scenario_pinned(entry[:-5]))
    for entry in sorted(os.listdir(PINNED))
    if entry.endswith(".json")
]


def run_scenario(name, scenario, binaries, keep):
    """Runs a scenario for every binary; returns the problems."""
    problems = []
    runners = []
    for label, command in binaries:
        runner = Runner(label, command, keep)
        runner.dir = os.path.realpath(tempfile.mkdtemp(prefix=f"watch-{name}-{label}-"))
        try:
            scenario(runner)
        except Skip as skip:
            shutil.rmtree(runner.dir, ignore_errors=True)
            return None, [str(skip)]
        except Failure as failure:
            runner.problems.append(str(failure))
        finally:
            runner.finish()
        problems += [f"[{name}, {label}] {problem}" for problem in runner.problems]
        runners.append(runner)
    if len(runners) == 2:
        port, upstream = runners
        if [r[0] for r in port.records] == [r[0] for r in upstream.records]:
            for (step, printed, produced), (_, expected, reference) in zip(
                port.records, upstream.records
            ):
                if printed != expected:
                    problems.append(
                        f"[{name}] {step}: printed\n{printed.decode(errors='replace')}\n"
                        f"--- upstream printed\n{expected.decode(errors='replace')}"
                    )
                if produced is not None and reference is not None and produced != reference:
                    problems.append(f"[{name}] {step}: the output differs from upstream's")
        else:
            problems.append(f"[{name}] the runs took different steps")
    for runner in runners:
        if keep or problems:
            print(f"  kept {runner.dir}")
        else:
            shutil.rmtree(runner.dir, ignore_errors=True)
    steps = len(runners[0].records) if runners else 0
    return steps, problems


DURATION = re.compile(r"in ([0-9.]+) (ns|µs|ms|s)$")
MINUTES = re.compile(r"in (\d+) min ([0-9.]+) s$")


def seconds(status):
    m = MINUTES.search(status)
    if m:
        return int(m.group(1)) * 60 + float(m.group(2))
    m = DURATION.search(status)
    if not m:
        raise Failure(f"no duration in `{status}`")
    return float(m.group(1)) * {"ns": 1e-9, "µs": 1e-6, "ms": 1e-3, "s": 1.0}[m.group(2)]


def edit_replace(old, new):
    """An edit that replaces the first `old` by `new % n`."""

    def edit(text, n):
        if old not in text:
            raise Failure(f"`{old}` is not in the file")
        return text.replace(old, new % n, 1)

    return edit


def edit_end(text, n):
    return text + "x" * n + "\n"


def edit_comment(text, n):
    return text + "// " + "x" * n + "\n"


def edit_loop(text, n):
    """The body of the loop that makes every section of `bench/long.typ`
    and `longer.typ`: every heading changes."""
    return text.replace("== Section", "== Section" + "x" * n, 1)


PACKAGES = os.path.join(ROOT, ".repos/typst-packages/preview")


class BenchDocument:
    """A document of `--bench`: where its files are, its main file, and the
    edits that are measured: `end` (a character appended to the main file),
    `middle` (an edit in the middle of it), `imported` (a change of a file
    it imports or reads that reaches the pages) and `comment` (a comment
    appended to the main file: nothing on the pages changes). An edit is
    (file, function of the file's text and a number)."""

    def __init__(
        self, name, source, main, middle, imported=None, packages=False, everything=None
    ):
        self.name = name
        self.source = source
        self.main = main
        self.packages = packages
        # For `--bench-memory`: an edit that reaches every page (file,
        # function), if the document has one that the four above are not.
        self.everything = everything
        self.edits = {
            "end": (main, edit_end),
            "middle": (main, middle),
            "imported": imported,
            "comment": (main, edit_comment),
        }

    def prepare(self, directory):
        """Copies the document into `directory`; returns the arguments of
        `typst watch` besides the input and the output."""
        args = ["--no-fullscreen", "--ignore-system-fonts"]
        if callable(self.source):
            self.source(directory)
        elif os.path.isdir(self.source):
            shutil.copytree(self.source, directory, dirs_exist_ok=True)
        else:
            # A file of a directory of documents: its siblings are its data.
            for entry in os.listdir(os.path.dirname(self.source)):
                path = os.path.join(os.path.dirname(self.source), entry)
                if os.path.isfile(path) and (
                    not entry.endswith(".typ") or path == self.source
                ):
                    shutil.copy(path, directory)
        if self.packages:
            if not os.path.isdir(PACKAGES):
                raise Skip(f"{PACKAGES} is missing (scripts/packages.sh)")
            shutil.copytree(PACKAGES, os.path.join(directory, "packages/preview"))
            args += ["--package-path", "packages", "--package-cache-path", "packages"]
        return args


DECK = []


def make_deck(directory):
    """The image deck of `bench/mkdeck.py`, generated once per run."""
    if not DECK:
        DECK.append(tempfile.mkdtemp(prefix="watch-bench-deck-"))
        subprocess.run(
            [sys.executable, os.path.join(ROOT, "bench/mkdeck.py"), DECK[0]],
            check=True,
            stdout=subprocess.DEVNULL,
        )
    shutil.copytree(DECK[0], directory, dirs_exist_ok=True)


# The size of the text of `bench/long.typ` and `longer.typ`: every
# paragraph is laid out again.
PARAGRAPHS = edit_replace("size: 10.5pt)", "size: 10.5%dpt)")


def bench_documents():
    docs = os.path.join(ROOT, "tests/recompile/docs")
    packages = os.path.join(ROOT, "tests/packages/docs")
    return [
        BenchDocument(
            "long",
            os.path.join(ROOT, "bench/long.typ"),
            "long.typ",
            edit_loop,
            everything=("long.typ", PARAGRAPHS),
        ),
        BenchDocument(
            "longer",
            os.path.join(ROOT, "bench/longer.typ"),
            "longer.typ",
            edit_loop,
            everything=("longer.typ", PARAGRAPHS),
        ),
        BenchDocument(
            "showcase",
            os.path.join(ROOT, "bench/showcase.typ"),
            "showcase.typ",
            edit_replace("Maxwell's law,", "Maxwell's law %d,"),
            # A bibliography file: the title of an entry.
            imported=(
                "works.bib",
                edit_replace("title={At-scale impact", "title={At-scale%d impact"),
            ),
        ),
        BenchDocument(
            "touying",
            os.path.join(packages, "touying/theme-metropolis.typ"),
            "theme-metropolis.typ",
            edit_replace("Only on the second.", "Only on the second %d."),
            # A length of the theme that every slide uses.
            imported=(
                "packages/preview/touying/0.8.0/themes/metropolis.typ",
                edit_replace("set text(size: 0.8em)", "set text(size: 0.8%dem)"),
            ),
            packages=True,
        ),
        BenchDocument(
            "handbook",
            os.path.join(packages, "ilm/bakers-handbook.typ"),
            "bakers-handbook.typ",
            edit_replace("Every ingredient is expressed", "Every ingredient %d is expressed"),
            # The size of the running header of every page.
            imported=(
                "packages/preview/ilm/2.1.1/lib.typ",
                edit_replace("text(size: 0.68em", "text(size: 0.68%dem"),
            ),
            packages=True,
        ),
        BenchDocument(
            "book",
            os.path.join(docs, "book"),
            "main.typ",
            edit_replace("#outline()", "#outline()\n\nMiddle %d."),
            imported=("lib/shared.typ", edit_replace("block(inset: 4pt", "block(inset: 4.%dpt")),
        ),
        BenchDocument(
            "chain",
            os.path.join(docs, "chain"),
            "main.typ",
            edit_replace("The diamond says", "The diamond %d says"),
            imported=("d.typ", edit_replace("This is `d`, with", "This is `d` %d, with")),
        ),
        BenchDocument(
            "notes",
            os.path.join(docs, "notes"),
            "main.typ",
            edit_replace("As counted in @counting", "As counted %d in @counting"),
            imported=("style.typ", edit_replace("inset: 3pt,", "inset: 3.%dpt,")),
        ),
        BenchDocument(
            "linked",
            os.path.join(docs, "linked"),
            "main.typ",
            edit_replace("= A tiling of it, handed", "= A tiling of it %d, handed"),
        ),
        BenchDocument(
            "deck",
            make_deck,
            "deck.typ",
            edit_replace("step 7 of 14.", "step 7 of 14, %d."),
            # The size of the title of every slide.
            everything=("deck.typ", edit_replace("#text(size: 24pt,", "#text(size: 24.%dpt,")),
        ),
    ]


KINDS = ("end", "middle", "imported", "comment")


def rss_kb(pid):
    """The resident set size of a process in kilobytes."""
    out = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True)
    return int(out.stdout.strip() or 0)


def bench_session(document, command, edits, extra):
    """One watch session: the first compilation, then `edits` edits of
    every kind, each from the file as it was at first (the file is put back
    after a kind, which is a recompilation that is not measured). Returns
    the duration of the first compilation and the durations by kind."""
    directory = os.path.realpath(tempfile.mkdtemp(prefix="watch-bench-"))
    session = None
    try:
        args = document.prepare(directory)
        session = Session(command, [document.main, "out.pdf"] + args + extra, directory)
        session.wait_compiled(0, timeout=600, quiet=0.3)
        status = session.statuses(0)[-1]
        if "with errors" in status:
            raise Failure(f"{document.name}: {session.text(0).decode()}")
        first = seconds(status)
        following = {}
        for kind in KINDS:
            if document.edits[kind] is None:
                continue
            name, edit = document.edits[kind]
            path = os.path.join(directory, name)
            text = open(path, encoding="utf-8").read()
            following[kind] = []
            for i in range(edits):
                start = session.mark()
                write(path, edit(text, i + 1))
                session.wait_compiled(start, timeout=600, quiet=0.3)
                status = session.statuses(start)[-1]
                if "with errors" in status:
                    raise Failure(f"{document.name}, {kind}: {session.text(start).decode()}")
                following[kind].append(seconds(status))
            start = session.mark()
            write(path, text)
            session.wait_compiled(start, timeout=600, quiet=0.3)
        return first, following
    finally:
        if session is not None:
            session.stop()
        shutil.rmtree(directory, ignore_errors=True)


def bench(binaries, edits, extra, sessions=5, only=None, raw=None):
    """Times compilations in watch sessions: per document and binary the
    median of the first compilations of `sessions` sessions, and per kind
    of edit the median of all recompilations after it (`sessions` times
    `edits`), with the least and the most. The sessions of the binaries
    take turns."""
    documents = [d for d in bench_documents() if not only or d.name in only]
    results = {}
    for document in documents:
        for round_ in range(sessions):
            for label, command in binaries:
                own = extra if label == "upstream" else []
                try:
                    first, following = bench_session(document, command, edits, own)
                except Skip as e:
                    print(f"skip {document.name}: {e}", file=sys.stderr)
                    break
                entry = results.setdefault((document.name, label), ([], {}))
                entry[0].append(first)
                for kind, times in following.items():
                    entry[1].setdefault(kind, []).extend(times)
                log(document.name, label, round_, first, following)
                if raw:
                    with open(raw, "a") as f:
                        f.write(repr((document.name, label, round_, first, following)) + "\n")

    def ms(values):
        if not values:
            return "–"
        return "%.1f (%.1f–%.1f)" % (
            statistics.median(values) * 1000,
            min(values) * 1000,
            max(values) * 1000,
        )

    print("| document | binary | first | " + " | ".join(KINDS) + " |")
    print("| --- | --- | ---: |" + " ---: |" * len(KINDS))
    for document in documents:
        for label, _ in binaries:
            if (document.name, label) not in results:
                continue
            first, following = results[(document.name, label)]
            cells = [ms(following.get(kind, [])) for kind in KINDS]
            print(f"| {document.name} | {label} | {ms(first)} | " + " | ".join(cells) + " |")
    for directory in DECK:
        shutil.rmtree(directory, ignore_errors=True)


def bench_memory(binaries, extra, only, counts=(10, 50, 200)):
    """The resident set size of a watching process after its first
    compilation and after 10, 50 and 200 edits, and the greatest size seen
    after an edit, for three kinds of edits: at the end of the main file,
    in the middle of it (in `long` and `longer` every heading), and one
    that reaches everything (every paragraph of `long` and `longer`, every
    slide of the deck, the theme of a package: `everything`, or else the
    edit of an imported file)."""
    documents = [d for d in bench_documents() if d.name in (only or ["longer", "deck"])]
    print(
        "| document | edits | binary | first | "
        + " | ".join(f"after {n}" for n in counts)
        + " | peak |"
    )
    print("| --- | --- | --- | ---: |" + " ---: |" * (len(counts) + 1))
    for document in documents:
        kinds = [("at the end", document.edits["end"]), ("in the middle", document.edits["middle"])]
        reaching = document.everything or document.edits["imported"]
        if reaching is not None:
            kinds.append(("everything", reaching))
        for kind, (name, edit) in kinds:
            for label, command in binaries:
                own = extra if label == "upstream" else []
                directory = os.path.realpath(tempfile.mkdtemp(prefix="watch-bench-"))
                session = None
                try:
                    args = document.prepare(directory)
                    session = Session(command, [document.main, "out.pdf"] + args + own, directory)
                    session.wait_compiled(0, timeout=600, quiet=0.3)
                    pid = session.proc.pid
                    sizes = [rss_kb(pid)]
                    peak = sizes[0]
                    path = os.path.join(directory, name)
                    text = open(path, encoding="utf-8").read()
                    for i in range(max(counts)):
                        start = session.mark()
                        # (Every edit gives a text that the session has
                        # not had: nothing of an earlier step comes back.)
                        write(path, edit(text, i + 1))
                        session.wait_compiled(start, timeout=600, quiet=0.3)
                        status = session.statuses(start)[-1]
                        if "with errors" in status:
                            raise Failure(f"{document.name}, {kind}: {session.text(start).decode()}")
                        size = rss_kb(pid)
                        peak = max(peak, size)
                        if i + 1 in counts:
                            sizes.append(size)
                            log(document.name, kind, label, i + 1, size)
                    cells = " | ".join(f"{size / 1024:.0f} MB" for size in sizes)
                    print(
                        f"| {document.name} | {kind} | {label} | {cells} | {peak / 1024:.0f} MB |",
                        flush=True,
                    )
                finally:
                    if session is not None:
                        session.stop()
                    shutil.rmtree(directory, ignore_errors=True)
    for directory in DECK:
        shutil.rmtree(directory, ignore_errors=True)


def main():
    global VERBOSE
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--typst", default=None, help="the command of the CLI under test")
    parser.add_argument("--upstream", default=None, help="the upstream typst binary")
    parser.add_argument("--no-upstream", action="store_true")
    parser.add_argument("--only", action="append", help="run only this scenario")
    parser.add_argument("--bench", action="store_true", help="time compilations instead")
    parser.add_argument(
        "--edits", type=int, default=5, help="edits of a kind per --bench session"
    )
    parser.add_argument(
        "--sessions", type=int, default=5, help="sessions per document and binary"
    )
    parser.add_argument(
        "--document", action="append", help="a document of --bench (default: all)"
    )
    parser.add_argument(
        "--binary",
        action="append",
        default=[],
        metavar="LABEL=PATH",
        help="another build of the CLI to measure with --bench",
    )
    parser.add_argument("--raw", default=None, help="append every --bench session to this file")
    parser.add_argument(
        "--bench-memory",
        action="store_true",
        help="the resident set size after 10, 50 and 200 edits instead",
    )
    parser.add_argument(
        "--jobs", default=None, help="--jobs for --bench (upstream's threads; the port has one)"
    )
    parser.add_argument("--keep", action="store_true", help="keep the directories")
    parser.add_argument("-v", "--verbose", action="store_true")
    options = parser.parse_args()
    VERBOSE = options.verbose

    if options.typst is None:
        command = [os.path.join(ROOT, "_build/native/release/build/cli/cli.exe")]
    else:
        command = shlex.split(options.typst)
        command[0] = os.path.abspath(shutil.which(command[0]) or command[0])
        # A relative path to the wasm module of `moonrun`.
        command = [
            os.path.abspath(part) if part.endswith(".wasm") else part for part in command
        ]
    if not os.path.exists(command[0]):
        sys.exit(f"watch_check: {command[0]} does not exist (build the CLI first)")
    binaries = [("port", command)]
    global PORT
    PORT = command
    upstream = options.upstream or os.path.join(ROOT, ".repos/typst/target/release/typst")
    if not options.no_upstream:
        if os.path.exists(upstream):
            binaries.append(("upstream", [os.path.abspath(upstream)]))
        elif options.upstream:
            sys.exit(f"watch_check: {upstream} does not exist")
        else:
            print("watch_check: no upstream binary, checking the port alone")

    for item in options.binary:
        label, _, path = item.partition("=")
        last = len(binaries) - (binaries[-1][0] == "upstream")
        binaries.insert(last, (label, [os.path.abspath(path)]))
    jobs = ["--jobs", options.jobs] if options.jobs else []
    if options.bench_memory:
        bench_memory(binaries, jobs, options.document)
        return
    if options.bench:
        bench(binaries, options.edits, jobs, options.sessions, options.document, options.raw)
        return

    failed = False
    for name, scenario in SCENARIOS:
        if options.only and name not in options.only:
            continue
        steps, problems = run_scenario(name, scenario, binaries, options.keep)
        if steps is None:
            print(f"skip {name}: {problems[0]}")
        elif problems:
            failed = True
            print(f"FAIL {name}")
            for problem in problems:
                print("  " + problem.replace("\n", "\n    "))
        else:
            print(f"ok   {name} ({steps} steps)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
