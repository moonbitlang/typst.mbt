// cetz 0.5.2: tree layout (wasm plugin + measured nodes), grids, arcs and
// angle marks, bezier/catmull/hobby curves, the mark catalogue, path
// decorations and braces, content placement (anchors, rotation, frames,
// two-point boxes). Canvases in a table, a grid and inline; intersections.

#import "@preview/cetz:0.5.2"
#import cetz: angle, decorations, tree

#set page(width: 17cm, height: 22cm, margin: 1.5cm, header: context {
  if counter(page).get().first() > 1 [
    #text(9pt, style: "italic")[Orchard notebook] #h(1fr) #text(9pt)[#counter(page).display()]
  ]
})
#set heading(numbering: "1.")
#show figure.caption: set text(9pt)

= What grows here

The orchard has eleven trees of four kinds. The diagram groups them the way
the nursery catalogue does.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    set-style(content: (padding: 0.12), stroke: 0.5pt)
    tree.tree(
      (
        [*Fruit trees*],
        ([Pome], ([Apple], [Boskoop], [Topaz], [Rubinette]), ([Pear], [Conference], [Williams])),
        ([Stone], ([Plum], [Mirabelle]), ([Cherry], [Morello], [Regina], [Kordia])),
      ),
      spread: 0.38,
      grow: 1.4,
      draw-node: node => {
        let leaf = node.children.len() == 0
        if leaf {
          content((), angle: 90deg, anchor: "east", frame: "rect", fill: green.lighten(80%), stroke: 0.4pt, padding: 0.1, text(8pt, node.content))
        } else {
          content((), frame: if node.depth == 0 { "rect" } else { "circle" }, fill: if node.depth == 0 { yellow.lighten(60%) } else { white }, padding: 0.1, text(9pt, node.content))
        }
      },
      draw-edge: (from, to) => {
        line(from.group-name, to.group-name, stroke: if to.children.len() == 0 { (dash: "dotted") } else { 0.6pt })
      },
      name: "t",
    )
  }),
  caption: [Kinds and varieties. Leaves are set upright to save width.],
) <fig-taxonomy>

A second tree, grown to the right with the default node and edge drawing,
gives the order of work in a year:

#align(center, cetz.canvas(length: 1cm, {
  import cetz.draw: *
  set-style(content: (padding: 0.1, frame: "rect", stroke: 0.4pt))
  tree.tree(
    ([Year], ([Winter], [prune], [graft]), ([Spring], [mulch]), ([Summer], [thin], [water], [net]), ([Autumn], [pick], [press])),
    direction: "right",
    grow: 1.8,
    spread: 0.3,
  )
}))

= Planting plan

#figure(
  cetz.canvas(length: 0.85cm, {
    import cetz.draw: *
    // The plot: a coarse and a fine grid.
    grid((0, 0), (12, 6), step: 0.5, stroke: luma(230) + 0.25pt)
    grid((0, 0), (12, 6), step: 2, stroke: luma(160) + 0.4pt, name: "plot")
    rect((0, 0), (12, 6), stroke: 1pt)
    // Trees: (column, row, kind).
    let kinds = (a: (green, [A]), p: (olive, [P]), m: (purple, [M]), c: (red, [C]))
    let trees = (
      (1, 5, "a"), (3, 5, "a"), (5, 5, "a"), (7, 5, "p"), (9, 5, "p"),
      (1, 3, "c"), (3, 3, "c"), (5, 3, "c"), (9, 3, "m"), (11, 3, "m"), (11, 5, "c"),
    )
    for (i, (x, y, k)) in trees.enumerate() {
      let (col, letter) = kinds.at(k)
      circle((x, y), radius: 0.55, fill: col.lighten(70%), stroke: col + 0.6pt, name: "tree" + str(i))
      content((x, y), text(8pt, weight: "bold", letter))
    }
    // The hose: a smooth curve through chosen points, with its control polygon.
    hobby((0, 1), (2, 1.6), (4, 0.8), (7, 1.8), (10, 1.2), (12, 2), stroke: blue + 1.4pt, name: "hose")
    catmull((0, 0.4), (3, 0.3), (6, 0.9), (9, 0.3), (12, 0.6), tension: 0.4, stroke: (paint: blue.lighten(40%), dash: "dashed"), name: "drip")
    content("hose.50%", anchor: "south", padding: 3pt, text(7pt, fill: blue)[main hose])
    content("drip.75%", anchor: "north", padding: 3pt, text(7pt, fill: blue)[drip line])
    // The path to the shed crosses the hose; mark the crossings.
    bezier((6, 6), (8, 0), (4.5, 4), (9.5, 2.2), stroke: (paint: maroon, thickness: 1pt, dash: "dash-dotted"), name: "path")
    intersections("x", "path", "hose", "drip")
    for-each-anchor("x", name => {
      circle("x." + name, radius: 3pt, stroke: maroon, fill: white)
    })
    // Scale bar and north arrow.
    line((0, -0.6), (2, -0.6), mark: (start: "|", end: "|"), name: "bar")
    content("bar.mid", anchor: "north", padding: 2pt, text(7pt)[4 m])
    line((11.2, -1.1), (11.2, -0.2), mark: (end: "stealth", fill: black))
    content((11.6, -0.6), text(8pt)[N])
    // Braces along the rows.
    decorations.brace((0.4, 5.8), (9.6, 5.8), name: "pome")
    content("pome.content", text(8pt)[pome fruit])
    decorations.flat-brace((11.6, 2.4), (8.4, 2.4), name: "plums")
    content("plums.content", text(8pt)[plums])
  }),
  caption: [Plan of the plot. A apple, P pear, M plum, C cherry; the circles
    on the dash-dotted path mark where it crosses the hoses.],
) <fig-plan>

#pagebreak()

= Sun and shade

The lowest branches should see the sun at noon in March. With the neighbour's
hedge at height $h$ and distance $d$ the limiting angle is
$alpha = arctan(h slash d)$; @fig-sun shows the three angles that matter.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    let o = (0, 0)
    line((-0.5, 0), (9, 0), stroke: 0.8pt, name: "ground")
    decorations.zigzag(line((6.5, 0), (6.5, 2.2)), amplitude: 0.15, segment-length: 0.25, stroke: green.darken(30%))
    content((6.5, 2.5), text(8pt)[hedge])
    for (a, col, lab) in ((18.7deg, orange, $alpha$), (40deg, red, $beta$), (63deg, maroon, $gamma$)) {
      line(o, (a, 5), stroke: col + 0.6pt, name: "ray")
      angle.angle(o, (1, 0), (a, 1), radius: 1.2 + a / 40deg, label: text(8pt, lab), stroke: col, mark: (end: ">", scale: 0.6), label-radius: 110%)
    }
    arc((5, 0), start: 0deg, stop: 180deg, radius: 5, stroke: (dash: "dotted"), anchor: "start")
    // The sun at three positions on the dotted arc.
    for a in (18.7deg, 40deg, 63deg) {
      n-star((a, 5), 8, radius: 0.28, inner-radius: 0.16, fill: yellow, stroke: 0.4pt)
    }
    angle.right-angle((6.5, 0), (6.5, 1), (5.5, 0), radius: 0.3, label: none)
    decorations.brace((6.5, -0.15), (0, -0.15), name: "d")
    content("d.content", $d$)
    decorations.brace((6.7, 2.2), (6.7, 0), name: "h", amplitude: 0.2)
    content("h.content", $h$)
  }),
  caption: [Noon sun angles in December ($alpha$), March ($beta$) and June
    ($gamma$).],
) <fig-sun>

= Symbols on the plan

The table lists arrow heads and path decorations as they are used on the
plans. Each cell is a canvas of its own.

#let mark-cell(sym, ..style) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  line((0, 0), (1.6, 0), mark: (end: sym, ..style.named()))
})
#let deco-cell(f, ..style) = cetz.canvas(length: 1cm, {
  import cetz.draw: *
  f(line((0, 0), (2.4, 0)), ..style.named())
})

#figure(
  table(
    columns: (auto, 1fr, auto, 1fr),
    align: (left + horizon, center + horizon, left + horizon, center + horizon),
    table.header[*Mark*][*Drawn*][*Mark*][*Drawn*],
    [`>`], mark-cell(">"), [`stealth`], mark-cell("stealth", fill: black),
    [`triangle`], mark-cell("triangle", fill: red), [`curved-stealth`], mark-cell("curved-stealth", fill: gray),
    [`|`], mark-cell("|"), [`o`], mark-cell("o", fill: white),
    [`<>`], mark-cell("<>", fill: yellow), [`[]`], mark-cell("[]"),
    [`]`], mark-cell("]"), [`hook`], mark-cell("hook"),
    [`barbed`], mark-cell("barbed"), [`+`], mark-cell("+"),
    [`x`], mark-cell("x"), [`*`], mark-cell("*"),
    [double], mark-cell((">", ">")), [scaled], mark-cell("stealth", scale: 2, fill: blue),
    table.hline(stroke: 1pt),
    [zigzag], deco-cell(decorations.zigzag, amplitude: 0.2), [wave], deco-cell(decorations.wave, amplitude: 0.2, segments: 6),
    [coil], deco-cell(decorations.coil, amplitude: 0.3, segments: 8), [square], deco-cell(decorations.square, amplitude: 0.2, segments: 5),
  ),
  caption: [Marks and decorations.],
) <tab-marks>

= Labels

Content can sit at a point with an anchor, be rotated, be framed, or fill
the box between two points. The labels of @fig-labels are measured by the
canvas, so that lines stop at their borders.

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    set-style(content: (padding: 0.08))
    content((0, 0), [Boskoop], frame: "rect", name: "a", fill: green.lighten(85%))
    content((4, 1.2), [planted 2019,\ half standard], frame: "rect", name: "b", stroke: (dash: "dashed"))
    content((4, -1.2), align(center)[yield\ $approx 38 "kg"$], frame: "circle", name: "c", fill: yellow.lighten(70%))
    content((8.2, 0), angle: 30deg, [keeps until March], frame: "rect", name: "d")
    line("a", "b", mark: (end: ">"))
    line("a", "c", mark: (end: ">"))
    line("b", "d", mark: (end: "stealth", fill: black))
    line("c.east", "d.south-west", mark: (end: "o"))
    // A paragraph laid out into a two-point box.
    rect((-1, -3.6), (9.6, -2.2), stroke: 0.3pt + gray)
    content((-1, -2.2), (9.6, -3.6), padding: 0.15, par(justify: true, text(8pt)[
      A two-point box gives the content a width: this note is justified
      between the left and the right edge of the grey frame, and wraps like
      any paragraph of the surrounding document would.
    ]))
    // Labels along a line.
    line((-1, -4.4), (9.6, -4.4), name: "axis", mark: (end: ">"))
    for (i, m) in ("Mar", "May", "Jul", "Sep", "Nov").enumerate() {
      let p = (name: "axis", anchor: (10 + i * 20) * 1%)
      line((rel: (0, 0.1), to: p), (rel: (0, -0.1), to: p))
      content((rel: (0, -0.15), to: p), anchor: "north-east", angle: 45deg, text(8pt, m))
    }
  }),
  caption: [Framed, rotated and boxed content.],
) <fig-labels>

Compare @fig-taxonomy, @fig-plan and @tab-marks.
