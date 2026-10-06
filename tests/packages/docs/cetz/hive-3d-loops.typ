// cetz 0.5.2: ortho and perspective projections (depth sorting, face
// culling, on-xy/on-xz/on-zy planes), a computed surface, and large composed
// 2D figures from loops (honeycomb, polar dance diagram, a linear congruential
// generator for jitter). Many drawables per canvas; vector/matrix helpers.

#import "@preview/cetz:0.5.2"

#set page(width: 18cm, height: 24cm, margin: 1.5cm, numbering: "1 / 1")
#set heading(numbering: "1.1")
#set figure(gap: 0.8em)

// A small deterministic generator: returns (value in [0, 1), next state).
#let lcg(s) = {
  let n = calc.rem(s * 1103515245 + 12345, 2147483648)
  (n / 2147483648, n)
}

= The hive in three views

A hive is a stack of boxes. @fig-stack draws it in an isometric projection,
each box from three visible faces, with the faces sorted by depth.

#let box3(pos, size, paint: yellow) = {
  import cetz.draw: *
  let (x, y, z) = pos
  let (w, h, d) = size
  // top (xz plane at y + h), front (xy plane at z + d), side (zy plane at x + w)
  on-xz(y: y + h, rect((x, z), (x + w, z + d), fill: paint.lighten(40%), stroke: 0.5pt))
  on-xy(z: z + d, rect((x, y), (x + w, y + h), fill: paint, stroke: 0.5pt))
  on-zy(x: x + w, rect((z, y), (z + d, y + h), fill: paint.darken(15%), stroke: 0.5pt))
}
// A label on the front face of such a box.
#let front-label(pos, size, label) = {
  import cetz.draw: *
  let (x, y, z) = pos
  let (w, h, d) = size
  on-xy(z: z + d, content((x + w / 2, y + h / 2), text(8pt, label)))
}

#let stack = (
  ((0, 0, 0), (4, 1.6, 3), orange.lighten(30%), [brood]),
  ((0, 1.6, 0), (4, 1.6, 3), orange.lighten(50%), [brood]),
  ((0, 3.2, 0), (4, 1, 3), yellow.lighten(20%), [honey]),
  ((0, 4.2, 0), (4, 1, 3), yellow.lighten(40%), [honey]),
)

#figure(
  grid(
    columns: (1fr, 1fr),
    align: center + bottom,
    cetz.canvas(length: 0.8cm, {
      import cetz.draw: *
      // Faces are sorted by depth, whatever the order of the calls.
      ortho({
        box3((-0.2, 5.2, -0.2), (4.4, 0.3, 3.4), paint: silver)
        for (pos, size, paint, _) in stack.rev() {
          box3(pos, size, paint: paint)
        }
        box3((-0.3, -0.4, -0.3), (4.6, 0.4, 3.6), paint: gray)
      })
      // Labels and axes go on top, in drawing order.
      ortho(sorted: false, {
        for (pos, size, _, label) in stack {
          front-label(pos, size, label)
        }
        line((0, -0.4, 3.9), (1.5, -0.4, 3.9), stroke: red, mark: (end: ">"), name: "x")
        line((4.9, -0.4, 3.3), (4.9, -0.4, 1.8), stroke: blue, mark: (end: ">"), name: "z")
        content("x.end", anchor: "north-west", text(8pt, fill: red)[$x$])
        content("z.end", anchor: "north-west", text(8pt, fill: blue)[$z$])
      })
    }),
    cetz.canvas(length: 0.8cm, {
      import cetz.draw: *
      // The lower three boxes, turned and seen from higher up, painted in
      // drawing order.
      ortho(x: 50deg, y: 30deg, sorted: false, {
        for (pos, size, paint, label) in stack.slice(0, 3) {
          box3(pos, size, paint: paint)
          front-label(pos, size, label)
        }
        // Ten frames hang in the top box.
        on-xz(y: 4.2, {
          for i in range(10) {
            rect((0.25 + i * 0.37, 0.15), (0.4 + i * 0.37, 2.85), fill: maroon, stroke: none)
          }
        })
      })
    }),
  ),
  caption: [The stack in the default isometric view (left) and turned, with
    the top box open (right).],
) <fig-stack>

== Temperature over the brood nest

The cluster keeps its centre near 35 °C. @fig-surface plots a model of the
temperature over one frame as a surface of quadrilaterals; each quad is
coloured by its height, and the projection sorts them back to front.

#let temp(x, y) = 1.8 * calc.exp(-(x * x + y * y) / 3.5) + 0.15 * calc.cos(2.2 * x) * calc.sin(1.7 * y)

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let n = 14
    let lo = -3.0
    let step = 6.0 / n
    ortho(x: 28deg, y: 38deg, {
      for i in range(n) {
        for j in range(n) {
          let x0 = lo + i * step
          let z0 = lo + j * step
          let x1 = x0 + step
          let z1 = z0 + step
          let h = temp(x0 + step / 2, z0 + step / 2)
          let t = calc.clamp(h / 1.9, 0, 1) * 100%
          line(
            (x0, temp(x0, z0), z0),
            (x1, temp(x1, z0), z0),
            (x1, temp(x1, z1), z1),
            (x0, temp(x0, z1), z1),
            close: true,
            fill: color.mix((red, t), (blue.lighten(60%), 100% - t)),
            stroke: 0.2pt + luma(60),
          )
        }
      }
      // Floor frame and axis labels.
      line((lo, 0, -lo), (-lo, 0, -lo), mark: (end: "stealth", fill: black), name: "xa")
      line((-lo, 0, -lo), (-lo, 0, lo), mark: (end: "stealth", fill: black), name: "za")
      line((lo, 0, -lo), (lo, 2.2, -lo), mark: (end: "stealth", fill: black), name: "ya")
      content("xa.mid", anchor: "north-east", padding: 3pt, text(8pt)[width])
      content("za.mid", anchor: "north-west", padding: 3pt, text(8pt)[height])
      content("ya.end", anchor: "south", padding: 2pt, text(8pt)[$T$])
    })
  }),
  caption: [Model temperature over a frame, #(14 * 14) quads.],
) <fig-surface>

#pagebreak()

== Perspective

The entrance side in a perspective projection: the landing board recedes
towards the hive wall. Here the faces are painted in the order they are
drawn, without depth sorting.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    perspective(x: 20deg, y: 30deg, distance: 9, sorted: false, {
      on-xz(y: 0, {
        rect((-3, -2), (3, 2), fill: olive.lighten(60%), stroke: 0.5pt)
        for i in range(-2, 3) {
          line((i, -2), (i, 2), stroke: 0.3pt + olive)
        }
      })
      on-xy(z: -2, {
        rect((-3, 0), (3, 2.5), fill: orange.lighten(60%), stroke: 0.5pt)
        rect((-1.2, 0), (1.2, 0.25), fill: black)
        content((0, 1.4), text(10pt, weight: "bold")[No. 7])
      })
      on-zy(x: 3, rect((-2, 0), (2, 2.5), fill: orange.lighten(30%), stroke: 0.5pt))
      for (x, z) in ((-2, 1), (0.5, 0.2), (1.8, 1.5), (-0.6, -0.9)) {
        on-xz(y: 0.02, circle((x, z), radius: (0.18, 0.09), fill: yellow, stroke: 0.4pt))
      }
    })
  }),
  caption: [Landing board with four bees, perspective distance 9.],
) <fig-entrance>

= The comb

Cells are regular hexagons. In axial coordinates $(q, r)$ the centre of a
cell with circumradius $s$ lies at
$ x = s sqrt(3) (q + r / 2), quad y = 3 / 2 s r. $
@fig-comb fills a patch of comb; what a cell holds depends on its distance
from the centre, with a little seeded jitter.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let s = 0.34
    let seed = 20240607
    let radius = 7
    for q in range(-radius, radius + 1) {
      for r in range(calc.max(-radius, -q - radius), calc.min(radius, -q + radius) + 1) {
        let x = s * calc.sqrt(3) * (q + r / 2)
        let y = 1.5 * s * r
        let dist = (calc.abs(q) + calc.abs(r) + calc.abs(q + r)) / 2
        let (u, next) = lcg(seed)
        seed = next
        let d = dist + (u - 0.5) * 1.6
        let fill = if d < 2.6 { rgb("#f6e7c8") } else if d < 4.4 { rgb("#d9a441") } else if d < 6 { rgb("#f2c230") } else { white }
        polygon((x, y), 6, radius: s, angle: 30deg, fill: fill, stroke: 0.4pt + rgb("#7a5a12"))
        if d < 2.6 and u > 0.35 {
          circle((x, y), radius: s * 0.3, fill: white, stroke: 0.3pt)
        }
      }
    }
    // Legend, placed relative to the comb.
    let entries = ((rgb("#f6e7c8"), [brood]), (rgb("#d9a441"), [pollen]), (rgb("#f2c230"), [honey]), (white, [empty]))
    for (i, (c, l)) in entries.enumerate() {
      polygon((5.4, 1.2 - i * 0.8), 6, radius: 0.26, angle: 30deg, fill: c, stroke: 0.4pt + rgb("#7a5a12"))
      content((5.85, 1.2 - i * 0.8), anchor: "west", text(9pt, l))
    }
  }),
  caption: [A patch of #(3 * 7 * 8 + 1) cells.],
) <fig-comb>

== The waggle dance

A forager reports a source by the angle of her run against the vertical.
@fig-dance draws eight reported sources on a compass: the direction is the
bearing, the length of the wavy run grows with the distance.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    import cetz: decorations, vector
    let ring(r, style) = circle((0, 0), radius: r, ..style)
    for r in (1, 2, 3) {
      ring(r, (stroke: (paint: luma(170), dash: "dashed", thickness: 0.4pt)))
      content((45deg, r), text(7pt, fill: luma(100))[#(r * 400) m], frame: "rect", stroke: none, fill: white, padding: 1pt)
    }
    for (i, d) in ("E", "N", "W", "S").enumerate() {
      line((i * 90deg, 3), (i * 90deg, 3.35), stroke: 0.5pt)
      content((i * 90deg, 3.6), text(9pt, weight: "bold", d))
    }
    let sources = ((12deg, 2.6, "lime"), (58deg, 1.4, "rape"), (97deg, 3.0, "clover"), (140deg, 0.9, "willow"), (188deg, 2.1, "heather"), (230deg, 1.7, "bramble"), (275deg, 2.8, "chestnut"), (322deg, 1.2, "ivy"))
    for (k, (a, r, plant)) in sources.enumerate() {
      let tip = (a, r)
      let col = color.hsv(a, 70%, 75%)
      decorations.wave(line((0, 0), tip), amplitude: 0.12, segment-length: 0.28, stroke: col + 1pt)
      circle(tip, radius: 2.5pt, fill: col, stroke: none)
      // Push the label outwards along the bearing.
      let off = vector.scale((calc.cos(a), calc.sin(a)), 0.45)
      content((rel: off, to: tip), text(7pt, plant))
    }
    circle((0, 0), radius: 3pt, fill: black)
  }),
  caption: [Bearings and distances of eight sources, reported on one
    afternoon.],
) <fig-dance>

The figures of this report are @fig-stack, @fig-surface, @fig-entrance,
@fig-comb and @fig-dance.
