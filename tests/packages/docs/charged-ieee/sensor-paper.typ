// charged-ieee 0.1.4: a two-column US-letter paper with four authors, abstract, index terms,
// headings to level 3, numbered equations and the template's equation references, floating
// single-column and page-wide figures/tables, footnotes, raw blocks and an IEEE bibliography.
// Engine paths: parent-scoped floats in columns, show rules on figure/ref/heading with
// counters, context, CSL (ieee) citations, footnotes inside columns, column balancing.
#import "@preview/charged-ieee:0.1.4": ieee

#show: ieee.with(
  title: [Adaptive Duty Cycling for Solar-Powered Soil-Moisture Sensor Networks],
  abstract: [
    Soil-moisture probes buried in orchards must run for years on a coin-sized solar cell and a
    supercapacitor. We describe a scheduler that chooses, once per hour, how often a node samples
    and transmits, using a scalar forecast of tomorrow's irradiance and the measured state of
    charge. On a testbed of 36 nodes observed for three growing seasons the scheduler delivers
    94.1 percent of the readings an agronomist asked for, while a fixed schedule with the same
    energy budget delivers 71.8 percent and browns out on 23 nights.
  ],
  authors: (
    (
      name: "Ingrid Halvorsen",
      department: [Department of Embedded Systems],
      organization: [Fjordvik Institute of Technology],
      location: [Fjordvik, Norway],
      email: "ingrid.halvorsen@fit.example",
    ),
    (
      name: "Chidi Okafor",
      department: [Rural Networks Group],
      organization: [Institute for Rural Networks],
      location: [Enugu, Nigeria],
      email: "okafor@irn.example",
    ),
    (
      name: "Marisol Reyes",
      organization: [Valle Verde Agricultural Cooperative],
      location: [Mendoza, Argentina],
      email: [m.reyes (at) valleverde.example],
    ),
    (
      name: "Haruto Tanaka",
      department: [Soil Physics Laboratory],
      organization: [Kisogawa University],
    ),
  ),
  index-terms: ("Duty cycling", "energy harvesting", "soil moisture", "sensor networks", "scheduling"),
  bibliography: bibliography("refs.bib"),
  figure-supplement: [Fig.],
)

// A small plotting helper: a polyline through data points scaled into a box.
#let plot-line(points, width, height, xmax, ymax, paint) = {
  let scaled = points.map(((x, y)) => (x / xmax * width, height - y / ymax * height))
  curve(
    stroke: 0.8pt + paint,
    curve.move(scaled.first()),
    ..scaled.slice(1).map(p => curve.line(p)),
  )
}

#let harvest = ((0, 0), (2, 0), (5, 3), (7, 21), (9, 48), (11, 71), (12, 76), (14, 63), (16, 34), (18, 8), (20, 0), (24, 0))
#let load = ((0, 12), (4, 12), (6, 14), (8, 26), (10, 34), (12, 38), (14, 34), (17, 22), (19, 14), (24, 12))

= Introduction

Irrigation in dry-land orchards is scheduled from the water content of the root zone, which
changes slowly at night and quickly after the valves open. A probe that reports every ten
minutes around irrigation and every two hours otherwise is as useful as one that reports
every ten minutes all day, and it needs a fifth of the energy @halvorsen2019duty. The
difficulty is that the energy arrives on the sun's schedule and not on the agronomist's.

Earlier systems fix the reporting period at deployment time @tanaka2021loam, or adapt it to
the stored energy alone @lindqvist2016harvest[Ch.~6]. The first wastes energy in summer and
fails in winter; the second reacts only after the capacitor has already sagged.#footnote[A
1~F supercapacitor at 2.1~V holds roughly 2.2~J above the brown-out threshold of the radio,
which is about forty transmissions.] We combine both signals with a forecast, as proposed in
general terms by Ibrahim @ibrahim2017chapter, and evaluate the result in the field.

The contributions of this paper are:
+ a charge model that fits in 40 bytes of state (@sec:model);
+ a scheduler with a provable no-brown-out condition, stated in @eq:safe;
+ three seasons of measurements from 36 nodes (@sec:eval), including
  + the radio link budget of each node,
  + nightly minimum voltages, and
  + the delivered fraction of requested readings.

= System Model <sec:model>

== Energy Storage

Let $E_k$ be the energy in the capacitor at the start of hour $k$, $H_k$ the energy harvested
during that hour and $C_k$ the energy consumed. With a leakage factor $lambda$ per hour,
$ E_(k+1) = (1 - lambda) E_k + eta H_k - C_k, $ <eq:balance>
where $eta$ is the efficiency of the boost converter. Consumption is the sum of a sleep floor
and the cost of the $n_k$ sample-and-send cycles scheduled in the hour:
$ C_k = P_"sleep" T + n_k (e_"meas" + e_"tx"). $ <eq:consumption>
Substituting @eq:consumption into @eq:balance gives a recurrence that is linear in the only
decision variable, $n_k$.

=== Leakage
Leakage in the cells we use is not constant: it roughly doubles for every 12~K, as Petrov
measured @petrov2020thesis. We tabulate $lambda$ in eight temperature bins.

=== Converter efficiency
Below 40~mV of input the converter does not start. We model this as $eta = 0$ for
$H_k < H_"min"$ and a constant otherwise, which over-estimates dawn and dusk by a few percent.

== Irradiance Forecast

Each node keeps a scalar Kalman filter of the day's total harvest @nakamura2018kalman. With
yesterday's total $D_(d-1)$ and the filtered estimate $hat(D)_(d-1)$,
$ hat(D)_d = hat(D)_(d-1) + K_d (D_(d-1) - hat(D)_(d-1)), quad
  K_d = P_(d-1) / (P_(d-1) + R), $ <eq:kalman>
and the hourly shape is a fixed profile $s_k$ with $sum_k s_k = 1$, so the forecast for hour
$k$ is $hat(H)_k = s_k hat(D)_d$. @fig:day shows the profile against the load that the
scheduler chose on a typical day in March.

#figure(
  placement: top,
  box(width: 200pt, height: 92pt, {
    place(left + bottom, line(length: 200pt, stroke: 0.5pt))
    place(left + bottom, line(angle: -90deg, length: 92pt, stroke: 0.5pt))
    for i in range(1, 6) {
      place(left + bottom, dx: i * 40pt, dy: 0pt, line(angle: -90deg, length: 3pt, stroke: 0.5pt))
      place(left + bottom, dy: -i * 18pt, line(length: 200pt, stroke: (paint: luma(200), thickness: 0.3pt, dash: "dotted")))
    }
    place(top + left, plot-line(harvest, 200pt, 92pt, 24, 80, rgb("#c9770a")))
    place(top + left, plot-line(load, 200pt, 92pt, 24, 80, rgb("#1f5fa8")))
    place(top + right, dx: -4pt, dy: 2pt, text(7pt, fill: rgb("#c9770a"))[harvest (mJ/h)])
    place(top + right, dx: -4pt, dy: 11pt, text(7pt, fill: rgb("#1f5fa8"))[load (mJ/h)])
    place(bottom + right, dx: -4pt, dy: -3pt, text(7pt)[hour of day, 0 to 24])
  }),
  caption: [Harvested energy and scheduled load of node 17 on 14 March. The load follows the
    sun with a lag because readings are most valuable after the morning irrigation.],
) <fig:day>

== Radio

The nodes use a sub-gigahertz long-range link @lorawan2020spec at spreading factor 9. One
uplink of 18 bytes costs
$ e_"tx" = V I_"tx" t_"air" approx 3.0 "V" times 44 "mA" times 185 "ms" = 24.4 "mJ". $ <eq:tx>
The cost in @eq:tx dominates $e_"meas"$ by a factor of thirty, which is why the scheduler
batches up to four readings per uplink when the budget is tight.

= Scheduler

At the top of each hour the node solves a tiny planning problem over the next 24 hours:
maximise the weighted number of readings subject to never dropping below the reserve
$E_"min"$. Because @eq:balance is linear, the constraint for hour $j$ unrolls to
$ E_k (1-lambda)^(j-k) + sum_(i=k)^(j-1) (1-lambda)^(j-1-i) (eta hat(H)_i - C_i) >= E_"min". $ <eq:safe>

We solve it greedily: hours are sorted by the agronomic weight $w_k$, and cycles are added to
the most valuable hour until @eq:safe would be violated for some later hour. The greedy
choice is optimal when the weights are non-increasing after their peak, which holds for the
irrigation profiles of all three orchards.#footnote[A counter-example with two irrigation
windows per day exists; there the greedy plan loses at most one reading per day.]

```c
/* add cycles to the best hour that keeps every later hour safe */
for (uint8_t r = 0; r < HOURS; r++) {
  uint8_t h = rank[r];
  while (n[h] < N_MAX && safe_after(h, n[h] + 1))
    n[h]++;
}
```

The inner test `safe_after` evaluates @eq:safe incrementally and costs 24 multiplications in
Q15 arithmetic, so the whole plan takes under 3~ms on the 8-bit controller.

#figure(
  placement: top,
  scope: "parent",
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right, right, right),
    stroke: none,
    table.hline(),
    table.header([Policy], [Delivered (%)], [Brown-outs], [Min. voltage (V)], [Uplinks / day], [Readings / uplink], [Energy / day (J)]),
    table.hline(stroke: 0.5pt),
    [Fixed, 30 min], [71.8], [23], [1.62], [48.0], [1.00], [1.31],
    [Charge-only @lindqvist2016harvest], [83.5], [6], [1.74], [41.3], [1.22], [1.19],
    [Forecast-only], [88.9], [9], [1.69], [44.7], [1.47], [1.24],
    [Proposed], [*94.1*], [*0*], [*1.88*], [39.2], [2.06], [1.12],
    [Oracle (offline)], [96.7], [0], [1.90], [38.5], [2.11], [1.10],
    table.hline(),
  ),
  caption: [Three seasons, 36 nodes: delivered fraction of requested readings and energy use],
) <tab:results>

= Evaluation <sec:eval>

== Testbed

The 36 nodes are spread over three orchards described in the testbed report
@orchard2022report. Each node carries a 22 by 35~mm amorphous cell, a 1~F capacitor and two
capacitive probes at 20 and 50~cm depth @tanaka2021loam. Policies were rotated between nodes
every two weeks so that shading and soil type average out.

#figure(
  placement: bottom,
  table(
    columns: 4,
    align: (left, center, center, center),
    table.header([Orchard], [Nodes], [Soil], [Canopy]),
    [North slope], [12], [loam], [dense],
    [River flat], [14], [sandy loam], [open],
    [Terrace], [10], [clay], [mixed],
  ),
  caption: [Sites of the testbed],
) <tab:sites>

== Results

@tab:results summarises the outcome and @tab:sites the sites. The proposed scheduler never
browned out, as @eq:safe promises whenever the forecast error stays below the reserve. The
charge-only policy fails on the first overcast day after a sunny week, when the capacitor is
full but tomorrow's harvest is a tenth of today's; the forecast-only policy fails when a
node is shaded by new growth and the profile $s_k$ no longer matches.

=== Sensitivity to the reserve
Halving $E_"min"$ raises the delivered fraction by 0.6 points and produces two brown-outs
in the clay orchard. Doubling it costs 2.3 points and changes nothing else.

=== Sensitivity to the forecast
Replacing the filter of @eq:kalman by yesterday's total costs 1.9 points; a perfect
forecast (the oracle row) gains 2.6. #lorem(40)

== Discussion

#lorem(120)

The remaining gap to the oracle comes almost entirely from the first two days after a
weather change. #lorem(90)

= Related Work

Surveys of harvesting-aware scheduling @halvorsen2019duty @ibrahim2017chapter distinguish
energy-neutral operation from quality-of-service scheduling. Our work belongs to the second
family but borrows the reserve from the first. #lorem(100)

Forecasting on the node itself was shown to be practical by Nakamura and Fitzgerald
@nakamura2018kalman; we reuse their filter unchanged. #lorem(80)

= Conclusion

A forecast, a charge measurement and a linear model are enough to schedule a soil-moisture
node safely. The scheduler fits in 1.1~kB of code and 40 bytes of state, and in three
seasons it delivered 94 percent of the requested readings without a single brown-out.
#lorem(60)

= Acknowledgment

We thank the growers of the Valle Verde cooperative for letting us dig 72 holes in their
orchards, and for filling them again.
