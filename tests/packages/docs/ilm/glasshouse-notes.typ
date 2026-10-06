// ilm 2.1.1: the other option values: A5 paper, one author given as a string, another date
// format, abstract on the cover, no preface, a table of contents with a custom title, no
// chapter page breaks, no external-link circles, the right-aligned footer with chapter,
// Typst's default raw styling, indices and appendix with their default titles and
// numbering, an APA bibliography. Engine paths: several chapters per page (footer query
// of "chapter starts on this page"), long breakable table across pages, outline indent,
// default-valued dictionary lookups (`.at(key, default: ..)`), APA author-date citations.
#import "@preview/ilm:2.1.1": blockquote, ilm

#show: ilm.with(
  title: [Glasshouse Notes],
  authors: "Beatriz Almeida",
  paper-size: "a5",
  date: datetime(year: 2023, month: 11, day: 5),
  date-format: "[year]-[month]-[day] (week [week_number])",
  abstract: [
    A year of climate records from the propagation house of a small botanical garden, with
    the rules of thumb the gardeners distilled from them.
  ],
  table-of-contents: outline(title: [What is in here], indent: 1.2em),
  appendix: (
    enabled: true,
    body: [
      = Sensor Placement
      One aspirated sensor hangs at bench height in each bay, shaded from direct sun.
      == Calibration
      Sensors are checked against a sling psychrometer on the first Monday of each month.
      = Units
      Vapour pressure deficit is given in kilopascals throughout.
    ],
  ),
  bibliography: bibliography("refs.bib", style: "apa", title: "Sources"),
  chapter-pagebreak: false,
  external-link-circle: false,
  footer: "page-number-right-with-chapter",
  raw-text: "use-typst-default",
  figure-index: (enabled: true),
  table-index: (enabled: true),
  listing-index: (enabled: true),
)

#let months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
#let t-min = (11.2, 11.8, 13.1, 14.6, 16.0, 18.3, 19.5, 19.1, 17.2, 14.8, 12.4, 11.0)
#let t-max = (19.4, 21.0, 24.2, 26.8, 29.5, 32.1, 34.0, 33.2, 29.9, 25.1, 21.3, 19.0)
#let rh = (78, 75, 71, 66, 63, 58, 55, 57, 62, 69, 74, 79)

// Saturation vapour pressure in kPa (Tetens), used for the VPD column.
#let svp(t) = 0.6108 * calc.exp(17.27 * t / (t + 237.3))
#let vpd(t, h) = svp(t) * (1 - h / 100)

= The House

The propagation house is a three-bay glasshouse of 1962, heated by hot-water pipes under
the benches and vented by hand-cranked ridge lights. It was described, with its original
boiler, in a survey of garden buildings of the district @hartley1962ovens. The climate
computer is new; the cranks are not.

See #link("https://example.org/glasshouse/plan")[the plan of the bays] for the layout. With
`external-link-circle: false` this link carries no marker.

== Why keep records?

#blockquote[
  Before the logger we argued about whether the house was too dry. Now we argue about what
  to do about it, which is progress.
]

= The Year in Numbers

@tab:climate gives the monthly means. The vapour pressure deficit is computed from the mean
of the daily maxima and the mean relative humidity as
$ "VPD" = e_s (T) (1 - "RH" / 100), quad e_s (T) = 0.6108 exp((17.27 T) / (T + 237.3)). $ <eq:vpd>

#figure(
  table(
    columns: (auto, 1fr, 1fr, 1fr, 1fr),
    align: (left, right, right, right, right),
    table.header[Month][Min (°C)][Max (°C)][RH (%)][VPD (kPa)],
    ..range(12)
      .map(i => (
        months.at(i),
        str(t-min.at(i)),
        str(t-max.at(i)),
        str(rh.at(i)),
        str(calc.round(vpd(t-max.at(i), rh.at(i)), digits: 2)),
      ))
      .flatten(),
    table.footer(
      [*Year*],
      [*#calc.round(t-min.sum() / 12, digits: 1)*],
      [*#calc.round(t-max.sum() / 12, digits: 1)*],
      [*#calc.round(rh.sum() / 12, digits: 0)*],
      [],
    ),
  ),
  caption: [Monthly means in the middle bay],
) <tab:climate>

The deficit of @eq:vpd passes 2~kPa in July and August, where most cuttings stop rooting
@brandt2011levain[p.~40].#footnote[The citation is to a book on fermentation whose chapter
on humidity chambers the gardeners found more useful than their own manuals.]

#figure(
  box(width: 12 * 16pt, height: 80pt, outset: (bottom: 10pt), inset: (bottom: 0pt), {
    for i in range(12) {
      let lo = (t-min.at(i) - 8) / 28 * 80pt
      let hi = (t-max.at(i) - 8) / 28 * 80pt
      place(left + bottom, dx: i * 16pt + 3pt, dy: -lo, rect(width: 10pt, height: hi - lo, fill: color.mix((rgb("#3a7ca5"), 34 - t-max.at(i)), (rgb("#d1495b"), t-max.at(i) - 18)), radius: 2pt))
      place(left + bottom, dx: i * 16pt + 3pt, dy: 9pt, text(6pt, months.at(i)))
    }
    place(left + bottom, line(length: 12 * 16pt, stroke: 0.5pt))
  }),
  gap: 1.6em,
  caption: [Range between mean daily minimum and maximum],
) <fig:range>

== Reading the range

@fig:range shows the same data as bars. The span is narrowest in December, when the heating
holds the minimum and the sun does little, and widest in July.

= Rules of Thumb

+ Open the ridge lights when the deficit falls below 0.4~kPa, whatever the temperature.
+ Damp down the paths when it rises above 1.6~kPa.
+ Never do both in the same hour.

The first two rules are what the controller of @lst:rule implements; the third is why it
has a timer.

#figure(
  ```lua
  -- called once a minute with temperature (°C) and humidity (%)
  function decide(t, rh, last_action_min)
    local es = 0.6108 * math.exp(17.27 * t / (t + 237.3))
    local d = es * (1 - rh / 100)
    if last_action_min < 60 then return "wait" end
    if d < 0.4 then return "vent" end
    if d > 1.6 then return "damp" end
    return "idle"
  end
  ```,
  caption: [The controller's decision rule],
) <lst:rule>

== What the rules cost

Heat lost through open vents in winter is paid for in gas. Over the year the vents were
open for #calc.round(rh.filter(h => h > 70).len() / 12 * 100)~% of the months with high
humidity; a study of small ovens, of all things, gives a usable estimate of the air
exchange through a slot of the same shape @nwosu2020oven.

#lorem(70)

= Plants That Disagreed

#lorem(50)

== Ferns

#lorem(40)

== Succulents

#lorem(40) See also @sato2017hydration and the millers' chart @millers2023chart for two
unrelated but well-made tables that served as models for @tab:climate.

= Next Year

#lorem(60)
