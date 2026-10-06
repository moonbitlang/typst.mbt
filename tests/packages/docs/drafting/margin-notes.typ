// drafting 0.2.2: margin notes on both sides with automatic overlap
// avoidance, phrase-highlighting notes, inline notes, per-reviewer styles,
// custom rect, hidden notes, changed defaults, and the outline of notes.
// Stresses here().position(), state updated from measured heights (several
// layout iterations), place + curve in boxes, queries by label, links to
// positions; several pages.
#import "@preview/drafting:0.2.2": *

#set page(width: 16cm, height: 18cm, margin: (left: 3.2cm, right: 3.8cm, y: 1.5cm), numbering: "1")
#set text(size: 9.5pt)
#set par(justify: true)
#set heading(numbering: "1.")
#set-page-properties()

#let editor = margin-note.with(stroke: blue, fill: blue.lighten(90%))
#let author = margin-note.with(stroke: purple, side: left)
#let small-note(stroke: none, fill: none, width: 0pt, body) = rect(
  stroke: stroke,
  fill: fill,
  width: width,
  radius: (top-right: 6pt, bottom-left: 6pt),
  inset: 4pt,
  text(size: 0.8em, style: "italic", body),
)

= The lighthouse keeper's draft

The first chapter opens on the rock at low water. #margin-note[Too slow an
opening?] The keeper counts the steps down to the landing, as he has every
morning for eleven years, #margin-note(side: left)[Eleven or twelve? Check
chapter four.] and finds one more than yesterday.

#lorem(30) #editor[Three notes follow each other closely here.] #lorem(6)
#editor[The second is pushed below the first.] #lorem(5)
#margin-note(stroke: green + 2pt)[And the third below the second.]
#lorem(30)

The supply boat is late. #author[The boat needs a name.][I would rather not
name it until the storm.] #lorem(25)

#inline-note[An inline note breaks the paragraph and takes the full width
of the text block.]

#lorem(20) #inline-note(par-break: false, stroke: stroke(paint: orange, dash: "dashed"))[a
running inline note] #lorem(20)

== The lamp

#set-margin-note-defaults(rect: small-note, stroke: teal, fill: teal.lighten(92%))

The lamp burns colza oil. #margin-note[From here on notes use a custom
rectangle.] #lorem(40) #margin-note(side: left, dy: -2em)[Moved up by hand
with `dy`.] #lorem(30)

#margin-note(stroke: red, fill: yellow.lighten(70%))[A phrase the note is about][The first
argument is highlighted in the text.] continues the sentence. #lorem(45)

#set-margin-note-defaults(hidden: true)

Hidden notes leave no trace: #margin-note[You cannot see me.] #lorem(15)
#margin-note(hidden: false)[But this one insists.] #lorem(25)

#set-margin-note-defaults(hidden: false, rect: rect, stroke: red, fill: none)

== The storm

#lorem(35) #editor(side: left)[Left, by the editor.] #lorem(35)
#author(side: right)[Right, by the author.] #lorem(40)

#let caution = rect.with(inset: 0.8em, radius: 0.5em)
#inline-note(rect: caution, fill: orange.lighten(80%), stroke: orange.darken(20%))[
  The whole storm scene is told twice, once here and once in the log book.
  + Keep the log book version.
  + Cut this one to a paragraph.
]

#lorem(50) #margin-note[Last note of the chapter, #text(fill: blue)[with
colour] and a footnote mark.] #lorem(30)

#pagebreak()

#note-outline(title: "Open remarks", level: 1, row-gutter: 7pt)
