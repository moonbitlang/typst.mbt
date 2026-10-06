// cmarker 0.1.10: a Markdown file next to the document (`read`) rendered by the package's
// WebAssembly plugin: headings, emphasis, sub/sup/mark, nested and ordered lists, task
// lists (`task-list-marker`), links and reference links, block quotes, hard breaks,
// thematic break, code blocks, pipe and HTML tables (row/colspan, head, foot), footnotes,
// description lists, inline SVG in a figure, custom HTML elements (`html:`), raw Typst in
// comments with `scope`, excluded sections, smart punctuation.
// Engine: wasm plugin, eval of generated markup with a scope of closures, counters and
// context in list markers, SVG image from bytes, labels from generated markup.
#import "@preview/cmarker:0.1.10"

#set page(width: 140mm, height: 180mm, margin: (x: 13mm, y: 14mm), numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.1")
#show link: set text(fill: rgb("#2a6f4e"))
#show quote.where(block: true): it => block(
  stroke: (left: 2pt + rgb("#9bbf73")),
  inset: (left: 8pt, y: 3pt),
  it.body,
)
#set table(stroke: 0.4pt, inset: 4pt)
#show table.cell.where(y: 0): strong

#let checkbox(checked) = box(
  width: 0.75em,
  height: 0.75em,
  stroke: 0.6pt,
  radius: 1.5pt,
  baseline: 0.05em,
  fill: if checked { rgb("#9bbf73") },
  if checked { place(center + horizon, text(0.7em, weight: "bold")[✓]) },
)

#cmarker.render(
  read("allotment.md"),
  task-list-marker: checkbox,
  scope: (
    season: [late winter],
    plot: 14,
    // The package hands `<dl>` to `terms` as (term, description) pairs, which this
    // compiler version does not cast to term items; build the items here.
    terms: (..pairs) => terms(..pairs.pos().map(((term, description)) => terms.item(term, description))),
  ),
  html: (
    bed: (attrs, body) => box(
      fill: rgb("#f4f1e6"),
      inset: (x: 3pt),
      outset: (y: 2pt),
      radius: 2pt,
    )[*#attrs.name*: #body],
    gauge: (
      "void",
      attrs => box(width: 30pt, height: 0.7em, stroke: 0.5pt, baseline: 0.05em, align(left, rect(
        width: int(attrs.level) * 1%,
        height: 100%,
        fill: rgb("#7fa7c9"),
      ))),
    ),
  ),
)
