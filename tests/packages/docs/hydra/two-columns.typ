// hydra 0.6.3: headers of a two-column document (`page(columns: 2)`): first vs. last
// section of the page (`use-last`), level ranges (`selectors.by-level`), custom `display`,
// `prev-filter`/`next-filter`. Engine: header queries with column layout, floats, colbreaks.
#import "@preview/hydra:0.6.3": hydra, selectors

#let small-caps-title(ctx, candidate) = {
  // Shows the number in a box and the title in small capitals.
  if candidate.numbering != none {
    box(
      fill: luma(220),
      inset: (x: 3pt),
      outset: (y: 2pt),
      numbering(candidate.numbering, ..counter(heading).at(candidate.location())),
    )
    h(4pt)
  }
  smallcaps(candidate.body)
}

#set page(
  width: 150mm,
  height: 110mm,
  margin: (x: 10mm, top: 17mm, bottom: 12mm),
  columns: 2,
  header: context {
    set text(size: 8pt)
    grid(
      columns: (1fr, auto, 1fr),
      align: (left, center, right),
      // First section that is active on this page ...
      hydra(2, display: small-caps-title),
      // ... the part, unless it is an appendix (filtered out) ...
      strong(hydra(
        1,
        skip-starting: false,
        prev-filter: (ctx, c) => c.primary.prev.numbering != "A",
        next-filter: (ctx, c) => c.primary.next.numbering != "A",
      )),
      // ... and the last heading of level two or three on it.
      hydra(selectors.by-level(min: 2, max: 3), use-last: true, skip-starting: false),
    )
    v(-5pt)
    line(length: 100%, stroke: 0.3pt)
  },
  footer: context align(center, text(8pt)[#counter(page).display() / #counter(page).final().first()]),
)
#set heading(numbering: "1.1")
#set text(size: 8.5pt)
#set par(justify: true)

#place(top + center, float: true, scope: "parent", block(inset: (bottom: 6pt))[
  #text(14pt, weight: "bold")[Timetable Review of the Valley Line]

  Working paper of the passenger committee, winter edition
])

= Morning Services

The valley line carries most of its passengers before nine o'clock.

== Departures from the terminus

#lorem(110)

== Connections at the junction

#lorem(60)

=== Towards the coast

#lorem(80)

=== Towards the hills

#lorem(55)

== Rolling stock

#lorem(150)

= Midday Gap

Between ten and two the line is served every ninety minutes only.
#lorem(170)

== Freight paths

#lorem(100)

#colbreak()

== Maintenance windows

#lorem(40)

=== Tamping

#lorem(30)

=== Signal tests

#lorem(45)

= Evening Services

== Commuter returns

#lorem(210)

== Last trains

#lorem(60)

#set heading(numbering: "A")
#counter(heading).update(0)

= Station Index

#table(
  columns: (1fr, auto, auto),
  stroke: 0.3pt,
  inset: 3pt,
  table.header[*Station*][*km*][*Zone*],
  [Terminus], [0.0], [1],
  [Mill Road], [2.4], [1],
  [Junction], [6.1], [2],
  [Quarry Halt], [9.8], [2],
  [Upper Valley], [14.3], [3],
  [Summit], [19.0], [3],
)

#lorem(120)
