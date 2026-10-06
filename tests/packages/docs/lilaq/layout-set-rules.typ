// lilaq 0.6.0: a multi-diagram dashboard. Shared settings through set and
// show rules of lilaq's elembic elements (set-diagram, set-tick, set-grid,
// set-legend, set-title, set-label, set-spine, cond-set, show_, selector),
// lq.layout for aligned grids with spanning cells (two-pass layout with
// query and metadata), scoped themes, style cycles, a datetime axis.

#import "@preview/lilaq:0.6.0" as lq

#set page(width: 18cm, height: 24cm, margin: 1.5cm, numbering: "1 of 1")
#set heading(numbering: "1.")
#set text(10pt)
#show figure.caption: set text(9pt)

// Settings for every diagram of the document.
#show: lq.set-diagram(width: 6cm, height: 3.2cm, cycle: lq.color.map.okabe-ito)
#show: lq.set-tick(inset: 2pt, outset: 2pt, pad: 0.4em)
#show: lq.set-grid(stroke: 0.4pt + luma(85%), stroke-sub: 0.25pt + luma(92%))
#show: lq.set-legend(stroke: none, fill: white.transparentize(10%), inset: 0.25em)
#show: lq.set-title(pad: 0.3em)
#show: lq.set-label(pad: 0.5em)
#show lq.selector(lq.title): set text(9pt, weight: "bold")
#show lq.selector(lq.label): set text(9pt)
#show lq.selector(lq.tick-label): set text(8pt)

= Glasshouse 3, week 31

Six beds of tomatoes, one logger per bed. All diagrams of this sheet share
one set of rules written at the top of the document: size, colour cycle,
tick length, grid and legend style, and the fonts of titles and labels.

#let hours = lq.linspace(0, 24, num: 49)
#let outside(h) = 17 + 6 * calc.sin((h - 9) / 24 * 2 * calc.pi)
#let inside(h) = 21 + 4.5 * calc.sin((h - 10.5) / 24 * 2 * calc.pi) + 0.6 * calc.sin(h * 1.3)
#let light(h) = calc.max(0, 620 * calc.sin((h - 5.5) / 15.5 * calc.pi))
#let yield-kg = (4.1, 5.3, 3.8, 6.0, 5.6, 4.4)
#let brix = (4.6, 5.1, 4.2, 5.8, 5.5, 4.9)

== Dashboard

The grid of @fig-dashboard is laid out by `lq.layout`: the spines of the
diagrams in a row or column line up although their tick labels, titles
and axis labels have different sizes. The last cell spans both columns.

#figure(
  {
    show: lq.layout
    grid(
      columns: 2,
      column-gutter: 1.2em,
      row-gutter: 1em,
      lq.diagram(
        title: [Air temperature],
        ylabel: [°C],
        xaxis: (ticks: range(0, 25, step: 6)),
        lq.plot(hours, inside, mark: none, label: [inside]),
        lq.plot(hours, outside, mark: none, label: [outside]),
      ),
      lq.diagram(
        title: [Light at canopy],
        ylabel: [W/m²],
        xaxis: (ticks: range(0, 25, step: 6)),
        yaxis: (exponent: 2),
        lq.fill-between(hours, light, fill: yellow.transparentize(40%)),
        lq.plot(hours, light, mark: none, color: orange),
      ),
      lq.diagram(
        title: [Yield per bed],
        ylabel: [kg per plant],
        xlabel: [bed],
        xaxis: (ticks: range(1, 7), subticks: none),
        ylim: (0, 7),
        lq.bar(range(1, 7), yield-kg, fill: yield-kg.map(y => if y > 5 { green } else { green.lighten(55%) })),
        lq.hlines(yield-kg.sum() / 6, stroke: (dash: "dashed", paint: black, thickness: 0.5pt)),
      ),
      lq.diagram(
        title: [Sugar against yield],
        ylabel: [°Brix],
        xlabel: [kg per plant],
        lq.scatter(yield-kg, brix, size: 7pt, mark: "o", label: [beds]),
        lq.plot((3.6, 6.2), x => 2.0 + 0.62 * x, mark: none, stroke: (dash: "dotted"), label: [trend]),
      ),
      grid.cell(
        colspan: 2,
        lq.diagram(
          width: 13.8cm,
          height: 2.6cm,
          title: [Soil moisture, beds 1 to 3],
          ylabel: [vol. %],
          xlabel: [hour],
          legend: (position: right + bottom),
          xaxis: (ticks: range(0, 25, step: 2)),
          ..range(3).map(b => lq.plot(
            hours,
            h => 31 - b * 2.5 - 5 * calc.rem(h + b * 3, 8) / 8,
            mark: none,
            step: end,
            label: [bed #(b + 1)],
          )),
          lq.vlines(..range(5, 24, step: 8), stroke: (paint: blue.lighten(40%), thickness: 0.5pt)),
        ),
      ),
    )
  },
  caption: [The week at a glance.],
) <fig-dashboard>

== Rules in a scope

Rules can also be local. Each block below starts from the document's rules
and adds its own, without touching the others.

#grid(
  columns: 3,
  column-gutter: 0.8em,
  align: bottom,
  [
    // No grid lines along x, slanted tick labels, thicker spines.
    #show: lq.cond-set(lq.grid.with(kind: "x"), stroke: none)
    #show: lq.set-spine(stroke: 1pt)
    #show: lq.show_(
      lq.tick-label.with(kind: "x"),
      it => box(width: 0pt, align(right, rotate(-40deg, reflow: true, it))),
    )
    #lq.diagram(
      width: 4.2cm,
      title: [Pests caught],
      xaxis: (ticks: ("whitefly", "thrips", "aphid", "mite").enumerate(), subticks: none),
      lq.bar(range(4), (23, 9, 14, 4)),
    )
  ],
  [
    // Marks and strokes from a folded cycle.
    #let marks-cycle = lq.cycle.generic(lq.mark, align: (lq.marks.s, lq.marks.d, lq.marks.star))
    #let color-cycle = lq.cycle.generic(lq.style, fill: (maroon, olive, navy))
    #show: lq.set-diagram(cycle: lq.cycle.fold(color-cycle, marks-cycle))
    #show: lq.set-legend(position: top + left)
    #lq.diagram(
      width: 4.2cm,
      title: [Trusses per plant],
      xlabel: [week],
      ..range(3).map(k => lq.plot(range(26, 32), range(6).map(w => 2 + k + calc.rem(w * (k + 2), 4)), label: [row #(k + 1)])),
    )
  ],
  [
    // Error bars restyled for this block only.
    #show: lq.set-errorbar(cap: 5pt, stroke: 1pt + red)
    #show: lq.set-tick(inset: 0pt, outset: 4pt)
    #lq.diagram(
      width: 4.2cm,
      title: [Fruit weight],
      ylabel: [g],
      xaxis: (ticks: range(1, 7), subticks: none),
      lq.plot(range(1, 7), (112, 131, 104, 140, 138, 119), yerr: (8, 11, 7, 15, 9, 10), stroke: none, mark: "o"),
    )
  ],
)

= Themes

The package ships themes, which are bundles of such rules. Applied in a
scope, they restyle the same diagram (@fig-themes).

#let demo(..args) = lq.diagram(
  width: 4.4cm,
  height: 2.8cm,
  xlabel: [hour],
  ylabel: [°C],
  ..args,
  lq.plot(hours, inside, mark: none, label: [in]),
  lq.plot(hours, outside, mark: none, label: [out]),
)

#figure(
  grid(
    columns: 3,
    column-gutter: 1em,
    row-gutter: 1em,
    align: center + bottom,
    [#show: lq.theme.skyline
      #demo(title: [skyline])],
    [#show: lq.theme.misty
      #demo(title: [misty], legend: none)],
    [#show: lq.theme.ocean
      #demo(title: [ocean])],
    grid.cell(colspan: 2)[
      #show: lq.theme.schoolbook
      #lq.diagram(
        width: 8cm,
        height: 3.2cm,
        xlim: (-3.4, 3.4),
        ylim: (-1.4, 1.6),
        xlabel: $x$,
        ylabel: $y$,
        lq.plot(lq.linspace(-3.2, 3.2, num: 60), x => calc.sin(2 * x) * calc.exp(-x * x / 6), mark: none),
        lq.plot(lq.linspace(-3.2, 3.2, num: 60), x => calc.exp(-x * x / 6), mark: none, stroke: (dash: "dashed")),
      )
    ],
    block(fill: rgb("#1c1c28"), inset: 6pt, radius: 3pt)[
      #set text(fill: white)
      #show: lq.theme.moon
      #demo(title: [moon], legend: none)
    ],
  ),
  caption: [Five themes; the wide one is the school-book theme with axes
    through the origin and arrow tips.],
) <fig-themes>

= Dates on an axis

Coordinates may be `datetime` values; the axis then picks date ticks and
formats them. @fig-season shows the harvest of the season with a twin axis
for the running total.

#let picks = (
  (datetime(year: 2024, month: 6, day: 17), 14),
  (datetime(year: 2024, month: 6, day: 24), 22),
  (datetime(year: 2024, month: 7, day: 1), 31),
  (datetime(year: 2024, month: 7, day: 8), 37),
  (datetime(year: 2024, month: 7, day: 15), 44),
  (datetime(year: 2024, month: 7, day: 22), 41),
  (datetime(year: 2024, month: 7, day: 29), 36),
  (datetime(year: 2024, month: 8, day: 5), 28),
  (datetime(year: 2024, month: 8, day: 12), 19),
)
#let running = picks.enumerate().map(((i, _)) => picks.slice(0, i + 1).map(p => p.at(1)).sum())

#figure(
  lq.diagram(
    width: 12cm,
    height: 3.6cm,
    ylabel: [kg per week],
    legend: (position: top + left),
    lq.plot(picks.map(p => p.at(0)), picks.map(p => p.at(1)), mark: "s", label: [picked]),
    lq.yaxis(
      position: right,
      label: [total / kg],
      lq.plot(picks.map(p => p.at(0)), running, mark: none, step: end, color: gray, label: [total]),
    ),
  ),
  caption: [Harvest per week, #running.last() kg in total.],
) <fig-season>

@fig-dashboard, @fig-themes and @fig-season use the same rules.
