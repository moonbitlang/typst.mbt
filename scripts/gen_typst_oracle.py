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
