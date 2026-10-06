// arkheion 0.1.2: the other paths of the template: `custom-authors` content instead of the
// author grid (the document metadata still comes from `authors`), no abstract, no
// keywords, no date, run-in level-4 headings, a table that breaks across pages with
// repeated header and footer, a footnote, no appendix and no bibliography.
// Engine paths: heading show rule by level (levels 3 and 4 take different branches),
// table header/footer repetition, grid cells with colspan, page numbering.
#import "@preview/arkheion:0.1.2": arkheion

#show: arkheion.with(
  title: "A Field Protocol for Ten-Minute Flower Watches",
  authors: (
    (name: "Jules Ferrand", email: "", affiliation: ""),
    (name: "Samira Ibrahim", email: "", affiliation: ""),
  ),
  custom-authors: align(center, pad(top: 0.8em, bottom: 0.4em, {
    set text(size: 10pt)
    grid(
      columns: (1fr, 1fr),
      row-gutter: 0.5em,
      [*Jules Ferrand*#super[1]], [*Samira Ibrahim*#super[1, 2]],
      grid.cell(colspan: 2, text(9pt)[
        #super[1] European Pollinator Monitoring Scheme, Lyon #h(1em)
        #super[2] Nile Delta Agricultural Station, Tanta
      ]),
      grid.cell(colspan: 2, text(9pt, style: "italic")[Technical note 4, revised edition]),
    )
  })),
)

= Purpose

This note fixes the procedure for timed flower observations so that counts made by
different people in different years can be compared. It replaces the first edition.

= Procedure

== Before the watch

=== Choosing the patch
Pick one square metre with at least ten open flowers of a single species. Mark the corners
with pegs.#footnote[Bamboo skewers are sufficient and do not attract insects.]

=== Weather
Do not start below 13 °C, in rain, or when the wind moves the flower heads continuously.

==== Shade
Note whether the patch is in sun, in shade, or changing.

==== Time
Start between 10:00 and 16:00 local solar time.

== During the watch

Stand one metre from the patch, with your shadow falling away from it. For ten minutes,
record every insect that touches the reproductive parts of a flower. An individual that
leaves the patch and returns is counted again, because it cannot be told apart from a
newcomer.

== After the watch

Count the open flowers in the patch and record the species.

= Recording Sheet

#table(
  columns: (auto, 1fr, auto, auto),
  align: (center, left, center, center),
  table.header[Code][Group][Typical size][Count],
  ..(
    ("HB", "Honeybee", "12 mm"),
    ("BB", "Bumblebees", "10 to 25 mm"),
    ("SB", "Solitary bees, large", "over 10 mm"),
    ("sb", "Solitary bees, small", "under 10 mm"),
    ("HF", "Hoverflies", "5 to 18 mm"),
    ("OF", "Other flies", "any"),
    ("BF", "Butterflies", "any"),
    ("MO", "Moths (day-flying)", "any"),
    ("BE", "Beetles", "over 3 mm"),
    ("WA", "Wasps", "any"),
    ("AN", "Ants", "any"),
    ("OT", "Other insects", "over 3 mm"),
  )
    .map(((code, group, size)) => (raw(code), group, size, []))
    .flatten(),
  table.footer(table.cell(colspan: 3, align: right)[*Total*], []),
)

= Common Mistakes

#lorem(180)

== Counting too much

#lorem(160)

== Counting too little

#lorem(200)

= Changes since the First Edition

+ The watch is ten minutes everywhere; the first edition allowed fifteen.
+ Ants are recorded.
+ The lower temperature limit is 13 °C for all regions.

#lorem(120)
