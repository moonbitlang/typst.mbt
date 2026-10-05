#!/usr/bin/env python3
"""Generates `typst/oracle_wbtest.mbt`: what upstream Typst reports for
documents that are not in its test suite.

The cases record observations from an upstream `typst` binary built from
the pinned revision (`cargo build --release -p typst-cli` in
`.repos/typst`): every case is a document whose `metadata` elements hold
strings (`repr`s), queried with `typst query`; the `title` cases record the
document title of the HTML export (the plain text of the title's content).

- `raw`: raw text built by markup, by the `raw` function and by `eval`. The
  evaluator stores the lines of raw syntax (`RawContent::Lines`, each with
  the span of its syntax node), the `raw` function a string
  (`RawContent::Text`). The two differ in what a document can observe: a
  raw without lines (` `` `) has no line while `raw("")` has one, and two
  raws compare by their lines.
- `location keys`: the key of a located element is the hash of the element
  including its span (`prepare` in typst-realize, `Hash for RawContent`).
  Measurement resolves the location of an element by its key
  (`Introspector::locator`): elements that are equal including their spans
  (one expression laid out twice) share a key and are told apart by their
  order, elements that differ in their spans only do not.
  Upstream's `Hash` covers all data of a value; the cases about values pin
  that for those whose fingerprints (`library/value_hash.mbt`,
  `library/visualize_hash.mbt`) were once written through their `repr`:
  strokes, gradients, tilings (upstream hashes the laid-out frame), colours
  and the other dynamic values, and closures (syntax tree, captured
  bindings).

Usage: python3 scripts/gen_typst_oracle.py <path to upstream typst binary>
       (then `moon fmt`)
"""

import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "typst", "oracle_wbtest.mbt")

# The preamble of the `location keys` cases about values. `check` measures
# its items, lays them out after one step of the counter each and measures
# them again. The width of an item is the value of the counter at its
# location: items with keys of their own report 10pt, 20pt, 30pt, .., items
# that share a key report the same width. Every list ends with a copy of its
# first item, which shares its key.
KEYS = r"""#set page(width: 200pt, height: auto)
#let c = counter("c")
#let width(body) = context metadata(repr(measure(body).width))
#let probe(it) = context box(width: c.at(it.location()).first() * 10pt, height: 1pt)
#show <r>: probe
#let check(items) = {
  c.update(0)
  for item in items { width(item) }
  for item in items { c.step(); item }
  for item in items { width(item) }
}
"""

# (group: name, kind, source). `metadata`: the values of the document's metadata
# elements, in order (all strings). `title`: the document title.
CASES = [
    (
        "raw: lines of markup, function and eval forms",
        "metadata",
        r"""#show raw: it => metadata(repr((it.text, it.block, it.lines.len(), it.lines.map(l => (l.number, l.count, l.text)))))
// Markup: without lines, with one empty line, with text.
``
``` ```
```
```
```

```
`a`
```
a
b
```
`a	b`
// The function: a string, split into lines.
#raw("")
#raw("a\nb")
#raw("\n")
#raw("a\tb")
#raw("a\u{2028}b\r\nc")
// Markup in an evaluated string: lines, with the span of the string.
#eval("``", mode: "markup")
#eval("``` ```", mode: "markup")
#eval("```\n```", mode: "markup")
#eval("```\n\n```", mode: "markup")
#eval("```\na\nb\n```", mode: "markup")
#eval("``", mode: "code")
#eval("`a\tb`", mode: "markup")
#eval("[``]")
""",
    ),
    (
        "raw: equality is by lines, or by text against a string",
        "metadata",
        r"""#let e0 = ``
#let e1 = ``` ```
#let b0 = ```
```
#let b1 = ```

```
#let test(..args) = metadata(repr(args.pos()))
// A raw without lines and a raw with one empty line have the same text.
#test(b0.text, b1.text, b0.block, b1.block)
#test(e0 == e1, b0 == b1, b1 == b1, b0 == b0)
#test(e0 == raw("", block: false), b0 == raw("", block: true), b1 == raw("", block: true))
#test(raw("", block: true) == b0, raw("", block: true) == b1)
#test(eval("``") == e0, eval("```\n```") == b0, eval("```\n```") == b1)
#test(eval("```\n\n```") == b1, eval("```\n\n```") == b0)
#test(`a` == `a`, `a` == `b`, `a` == raw("a", block: false), `a` == raw("a"))
#test((b0,).contains(b1), (b1,).contains(b1), (b0, b1).dedup().len())
#test((b0, b1).position(x => x == b1), (a: b0) == (a: b1), (a: b0) == (a: b0))
#test([#b0] == [#b1], [#b0 a] == [#b1 a], [#b1 a] == [#b1 a])
""",
    ),
    (
        "raw: the text field is a string",
        "metadata",
        r"""#let a = `abc`
#let b = ```py
x = 1
	y = 2
```
#let c = ```


```
#let d = ``
#let info(it) = metadata(repr((
  it.text,
  it.text.len(),
  it.text + "!",
  type(it.text),
  it.at("text"),
  it.fields(),
  it,
  it.has("text"),
  it == raw(it.text, block: it.block, ..if it.has("lang") { (lang: it.lang) }),
  it.text.split("\n"),
  str(it.text),
  json.encode(it.text),
  "x" in it.text,
)))
#info(a)
#info(b)
#info(c)
#info(d)

// Selectors compare the text.
#show raw.where(text: "abc"): it => metadata(repr(("where abc", it.lines.len())))
#show raw.where(text: ""): it => metadata(repr(("where empty", it.lines.len())))
#show raw.where(text: "\n"): it => metadata(repr(("where newline", it.lines.len())))
`abc` #raw("abc") `` #raw("") #c #eval("`abc`", mode: "markup")

// Values that hold raw content.
#let s = state("s", ``)
#context metadata(repr(("state", s.get() == ``, s.get() == d, s.get().text, s.get())))
#metadata(repr(("array", (a, b).contains(`abc`), (c,).contains(``), (a, d).map(x => x.text))))
#metadata(repr(("math", $`x` + #a$.body.children)))
#metadata(repr(("join", (a + d).children.map(x => x.text), [#a#d].children.len())))
""",
    ),
    (
        "raw: lines of highlighted and tabbed raw",
        "metadata",
        r"""#show raw.line: it => metadata(repr((it.number, it.count, it.text, it.body)))
```py
x = 1
	y = 2
```
```typ
= A
*b*
```
#raw("= A\n*b*", lang: "typ")
#eval("```typ\n= A\n*b*\n```", mode: "markup")
""",
    ),
    (
        "raw: plain text of raw content",
        "title",
        r"""#set document(title: [a `b` c ```
x
y
``` d #raw("e\nf") g `` h])
""",
    ),
    (
        "location keys: measurement finds an element by its key and order",
        "metadata",
        r"""#set page(width: 200pt, height: auto)
#let c = counter("c")
#let width(body) = context metadata(repr(measure(body).width))
// The width of a probe is the value of the counter where it is.
#let probe = context box(width: c.get().first() * 10pt, height: 1pt)
// One expression laid out twice: the two probes are equal including their
// spans, so they share their key, and a measured probe is the closest one
// after the measurement.
#width(probe)
#c.step()
#probe
#width(probe)
#c.step()
#probe
#width(probe)
// Two expressions: probes that differ in their spans only have keys of
// their own, and a measured one is itself wherever it is measured.
#let first = context box(width: c.get().first() * 10pt, height: 1pt)
#let second = context box(width: c.get().first() * 10pt, height: 1pt)
#width(first)
#width(second)
#c.step()
#first
#width(first)
#width(second)
#c.step()
#second
#width(first)
#width(second)
// A probe that is not in the document is measured where the measurement is.
#c.step()
#width(context box(width: c.get().first() * 10pt, height: 1pt))
""",
    ),
    (
        "location keys: the element's own location in measurement",
        "metadata",
        r"""#set page(width: 200pt, height: auto)
#let c = counter("c")
#let width(body) = context metadata(repr(measure(body).width))
// The width of a probe is the value of the counter at the location of the
// element that the show rule replaces.
#let probe(it) = context box(width: c.at(it.location()).first() * 10pt, height: 1pt)
// Raw text: two literals with the same text are two elements.
#show raw: probe
#let a = `x`
#let b = `x`
#width(a)
#width(b)
#c.step()
#a
#width(a)
#width(b)
#c.step()
#b
#width(a)
#width(b)
// One literal laid out twice is the closest one after the measurement.
#c.step()
#a
#width(a)
// Labelled text is located: two words that differ in their spans only,
// and one word twice.
#show <w>: probe
#let u = [word<w>]
#let v = [word<w>]
#width(u)
#width(v)
#c.step()
#u
#width(u)
#width(v)
#c.step()
#v
#width(u)
#width(v)
#c.step()
#u
#width(u)
#width(v)
// Elements of one expression in a loop.
#show emph: probe
#let items = range(3).map(i => emph[item])
#width(items.at(0))
#for item in items {
  c.step()
  item
  width(item)
}
""",
    ),
    (
        "location keys: strokes",
        "metadata",
        KEYS
        + r"""// Thickness, dash array, dash phase and miter limit beyond the digits of
// the repr.
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#rect(stroke: s)<r>]))
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#rect(stroke: (dash: (s, 2pt)))<r>]))
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#rect(stroke: (dash: (array: (1pt, 2pt), phase: s)))<r>]))
#check((1.001, 1.002, 1.001).map(s => [#rect(stroke: (miter-limit: s))<r>]))
#check((1.001em, 1.002em, 1.001em).map(s => [#rect(stroke: s + 1pt)<r>]))
// The paint, the cap and the join.
#check((red, blue, red).map(s => [#rect(stroke: s)<r>]))
#check(("butt", "round", "square", "butt").map(s => [#rect(stroke: (cap: s))<r>]))
#check(("miter", "round", "bevel", "miter").map(s => [#rect(stroke: (join: s))<r>]))
#check((auto, none, "dotted", auto).map(s => [#rect(stroke: (dash: s))<r>]))
// Strokes in other elements: lines, the resolved lines of a table, and a
// stroke as a value.
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#line(stroke: s)<r>]))
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#table(stroke: s)[]<r>]))
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#box(metadata(stroke(s)))<r>]))
""",
    ),
    (
        "location keys: gradients",
        "metadata",
        KEYS
        + r"""// Stops beyond the digits of the repr: offsets and colours.
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: gradient.linear((red, 0%), (blue, s), (green, 100%)))<r>]))
#check((10.0001%, 10.0002%, 10.0001%).map(s => [#rect(fill: gradient.linear(red, oklab(s, 0, 0)))<r>]))
// Angles, centers and radii.
#check((10.001deg, 10.002deg, 10.001deg).map(s => [#rect(fill: gradient.linear(red, blue, angle: s))<r>]))
#check((10.001deg, 10.002deg, 10.001deg).map(s => [#rect(fill: gradient.conic(red, blue, angle: s))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: gradient.conic(red, blue, center: (s, 50%)))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: gradient.radial(red, blue, center: (50%, s)))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: gradient.radial(red, blue, radius: s))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: gradient.radial(red, blue, focal-center: (s, 50%)))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: gradient.radial(red, blue, focal-radius: s))<r>]))
// The kind, the colour space and the relative placement.
#check((gradient.linear, gradient.radial, gradient.conic, gradient.linear).map(s => [#rect(fill: s(red, blue))<r>]))
#check((oklab, rgb, color.hsl, oklab).map(s => [#rect(fill: gradient.linear(red, blue, space: s))<r>]))
#check((auto, "self", "parent", auto).map(s => [#rect(fill: gradient.linear(red, blue, relative: s))<r>]))
// Sharp gradients, and a gradient as the paint of a stroke.
#check((2, 3, 2).map(s => [#rect(fill: gradient.linear(red, blue).sharp(s))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(stroke: gradient.linear((red, 0%), (blue, s), (green, 100%)))<r>]))
""",
    ),
    (
        "location keys: tilings",
        "metadata",
        KEYS
        + r"""// Tilings of the same size over different frames: fills, strokes and
// geometry of the shapes, nested paints and groups.
#check((red, blue, green, red).map(s => [#rect(fill: tiling(size: (10pt, 10pt), square(size: 5pt, fill: s)))<r>]))
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#rect(fill: tiling(size: (10pt, 10pt), line(length: 5pt, stroke: s)))<r>]))
#check((4.001pt, 4.002pt, 4.001pt).map(s => [#rect(fill: tiling(size: (10pt, 10pt), square(size: s)))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: tiling(size: (10pt, 10pt), square(size: 5pt, fill: gradient.radial((red, 0%), (blue, s), (green, 100%)))))<r>]))
#check((red, blue, red).map(s => [#rect(fill: tiling(size: (10pt, 10pt), square(size: 5pt, fill: tiling(size: (2pt, 2pt), square(size: 1pt, fill: s)))))<r>]))
#check((10.001deg, 10.002deg, 10.001deg).map(s => [#rect(fill: tiling(size: (10pt, 10pt), rotate(s, square(size: 5pt))))<r>]))
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#rect(fill: tiling(size: (10pt, 10pt), move(dx: s, square(size: 5pt))))<r>]))
#check((true, false, true).map(s => [#rect(fill: tiling(size: (10pt, 10pt), box(width: 4pt, height: 4pt, clip: s, square(size: 5pt))))<r>]))
// The spacing and the relative placement.
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#rect(fill: tiling(size: (10pt, 10pt), spacing: (s, 1pt), square(size: 5pt)))<r>]))
#check((auto, "self", "parent", auto).map(s => [#rect(fill: tiling(size: (10pt, 10pt), relative: s, square(size: 5pt)))<r>]))
// A tiling as the paint of a stroke, and as a value.
#check((red, blue, red).map(s => [#rect(stroke: tiling(size: (10pt, 10pt), square(size: 5pt, fill: s)))<r>]))
#check((red, blue, red).map(s => [#box(metadata(tiling(size: (10pt, 10pt), square(size: 5pt, fill: s))))<r>]))
""",
    ),
    (
        "location keys: colours and other dynamic values",
        "metadata",
        KEYS
        + r"""// Colours hash their components: sRGB colours that are equal (they compare
// with 8 bits per channel) have keys of their own.
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: rgb(s, 0%, 0%))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: luma(s))<r>]))
#check((10.0001%, 10.0002%, 10.0001%).map(s => [#rect(fill: oklab(s, 0, 0))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: cmyk(s, 0%, 0%, 0%))<r>]))
#check((rgb, color.linear-rgb, rgb).map(s => [#rect(fill: s(10%, 20%, 30%))<r>]))
#check((color.hsl, color.hsv, color.hsl).map(s => [#rect(fill: s(10deg, 20%, 30%))<r>]))
// Spot colours and colorants.
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: color.spot("A", cmyk(s, 0%, 0%, 0%)).tint(50%))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#rect(fill: color.spot("A", cmyk(0%, 0%, 0%, 100%)).tint(s))<r>]))
#check(("A", "B", "A").map(s => [#rect(fill: color.spot(s, cmyk(0%, 0%, 0%, 100%)).tint(50%))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#box(metadata(color.spot("A", cmyk(s, 0%, 0%, 0%))))<r>]))
// Paths.
#check(("a.typ", "b.typ", "a.typ").map(s => [#box(metadata(path(s)))<r>]))
""",
    ),
    (
        "location keys: closures",
        "metadata",
        KEYS
        + r"""// Captured values.
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#box(metadata(() => stroke(s)))<r>]))
#check((10.001%, 10.002%, 10.001%).map(s => [#box(metadata(() => gradient.linear((red, 0%), (blue, s), (green, 100%))))<r>]))
#check((1, 1.0, 1).map(s => [#box(metadata(() => s))<r>]))
// Captured modules.
#check((std, calc, sym, std).map(s => [#box(metadata(() => s))<r>]))
#check((std, calc, sym, std).map(s => [#box(metadata(s))<r>]))
// Default values of named parameters.
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#box(metadata((x: stroke(s)) => x))<r>]))
// Context expressions.
#check((1.001pt, 1.002pt, 1.001pt).map(s => [#box(context stroke(s))<r>]))
// The syntax tree: the nodes of an evaluated string have the span of the
// call, and a closure is hashed with its tree. The list in the content
// block of the first closure is nested (its marker is to the left of the
// second one); in the other two it is not, and they are the same tree at
// different offsets of their strings.
#let code(s) = eval(s, mode: "code")
#check((
  "(x => [- a\n          - b])",
  "     (x => [- a\n          - b])",
  "         (x => [- a\n          - b])",
  "(x => [- a\n          - b])",
).map(s => [#box(metadata(code(s)))<r>]))
// Closures with the same text in different strings of one call.
#check(("(x => x, 1)", "(x => x, 2)", "(x => x, 1)").map(s => [#box(metadata(code(s).first()))<r>]))
#check(("(x => x)", "(x => y)", "(x => x)").map(s => [#box(metadata(code(s)))<r>]))
""",
    ),
    (
        "location keys: other values",
        "metadata",
        KEYS
        + r"""// Symbols (with their variants), decimals (with their scale), durations
// and datetimes.
#check((sym.arrow.r, symbol("→"), sym.arrow, sym.arrow.r, symbol("→", ("r", "→")), symbol("→")).map(s => [#box(metadata(s))<r>]))
#check((decimal("1.0"), decimal("1.00"), decimal("1.0")).map(s => [#box(metadata(s))<r>]))
#check((duration(seconds: 1), duration(seconds: 2), duration(seconds: 1), duration(minutes: 1), duration(seconds: 60)).map(s => [#box(metadata(s))<r>]))
#check((datetime(year: 2020, month: 1, day: 1), datetime(year: 2020, month: 1, day: 1, hour: 0, minute: 0, second: 0), datetime(year: 2020, month: 1, day: 1)).map(s => [#box(metadata(s))<r>]))
// Alignments, directions, regular expressions, versions, bytes and labels.
#check((left, start, left + top, left, ltr, rtl, ltr).map(s => [#box(metadata(s))<r>]))
#check((regex("a"), regex("b"), regex("a"), version(1, 0), version(1), version(1, 0)).map(s => [#box(metadata(s))<r>]))
#check((bytes("a"), bytes("b"), bytes("a"), "a", <a>, <b>, <a>).map(s => [#box(metadata(s))<r>]))
// Lengths, relative lengths and fractions.
#check((1em, 1.00001em, 1em, 1pt + 1em, 50% + 1pt, 50.00001% + 1pt, 50% + 1pt, 1fr, 1.00001fr, 1fr).map(s => [#box(metadata(s))<r>]))
// Arguments, dictionaries, types, functions, selectors, counters, states.
#check((arguments(1, a: 2), arguments(1, a: 3), arguments(1, a: 2), (a: 1), (a: 1, b: 2), (a: 1)).map(s => [#box(metadata(s))<r>]))
#check((int, float, int, rect, circle, rect, calc.pow, calc.sin, calc.pow, rect.with(width: 1pt), rect.with(width: 2pt), rect.with(width: 1pt)).map(s => [#box(metadata(s))<r>]))
#check((heading.where(level: 1), heading.where(level: 2), heading.where(level: 1), counter("a"), counter("b"), counter("a"), state("a", 1), state("a", 2), state("a", 1)).map(s => [#box(metadata(s))<r>]))
""",
    ),
]


def run(binary, args):
    out = subprocess.run([binary, *args], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    assert out.returncode == 0, (args, out.stderr)
    return out.stdout


def upstream(binary, kind, source):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "main.typ")
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write(source)
        if kind == "metadata":
            values = json.loads(run(binary, ["query", "--root", tmp, path, "metadata", "--field", "value"]))
            assert all(isinstance(v, str) for v in values), values
            return values
        html = os.path.join(tmp, "main.html")
        run(binary, ["compile", "--root", tmp, "--features", "html", "--format", "html", path, html])
        with open(html, encoding="utf-8") as f:
            found = re.search(r"<title>(.*?)</title>", f.read(), re.S)
        assert found is not None
        title = found.group(1)
        assert "&" not in title, title
        return [title]


def literal(text):
    out = ['"']
    for ch in text:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20 or ord(ch) > 0x7E:
            out.append("\\u{%x}" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    binary = sys.argv[1]
    version = run(binary, ["--version"]).strip()
    out = [
        "// Generated by scripts/gen_typst_oracle.py from the upstream binary\n"
        f"// ({version}). DO NOT EDIT.\n"
        "//\n"
        "// What upstream reports for documents that are not in its test suite:\n"
        "// raw text built by markup (lines), by the `raw` function (a string)\n"
        "// and by `eval`; the keys of located elements in measurement. The\n"
        "// helpers are in `oracle_helpers_wbtest.mbt`.\n"
    ]
    for name, kind, source in CASES:
        expected = upstream(binary, kind, source)
        body = [f"///|\ntest {literal('oracle: ' + name)} {{\n"]
        body.append(f"  let source = {literal(source)}\n")
        if kind == "metadata":
            body.append("  let expected = [\n")
            for value in expected:
                body.append(f"    {literal(value)},\n")
            body.append("  ]\n")
            body.append("  assert_eq(oracle_metadata(source), expected)\n")
        else:
            body.append(f"  assert_eq(oracle_title(source), Some({literal(expected[0])}))\n")
        body.append("}\n")
        out.append("".join(body))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"{len(CASES)} cases -> {OUT}")


if __name__ == "__main__":
    main()
