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
  bindings). Field values are hashed as the field's type stores them: two
  spellings that cast to one value share a key, values that are equal but
  differ in their bits (negative zeros, NaNs) do not.
- `floats`: NaN values have the bits of Rust's `f64::NAN`, negated where
  upstream negates (`float("-nan")`, TOML's `-nan`).
- `closures`: functions compare by their inner representation, and a
  closure is an `Arc<LazyHash<Closure>>`: two closures are equal if their
  hashes are (syntax node, defaults, captured bindings), so one closure
  expression evaluated twice in the same environment gives equal functions.
  Upstream memoizes closure calls (`eval_closure`) on the hashes of the
  function and of the arguments: the second group pins that a repeated call
  is indistinguishable from an evaluation (results are values, arguments
  hash by their bits and types, calls in context see their location).
- `sharing`: the probes of `scripts/sharing_probes.py` (which see): a value
  that is handed out of storage (a state, a style, a field, a captured
  variable, a cached result, ...) is upstream's clone, so a mutation of it
  shows nowhere else.
- `memo`: documents where memoized closure calls are reused together with
  what they did besides returning a value: delayed errors, warnings at the
  spans of forwarded arguments, imports (the route queries of cached
  modules); these record the diagnostics too (`report`).
- `fields`: a field that upstream marks `#[external]` (the `body` of `text`
  and `page`, which is also `#[required]`) is documentation only: the
  element has no such field for `has`, `at` and field access.
- `packages`: reductions of what the `packages` stage found (documents that
  use real packages, tests/packages): each case is the engine behaviour a
  package relied on, without the package.

Usage: python3 scripts/gen_typst_oracle.py <path to upstream typst binary>
       (then `moon fmt`)
"""

import json
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sharing_probes  # noqa: E402

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

# (group: name, kind, source[, files]). `metadata`: the values of the
# document's metadata elements that are strings, in order. `title`: the
# document title. `report`: the diagnostics as the CLI prints them with
# `--diagnostic-format short`, then `--` and the metadata values if the
# document compiled. `files`: other files of the project.
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
// Symbols with the same accessible variants (and repr) that differ in the
// variants their modifiers have ruled out.
#let kept(..variants) = symbol(..variants, ("keep", "K")).keep
#check((kept(("a", "b\u{301}")), kept(("ab", "\u{301}")), kept(("a", "b\u{301}"))).map(s => [#box(metadata(s))<r>]))
#check((sym.plus, symbol("+"), $+$.body, sym.plus).map(s => [#box(metadata(s))<r>]))
#check((decimal("1.0"), decimal("1.00"), decimal("1.0")).map(s => [#box(metadata(s))<r>]))
// Durations below one second (the repr shows whole seconds).
#check((duration(seconds: 1) * 0.5, duration(seconds: 1) * 0.25, duration(seconds: 1) * 0.5, duration(seconds: 0)).map(s => [#box(metadata(s))<r>]))
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
    (
        "location keys: field values are hashed as they are cast",
        "metadata",
        KEYS
        + r"""// Field values that are spelled differently but cast to the same data.
#check((10pt, 10pt + 0%, 10pt + 0em, 10pt).map(s => [#rect(width: s)<r>]))
#check((1pt, stroke(1pt), (thickness: 1pt), 1pt + 0em, 1pt).map(s => [#rect(stroke: s)<r>]))
#check((5pt, (rest: 5pt), (x: 5pt, y: 5pt), (left: 5pt, rest: 5pt), 5pt + 0%, 5pt).map(s => [#rect(inset: s)<r>]))
#check((1pt, (rest: 1pt), (top: 1pt, bottom: 1pt), 1pt).map(s => [#rect(radius: s)<r>]))
#check((red, rgb("#ff4136"), rgb(255, 65, 54), red).map(s => [#rect(fill: s)<r>]))
#check((2, (auto, auto), (auto,) * 2, 2).map(s => [#grid(columns: s)<r>]))
#check((1pt, 1pt + 0%, 1pt).map(s => [#move(dx: s)[]<r>]))
#check((1em, 1em + 0pt, 1em).map(s => [#h(s)<r>]))
#check((100%, 100% + 0pt, 1fr, 100%).map(s => [#box(width: s)<r>]))
#check((90deg, 1.5707963267948966rad, 90.0deg, 90deg).map(s => [#rotate(s)[]<r>]))
#check((2, 2.0, 200%, 2).map(s => [#scale(x: s * 50%)[]<r>]))
#check(("1.", numbering.with("1."), "1.").map(s => [#heading(numbering: s)[]<r>]))
#check((3, 3.0).map(s => [#polygon.regular(vertices: 3, size: s * 1pt)<r>]))
#check(("https://a.b", "https://a.b").map(s => [#link(s)[]<r>]))
#check((1, 1.0, "1", 1).map(s => [#box(metadata(s))<r>]))
#check((left, start, left).map(s => [#align(s)[]<r>]))
#check(((x: 1pt), (left: 1pt, right: 1pt), (rest: 0pt, x: 1pt), (x: 1pt)).map(s => [#pad(..s)[]<r>]))
#check(((1pt, 2pt), (1pt + 0%, 2pt), (1pt, 2pt)).map(s => [#line(end: (1pt, 2pt), start: s)<r>]))
#check((0pt, 0pt + 0%, auto, 0pt).map(s => [#block(spacing: 1pt, above: s)[]<r>]))
#check((1, 1.0, 1).map(s => [#box(v(s * 1pt, weak: true))<r>]))
""",
    ),
    (
        "location keys: negative zeros and NaNs",
        "metadata",
        KEYS
        + r"""// Negative zeros: equal values with different bits.
#check((10pt, 10pt + -0%, 10pt - 0%, 10pt).map(s => [#rect(width: s)<r>]))
#check((0pt, -0pt, 0pt, 0em, -0em, 0pt).map(s => [#h(s)<r>]))
#check((0%, -0%, 0%).map(s => [#rect(width: s)<r>]))
#check((0deg, -0deg, 0deg).map(s => [#rotate(s)[]<r>]))
#check((0.0, -0.0, 0.0).map(s => [#box(metadata(s))<r>]))
#check((0fr, -0fr, 0fr).map(s => [#h(s)<r>]))
#check((10pt, 10pt + -0%, 10pt).map(s => [#grid(columns: (s,))[]<r>]))
#check((10pt, 10pt + -0%, 10pt).map(s => [#move(dx: s)[]<r>]))
#check((1pt, 1pt + -0em, 1pt).map(s => [#rect(stroke: s)<r>]))
#check((10pt, 10pt + -0%, 10pt).map(s => [#rect(inset: s)<r>]))
#check((10pt, 10pt + -0%, 10pt).map(s => [#rect(radius: s)<r>]))
#check((10pt, 10pt + -0%, 10pt).map(s => [#box(metadata(s))<r>]))
#check((rgb(0, 0, 0), rgb(-0%, 0%, 0%), rgb(0, 0, 0)).map(s => [#rect(fill: s)<r>]))
#check((float.nan, -float.nan, float.inf - float.inf, float.nan).map(s => [#box(metadata(s))<r>]))
""",
    ),
    (
        "floats: the bits of NaN values",
        "metadata",
        r"""#let b(x) = if type(x) == float { array(x.to-bytes(endian: "big")).map(v => str(v, base: 16)).join("") } else { repr(x) }
#let n = float.nan
#let row(..xs) = metadata(xs.pos().map(b).join(" "))
#row(float.nan, -float.nan, -n, float.inf - float.inf, 0.0 * float.inf, -(float.inf - float.inf))
#row(float("nan"), float("-nan"), float("+nan"), float("NaN"), float("-NaN"), float("NAN"))
#row(..yaml(bytes("[.nan, .NaN, .NAN, -.nan, +.nan, .inf, -.inf]")))
#row(..toml(bytes("a = [nan, -nan, +nan, inf, -inf]")).a)
#row(float.nan + 1, float.nan * -1, calc.abs(-float.nan), calc.pow(float.nan, 1), calc.abs(float.nan))
#row(float.nan * 1%, float.nan / 2, calc.ln(float.nan), calc.sin(float.nan), calc.rem(float.nan, 2))
#row(..cbor(cbor.encode((float.nan, -float.nan))))
#row(eval("float.nan"), eval("-float.nan"), eval("float.inf * 0", mode: "code"))
""",
    ),
    (
        "fields: an external field is not a field of the element",
        "metadata",
        r"""// `text` and `page` declare `#[external] #[required] body`: documentation
// only. Packages that walk content (touying's `shape-of`) rely on
// `has("body")` being false for a text element.
#let t = [hello]
#let s = [*x*]
#let h = heading[T]
#let r = raw("a")
#metadata(repr((t.func(), t.has("body"), t.has("text"), t.fields().keys(), t.at("body", default: "none"))))
#metadata(repr((s.has("body"), s.has("delta"), s.fields().keys())))
#metadata(repr((h.has("body"), h.has("level"), h.has("numbering"), h.fields().keys())))
#metadata(repr((r.has("text"), r.has("lang"), r.has("lines"), r.fields().keys())))
#metadata(repr((text(red)[a].func(), text(red)[a].has("body"), text(red)[a].has("child"))))
""",
    ),
    (
        "closures: functions are equal if their hashes are",
        "metadata",
        r"""#let row(..args) = metadata(repr(args.pos()))
#let f() = (x => x)
#let g(a) = (x => x + a)
#let h = f()
// One closure expression evaluated twice with the same captured values.
#row(f() == f(), g(1) == g(1), g(1) == g(2), g(1) == g(1.0), h == h, h == f())
// Two expressions with the same text are two syntax nodes.
#row((x => x) == (x => x), f() == (x => x))
#row(range(3).map(i => (x => x)).dedup().len(), range(3).map(i => (x => x + i)).dedup().len())
#row(range(4).map(i => (x => x + calc.rem(i, 2))).dedup().len(), range(4).map(i => { let j = calc.rem(i, 2); x => x + j }).dedup().len())
// Through values that hold functions.
#row(f().with(1) == f().with(1), f().with(1) == f().with(2), (f(),) == (f(),), (a: f()) == (a: f()), f() in (f(),))
#row((f(), g(1), f(), g(1), g(2)).dedup().len(), (f(), g(1)).position(x => x == g(1)))
// Named closures, defaults and context expressions.
#let k(a) = { let n(x, y: a) = x; n }
#let c() = context 1
#row(k(1) == k(1), k(1) == k(2), [#context 1] == [#context 1], c() == c())
// Captured functions and modules.
#let m(p) = (x => p(x))
#row(m(f()) == m(f()), m(g(1)) == m(g(2)), m(calc.abs) == m(calc.abs), m(calc.abs) == m(calc.max))
// Element and native functions compare as before.
#row(text == text, text == strong, calc.abs == calc.abs, text.with(red) == text.with(red))
// State and show rules see equal functions as equal values.
#let s = state("s", f())
#context row(s.get() == f(), s.final() == f())
""",
    ),
    (
        "closures: a repeated call gives an independent, equal result",
        "metadata",
        r"""#let row(..args) = metadata(repr(args.pos()))
// Upstream memoizes closure calls: the second call returns the value of
// the first. Values that are mutated afterwards are copies.
#let mk() = (1, 2)
#let a = mk()
#a.push(3)
#row(a, mk(), mk() == mk())
#let d() = (a: (1,), b: (c: 2))
#let x = d()
#x.a.push(2)
#x.b.c = 5
#x.insert("e", 1)
#row(x, d())
#let nest() = ((1,), (2,))
#let y = nest()
#y.at(0).push(9)
#row(y, nest())
// Arguments that the callee changes.
#let grow(v) = { v.push(0); v }
#let base = (1,)
#row(grow(base), grow(base), base)
#let put(v) = { v.k = 1; v }
#let dict = (j: 0)
#row(put(dict), put(dict), dict)
// The same call from one place, with equal and with different arguments.
#let sq(v) = v * v
#let rp(v) = repr(v)
#row(range(4).map(i => sq(calc.rem(i, 2))), (1, 1.0, 1).map(sq), (0.0, -0.0, 0, 0.0).map(rp), (1, 1.0, 100%, 1).map(rp))
// Calls that return functions and content.
#let adder(n) = (v => v + n)
#row((adder(1))(1), (adder(1))(2), adder(1) == adder(1), (adder(2))(1))
#let wrap(body) = [*#body*]
#row(wrap[a] == wrap[a], wrap[a] == wrap[b], wrap[a].body)
// Recursion and sinks.
#let fib(n) = if n < 2 { n } else { fib(n - 1) + fib(n - 2) }
#row(fib(20), fib(20))
#let all(..args) = args
#row(all(1, a: 2), all(1, a: 2) == all(1, a: 2), all(1, a: 2).pos(), all(..(1, 2), ..(b: 3)).named())
// Counters and state read in context: every call sees its own location.
#let c = counter("c")
#let show-c() = context row(c.get(), c.final())
#show-c()
#c.step()
#show-c()
#c.step()
#show-c()
#let st = state("st", 0)
#let bump() = st.update(v => v + 1)
#let read() = context row(st.get(), st.final())
#read() #bump() #read() #bump() #read()
""",
    ),
    (
        "packages: a float without an alignment keeps the vertical alignment of its content",
        "metadata",
        r"""// charged-ieee: a table in `figure(placement: auto)`. The body of a float
// is laid out with `Alignment::CENTER` if its alignment is `auto`
// (`PlacedChild::layout`), which is horizontal only: boxes and cells keep
// the inherited vertical alignment.
#set page(width: 200pt, height: 200pt, margin: 20pt)
#let at(label) = context metadata(repr(locate(label).position()))
#let mark(name) = box(width: 6pt, height: 6pt)[#metadata(name)#label(name)]
#place(auto, float: true, box(width: 60pt, height: 40pt, mark("a")))
#place(top, float: true, box(width: 60pt, height: 40pt, mark("b")))
#place(auto, float: true, grid(columns: 2, mark("c"), box(width: 6pt, height: 30pt)))
#[
  #set align(bottom)
  #place(auto, float: true, box(width: 60pt, height: 40pt, mark("d")))
  #place(auto, float: true, table(columns: 2, mark("e"), box(width: 6pt, height: 30pt)))
]
#at(<a>) #at(<b>) #at(<c>) #at(<d>) #at(<e>)
""",
    ),
    (
        "packages: the text of the predefined math operators",
        "metadata",
        r"""// mitex: `\limsup` is `math.limsup`, whose text has a thin space (U+2009),
// like `math.liminf` (`ops!` in typst-library/src/math/op.rs).
#let ops = dictionary(math).pairs().filter(((_, v)) => type(v) == content and v.func() == math.op)
#metadata(repr(ops.len()))
#for (name, v) in ops {
  metadata(repr((name, v.text.text.codepoints().map(str.to-unicode), v.limits)))
}
""",
    ),
]

MEMO_LIB = r"""#let load(p) = { import p as m; m.v }
#let warnfont(font) = text(font: font)[x]
#let width(b) = measure(b).width
"""

CASES += [
    (
        "memo: a reused call with a delayed error that goes away",
        "report",
        r"""// The first layout finds no target: the show rule fails inside the
// measurement, which the closure call keeps as a delayed error. The second
// layout must not reuse that call.
#let probe(b) = measure(b).width
#show strong: it => box(width: query(<target>).first().value.first(), height: 1pt)
#context metadata(repr((probe([*x*]), probe([*x*]))))
#context metadata(repr(range(3).map(i => probe([*x*]))))
#metadata((10pt,)) <target>
""",
    ),
    (
        "memo: a reused call with a delayed error that stays",
        "report",
        r"""#let probe(b) = measure(b).width
#show strong: it => panic("no")
#context metadata(repr((probe([*x*]), probe([*x*]))))
#context metadata(repr(range(3).map(i => probe([*x*]))))
""",
    ),
    (
        "memo: reused calls with warnings, forwarded arguments, imports and delayed errors",
        "report",
        r"""#import "lib.typ": load, warnfont, width
#show strong: it => box(width: query(<target>).first().value.first(), height: 1pt)
// The second call is reused; `c.typ` reuses it from another route.
#let both = ("a.typ", "a.typ").map(load)
#import "c.typ": again
// Forwarded arguments: the warning is the callee's, once per message.
#let fw(..args) = warnfont(..args)
#fw("Nope") #fw("Nope")
#(1, 2).map(i => fw("Nope2")).join()
#(1, 2).map(i => fw(..("Nope3",))).join()
#context metadata(repr((width([*x*]), width([*x*]), both, again)))
// A deprecation warning at the access inside the function.
#let deprecated(v) = { let x = sym.prec.curly.eq; v }
#metadata(repr((1, 1, 2).map(deprecated)))
#metadata((10pt,)) <target>
""",
        {
            "lib.typ": MEMO_LIB,
            "a.typ": '#import "b.typ": w\n#let v = (w, w)\n',
            "b.typ": "#let w = (1, 2)\n",
            "c.typ": '#import "lib.typ": load\n#let again = ("a.typ",).map(load)\n',
        },
    ),
    (
        "memo: a cyclic import through a reused function",
        "report",
        r"""#import "lib.typ": load
#let once = ("a.typ", "a.typ").map(load)
#metadata(repr(once))
#import "d.typ": v
""",
        {
            "lib.typ": MEMO_LIB,
            "a.typ": '#import "b.typ": w\n#let v = (w, w)\n',
            "b.typ": "#let w = (1, 2)\n",
            "d.typ": '#import "lib.typ": load\n#let v = ("a.typ", "d.typ").map(load)\n',
        },
    ),
    (
        "memo: modules of plugins without functions",
        "metadata",
        r"""// Two plugins that export their memory and nothing else: their modules
// are equal in everything but their identity. (Not recorded here: upstream
// takes one for the other as the argument of a memoized call,
// `(pa, pb).map(m => m == pa)` is `(true, true)` there and `(true, false)`
// in the port.)
#let wasm(pages) = bytes((0, 97, 115, 109, 1, 0, 0, 0, 5, 3, 1, 0, pages, 7, 10, 1, 6, 109, 101, 109, 111, 114, 121, 2, 0))
#let pa = plugin(wasm(1))
#let pb = plugin(wasm(2))
#let row(..args) = metadata(repr(args.pos()))
#row(pa == pb, pa == pa, pa == plugin(wasm(1)), pb == plugin(wasm(2)), pa, dictionary(pa))
#row((pa, pb, pa).dedup().len(), (pa, pb).contains(pb), (pa,).contains(pb), (a: pa) == (a: pb))
#let is-a(m) = m == pa
#row(is-a(pa), is-a(pb))
#let s = state("plugins", pa)
#s.update(pb)
#context row(s.get() == pb, s.get() == pa, s.final() == pb)
#metadata((pa,)) <first>
#metadata((pb,)) <second>
#context row(query(<first>).first().value.first() == pa, query(<second>).first().value.first() == pa, query(<second>).first().value.first() == pb)
#let captured() = pa
#let other() = pb
#row(captured() == pa, other() == pa, captured == other, captured == captured)
#context row(measure(box(width: if query(<second>).first().value.first() == pb { 10pt } else { 20pt })).width)
""",
    ),
]
CASES += sharing_probes.cases()


def run(binary, args):
    out = subprocess.run([binary, *args], capture_output=True, text=True, stdin=subprocess.DEVNULL)
    assert out.returncode == 0, (args, out.stderr)
    return out.stdout


def upstream(binary, kind, source, files):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "main.typ")
        for name, text in {**files, "main.typ": source}.items():
            with open(os.path.join(tmp, name), "w", encoding="utf-8", newline="") as f:
                f.write(text)
        if kind == "metadata":
            values = json.loads(run(binary, ["query", "--root", tmp, path, "metadata", "--field", "value"]))
            # The other metadata elements are the documents' own.
            return [v for v in values if isinstance(v, str)]
        if kind == "report":
            # From the directory, so that the diagnostics name the files as
            # the test world does.
            out = subprocess.run(
                [binary, "query", "--root", ".", "--diagnostic-format", "short", "main.typ", "metadata",
                 "--field", "value"],
                capture_output=True, text=True, stdin=subprocess.DEVNULL, cwd=tmp)
            lines = out.stderr.split("\n")
            while lines and lines[-1] == "":
                lines.pop()
            # The notice about `typst query` itself.
            notice = [i for i, line in enumerate(lines) if "`typst query` subcommand is deprecated" in line]
            assert len(notice) == 1, lines
            del lines[notice[0]:notice[0] + 2]
            assert all(line and not line.startswith(" ") for line in lines), lines
            if out.returncode == 0:
                lines.append("--")
                lines += [v for v in json.loads(out.stdout) if isinstance(v, str)]
            return lines
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


def source_literal(text):
    """A source as a MoonBit string: a literal, or the lines of a multi-line
    string if it is long (a literal has to fit a line)."""
    plain = literal(text)
    printable = all(ch == "\n" or 0x20 <= ord(ch) <= 0x7E for ch in text)
    if len(plain) < 8000 or not printable or not text.endswith("\n"):
        return plain
    # The lines are joined by newlines: the last, empty one ends the text.
    lines = text.split("\n")
    return "\n" + "".join(f"    #|{line}\n" for line in lines).rstrip("\n")


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
        "// and by `eval`; the keys of located elements in measurement; the\n"
        "// reductions of what the `packages` stage found (tests/packages);\n"
        "// closure equality, memoized calls and the sharing of values\n"
        "// (`scripts/sharing_probes.py`). The helpers are in\n"
        "// `oracle_helpers_wbtest.mbt`.\n"
    ]
    for case in CASES:
        name, kind, source = case[:3]
        files = case[3] if len(case) > 3 else {}
        expected = upstream(binary, kind, source, files)
        body = [f"///|\ntest {literal('oracle: ' + name)} {{\n"]
        body.append(f"  let source = {source_literal(source)}\n")
        args = "source"
        if files:
            body.append("  let files = [\n")
            for path, text in files.items():
                body.append(f"    ({literal(path)}, {literal(text)}),\n")
            body.append("  ]\n")
            args = "source, files~"
        if kind in ("metadata", "report"):
            body.append("  let expected = [\n")
            for value in expected:
                body.append(f"    {literal(value)},\n")
            body.append("  ]\n")
            body.append(f"  assert_eq(oracle_{kind}({args}), expected)\n")
        else:
            body.append(f"  assert_eq(oracle_title(source), Some({literal(expected[0])}))\n")
        body.append("}\n")
        out.append("".join(body))
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"{len(CASES)} cases -> {OUT}")


if __name__ == "__main__":
    main()
