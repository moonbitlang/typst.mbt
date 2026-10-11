// Blocks: what the block level of the flow keeps (tables, grids, blocks in
// blocks, a block that breaks across pages, shapes), with two blocks whose
// layout depends on what is neither their text nor their styles: one reads
// a file while it is laid out, one asks the document. A block's layout that
// a compilation keeps must not be what the next one sees if any of that
// changed.
#import "parts.typ": ledger, summary, swatch

#set page(width: 240pt, height: 200pt, margin: 14pt, numbering: "1")
#set text(size: 8pt)
#set heading(numbering: "1.")
#set table(stroke: 0.5pt + gray, inset: 3pt)

= Tables

#table(
  columns: (auto, 1fr, 30pt),
  table.header([*Item*], [*What*], [*N*]),
  table.hline(stroke: 1pt),
  [a], [first], [1],
  table.cell(colspan: 2, fill: yellow.lighten(60%))[spans two], [2],
  [c], table.cell(stroke: (bottom: 1.5pt + red))[third], [3],
  table.footer([sum], [], [6]),
)

// The rows of this table are in a file that is read when the block is laid
// out (`context`): the read is the layout's, not the evaluation's, and the
// block's text and styles do not change when the file does.
#block(inset: 3pt, stroke: 0.5pt, context ledger())

= Blocks in blocks

#block(fill: aqua.lighten(70%), inset: 4pt, width: 100%)[
  Outer.
  #block(stroke: 1pt + navy, inset: 3pt)[
    Inner, with #swatch(red) and #swatch(green).
    #block(fill: white, inset: 2pt)[Innermost.]
  ]
  #grid(columns: (1fr, 1fr), gutter: 3pt, [left #swatch(blue)], [right])
]

// What this block shows is asked of the document: it changes when the file
// that is included at the end does, and nothing of the block itself.
#block(inset: 3pt, stroke: (left: 2pt + navy), width: 100%, summary())

= A block that breaks

// The footnote takes room on the page it lands on, so the part of the block
// on that page is laid out for a region that is not what the page before
// promised: the heights of the regions after the first are in the key.
#block(breakable: true, stroke: 0.5pt, inset: 3pt)[
  #for i in range(30) [
    Line #(i + 1) of a block that is longer than what is left of its page.
    #if i == 9 { footnote[A note on the page of the tenth line.] } \
  ]
]

#table(
  columns: 2,
  ..range(16).map(i => [cell #i]),
)

#rect(width: 40pt, height: 12pt, fill: gray)
#ellipse(width: 30pt, height: 10pt)

= The same block, three times

// One call, one content, one span: what tells the three layouts apart is
// where they are.
#let stamp() = block(breakable: false, inset: 2pt, stroke: 0.5pt, context [
  At #calc.round(here().position().y.pt()) on page #here().page().
])
#stamp()
#stamp()
#stamp()

// A block whose layout reads `sys.inputs`, and one whose layout warns (in
// every compilation, also in one that finds the layout).
#block(inset: 2pt, context [Mode: #sys.inputs.at("mode", default: "final").])
#block(inset: 2pt, par[A paragraph #parbreak() without a break.])

#include "tail.typ"
