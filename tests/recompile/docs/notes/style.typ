// The elements of the notes.
#let definitions = counter("definition")
#let exercises = state("exercises", 0)
#let total = state("points", 0)
#let accent = rgb("#225588")

#let lecture(title) = heading(level: 1, title)

#let definition(term, body) = block(
  width: 100%,
  inset: (left: 6pt, y: 3pt),
  stroke: (left: 1.5pt + accent),
)[
  #definitions.step()
  #context [
    #metadata(term) #label("def-" + str(definitions.get().first()))
  ]
  *Definition #context definitions.display() (#term).* #body
]

#let exercise(points, body) = block(width: 100%, above: 6pt)[
  #exercises.update(n => n + 1)
  #total.update(sum => sum + points)
  #text(fill: accent)[*Exercise #context exercises.get()*]
  (#points #if points == 1 [point] else [points]) <exercise>
  #body
]

#let card(body) = box(
  fill: accent.lighten(85%),
  inset: 3pt,
  radius: 2pt,
  body,
)

// Functions without arguments that read what is not a file: the same call
// gives another value on another day or with other inputs.
#let stamp() = datetime.today().display("[year]-[month]-[day]")
#let mode() = sys.inputs.at("mode", default: "final")
