// touying 0.8.0: a long deck generated from data (dewdrop theme with the sidebar
// navigation): four rounds of three quiz questions, every question slide built by one
// function with a pause, `item-by-item` over a generated enum, `uncover` and
// `alternatives`; headings come out of `for` loops; a state is updated once per round and
// read in the footer and on a final summary that also queries the headings. About 80 pages.
// Engine paths: slides split out of code-generated sequences, progressive outline in the
// sidebar of every page, slide/page counters and `final()`, state across many pages,
// repeated layout of similar content (memoization, location disambiguation).
#import "@preview/touying:0.8.0": *
#import themes.dewdrop: *

#let asked = state("quiz-asked", 0)

#show: dewdrop-theme.with(
  aspect-ratio: "16-9",
  navigation: "sidebar",
  sidebar: (width: 9em, filled: false, numbered: true, indent: 0.5em, short-heading: true),
  footer: context [Questions asked in finished rounds: #asked.get()],
  primary: rgb("#7a3b12"),
  config-info(
    title: [The Harbour Arms Quiz],
    subtitle: [Twelve questions, four rounds],
    author: [Your quizmaster],
    date: datetime(year: 2025, month: 12, day: 5),
    institution: [Back room, first Friday],
  ),
)

#set heading(numbering: "1.1")

#let rounds = (
  (
    name: "Rivers",
    questions: (
      (q: [Which river flows through Vienna, Bratislava, Budapest and Belgrade?], options: ([Rhine], [Danube], [Elbe]), answer: 1, extra: [It reaches the Black Sea after about 2,850 km.]),
      (q: [On which river does Cairo stand?], options: ([Nile], [Niger], [Congo]), answer: 0, extra: [The city lies just upstream of the delta.]),
      (q: [Which river forms much of the border between Devon and Cornwall?], options: ([Exe], [Severn], [Tamar]), answer: 2, extra: [Brunel's railway bridge crosses it at Saltash.]),
    ),
  ),
  (
    name: "Numbers",
    questions: (
      (q: [How many faces does a regular dodecahedron have?], options: ([Ten], [Twelve], [Twenty]), answer: 1, extra: [Each face is a regular pentagon.]),
      (q: [What is the sum of the whole numbers from 1 to 100?], options: ([$5050$], [$5000$], [$5151$]), answer: 0, extra: [$sum_(k=1)^100 k = (100 dot 101) / 2$.]),
      (q: [Which of these numbers is prime?], options: ([$91$], [$87$], [$97$]), answer: 2, extra: [$91 = 7 dot 13$ and $87 = 3 dot 29$.]),
    ),
  ),
  (
    name: "Kitchen",
    questions: (
      (q: [At sea level, water boils at how many degrees Fahrenheit?], options: ([$100$], [$180$], [$212$]), answer: 2, extra: [It freezes at $32$, so the two are $180$ degrees apart.]),
      (q: [Which of these is not a member of the onion family?], options: ([Leek], [Fennel], [Chive]), answer: 1, extra: [Fennel belongs with carrots and parsley.]),
      (q: [Roughly how much of a loaf's flour weight is salt?], options: ([Two percent], [Ten percent], [Half a percent]), answer: 0, extra: [Bakers say "two percent" without thinking.]),
    ),
  ),
  (
    name: "Sky",
    questions: (
      (q: [Which planet has the shortest year?], options: ([Venus], [Mars], [Mercury]), answer: 2, extra: [It goes round the Sun in about 88 days.]),
      (q: [How long does sunlight take to reach the Earth?], options: ([About eight minutes], [About eight seconds], [About eight hours]), answer: 0, extra: [The distance is roughly 150 million km.]),
      (q: [In which direction does the Sun set at the equinox?], options: ([South-west], [Due west], [North-west]), answer: 1, extra: [And it rises due east, everywhere on Earth.]),
    ),
  ),
)

#let letters = ("A", "B", "C")

// One question: the text, then the options one by one, then the answer.
#let question-slide(n, item) = {
  heading(depth: 2)[Question #n]
  item.q
  pause
  item-by-item(enum(numbering: "A.", ..item.options))
  pause
  block(
    width: 100%,
    inset: 0.6em,
    radius: 4pt,
    fill: rgb("#7a3b12").lighten(88%),
    [*Answer #letters.at(item.answer):* #item.options.at(item.answer). #uncover("6-", item.extra)],
  )
  [Hands up: #alternatives(repeat-last: true)[who had #letters.at(item.answer)?][keep your own score.]]
}

#title-slide()

#outline-slide()

#for (r, round) in rounds.enumerate() {
  heading(depth: 1, round.name)
  for (i, item) in round.questions.enumerate() {
    question-slide(r * 3 + i + 1, item)
  }
  heading(depth: 2)[Answers of round #(r + 1)]
  asked.update(n => n + round.questions.len())
  table(
    columns: (auto, 1fr, auto),
    table.header[No.][Question][Answer],
    ..round
      .questions
      .enumerate()
      .map(((i, item)) => ([#(r * 3 + i + 1)], item.q, [#letters.at(item.answer). #item.options.at(item.answer)]))
      .flatten(),
  )
  context [After this round #asked.get() of #asked.final() questions have been asked, on
    page #here().page() of #counter(page).final().first().]
}

= Scores

== The whole evening

#context {
  let slides = query(heading.where(level: 2))
  [The deck has #slides.len() slides below the round headings, #utils.last-slide-number
    counted slides and #counter(page).final().first() pages.]
}

#grid(
  columns: (1fr,) * 4,
  gutter: 0.6em,
  ..rounds.map(round => block(
    width: 100%,
    inset: 0.5em,
    stroke: 0.8pt + rgb("#7a3b12"),
    radius: 4pt,
    [*#round.name* \ #round.questions.map(item => letters.at(item.answer)).join(" · ")],
  )),
)

#pause

Thank you for playing. #pause The bar is still open.

#focus-slide[Same time next month.]
