// zero 0.7.1: number alignment in tables: `ztable` with `format:` (none/auto/dictionaries of
// `num` options), `format-table` as a show rule on `table`, alignment at the decimal point,
// the uncertainty and the power, `nonum`, protected header cells, `align-column`, and a
// generated table of 90 rows that breaks across pages with a repeated header.
// Engine: two-pass layout through labelled metadata queries (`before`/`after`), measure of
// cell parts, show rules on table.cell that rebuild cells, table headers across pages.
#import "@preview/zero:0.7.1": num, ztable, format-table, nonum, align-column, set-num, set-round, zi

#set page(
  width: 140mm,
  height: 150mm,
  margin: (x: 12mm, y: 13mm),
  footer: context align(center, text(8pt)[#counter(page).display() / #counter(page).final().first()]),
)
#set text(size: 9.5pt)
#set par(justify: true)
#set heading(numbering: "1.")
#set table(stroke: none, inset: (x: 6pt, y: 3pt))
#show table.cell.where(y: 0): strong

= Thermocouple check

Numbers in the second and third column are aligned at the decimal
point; the first column is left alone.

#figure(
  ztable(
    columns: 3,
    align: center,
    format: (none, auto, auto),
    table.hline(),
    table.header[Point][Reference / °C][Reading / °C],
    table.hline(stroke: 0.5pt),
    [ice bath], [0.00], [-0.12],
    [room], [21.5], [21.63],
    [boiling water], [99.974], [100.4],
    [tin], [231.928], [232.1],
    [zinc], [419.527], [421],
    [aluminium], [660.323], [658.75],
    table.hline(),
  ),
  caption: [Fixed points and readings of probe K-7],
) <tab-fixed>

Uncertainties and powers are aligned as parts of their own, and a
dictionary applies `num` options to a whole column: fixed digits in the
third column of @tab-parts, engineering exponents in the fourth.

#figure(
  ztable(
    columns: 4,
    align: (left, center, center, center),
    format: (none, auto, (digits: 2), (exponent: "eng", round: (mode: "figures", precision: 3))),
    stroke: (x, y) => if y == 0 { (bottom: 0.6pt) },
    table.header[Quantity][Value][Fixed digits][Engineering],
    [Seebeck coefficient], [41.2+-0.3], [41.2], [41.2e-6],
    [Offset], [-1.25+-0.08e-3], [-0.00125], [-0.00125],
    [Loop resistance], [12.84(5)], [12.8401], [12.84],
    [Time constant], [0.35+0.05-0.02], [0.3], [350e-3],
    [Insulation], [2.1e9], [2100.5], [2.1e9],
    [Drift per year], [1.5+-0.5e-2], [0.015], [0.015],
  ),
  caption: [Parts of a number line up separately],
) <tab-parts>

= The show rule

The same alignment is switched on for an ordinary `table` by a scoped show
rule. Cells that are not numbers are left as they are; a trailing space
protects an ambiguous one, and `nonum` keeps a prefix or suffix out of
the number.

#figure(
  {
    show table: format-table(none, auto, auto, auto)
    table(
      columns: 4,
      align: (left, right, center, center),
      stroke: 0.4pt,
      table.header[Item][Count][Price][Remark],
      [Probe K-7], [3], [#nonum[€]84.50], [2024 ],
      [Extension cable], [12], [#nonum[€]7.25], [n/a],
      [Reference junction], [1], [#nonum[€]1249.00#nonum(super[a])], [-],
      [Connector pairs], [150], [#nonum[€]0.8], [see @tab-fixed],
      [Calibration], [2], [#nonum[€]310], [1.5e2],
    )
  },
  caption: [An ordinary table with the show rule (#super[a] quoted price)],
)

A single column can also be aligned outside of any table:

#context grid(
  columns: 3,
  column-gutter: 2em,
  row-gutter: 0.5em,
  grid.header[*raw*][*aligned*][*aligned, two digits*],
  stack(spacing: 0.5em, ..("3.14159", "-27.1", "1200", "0.5+-0.1", "6.02e23").map(raw)),
  stack(spacing: 0.5em, ..align-column("3.14159", "-27.1", "1200", "0.5+-0.1", "6.02e23")),
  stack(spacing: 0.5em, ..align-column("3.14159", "-27.1", "1200", "0.5", "6.02", digits: 2)),
)

#pagebreak()

= Logged run

Ninety samples of the cooling curve, generated from a formula. The table
breaks across pages; the header is repeated and the widths of the
aligned parts are the same on every page, because they are measured
over the whole table.

#let rows = range(90).map(i => {
  let t = i * 20
  let temp = 21.5 + 398.0 * calc.exp(-t / 610.0)
  let emf = 0.0412 * (temp - 21.5)
  let sigma = 0.02 + 0.0004 * calc.rem(i * 7, 23)
  let rate = -398.0 / 610.0 * calc.exp(-t / 610.0)
  (
    str(i + 1),
    str(t),
    str(calc.round(temp, digits: 2)) + "+-" + str(calc.round(sigma * 10, digits: 2)),
    str(calc.round(emf, digits: 3)),
    str(calc.round(rate * 1000, digits: 1)) + "e-3",
  )
})

#ztable(
  columns: (auto, 1fr, 1.6fr, 1fr, 1.4fr),
  align: center,
  format: (none, auto, auto, (digits: 3), auto),
  stroke: (x, y) => (bottom: if y == 0 { 0.6pt } else if calc.rem(y, 10) == 0 { 0.3pt + gray }),
  fill: (x, y) => if y > 0 and calc.odd(y) { luma(246) },
  table.header[No.][$t$ / s][$T$ / °C][$U$ / mV][$dot(T)$ / K s#super[−1]],
  ..rows.flatten().map(s => [#s]),
)

#let K-s = zi.declare("K/s")
The run ends at #zi.s(rows.last().at(1)) with a rate of #K-s(rows.last().at(4)),
that is #K-s(rows.last().at(4), exponent: (fixed: 0), fraction: "inline").
