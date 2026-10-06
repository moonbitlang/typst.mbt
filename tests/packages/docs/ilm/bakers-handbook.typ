// ilm 2.1.1: a multi-chapter handbook with the default cover page (three authors, abstract,
// date format), preface, table of contents, chapter page breaks, the alternating footer
// with the chapter name, external-link circles, custom raw text settings, blockquotes,
// figures/tables/listings and their three indices, an appendix with its own numbering,
// footnotes, numbered equations and a bibliography.
// Engine paths: footer context with queries (heading before here, page of each chapter),
// show rules on link/raw/heading/table.cell, weak page breaks, outline with several
// targets, counter(figure.where(kind)) at the end, breakable table figures.
#import "@preview/ilm:2.1.1": *

#set text(lang: "en")

#show: ilm.with(
  title: [The Patient Loaf],
  authors: ("Mathilde Brandt", "Kenji Sato", "Adaeze Nwosu"),
  date: datetime(year: 2024, month: 3, day: 9),
  date-format: "[weekday repr:long], [day padding:none] [month repr:long] [year]",
  abstract: [
    A working handbook for bakers who keep a sourdough starter at home: how to feed it, how
    to read a dough, and how to bake it in an ordinary oven. Every formula is given in
    baker's percentages and every schedule fits around a working day.
  ],
  preface: [
    #align(center + horizon)[
      _For the neighbours, who took the failures \ and said they were delicious._

      #v(2em)
      #block(width: 70%)[
        #set par(justify: true)
        This handbook grew out of a shared notebook kept beside the oven of a community
        kitchen. Quantities were tested on a 5~kg batch and scaled down; where a step
        failed for us we say so. Nothing here is new, and all of it has been baked.
      ]
    ]
  ],
  table-of-contents: outline(depth: 2),
  appendix: (
    enabled: true,
    title: "Appendix",
    heading-numbering-format: "A.1.",
    body: [
      = Conversion Tables
      == Volume to weight
      The handbook weighs everything, but old recipes do not.

      #figure(
        table(
          columns: (1fr, auto, auto),
          align: (left, right, right),
          table.header[Ingredient][1 cup (g)][1 tablespoon (g)],
          [Bread flour], [136], [8.5],
          [Wholemeal flour], [128], [8.0],
          [Rye flour, medium], [102], [6.4],
          [Water], [237], [14.8],
          [Fine salt], [292], [18.2],
        ),
        caption: [Weights of common volume measures],
      ) <tab:volume>

      == Temperatures
      Gas marks, Celsius and Fahrenheit are related by
      $ F = 9 / 5 C + 32, quad G approx (C - 121) / 14. $ <eq:gas>

      = A Blank Schedule
      #lorem(60)
    ],
  ),
  bibliography: bibliography("refs.bib"),
  chapter-pagebreak: true,
  external-link-circle: true,
  footer: "page-number-alternate-with-chapter",
  raw-text: (font: ("DejaVu Sans Mono",), size: 8.5pt),
  figure-index: (enabled: true, title: "List of Illustrations"),
  table-index: (enabled: true, title: "List of Tables"),
  listing-index: (enabled: true, title: "List of Programs"),
)

// A bar for a timeline: start hour, duration, label.
#let bar(start, dur, label, fill) = place(
  left + top,
  dx: start * 14pt,
  box(width: dur * 14pt, height: 14pt, fill: fill, stroke: 0.4pt, align(center + horizon, text(7pt, label))),
)

= The Starter <ch:starter>

A starter is flour and water in which wild yeasts and lactic acid bacteria have settled
into a stable community @brandt2011levain. It is kept alive by _refreshing_: discarding
most of it and feeding the rest. The #link("https://example.org/starter-map")[map of
starters] kept by the Guild shows cultures that have been refreshed daily for over a
century @millers2023chart.

== Feeding ratios

A feed is written as starter : flour : water. A 1:5:5 feed at 24~°C peaks in about ten
hours; a 1:1:1 feed in four.#footnote[Peak means the dome has just begun to flatten. A
rubber band around the jar at the starting level makes this easy to see.] The time to peak
is roughly logarithmic in the dilution,
$ t_"peak" approx t_d log_2 (1 + (F + W) / S), $ <eq:peak>
where $S$, $F$ and $W$ are the weights of starter, flour and water and $t_d$ is the
doubling time of the culture at the given temperature. @eq:peak is only a rule of thumb,
but it predicts the entries of @tab:feeds within half an hour.

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (left, center, center, center),
    table.header[Feed][18 °C][24 °C][28 °C],
    [1:1:1], [7 h], [4 h], [3 h],
    [1:2:2], [10 h], [6 h], [4.5 h],
    [1:5:5], [16 h], [10 h], [7 h],
    [1:10:10], [22 h], [13 h], [9.5 h],
  ),
  caption: [Hours to peak for a liquid starter at three kitchen temperatures],
) <tab:feeds>

#blockquote[
  A starter is not a pet and not a recipe. It is a clock, and the baker's whole skill is
  learning to read it.

  #align(right)[--- note pinned above the kitchen's flour bins]
]

== Stiff and liquid starters

A stiff starter (50--60 % water) favours acetic acid and keeps longer between feeds; a
liquid one (100 % or more) is milder and faster @duarte2015acid. We keep a liquid starter
in summer and a stiff one in winter, converting by adjusting one feed:

+ weigh the starter to keep, say 20~g;
+ work out its flour and water from the old hydration;
+ add flour or water alone until the new hydration is reached;
+ then feed as usual.

The arithmetic is in @lst:convert. Inline code such as `hydration = water / flour` is set in
a tinted box by the template.

#figure(
  ```python
  def convert(starter_g, old_h, new_h):
      """Flour or water to add so that the hydration becomes new_h."""
      flour = starter_g / (1 + old_h)
      water = starter_g - flour
      if new_h > old_h:
          return ("water", new_h * flour - water)
      return ("flour", water / new_h - flour)

  print(convert(20, 1.00, 0.55))   # ('flour', 8.18...)
  ```,
  caption: [Converting a starter from one hydration to another],
) <lst:convert>

= The Dough <ch:dough>

== Baker's percentages

Every ingredient is expressed as a percentage of the total flour weight, so a formula can
be scaled to any batch. If the starter is a significant share of the dough its flour and
water are counted too: with $s$ the starter percentage and $h_s$ its hydration, the _true_
hydration of a dough with nominal hydration $h$ is
$ h_"true" = (h + s h_s / (1 + h_s)) / (1 + s / (1 + h_s)). $ <eq:true>

#figure(
  table(
    columns: (1.4fr, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header[Ingredient][Country loaf][Wholemeal][Rye 70 %][Focaccia],
    [Bread flour], [90], [30], [30], [100],
    [Wholemeal flour], [10], [70], [0], [0],
    [Rye flour], [0], [0], [70], [0],
    [Water], [75], [82], [80], [85],
    [Starter (100 %)], [20], [20], [35], [15],
    [Salt], [2.2], [2.2], [2.0], [2.5],
    [Olive oil], [0], [0], [0], [6],
    table.hline(stroke: 1pt),
    [True hydration (@eq:true)], [77.3], [83.6], [82.9], [86.0],
  ),
  caption: [Four formulas in baker's percentages],
) <tab:formulas>

High-extraction flours absorb more water, which is why the wholemeal formula of
@tab:formulas is wetter without being slacker @sato2017hydration.

== A day's schedule

@fig:schedule shows the schedule we use on working days: the dough is mixed before
breakfast, folded at lunch if someone is at home, shaped in the evening and baked the next
morning straight from the refrigerator.

#figure(
  box(width: 24 * 14pt, height: 62pt, {
    for h in range(0, 25, step: 3) {
      place(left + bottom, dx: h * 14pt - 4pt, text(7pt, str(calc.rem(h + 6, 24)) + "h"))
      place(left + top, dx: h * 14pt, line(angle: 90deg, length: 50pt, stroke: 0.3pt + luma(180)))
    }
    place(top + left, dy: 2pt, bar(0, 1, [mix], rgb("#f2d7a0")))
    place(top + left, dy: 2pt, bar(1, 11, [bulk fermentation, 21 °C], rgb("#f7e9c8")))
    place(top + left, dy: 18pt, bar(6, 1, [fold], rgb("#d9b46a")))
    place(top + left, dy: 18pt, bar(12, 1, [shape], rgb("#d9b46a")))
    place(top + left, dy: 34pt, bar(13, 10, [cold proof, 4 °C], rgb("#cfe3f5")))
    place(top + left, dy: 34pt, bar(23, 1, [bake], rgb("#e08a5b")))
  }),
  caption: [A 24-hour schedule starting at six in the morning],
) <fig:schedule>

=== Reading the dough

The schedule is a guess; the dough decides. Bulk fermentation is over when

- the volume has grown by half to three quarters,
- the surface is domed and shows bubbles at the edge of the tub,
- a wet finger pressed in leaves a dent that springs back slowly.

#blockquote[
  #lorem(45)
]

#lorem(110)

== Mixing by hand

#lorem(90)

A short script prints the weights for a batch from a row of @tab:formulas; it is shown in
@lst:scale. More formulas are collected at
#link("https://example.org/patient-loaf/formulas").

#figure(
  ```rust
  /// Weights in grams for `loaves` loaves of `dough_g` grams each.
  fn scale(percent: &[(&str, f64)], loaves: u32, dough_g: f64) -> Vec<(String, f64)> {
      let total: f64 = percent.iter().map(|(_, p)| p).sum();
      let flour = loaves as f64 * dough_g * 100.0 / total;
      percent
          .iter()
          .map(|(name, p)| (name.to_string(), (flour * p / 100.0).round()))
          .collect()
  }
  ```,
  caption: [Scaling a formula to a batch],
) <lst:scale>

= The Bake <ch:bake>

== Steam and heat

A loaf rises in the oven for as long as its crust stays soft, and the crust stays soft
for as long as the air around it is saturated. Domestic ovens vent steam within a minute
@nwosu2020oven; a lidded cast-iron pot traps the loaf's own. The old village ovens solved
the same problem with mass: a brick vault holds enough heat that a wet mop swabbed over
the floor fills it with steam for the whole bake @hartley1962ovens.

#figure(
  box(width: 220pt, height: 96pt, {
    let pts = ((0, 250), (5, 232), (10, 226), (20, 230), (21, 205), (30, 212), (40, 220), (45, 222))
    let scaled = pts.map(((m, t)) => (m / 45 * 220pt, 96pt - (t - 190) / 70 * 96pt))
    place(left + bottom, line(length: 220pt, stroke: 0.5pt))
    place(left + bottom, line(angle: -90deg, length: 96pt, stroke: 0.5pt))
    place(top + left, curve(stroke: 1pt + rgb("#b3421f"), curve.move(scaled.first()), ..scaled.slice(1).map(p => curve.line(p))))
    place(left + top, dx: 20 / 45 * 220pt, line(angle: 90deg, length: 96pt, stroke: (dash: "dashed", thickness: 0.5pt)))
    place(left + top, dx: 20 / 45 * 220pt + 3pt, dy: 4pt, text(7pt)[lid off])
    place(right + bottom, dy: -3pt, dx: -3pt, text(7pt)[minutes])
    place(left + top, dx: 3pt, dy: 14pt, text(7pt)[°C])
  }),
  caption: [Air temperature inside the pot during a 45-minute bake],
) <fig:bake>

The temperature record of @fig:bake shows the two phases: twenty minutes with the lid on,
during which the pot cools as the loaf takes up heat, and twenty-five with the lid off.

== When is it done?

#figure(
  table(
    columns: (1fr, auto, auto),
    align: (left, right, right),
    table.header[Loaf][Core temperature][Weight loss],
    [Country loaf, 900 g], [97 °C], [14 %],
    [Wholemeal, 900 g], [98 °C], [12 %],
    [Rye 70 %, 1 kg], [98 °C], [10 %],
    [Focaccia, tray], [94 °C], [9 %],
  ),
  caption: [Signs of a finished bake],
) <tab:done>

@tab:done gives two measurable signs; the traditional one, a hollow sound when the base is
knocked, is reliable only for lean wheat loaves.#footnote[Rye loaves sound dull even when
fully baked and should be left for a day before cutting.]

#lorem(150)

= Troubleshooting <ch:trouble>

/ Dense, gummy crumb: Under-fermented. Extend the bulk by an hour, or use @eq:peak to feed
  the starter so that it peaks when you mix.
/ Flat loaf, large irregular holes: Over-fermented or under-shaped. Shorten the cold proof.
/ Pale crust: Not enough sugar left, usually from over-fermentation, or the oven is cool.
/ Sour beyond pleasure: Stiff starter and long cold proof together; change one of them.

#lorem(60)

See @ch:starter for feeding, @ch:dough for formulas and @ch:bake for the oven; the
conversion tables are in the appendix (@tab:volume).
