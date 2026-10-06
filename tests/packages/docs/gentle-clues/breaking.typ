// gentle-clues 1.3.1: breakable clues that split across pages, clues nested
// in lists, enums, clues in clues, in columns and in a figure.
// Stresses sticky header blocks, clip + stroke on broken blocks, state for
// the global breakable flag, footnotes and counters inside broken blocks.
#import "@preview/gentle-clues:1.3.1": *

#set page(width: 12cm, height: 15cm, margin: (x: 1.2cm, y: 1.4cm), footer: context align(center, text(size: 8pt, counter(page).display("— 1 —"))))
#set text(size: 9.5pt, lang: "en")
#set par(justify: true)
#set heading(numbering: "1.")

#show: gentle-clues.with(breakable: true)

= Sourdough, week one

The starter is seven days old. These are the notes of the first bake, kept
in the order things happened.

#info(title: "Schedule")[
  Feed at eight in the morning, mix at noon, fold four times during the
  afternoon, shape at six and bake the next day.#footnote[The fridge is the
  only reason this fits around work.]

  #lorem(70)

  + Autolyse for forty minutes.
  + Add salt and the levain.
  + Rest.

  #lorem(60)
]

#warning[
  This clue starts wherever the previous one ended and is long enough to
  run on to the following page. #lorem(90)
]

= Shaping

- Flour the bench lightly.
- Turn the dough out.
  #tip[
    A wet scraper sticks less than a floured one.
    - Hold it at a shallow angle.
    - Push, do not cut.
      #danger(title: "Hot")[The pot is at 250 °C when the loaf goes in.]
  ]
- Pre-shape into a round and rest it for twenty minutes.
  #task[Set a timer.]
- Final shape:
  + Fold the bottom third up.
  + Fold the sides in.
    #question(breakable: false)[Does the seam hold when the loaf is turned over? #lorem(18)]
  + Roll it towards you and seal.
    #task[Dust the basket with rice flour.]

= Baking in two columns

#columns(2, gutter: 1em)[
  #experiment(title: "Steam")[
    Three loaves, three ways of making steam. #lorem(40)

    #success(headless: true)[Lidded pot: best ear.]
    #error(headless: true)[Tray of water: pale crust.]

    #lorem(45)
  ]

  #example[
    $ "hydration" = m_"water" / m_"flour" = 375 / 500 = 75% $
    #lorem(30)
  ]

  #conclusion(breakable: false)[
    The pot wins. It is unbreakable, like this clue. #lorem(20)
  ]
]

#figure(
  memo(width: 80%)[
    #table(
      columns: (1fr, auto, auto),
      table.header[Stage][Start][Hours],
      [Levain], [08:00], [4],
      [Bulk], [12:00], [6],
      [Cold proof], [18:30], [14],
      [Bake], [08:30], [1],
    )
  ],
  caption: [The timetable, as a clue inside a figure.],
)

Tasks set in these notes: #context gc-task-counter.get().first().
