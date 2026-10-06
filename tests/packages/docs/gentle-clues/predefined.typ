// gentle-clues 1.3.1: all predefined clues, overridden titles/colours/icons,
// custom clues, the numbered task counter, global `gentle-clues` settings and
// translated titles via linguify 0.5.0 (text.lang switches, fallback).
// Stresses SVG icons from the package, state updates, context text.lang,
// toml database lookup, clipped blocks with partial strokes.
#import "@preview/gentle-clues:1.3.1": *

#set page(width: 15cm, height: 20cm, margin: 1.3cm, numbering: "1 / 1")
#set text(size: 9.5pt)

= Bicycle workshop handbook

#abstract[
  How the Saturday repair workshop is run: what volunteers check first,
  which jobs they hand on, and how the tool wall is kept in order.
]

== The whole palette

#grid(
  columns: (1fr, 1fr),
  gutter: 0.7em,
  info[Opening hours are ten to two.],
  notify[The truing stand is booked until noon.],
  success[Brake cable replaced and tested.],
  warning[Carbon parts need the torque wrench.],
  danger[Never spin a wheel with fingers near the disc.],
  error[The chain checker reads past 1 %.],
  tip[Shift to the smallest sprocket before removing the wheel.],
  goal[Twenty bicycles back on the road each week.],
  question[Is the rim worn below the indicator groove?],
  idea[Colour code the hex keys by size.],
  example[A 622 mm rim takes 700C tyres.],
  experiment[Try the new bio degreaser on one chain first.],
  conclusion[Most squeaks are a dry chain.],
  memo[Order inner tubes on Thursday.],
  code[`ISO 5775: 37-622`],
  quotation[Two wheels good.],
)

#quotation(attribution: [the workshop founder], title: "Motto")[
  A bicycle that leaves here stops when asked to.
]

== Tasks with a counter

#task[Check both tyres for cuts and set the pressure.]
#task[Squeeze each brake lever; it must not reach the bar.]
#task(accent-color: olive)[Lift the rear wheel and run through every gear.]

#gc-task-counter-enabled.update(false)
#task[An unnumbered extra: wipe the frame.]
#gc-task-counter-enabled.update(true)
#task[The count resumes here.]

Tasks done so far: #context gc-task-counter.display("I").

#pagebreak()

== Overrides and custom clues

#info(title: "Tool wall", icon: none, radius: 8pt)[No icon, a rounder corner.]

#warning(title: [With _markup_ in the title], header-color: yellow.lighten(40%), border-color: orange, border-width: 1.5pt)[
  A louder header and a thicker border.
]

#tip(headless: true, body-color: aqua.lighten(80%))[Headless, with a tinted body.]

#let workshop-note(..args) = clue(
  accent-color: gradient.linear(purple, blue, angle: 90deg),
  title: "From the logbook",
  icon: circle(radius: 0.45em, fill: purple, stroke: none),
  ..args,
)

#workshop-note[The accent is a gradient, so header and border use it too.]

#workshop-note(title: "Narrow entry", width: 6cm, stroke-width: 6pt, content-inset: 0.5em, header-inset: 0.3em, title-weight-delta: 0)[
  Six centimetres wide.
]

#clue(title: none)[A bare clue without any title at all.]

#clue(
  title: "Striped",
  accent-color: tiling(size: (6pt, 6pt), {
    rect(width: 6pt, height: 6pt, fill: luma(235))
    place(top + left, line(start: (0pt, 6pt), end: (6pt, 0pt), stroke: 1pt + red))
  }),
  title-font: "New Computer Modern",
)[A tiling as accent colour, and another title font.]

== Global settings

#[
  #show: gentle-clues.with(
    headless: true,
    stroke-width: 5pt,
    border-radius: 0pt,
    border-width: 1pt,
    content-inset: 0.6em,
    width: 9cm,
  )
  #success[Every clue in this block is headless and nine centimetres wide.]
  #memo(headless: false)[Unless a clue asks for its header back.]
  #task[The task counter keeps counting.]
]

#show: gentle-clues.with(header-inset: 0.3em, title-weight-delta: 400)

#pagebreak()

== Translated titles

#let languages = (
  ("en", "English"),
  ("de", "German"),
  ("fr", "French"),
  ("es", "Spanish"),
  ("it", "Italian"),
  ("hu", "Hungarian"),
  ("cs", "Czech"),
  ("dk", "the key `dk`"),
  ("nl", "Dutch, not in the database"),
)

#for (code, name) in languages [
  #set text(lang: code)
  #block(breakable: false)[
    #text(style: "italic")[Language: #name]
    #grid(
      columns: (1fr, 1fr, 1fr),
      gutter: 0.5em,
      warning(content-inset: 0.5em)[#code], question(content-inset: 0.5em)[#code], conclusion(content-inset: 0.5em)[#code],
    )
  ]
]

#set text(lang: "de")
#task[Die Zählung läuft auch auf Deutsch weiter.]
