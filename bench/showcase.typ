#set document(
  title: [typst.mbt Showcase],
  author: "typst.mbt",
  keywords: ("typst", "moonbit", "typesetting"),
)
#set page(
  paper: "a4",
  margin: (x: 2.2cm, top: 2.6cm, bottom: 2.4cm),
  header: context {
    if counter(page).get().first() > 1 [
      #set text(9pt, fill: luma(110))
      _typst.mbt — a MoonBit port of Typst_
      #h(1fr)
      #counter(page).display("1 / 1", both: true)
    ]
  },
)
#set text(font: "Libertinus Serif", size: 11pt, lang: "en")
#set par(justify: true, leading: 0.62em)
#set heading(numbering: "1.1")
#set math.equation(numbering: "(1)")
#show heading.where(level: 1): it => {
  v(0.6em)
  block(text(fill: rgb("#1f4e79"), it))
  v(0.2em)
}
#show raw.where(block: true): block.with(
  fill: luma(246),
  inset: 9pt,
  radius: 4pt,
  width: 100%,
  stroke: 0.5pt + luma(220),
)
#show link: underline

// ---------------------------------------------------------------- Title
#block(
  width: 100%,
  inset: (x: 18pt, y: 22pt),
  radius: 8pt,
  fill: gradient.linear(rgb("#1f4e79"), rgb("#2e86ab"), rgb("#7fc8a9"), angle: 20deg),
)[
  #set text(fill: white)
  #text(26pt, weight: "bold")[typst.mbt]
  #v(-6pt)
  #text(13pt)[A faithful MoonBit port of the Typst typesetting engine]
  #v(4pt)
  #text(9.5pt)[This document was compiled end to end by the MoonBit port: parsing, evaluation,
    layout, shaping, line breaking, hyphenation, math, bibliography and PDF export.]
]

#v(4pt)
#outline(depth: 2, indent: auto)

= Text and paragraphs

Typst lays out text with a Knuth–Plass style optimizer, OpenType shaping and
Unicode line breaking. Ligatures (fi, fl, ffi), kerning and old-style figures
(#text(number-type: "old-style")[1234567890]) come from the fonts' OpenType
tables, and hyphenation follows the language: the paragraph you are reading is
justified with hyphenation enabled.#footnote[Hyphenation patterns come from the
`hypher` crate, ported to MoonBit together with its tries.] Smart quotes adapt
to the language: "English", #text(lang: "de")["Deutsch"],
#text(lang: "fr")["Français"].

#text(lang: "de")[Donaudampfschifffahrtsgesellschaftskapitänsmütze ist ein
langes deutsches Wort, das ohne Silbentrennung kaum in eine Zeile passt.]

Mixed scripts are shaped and reordered with the Unicode bidirectional
algorithm: English, #text(font: "Geeza Pro", lang: "ar")[مرحبا بالعالم], and
#text(font: ("PingFang SC", "Songti SC"), lang: "zh")[排版引擎的移植], all in
one line.

#grid(
  columns: (1fr, 1fr),
  gutter: 14pt,
  [
    *Lists*
    - Native, wasm-gc and wasm targets
    - Differential tests against upstream
      - 3 792 test files
      - Byte-exact SVG
    + Parse
    + Evaluate
    + Lay out
  ],
  [
    *Quote*
    #quote(attribution: [Donald E. Knuth], block: true)[
      Beauty is our business.
    ]
  ],
)

= Mathematics

The quadratic formula $x = (-b plus.minus sqrt(b^2 - 4 a c)) / (2 a)$ sits
inline, while display math gets its own line:

$ integral_(-infinity)^infinity e^(-x^2) dif x = sqrt(pi)
  quad "and" quad
  sum_(n=1)^infinity 1 / n^2 = pi^2 / 6 $

$ mat(
  cos theta, -sin theta;
  sin theta, cos theta;
) vec(x, y)
= vec(x cos theta - y sin theta, x sin theta + y cos theta) $

$ f(x) = cases(
  x^2 & "if" x >= 0,
  -x & "otherwise",
) wide
lim_(n -> infinity) (1 + 1/n)^n = e $

$ nabla times bold(B) - 1/c^2 (partial bold(E)) / (partial t) = mu_0 bold(J) $ <maxwell>

Maxwell's law, @maxwell, is referenced by label.

= Tables and figures

#figure(
  table(
    columns: (auto, 1fr, auto, auto),
    align: (left, left, right, right),
    stroke: (x, y) => if y == 0 { (bottom: 0.8pt) } else { (bottom: 0.3pt + luma(200)) },
    fill: (_, y) => if y > 0 and calc.odd(y) { luma(247) },
    table.header[*Stage*][*What it checks*][*Tests*][*Pass*],
    [syntax], [parser, AST, incremental reparse], [3 792], [100%],
    [eval], [evaluation, styles, introspection], [3 792], [99.7%],
    [paged], [frames: layout, text, math], [2 299], [100%],
    [svg], [SVG export, byte-identical], [2 299], [100%],
    [pdf], [PDF semantics and tag tree], [2 299], [100%],
    [render], [PNG rasterization], [2 299], [100%],
  ),
  caption: [Differential test stages against upstream Typst.],
) <stages>

#grid(
  columns: (1.15fr, 1fr),
  gutter: 12pt,
  figure(
    image("glacier.jpg", width: 100%),
    caption: [A JPEG photo, embedded as is.],
  ),
  figure(
    image("diagram.svg", width: 100%),
    caption: [An SVG diagram, converted to vectors.],
  ),
)

#figure(
  image("matplotlib.pdf", width: 62%),
  caption: [A PDF figure (matplotlib), embedded as a vector form.],
)

= Code

Code blocks are highlighted with a port of `syntect` and Typst's bundled
syntaxes:

```rust
/// Compute the n-th Fibonacci number.
fn fib(n: u64) -> u64 {
    let (mut a, mut b) = (0, 1);
    for _ in 0..n {
        (a, b) = (b, a + b);
    }
    a
}
```

```python
def primes(limit: int) -> list[int]:
    sieve = [True] * (limit + 1)
    for i in range(2, int(limit ** 0.5) + 1):
        if sieve[i]:
            sieve[i * i :: i] = [False] * len(sieve[i * i :: i])
    return [i for i in range(2, limit + 1) if sieve[i]]
```

And Typst itself is scriptable — this table is computed:

#let fibs = (0, 1)
#for i in range(2, 12) { fibs.push(fibs.at(i - 1) + fibs.at(i - 2)) }
#table(
  columns: 12,
  align: center,
  inset: 5pt,
  ..fibs.map(n => [#n]),
)

= Drawing

#align(center, stack(
  dir: ltr,
  spacing: 12pt,
  circle(radius: 22pt, fill: gradient.radial(rgb("#ffd166"), rgb("#ef476f"))),
  rect(width: 60pt, height: 44pt, radius: 6pt, fill: gradient.conic(..color.map.rainbow)),
  polygon.regular(vertices: 6, size: 48pt, fill: rgb("#118ab2"), stroke: 1.5pt + rgb("#073b4c")),
  curve(
    stroke: 2pt + rgb("#06d6a0"),
    curve.move((0pt, 40pt)),
    curve.cubic((20pt, -20pt), (40pt, 80pt), (60pt, 10pt)),
  ),
  box(
    width: 70pt,
    height: 44pt,
    fill: tiling(size: (8pt, 8pt))[
      #place(line(start: (0pt, 0pt), end: (8pt, 8pt), stroke: 0.6pt + luma(120)))
    ],
    stroke: 0.6pt,
  ),
))

= Citations

Bibliographies are formatted with a port of `hayagriva` and the Citation Style
Language: the Net Wok study @netwok, distributed dumplings revisited
@netwok[p. 200], piracy @arrgh and glaciers @glacier-melt, as well as a classic
@tolkien54.

#bibliography("works.bib", style: "ieee")
