// subpar 0.2.2: subpar.super with free layouts (stack, columns), table and
// raw kinds, show-sub and show-sub-caption overrides, floating super figures
// (placement, scope) in a two-column page, translated supplements.
// Stresses show rules that wrap figures and captions, kinds gathered from
// content, floats with parent scope, counter(figure.where(kind)) per kind.
#import "@preview/subpar:0.2.2"

#set page(width: 16cm, height: 20cm, margin: 1.3cm, columns: 2, numbering: "1")
#set columns(gutter: 1em)
#set text(size: 9pt)
#set par(justify: true)
#set heading(numbering: "1.1")

#let bars(..values) = box(height: 1.6cm, stack(
  dir: ltr,
  spacing: 3pt,
  ..values.pos().map(v => align(bottom, rect(width: 0.45cm, height: v * 1.6cm, fill: eastern.lighten(20%)))),
))

= Harvest report

The orchard keeps three kinds of records: charts, tables and the scripts
that produce them. Each kind has its own counter, and each record may
consist of parts.

#subpar.super(
  caption: [Crates filled per week, by fruit.],
  label: <fig:crates>,
  {
    [#figure(bars(0.3, 0.5, 0.9, 0.7), caption: [Apples.]) <fig:apples>]
    h(1em)
    [#figure(bars(0.8, 0.6, 0.2), caption: [Pears.]) <fig:pears>]
    v(0.3em)
    [#figure(bars(0.1, 0.2, 0.4, 0.8, 1.0, 0.6), caption: [Plums, below the other two.]) <fig:plums>]
  },
)

@fig:crates is laid out by hand: @fig:apples and @fig:pears, then
@fig:plums. #lorem(25)

#subpar.super(
  kind: table,
  caption: [Yield per row of trees, early and late varieties.],
  label: <tab:yield>,
  show-sub-caption: (num, it) => {
    set text(size: 0.9em, style: "italic")
    [#num #it.body]
  },
  stack(
    dir: ttb,
    spacing: 0.8em,
    [#figure(
      table(
        columns: (1fr, auto, auto),
        table.header[Row][Trees][kg],
        [North], [14], [312],
        [Middle], [16], [401],
        [South], [12], [288],
      ),
      caption: [Early varieties.],
    ) <tab:early>],
    [#figure(
      table(
        columns: (1fr, auto, auto),
        table.header[Row][Trees][kg],
        [North], [10], [198],
        [South], [18], [455],
      ),
      caption: [Late varieties.],
    ) <tab:late>],
  ),
)

@tab:yield has two parts, @tab:early and @tab:late. #lorem(30)

#subpar.super(
  kind: raw,
  numbering: "A",
  numbering-sub-ref: "A-1",
  numbering-sub: "1.",
  caption: [The two scripts behind the tables.],
  label: <lst:scripts>,
  show-sub: it => block(fill: luma(245), inset: 4pt, radius: 2pt, width: 100%, it),
  [
    #figure(
      ```python
      def total(rows):
          return sum(r.kg for r in rows)
      ```,
      caption: [Summing.],
    ) <lst:sum>
    #figure(
      ```python
      def mean(rows):
          return total(rows) / len(rows)
      ```,
      caption: [Averaging.],
    ) <lst:mean>
  ],
)

@lst:scripts contains @lst:sum and @lst:mean. #lorem(50)

#subpar.grid(
  figure(bars(0.2, 0.4, 0.6, 0.8, 1.0), caption: [Weight picked per week.]), <fig:week>,
  figure(bars(1.0, 0.7, 0.5, 0.2, 0.1), caption: [Fruit left on the trees.]), <fig:left>,
  figure(bars(0.5, 0.5, 0.6, 0.5, 0.4), caption: [Pickers at work.]), <fig:pickers>,
  columns: (1fr, 1fr, 1fr),
  placement: top,
  scope: "parent",
  gap: 1em,
  caption: [A floating figure across both columns.],
  label: <fig:season>,
)

= Reading the charts

@fig:season floats to the top of a page. Its parts are @fig:week,
@fig:left and @fig:pickers. #lorem(60)

#set text(lang: "de")

#subpar.grid(
  figure(circle(radius: 0.7cm, fill: red.lighten(30%)), caption: [Rot.]), <fig:rot>,
  figure(circle(radius: 0.7cm, fill: yellow.lighten(30%)), caption: [Gelb.]), <fig:gelb>,
  columns: 2,
  placement: bottom,
  caption: [Zwei Sorten, mit deutschem Zusatz.],
  label: <fig:sorten>,
)

Die @fig:sorten zeigt @fig:rot und @fig:gelb. #lorem(80)

#set text(lang: "en")

= Counters at the end

#context [
  Images: #counter(figure.where(kind: image)).get().first();
  tables: #counter(figure.where(kind: table)).get().first();
  listings: #counter(figure.where(kind: raw)).get().first().
]

#lorem(60)
