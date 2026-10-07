#import "../lib/shared.typ": note

#set raw(theme: "../data/theme.tmTheme", syntaxes: "../data/tally.sublime-syntax")

= Figures <figures>

#figure(
  image("../data/diagram.svg", width: 60%),
  caption: [A diagram, drawn as an SVG.],
) <fig-diagram>

#figure(
  image("../data/dots.png", width: 20%),
  caption: [Dots, as a PNG.],
) <fig-dots>

#figure(
  ```tally
  count 7 figures
  sum 2 tables
  ```,
  caption: [A listing in a language of its own.],
) <lst-tally>

There are #context counter(figure).final().first() figures of images and
#context counter(figure.where(kind: raw)).final().first() listing.#note[The
last note of the book.] @fig-dots comes after @fig-diagram, and @lst-tally
is highlighted with the theme of the book. A second image is small enough
for a line: #box(image("../data/squares.png", height: 0.8em)).

#outline(title: [List of figures], target: figure.where(kind: image))
