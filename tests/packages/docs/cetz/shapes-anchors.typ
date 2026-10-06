// cetz 0.5.2: basic shapes, paths, named anchors, relative/polar/barycentric
// coordinates, transforms and style cascades, in figures with captions and
// references. Stresses the wasm plugin, measure of content nodes, nested
// groups, boolean path operations and context-dependent canvas lengths.

#import "@preview/cetz:0.5.2"

#set page(width: 16cm, height: 21cm, margin: 1.4cm, numbering: "1")
#set heading(numbering: "1.1")
#set par(justify: true)
#set figure(placement: none)

= Workshop sheet: a wall bracket

The bracket in @fig-outline holds a shelf of 30 cm depth. It is cut from a
plate, bent once, and drilled three times. Every drawing on this sheet is made
from the same handful of primitives; @fig-prims lists them.

#figure(
  cetz.canvas(length: 0.9cm, {
    import cetz.draw: *
    set-style(stroke: 0.6pt)
    rect((0, 0), (2, 1.2), name: "r", fill: aqua.lighten(60%))
    content("r.center", [rect])
    circle((3.4, 0.6), radius: 0.6, name: "c", fill: yellow.lighten(40%))
    content("c.center", [circle])
    circle((5.4, 0.6), radius: (0.9, 0.5), name: "e", stroke: (dash: "dashed"))
    content("e.center", [ellipse])
    arc((7, 0.2), start: 0deg, stop: 140deg, radius: 0.8, mode: "PIE", fill: lime.lighten(50%), name: "a")
    content((rel: (0, -0.5), to: "a.origin"), text(8pt)[pie arc])
    polygon((9.4, 0.6), 6, radius: 0.7, fill: orange.lighten(60%), name: "p")
    content("p.center", [6])
    n-star((11.4, 0.6), 5, radius: 0.75, inner-radius: 0.35, fill: red.lighten(60%), name: "s")
    line((0, -0.6), (2, -0.6), (2.6, -1.2), (4.2, -1.2), name: "l", stroke: blue)
    content("l.mid", anchor: "south", padding: 2pt, text(8pt)[polyline])
    rect((5, -1.5), (7.2, -0.5), radius: (north-east: 0.4, south-west: 0.4, rest: 0), stroke: purple + 1pt)
    circle-through((8, -1.4), (9, -0.5), (9.8, -1.3), stroke: teal, name: "ct")
    for pt in ((8, -1.4), (9, -0.5), (9.8, -1.3)) {
      circle(pt, radius: 1.5pt, fill: black)
    }
    arc-through((10.4, -1.4), (11.2, -0.5), (12, -1.4), stroke: maroon + 1.2pt)
  }),
  caption: [The primitives used below: rectangles, circles, arcs, regular
    polygons, stars and polylines.],
) <fig-prims>

== Outline and holes

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    // The outline is one merged path, so that it can be filled.
    merge-path(fill: luma(225), stroke: 1pt, close: true, name: "outline", {
      line((0, 0), (6, 0), (6, 1))
      arc((), start: 0deg, delta: 90deg, radius: 0.5)
      line((), (1.5, 1.5))
      bezier((), (1, 2), (1, 1.5))
      line((), (1, 5))
      arc((), start: 0deg, delta: 180deg, radius: 0.5)
      line((), (0, 0))
    })
    // Holes with centre marks.
    let hole(pos, name, r: 0.22) = {
      circle(pos, radius: r, fill: white, name: name)
      line((rel: (-r - 0.15, 0), to: pos), (rel: (r + 0.15, 0), to: pos), stroke: (thickness: 0.3pt, dash: "dash-dotted"))
      line((rel: (0, -r - 0.15), to: pos), (rel: (0, r + 0.15), to: pos), stroke: (thickness: 0.3pt, dash: "dash-dotted"))
    }
    hole((0.5, 4.5), "h1")
    hole((0.5, 2.5), "h2")
    hole((5, 0.5), "h3", r: 0.3)

    // Dimension lines.
    set-style(mark: (fill: black, scale: 0.7), stroke: 0.4pt)
    let dim(a, b, label, off: (0, -0.5), anchor: "north") = {
      line((rel: off, to: a), (rel: off, to: b), mark: (start: "stealth", end: "stealth"), name: "d")
      line(a, (rel: off, to: a), stroke: 0.2pt)
      line(b, (rel: off, to: b), stroke: 0.2pt)
      content("d.mid", anchor: anchor, padding: 2pt, text(8pt, label))
    }
    dim((0, 0), (6, 0), [60])
    dim((6, 0), (6, 1.5), [15], off: (0.6, 0), anchor: "west")
    dim((0, 0), (0, 5.5), [55], off: (-0.6, 0), anchor: "east")
    dim("h1.center", "h2.center", [20], off: (1.6, 0), anchor: "west")

    // A leader with a relative polar coordinate.
    line("h3.north-east", (rel: (50deg, 1.2)), (rel: (0.8, 0)), name: "lead")
    content("lead.end", anchor: "west", padding: 2pt, text(8pt)[$diameter 6$])
    content((3.2, 0.5), text(8pt, style: "italic")[plate, 3 mm])
  }),
  caption: [Outline of the bracket with its three holes. Lengths in
    millimetres, scale 1:10.],
) <fig-outline>

The outline is a single closed path (`merge-path`), built from lines, two
arcs and one quadratic Bézier segment. The holes are drawn on top with a
white fill. Their anchors `h1.center` and `h2.center` are reused by the
dimension lines.

== Anchors

Every element has anchors, and @fig-anchors shows the ones of a rectangle and
of a circle. A point between two anchors is written with an interpolation
coordinate; a point on the border with an angle.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    rect((0, 0), (4, 2.4), name: "box", fill: blue.lighten(90%))
    for-each-anchor("box", exclude: ("start", "end", "mid"), name => {
      circle("box." + name, radius: 1.6pt, fill: red, stroke: none)
      content((rel: (0, 0.22), to: "box." + name), text(6pt, name))
    })
    circle((7, 1.2), radius: 1.2, name: "ring")
    for a in range(0, 360, step: 45) {
      let p = (name: "ring", anchor: a * 1deg)
      circle(p, radius: 1.4pt, fill: blue, stroke: none)
      content((rel: (a * 1deg, 0.32), to: p), text(6pt)[#a°])
    }
    line("box.east", "ring.west", mark: (end: ">"), name: "link")
    circle(("box.east", 50%, "ring.west"), radius: 2pt, fill: green)
    circle(("box.east", 0.3, "ring.west"), radius: 2pt, fill: orange)
    // Perpendicular and projection coordinates.
    line("box.north-east", ("box.north-east", "|-", "ring.north"), ("box.north-east", "-|", "ring.north"), stroke: (dash: "dotted"))
    // Barycentric combination of three anchors.
    circle((bary: ("box.north-west": 1, "box.south-east": 1, "ring.center": 2)), radius: 2.5pt, fill: purple, stroke: none)
  }),
  caption: [Named, angle and interpolated anchors.],
) <fig-anchors>

#pagebreak()

= Transformations <sec-transform>

A group opens a scope for transformations. In @fig-transform the same small
flag is drawn six times: plain, translated, rotated, scaled, mirrored and
sheared with an explicit matrix.

#let flag = {
  import cetz.draw: *
  line((0, 0), (0, 1.6), stroke: 1pt)
  line((0, 1.6), (1, 1.3), (0, 1), close: true, fill: red.lighten(30%))
  circle((0, 0), radius: 2pt, fill: black)
}

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    grid((-0.5, -0.5), (11.5, 2.5), step: 0.5, stroke: luma(220) + 0.3pt)
    let cell(x, label, body) = {
      group({
        translate((x, 0))
        body
      })
      content((x + 0.4, -0.8), text(8pt, label))
    }
    cell(0, [plain], flag)
    cell(2, [rotate], { rotate(-25deg); flag })
    cell(4, [scale], { scale(x: 1.4, y: 0.7); flag })
    cell(6.6, [mirror], { scale(x: -1); flag })
    cell(8, [shear], {
      transform(((1, 0.6, 0, 0), (0, 1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
      flag
    })
    cell(10, [origin], {
      set-origin((0.5, 0.5))
      rotate(90deg)
      flag
    })
  }),
  caption: [One drawing under six transformations.],
) <fig-transform>

== Styles

Styles cascade: `set-style` changes the defaults of all following elements
of a scope, and an element's own arguments win over them.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    set-style(stroke: (paint: navy, thickness: 1.2pt), fill: navy.lighten(80%))
    rect((0, 0), (1.5, 1))
    group({
      set-style(stroke: (dash: "dashed"), circle: (fill: yellow, radius: 0.4))
      circle((2.5, 0.5))
      circle((3.6, 0.5), fill: none)
      rect((4.3, 0), (5.8, 1), fill: gradient.linear(white, navy))
    })
    rect((6.3, 0), (7.8, 1), stroke: none)
    stroke(red)
    fill(none)
    line((8.3, 0), (9.8, 1))
    line((8.3, 1), (9.8, 0), stroke: (cap: "round", thickness: 3pt))
    // Line joins and caps.
    for (i, join) in ("miter", "round", "bevel").enumerate() {
      line((i * 2, -2), (i * 2 + 0.7, -1), (i * 2 + 1.4, -2), stroke: (paint: black, thickness: 5pt, join: join))
      content((i * 2 + 0.7, -2.4), text(8pt, join))
    }
    // A palette.
    let pal = cetz.palette.tango
    for i in range(6) {
      rect((6.2 + i * 0.6, -2), (6.7 + i * 0.6, -1), ..pal(i))
    }
    content((7.95, -2.4), text(8pt)[tango palette])
  }),
  caption: [Style cascade, line joins and a colour palette.],
) <fig-style>

== Cut-outs with boolean operations

The gusset of the bracket is a triangle with a round relief cut; the plate
washer is a ring. Both are computed from simpler outlines (@fig-bool).

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let ops = ("union", "intersection", "difference", "xor")
    for (i, op) in ops.enumerate() {
      group({
        translate((i * 3, 0))
        boolean(
          line((0, 0), (2, 0), (0, 2), close: true),
          circle((0.3, 0.3), radius: 0.9),
          op: op,
          fill: teal.lighten(50%),
          stroke: 0.8pt,
        )
        content((1, -0.4), text(8pt, op))
      })
    }
  }),
  caption: [The four boolean operations on a triangle and a circle.],
) <fig-bool>

== Drawings that follow the text

A canvas can read its surroundings. The ruler below is as wide as the text
block (measured with `layout`), and its tick labels use the current text
size.

#context layout(size => {
  let n = int(size.width / 1cm)
  let em = text.size
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    rect((0, 0), (n, 0.8), fill: yellow.lighten(70%), stroke: 0.5pt)
    for i in range(n + 1) {
      line((i, 0.8), (i, 0.45), stroke: 0.5pt)
      content((i, 0.2), text(0.6 * em)[#i])
      if i < n {
        for j in range(1, 10) {
          line((i + j / 10, 0.8), (i + j / 10, if j == 5 { 0.55 } else { 0.65 }), stroke: 0.25pt)
        }
      }
    }
  })
})

Inline drawings work too: the hole symbol
#box(baseline: 20%, cetz.canvas(length: 1em, {
  import cetz.draw: *
  circle((0, 0), radius: 0.4)
  line((-0.55, 0), (0.55, 0), stroke: 0.3pt)
  line((0, -0.55), (0, 0.55), stroke: 0.3pt)
}))
marks a drilled hole, and
#box(baseline: 20%, cetz.canvas(length: 1em, {
  import cetz.draw: *
  rect((0, -0.4), (0.9, 0.4))
  line((0, -0.4), (0.9, 0.4))
}))
marks a surface that stays unpainted. See @sec-transform for the flags and
@fig-style for the styles.
