// showybox 2.0.4: breakable boxes that split across pages, nested boxes,
// boxes in columns, with footnotes and a running header.
// Stresses breakable blocks with fill/stroke/radius over several regions,
// shadows around broken blocks, column breaks, footnotes inside blocks.
#import "@preview/showybox:2.0.4": showybox

#set page(
  width: 12cm,
  height: 16cm,
  margin: (x: 1.2cm, top: 1.8cm, bottom: 1.5cm),
  header: context [
    #set text(size: 8pt)
    Harbour logbook #h(1fr) sheet #counter(page).display()
    #v(-0.6em)
    #line(length: 100%, stroke: 0.4pt)
  ],
)
#set text(size: 9.5pt)
#set par(justify: true)

#let entry = showybox.with(
  breakable: true,
  frame: (
    border-color: blue.darken(50%),
    title-color: blue.darken(30%),
    body-color: blue.lighten(95%),
    footer-color: blue.lighten(80%),
  ),
  title-style: (weight: "bold"),
)

= Week of the spring tide

#entry(title: "Monday: arrivals", footer: "Signed by the duty officer")[
  The collier _Marta_ came alongside at first light and was made fast at
  the north quay.#footnote[Berth 4, the one with the broken bollard.] She
  discharged until noon.

  #lorem(60)
][
  The ferry ran late on every crossing. #lorem(50)
][
  In the evening the dredger took up station off the bar.#footnote[She
  will be there for a fortnight.] #lorem(70)

  #lorem(40)
]

Between the entries the harbour master notes the weather: wind south-west,
force five, backing; glass falling slowly.

#entry(
  title: "Tuesday: a nested report",
  shadow: (offset: 3pt, color: blue.lighten(60%)),
)[
  The pilot's report is pasted in as it was handed over.

  #showybox(
    title: "Pilot's report",
    breakable: true,
    frame: (border-color: red.darken(30%), title-color: red.darken(30%), body-color: white, thickness: 0.8pt),
  )[
    Boarded at the fairway buoy. #lorem(45)

    #showybox(
      title: "Margin note",
      title-style: (color: black, sep-thickness: 0pt),
      frame: (title-color: luma(230), dash: "dotted", border-color: gray, radius: 2pt),
    )[
      The leading lights were not lit until we were abeam of the mole.
    ]

    #lorem(55)
  ]

  After the report the day went on quietly. #lorem(35)
]

#pagebreak()

= Tide tables in two columns

#columns(2, gutter: 0.8em)[
  #entry(title: "High water", frame: (border-color: teal.darken(30%), title-color: teal.darken(30%), body-color: teal.lighten(92%)))[
    #for (d, t, h) in (
      ("Mon", "05:12", 4.1),
      ("Tue", "05:58", 4.4),
      ("Wed", "06:41", 4.7),
      ("Thu", "07:23", 4.9),
      ("Fri", "08:06", 4.8),
      ("Sat", "08:51", 4.5),
      ("Sun", "09:40", 4.2),
    ) [
      / #d: #t, #h m
    ]

    #lorem(50)
  ]

  #entry(title: "Low water", footer: [Heights above chart datum.])[
    #lorem(38)

    $ h(t) = h_0 + A cos(omega t + phi) $

    #lorem(52)
  ]

  #showybox(title: "Unbreakable", frame: (title-color: black))[
    This box is not breakable, so it moves to the next column or page as a
    whole. #lorem(30)
  ]
]
