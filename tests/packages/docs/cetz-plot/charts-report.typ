// cetz-plot 0.1.4 on cetz 0.5.2: column and bar charts (basic, clustered,
// stacked, stacked100, error bars), pie and donut charts with inner/outer
// labels, radar chart, pyramid, box-and-whisker, violin and error-bar data
// plots with annotations, smartart process/cycle. Data from a CSV file;
// charts in figures, in a table cell, in a two-column grid and inline.

#import "@preview/cetz:0.5.2"
#import "@preview/cetz-plot:0.1.4": chart, plot, smartart

#set page(width: 18cm, height: 25cm, margin: 1.6cm, numbering: "1", columns: 1)
#set heading(numbering: "1.")
#set text(10pt)
#show figure.caption: set text(9pt)
#show heading.where(level: 1): set block(above: 1.4em, below: 0.8em)

#let raw-data = csv("library-loans.csv", row-type: dictionary)
#let kinds = ("fiction", "nonfiction", "children", "audio")
#let loans = raw-data.map(r => (r.quarter, ..kinds.map(k => int(r.at(k)))))
#let totals = kinds.enumerate().map(((i, k)) => (k, loans.map(r => r.at(i + 1)).sum()))
#let grand = totals.map(t => t.at(1)).sum()

#align(center, text(16pt, weight: "bold")[Village library: the year in numbers])

The library lent #grand items this year, #totals.at(0).at(1) of them novels.
A sparkline of the quarters:
#box(baseline: 15%, cetz.canvas(length: 1em, {
  plot.plot(size: (4, 1), axis-style: none, {
    plot.add(loans.enumerate().map(((i, r)) => (i, r.slice(1).sum())), mark: "o", mark-size: 0.2, style: (stroke: 0.6pt + blue))
  })
})).
All figures below are computed from one CSV file with #raw-data.len() rows.

= Loans by quarter

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    set-style(legend: (stroke: none, orientation: ltr, item: (spacing: 0.3)), axes: (tick: (stroke: 0.4pt)))
    chart.columnchart(
      loans,
      mode: "clustered",
      size: (12, 5),
      label-key: 0,
      value-key: (1, 2, 3, 4),
      labels: kinds.map(k => upper(k.first()) + k.slice(1)),
      legend: "north",
      y-label: [items lent],
      x-label: [quarter],
      y-tick-step: 100,
      y-max: 500,
      bar-style: cetz.palette.new(colors: (rgb("#35618f"), rgb("#8f3550"), rgb("#4d8f35"), rgb("#8f7a35"))),
    )
  }),
  caption: [Items lent per quarter and kind.],
) <fig-quarters>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  [
    #figure(
      cetz.canvas(length: 1cm, {
        chart.barchart(
          loans,
          mode: "stacked100",
          size: (6, 4),
          label-key: 0,
          value-key: (1, 2, 3, 4),
          bar-style: cetz.palette.tango-light,
          x-label: [share in %],
          x-tick-step: 25,
        )
      }),
      caption: [Shares per quarter.],
    ) <fig-shares>
  ],
  [
    #figure(
      cetz.canvas(length: 1cm, {
        chart.columnchart(
          loans.map(r => (r.at(0), r.slice(1).sum() / 13, calc.sqrt(r.slice(1).sum()) / 4)),
          size: (6, 4),
          label-key: 0,
          value-key: 1,
          error-key: 2,
          bar-style: (fill: teal.lighten(50%), stroke: 0.5pt),
          y-label: [items per week],
          y-min: 0,
          y-max: 100,
          y-tick-step: 20,
        )
      }),
      caption: [Weekly mean with spread.],
    ) <fig-weekly>
  ],
)

= Who borrows what

#figure(
  grid(
    columns: 3,
    column-gutter: 0.8cm,
    align: horizon,
    cetz.canvas(length: 1cm, {
      import cetz.draw: *
      chart.piechart(
        totals,
        value-key: 1,
        label-key: 0,
        radius: 1.8,
        slice-style: cetz.palette.tango,
        outset: 2,
        outset-offset: 12%,
        inner-label: (content: "%", radius: 130%),
        outer-label: (content: "LABEL", radius: 125%),
        name: "pie",
      )
    }),
    cetz.canvas(length: 1cm, {
      import cetz.draw: *
      chart.piechart(
        (38, 27, 21, 14),
        radius: 1.8,
        inner-radius: 0.9,
        gap: 2deg,
        start: 0deg,
        stop: 360deg,
        clockwise: false,
        slice-style: cetz.palette.blue,
        inner-label: (content: (value, label) => text(8pt, fill: white, weight: "bold")[#value], radius: 100%),
        outer-label: (content: none),
      )
      content((0, 0), align(center, text(8pt)[age\ groups]))
    }),
    cetz.canvas(length: 1cm, {
      chart.pyramid(
        ((9, [reading club]), (48, [weekly]), (160, [monthly]), (410, [card holders])),
        value-key: 0,
        label-key: 1,
        level-style: cetz.palette.orange,
        level-height: 0.8,
        side-label: (content: "VALUE", side: "east"),
        inner-label: (content: (value, label) => text(7pt, label)),
        gap: 0.08,
      )
    }),
  ),
  caption: [Left: items by kind, the children's books pulled out. Middle:
    borrowers by age group in percent. Right: how often card holders come.],
) <fig-who>

== Branch comparison

#figure(
  table(
    columns: (auto, 1fr, 1fr),
    align: (left + horizon, center, center),
    stroke: (x, y) => if y == 0 { (bottom: 0.8pt) },
    table.header[][*Main street*][*School annex*],
    [Profile],
    cetz.canvas(length: 1cm, {
      chart.radarchart(
        ([hours], [stock], [events], [seats], [loans]),
        (0.9, 0.8, 0.5, 0.6, 0.85),
        radius: 1.6,
        data-style: (fill: blue.transparentize(70%), stroke: blue),
      )
    }),
    cetz.canvas(length: 1cm, {
      chart.radarchart(
        ([hours], [stock], [events], [seats], [loans]),
        ((0.4, 0.35, 0.9, 0.8, 0.5), (0.5, 0.3, 0.6, 0.7, 0.4)),
        radius: 1.6,
        data-style: cetz.palette.new(colors: (red.transparentize(70%), olive.transparentize(70%))),
      )
    }),
    [Loan period\ (days)],
    cetz.canvas(length: 1cm, {
      chart.boxwhisker(
        size: (4, 3),
        label-key: "label",
        y-min: 0,
        y-max: 45,
        y-tick-step: 15,
        (
          (label: [novel], min: 4, q1: 12, q2: 19, q3: 26, max: 38, outliers: (43,)),
          (label: [guide], min: 2, q1: 6, q2: 9, q3: 15, max: 24),
          (label: [audio], min: 3, q1: 8, q2: 14, q3: 17, max: 28, outliers: (1, 40)),
        ),
      )
    }),
    cetz.canvas(length: 1cm, {
      chart.boxwhisker(
        size: (4, 3),
        label-key: "label",
        y-min: 0,
        y-max: 45,
        y-tick-step: 15,
        mark: "x",
        (
          (label: [picture], min: 1, q1: 5, q2: 7, q3: 10, max: 14, outliers: (30, 33)),
          (label: [comic], min: 2, q1: 4, q2: 6, q3: 12, max: 21),
        ),
      )
    }),
  ),
  caption: [The two branches side by side.],
) <tab-branches>

= Opening hours and visits

Visits were counted on #(6) days per slot. @fig-visits shows them as a bar
plot with error bars and a fitted line, annotated in plot coordinates, and
the distribution of visit lengths as violins.

#let slots = ((9, 14, 3), (11, 22, 4), (13, 17, 5), (15, 31, 4), (17, 38, 6), (19, 12, 3))
#let durations = (
  (1, (12, 18, 22, 25, 31, 44, 20, 15)),
  (2, (35, 41, 48, 52, 55, 61, 38, 70)),
  (3, (8, 9, 12, 14, 15, 19, 26, 11)),
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6cm,
    cetz.canvas(length: 1cm, {
      plot.plot(
        size: (7.5, 4.5),
        x-label: [hour of day],
        y-label: [visits per hour],
        x-tick-step: 2,
        x-min: 8,
        x-max: 20,
        y-min: 0,
        y-max: 50,
        y-tick-step: 10,
        legend: "inner-north-west",
        {
          plot.add-bar(slots.map(s => (s.at(0), s.at(1))), bar-width: 1.4, style: (fill: aqua.lighten(40%), stroke: 0.4pt))
          for (h, v, e) in slots {
            plot.add-errorbar((h, v), y-error: e, mark: none, whisker-size: 0.3, style: (stroke: 0.6pt))
          }
          plot.add(domain: (8.5, 18), h => 2.6 * h - 10.5, style: (stroke: (paint: red, dash: "dashed")), label: [trend until 18 h])
          plot.add-errorbar((19, 12), x-error: 0.6, y-error: (-2, 5), mark: "o", mark-size: 0.12, mark-style: (fill: white), label: [last slot])
          plot.annotate({
            import cetz.draw: *
            rect((16, 0), (18, 46), fill: yellow.transparentize(75%), stroke: none)
            content((17, 44), text(7pt)[school's out])
          }, background: true)
          plot.annotate({
            import cetz.draw: *
            content((10.5, 34), text(7pt)[market day], name: "m", frame: "rect", padding: 2pt, stroke: 0.3pt)
            line("m.south", (11, 26.5), stroke: 0.3pt)
          })
        },
      )
    }),
    cetz.canvas(length: 1cm, {
      plot.plot(
        size: (5, 4.5),
        x-min: 0.3,
        x-max: 3.7,
        x-tick-step: none,
        x-ticks: ((1, [read]), (2, [study]), (3, [return])),
        y-label: [minutes],
        y-min: 0,
        y-max: 80,
        y-tick-step: 20,
        y-grid: true,
        {
          plot.add-violin(durations, side: "both", bandwidth: 5, extents: 0.3, samples: 40, style: (fill: purple.lighten(70%), stroke: 0.5pt + purple))
          plot.add(durations.map(((x, ys)) => ys.map(y => (x, y))).flatten().chunks(2), style: (stroke: none), mark: "+", mark-size: 0.08)
        },
      )
    }),
  ),
  caption: [Visits per hour (left) and length of a visit by purpose
    (right).],
) <fig-visits>

= How a book gets on the shelf

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    smartart.process.chevron(
      ([Wish], [Order], [Catalogue], [Cover], [Shelf]),
      step-style: cetz.palette.light-green,
      equal-length: true,
      name: "chain",
    )
    translate((0, -3.4))
    smartart.process.basic(
      ([Return], [Check], [Repair?], [Reshelve]),
      step-style: cetz.palette.gray,
      arrow-style: (fill: black, stroke: none),
      equal-width: true,
      name: "back",
    )
    translate((11, 1.4))
    smartart.cycle.basic(
      ([Lend], [Read], [Return], [Rest]),
      radius: 1.4,
      step-style: cetz.palette.pink,
      name: "life",
    )
  }),
  caption: [Acquisition (top), return desk (bottom) and the life of a
    borrowed book (right).],
) <fig-process>

The charts are @fig-quarters, @fig-shares, @fig-weekly, @fig-who,
@tab-branches, @fig-visits and @fig-process.
