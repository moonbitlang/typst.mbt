// drafting 0.2.2: inside/outside margins with binding (notes swap sides on
// odd and even pages), explicit margins given to set-page-properties,
// rule-grid (relative, absolute, divisions, square), absolute-place,
// place-margin-rects, margin-lines, notes inside a container with an offset.
// Stresses layout() + state in set-page-properties, measure, metadata
// queries for absolute placement, many placed lines and labels.
#import "@preview/drafting:0.2.2": *

#set page(width: 14cm, height: 16cm, margin: (inside: 1.2cm, outside: 3.6cm, y: 1.4cm), numbering: "1")
#set text(size: 9.5pt)
#set par(justify: true)
#set-page-properties()

= A plan of the allotment

On a right-hand page the wide margin is on the right. #margin-note[Outside
margin, page one.] The plots are numbered from the gate. #lorem(40)
#margin-note(stroke: blue)[Still outside.] #lorem(40)

#rule-grid(width: 9cm, height: 3cm, spacing: 20pt, stroke: gray)
#place(dx: 100pt, dy: 20pt, rect(fill: white, stroke: red, width: 3cm)[The shed, at (100, 20).])
#place(dx: 20pt, dy: 60pt, circle(radius: 8pt, fill: green.lighten(40%), stroke: green.darken(30%)))
#v(3cm + 1em)

#rule-grid(dx: 1cm, width: 4cm, height: 1.5cm, divisions: 4, square: true, stroke: green.darken(20%))
#rule-grid(dx: 6cm, width: 3cm, height: 1.5cm, divisions: (6, 3), stroke: (paint: maroon, thickness: 0.4pt))
#v(1.5cm + 1em)

#lorem(30)

#pagebreak()

#margin-lines(stroke: orange + 0.6pt)

On a left-hand page the wide margin is on the left, and the notes follow
it. #margin-note[Outside margin, page two.] #lorem(30)
#margin-note(side: right, fill: yellow.lighten(60%))[Forced into the narrow
inside margin.] #lorem(40)

#absolute-place(dx: 5cm, dy: 12cm, rect(fill: aqua.lighten(60%), stroke: navy, inset: 4pt)[Placed at (5 cm, 12 cm) of the page.])

#absolute-place(dx: 0.3cm, dy: 0.3cm, text(size: 7pt, fill: gray)[corner mark])

#lorem(40)

#pagebreak()

// Explicit left/right margins handed to the helper.
#set page(margin: (left: 3cm, right: 1.5cm, y: 1.4cm))
#set-page-properties(margin-left: 2.6cm)

#place-margin-rects(fill: luma(235), stroke: none, padding: 2%)

#rule-grid(relative: false, spacing: 1cm, stroke: (paint: blue.lighten(60%), thickness: 0.3pt), width: 14cm, height: 16cm)

The whole page is ruled from its top left corner. With the wider margin on
the left, notes go left by themselves. #margin-note[Left because it is
wider; the helper was told 2.6 cm.] #lorem(30) #margin-note(side: right)[Right
on request.] #lorem(30)

A boxed plan with its own margins:

#block(width: 100%, stroke: 0.5pt, inset: (x: 2cm, y: 0.6em))[
  #set-margin-note-defaults(margin-left: 2cm, margin-right: 2cm, page-width: 14cm - 4.5cm - 4cm, page-offset-x: 3cm)
  Inside the frame the notes #margin-note(side: left, stroke: green.darken(20%))[In the frame, left.]
  use the frame's padding as their margins. #lorem(20)
  #margin-note(side: right, stroke: green.darken(20%))[In the frame, right.] #lorem(15)
]

#lorem(30)
