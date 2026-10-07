// Lecture notes: almost everything on a page is computed from the rest of
// the document (counters, state, queries, measurements, page numbers), with
// functions that are called again and again with the same arguments. What a
// compilation memoizes of this must not be what the next one sees.
#import "style.typ": (
  card, definition, definitions, exercise, exercises, lecture, mode, stamp, total,
)

#set page(
  width: 260pt,
  height: 220pt,
  margin: (x: 16pt, top: 28pt, bottom: 24pt),
  numbering: "1 / 1",
  header: context {
    let lectures = query(heading.where(level: 1).before(here()))
    let title = if lectures.len() > 0 { lectures.last().body } else [Notes]
    text(8pt)[#title #h(1fr) #datetime.today().display("[year]-[month]-[day]")]
  },
)
#set text(size: 9pt)
#set heading(numbering: "1.a")
#set math.equation(numbering: "(1)")
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  it
}

#let draft = sys.inputs.at("mode", default: "final") == "draft"

#align(center)[
  *Notes* #if draft [(draft)] \
  #context [#counter(heading).final().first() lectures,
    #definitions.final().first() definitions,
    #exercises.final() exercises worth #total.final() points,
    #counter(page).final().first() pages]
]

#outline(depth: 1)

Printed on #stamp() as #mode(); once more: #stamp(), #mode().

#lecture[Counting] <counting>

#definition[Counter][Something that is stepped where it stands and read
  anywhere.]

#definition[State][A value with a history: at every place it has the value
  that the updates before that place gave it.]

The first definition is on page #context locate(<def-1>).page() and the
last exercise on page #context {
  let all = query(<exercise>)
  if all.len() > 0 { all.last().location().page() } else { 0 }
}.

#exercise(2)[Step a counter twice and read it between the steps.]
#exercise(3)[Read the final value of a state before its first update.]

$ sum_(k = 1)^n k = (n (n + 1)) / 2 $ <sum>

By @sum the points of the first #context exercises.get() exercises are
soon counted.

#lecture[Measuring] <measuring>

#definition[Measurement][The size that content would have, laid out where
  it is measured.]

#context {
  let words = ("a", "wider word", "the widest of the words")
  let widths = words.map(word => measure(card(word)).width)
  let widest = calc.max(..widths)
  grid(
    columns: 3 * (widest,),
    gutter: 4pt,
    ..range(9).map(i => card(words.at(calc.rem(i, 3)))),
  )
}

#layout(size => {
  let half = size.width / 2
  [Half of the column is #calc.round(half.pt(), digits: 1) points.]
})

#exercise(5)[Measure this exercise.]

As counted in @counting, there are
#context counter(heading).at(<measuring>).first() lectures up to here.
#footnote[And #context counter(footnote).final().first() footnotes in all.]

#lecture[Looking back] <back>

#context {
  let before = query(selector(<exercise>).before(here()))
  [There were #before.len() exercises before this line, ]
  let pages = before.map(e => e.location().page()).dedup()
  [on #pages.len() pages.]
}

#exercise(1)[Query the exercises after this one.]

#for i in range(6) {
  card[Card #(i + 1) of 6]
  h(4pt)
}

The notes end on page #context here().page() of
#context counter(page).final().first().#footnote[A last footnote.]
