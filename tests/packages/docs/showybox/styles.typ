// showybox 2.0.4: titled boxes with frames, dashes, shadows, separators,
// footers, boxed titles (anchors, offsets) and reusable styles.
// Stresses counter + state per box, state.final() for the boxed title height,
// place/hide pre-rendering, nested blocks with strokes and radii.
#import "@preview/showybox:2.0.4": showybox

#set page(width: 14cm, height: 19cm, margin: 1.4cm, numbering: "1")
#set text(size: 10pt)
#set par(justify: true)

= Notes from the tea cupboard

Every tin in the cupboard gets a card. The cards below record how each tea
is brewed, what went wrong the last time, and who is allowed to finish it.

#showybox(
  title: "Assam, second flush",
  frame: (
    border-color: rgb("#7a3b12"),
    title-color: rgb("#a8551f"),
    body-color: rgb("#fbf1e4"),
    footer-color: rgb("#eeddc6"),
    thickness: 1.5pt,
  ),
  title-style: (weight: "bold", sep-thickness: 2pt),
  footer-style: (color: rgb("#5a2c0c"), align: end, sep-thickness: 0.5pt),
  footer: [Tin 3, bought in March],
)[
  Four grams per cup, water just off the boil, four minutes. Takes milk
  without complaint. The second infusion is thin and not worth the kettle.
]

#showybox(
  title: [Sencha _(shaded)_],
  frame: (
    border-color: green.darken(40%),
    title-color: green.lighten(75%),
    body-color: white,
    radius: (top-left: 12pt, bottom-right: 12pt, rest: 0pt),
    dash: "dashed",
    inset: (x: 1.4em, y: 0.9em),
  ),
  title-style: (color: green.darken(60%), align: center, weight: "bold"),
  body-style: (align: center, color: green.darken(70%)),
  sep: (dash: "dotted", thickness: 0.8pt, gutter: 0.9em),
  shadow: (offset: 3pt, color: green.lighten(60%)),
)[
  Seventy degrees. *Never* boiling water.
][
  One minute for the first cup, twenty seconds for the second.
][
  $ t_n = 60 dot (1/3)^(n - 1) "s" $
]

#let recipe-card = showybox.with(
  frame: (
    border-color: navy,
    title-color: navy.lighten(85%),
    thickness: (left: 4pt, rest: 0.6pt),
    radius: 0pt,
    title-inset: (x: 0.8em, y: 0.4em),
    body-inset: (x: 0.8em, y: 0.8em),
    footer-inset: (x: 0.8em, y: 0.3em),
  ),
  title-style: (color: navy, weight: "bold"),
  shadow: (offset: (x: 2pt, y: 5pt), color: luma(190)),
)

#grid(
  columns: (1fr, 1fr),
  gutter: 1em,
  recipe-card(title: "Masala chai", footer: "Serves two")[
    + Crush cardamom, clove, pepper.
    + Simmer in water for five minutes.
    + Add tea and milk, bring up twice.
  ],
  recipe-card(title: "Iced hibiscus", width: 100%)[
    - Steep cold overnight.
    - Strain; sweeten with honey.
    - Serve over ice with lime.
  ],
)

== Boxed titles

#showybox(
  title: "Rule of the house",
  frame: (border-color: maroon, title-color: maroon, thickness: 1.2pt),
  title-style: (
    weight: "bold",
    boxed-style: (anchor: (x: center, y: horizon), radius: (top-left: 8pt, bottom-right: 8pt, rest: 0pt)),
  ),
)[
  Whoever empties a tin writes its name on the shopping list before the
  kettle has cooled.
]

#showybox(
  title: "Top anchored, pushed right",
  frame: (border-color: teal.darken(20%), title-color: teal.darken(20%), body-color: teal.lighten(90%)),
  title-style: (boxed-style: (anchor: (x: right, y: top), offset: (x: -1em, y: 0pt))),
  shadow: (offset: 4pt),
  footer: "The title sits inside the frame here.",
)[
  #lorem(24)
]

#showybox(
  title: "Bottom anchored",
  frame: (border-color: orange.darken(30%), title-color: orange.darken(10%), dash: "dash-dotted"),
  title-style: (color: black, boxed-style: (anchor: (x: left, y: bottom), offset: (x: 6pt, y: 0pt), radius: 0pt)),
  width: 75%,
  align: center,
)[
  A narrow box, centred on the page, whose title stands on the top edge.
]

== A table inside a figure

#figure(
  showybox(
    title: "Steeping times",
    frame: (title-color: luma(40), border-color: luma(40), inset: 0.5em),
    title-style: (align: center),
    width: 80%,
    table(
      columns: (1fr, auto, auto),
      stroke: none,
      table.header([*Tea*], [*°C*], [*min*]),
      table.hline(stroke: 0.5pt),
      [Assam], [98], [4],
      [Sencha], [70], [1],
      [Oolong], [90], [3],
      [Pu-erh], [100], [5],
    ),
  ),
  caption: [The cupboard at a glance.],
) <fig-times>

@fig-times is pinned inside the cupboard door. An untitled box closes the
page:

#showybox(frame: (thickness: (y: 2pt, x: 0pt), radius: 0pt, body-color: luma(245)), above: 2em, below: 1em)[
  No title, no footer, only rules above and below.
]
