// subpar 0.2.2: subpar.grid with drawn sub figures, references to sub
// figures and super figures, custom numberings (pattern and function), grid
// arguments passed through, a list of figures with and without sub figures.
// Stresses nested figures with show-set rules per kind, counters stepped and
// rolled back, context numbering, references across pages, outline of figures.
#import "@preview/subpar:0.2.2"

#set page(width: 14cm, height: 19cm, margin: 1.4cm, numbering: "1")
#set text(size: 10pt)
#set par(justify: true)
#set heading(numbering: "1.")

#let tile(fill, body) = rect(width: 100%, height: 2.2cm, fill: fill, stroke: 0.6pt + black, align(center + horizon, body))
#let moon(phase) = box(width: 2cm, height: 2cm, {
  place(circle(radius: 1cm, fill: luma(40)))
  place(dx: phase * 1cm, circle(radius: 1cm, fill: luma(235), stroke: 0.4pt))
})

#outline(title: [Figures], target: figure.where(kind: image))

= Phases

The observatory keeps a sketch for each night. Four of them are collected in
@fig:phases: the thin crescent of @fig:crescent, the half disc of
@fig:quarter, then @fig:gibbous and @fig:full.

#subpar.grid(
  figure(moon(1.5), caption: [Crescent.]), <fig:crescent>,
  figure(moon(1.0), caption: [First quarter.]), <fig:quarter>,
  figure(moon(0.5), caption: [Gibbous.]), <fig:gibbous>,
  figure(moon(0.0), caption: [Full.]), <fig:full>,
  columns: (1fr, 1fr, 1fr, 1fr),
  caption: [Four nights in the first half of the lunation.],
  label: <fig:phases>,
)

An ordinary figure in between keeps the count going:

#figure(
  tile(aqua.lighten(60%))[seeing: 2 arcsec],
  caption: [The seeing log, one bar.],
) <fig:seeing>

@fig:seeing is the second figure. The third has its own numbering for the
parts and for references to them.

#subpar.grid(
  figure(tile(red.lighten(60%))[R], caption: [Red filter.]), <fig:r>,
  figure(tile(green.lighten(60%))[G], caption: [Green filter.]), <fig:g>,
  figure(tile(blue.lighten(60%))[B], caption: [Blue filter.]), <fig:b>,
  grid.cell(colspan: 3, figure(
    tile(gradient.linear(red.lighten(60%), green.lighten(60%), blue.lighten(60%)))[R + G + B],
    caption: [The stacked frame, spanning the row.],
  )),
  columns: 3,
  gutter: 0.6em,
  numbering-sub: "i)",
  numbering-sub-ref: "1.i",
  caption: [Colour planes of one exposure.],
  label: <fig:rgb>,
)

In @fig:rgb the planes are @fig:r, @fig:g and @fig:b.

= Instruments

#subpar.grid(
  figure(
    polygon(fill: yellow.lighten(50%), stroke: 0.6pt, (0cm, 2cm), (1.5cm, 0cm), (3cm, 2cm)),
    caption: [Prism.],
  ), <fig:prism>,
  figure(
    ellipse(width: 3cm, height: 1.2cm, fill: aqua.lighten(70%), stroke: 0.6pt),
    caption: [Lens.],
  ), <fig:lens>,
  figure(
    {
      line(length: 3cm, stroke: 2pt)
      v(-0.6em)
      line(length: 3cm, angle: 20deg, stroke: (dash: "dashed"))
    },
    caption: [Mirror with a reflected ray.],
  ), <fig:mirror>,
  figure(
    grid(columns: 6, gutter: 2pt, ..range(18).map(i => square(size: 0.42cm, fill: luma(60 + 10 * i)))),
    caption: [Detector.],
  ), <fig:ccd>,
  columns: (1fr, 1fr),
  rows: (auto, auto),
  align: center + horizon,
  row-gutter: 1.5em,
  stroke: (x, y) => if x == 0 { (right: 0.4pt + gray) },
  inset: 4pt,
  numbering: n => numbering("I", n),
  numbering-sub: (sup, sub) => numbering("I-a", sup, sub),
  numbering-sub-ref: (sup, sub) => [#numbering("I", sup)/#numbering("a", sub)],
  supplement: [Plate],
  caption: [Optical parts, with roman plate numbers.],
  label: <fig:optics>,
)

Light passes @fig:prism or @fig:lens, is folded by @fig:mirror and lands on
@fig:ccd; all four are on @fig:optics.

#pagebreak()

= With sub figures in the list

#subpar.grid(
  figure(tile(luma(220))[dusk], caption: [Dusk flat.]),
  figure(tile(luma(120), text(white)[dark]), caption: [Dark frame.]),
  figure(tile(luma(180))[bias], caption: [Bias frame.]),
  columns: (1fr, 1fr, 1fr),
  outlined-sub: true,
  propagate-supplement: false,
  supplement: [Calibration set],
  caption: [Calibration frames, each listed on its own.],
  label: <fig:calib>,
)

#outline(title: [Everything, including parts], target: figure)

See @fig:calib, and back on the first page @fig:phases with @fig:full.
