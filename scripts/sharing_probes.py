#!/usr/bin/env python3
"""Probes of the value-sharing discipline: does a mutation through one path
show through another?

Upstream's values are reference counted and copied on write, so a container
that a function hands out of storage (a state, an element field, a style, a
captured variable, a cached result, ...) is a clone: mutating it changes
nothing else. The port's arrays and dictionaries are mutable objects with a
`shared` flag (`Value::shared`): whatever hands a container out of storage
that outlives the expression must set it, where upstream clones.

A probe evaluates an expression `E` that yields a container from such a
source and tries to change what it got, in three ways:

- direct: a native mutator called as a function on the temporary,
  `(array.pop)(E)`, `(array.push)(E, 0)`, `(dictionary.insert)(E, "zz", 0)`,
  `(dictionary.remove)(E, key)`, also on the containers inside it
  (`E.at(0)`, `E.d.k`, ...);
- place: the value is stored with a native method and changed through the
  variable, `let x = (); x.push(E); x.at(0).push(0)`;
- call: the same as direct on `get()` for `let get() = E` (closure calls are
  memoized).

After each it writes `repr(E)` (and the other holders of the value) into a
`metadata` element, and once more at the end of the document. Upstream
never shows a change; `scripts/gen_typst_oracle.py` records what it says in
`typst/oracle_wbtest.mbt` (the `sharing` cases, compiled with memoization
on and off).

    python3 scripts/sharing_probes.py <upstream typst> <port cli> [filter]

runs every source on its own with both programs and prints a verdict per
source (the oracle cases group them, so one failure can hide another).
"""

import json
import os
import subprocess
import sys
import tempfile

# The payloads. They are written into the sources as literals: a value read
# from a variable is already marked shared.
ARR = "((1, 2), (k: (3,)))"
DICT = "(a: (1, 2), d: (k: (3,)))"

# Shapes: the containers of a value as (suffix, kind, key, place). `kind` is
# `A` (array) or `D` (dictionary, `key` is one of its keys or None); `place`
# says whether the suffix is a chain of accessors (usable on the left of a
# mutating method call).
A = [("", "A", None, True)]
A0 = [("", "A0", None, True)]
D = [("", "D", None, True)]


def d_key(key):
    return [("", "D", key, True)]


AA = [
    ("", "A", None, True),
    (".at(0)", "A", None, True),
    (".first()", "A", None, True),
    (".at(1)", "D", "k", True),
    (".last()", "D", "k", True),
    (".at(1).k", "A", None, True),
    ('.last().at("k")', "A", None, True),
    (".at(1).values().first()", "A", None, False),
    (".slice(0, 1).first()", "A", None, False),
]
DD = [
    ("", "D", "a", True),
    (".a", "A", None, True),
    ('.at("a")', "A", None, True),
    (".d", "D", "k", True),
    (".d.k", "A", None, True),
    (".values().first()", "A", None, False),
    (".pairs().first().last()", "A", None, False),
    (".values().last().k", "A", None, False),
]


def nested(prefix, shape):
    """`shape` below the accessor chain `prefix`."""
    return [(prefix + s, k, key, place) for (s, k, key, place) in shape]


def path(e, suffix):
    """The container at `suffix` of the expression `e`."""
    if not suffix:
        return e
    simple = all(c.isalnum() or c in "-_.()<>\"" for c in e) and " " not in e
    return (e if simple else f"({e})") + suffix


def direct(e, shape):
    # Removals first: in an array that is changed in place they are not
    # undone by the additions after them.
    out = []
    for suffix, kind, key, _ in shape:
        p = path(e, suffix)
        if kind == "A":
            out += [
                f"let _ = (array.pop)({p})",
                f"let _ = (array.push)({p}, 0)",
            ]
        elif kind == "A0":
            # An array that may be empty.
            out.append(f"let _ = (array.push)({p}, 0)")
        else:
            out.append(f'let _ = (dictionary.insert)({p}, "zz", 0)')
            if key is not None:
                out.append(f'let _ = (dictionary.remove)({p}, "{key}")')
    return out


def place(e, shape):
    out = []
    for suffix, kind, key, ok in shape:
        if not ok:
            continue
        if kind == "A":
            out.append(f"{{ let pv = (); pv.push({e}); let _ = pv.at(0){suffix}.pop() }}")
            out.append(f"{{ let pv = (); pv.push({e}); pv.at(0){suffix}.push(0) }}")
        elif kind == "A0":
            out.append(f"{{ let pv = (); pv.push({e}); pv.at(0){suffix}.push(0) }}")
        else:
            out.append(f'{{ let pv = (); pv.push({e}); pv.at(0){suffix}.insert("zz", 0) }}')
            if key is not None:
                out.append(f'{{ let pv = (); pv.push({e}); let _ = pv.at(0){suffix}.remove("{key}") }}')
    return out


class Source:
    """One source of container values.

    `pre`: markup before the probes; `expr`: the expression; `shape`: its
    containers; `ctx`: whether it needs `context`; `also`: other expressions
    that hold the value; `clone`: where upstream clones; `files`: other
    files of the project; `body`: a whole document instead of the generated
    probes (for sources that are not an expression).
    """

    def __init__(self, name, expr=None, shape=None, pre="", ctx=False, also=(), clone="",
                 files=None, body=None, call=True, top=False):
        self.name = name
        self.expr = expr
        self.shape = shape
        self.pre = pre
        self.ctx = ctx
        self.also = list(also)
        self.clone = clone
        self.files = files or {}
        self.body = body
        self.call = call
        # Whether the document cannot be put into a content block (set rules
        # of the document).
        self.top = top

    def document(self):
        if self.body is not None:
            return self.pre + self.body
        e = self.expr
        ctx = "context " if self.ctx else ""
        reads = [e] + self.also
        read = "metadata(repr((" + ", ".join(reads) + ",)))"
        lines = [self.pre.rstrip("\n")] if self.pre else []

        def block(statements, read):
            lines.append("#" + ctx + "{")
            lines.extend("  " + s for s in statements)
            lines.append("  " + read)
            lines.append("}")

        block(direct(e, self.shape), read)
        block(place(e, self.shape), read)
        if self.call:
            lines.append(f"#let get() = {e}")
            reads_call = ["get()"] + self.also
            read_call = "metadata(repr((" + ", ".join(reads_call) + ",)))"
            block(direct("get()", self.shape), read_call)
        lines.append("#" + ctx + read)
        return "\n".join(lines) + "\n"


def state_sources():
    out = []
    clone = "state.rs: `State::at_loc`/`final_` clone the stop of the sequence, `sequence` the initial value"
    for payload, shape, tag in ((ARR, AA, "array"), (DICT, DD, "dictionary")):
        for read in ("get()", "at(here())", "final()"):
            name = read.split("(")[0]
            out.append(Source(
                f"state: initial {tag} through {name}",
                pre=f'#let s = state("s-init-{tag}-{name}", {payload})',
                expr=f"s.{read}", shape=shape, ctx=True, clone=clone))
            out.append(Source(
                f"state: {tag} set by an update through {name}",
                pre=f'#let s = state("s-set-{tag}-{name}", 0)\n#s.update({payload})',
                expr=f"s.{read}", shape=shape, ctx=True, clone=clone))
            out.append(Source(
                f"state: {tag} returned by an update function through {name}",
                pre=f'#let s = state("s-fn-{tag}-{name}", 0)\n#s.update(v => {payload})',
                expr=f"s.{read}", shape=shape, ctx=True, clone=clone))
    out.append(Source(
        "state: an update function that returns its argument",
        pre=f'#let s = state("s-id", {ARR})\n#s.update(v => v)\n#s.update(v => {{ v.at(0).push(7); v }})',
        expr="s.final()",
        shape=[("", "A", None, True), (".at(0)", "A", None, True), (".at(1)", "D", "k", True)],
        ctx=True, also=["s.get()"], clone=clone))
    out.append(Source(
        "state: a native function as the update",
        clone="state.rs `sequence_impl`: `stops.push(current.clone())`",
        body="""#let s = state("s-native", (2, 1))
// A new array that only the sequence holds, then a native mutator as the
// update function.
#s.update(array.rev)
#metadata(none) <s-native-before>
#s.update(array.pop)
#s.update(v => (v, (3, 4)))
#metadata(none) <s-native-mid>
#s.update(array.last)
#s.update(array.pop)
#context metadata(repr((s.at(<s-native-before>), s.at(<s-native-mid>), s.final(), s.get())))
#context metadata(repr((s.at(<s-native-before>), s.at(<s-native-mid>), s.final())))
"""))
    out.append(Source(
        "state: made by a closure that is called twice",
        pre=f'#let make() = state("s-made", {ARR})',
        expr="make().final()", shape=AA, ctx=True, also=["make().get()"], clone=clone))
    out.append(Source(
        "state: captured by a closure",
        pre=f'#let s = state("s-captured", {DICT})\n#let read() = s.final()',
        expr="read()", shape=DD, ctx=True, also=["s.get()"], clone=clone))
    out.append(Source(
        "state: the reviewer's case",
        pre='#let make() = state("s-review", (1, 2))',
        body="\n#context metadata(repr(range(2).map(i => (array.pop)(make().final()))))\n"
             "#context metadata(repr(make().final()))\n",
        clone=clone))
    return out


def counter_sources():
    clone = "counter.rs: `CounterState` is converted to a new array (`IntoValue`)"
    out = []
    for read in ("get()", "at(here())", "final()"):
        name = read.split("(")[0]
        out.append(Source(
            f"counter: custom counter through {name}",
            pre=f'#let c = counter("c-{name}")\n#c.update((1, 2))',
            expr=f"c.{read}", shape=A, ctx=True, clone=clone))
    out.append(Source(
        "counter: headings and pages",
        pre="#set heading(numbering: \"1.1\")\n= A\n== B",
        expr="counter(heading).get()", shape=A, ctx=True,
        also=["counter(heading).final()", "counter(page).get()", "counter(page).final()"], clone=clone))
    out.append(Source(
        "counter: the page counter",
        expr="counter(page).get()", shape=A, ctx=True, clone=clone))
    return out


def element_sources():
    clone = "content/raw.rs, element macro: a field access converts or clones the stored field (`IntoValue`)"
    out = [
        Source("element: children of a sequence", pre="#let it = [a *b* c]",
               expr="it.children", shape=A, clone=clone),
        Source("element: `at` of a sequence", pre="#let it = [a *b* c]",
               expr='it.at("children")', shape=A, clone=clone),
        Source("element: `fields()` of a sequence", pre="#let it = [a *b* c]",
               expr="it.fields()", shape=d_key("children") + [(".children", "A", None, True)],
               clone=clone),
        Source("element: the value of metadata", pre=f"#let m = metadata({ARR})",
               expr="m.value", shape=AA, clone=clone),
        Source("element: the value of metadata, dictionary", pre=f"#let m = metadata({DICT})",
               expr="m.value", shape=DD, clone=clone),
        Source("element: `at` of metadata", pre=f"#let m = metadata({ARR})",
               expr='m.at("value")', shape=AA, clone=clone),
        Source("element: `at` of metadata with a default", pre=f"#let m = metadata({ARR})\n#let dflt = {ARR}",
               expr='m.at("nothing", default: dflt)', shape=AA, also=["dflt"], clone=clone),
        Source("element: `fields()` of metadata", pre=f"#let m = metadata({ARR})",
               expr="m.fields()", shape=d_key("value") + nested(".value", AA), also=["m.value"],
               clone=clone),
        Source("element: metadata found by a query", pre=f"#metadata({ARR}) <probe-m>",
               expr="query(<probe-m>).first().value", shape=AA, ctx=True,
               also=["query(<probe-m>).first().fields().value"], clone=clone),
        Source("element: the result of a query", pre=f"#metadata({ARR}) <probe-q>",
               expr="query(<probe-q>)", shape=A, ctx=True, clone="foundations/query: a new array"),
        Source("element: table fields",
               pre="#let t = table(columns: (1fr, 2fr), align: (left, right), [a], [b])",
               expr="t.columns", shape=A, also=["t.children.len()", "t.align"], clone=clone),
        Source("element: table children",
               pre="#let t = table(columns: (1fr, 2fr), [a], [b])",
               expr="t.children", shape=A, also=["t.columns"], clone=clone),
        Source("element: table alignment and fill",
               pre="#let t = table(columns: 2, align: (left, right), fill: (red, blue), [a], [b])",
               expr="t.align", shape=A, also=["t.fill"], clone=clone),
        Source("element: table fill", pre="#let t = table(columns: 2, fill: (red, blue), [a], [b])",
               expr="t.fill", shape=A, clone=clone),
        Source("element: `fields()` of a table",
               pre="#let t = table(columns: (1fr, 2fr), [a], [b])",
               expr="t.fields()",
               shape=d_key("columns") + [(".columns", "A", None, True), (".children", "A", None, True)],
               also=["t.columns", "t.children.len()"], clone=clone),
        Source("element: grid tracks",
               pre="#let g = grid(columns: (1fr, 2fr), rows: (auto, 1em), column-gutter: (1pt, 2pt), [a], [b])",
               expr="g.columns", shape=A, also=["g.rows", "g.column-gutter", "g.children.len()"],
               clone=clone),
        Source("element: grid rows",
               pre="#let g = grid(columns: (1fr, 2fr), rows: (auto, 1em), column-gutter: (1pt, 2pt), [a], [b])",
               expr="g.rows", shape=A, also=["g.column-gutter"], clone=clone),
        Source("element: grid gutter",
               pre="#let g = grid(columns: 2, column-gutter: (1pt, 2pt), row-gutter: (3pt,), [a], [b])",
               expr="g.column-gutter", shape=A, also=["g.row-gutter"], clone=clone),
        Source("element: sides of a block",
               pre="#let b = block(inset: (x: 1pt), outset: (top: 2pt), radius: (top-left: 3pt), stroke: (left: 1pt))[a]",
               expr="b.inset", shape=D, also=["b.outset", "b.radius", "b.stroke"], clone=clone),
        Source("element: outset of a block",
               pre="#let b = block(inset: (x: 1pt), outset: (top: 2pt), radius: (top-left: 3pt))[a]",
               expr="b.outset", shape=D, also=["b.radius"], clone=clone),
        Source("element: radius and stroke of a rect",
               pre="#let r = rect(radius: (top-left: 3pt), stroke: (left: 1pt))",
               expr="r.radius", shape=D, also=["r.stroke"], clone=clone),
        Source("element: stroke of a rect",
               pre="#let r = rect(stroke: (left: 1pt, rest: 2pt))",
               expr="r.stroke", shape=D, clone=clone),
        Source("element: children of a stack and an enum",
               pre="#let s = stack([a], [b])\n#let e = enum([a], [b])",
               expr="s.children", shape=A, also=["e.children"], clone=clone),
        Source("element: children of an enum", pre="#let e = enum([a], [b])",
               expr="e.children", shape=A, clone=clone),
        Source("element: children of a list", pre="#let l = list([a], [b])",
               expr="l.children", shape=A, clone=clone),
        Source("element: children of terms", pre="#let t = terms(terms.item[a][b], terms.item[c][d])",
               expr="t.children", shape=A, clone=clone),
        Source("element: rows of a matrix", pre="#let m = math.mat((1, 2), (3, 4))",
               expr="m.rows", shape=[("", "A", None, True), (".at(0)", "A", None, True)], clone=clone),
        Source("element: children of a vector", pre="#let v = math.vec($1$, $2$)",
               expr="v.children", shape=A, clone=clone),
        Source("element: vertices of a polygon", pre="#let p = polygon((0pt, 0pt), (1pt, 2pt))",
               expr="p.vertices", shape=[("", "A", None, True), (".at(0)", "A", None, True)], clone=clone),
        Source("element: `fields()` of a heading and a figure",
               pre="#let h = heading(level: 2)[T]\n#let f = figure([x], caption: [c])",
               expr="h.fields()", shape=d_key("level"), also=["f.fields().keys()"], clone=clone),
        Source("element: fields in a show rule, used twice", clone=clone, body=f"""#show table: it => {{
  let _ = (array.pop)(it.children)
  let _ = (array.pop)(it.columns)
  let _ = (array.push)(it.align, center)
  let _ = (dictionary.insert)(it.fields(), "zz", 0)
  let _ = (array.pop)(it.fields().children)
  let _ = (array.pop)(it.at("columns"))
  {{ let x = (); x.push(it.columns); let _ = x.at(0).pop() }}
  metadata(repr((it.children.len(), it.columns, it.align, it.fields().keys().len())))
  it
}}
#show metadata.where(label: <probe-show>): it => {{
  let _ = (array.pop)(it.value)
  let _ = (array.pop)(it.value.at(0))
  let _ = (dictionary.insert)(it.value.at(1), "zz", 0)
  let _ = (array.pop)(it.fields().value)
  metadata(repr(it.value))
  it
}}
#table(columns: (1fr, 2fr), align: (left, right), [a], [b])
#metadata({ARR}) <probe-show>
#context metadata(repr((query(table).first().children.len(), query(table).first().columns, query(table).first().align, query(<probe-show>).first().value)))
"""),
        Source("element: raw lines in a show rule", clone=clone, body="""#show raw: it => {
  let _ = (array.pop)(it.lines)
  let _ = (array.push)(it.lines, 0)
  let _ = (dictionary.insert)(it.fields(), "zz", 0)
  let _ = (array.pop)(it.fields().lines)
  { let x = (); x.push(it.lines); let _ = x.at(0).pop() }
  metadata(repr((it.lines.len(), it.lines.map(l => l.text), it.fields().keys().len())))
  it
}
#show raw.line: it => {
  let _ = (dictionary.insert)(it.fields(), "zz", 0)
  metadata(repr((it.number, it.count, it.fields().keys().len())))
  it
}
```
a
b
```
"""),
    ]
    return out


def style_sources():
    clone = "element macro, `Element::settable_field_accessor`: the resolved style is converted or cloned (`IntoValue`)"

    def s(name, rule, expr, shape, also=(), top=False):
        return Source("style: " + name, pre=rule, expr=expr, shape=shape, ctx=True, also=also,
                      clone=clone, top=top)

    return [
        s("text.font", '#set text(font: ("Libertinus Serif", "New Computer Modern"))', "text.font", A),
        s("text.font with coverage",
          '#set text(font: ((name: "Libertinus Serif", covers: "latin-in-cjk"), "New Computer Modern"))',
          "text.font", [("", "A", None, True), (".at(0)", "D", "name", True)]),
        s("text.font, the default", "", "text.font", []),
        s("text.features", '#set text(features: ("smcp", "c2sc"))', "text.features", D),
        s("text.features as a dictionary", '#set text(features: (smcp: 1, liga: 0))', "text.features", D),
        s("text.features, the default", "", "text.features", D),
        s("text.stylistic-set", "#set text(stylistic-set: (1, 2))", "text.stylistic-set", A),
        s("text.stylistic-set, the default", "", "text.stylistic-set", A0),
        s("text.costs", "#set text(costs: (hyphenation: 50%))", "text.costs", d_key("hyphenation")),
        s("text.costs, the default", "", "text.costs", d_key("hyphenation")),
        s("par.first-line-indent", "#set par(first-line-indent: (amount: 1em, all: true))",
          "par.first-line-indent", d_key("amount")),
        s("table.columns and its other tracks",
          "#set table(columns: (1fr, 2fr), rows: (auto,), align: (left, right), fill: (red, blue), inset: (x: 1pt), stroke: (top: 1pt))",
          "table.columns", A, also=["table.rows", "table.align", "table.fill", "table.inset", "table.stroke"]),
        s("table.align", "#set table(align: (left, right), fill: (red, blue))", "table.align", A,
          also=["table.fill"]),
        s("table.fill", "#set table(fill: (red, blue))", "table.fill", A),
        s("table.inset", "#set table(inset: (x: 1pt))", "table.inset", D),
        s("table.stroke", "#set table(stroke: (top: 1pt))", "table.stroke", D),
        s("table.columns, the default", "", "table.columns", A0,
          also=["table.rows", "table.inset", "table.column-gutter"]),
        s("grid tracks", "#set grid(columns: (1fr, 2fr), rows: (auto, 1em), column-gutter: (1pt, 2pt), row-gutter: (3pt,))",
          "grid.columns", A, also=["grid.rows", "grid.column-gutter", "grid.row-gutter"]),
        s("grid.rows", "#set grid(rows: (auto, 1em), column-gutter: (1pt, 2pt))", "grid.rows", A,
          also=["grid.column-gutter"]),
        s("grid.column-gutter", "#set grid(column-gutter: (1pt, 2pt))", "grid.column-gutter", A),
        s("page.margin", "#set page(margin: (x: 1cm, y: 2cm))", "page.margin", D),
        s("page.margin, the default", "", "page.margin", [], also=["page.columns"]),
        s("rect sides", "#set rect(stroke: (top: 1pt), inset: (x: 1pt), radius: (top-left: 1pt), outset: (y: 2pt))",
          "rect.stroke", D, also=["rect.inset", "rect.radius", "rect.outset"]),
        s("rect.inset", "#set rect(inset: (x: 1pt), radius: (top-left: 1pt), outset: (y: 2pt))",
          "rect.inset", D, also=["rect.radius", "rect.outset"]),
        s("rect.radius", "#set rect(radius: (top-left: 1pt))", "rect.radius", D),
        s("rect.inset, the default", "", "rect.inset", [], also=["rect.outset", "rect.radius"]),
        s("block and box sides", "#set block(inset: (x: 1pt))\n#set box(inset: (y: 1pt))", "block.inset", D,
          also=["box.inset"]),
        s("box.inset", "#set box(inset: (y: 1pt))", "box.inset", D),
        s("table.cell.inset", "#set table.cell(inset: (x: 1pt))", "table.cell.inset", D),
        s("list.marker", "#set list(marker: ([a], [b]))", "list.marker", A),
        s("list.marker, the default", "", "list.marker", A),
        s("smartquote.quotes", '#set smartquote(quotes: (single: ("a", "b"), double: ("c", "d")))',
          "smartquote.quotes", d_key("single") + [(".single", "A", None, True)]),
        s("math.mat.delim", '#set math.mat(delim: ("[", "]"))', "math.mat.delim", A),
        s("math.mat.augment", "#set math.mat(augment: (hline: (1, 2), vline: 1))", "math.mat.augment",
          d_key("hline") + [(".hline", "A", None, True)]),
        s("raw.syntaxes, the default", "", "raw.syntaxes", A0),
        s("enum.numbering and start", '#set enum(numbering: "(a)", start: 3)', "enum.numbering", [],
          also=["enum.start"]),
        s("document.author and keywords", '#set document(author: ("a", "b"), keywords: ("k", "l"))',
          "document.author", A, also=["document.keywords"], top=True),
        s("the reviewer's case", '#set text(font: ("Libertinus Serif", "New Computer Modern"))\n#let f() = (array.pop)(text.font)',
          "(range(2).map(i => f()), text.font)", []),
    ]


def function_sources():
    out = [
        Source("function: the default of a named parameter", pre=f"#let f(x: {ARR}) = x",
               expr="f()", shape=AA, clone="call.rs `eval_closure`: `default.clone()`"),
        Source("function: the default of a named parameter, dictionary", pre=f"#let f(x: {DICT}) = x",
               expr="f()", shape=DD, clone="call.rs `eval_closure`: `default.clone()`"),
        Source("function: a pre-applied positional argument", pre=f"#let f(x) = x\n#let g = f.with({ARR})",
               expr="g()", shape=AA, clone="func.rs `Func::call`: the pre-applied `Args` are cloned"),
        Source("function: a pre-applied named argument", pre=f"#let f(x: none) = x\n#let g = f.with(x: {DICT})",
               expr="g()", shape=DD, clone="func.rs `Func::call`: the pre-applied `Args` are cloned"),
        Source("function: a pre-applied argument of a native function",
               pre=f"#let g = array.rev.with({ARR})\n#let h = array.first.with({ARR})\n#let k = dictionary.at.with({DICT})",
               expr="h()", shape=A, also=["g()", 'k("a")'],
               clone="func.rs `Func::call`: the pre-applied `Args` are cloned"),
        Source("function: a pre-applied argument through a sink",
               pre=f"#let f(..a) = a.pos()\n#let g = f.with({ARR})",
               expr="g()", shape=[("", "A", None, True)] + nested(".at(0)", AA),
               clone="func.rs `Func::call`: the pre-applied `Args` are cloned"),
        Source("function: a captured variable", pre=f"#let xs = {ARR}\n#let f() = xs",
               expr="f()", shape=AA, also=["xs"], clone="scope.rs `Binding::read`, `Eval for Ident`: `.cloned()`"),
        Source("function: a captured variable, dictionary", pre=f"#let xs = {DICT}\n#let f() = xs",
               expr="f()", shape=DD, also=["xs"], clone="scope.rs `Binding::read`, `Eval for Ident`: `.cloned()`"),
        Source("function: a parameter captured by a returned closure",
               pre=f"#let mk(v) = () => v\n#let f = mk({ARR})",
               expr="f()", shape=AA, clone="`Eval for Ident`: `.cloned()`"),
        Source("function: a literal built by a closure called twice", pre=f"#let load() = {ARR}",
               expr="load()", shape=AA, clone="`eval_closure` is memoized: comemo clones the output"),
        Source("function: a dictionary built by a closure called twice", pre=f"#let load() = {DICT}",
               expr="load()", shape=DD, clone="`eval_closure` is memoized: comemo clones the output"),
        Source("function: a nested result of a closure called twice",
               pre=f"#let load() = (v: {ARR}, w: ({DICT},))",
               expr="load()", shape=d_key("v") + nested(".v", AA) + nested(".w.at(0)", DD),
               clone="`eval_closure` is memoized: comemo clones the output"),
        Source("function: a variable captured by a context expression",
               pre=f"#let xs = {ARR}", expr="xs", shape=AA, ctx=True, clone="`Eval for Ident`: `.cloned()`"),
        Source("function: the scope of an evaluated string",
               clone="foundations/mod.rs `eval`: the scope dictionary is consumed (a clone of its values)",
               body=f"""#let d = (x: (1, 2), y: (k: (3,)))
#let r = eval("x.push(9); y.k.push(9); y.insert(\\"zz\\", 0); (x, y)", scope: d)
#metadata(repr((r, d)))
#let r = eval("x.at(0).push(9); x", scope: (x: d.values()))
#metadata(repr((r, d)))
#let r = eval("#x.push(9)#y.insert(\\"zz\\", 0)#metadata(repr((x, y)))", scope: d, mode: "markup")
#r
#metadata(repr(d))
#let st = state("f-eval", (v: (1, 2), w: {ARR}))
#context metadata(repr((eval("v.push(9); w.at(0).push(9); (v, w)", scope: st.get()), st.get(), st.final())))
#set text(costs: (hyphenation: 50%))
#context metadata(repr((eval("c.insert(\\"zz\\", 0); c", scope: (c: text.costs)), text.costs)))
#let m = metadata((v: {ARR}))
#metadata(repr((eval("v.at(0).push(9); v.at(1).k.push(9); v", scope: m.value), m.value)))
#let mk() = (v: {ARR})
#metadata(repr(range(2).map(i => eval("v.at(0).push(9); v.push(9); v", scope: mk()))))
#metadata(repr(mk()))
"""),
        Source("function: the value of an evaluated string", pre=f"#let xs = {ARR}",
               expr='eval("x", scope: (x: xs))', shape=AA, also=["xs", 'eval("(x, x)", scope: (x: xs))'],
               clone="`Eval for Ident`: `.cloned()`"),
    ]
    return out


def module_sources():
    files = {"a.typ": f"#let xs = {ARR}\n#let d = {DICT}\n#let get() = xs\n"}
    clone = "module.rs `Module::field`: `.cloned()`; scope.rs `Binding::read`"
    return [
        Source("module: a variable of an imported file", pre='#import "a.typ" as m',
               expr="m.xs", shape=AA, also=["m.d"], files=files, clone=clone),
        Source("module: a dictionary of an imported file", pre='#import "a.typ" as m',
               expr="m.d", shape=DD, also=["m.xs"], files=files, clone=clone),
        Source("module: an imported item", pre='#import "a.typ": xs, d, get',
               expr="xs", shape=AA, also=["d", "get()"], files=files, clone=clone),
        Source("module: a function of an imported file", pre='#import "a.typ" as m',
               expr="m.get()", shape=AA, also=["m.xs"], files=files, clone=clone),
        Source("module: the module as a dictionary", pre='#import "a.typ" as m',
               expr="dictionary(m)", shape=d_key("xs") + nested(".xs", AA) + nested(".d", DD),
               also=["m.xs", "m.d"], files=files, clone="dict.rs `Dict::construct`: `value.clone()`"),
        Source("module: a wildcard import", pre='#import "a.typ": *',
               expr="d", shape=DD, also=["xs"], files=files, clone=clone),
        Source("module: sys.inputs", expr="sys.inputs", shape=D, also=["dictionary(sys).inputs", "std.sys.inputs"],
               clone=clone),
        Source("module: sys as a dictionary", expr="dictionary(sys).inputs", shape=D, also=["sys.inputs"],
               clone="dict.rs `Dict::construct`: `value.clone()`"),
    ]


def arguments_sources():
    clone = "args.rs `Args::to_pos`/`to_named`/`at`: `.clone()`"
    return [
        Source("arguments: positional values", pre=f"#let a = arguments({ARR}, 5, k: {DICT})",
               expr="a.pos()", shape=[("", "A", None, True)] + nested(".at(0)", AA), clone=clone),
        Source("arguments: named values", pre=f"#let a = arguments({ARR}, 5, k: {DICT})",
               expr="a.named()", shape=d_key("k") + nested(".k", DD), clone=clone),
        Source("arguments: `at` with an index", pre=f"#let a = arguments({ARR}, 5, k: {DICT})",
               expr="a.at(0)", shape=AA, clone=clone),
        Source("arguments: `at` with a name and field access", pre=f"#let a = arguments({ARR}, 5, k: {DICT})",
               expr='a.at("k")', shape=DD, also=["a.k"], clone=clone),
        Source("arguments: a named field", pre=f"#let a = arguments({ARR}, 5, k: {DICT})",
               expr="a.k", shape=DD, clone=clone),
        Source("arguments: `at` with a default", pre=f"#let a = arguments(1)\n#let dflt = {ARR}",
               expr="a.at(5, default: dflt)", shape=AA, also=["dflt"], clone=clone),
        Source("arguments: the sink of a function", clone=clone, body=f"""#let f(..a) = {{
  let _ = (array.push)(a.pos(), 0)
  let _ = (array.pop)(a.pos().at(0))
  let _ = (array.pop)(a.at(0))
  let _ = (array.pop)(a.at(0).at(0))
  let _ = (dictionary.insert)(a.named(), "zz", 0)
  let _ = (dictionary.insert)(a.named().k, "zz", 0)
  let _ = (array.pop)(a.at("k").a)
  let _ = (array.pop)(a.k.a)
  {{ let x = (); x.push(a.at(0)); let _ = x.at(0).at(0).pop() }}
  {{ let x = (); x.push(a.pos()); let _ = x.at(0).at(0).pop() }}
  {{ let x = (); x.push(a.named()); let _ = x.at(0).k.a.pop() }}
  (a.pos(), a.named())
}}
#let xs = {ARR}
#let d = {DICT}
#metadata(repr(f({ARR}, k: {DICT})))
#metadata(repr(f({ARR}, k: {DICT})))
#metadata(repr((f(xs, k: d), xs, d)))
#metadata(repr((f(..(xs,), ..(k: d)), xs, d)))
"""),
        Source("arguments: spread into a native function",
               clone="`Eval for Ident` clones the arguments; `Eval for Args` moves the clone's items",
               body=f"""#let a = arguments({ARR}, 0, k: {DICT})
#let b = arguments((1, 2))
#let d = arguments({DICT}, "zz", 0)
#let _ = (array.push)(..a.pos())
#let _ = (array.push)(..b, 0)
#let _ = (array.pop)(..b)
#let _ = (dictionary.insert)(..d)
#let _ = (array.pop)(..arguments(..b))
#metadata(repr((a, b, d)))
#let f(..a) = {{
  let _ = (array.pop)(..a)
  let _ = (array.push)(..a, 0)
  let _ = (array.pop)(..arguments(..a))
  a.pos()
}}
#let g(..a) = {{
  let _ = (dictionary.insert)(..a, "zz", 0)
  let _ = (dictionary.remove)(..a, "a")
  a.pos()
}}
#let h(..a) = (f(..a), a.pos())
#metadata(repr((f((1, 2)), f((1, 2)), g({DICT}), g({DICT}), h((1, 2)), h((1, 2)))))
#let xs = (1, 2)
#metadata(repr((f(xs), h(xs), xs)))
// In math (`eval_math_args`).
#let am = arguments((1, 2), (3, 4))
#let pop = array.pop
#let both(a, b) = (array.pop)(a) + (array.pop)(b)
// (Evaluated, not laid out: the oracle's test world has no fonts.)
#let one = arguments((1, 2))
#let eq = $ pop(..#one) + pop(..#am.filter(v => v.len() == 2).pos().slice(0, 1)) + both(..#am) $
#metadata(repr((one, am)))
#let mk() = arguments((1, 2), (k: (3,)))
#let _ = range(2).map(i => (array.pop)(..mk().filter(v => type(v) == array)))
#let _ = range(2).map(i => (dictionary.insert)(mk().at(1), "zz", 0))
#metadata(repr(range(2).map(i => mk())))
#metadata(repr((a.pos(), b.pos())))
"""),
        Source("arguments: `filter` and `map`", pre=f"#let a = arguments({ARR}, 5, k: {DICT})",
               expr="a.filter(v => true).pos()", shape=[("", "A", None, True)] + nested(".at(0)", AA),
               also=["a", "a.map(v => v).named()", "a.map(v => v).at(0)", "a.filter(v => true).at(\"k\")"],
               clone=clone),
        Source("arguments: spread into a sink", pre=f"#let xs = {ARR}\n#let d = {DICT}\n#let f(..a) = a.pos()\n#let g(..a) = a.named()",
               expr="f(..xs)", shape=[("", "A", None, True), (".at(0)", "A", None, True), (".at(1)", "D", "k", True)],
               also=["xs", "g(..d)", "d"], clone="`Eval for Args`: the spread values are cloned"),
        Source("arguments: a dictionary spread into a sink", pre=f"#let d = {DICT}\n#let g(..a) = a.named()",
               expr="g(..d)", shape=DD, also=["d"], clone="`Eval for Args`: the spread values are cloned"),
    ]


def data_sources():
    clone = "loading: the value is deserialized (upstream memoizes none of these)"
    return [
        Source("data: json", expr='json(bytes("[[1, 2], {\\"k\\": [3]}]"))', shape=AA, clone=clone),
        Source("data: yaml", expr='yaml(bytes("- [1, 2]\\n- {k: [3]}"))', shape=AA, clone=clone),
        Source("data: toml", expr='toml(bytes("a = [1, 2]\\n[d]\\nk = [3]"))', shape=DD, clone=clone),
        Source("data: csv", expr='csv(bytes("1,2\\n3,4"))',
               shape=[("", "A", None, True), (".at(0)", "A", None, True)], clone=clone),
        Source("data: csv rows as dictionaries", expr='csv(bytes("a,b\\n3,4"), row-type: dictionary)',
               shape=[("", "A", None, True), (".at(0)", "D", "a", True)], clone=clone),
        Source("data: cbor", expr=f"cbor(cbor.encode({ARR}))", shape=AA, clone=clone),
        Source("data: xml", expr='xml(bytes("<a><b/></a>"))',
               shape=[("", "A", None, True), (".at(0)", "D", "tag", True), (".at(0).children", "A", None, True),
                      (".at(0).attrs", "D", None, True)], clone=clone),
        Source("data: matches of a regex", expr='"a1b2".matches(regex("[a-z](\\\\d)"))',
               shape=[("", "A", None, True), (".at(0)", "D", "text", True), (".at(0).captures", "A", None, True)],
               clone="str.rs: new values"),
        Source("data: measure, position and layout sizes", ctx=True, call=False,
               expr="measure(box(width: 10pt, height: 5pt))", shape=d_key("width"),
               also=["here().position().keys()"],
               clone="new dictionaries"),
        Source("data: stops of a gradient and components of a color",
               pre="#let g = gradient.linear(red, blue)\n#let st = stroke(dash: (1pt, 2pt))",
               expr="g.stops()", shape=[("", "A", None, True), (".at(0)", "A", None, True)],
               also=["red.components()", "st.dash"], clone="new arrays"),
        Source("data: the dash pattern of a stroke", pre="#let st = stroke(dash: (1pt, 2pt))",
               expr="st.dash", shape=d_key("array") + [(".array", "A", None, True)], clone="new values"),
    ]


def accessor_sources():
    """Methods that return their receiver's parts, on a variable."""
    x = "#let x = ((1, 2), (3, 4), (5, 6))"
    d = f"#let d = {DICT}"
    inner = [("", "A", None, True)]
    outer = [("", "A", None, True), (".at(0)", "A", None, True)]
    pairs = [("", "A", None, True), (".at(0)", "A", None, True), (".at(0).at(0)", "A", None, True)]

    def a(name, expr, shape, pre=x, also=("x",), clone="array.rs: `.clone()` / `.cloned()` of the items"):
        return Source("accessor: " + name, pre=pre, expr=expr, shape=shape, also=also, clone=clone)

    dc = "dict.rs: `.clone()` / `.cloned()` of the values"
    return [
        a("array.first", "x.first()", inner),
        a("array.last", "x.last()", inner),
        a("array.at", "x.at(1)", inner),
        a("array.at with a negative index and a default", "x.at(-1, default: x.at(0))", inner),
        a("array.at, the default", "x.at(9, default: x.at(0))", inner),
        a("array.first and last with a default", "x.first(default: x.at(1))", inner, also=["x", "x.last(default: x.at(1))"]),
        a("array.slice", "x.slice(0, 2)", outer),
        a("array.rev", "x.rev()", outer),
        a("array.zip", "x.zip(x)", pairs),
        a("array.zip with exact", "x.zip(x, exact: true)", pairs),
        a("array.chunks", "x.chunks(2)", pairs),
        a("array.windows", "x.windows(2)", pairs),
        a("array.enumerate", "x.enumerate()", [("", "A", None, True), (".at(0)", "A", None, True), (".at(0).at(1)", "A", None, True)]),
        a("array.sorted", "x.sorted()", outer),
        a("array.sorted with a key", "x.sorted(key: v => v.at(0))", outer),
        a("array.dedup", "x.dedup()", outer),
        a("array.dedup with a key", "x.dedup(key: v => v.at(0))", outer),
        a("array.filter", "x.filter(v => true)", outer),
        a("array.map with the identity", "x.map(v => v)", outer),
        a("array.find", "x.find(v => true)", inner),
        a("array.flatten", "(x, x).flatten()", inner),
        a("array.flatten of deeper arrays", "((x,), (x,)).flatten()", inner),
        a("array.join of one item", "(x.at(0),).join()", inner),
        a("array.join", "x.join()", inner),
        a("array.join of nested arrays", "(x, x).join()", outer),
        a("array.sum of one item", "(x.at(0),).sum()", inner),
        a("array.sum with a default", "().sum(default: x.at(0))", inner),
        a("array.sum of nested arrays", "(x, x).sum()", outer),
        a("array.product of one item", "(x.at(0),).product()", inner),
        a("array.product with a default", "().product(default: x.at(0))", inner),
        a("the result of a native pop and remove", "(array.pop)(x)", inner,
          also=["x", "(array.remove)(x, 0)", "(array.at)(x, 0)", "(array.first)(x)"]),
        a("the result of a native remove", "(array.remove)(x, 1)", inner),
        a("calc.abs and other natives that return an argument", "x.at(0, default: calc.abs(1))", inner,
          also=["x", "calc.abs(-1)", "type(x)"]),
        a("array.fold", "x.fold((), (acc, v) => v)", inner),
        a("array.fold, the initial value", "().fold(x.at(0), (acc, v) => v)", inner),
        a("array.reduce", "x.reduce((acc, v) => v)", inner),
        a("array.reduce of one item", "(x.at(0),).reduce((acc, v) => v)", inner),
        a("array.intersperse", "x.intersperse(x.at(0))", outer + [(".at(1)", "A", None, True)]),
        a("array.split", "x.split((3, 4))", pairs),
        a("array.to-dict", '(("a", x.at(0)), ("b", x)).to-dict()',
          d_key("a") + [(".a", "A", None, True), (".b", "A", None, True), (".b.at(0)", "A", None, True)]),
        a("array + array", "x + ()", outer),
        a("array + array, right", "() + x", outer),
        a("array + array, both", "x + x", outer),
        a("array * 1", "x * 1", outer),
        a("array * 2", "2 * x", outer),
        a("a spread into an array", "(..x,)", outer),
        a("an array literal", "(x, x.at(0))", pairs[:2] + [(".at(1)", "A", None, True), (".at(0).at(0)", "A", None, True)]),
        a("the array constructor", "array(x)", outer),
        a("calc.max and calc.min", "calc.max(..x)", inner, also=["x", "calc.min(..x)"]),
        a("calc.min", "calc.min(..x)", inner),
        a("a conditional and a block", "if true { x.at(0) } else { x.at(1) }", inner, also=["x", "{ x.at(1) }"]),
        a("a block", "{ x.at(1) }", inner),
        a("array.range and others without parts", "range(3)", inner, also=["x", "x.flatten()", "x.len()"]),
        a("array.at of a dictionary value", "d.a", inner, pre=d, also=["d"], clone=dc),
        a("dictionary.at", 'd.at("a")', inner, pre=d, also=["d"], clone=dc),
        a("dictionary.at, the default", 'd.at("zz", default: d.a)', inner, pre=d, also=["d"], clone=dc),
        a("dictionary.values", "d.values()",
          [("", "A", None, True), (".at(0)", "A", None, True), (".at(1)", "D", "k", True), (".at(1).k", "A", None, True)],
          pre=d, also=["d"], clone=dc),
        a("dictionary.pairs", "d.pairs()",
          [("", "A", None, True), (".at(0)", "A", None, True), (".at(0).at(1)", "A", None, True),
           (".at(1).at(1)", "D", "k", True)], pre=d, also=["d"], clone=dc),
        a("dictionary.keys", "d.keys()", inner, pre=d, also=["d"], clone=dc),
        a("dictionary + dictionary", "d + (:)", DD, pre=d, also=["d"], clone=dc),
        a("dictionary + dictionary, right", "(:) + d", DD, pre=d, also=["d"], clone=dc),
        a("a spread into a dictionary", "(w: 1, ..d)", DD[:5], pre=d, also=["d"], clone=dc),
        a("a dictionary literal", "(v: d, w: d.a)", d_key("v") + nested(".v", DD) + [(".w", "A", None, True)],
          pre=d, also=["d"], clone=dc),
        a("pairs back to a dictionary", "d.pairs().to-dict()", DD, pre=d, also=["d"], clone=dc),
        a("dictionary.filter", "d.filter(v => true)", DD, pre=d, also=["d"], clone=dc),
        a("dictionary.map with the identity", "d.map(v => v)", DD, pre=d, also=["d"], clone=dc),
        a("the result of a native dictionary remove", '(dictionary.remove)(d, "a")', inner, pre=d,
          also=["d", '(dictionary.remove)(d, "d")', '(dictionary.at)(d, "a")'], clone=dc),
        a("a nested dictionary value", "d.d", [("", "D", "k", True), (".k", "A", None, True)],
          pre=d, also=["d"], clone=dc),
        Source("accessor: native functions as callbacks", clone="array.rs: the callbacks get clones of the items",
               body="""#let x = ((1, 2), (3, 4), (5, 6))
#let b = ((true, true), (false, true), (true, false))
#let d = (a: (1, 2), b: (3, 4))
#let _ = x.map(array.pop)
#metadata(repr(x))
#let _ = x.sorted(key: array.pop)
#let _ = x.dedup(key: array.pop)
#metadata(repr(x))
#let _ = b.filter(array.pop)
#let _ = b.any(array.pop)
#let _ = b.all(array.pop)
#let _ = b.find(array.pop)
#let _ = b.position(array.pop)
#metadata(repr(b))
#let _ = d.values().map(array.pop)
#let _ = d.map(array.pop)
#let dt = (a: (true, true), b: (false, true))
#let _ = dt.filter(array.pop)
#metadata(repr(dt))
#let ar = arguments((true, true), (false, true), k: (true, false))
#let _ = ar.filter(array.pop)
#let _ = ar.map(array.pop)
#metadata(repr(ar))
#let _ = d.pairs().map(array.last).map(array.pop)
#metadata(repr(d))
#let _ = x.zip(x).map(array.first).map(array.pop)
#let _ = x.enumerate().map(array.last).map(array.pop)
#let _ = x.chunks(2).map(array.first).map(array.pop)
#let _ = x.windows(2).map(array.first).map(array.pop)
#let _ = x.rev().map(array.pop)
#let _ = x.slice(0).map(array.pop)
#let _ = (x + ()).map(array.pop)
#let _ = (x * 1).map(array.pop)
#let _ = (..x,).map(array.pop)
#let _ = x.sorted().map(array.pop)
#let _ = x.dedup().map(array.pop)
#let _ = x.filter(v => true).map(array.pop)
#let _ = x.intersperse(x.at(0)).map(array.pop)
#let _ = x.split((9,)).first().map(array.pop)
#let _ = (x, x).join().map(array.pop)
#let _ = (x, x).sum().map(array.pop)
#metadata(repr(x))
#let f() = x
#let _ = f().map(array.pop)
#let load() = ((1, 2), (3, 4))
#let _ = load().map(array.pop)
#metadata(repr((x, f(), load())))
"""),
        Source("accessor: destructuring and loops", clone="binding: the bound values are clones",
               body=f"""#let x = ((1, 2), (3, 4), (5, 6))
#let d = {DICT}
#{{
  let (a, ..rest) = x
  let _ = (array.pop)(a)
  let _ = (array.pop)(rest.at(0))
  let _ = (array.pop)(rest)
  let (a: p, ..others) = d
  let _ = (array.pop)(p)
  let _ = (dictionary.insert)(others.d, "zz", 0)
  for v in x {{ let _ = (array.pop)(v) }}
  for (k, v) in d {{ if k == "a" {{ let _ = (array.pop)(v) }} else {{ let _ = (dictionary.insert)(v, "zz", 0) }} }}
  for (i, v) in x.enumerate() {{ let _ = (array.pop)(v) }}
  metadata(repr((x, d)))
}}
#metadata(repr((x, d)))
"""),
    ]


def memo_sources():
    """What memoized evaluations and layouts hand out again."""
    return [
        Source("memo: the result of a closure that reads a state", ctx=True,
               pre=f'#let s = state("m-state", {ARR})\n#let read() = (s.get(), s.final())',
               expr="read()", shape=[("", "A", None, True)] + nested(".at(0)", AA) + nested(".at(1)", AA),
               also=["s.get()"], clone="comemo clones the output; state.rs clones the value"),
        Source("memo: a value handed through two closures", pre=f"#let inner() = {ARR}\n#let outer() = inner()",
               expr="outer()", shape=AA, also=["inner()"], clone="comemo clones the output"),
        Source("memo: a closure result held by a second holder",
               pre=f"#let load() = {ARR}\n#let kept = load()",
               expr="load()", shape=AA, also=["kept"], clone="comemo clones the output"),
        Source("memo: an argument returned by the closure", pre=f"#let id(v) = v\n#let xs = {ARR}",
               expr="id(xs)", shape=AA, also=["xs", f"id({ARR})"], clone="arguments are passed by value"),
        Source("memo: an argument mutated by the closure",
               pre=f"#let grow(v) = {{ v.at(0).push(9); v.at(1).k.push(9); v }}\n#let xs = {ARR}",
               expr="grow(xs)", shape=AA, also=["xs", "grow(xs)", f"grow({ARR})"],
               clone="arguments are passed by value"),
        Source("memo: a state object returned by a closure", ctx=True,
               pre=f'#let make() = state("m-made", {DICT})\n#make().update(v => v)',
               expr="make().get()", shape=DD, also=["make().final()"], clone="state.rs clones the value"),
        Source("memo: content with a container field returned by a closure",
               pre=f"#let mk() = metadata({ARR})",
               expr="mk().value", shape=AA, also=["mk().fields().value"], clone="a field access clones the field"),
        Source("memo: arguments returned by a closure",
               pre=f"#let mk() = arguments({ARR}, k: {DICT})",
               expr="mk().pos()", shape=[("", "A", None, True)] + nested(".at(0)", AA),
               also=["mk().named()", "mk().at(0)"], clone="args.rs clones the values"),
        Source("memo: a function with a default returned by a closure",
               pre=f"#let mk() = (x: {ARR}) => x",
               expr="(mk())()", shape=AA, clone="call.rs `default.clone()`"),
        Source("memo: the size given to a layout callback and a measurement", call=False,
               body="""#layout(size => {
  let _ = (dictionary.insert)(size, "zz", 0)
  let m = measure([x])
  let _ = (dictionary.insert)(measure([x]), "zz", 0)
  metadata(repr((size.keys(), measure([x]).keys())))
})
#layout(size => metadata(repr(size.keys())))
""", clone="new dictionaries"),
    ]


def all_sources():
    groups = [
        ("state", state_sources()),
        ("counters", counter_sources()),
        ("element fields", element_sources()),
        ("styles through contextual field access", style_sources()),
        ("functions", function_sources()),
        ("modules", module_sources()),
        ("arguments", arguments_sources()),
        ("loaded and computed data", data_sources()),
        ("methods that return parts of their receiver", accessor_sources()),
        ("memoized calls and layouts", memo_sources()),
    ]
    return groups


def group_document(sources):
    """The sources of a group as one document: each in a content block, so
    that its definitions and rules are its own."""
    out = []
    top = [s for s in sources if s.top]
    assert len(top) <= 1
    for s in top:
        out.append(f"#metadata({json.dumps('== ' + s.name)})\n" + s.document())
    for s in sources:
        if s.top:
            continue
        doc = s.document().rstrip("\n")
        out.append(f"#metadata({json.dumps('== ' + s.name)})\n#[\n{doc}\n]\n")
    files = {}
    for s in sources:
        for path, text in s.files.items():
            assert files.get(path, text) == text
            files[path] = text
    return "".join(out), files


def cases():
    """The oracle cases: (name, kind, source, files)."""
    out = []
    for name, sources in all_sources():
        source, files = group_document(sources)
        out.append((f"sharing: {name}", "metadata", source, files))
    return out


def query(binary, source, files):
    with tempfile.TemporaryDirectory() as tmp:
        for path, text in files.items():
            with open(os.path.join(tmp, path), "w", encoding="utf-8", newline="") as f:
                f.write(text)
        main = os.path.join(tmp, "main.typ")
        with open(main, "w", encoding="utf-8", newline="") as f:
            f.write(source)
        run = subprocess.run(
            [binary, "query", "--root", tmp, "--ignore-system-fonts", main, "metadata", "--field", "value"],
            capture_output=True, text=True, stdin=subprocess.DEVNULL)
        if run.returncode != 0:
            errors = [l for l in run.stderr.split("\n") if l.startswith("error")]
            return None, "; ".join(errors) or run.stderr.strip()[:300]
        return [v for v in json.loads(run.stdout) if isinstance(v, str)], ""


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    upstream, port = sys.argv[1], sys.argv[2]
    filters = sys.argv[3:]
    verbose = os.environ.get("VERBOSE")
    bad = 0
    total = 0
    for group, sources in all_sources():
        for s in sources:
            if filters and not any(f in s.name for f in filters):
                continue
            total += 1
            doc = s.document()
            expected, err = query(upstream, doc, s.files)
            if expected is None:
                print(f"INVALID  {s.name}: upstream fails: {err}")
                bad += 1
                continue
            actual, err = query(port, doc, s.files)
            if actual == expected:
                print(f"same     {s.name}")
            else:
                bad += 1
                print(f"DIFFERS  {s.name}")
                if actual is None:
                    print(f"           port fails: {err}")
                else:
                    for i, (e, a) in enumerate(zip(expected, actual)):
                        if e != a:
                            print(f"           value {i}: upstream {e}")
                            print(f"           value {i}: port     {a}")
                            break
                    else:
                        print(f"           {len(expected)} values upstream, {len(actual)} in the port")
            if verbose:
                print(doc)
                print(expected)
    print(f"{total} sources, {bad} differ")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
