// charged-ieee 0.1.4: the other option values: A4 paper (fixed margins), two authors, an
// abstract without index terms, `figure-supplement: [Figure]`, a listing figure (the
// generic-supplement branch of the caption rule), level-4 and unnumbered headings, the
// alternative spelling of the acknowledgement heading, multi-line aligned equations,
// a full bibliography of uncited entries. Engine paths: float placement with `auto`,
// figure kinds and counters, nested enum numbering "1)a)i)", term lists in columns.
#import "@preview/charged-ieee:0.1.4": ieee

#show: ieee.with(
  title: [A Note on Clock Drift in Tide Gauges],
  abstract: [
    Tide gauges along the Skerry coast log the water level once a minute against a quartz
    clock that is corrected by hand twice a year. We show that the drift between corrections
    is predictable from the logger's own temperature record, and that removing it lowers the
    residual of the harmonic fit by a third.
  ],
  authors: (
    (
      name: "Aoife Fitzgerald",
      department: [Harbour Office],
      organization: [Port of Kinvarra],
      location: [Kinvarra, Ireland],
      email: "aoife@kinvarra-port.example",
    ),
    (
      name: "Kwame Osei",
      organization: [Coastal Survey of Ghana],
      location: [Takoradi, Ghana],
    ),
  ),
  paper-size: "a4",
  figure-supplement: [Figure],
  bibliography: bibliography("refs.bib", full: true, title: [Further Reading]),
)

= Problem

A gauge that is thirty seconds late reports the tide of thirty seconds ago. At spring tide
in a narrow inlet the level changes by 4~mm in that time, which is more than the resolution
of the float.#footnote[The float encoder resolves 1~mm; the stilling well damps waves
shorter than about 12~s.] The loggers are visited in April and October; in between, nobody
knows what time they think it is.

/ Drift: the difference between logger time and true time, in seconds.
/ Rate: the derivative of the drift, in parts per million (ppm).
/ Turnover: the temperature at which a tuning-fork crystal runs fastest.

== Crystal Model

The rate of a 32~kHz tuning-fork crystal is a parabola in temperature,
$ r(T) = r_0 - beta (T - T_0)^2, $ <eq:parabola>
with $beta approx 0.034 "ppm/K"^2$ and turnover $T_0 approx 25 degree"C"$. The drift after
$n$ minutes is the sum of the rates:
$ d_n &= d_0 + 60 dot 10^(-6) sum_(i=1)^n r(T_i) \
      &= d_0 + 60 dot 10^(-6) (n r_0 - beta sum_(i=1)^n (T_i - T_0)^2). $ <eq:drift>
Both unknowns of @eq:parabola that vary between loggers, $r_0$ and $T_0$, can be estimated
from two visits if the temperatures in between are known; @eq:drift is linear in $r_0$ and
quadratic in $T_0$.

=== Estimation
We proceed as follows.
+ Read the two corrections $d_"apr"$ and $d_"oct"$ from the visit log.
+ For each candidate $T_0$ on a grid of 0.1~K,
  + compute the sum of squares in @eq:drift,
  + solve for $r_0$ in closed form:
    + from April to October,
    + from October to April of the next year,
  + keep the candidate whose two values of $r_0$ agree best.
+ Interpolate the drift for every minute and shift the record.

==== A caveat
The grid search needs two half-years with different mean temperatures. Loggers in heated
huts do not qualify.

#figure(
  ```python
  def rate(temp, r0, t0, beta=0.034):
      return r0 - beta * (temp - t0) ** 2

  def drift(temps, r0, t0, d0=0.0):
      total = d0
      for t in temps:           # one value per minute
          total += 60e-6 * rate(t, r0, t0)
      return total
  ```,
  caption: [The model of @eq:parabola in eight lines],
) <lst:model>

== Data

#figure(
  placement: auto,
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    table.header([Gauge], [$r_0$ (ppm)], [$T_0$ (#sym.degree\C)], [Drift (s)]),
    [Kinvarra pier], [1.8], [24.6], [$-41$],
    [Black Head], [$-0.6$], [25.9], [$-78$],
    [Inishmaan slip], [3.1], [23.8], [$-12$],
    [Rossaveal], [0.4], [25.2], [$-55$],
  ),
  caption: [Fitted crystal parameters and drift over one half-year],
) <tab:fit>

#figure(
  placement: auto,
  {
    let temps = (9, 8, 8, 10, 13, 16, 18, 19, 17, 14, 11, 9)
    let months = ("J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D")
    stack(
      dir: ltr,
      spacing: 4pt,
      ..temps.zip(months).map(((t, m)) => stack(
        dir: ttb,
        spacing: 2pt,
        v((20 - t) * 3pt),
        rect(width: 12pt, height: t * 3pt, fill: gradient.linear(rgb("#7db3e8"), rgb("#1f5fa8"), angle: 90deg)),
        text(7pt, m),
      )),
    )
  },
  caption: [Monthly mean temperature inside the Kinvarra logger housing],
) <fig:temps>

@tab:fit lists the parameters for four gauges, @fig:temps the temperature that drives them
and @lst:model the code. All four loggers run slow in winter, as expected: the housing is
15~K below turnover.

= Effect on the Harmonic Fit

#lorem(70)

#heading(numbering: none)[A remark on leap seconds]

None occurred in the period. #lorem(40)

== Residuals

#lorem(150)

= Conclusion

Correcting the clock from the temperature record costs nothing and removes a third of the
residual. #lorem(50)

= Acknowledgements

The visit logs were transcribed by the harbour office's summer students.
