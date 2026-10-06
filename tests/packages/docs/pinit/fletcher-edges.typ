// pinit 0.2.2: pins in table cells and in a list with arrows, pins inside
// raw code through a show rule, and one pinit-fletcher-edge with the
// fletcher 0.5.8 module passed explicitly (a bent, labelled edge).
// Stresses a fletcher/cetz diagram placed absolutely, a pin inside a hidden
// diagram queried one layout iteration later (the edge is the last
// annotation of the document so that layout converges), regex show rules
// on raw text.
#import "@preview/pinit:0.2.2": *
#import "@preview/fletcher:0.5.8"

#set page(width: 14cm, height: 16cm, margin: 1.5cm)
#set text(size: 10pt)

= Working out a fare

== Between table cells

#table(
  columns: (auto, 1fr, 1fr),
  inset: 8pt,
  table.header[Zone][Tariff][Fare for 10 km],
  [A], [1.50 #pin("ta")], [#pin("fa") 3.50],
  [B], [2.20 #pin("tb")], [#pin("fb") 4.20],
  [C], [3.10 #pin("tc")], [#pin("fc") 5.10],
)

#for (a, b, paint) in (("ta", "fa", green.darken(30%)), ("tb", "fb", olive), ("tc", "fc", teal)) {
  pinit-arrow(a, b, start-dx: 3pt, start-dy: -3pt, end-dx: -3pt, end-dy: -3pt, stroke: 0.5pt + paint, fill: paint)
}

#pinit-rect("fa", "fc", dx: -4pt, dy: -1.1em, extended-width: 3em, stroke: 0.5pt + gray, radius: 3pt)

== In a list

+ Read the distance #pin("l1")
+ Find the zone
+ Add the two parts #pin("l3")

#pinit-double-arrow("l1", "l3", start-dx: 30pt, start-dy: -3pt, end-dx: 30pt, end-dy: -3pt, stroke: 0.6pt + purple, fill: purple)
#pinit-line("l1", "l1", start-dx: 3pt, start-dy: -3pt, end-dx: 30pt, end-dy: -3pt, stroke: (paint: purple, dash: "dotted"))
#pinit-line("l3", "l3", start-dx: 3pt, start-dy: -3pt, end-dx: 30pt, end-dy: -3pt, stroke: (paint: purple, dash: "dotted"))
#pinit-place("l3", dx: 36pt, dy: -24pt, text(size: 7pt, fill: purple)[both are needed])

== In code

#show raw.where(block: true): it => {
  show regex("pin\d"): m => pin(eval(m.text.slice(3)))
  it
}

#v(1.5em)

```python
def fare(pin1distancepin2, zone):
    base = pin3TARIFF[zone]pin4
    return base + 0.2 * pin5distancepin6
```

#pinit-highlight(1, 2)
#pinit-highlight(5, 6)
#pinit-highlight(3, 4, fill: rgb(0, 100, 255, 30))

#pinit-point-from(4, pin-dx: 3pt, pin-dy: -3pt, offset-dx: 60pt, offset-dy: -3pt, body-dy: -8pt, stroke: 0.6pt + blue, fill: blue)[
  #text(size: 7pt, fill: blue)[looked up in the table above]
]

#pinit-fletcher-edge(
  fletcher,
  1,
  end: 5,
  (0, 0),
  (1, 1),
  [same value],
  "->",
  bend: 40deg,
  start-dx: 10pt,
  start-dy: 4pt,
  end-dx: 10pt,
  end-dy: -9pt,
  stroke: 0.6pt + red,
  label-size: 7pt,
  label-side: right,
  label-pos: 0.35,
)
