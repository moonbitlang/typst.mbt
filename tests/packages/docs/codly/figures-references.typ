// codly 1.3.0: listings inside labelled figures: references to lines (`@label:line`), to
// highlights and annotations by label, `reference-by` line/item, `reference-sep`,
// `reference-number-format`, an outline of listings, a floating listing; inline raw untouched.
// Engine: nested show rules (figure > raw > raw.line), generated labels, hidden placed figures
// as reference targets, ref show through custom numbering, links across pages.
#import "@preview/codly:1.3.0": *

#set page(width: 125mm, height: 135mm, margin: (x: 11mm, y: 13mm), numbering: "1")
#set text(size: 9pt)
#set par(justify: true)
#set heading(numbering: "1.")
#show figure.where(kind: raw): set figure(supplement: [Listing])
#show figure.caption: set text(size: 8pt)
#show link: set text(fill: rgb("#0b5394"))
#show: codly-init

#codly(languages: (
  py: (name: "Python", color: rgb("#3572a5")),
  js: (name: "JavaScript", color: rgb("#b8a100")),
))

#align(center, text(13pt, weight: "bold")[Predicting Tides from Harmonics])

#outline(title: [Listings], target: figure.where(kind: raw))

= The model

A tide is a sum of cosines. The constituents are stored as triples and
summed in @lst-height. The table is on @lst-height:1[line], the sum itself
on line @lst-height:8, and the unit conversion in `height()` happens last
(@lst-height:9). Inline code like `M2` or #raw("cos(x)", lang: "py") stays
as it is.

#figure(
  caption: [Tide height from three constituents],
)[
```py
CONSTITUENTS = [("M2", 1.21, 28.984), ("S2", 0.42, 30.0), ("K1", 0.18, 15.041)]

def height(hours, phases, datum=2.6):
    total = 0.0
    for (name, amplitude, speed) in CONSTITUENTS:
        angle = math.radians(speed * hours - phases[name])
        total += amplitude * math.cos(angle)
    metres = datum + total
    return round(metres * 3.2808, 1)
```
] <lst-height>

#lorem(50)

= Finding high water

High water is where the derivative changes sign. In @lst-search the
step is marked (@hl-step) and so is the comparison (@hl-sign); both
references print the listing and the line.

#codly(highlights: (
  (line: 2, start: 11, end: 20, fill: orange, label: <hl-step>),
  (line: 5, start: 11, end: 31, fill: teal, tag: [sign], label: <hl-sign>),
))
#figure(
  caption: [Scanning a day for high water],
)[
```py
def high_waters(day, phases):
    step = 0.1
    found = []
    for i in range(1, 240):
        if slope(i - 1) > 0 >= slope(i):
            found.append(round(i * step, 1))
    return found
```
] <lst-search>
// Reset by hand: the package does it itself only after the block has seen
// the highlights, which is one introspection iteration too late for the
// blocks below (their labels may only be used inside a labelled figure).
#codly(highlights: none)

#lorem(40)

#pagebreak()

= The same in the browser

From here on, references name the item instead of the line, with an
arrow as separator. In @lst-js the cache (@hl-cache) avoids recomputing
a day, the annotated loop fills it, and the constant (@hl-speed) is the
speed of the principal lunar constituent. A line reference still works:
@lst-js:3.

#codly(
  reference-by: "item",
  reference-sep: [ → ],
  reference-number-format: n => [L#n],
  highlights: (
    (line: 1, start: 6, end: 11, fill: purple, tag: [cache], label: <hl-cache>),
    (line: 2, start: 6, end: 20, fill: red, tag: [M2 speed], label: <hl-speed>),
  ),
  annotations: (
    (start: 5, end: 7, content: block(width: 1.6em, rotate(-90deg, reflow: true)[fill])),
  ),
)
#figure(
  caption: [Caching one day of predictions],
  placement: bottom,
)[
```js
const cache = new Map();
const M2 = 28.984;
function day(date, phases) {
  if (cache.has(date)) return cache.get(date);
  const out = [];
  for (let h = 0; h < 24; h += 0.5)
    out.push(height(h, phases));
  cache.set(date, out);
  return out;
}
```
] <lst-js>
#codly(highlights: none, annotations: none, reference-by: "line", reference-sep: "-")

#lorem(70)

= Loose ends

A listing in a figure without a label gets a number but no line
labels, and a raw block outside of a figure is styled all the same:

#figure(caption: [Phases for the home port])[
```py
PHASES = {"M2": 134.0, "S2": 171.5, "K1": 92.3}
```
]

```py
print(high_waters("2024-03-09", PHASES))
```

#figure(
  table(
    columns: 3,
    table.header[Constituent][Period (h)][Listing],
    [`M2`], [12.42], [@lst-height],
    [`S2`], [12.00], [@lst-height],
    [`K1`], [23.93], [@lst-js],
  ),
  caption: [Where each constituent is used; see also @lst-search:5],
) <tab-use>

@tab-use is an ordinary table figure and is not affected. The first
listing is on page #context counter(page).at(<lst-height>).first(), its
last line on page #context counter(page).at(label("lst-height:9")).first();
the third one floats to the bottom of page
#context counter(page).at(<lst-js>).first().
