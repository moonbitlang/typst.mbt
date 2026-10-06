// hydra 0.6.3: running headers of a book (`book: true`, odd/even pages, chapter on
// verso and section on recto), `skip-starting`, hydra in the footer through `anchor()`.
// Engine: queries before/after `here()` from the page header, positions, counters at locations.
#import "@preview/hydra:0.6.3": hydra, anchor

#set page(
  width: 105mm,
  height: 120mm,
  margin: (inside: 14mm, outside: 10mm, top: 16mm, bottom: 15mm),
  binding: left,
  numbering: "1",
  header: context {
    anchor()
    set text(size: 8pt)
    if calc.even(here().page()) {
      // verso: the chapter, on the outside
      emph(hydra(1, book: true))
      h(1fr)
      [Field Guide]
    } else {
      // recto: the section
      [p. #here().page()]
      h(1fr)
      emph(hydra(2, book: true))
    }
    v(-6pt)
    line(length: 100%, stroke: 0.4pt)
  },
  footer: context {
    set text(size: 7pt, fill: luma(90))
    // Outside of the top margin: hydra searches from the anchor in the header.
    let chapter = hydra(1, skip-starting: false)
    let section = hydra(2, skip-starting: false, use-last: true)
    grid(
      columns: (1fr, auto, 1fr),
      align: (left, center, right),
      chapter, counter(page).display("— 1 —"), section,
    )
  },
)
#set heading(numbering: "1.1")
#set par(justify: true)
#set text(size: 9pt)
#show heading.where(level: 1): it => pagebreak(weak: true) + it

#outline(depth: 2)

= Marsh Birds

The marsh at the river mouth is flooded twice a day. What follows is a
compact guide to the birds that a patient observer meets there between
the first frost and the return of the swallows.

== Waders at low tide

When the water falls back, the mud is covered with small feeding
parties. #lorem(60)

A second group arrives an hour later and works the channel edges.
#lorem(70)

== Reed dwellers

#lorem(45)

The reed bed is best visited at dawn. #lorem(120)

Bitterns are heard far more often than seen. #lorem(210)

=== Song posts

#lorem(40)

== Night roosts

#lorem(30)

= Woodland Edge

== The hedge in winter

Hawthorn and blackthorn keep their fruit until January. #lorem(150)

== Clearings

#lorem(35)

= Open Water

No section heading opens this chapter, so the recto header has to fall
back on nothing at all until the first section appears.

#lorem(140)

== Diving ducks

#lorem(90)

== Gulls and terns

#lorem(110)

= Notes on Method

== Counting

Counts were made from fixed points, each for ten minutes.
#lorem(50)

== Recording

#lorem(30)
