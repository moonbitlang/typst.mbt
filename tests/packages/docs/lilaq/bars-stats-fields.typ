// lilaq 0.6.0: bar and hbar (grouped, stacked, custom tick labels through an
// elembic show rule), asymmetric error bars, fill-between bands, box plots
// and violins, contour (marching squares) and colormesh with colorbars, and
// a quiver field. Heavy array computation; images from generated pixel data;
// figures side by side and a diagram inside a table.

#import "@preview/lilaq:0.6.0" as lq

#set page(width: 17cm, height: 23cm, margin: 1.5cm, numbering: "— 1 —")
#set heading(numbering: "1.")
#show figure.caption: set text(9pt)
#set par(justify: true)

#let lcg(n, seed) = {
  let s = seed
  let out = ()
  for _ in range(n) {
    s = calc.rem(s * 16807, 2147483647)
    out.push(s / 2147483647)
  }
  out
}
// Roughly normal numbers from sums of uniform ones.
#let normal(n, seed, mean: 0, sd: 1) = lcg(n * 6, seed).chunks(6).map(c => mean + sd * (c.sum() - 3) * 1.41)

= Cheese cellar report

Four cheeses ripen in the cellar. This report compares their weight loss,
the climate of the three vaults and the air flow around the door.

== Weight loss per month

#let cheeses = ("Tomme", "Blue", "Gouda", "Chèvre")
#let months = ("Jan", "Feb", "Mar", "Apr", "May")
#let loss = (
  (2.1, 1.8, 1.4, 1.1, 0.9),
  (2.8, 2.2, 1.9, 1.2, 1.0),
  (1.5, 1.3, 1.2, 1.0, 0.9),
  (3.9, 2.7, 1.6, 0.8, 0.4),
)

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6cm,
    lq.diagram(
      width: 7cm,
      height: 4.5cm,
      title: [grouped],
      ylabel: [loss / %],
      xaxis: (ticks: months.enumerate(), subticks: none),
      legend: (position: top + right),
      ..loss.enumerate().map(((i, row)) => lq.bar(
        range(5),
        row,
        width: 0.2,
        offset: (i - 1.5) * 0.2,
        label: cheeses.at(i),
      )),
    ),
    lq.diagram(
      width: 5cm,
      height: 4.5cm,
      title: [stacked],
      xlabel: [total loss / %],
      yaxis: (ticks: cheeses.enumerate(), subticks: none),
      xlim: (0, 11),
      ..range(5).map(m => lq.hbar(
        loss.map(row => row.at(m)),
        range(4),
        base: loss.map(row => row.slice(0, m).sum(default: 0)),
        fill: blue.lighten(m * 18%),
        stroke: 0.3pt + white,
      )),
      ..loss.enumerate().map(((i, row)) => lq.place(row.sum() + 0.2, i, align: left, text(7pt)[#calc.round(row.sum(), digits: 1)])),
    ),
  ),
  caption: [Monthly weight loss, grouped by month (left) and summed per
    cheese (right).],
) <fig-loss>

== Rind thickness

Each wheel was measured at eight points. @fig-rind draws the samples as box
plots and as violins; the mean with its asymmetric uncertainty is on top.

#let rind = cheeses.enumerate().map(((i, _)) => normal(8 * 3, 101 + i * 17, mean: 3 + i * 0.8, sd: 0.5 + 0.2 * i))

#figure(
  grid(
    columns: 2,
    column-gutter: 0.6cm,
    lq.diagram(
      width: 6cm,
      height: 4.5cm,
      ylabel: [rind / mm],
      xaxis: (ticks: cheeses.enumerate(start: 1), subticks: none),
      lq.boxplot(..rind, fill: yellow.lighten(60%), median: 1.5pt + red, mean: "x", outliers: "d", stroke: 0.6pt),
      lq.plot(
        range(1, 5),
        rind.map(r => r.sum() / r.len()),
        yerr: (p: (0.6, 0.9, 0.5, 1.2), m: (0.3, 0.4, 0.5, 0.6)),
        xerr: 0.15,
        stroke: none,
        mark: "s",
        mark-size: 4pt,
        color: black,
      ),
    ),
    lq.diagram(
      width: 6cm,
      height: 4.5cm,
      xaxis: (ticks: cheeses.enumerate(start: 1), subticks: none),
      lq.violin(..rind, fill: purple.lighten(70%), stroke: 0.5pt + purple),
      lq.scatter(
        rind.enumerate().map(((i, r)) => r.map(_ => i + 1)).flatten(),
        rind.flatten(),
        size: 3pt,
        mark: ".",
        color: black,
        alpha: 60%,
      ),
    ),
  ),
  caption: [Rind thickness of #(8 * 3) samples per cheese.],
) <fig-rind>

= Climate of the vaults

The humidity of a vault swings with the weather outside, between the bounds
that the ventilation allows. @fig-band fills that band and the range where
the rind dries too fast.

#let days = lq.linspace(0, 60, num: 121)
#let centre(d) = 88 + 4 * calc.sin(d / 9) + 1.5 * calc.sin(d / 2.3)

#figure(
  lq.diagram(
    width: 12cm,
    height: 4cm,
    xlabel: [day],
    ylabel: [relative humidity / %],
    ylim: (76, 100),
    legend: (position: bottom + right),
    lq.fill-between(days, d => centre(d) - 3, y2: d => centre(d) + 3, fill: aqua.transparentize(50%), label: [allowed band]),
    lq.fill-between(days, d => 76, y2: d => 82, fill: red.transparentize(80%), label: [too dry]),
    lq.plot(days, centre, mark: none, stroke: 0.8pt + navy, label: [set point]),
    lq.plot(
      range(2, 60, step: 4),
      range(2, 60, step: 4).zip(normal(15, 5, sd: 1.6)).map(((d, e)) => centre(d) + e),
      stroke: none,
      mark: "o",
      mark-size: 4pt,
      color: orange,
      label: [reading],
    ),
    lq.fill-between((20, 26), (76, 76), y2: (100, 100), fill: tiling(size: (4pt, 4pt), std.line(start: (0pt, 4pt), end: (4pt, 0pt), stroke: 0.3pt + gray)), label: [door open]),
  ),
  caption: [Humidity of vault 2 over two months.],
) <fig-band>

== Temperature field

Sensors on a grid give the temperature over the floor plan of vault 2. The
field is drawn twice in @fig-field: as level lines and as a colour mesh,
each with its colour bar.

#let xs = lq.linspace(0, 8, num: 25)
#let ys = lq.linspace(0, 5, num: 17)
#let field(x, y) = 11 + 2.2 * calc.exp(-((x - 1) * (x - 1) + (y - 4) * (y - 4)) / 3) - 1.4 * calc.exp(-((x - 6.5) * (x - 6.5) + (y - 1.2) * (y - 1.2)) / 4) + 0.08 * x

#let level-lines = lq.contour(xs, ys, field, levels: 9, map: color.map.turbo, stroke: 0.9pt)
#let mesh = lq.colormesh(xs, ys, field, map: color.map.inferno, min: 9.5, max: 13.5)

#figure(
  grid(
    columns: 4,
    column-gutter: 0.25cm,
    align: bottom,
    lq.diagram(
      width: 5.2cm,
      height: 3.6cm,
      xlabel: [m],
      ylabel: [m],
      level-lines,
      lq.contour(xs, ys, field, levels: (11.2,), stroke: 1.6pt + black),
      lq.place(1, 4, text(7pt)[door]),
      lq.place(6.5, 1.2, text(7pt)[cooler]),
    ),
    lq.colorbar(level-lines, thickness: 2mm, label: [°C]),
    lq.diagram(
      width: 5.2cm,
      height: 3.6cm,
      xlabel: [m],
      mesh,
      lq.contour(xs, ys, field, levels: 5, stroke: 0.4pt + white),
    ),
    lq.colorbar(mesh, thickness: 2mm, label: [°C]),
  ),
  caption: [Temperature of vault 2: #(xs.len() * ys.len()) grid values, the
    thick line is the 11.2 °C level.],
) <fig-field>

== Air flow

The air moves from the door to the cooler and back along the ceiling. In
the table, the flow is a quiver plot coloured by speed, next to the filled
level plot of the stream function.

#let stream(x, y) = calc.sin(calc.pi * x / 8) * calc.sin(calc.pi * y / 5)
#let qx = lq.linspace(0.5, 7.5, num: 11)
#let qy = lq.linspace(0.5, 4.5, num: 7)

#figure(
  table(
    columns: 2,
    align: center + horizon,
    table.header[*Velocity*][*Stream function*],
    lq.diagram(
      width: 5.5cm,
      height: 3.6cm,
      lq.quiver(
        qx,
        qy,
        (x, y) => (
          calc.sin(calc.pi * x / 8) * calc.cos(calc.pi * y / 5) * calc.pi / 5,
          -calc.cos(calc.pi * x / 8) * calc.sin(calc.pi * y / 5) * calc.pi / 8,
        ),
        color: (x, y, u, v) => calc.sqrt(u * u + v * v),
        map: color.map.viridis,
        scale: 0.9,
      ),
    ),
    lq.diagram(
      width: 5.5cm,
      height: 3.6cm,
      lq.contour(xs, ys, stream, levels: 7, fill: true, map: color.map.mako),
    ),
  ),
  caption: [Air flow in vault 2.],
) <tab-flow>

See @fig-loss, @fig-rind, @fig-band, @fig-field and @tab-flow.
