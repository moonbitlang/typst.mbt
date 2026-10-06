// cetz-plot 0.1.4 on cetz 0.5.2: sampled function plots (heavy float
// computation), axis styles scientific / scientific-auto / school-book /
// left, legends inside and outside, custom tick formats, log axes, secondary
// axes, fill-between, hypographs, parametric curves, contours, annotations
// and plot anchors. Figures with captions, references and a plot per grid cell.

#import "@preview/cetz:0.5.2"
#import "@preview/cetz-plot:0.1.4": plot

#set page(width: 17cm, height: 24cm, margin: 1.5cm, numbering: "1")
#set heading(numbering: "1.1")
#set par(justify: true)
#set math.equation(numbering: "(1)")
#show figure.caption: set text(9pt)

= A pendulum that loses energy

The bob of a clock pendulum without its escapement swings as
$ theta(t) = theta_0 e^(-gamma t) cos(omega t), $ <eq-theta>
with $theta_0 = 0.2$, $gamma = 0.15 "s"^(-1)$ and $omega = 2 pi slash 2 "s"$.
@fig-decay plots @eq-theta with its envelope; the band between the two
envelope curves is filled.

#let theta0 = 0.2
#let damp = 0.15
#let om = calc.pi
#let swing(t) = theta0 * calc.exp(-damp * t) * calc.cos(om * t)
#let env(t) = theta0 * calc.exp(-damp * t)

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    set-style(axes: (stroke: 0.5pt, tick: (stroke: 0.5pt)), legend: (stroke: 0.4pt, padding: 0.12, item: (spacing: 0.12)))
    plot.plot(
      size: (11, 5),
      name: "decay",
      x-label: [time $t$ / s],
      y-label: [angle $theta$ / rad],
      x-tick-step: 2,
      x-minor-tick-step: 0.5,
      y-tick-step: 0.1,
      y-min: -0.22,
      y-max: 0.22,
      x-grid: true,
      y-grid: "both",
      y-minor-tick-step: 0.05,
      legend: "inner-north-east",
      {
        plot.add-fill-between(domain: (0, 14), samples: 60, env, t => -env(t), style: (fill: blue.lighten(88%), stroke: none), label: [envelope])
        plot.add(domain: (0, 14), samples: 280, swing, style: (stroke: blue + 1pt), label: $theta(t)$)
        plot.add(domain: (0, 14), env, style: (stroke: (paint: red, dash: "dashed")), label: $plus.minus theta_0 e^(-gamma t)$)
        plot.add(domain: (0, 14), t => -env(t), style: (stroke: (paint: red, dash: "dashed")))
        plot.add-hline(theta0 / calc.e, -theta0 / calc.e, style: (stroke: (paint: gray, dash: "dotted")))
        plot.add-vline(1 / damp, style: (stroke: (paint: gray, dash: "dotted")))
        plot.add-anchor("tau", (1 / damp, theta0 / calc.e))
        plot.annotate({
          content((10.5, -0.17), text(8pt)[half-life $ln 2 slash gamma approx #calc.round(calc.ln(2) / damp, digits: 2)$ s])
        })
      },
    )
    line("decay.tau", (rel: (1.2, 0.9)), mark: (start: ">", fill: black), stroke: 0.5pt, name: "note")
    content("note.end", anchor: "west", padding: 2pt, text(8pt)[$t = tau = 1 slash gamma$])
  }),
  caption: [The decaying swing with its envelope.],
) <fig-decay>

== Energy on a logarithmic axis

The energy falls as $E prop e^(-2 gamma t)$, a straight line on a
logarithmic axis. The right axis of @fig-energy shows the count of half
swings on a linear scale.

#figure(
  cetz.canvas(length: 1cm, {
    plot.plot(
      size: (10, 4),
      axis-style: "scientific",
      x-label: [$t$ / s],
      y-label: [$E slash E_0$],
      y2-label: [half swings],
      y-mode: "log",
      y-base: 10,
      y-format: "sci",
      y-min: 0.001,
      y-max: 1,
      y-tick-step: 1,
      y-minor-tick-step: 1,
      y-grid: "both",
      x-tick-step: 4,
      y2-min: 0,
      y2-max: 24,
      y2-tick-step: 6,
      legend: "south",
      legend-style: (orientation: ltr, stroke: none),
      {
        plot.add(domain: (0, 22), samples: 40, t => calc.exp(-2 * damp * t), label: [energy], style: (stroke: purple + 1.2pt))
        plot.add(domain: (0, 22), samples: 120, t => calc.exp(-2 * damp * t) * (0.85 + 0.15 * calc.cos(2 * om * t)), label: [kinetic share], style: (stroke: (paint: orange, thickness: 0.6pt)))
        plot.add(domain: (0, 22), samples: 23, t => calc.floor(t), axes: ("x", "y2"), line: "hv", label: [count], style: (stroke: teal))
      },
    )
  }),
  caption: [Energy (log scale, left) and number of half swings (right).],
) <fig-energy>


= Phase portraits and textbook axes

With the angular velocity on the second axis the motion becomes a spiral.
@fig-phase uses the school-book style, in which the axes cross in the
origin, and locks the aspect ratio so that circles stay circles.

#figure(
  grid(
    columns: 2,
    column-gutter: 1cm,
    align: bottom,
    cetz.canvas(length: 1cm, {
      plot.plot(
        size: (6, 6),
        axis-style: "school-book",
        x-label: $theta$,
        y-label: $dot(theta) slash omega$,
        x-tick-step: 0.1,
        y-tick-step: 0.1,
        x-min: -0.22,
        x-max: 0.22,
        y-min: -0.22,
        y-max: 0.22,
        x-equal: "y",
        {
          // A parametric curve: the function returns a point.
          plot.add(
            domain: (0, 16),
            samples: 400,
            t => (swing(t), -theta0 * calc.exp(-damp * t) * calc.sin(om * t)),
            style: (stroke: blue + 0.7pt),
          )
          plot.add(((theta0, 0),), mark: "o", mark-size: 0.15, mark-style: (fill: red, stroke: none))
          plot.annotate({
            import cetz.draw: *
            content((0.15, 0.17), text(8pt)[start], name: "s")
            line("s.south", (theta0, 0.012), stroke: 0.4pt)
          })
        },
      )
    }),
    cetz.canvas(length: 1cm, {
      plot.plot(
        size: (6, 6),
        axis-style: "left",
        x-label: $x$,
        y-label: $y$,
        x-tick-step: 1,
        y-tick-step: 1,
        x-min: -1.2,
        x-max: 1.2,
        y-min: -1.2,
        y-max: 1.2,
        legend: "north",
        legend-style: (orientation: ltr, stroke: none, item: (spacing: 0.2)),
        {
          for (i, (a, b)) in ((1, 2), (3, 2), (5, 4)).enumerate() {
            plot.add(
              domain: (0, 2 * calc.pi),
              samples: 240,
              t => (calc.sin(a * t + calc.pi / 4), calc.sin(b * t)),
              label: [#a:#b],
              style: (stroke: (paint: (red, green.darken(20%), blue).at(i), thickness: 0.6pt)),
            )
          }
        },
      )
    }),
  ),
  caption: [Left: phase portrait of @eq-theta. Right: three Lissajous
    figures of a double pendulum's bench test.],
) <fig-phase>

== Period against amplitude

For large swings the period grows. The series
$T slash T_0 = 1 + theta_0^2 slash 16 + 11 theta_0^4 slash 3072 + dots$
is compared in @fig-period with a numerical value from the arithmetic
geometric mean, $T slash T_0 = 1 slash "agm"(1, cos(theta_0 slash 2))$.
Measured points are drawn with marks, and the tick labels are written as
fractions of $pi$.

#let agm(a, b) = {
  for _ in range(12) {
    (a, b) = ((a + b) / 2, calc.sqrt(a * b))
  }
  a
}
#let period-exact(th) = 1 / agm(1, calc.cos(th / 2))
#let period-series(th, n) = (1, 1 / 16, 11 / 3072, 173 / 737280).slice(0, n).enumerate().map(((k, c)) => if k == 0 { c } else { c * calc.pow(th, 2 * k) }).sum()
#let measured = ((0.3, 1.006), (0.7, 1.031), (1.1, 1.083), (1.5, 1.16), (1.9, 1.29), (2.3, 1.49), (2.7, 1.87))
#let pi-format(v) = {
  let k = calc.round(v / (calc.pi / 4))
  if k == 0 { $0$ } else if k == 1 { $pi slash 4$ } else if k == 4 { $pi$ } else if k == 2 { $pi slash 2$ } else { $#k pi slash 4$ }
}

#figure(
  cetz.canvas(length: 1cm, {
    plot.plot(
      size: (11, 5.5),
      axis-style: "scientific-auto",
      x-label: [amplitude $theta_0$],
      y-label: $T slash T_0$,
      x-tick-step: calc.pi / 4,
      x-format: pi-format,
      x-min: 0,
      x-max: 3,
      y-min: 0.95,
      y-max: 2.1,
      y-tick-step: 0.25,
      y-decimals: 2,
      y-grid: true,
      legend: "inner-north-west",
      plot-style: cetz.palette.dark-green,
      {
        plot.add(domain: (0, 3), samples: 80, period-exact, label: [exact (agm)], style: (stroke: black + 1.2pt))
        for n in (2, 3, 4) {
          plot.add(domain: (0, 3), samples: 40, th => period-series(th, n), label: [series, #n terms], line: "spline")
        }
        plot.add(measured, mark: "square", mark-size: 0.16, style: (stroke: none), mark-style: (fill: yellow, stroke: black + 0.5pt), label: [bench])
        plot.add(measured.map(((x, y)) => (x, y - 0.02)), mark: "x", mark-size: 0.12, style: (stroke: (dash: "dotted", paint: gray)), line: "linear", label: [corrected])
      },
    )
  }),
  caption: [Period of the pendulum against its amplitude.],
) <fig-period>


= Two parameters at once

How well a drive at frequency $f$ and damping $gamma$ excites the pendulum
is a function of two variables,
$A(f, gamma) = 1 slash sqrt((1 - f^2)^2 + (2 gamma f)^2)$. @fig-contour draws
its level lines, sampled on a #(30)-by-#(30) grid, and next to it three
cuts at fixed damping with a hypograph filled under the lowest.

#let amp(f, g) = 1 / calc.sqrt(calc.pow(1 - f * f, 2) + calc.pow(2 * g * f, 2))

#figure(
  grid(
    columns: 2,
    column-gutter: 0.8cm,
    cetz.canvas(length: 1cm, {
      plot.plot(
        size: (6, 5),
        x-label: [drive $f$],
        y-label: [damping $gamma$],
        x-tick-step: 0.5,
        y-tick-step: 0.2,
        x-min: 0,
        x-max: 2,
        y-min: 0.05,
        y-max: 0.8,
        {
          plot.add-contour(
            x-domain: (0, 2),
            y-domain: (0.05, 0.8),
            x-samples: 30,
            y-samples: 30,
            z: (0.5, 1, 1.5, 2.5, 4),
            fill: true,
            style: (stroke: 0.4pt + black, fill: rgb(200, 60, 20, 22%)),
            amp,
          )
          plot.add(domain: (0.05, 0.7), g => (calc.sqrt(1 - 2 * g * g), g), style: (stroke: (paint: blue, dash: "dashed")))
        },
      )
    }),
    cetz.canvas(length: 1cm, {
      plot.plot(
        size: (6, 5),
        x-label: [drive $f$],
        y-label: [gain $A$],
        x-tick-step: 0.5,
        y-tick-step: 1,
        y-max: 5.5,
        y-min: 0,
        legend: "inner-north-east",
        {
          plot.add(domain: (0, 2), samples: 60, f => amp(f, 0.4), hypograph: true, style: (stroke: none, fill: green.lighten(80%)))
          for (g, col) in ((0.1, red), (0.2, orange), (0.4, green.darken(20%))) {
            plot.add(domain: (0, 2), samples: 160, f => amp(f, g), label: $gamma = #g$, style: (stroke: col + 0.8pt))
          }
          plot.add-vline(1, style: (stroke: (dash: "dotted")))
        },
      )
    }),
  ),
  caption: [Gain of the driven pendulum: level lines (left; the dashed
    curve joins the maxima) and three cuts (right).],
) <fig-contour>

Together, @fig-decay, @fig-energy, @fig-phase, @fig-period and @fig-contour
describe the clock without its escapement.
