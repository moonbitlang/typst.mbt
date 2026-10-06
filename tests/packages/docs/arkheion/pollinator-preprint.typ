// arkheion 0.1.2: an arXiv-style preprint with four authors (three with ORCID: the package's
// SVG icon inside a link inside a grid), abstract, keywords, date, headings to level 4
// (run-in from level 4), numbered equations, tables, a drawn figure, footnotes, appendices
// via `arkheion-appendices` (letter numbering from a closure) and a bibliography.
// Engine paths: SVG image from a package, nested grids with negative padding, heading show
// rule by level, counter(heading).update + numbering function, page numbering, CSL.
#import "@preview/arkheion:0.1.2": arkheion, arkheion-appendices

#show: arkheion.with(
  title: "Counting Flower Visitors with Solar Cameras: Detection, Double Counting and What Survives Both",
  authors: (
    (
      name: "Marisol Reyes",
      email: "m.reyes@valleverde.example",
      affiliation: "Valle Verde Field Station",
      orcid: "0000-0001-5109-3700",
    ),
    (
      name: "Min-jun Park",
      email: "mjpark@hanbit.example",
      affiliation: "Hanbit Institute of Technology",
      orcid: "0000-0002-9079-593X",
    ),
    (
      name: "Miriam Hale",
      email: "m.hale@fenland.example",
      affiliation: "Fenland University",
    ),
    (
      name: "Kwame Osei",
      email: "osei@csg.example",
      affiliation: "Coastal Survey of Ghana",
      orcid: "0000-0003-1415-9269",
    ),
  ),
  abstract: [
    Fixed cameras promise continuous counts of flower visitors, but a camera sees the same
    bee many times and misses many others. We combine a small on-device detector with an
    N-mixture model that separates abundance from detection, and validate it against 312
    hours of observer counts in 24 meadow plots. Camera-derived abundance explains 81 % of
    the variance of the observer counts once detection is allowed to vary with temperature
    and time of day; raw detections explain 46 %. The remaining error is dominated by
    hoverflies, which the detector confuses with small wasps.
  ],
  keywords: ("pollinators", "camera traps", "N-mixture models", "edge inference", "field methods"),
  date: "12 September 2024",
)

#set cite(style: "chicago-author-date")
#show link: underline

= Introduction

Pollinator monitoring rests on people standing in meadows with clipboards. The standard
protocol asks for ten minutes per flower patch in fair weather @ferrand2019protocol, which
gives accurate snapshots and very little coverage: a season of weekly visits samples about
0.1 % of daylight hours. Cameras invert the trade-off, as #cite(<reyes2020pollinators>, form: "prose")
showed with hand-annotated footage.

What cameras produce, however, is _detections_, not animals. A single bumblebee working a
patch of knapweed for four minutes yields forty detections at ten-second intervals, and a
solitary bee that visits for two seconds between frames yields none.#footnote[At one frame
per ten seconds, a visit of duration $d$ seconds is captured with probability
$min(1, d\/10)$ if arrival times are uniform.] This paper is about turning the first into
an estimate of the second.

= Methods

== Hardware and detector

Each unit is a 2-megapixel camera on a microcontroller with a 1~W panel, running the
detector of #cite(<park2022tiny>, form: "prose") at one frame per ten seconds between sunrise and sunset.
Frames with detections are stored; all others are discarded on the device.

=== Classes
The detector distinguishes five classes: honeybees, bumblebees, solitary bees, hoverflies
and "other".

==== Training data
We fine-tuned on the Meadow-Cam frames @vogel2023dataset, holding out all frames from the
24 plots of this study.

==== Thresholds
A detection is kept if its confidence exceeds 0.45, the value that equalises precision and
recall on the held-out frames.

== Statistical model

Let $N_i$ be the number of individuals of a class using plot $i$ on a given day, and
$y_(i t)$ the number of _tracks_ (detections linked across consecutive frames) in hour $t$.
Following #cite(<hale2015occupancy>, form: "prose", supplement: [ch.~7]) we assume
$ N_i tilde "Poisson"(lambda_i), quad y_(i t) | N_i tilde "Binomial"(N_i, p_(i t)), $ <eq:nmix>
with log-linear abundance and logit-linear detection,
$ log lambda_i = alpha_0 + alpha_1 x_i, quad
  "logit" p_(i t) = beta_0 + beta_1 T_(i t) + beta_2 T_(i t)^2 + beta_3 h_t, $ <eq:links>
where $x_i$ is floral cover, $T_(i t)$ air temperature and $h_t$ the hour. The quadratic
term in @eq:links follows #cite(<petrov2021nmixture>, form: "prose"), who found that
activity peaks near 24 °C. Marginalising $N_i$ in @eq:nmix gives the likelihood
$ L(alpha, beta) = product_i sum_(N = max_t y_(i t))^(K)
  (e^(-lambda_i) lambda_i^N) / N! product_t binom(N, y_(i t)) p_(i t)^(y_(i t)) (1 - p_(i t))^(N - y_(i t)), $ <eq:lik>
truncated at $K = 200$.

== Validation counts

Two observers counted visitors on each plot for 13 hours spread over the season, following
the timed protocol. @tab:effort summarises the effort.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto),
    align: (left, right, right, right, right),
    stroke: none,
    table.hline(),
    table.header[Habitat][Plots][Camera hours][Observer hours][Tracks],
    table.hline(stroke: 0.5pt),
    [Hay meadow], [8], [9,412], [104], [48,210],
    [Road verge], [6], [7,020], [78], [21,884],
    [Orchard floor], [6], [6,866], [78], [30,115],
    [Field margin], [4], [4,590], [52], [9,407],
    table.hline(stroke: 0.5pt),
    [*Total*], [*24*], [*27,888*], [*312*], [*109,616*],
    table.hline(),
  ),
  caption: [Sampling effort by habitat],
) <tab:effort>

= Results

== Detection

Detection probability per individual and hour ranged from 0.08 on cold mornings to 0.61 at
24 °C in the early afternoon (@fig:detection). The fitted optimum,
$T^* = -beta_1 \/ (2 beta_2) = 24.3$ °C, agrees with the literature.

#figure(
  box(width: 260pt, height: 110pt, {
    // Fitted quadratic-logit curve for three hours of the day.
    let p(t, h) = {
      let z = -6.9 + 0.52 * t - 0.0107 * t * t + 0.05 * h
      1 / (1 + calc.exp(-z))
    }
    place(left + bottom, line(length: 260pt, stroke: 0.5pt))
    place(left + bottom, line(angle: -90deg, length: 110pt, stroke: 0.5pt))
    for (h, paint) in ((9, rgb("#4c78a8")), (13, rgb("#e45756")), (17, rgb("#72b7b2"))) {
      let pts = range(8, 37).map(t => ((t - 8) / 28 * 260pt, 110pt - p(t, h) / 0.7 * 110pt))
      place(top + left, curve(stroke: 1pt + paint, curve.move(pts.first()), ..pts.slice(1).map(q => curve.line(q))))
      let (x, y) = pts.at(16)
      place(top + left, dx: x - 8pt, dy: y - 9pt, text(7pt, fill: paint)[#h:00])
    }
    for t in range(10, 37, step: 5) {
      place(left + bottom, dx: (t - 8) / 28 * 260pt - 4pt, dy: 9pt, text(7pt)[#t])
    }
    place(right + bottom, dx: -2pt, dy: -3pt, text(7pt)[temperature (°C)])
    place(left + top, dx: 3pt, text(7pt)[detection probability, 0 to 0.7])
  }),
  gap: 1.4em,
  caption: [Fitted detection probability against temperature at three times of day],
) <fig:detection>

== Abundance

@tab:fit compares three predictors of the observer counts. Raw detections are dominated by
long visits of a few bumblebees; linking detections into tracks removes most of that, and
the model of @eq:nmix removes the dependence on weather.

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    table.header[Predictor][$R^2$][Slope][RMSE (visitors / h)],
    [Raw detections], [0.46], [0.11], [9.8],
    [Tracks], [0.63], [0.58], [7.1],
    [N-mixture abundance], [0.81], [0.94], [4.4],
  ),
  caption: [Agreement with observer counts over 312 plot-hours],
) <tab:fit>

#lorem(120)

== Errors by class

#lorem(80)

= Discussion

#lorem(140)

The likelihood @eq:lik is cheap enough to fit on a laptop, and the cameras cost less than a
day of an observer's time. #lorem(60)

= Conclusion

Camera counts become comparable with observer counts once detection is modelled; without
that step they mostly measure the weather. #lorem(40)

#bibliography("refs.bib", style: "chicago-author-date")

#show: arkheion-appendices

= Detector details

== Architecture
The detector has 0.9 million parameters and runs in 410 ms per frame.

== Confusion matrix

#figure(
  table(
    columns: 6,
    align: center,
    table.header[][Honey][Bumble][Solitary][Hover][Other],
    [Honey], [912], [14], [31], [22], [21],
    [Bumble], [9], [958], [6], [3], [24],
    [Solitary], [44], [8], [803], [97], [48],
    [Hover], [25], [2], [88], [741], [144],
    [Other], [18], [11], [39], [120], [812],
  ),
  caption: [Confusion matrix on 5,000 held-out frames (rows: truth)],
) <tab:confusion>

= Priors and computation

The parameters of @eq:links were given independent normal priors with standard deviation
2.5 on the standardised scale. @tab:confusion shows where the detector errs.

== Convergence
#lorem(50)
