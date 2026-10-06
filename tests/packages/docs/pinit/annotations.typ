// pinit 0.2.2: pins in text and in math, highlights and rects over pin
// groups, arrows and double arrows between pins, point-to / point-from /
// line-to annotations, placed content, the same pin names reused on a
// later page, a custom callback computing from pin positions.
// Stresses labels built from page numbers, query(...before(here())),
// location().position(), absolute placement by negative offsets, curves.
#import "@preview/pinit:0.2.2": *

#set page(width: 14cm, height: 19.5cm, margin: (x: 1.5cm, y: 1.6cm), numbering: "1")
#set text(size: 10.5pt)
#set par(justify: true, leading: 0.9em)

= Reading a knitting pattern

A row of a pattern is short but dense. Take this one:

#v(3.6em)

#align(center, text(size: 13pt)[
  #pin(1)K2#pin(2), #pin(3)P2#pin(4), #pin(5)\*YO, K2tog\*#pin(6) #pin(7)×6#pin(8), K1#pin(9)
])

#pinit-highlight(1, 2)
#pinit-highlight(3, 4, fill: rgb(0, 120, 255, 40))
#pinit-highlight(5, 6, fill: rgb(0, 180, 0, 40), radius: 0pt, extended-height: 1.6em)
#pinit-rect(7, 8, stroke: (paint: orange, dash: "dashed"), dy: -1.05em)

#pinit-point-from(2, pin-dx: -10pt, pin-dy: 6pt, offset-dx: -30pt, offset-dy: 38pt, body-dx: -40pt)[knit two]
#pinit-point-from((3, 4), pin-dy: -16pt, offset-dy: -40pt, offset-dx: 0pt, body-dx: -22pt, body-dy: -14pt, fill: blue, stroke: blue)[
  #text(fill: blue)[purl two]
]
#pinit-point-to((5, 6), pin-dy: 8pt, offset-dy: 45pt, offset-dx: 10pt, fill: green.darken(20%), stroke: green.darken(20%))[
  #text(fill: green.darken(30%))[the lace repeat]
]
#pinit-line-to(8, pin-dx: -8pt, pin-dy: -14pt, offset-dx: 30pt, offset-dy: -36pt, body-dy: -12pt, stroke: orange)[six times]
#pinit-place(9, dx: 4pt, dy: 6pt, text(size: 8pt, fill: gray)[end of row])

#v(4.5em)

The repeat between the asterisks makes one hole and takes one stitch away,
so the stitch count does not change. That is what the arrows below say.

#v(1em)

#grid(
  columns: (1fr, 1fr),
  align: center,
  [before: #pin("in")20 stitches#pin("in-end")],
  [after: #pin("out")20 stitches#pin("out-end")],
)

#pinit-arrow("in-end", "out", start-dx: 4pt, start-dy: -4pt, end-dx: -40pt, end-dy: -4pt)
#pinit-double-arrow("in", "out-end", start-dy: 8pt, end-dy: 8pt, stroke: 0.6pt + purple, fill: purple)

#v(2em)

== The arithmetic

The stitch count after a row with $k$ increases and $d$ decreases:

#v(4.2em)

$ #pin("n")n_"after"#pin("n2") = #pin("b")n_"before"#pin("b2") + #pin("k")k#pin("k2") - #pin("d")d#pin("d2") $

#pinit-highlight("n", "n2")
#pinit-highlight("k", "k2", fill: rgb(0, 180, 0, 50))
#pinit-highlight("d", "d2", fill: rgb(0, 0, 255, 40))
#pinit-point-from("k2", pin-dx: -4pt, pin-dy: -14pt, offset-dx: 20pt, offset-dy: -36pt, body-dy: -14pt, body-dx: -8pt)[yarn overs]
#pinit-point-from("d", pin-dx: 3pt, pin-dy: 8pt, offset-dx: 30pt, offset-dy: 34pt, body-dx: -5pt)[k2tog, ssk]
#pinit-point-to("n", pin-dx: 8pt, pin-dy: 8pt, offset-dx: -30pt, offset-dy: 34pt, body-dx: -60pt)[what you count]

#v(4.6em)

Inline math takes pins too: with $k = #pin("six")6#pin("six2")$ and
$d = 6$ the count stays at twenty.
#pinit-rect("six", "six2", stroke: 0.5pt + red, extended-width: 1pt)

#pagebreak()

= The same names, a page later

Pins are looked up on the page of the annotation, so the names 1, 2, ...
can be used again here without touching the first page.

#v(2.2em)

#align(center, text(size: 13pt)[
  #pin(1)SSK#pin(2), #pin(3)K to last 2#pin(4), #pin(5)K2tog#pin(6)
])

#pinit-highlight(1, 2, fill: rgb(200, 0, 150, 40))
#pinit-highlight(5, 6, fill: rgb(200, 0, 150, 40))
#pinit-arrow(2, 5, start-dx: 2pt, start-dy: -14pt, end-dx: -2pt, end-dy: -14pt, stroke: 0.5pt + gray, fill: gray)
#pinit-place((3, 4), dx: -40pt, dy: 10pt, text(size: 8pt)[plain knitting in between])

#v(3em)

A callback gets the positions and may compute with them. Here it draws a
bracket whose width is measured from two pins and prints that width.

#v(0.5em)

Cast on #pin("a")forty-two stitches loosely#pin("z") and join in the round.

#pinit("a", "z", callback: (a, z) => {
  let w = z.x - a.x
  absolute-place(dx: a.x, dy: a.y + 4pt, {
    curve(
      stroke: 0.6pt + teal,
      curve.line((0pt, 4pt)),
      curve.line((w, 4pt)),
      curve.line((w, 0pt)),
    )
  })
  absolute-place(dx: a.x, dy: a.y + 10pt, text(size: 7pt, fill: teal)[#calc.round(w.pt(), digits: 1) pt wide, on page #a.page])
})

#v(2em)

#lorem(40)

Pins at the two ends of a paragraph that wraps: #pin("p0")#lorem(18)#pin("p1")

#pinit-line("p0", "p1", stroke: (paint: red, thickness: 0.5pt, dash: "dotted"), start-dy: -3pt, end-dy: -3pt)
