// codly 1.3.0: line numbers, language boxes (`languages`, icons, `typst-icon` PNG, `lang-format`,
// `aliases`), zebra, `highlights` with tags, `highlighted-lines`, `annotations`, `range`,
// `ranges` + `smart-skip`, `skips`, offsets (`codly-offset`, `offset-from`), disable/enable,
// `no-codly`, `local` overrides. Engine: show rules on raw and raw.line, state per block,
// measure, grids with fills and strokes, package image.
#import "@preview/codly:1.3.0": *

#set page(width: 130mm, height: 150mm, margin: (x: 11mm, y: 12mm), numbering: "1")
#set text(size: 9pt)
#show: codly-init.with()

#let dot(c) = box(circle(radius: 2.4pt, fill: c), baseline: -0.5pt) + h(3pt)
#codly(
  languages: (
    py: (name: "Python", icon: dot(rgb("#3572a5")), color: rgb("#3572a5")),
    rust: (name: "Rust", icon: dot(rgb("#ce412b")), color: rgb("#ce412b")),
    sql: (name: [SQL], color: rgb("#8a6d00")),
    sh: (name: "Shell", icon: text(fill: rgb("#3a7d44"))[\$ ], color: rgb("#3a7d44")),
    ..typst-icon,
  ),
)

= Review of the Ferry Booking Service

The service sells deck tickets for three island routes. This review
walks through the parts that changed, from the fare table to the
nightly export. Inline code such as `fare(route, deck)` or
#raw("SELECT 1", lang: "sql") is not touched by the package.

== Fare calculation

The default look: numbers, zebra stripes and the language box.

```py
BASE = {"north": 12.5, "south": 9.0, "loop": 21.0}

def fare(route, deck, child=False):
    price = BASE[route]
    if deck == "upper":
        price *= 1.4
    if child:
        price /= 2
    return round(price, 2)
```

Two spans of the block are highlighted, one with a tag, and two lines
get a background of their own:

#codly(
  highlights: (
    (line: 5, start: 8, end: 18, fill: red),
    (line: 7, start: 8, fill: green, tag: [halved]),
    (line: 8, start: 11, end: 26, fill: blue, tag: "(r)"),
  ),
  highlighted-lines: (1, (3, yellow.lighten(60%))),
)
```py
BASE = {"north": 12.5, "south": 9.0, "loop": 21.0}

def fare(route, deck, child=False):
    price = BASE[route]
    if deck == "upper":
        price *= 1.4
    if child:
        price /= 2
    return round(price, 2)
```

== Seat allocation

An annotation brackets the retry loop; the second one has no content
and shows only its number.

#codly(
  annotations: (
    (
      start: 3,
      end: 7,
      content: block(width: 2em, rotate(-90deg, reflow: true, align(center)[retry loop])),
    ),
    (start: 9),
  ),
)
```rust
fn allocate(deck: &mut Deck, party: usize) -> Option<Vec<Seat>> {
    let mut attempts = 0;
    loop {
        if let Some(seats) = deck.take_adjacent(party) {
            return Some(seats);
        }
        attempts += 1;
        if attempts == 3 { break; }
    }
    None
}
```
// The package resets annotations after the block, but only once the block
// has seen them: until the introspection has converged, the blocks below
// (ranges, skips) would be laid out with these annotations and fail.
#codly(annotations: none)

Only a range of the same function, with the original numbering:

#codly-range(3, end: 8)
```rust
fn allocate(deck: &mut Deck, party: usize) -> Option<Vec<Seat>> {
    let mut attempts = 0;
    loop {
        if let Some(seats) = deck.take_adjacent(party) {
            return Some(seats);
        }
        attempts += 1;
        if attempts == 3 { break; }
    }
    None
}
```

Several ranges, with skips inserted between them automatically:

#codly(ranges: ((1, 2), (7, 8), (10, 11)), smart-skip: true)
```rust
fn allocate(deck: &mut Deck, party: usize) -> Option<Vec<Seat>> {
    let mut attempts = 0;
    loop {
        if let Some(seats) = deck.take_adjacent(party) {
            return Some(seats);
        }
        attempts += 1;
        if attempts == 3 { break; }
    }
    None
}
```

== Nightly export

The query is quoted from a longer file: the block starts at line 41,
and a skip of 120 lines sits before its fourth line.

#codly(offset: 40, skips: ((3, 120),), skip-number: text(fill: gray)[⋮])
```sql
SELECT route, deck, count(*) AS sold
FROM tickets
WHERE sailing_date = :day
GROUP BY route, deck
ORDER BY route;
```

The shell wrapper continues the numbering of the first block through
`offset-from`:

#codly(number-format: n => text(fill: rgb("#3a7d44"), numbering("01", n)))
```sh
#!/bin/sh
set -eu
day=$(date -u +%F)
``` <wrapper-head>

#codly(offset-from: <wrapper-head>)
```sh
psql -v day="$day" -f export.sql > "sold-$day.csv"
gzip "sold-$day.csv"
```
#codly(number-format: numbering.with("1"))

A manual offset set by its own function:

#codly-offset(offset: 99)
```sh
echo "export finished"
```

== Without the package

#codly-disable()
```py
# plain raw block while the package is disabled
print(fare("loop", "upper"))
```
#codly-enable()

#no-codly[
  ```sql
  -- plain as well, through no-codly
  SELECT count(*) FROM tickets;
  ```
]

== Local overrides

#local(
  number-format: none,
  zebra-fill: none,
  stroke: 0.8pt + rgb("#ce412b"),
  radius: 0pt,
  display-icon: false,
)[
  ```rust
  // no numbers, no stripes, square corners, name without icon
  struct Seat { row: u8, number: u8 }
  ```
]

#local(
  number-placement: "outside",
  number-align: right + top,
  fill: rgb("#fbf7ee"),
  zebra-fill: rgb("#f1e9d6"),
  lang-format: (lang, icon, color) => box(
    fill: color,
    inset: (x: 4pt, y: 2pt),
    text(fill: white, weight: "bold", upper(lang)),
  ),
  inset: (x: 0.5em, y: 0.4em),
)[
  ```py
  # numbers outside of the frame, custom language box
  def is_full(deck):
      return deck.free == 0 and not deck.waiting_list_open and deck.route in ("north", "south", "loop")
  ```
]

After the local blocks the global settings are back, here for a Typst
snippet with the bundled icon and for a language without an entry:

```typ
#let fare(route) = table(columns: 2, [Route], [#route])
```

```toml
[export]
hour = 2
compress = true
```

#codly(aliases: (fish: "sh"), languages: (fish: (name: "Fish", color: rgb("#4aae47"))))
```fish
set day (date -u +%F)
```

The last line of a block is dropped when it is empty, unless asked:

#codly(skip-last-empty: false, display-name: false)
```py
print("done")

```
