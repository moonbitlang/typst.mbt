// meander 0.4.4: `meander.reflow` fails with Typst 0.15 (see error-reflow),
// so this document drives the package's engine itself: elements from
// placed/container/content, `tiling` (separate, create-data, next-elem,
// push-elem) for the zones around obstacles, `internals.fill-box` for the
// bisection of content, and the contour functions (margin, grid, horiz,
// width, ascii-art, phantom), tags with `invisible`, and a query callback.
// Stresses measure() in layout(), deep content introspection and rebuilding
// (paragraphs, strong/emph, lists, math), many placed boxes, three pages.
#import "@preview/meander:0.4.4"

#let tiling = meander.contour.tiling
#let fill-box = meander.internals.fill-box

// Lays out one page of elements and threads `body` through its containers.
// Returns the placed content and what did not fit.
#let flow-page(size, elems, body, debug: false) = {
  let out = []
  let data = tiling.create-data(size: size, elems: elems)
  while true {
    let (elem, next) = tiling.next-elem(data)
    data = next
    if elem == none { break }
    if elem == () { continue }
    if elem.type == place {
      if elem.display { out += elem.content }
      data = tiling.push-elem(data, elem)
      if debug {
        for b in elem.contour {
          out += place(dx: b.x, dy: b.y, box(width: b.width, height: b.height, stroke: 0.3pt + red, fill: red.transparentize(90%)))
        }
      }
      continue
    }
    for zone in elem.contour {
      if body == none { break }
      // A zone may not grow beyond the bounds of its container (which the
      // package keeps a hair below the full height, because `measure`
      // cannot see beyond the region it is given).
      zone.height = calc.min(zone.y + zone.height, zone.bounds.y + zone.bounds.height) - zone.y
      let dims = measure(box(width: zone.width, height: zone.height), ..size)
      let (fits, rest) = fill-box(dims, body, size: size)
      if fits == none { continue }
      let used = measure(box(width: zone.width, fits), ..size).height
      if used < 1mm { continue }
      let styled = fits
      if "text-fill" in zone.style { styled = text(fill: zone.style.text-fill, styled) }
      if "align" in zone.style { styled = align(zone.style.align, styled) }
      out += place(dx: zone.x, dy: zone.y, box(
        width: zone.width,
        height: zone.height,
        stroke: if debug { 0.3pt + green.darken(20%) },
        styled,
      ))
      data = tiling.push-elem(data, (contour: (tiling.add-self-margin((..zone, height: used)),)))
      body = rest
    }
  }
  (out, body)
}

// A stand-in for `meander.reflow` on a fresh page (or in a box of a given
// height): every page of the sequence becomes one block.
#let flow-around(seq, height: auto, debug: false, leftover: rest => rest) = layout(size => {
  let size = if height == auto { size } else { (width: size.width, height: height) }
  let (flow, pages, opts) = tiling.separate(seq)
  let body = flow.map(f => f.data).join()
  for (i, elems) in pages.enumerate() {
    if i > 0 { colbreak() }
    let (out, rest) = flow-page(size, elems, body, debug: debug)
    block(width: size.width, height: size.height, breakable: false, out)
    body = rest
  }
  if body != none { leftover(body) }
})

#set page(width: 14cm, height: 19cm, margin: 1.2cm)
#set text(size: 9pt)
#set par(justify: true)

#let chart(w, h, fill, label) = box(width: w, height: h, fill: fill, stroke: 0.5pt + fill.darken(40%), radius: 2pt, align(center + horizon, text(fill: fill.darken(60%), size: 8pt, label)))

#flow-around({
  import meander: *

  placed(top + left, block(width: 100%, inset: (bottom: 4pt), stroke: (bottom: 1.5pt))[
    #text(size: 18pt, weight: "bold")[An atlas of small islands]
    #h(1fr) #text(size: 8pt)[sheet 1]
  ])
  placed(top + right, dy: 1.2cm, chart(4.5cm, 3.2cm, aqua.lighten(50%), [the anchorage]))
  placed(horizon + left, dy: 1cm, chart(3.2cm, 4cm, yellow.lighten(40%), [the dunes]))
  placed(bottom + right, chart(5cm, 2.2cm, green.lighten(50%), [the saltings]))
  placed(bottom + left, dx: 15%, chart(2.4cm, 1.6cm, orange.lighten(40%), [light]))

  container()

  content[
    *The island is two kilometres long and nowhere more than four metres
    above the spring tides.* It has no trees, one well, and a light on an
    iron tower at the western end. The ferry calls on Tuesdays if the bar
    allows.

    #lorem(90)

    What a visitor should bring:
    - boots, because the path floods,
    - water, because the well is brackish in summer,
    - _patience_, because the ferry keeps its own time.

    The area exposed at low water grows roughly as $A(h) = A_0 + k h^2$,
    where $h$ is the fall of the tide below the mean. #lorem(140)
  ]
})

#pagebreak()

#flow-around(debug: true, {
  import meander: *

  placed(top + left, block(width: 100%)[
    #text(size: 14pt, weight: "bold")[Contours, with the zones drawn]
  ])
  placed(
    center + horizon,
    boundary: contour.margin(3mm) + contour.grid(div: 14, (x, y) => calc.pow(2 * x - 1, 2) + calc.pow(2 * y - 1, 2) <= 1),
    circle(radius: 2cm, fill: gradient.radial(white, blue.lighten(60%)), stroke: 0.5pt + blue.darken(20%), align(center + horizon, text(size: 8pt)[the\ lagoon])),
  )
  placed(
    bottom + left,
    boundary: contour.horiz(div: 8, y => (0, 1 - y)) + contour.margin(2mm),
    polygon(fill: olive.lighten(50%), stroke: 0.5pt, (0cm, 0cm), (3.5cm, 0cm), (0cm, 3.5cm)),
    tags: <spit>,
  )
  placed(
    top + right,
    dy: 1cm,
    boundary: contour.width(div: 6, flush: right, y => (0, 0.3 + 0.7 * y)),
    polygon(fill: maroon.lighten(60%), stroke: 0.5pt, (2.1cm, 0cm), (3cm, 0cm), (3cm, 3cm), (0cm, 3cm)),
  )
  placed(
    bottom + right,
    boundary: contour.ascii-art(
      ```
       .#.
      [###]
      ##_##
      ```,
    ),
    chart(3cm, 2.4cm, purple.lighten(60%), [a hut, in ascii]),
  )
  placed(horizon + right, dy: 3cm, boundary: contour.phantom(), text(size: 30pt, fill: gray.transparentize(60%))[N])

  container(width: 48%, style: (text-fill: navy))
  container(align: right, width: 48%, margin: 3mm)

  content[
    The lagoon in the middle of the sheet is a circle, cut out of both
    columns by a grid of small obstacles. #lorem(150)

    The spit in the corner slopes, the cliff at the top right is flush with
    the margin, and the letter N lets the text run over it. #lorem(190)
  ]
})

#pagebreak()

#text(size: 14pt, weight: "bold")[A box inside a page]

The same engine in a box of fixed height that shares its page with ordinary
paragraphs. The second container ignores the tagged obstacle, and the
caption below the picture is placed by a callback that asks where the
picture ended up.

#flow-around(
  height: 7cm,
  leftover: rest => block(stroke: (left: 2pt + orange), inset: (left: 6pt))[#text(fill: orange.darken(30%))[#rest]],
  {
    import meander: *

    placed(top + center, chart(4cm, 2.5cm, red.lighten(60%), [the wreck]), tags: <wreck>)
    callback(env: (below: query.position(<wreck>, at: bottom + left), w: query.width(<wreck>)), env => {
      placed(env.below, boundary: contour.margin(1mm), box(width: env.w, align(center, text(size: 7pt, style: "italic")[lost in the gale of the third winter])))
    })

    container(width: 30%, height: 100%, style: (align: left))
    container(align: top + right, width: 30%, height: 100%, style: (align: right))
    container(align: bottom + center, width: 34%, height: 45%, invisible: <wreck>, style: (text-fill: maroon))

    content[#lorem(75)]
    content(size: 8pt)[
      + first the mast went,
      + then the rudder,
      + then the cargo of slates.

      #lorem(120)
    ]
  },
)

Text after the box continues normally. The orange rule marks what did not
fit into the three containers.
