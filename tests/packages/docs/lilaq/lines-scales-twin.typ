// lilaq 0.6.0: line and scatter plots with legends, marks, manual and
// formatted ticks, subticks, log and symlog scales, twin and dependent
// secondary axes, error bars, steps, smoothing, annotations (place, line,
// rect, hlines/vlines). Stresses elembic elements (state-free styling via
// metadata/context/query), zero number formatting, measure and layout.

#import "@preview/lilaq:0.6.0" as lq

#set page(width: 16cm, height: 22cm, margin: 1.5cm, numbering: "1")
#set heading(numbering: "1.")
#set par(justify: true)
#show figure.caption: set text(9pt)

// A fixed linear congruential generator for measurement noise.
#let noise(n, seed: 7) = {
  let s = seed
  let out = ()
  for _ in range(n) {
    s = calc.rem(s * 48271, 2147483647)
    out.push(s / 2147483647 - 0.5)
  }
  out
}

= Weather hut, station log

The hut records temperature, pressure and rain once an hour. This sheet
plots one day and a few derived laws.

== One day

#let hours = lq.arange(0, 25)
#let temp = hours.map(h => 9.5 - 5.5 * calc.cos((h - 3) / 24 * 2 * calc.pi))
#let jitter = noise(25)
#let measured = temp.zip(jitter).map(((t, j)) => t + 1.6 * j)
#let rain = (0, 0, 0, 0.2, 1.1, 2.4, 1.8, 0.6, 0, 0, 0, 0, 0, 0, 0.3, 0.9, 3.2, 4.1, 1.5, 0.4, 0, 0, 0, 0, 0)

#figure(
  lq.diagram(
    width: 11cm,
    height: 5cm,
    title: [14 March, hourly],
    xlabel: [hour],
    ylabel: [temperature / °C],
    xlim: (0, 24),
    ylim: (0, 18),
    xaxis: (ticks: range(0, 25, step: 3), subticks: 2),
    legend: (position: top + left),
    lq.plot(hours, temp, mark: none, stroke: 1.2pt, label: [model]),
    lq.plot(hours, measured, stroke: none, mark: "o", mark-size: 4pt, yerr: 0.8, label: [sensor]),
    lq.plot(hours, measured, mark: none, smooth: true, stroke: (dash: "dashed", thickness: 0.6pt), label: [smoothed]),
    lq.hlines(9.5, stroke: (paint: gray, dash: "dotted"), label: [mean]),
    lq.vlines(6.4, 18.3, stroke: orange + 0.6pt),
    lq.place(6.4, 16.5, align: left, pad(left: 2pt, text(8pt, fill: orange)[sunrise])),
    lq.place(18.3, 16.5, align: right, pad(right: 2pt, text(8pt, fill: orange)[sunset])),
    // The rain uses its own axis on the right.
    lq.yaxis(
      position: right,
      label: [rain / mm],
      lim: (0, 12),
      lq.plot(hours, rain, step: center, mark: none, color: blue.lighten(20%), label: [rain]),
    ),
  ),
  caption: [Temperature (left axis) and rain (right axis) over one day.],
) <fig-day>

The right axis of @fig-day is an _independent_ twin axis: it has its own
limits and its own plot. A _dependent_ axis only relabels the data, as the
Fahrenheit scale of @fig-units does.

#figure(
  lq.diagram(
    width: 10cm,
    height: 3.2cm,
    xlabel: [hour],
    ylabel: [°C],
    margin: (x: 0%, y: 10%),
    yaxis: (mirror: false),
    lq.plot(hours, temp, mark: none),
    lq.plot(hours, temp, every: 4, stroke: none, mark: "d", mark-size: 6pt),
    lq.yaxis(
      position: right,
      label: [°F],
      functions: (c => c * 1.8 + 32, f => (f - 32) / 1.8),
    ),
    lq.xaxis(
      position: top,
      label: [hours until midnight],
      functions: (h => 24 - h, r => 24 - r),
      tick-distance: 6,
    ),
  ),
  caption: [The same curve with two dependent axes.],
) <fig-units>

= Laws on logarithmic axes

== Pressure against height

Pressure falls nearly exponentially with height,
$p(h) = p_0 e^(-h slash H)$ with $H approx 8.4 "km"$; on a logarithmic
$y$-axis the three curves of @fig-pressure are straight lines.

#let heights = lq.linspace(0, 30, num: 31)

#figure(
  lq.diagram(
    width: 10cm,
    height: 5cm,
    yscale: "log",
    xlabel: [height / km],
    ylabel: [pressure / hPa],
    ylim: (10, 2000),
    legend: (position: bottom + left),
    cycle: (
      (color: red, stroke: (dash: "solid")),
      (color: green.darken(20%), stroke: (dash: "dashed")),
      (color: blue, stroke: (dash: "dash-dotted")),
    ),
    ..((7.4, [cold, $H = 7.4$]), (8.4, [standard, $H = 8.4$]), (9.2, [warm, $H = 9.2$])).map(((scale-height, name)) => lq.plot(
      heights,
      h => 1013.25 * calc.exp(-h / scale-height),
      mark: none,
      label: name,
    )),
    lq.scatter(
      (0.5, 1.5, 3.1, 5.6, 9.2, 12, 16.2, 20.6, 24, 26.5),
      (955, 845, 697, 505, 307, 194, 101, 51, 29, 20),
      mark: "s",
      size: 5pt,
      color: black,
      label: [balloon],
    ),
    lq.rect(11, 10, width: 9, height: 1990, fill: yellow.transparentize(80%), stroke: none, z-index: 1),
    lq.place(15.5, 1100, text(8pt)[tropopause]),
  ),
  caption: [Barometric pressure against height.],
) <fig-pressure>

== Drop sizes

The number of rain drops per size class follows a power law over three
decades (@fig-drops), so both axes are logarithmic. Marks are coloured by
the hour of the sample and sized by its weight.

#let sizes = lq.logspace(-1, 0.9, num: 16)
#let counts = sizes.zip(noise(16, seed: 99)).map(((d, j)) => 8000 * calc.pow(d, -2.3) * calc.exp(-1.1 * d) * (1 + 0.5 * j))

#figure(
  lq.diagram(
    width: 9cm,
    height: 5cm,
    xscale: "log",
    yscale: "log",
    xlabel: [diameter $d$ / mm],
    ylabel: [drops per m³],
    xaxis: (exponent: none),
    lq.plot(sizes, d => 8000 * calc.pow(d, -2.3) * calc.exp(-1.1 * d), mark: none, color: gray, label: [fit]),
    lq.scatter(
      sizes,
      counts,
      size: range(16).map(i => 20 + 12 * calc.rem(i * 5, 7)),
      color: range(16).map(i => calc.rem(i * 7, 24)),
      map: color.map.plasma,
      stroke: 0.4pt + black,
      label: [samples],
    ),
    lq.line((0.2, 20), (2, 20 * calc.pow(10, -2.3)), stroke: (dash: "dotted"), tip: none),
    lq.place(0.6, 3, text(8pt)[slope $-2.3$]),
  ),
  caption: [Drop size distribution.],
) <fig-drops>

== Pressure tendency

Tendencies are tiny most of the time and large in a squall, with either
sign. A symmetric logarithmic axis shows both ranges (@fig-tendency), here
as a stem plot.

#let tendency = (0.2, -0.1, 0.4, 1.5, 12, 85, -140, -22, -3, -0.6, 0.3, 0.1, -0.2, 2.5, 30, -9, -0.4)

#figure(
  lq.diagram(
    width: 10cm,
    height: 4cm,
    yscale: lq.scale.symlog(threshold: 1),
    xlabel: [sample],
    ylabel: [Pa / min],
    lq.stem(range(tendency.len()), tendency, mark: "o", color: purple, base-stroke: gray),
    lq.hlines(1, -1, stroke: (paint: gray, dash: "dashed", thickness: 0.5pt)),
  ),
  caption: [Pressure tendency on a symlog axis; linear between the dashed
    lines.],
) <fig-tendency>

@fig-day, @fig-units, @fig-pressure, @fig-drops and @fig-tendency are drawn
with a text size of #context [#text.size.pt() pt]; tick labels follow it.
