// touying 0.8.0: handout mode with speaker notes on a second screen (simple theme):
// `config-common(handout: true, handout-subslides: ..)` keeps chosen subslides of each
// animated slide, `show-notes-on-second-screen: right` doubles the page width and puts the
// notes panel beside every slide, `handout-only`/`presentation-only` content, notes with
// pauses, per-subslide notes, Markdown-mode notes, a per-slide handout override, footnotes
// and a bibliography-free reference list.
// Engine paths: page width computed from config, `place` of a panel outside the margins,
// state read in the footer (current note), dropped subslides and their counters.
#import "@preview/touying:0.8.0": *
#import themes.simple: *

#show: simple-theme.with(
  aspect-ratio: "4-3",
  primary: rgb("#6b3fa0"),
  footer: [Evening class, week 6],
  config-common(
    handout: true,
    handout-subslides: "1, 3-",
    show-notes-on-second-screen: right,
  ),
  config-info(
    title: [Reading a Weather Map],
    author: [Katrin Vogel],
    date: datetime(year: 2026, month: 1, day: 20),
  ),
)

#title-slide[
  = Reading a Weather Map
  #v(1em)
  Katrin Vogel \
  Evening class, week 6

  #handout-only[_Handout: animation steps two are left out; notes are on the right._]
  #presentation-only[_Live version._]
]

= Isobars

== Lines of equal pressure

An isobar joins places with the same air pressure, reduced to sea level.

#pause

Close isobars mean a steep gradient. #pause A steep gradient means wind.

#pause

- 4 hPa spacing on most European charts
- labelled in whole hectopascals

#speaker-note[
  Start with the map from this morning. Ask who has seen one before.

  #pause

  Draw two isobars on the board, close together, and blow across them.
]

== Buys Ballot's law

Stand with your back to the wind: #pause the low is on your left #pause (in the northern
hemisphere).#footnote[On the southern hemisphere it is on your right.]

#speaker-note(subslide: 1)[Let them try it with the chart turned round.]
#speaker-note(subslide: 3)[Mention the southern hemisphere only if someone asks.]

= Fronts

== Three kinds

#slide(composer: (1fr, 1fr), config: config-common(handout-subslides: none))[
  / Warm front: half circles, drawn in red.
  / Cold front: triangles, drawn in blue.
  #pause
  / Occlusion: both, on the same side.
][
  #let front(marks, paint) = box(width: 100%, height: 1.2em, {
    place(left + horizon, line(length: 100%, stroke: 2pt + paint))
    for i in range(6) {
      place(left + horizon, dx: i * 16% + 4%, dy: -0.32em, marks(paint))
    }
  })
  #front(p => circle(radius: 0.3em, fill: p), rgb("#c0392b"))
  #front(p => polygon(fill: p, (0em, 0.3em), (0.6em, 0.3em), (0.3em, -0.3em)), rgb("#2c5aa0"))
  #pause
  #front(p => rect(width: 0.5em, height: 0.5em, fill: p), rgb("#6b3fa0"))
]

#speaker-note(mode: "md")[
  This slide overrides the handout selection: only its *last* subslide is kept.
  - warm: steady rain
  - cold: showers, then clearing
]

== What passes overhead

#table(
  columns: (auto, 1fr, 1fr),
  table.header[][Before][After],
  [Warm front], [falling pressure, thickening cloud], [mild, damp, poor visibility],
  [Cold front], [gusts, a line of heavy showers], [rising pressure, clear, cold],
)

#pause

The wind veers at both. #pause At the cold front it does so within minutes.

#speaker-note[Veering: clockwise. Backing: anticlockwise. Write both words down.]

= Practice

== Tonight's chart

+ Find the lowest pressure. #pause
+ Follow the 1012 isobar all the way round. #pause
+ Mark where you would expect the strongest wind.

#handout-only[
  #v(1em)
  #rect(width: 100%, height: 3.2em, stroke: (dash: "dashed"), inset: 0.5em)[_Space for your answer._]
]

#speaker-note[Give them ten minutes. Collect the charts afterwards.]

#focus-slide[Back to the wind, low on the left.]
