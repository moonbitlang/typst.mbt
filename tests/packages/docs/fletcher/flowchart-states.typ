// fletcher 0.5.8: flowcharts and state machines. Node shapes, extrusions,
// named nodes and cetz anchors, polyline/corner/bent/loop edges, mark
// shorthands, custom mark dictionaries and the MARKS state, decorations,
// crow's foot notation, enclosing nodes, layers, hidden parts, a custom
// render callback; diagrams in figures, a breakable table and with context.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, edge, node
#import fletcher.shapes: chevron, cylinder, diamond, ellipse, hexagon, house, octagon, parallelogram, pill, trapezium, triangle

#set page(width: 17cm, height: 23cm, margin: 1.5cm, numbering: "1", header: context {
  let h = query(selector(heading.where(level: 1)).before(here()))
  if h.len() > 0 {
    text(9pt, fill: gray)[Bakery handbook #sym.dot.c #h.last().body]
  }
})
#set heading(numbering: "1.1")
#set text(10pt)

= From order to oven <sec-order>

Every order takes the path of @fig-order. Decisions are diamonds, stores are
cylinders, documents are parallelograms; the grey box groups what happens
in the night shift.

#figure(
  diagram(
    node-stroke: 0.6pt,
    node-fill: white,
    spacing: (11mm, 9mm),
    edge-stroke: 0.6pt,
    mark-scale: 80%,
    node((0, 0), [Order arrives], shape: pill, fill: green.lighten(80%), name: <start>),
    node((0, 1), [Order sheet], shape: parallelogram, name: <sheet>),
    node((0, 2), align(center)[Flour in\ stock?], shape: diamond, name: <stock>),
    node((2, 2), [Reorder], shape: hexagon, name: <reorder>),
    node((2, 1), [Mill], shape: house, name: <mill>),
    node((2, 0), [Silo], shape: cylinder, name: <silo>),
    node((0, 3), [Mix dough], name: <mix>),
    node((0, 4), [Proof 8 h], shape: trapezium, name: <proof>),
    node((1, 4), [Shape loaves], shape: chevron, name: <shape>),
    node((2, 4), [Bake], shape: octagon, fill: orange.lighten(70%), name: <bake>),
    node((2, 5), [Shelf], shape: pill, extrude: (0, 2.5), fill: green.lighten(80%), name: <shelf>),
    node((1, 5), align(center)[Crust\ ok?], shape: diamond, name: <check>),
    node((0, 5), [Crumbs bin], shape: ellipse, name: <bin>),
    edge(<start>, <sheet>, "-|>"),
    edge(<sheet>, <stock>, "-|>"),
    edge(<stock>, <mix>, "-|>", [yes]),
    edge(<stock>, <reorder>, "-|>", [no]),
    edge(<reorder>, <mill>, "-|>", [fax], label-side: right),
    edge(<mill>, <silo>, "--|>", [2 days]),
    edge(<silo>, "l,d", <sheet>, "-|>", [refill], label-pos: 0.25),
    edge(<mix>, <proof>, "-|>"),
    edge(<proof>, <shape>, "-|>"),
    edge(<shape>, <bake>, "-|>"),
    edge(<bake>, <shelf>, "-|>", [45 min]),
    edge(<shelf>, <check>, "<|-"),
    edge(<check>, <bin>, "-|>", [no]),
    edge(<bin>, (-0.9, 5), (-0.9, 3), <mix>, "..|>", [old dough], label-pos: 0.5, label-side: left, label-angle: 90deg, label-sep: 2pt),
    // The night shift encloses three nodes; it is drawn below them.
    node(enclose: (<mix>, <proof>, <shape>), stroke: (dash: "dashed", paint: gray), fill: luma(240), inset: 9pt, corner-radius: 4pt, layer: -1, name: <night>),
    node((1, 3), text(8pt, fill: gray)[night shift], stroke: none, fill: none),
    edge(<night.south-east>, (rel: (6mm, 6mm)), "-o", stroke: gray),
  ),
  caption: [The path of an order.],
) <fig-order>

== Shapes at a glance

#let shape-cell(s, ..args) = diagram(node-stroke: 0.5pt, node((0, 0), text(8pt, s.at(0)), shape: s.at(1), ..args))
#let all-shapes = (
  ("rect", fletcher.shapes.rect), ("circle", fletcher.shapes.circle), ("ellipse", ellipse), ("pill", pill),
  ("parallelogram", parallelogram), ("trapezium", trapezium), ("diamond", diamond), ("triangle", triangle),
  ("house", house), ("chevron", chevron), ("hexagon", hexagon), ("octagon", octagon), ("cylinder", cylinder),
)

#grid(
  columns: (1fr,) * 5,
  row-gutter: 8pt,
  align: center + horizon,
  ..all-shapes.map(s => shape-cell(s)),
  shape-cell(("extruded", fletcher.shapes.rect), extrude: (-2, 0, 2)),
  shape-cell(("dir: left", chevron.with(dir: left))),
)

= The oven controller

The controller of the deck oven is a machine with five states
(@fig-states). Loops and bent edges avoid each other by their angles.

#figure(
  diagram(
    node-stroke: 0.8pt,
    node-fill: gradient.radial(white, yellow.lighten(60%)),
    node-shape: fletcher.shapes.circle,
    spacing: (22mm, 16mm),
    label-size: 0.85em,
    node((0, 0), [idle], radius: 7mm, extrude: (0, -2.5), name: <idle>),
    node((1, 0), [heat], radius: 7mm, name: <heat>),
    node((2, 0), [bake], radius: 7mm, name: <bake>),
    node((3, 0), [steam], radius: 7mm, name: <steam>),
    node((1, 1), [cool], radius: 7mm, name: <cool>),
    edge((-0.7, 0), <idle>, "-|>", [power], label-pos: 0),
    edge(<idle>, <heat>, "-|>", `start`),
    edge(<heat>, <bake>, "-|>", $T >= 230 degree$),
    edge(<heat>, <heat>, "-|>", $T < 230 degree$, bend: 125deg, loop-angle: 90deg),
    edge(<bake>, <steam>, "-|>", `steam`, bend: 35deg),
    edge(<steam>, <bake>, "-|>", [10 s], bend: 35deg),
    edge(<bake>, <cool>, "-|>", `done`, label-side: left, label-pos: 0.4),
    edge(<cool>, <idle>, "-|>", $T < 60 degree$, label-side: left),
    edge(<bake>, <bake>, "--|>", `tick`, bend: 125deg, loop-angle: 90deg),
    edge(<steam>, "d", <cool>, "-|>", `abort`, stroke: red, label-pos: 0.7),
    edge(<heat>, <cool>, "~>", `fault`, stroke: red),
  ),
  caption: [States of the oven controller. The double ring marks the
    initial state.],
) <fig-states>

#pagebreak()

= Edge catalogue

The handbook uses a fixed set of line styles. The table is breakable and
longer than what is left of a page would hold if it came later; each row
draws one two-node diagram.

#let sample(..args) = diagram(
  spacing: 22mm,
  node((0, 0), [a], stroke: 0.5pt, inset: 4pt),
  node((1, 0), [b], stroke: 0.5pt, inset: 4pt),
  edge((0, 0), (1, 0), ..args),
)

#table(
  columns: (auto, 1fr, auto),
  align: (left + horizon, left + horizon, center + horizon),
  table.header[*Style*][*Used for*][*Sample*],
  [`->`], [next step], sample("->"),
  [`-|>`], [next step, emphasised], sample("-|>"),
  [`--|>`], [optional step], sample("--|>"),
  [`..>`], [information only], sample("..>"),
  [`<|-|>`], [exchange], sample("<|-|>"),
  [`=>`], [bulk transport], sample("=>"),
  [`o-O`], [pipe between vessels], sample("o-O"),
  [`|-|`], [fixed distance], sample("|-|"),
  [`>->>`], [one way, then fan out], sample(">->>"),
  [`x-}>`], [blocked at the source], sample("x-}>"),
  [`[-)`], [bracket to parenthesis], sample("[-)"),
  [`1!-n?`], [one recipe, many optional batches], sample("1!-n?"),
  [`1-n!`], [one batch, at least one tray], sample("1-n!"),
  [wave], [heat], sample("~>", stroke: red),
  [coil], [steam hose], sample("-", decorations: "coil"),
  [zigzag], [cable], sample("-", decorations: "zigzag"),
  [thick], [main conveyor], sample("-|>", stroke: 2pt + navy, mark-scale: 60%),
  [extruded], [double wall], sample("-", extrude: (-2, 0, 2)),
  [shifted pair], [two lanes], diagram(
    spacing: 22mm,
    node((0, 0), [a], stroke: 0.5pt, inset: 4pt),
    node((1, 0), [b], stroke: 0.5pt, inset: 4pt),
    edge((0, 0), (1, 0), "->", shift: 3pt),
    edge((0, 0), (1, 0), "<-", shift: -3pt),
  ),
  [custom head], [special deliveries], sample(marks: ((inherit: "circle", size: 3, fill: yellow), (inherit: "head", size: 12, sharpness: 20deg), (inherit: "solid", pos: 0.5, fill: red))),
  [corner], [around an obstacle], diagram(
    spacing: (22mm, 5mm),
    node((0, 0), [a], stroke: 0.5pt, inset: 4pt),
    node((1, 1), [b], stroke: 0.5pt, inset: 4pt),
    edge((0, 0), (1, 1), "-|>", corner: right),
  ),
  [bend], [detour], sample("-|>", bend: 35deg),
)

== A mark of our own

A new mark can be registered in the package's state and then used by its
name in any later diagram.

#fletcher.MARKS.update(m => m + (
  "loaf": (
    inherit: "circle",
    size: 3.5,
    fill: orange,
    extrude: (0,),
  ),
))

#align(center, diagram(
  spacing: 26mm,
  node((0, 0), [oven], stroke: 0.5pt),
  node((1, 0), [rack], stroke: 0.5pt),
  node((2, 0), [van], stroke: 0.5pt),
  edge((0, 0), (1, 0), marks: (none, "loaf")),
  edge((1, 0), (2, 0), marks: ("loaf", "loaf", "|>")),
))

= Shifts <sec-shifts>

The last diagram is built from data and adapts to the page: the spacing is
derived from the width that `layout` reports, and the part for Sunday is
hidden but keeps its place. Its `render` callback adds a title bar with
cetz around the finished diagram.

#let shifts = (
  ("Mon", ("mix", "bake", "sell")),
  ("Wed", ("mix", "bake", "sell", "clean")),
  ("Fri", ("mix", "bake", "sell")),
  ("Sun", ("rest",)),
)

#context layout(size => {
  let gap = (size.width - 4cm) / 4
  diagram(
    spacing: (gap, 7mm),
    node-stroke: 0.5pt,
    node-corner-radius: 3pt,
    render: (grid, nodes, edges, options) => {
      import fletcher.cetz.draw as cd
      fletcher.cetz.canvas({
        cd.group(name: "plan", fletcher.draw-diagram(grid, nodes, edges, debug: options.debug))
        cd.rect((rel: (0, 0.25), to: "plan.north-west"), (rel: (0, 0.85), to: "plan.north-east"), fill: luma(230), stroke: none, name: "bar")
        cd.content("bar.center", text(9pt, weight: "bold")[Week plan, built from #shifts.len() rows])
        cd.line("plan.south-west", "plan.south-east", stroke: 0.4pt + gray)
      })
    },
    {
      for (c, (day, tasks)) in shifts.enumerate() {
        let col = {
          node((c, 0), strong(day), fill: blue.lighten(85%), name: label("d" + str(c)))
          for (r, t) in tasks.enumerate() {
            node((c, r + 1), t, name: label("t" + str(c) + "-" + str(r)))
            edge((c, r), (c, r + 1), "-|>")
          }
        }
        if day == "Sun" { fletcher.hide(col) } else { col }
        if c > 0 and c < 3 {
          edge(label("d" + str(c - 1)), label("d" + str(c)), "..>", bend: 20deg)
        }
      }
      edge(<t0-2>, <t1-0>, "-|>", [leftovers], stroke: gray, label-angle: auto, label-size: 0.75em)
      edge(<t1-3>, "r", <t2-2>, "-|>", stroke: gray)
    },
  )
})

See @sec-order for the flowchart and @fig-states for the controller.
