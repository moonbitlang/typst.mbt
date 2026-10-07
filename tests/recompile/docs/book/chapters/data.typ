#import "../lib/shared.typ": config, note, theorem

= Data <data>

#let rows = csv("../data/table.csv")

#figure(
  table(
    columns: rows.first().len(),
    ..rows.flatten(),
  ),
  caption: [The table of `table.csv`.],
) <tab-data>

The amounts of @tab-data add up to
#rows.slice(1).map(row => int(row.at(1))).sum().#note[Counted again here.]

#let lines = read("../data/notes.txt").split("\n").filter(line => line != "")

#for line in lines [
  - #line
]

#let settings = toml("../data/settings.toml")
#let people = yaml("../data/people.yaml")

The ratio is #settings.layout.ratio and the columns are
#settings.layout.columns.

#for person in people [
  / #person.name: #person.role, since #person.since
]

#theorem[There are #lines.len() notes and #people.len() people.]

// A file that is a module for one reader and text for another.
The shared module has #read("../lib/shared.typ").split("\n").len() lines.

#context {
  let size = measure(text(size: config.size * 1pt, config.title))
  [The title is #calc.round(size.width.pt(), digits: 2) points wide. ]
}
#layout(size => [The column is #calc.round(size.width.pt(), digits: 2) points wide.])

```tally
count 12 apples
sum 3 pears
```
