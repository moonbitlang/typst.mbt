// wrap-it 0.1.1: wrap-content left/right/top/bottom around drawn figures,
// wrap-top-bottom, grid arguments (gutter, fixed columns), styled and
// emphasised text being split, several wraps across page breaks.
// Stresses repeated measure() inside layout(), content introspection
// (fields(), func(), rebuilding styled elements), grids of two rows.
#import "@preview/wrap-it:0.1.1": wrap-content, wrap-top-bottom

#set page(width: 13cm, height: 17cm, margin: 1.3cm, numbering: "1")
#set text(size: 9.5pt)
#set par(justify: true)
#set heading(numbering: "1.")
#set figure.caption(separator: [ --- ])

#let leaf(fill, w: 2.6cm, h: 2cm) = box(width: w, height: h, {
  place(ellipse(width: w, height: h, fill: fill, stroke: 0.6pt + fill.darken(40%)))
  place(dx: 0.1 * w, dy: h / 2, line(length: 0.8 * w, stroke: 0.5pt + fill.darken(50%)))
  for i in range(1, 5) {
    place(dx: i * w / 6 + 0.1 * w, dy: h / 2, line(length: 0.25 * h, angle: -55deg, stroke: 0.3pt + fill.darken(50%)))
    place(dx: i * w / 6 + 0.1 * w, dy: h / 2, line(length: 0.25 * h, angle: 55deg, stroke: 0.3pt + fill.darken(50%)))
  }
})

#let plate(fill, caption, ..args) = figure(leaf(fill, ..args), caption: caption)

= Trees of the river bank

#wrap-content(
  plate(green.lighten(30%))[Alder],
  [
    The alder stands with its feet in the water. Its leaves are round and
    blunt, often notched at the tip, and stay green until they fall. In
    winter the small woody cones remain on the twigs and are the surest
    way to tell it from a distance. The wood turns orange when cut and
    lasts for centuries under water, which is why half the old quays of
    the town rest on it.
  ],
)

#wrap-content(
  plate(olive.lighten(20%), w: 3.2cm, h: 1.2cm)[White willow],
  [
    The white willow has narrow leaves, silvery beneath, that turn in the
    slightest wind so that the whole tree seems to change colour.
    *Pollarded willows are cut every few years at head height;* the shoots
    were once used for baskets and hurdles, _and the hollow trunks that
    result shelter owls, bats and the occasional fisherman caught by rain._
    A willow twig pushed into wet ground will root within a season.
  ],
  align: right,
)

#wrap-content(
  plate(yellow.darken(10%))[Black poplar],
  text(fill: navy)[
    The black poplar is the rarest of the three. Its leaves are triangular
    with a drawn-out tip and tremble on flattened stalks. Old trees lean,
    carry heavy burrs on the trunk, and shed red catkins in April that lie
    on the path like caterpillars. Most poplars seen along roads are
    hybrids planted for timber; the native tree survives where the river
    still floods.
  ],
  align: bottom + right,
  column-gutter: 2em,
)

= Shrubs

#wrap-content(
  box(inset: (bottom: 0.4em, right: 0.3em), plate(red.lighten(40%), w: 2cm, h: 2.4cm)[Guelder rose]),
  [
    The guelder rose has leaves with three lobes, like a small maple, and
    flat heads of white flowers ringed by larger sterile ones. The berries
    are translucent red and hang on long after the leaves have gone.
    #highlight[Birds leave them until hard frost has taken the bitterness
    away.] In autumn the foliage turns the colour of wine. #lorem(30)
  ],
  align: bottom,
  columns: (35%, 65%),
)

#wrap-top-bottom(
  plate(teal.lighten(40%))[Dogwood, in leaf],
  plate(maroon.lighten(30%), w: 3cm, h: 1cm)[Dogwood, a winter twig],
  [
    Dogwood is known by its stems, which are blood red on the side that
    faces the sun. The leaves are oval with veins that curve towards the
    tip; tear one gently across and the halves hang together by fine
    threads. #lorem(45) The black berries are bitter and were pressed for
    lamp oil. #lorem(40)
  ],
)

= One more, at the left, with a fixed size

#context wrap-content(
  rect(width: 2.4cm, height: 2.4cm, radius: 0.3cm, fill: gradient.linear(green.lighten(40%), yellow, angle: 45deg), stroke: 0.5pt),
  [#lorem(55)],
  size: (width: 8cm, height: 10cm),
)

#wrap-content(
  circle(radius: 0.9cm, fill: gradient.radial(white, orange)),
  [A short text that never reaches below the circle is not split at all.],
  align: right,
)
