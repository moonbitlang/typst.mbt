// meander 0.4.4: the documented entry point, `meander.reflow`, with placed
// obstacles, two containers, a circular contour and an overflow option.
// With Typst 0.15 it fails inside the package: `here().position()` is `none`
// for the location of a `layout` callback, and the package reads `.x` of it.
// Stresses the error trace through a layout callback and package closures.
#import "@preview/meander:0.4.4"

#set page(width: 14cm, height: 19cm, margin: 1.2cm)
#set text(size: 9pt)
#set par(justify: true)

#meander.reflow({
  import meander: *

  placed(top + left, block(width: 100%, stroke: (bottom: 1.5pt), inset: (bottom: 4pt))[
    #text(size: 18pt, weight: "bold")[The Tide Mill Gazette]
  ])
  placed(
    center + horizon,
    boundary: contour.margin(4mm) + contour.grid(div: 16, (x, y) => calc.pow(2 * x - 1, 2) + calc.pow(2 * y - 1, 2) <= 1),
    circle(radius: 2cm, fill: blue.lighten(70%)),
  )
  placed(bottom + right, rect(width: 5cm, height: 2.2cm, fill: green.lighten(50%)))

  container(width: 48%, style: (text-fill: navy))
  container(align: right, width: 48%, margin: 3mm)

  content[
    *Twice a day the sea fills the pond behind the mill, and twice a day the
    miller lets it out again through the wheel.* #lorem(150)
  ]
  colbreak()
  content(size: 8.5pt)[#lorem(200)]

  opt.overflow.repeat(count: 1)
})
