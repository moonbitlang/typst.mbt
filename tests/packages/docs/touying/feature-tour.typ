// touying 0.8.0: a feature tour on a theme defined in the document (`touying-slides` with own
// slide/title/section/focus functions, config-page/-colors/-methods/-store, progress bar,
// left-and-right/left-mid-right, progressive outline): pause/meanwhile/jump, uncover/only,
// alternatives(-match/-fn/-cases), effect, item-by-item(-fn), waypoints, animate + swap,
// callback-style slides, covers, math with pauses, numbered equations, touying-mitex (wasm),
// touying-raw, cetz 0.5.2 and fletcher 0.5.8 reducers, composer/cols/lazy layout,
// fit-to-height/width, checkerboard, speaker notes, per-slide config, touying-recall,
// labels and references across slides, appendix with frozen counters.
// Engine paths: metadata-driven content rewriting, states/counters across 78 pages,
// measure/layout in context, hide, query-based headers, wasm plugin, frozen counters.
#import "@preview/touying:0.8.0": *
#import "@preview/cetz:0.5.2"
#import "@preview/fletcher:0.5.8" as fletcher: edge, node
#import "@preview/mitex:0.2.6": mitex

#let cetz-canvas = touying-reduce.with(cetz)
#let fletcher-diagram = touying-reduce.with(fletcher)

// ---------------------------------------------------------------------------
// A small theme of our own.
// ---------------------------------------------------------------------------
#let harbour-slide(
  config: (:),
  repeat: auto,
  setting: body => body,
  composer: auto,
  ..bodies,
) = touying-slide-wrapper(self => {
  let header(self) = {
    set align(top)
    components.progress-bar(height: 4pt, self.colors.primary, self.colors.primary-lightest)
    block(
      width: 100%,
      inset: (x: 1.4em, top: 0.5em),
      components.left-and-right(
        text(1.15em, weight: "bold", fill: self.colors.primary, utils.display-current-heading(level: 2)),
        text(0.65em, fill: self.colors.neutral-dark, utils.display-current-heading(level: 1)),
      ),
    )
  }
  let footer(self) = {
    set align(bottom)
    set text(size: 0.5em, fill: self.colors.neutral-dark)
    block(
      width: 100%,
      inset: (x: 2.8em, bottom: 0.9em),
      components.left-mid-right(
        self.info.short-title,
        utils.display-info-date(self),
        context utils.slide-counter.display() + " / " + utils.last-slide-number,
      ),
    )
  }
  let self = utils.merge-dicts(self, config-page(header: header, footer: footer))
  touying-slide(self: self, config: config, repeat: repeat, setting: setting, composer: composer, ..bodies)
})

#let harbour-title-slide(config: (:)) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self,
    config,
    config-common(freeze-slide-counter: true),
    config-page(fill: self.colors.primary-lightest, margin: 2em),
  )
  touying-slide(self: self, align(horizon, {
    text(1.9em, weight: "bold", fill: self.colors.primary, self.info.title)
    linebreak()
    text(1.1em, fill: self.colors.neutral-dark, self.info.subtitle)
    v(1em)
    line(length: 30%, stroke: 2pt + self.colors.secondary)
    v(0.5em)
    text(0.8em)[#self.info.author \ #self.info.institution \ #utils.display-info-date(self)]
  }))
})

#let harbour-section-slide(config: (:), body) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(self, config, config-page(fill: self.colors.primary, margin: 2.5em))
  touying-slide(self: self, {
    set text(fill: self.colors.neutral-lightest)
    set align(horizon)
    text(1.6em, weight: "bold", utils.display-current-heading(level: 1))
    v(0.6em)
    text(0.75em, components.progressive-outline(alpha: 55%, level: 1, title: none, depth: 1))
    body
  })
})

#let harbour-focus-slide(config: (:), body) = touying-slide-wrapper(self => {
  let self = utils.merge-dicts(
    self,
    config,
    config-common(freeze-slide-counter: true),
    config-page(fill: self.colors.secondary, margin: 2em),
  )
  touying-slide(self: self, align(center + horizon, text(1.8em, weight: "bold", fill: white, body)))
})

#let harbour-theme(aspect-ratio: "16-9", ..args, body) = {
  show: touying-slides.with(
    config-page(
      ..utils.page-args-from-aspect-ratio(aspect-ratio),
      margin: (top: 3.4em, bottom: 2em, x: 1.4em),
      header-ascent: 0em,
      footer-descent: 0em,
    ),
    config-common(slide-fn: harbour-slide, new-section-slide-fn: harbour-section-slide),
    config-methods(
      init: (self: none, body) => {
        set text(size: 20pt)
        set list(marker: text(fill: self.colors.secondary, sym.triangle.filled.small.r))
        show heading.where(level: 3): set text(fill: self.colors.primary-dark, size: 0.9em)
        show raw.where(block: true): set text(size: 0.8em)
        show footnote.entry: set text(size: 0.6em)
        body
      },
      alert: utils.alert-with-primary-color,
    ),
    config-colors(
      primary: rgb("#0f4c75"),
      primary-dark: rgb("#0a3350"),
      primary-lightest: rgb("#e3eef6"),
      secondary: rgb("#c8553d"),
      neutral-dark: rgb("#555b61"),
      neutral-lightest: rgb("#ffffff"),
      neutral-darkest: rgb("#111111"),
    ),
    ..args,
  )
  body
}

#show: harbour-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Tides for Harbour Pilots],
    short-title: [Tides for Pilots],
    subtitle: [How the tables are made, and when not to trust them],
    author: [Aoife Fitzgerald],
    date: datetime(year: 2025, month: 4, day: 12),
    institution: [Port of Kinvarra],
  ),
  config-common(datetime-format: "[day] [month repr:short] [year]"),
)

#set math.equation(numbering: "(1)")

#harbour-title-slide()

== Outline <touying:hidden>

#components.adaptive-columns(outline(title: none, indent: 1em, depth: 2))

= Revealing

== Pause and meanwhile

High water is late today. #pause The reason is the wind.

#pause

- A south-westerly holds the ebb back in the bay.
- The gauge at the pier reads 20 cm above the table. #pause
- The table knows nothing about wind.

#meanwhile

This line belongs to the first subslide. #pause This one comes with the second.

#jump(4)

And this sentence waits for the fourth, whatever came before it.

== Uncover, only, alternatives

#uncover("2-")[Space for this sentence is reserved from the start.]

#only("2-3")[This one takes no space until it appears, and leaves again.]

The tide is #alternatives[flooding][at slack water][ebbing][low].

#alternatives-match((
  "1, 3": [Odd subslides: check the leading lights.],
  "2, 4": [Even subslides: check the depth sounder.],
))

Step #alternatives-fn(start: 1, count: 4, n => numbering("I", n)) of IV;
#alternatives-cases(("1, 2", "3-"), case => [
  #set text(fill: rgb("#c8553d")) if case == 1
  the bar is #if case == 0 [closed] else [open].
])

== Callback style

#slide(repeat: 3, self => [
  #let (uncover, only, alternatives) = utils.methods(self)

  This slide is a function of `self`; it is drawn three times and this is
  subslide #self.subslide.

  #uncover("2-")[The methods come from `utils.methods(self)`.]

  #only(3)[Only the third time.]

  #alternatives[one][two][three] of three.
])

== Effects and items

#effect(text.with(fill: rgb("#c8553d")), "2")[Red on the second subslide only.]
#effect(strike, "3-")[Struck out from the third.]

#item-by-item[
  - Springs follow new and full moon by about two days.
  - Neaps follow the quarters.
  - The lag is called the age of the tide.
]

#item-by-item-fn("current-highlight")[
  + Read the predicted height.
  + Add the surge.
  + Subtract the draught.
]

== Waypoints

The approach, step by step.

#waypoint(<fairway>)
#uncover(<fairway>)[Enter the fairway at the outer buoy.]

#waypoint(<bar>)
#uncover(from-wp(<bar>))[Cross the bar no earlier than two hours before high water.]

#waypoint(<berth>)
#only(<berth>)[Swing to starboard and berth port side to.]

#only(not-wp(<berth>))[_(the berth is not yet in sight)_]

#alternatives(at: (<fairway>, <bar>, <berth>))[Speed: 8 knots][Speed: 5 knots][Speed: dead slow]

== Animate

#animate(
  [The pilot boards at the fairway buoy.],
  effects: (
    (effect: "cover", subslides: "-1"),
    (effect: swap[The pilot boards inside the breakwater (bad weather).], subslides: 3),
    (effect: (body, ..) => text(fill: rgb("#0f4c75"), weight: "bold", body), subslides: "4-", priority: 2),
  ),
)

#animate-hidden([Appears on the second subslide and stays.], effects: (effect: "show", subslides: "2-"))

#animate-removed([Present on subslides three and four only.], effects: (effect: "show", subslides: "3-4"))

== Covers

#slide(config: config-methods(cover: utils.alpha-changing-cover.with(alpha: 30%)))[
  With `alpha-changing-cover` hidden text stays faintly visible.

  #pause

  - This item is pale on the first subslide.

  #pause

  - And this one for two of them.
]

#slide(config: config-methods(cover: utils.color-changing-cover.with(color: luma(200))))[
  With `color-changing-cover` it turns grey instead.

  #pause

  The same slide title, another cover method. #pause And a third step.
]

= Drawings

== A tide curve in CeTZ

#cetz-canvas(length: 1.1cm, {
  import cetz.draw: *

  line((0, 0), (12.6, 0), mark: (end: ">"), name: "t")
  line((0, -2.2), (0, 2.4), mark: (end: ">"))
  content((12.6, -0.35), [time])
  content((-0.6, 2.2), [$h$])

  (pause,)

  let pts = range(0, 121).map(i => (i / 10, 1.8 * calc.cos(i / 10 * 1.0)))
  line(..pts, stroke: 1.5pt + rgb("#0f4c75"))

  (pause,)

  let pts2 = range(0, 121).map(i => (i / 10, 1.8 * calc.cos(i / 10) + 0.5 * calc.cos(i / 10 * 0.52 + 1)))
  line(..pts2, stroke: (paint: rgb("#c8553d"), dash: "dashed", thickness: 1.2pt))
  content((9.2, 2.3), text(0.7em, fill: rgb("#c8553d"))[with the diurnal term])

  (pause,)

  circle((6.28, 1.8), radius: 0.12, fill: black)
  content((6.28, 2.55), text(0.7em)[second high water])
})

== A lock cycle in Fletcher

#fletcher-diagram(
  node-stroke: 0.08em,
  node-fill: rgb("#e3eef6"),
  spacing: (3.2em, 2.2em),
  node((0, 0), [waiting], corner-radius: 4pt, name: <w>),
  edge("-|>", [gates open]),
  node((1, 0), [entering], corner-radius: 4pt, name: <e>),
  pause,
  edge("-|>", [gates shut]),
  node((2, 0), [levelling], corner-radius: 4pt, name: <l>),
  pause,
  edge("-|>", [levels equal]),
  node((3, 0), [leaving], corner-radius: 4pt, name: <x>),
  edge(<x>, <w>, "-|>", [next vessel], bend: 35deg),
  pause,
  edge(<l>, <l>, "--|>", [pumps], bend: 130deg),
)

= Layout

== Columns from the composer

#slide(composer: (2fr, 1fr))[
  === Left, two thirds
  The composer turns several bodies into columns. A third-level heading is ordinary
  content because the slide level is two.

  #pause
  Pauses work across columns.
][
  === Right
  #table(
    columns: 2,
    table.header[Port][Range],
    [Kinvarra], [4.6 m],
    [Rossaveal], [4.1 m],
    [Inishmaan], [3.9 m],
  )
]

== A grid with a footer row

#slide(composer: 2)[
  First of two equal columns.
][
  Second column. #pause Then more.
][
  #grid.cell(colspan: 2, align(center, text(0.8em, style: "italic")[A cell that spans both columns.]))
]

== Equal-height blocks

#cols(columns: (1fr, 1fr), gutter: 1em, lazy-layout: true)[
  #block(fill: rgb("#e3eef6"), inset: 0.6em, radius: 4pt, width: 100%)[
    *Springs.* Large range, strong streams, short slack.
    #lazy-v(1fr)
    Bottom of the left block.
  ]
][
  #block(fill: rgb("#f6e6e2"), inset: 0.6em, radius: 4pt, width: 100%)[
    *Neaps.* Small range and weak streams; the bar may not be passable at all for deep
    vessels, which is the more common reason for a delay.
    #lazy-v(1fr)
    Bottom of the right block.
  ]
]

== Fitting

#utils.fit-to-width(grow: true, 100%)[A line stretched to the full width]

#utils.fit-to-width(grow: false, 60%)[A line that is far too long for sixty percent of the slide and is therefore shrunk]

#utils.fit-to-height(2.2em)[Scaled to a height of 2.2 em]

== Checkerboard

#components.checkerboard(columns: 3, rows: (2.4em, 2.4em), primary: rgb("#e3eef6"), secondary: white)[HW 05:12][LW 11:31][HW 17:40][LW 23:58][4.4 m][0.7 m]

#v(0.5em)
#components.full-width-block(fill: rgb("#0f4c75"), inset: 0.5em)[
  #text(fill: white)[A block that ignores the page margins.]
]

== A slide that overflows

#lorem(190)

== Notes for the speaker

Notes do not appear on the slides unless a second screen is configured.

#speaker-note[
  + Mention the gale of last November.
  + Do not read the table aloud.
]

#pause

A second step with its own note.

#speaker-note(subslide: 2)[Only relevant after the click.]

= Configuration

== One slide, another page

#slide(
  config: utils.merge-dicts(
    config-page(fill: rgb("#10212e")),
    config-colors(primary: rgb("#ffd166"), neutral-dark: rgb("#c0c8d0")),
  ),
  setting: body => {
    set text(fill: white)
    body
  },
)[
  This slide overrides the page fill and two colours for itself only. The header and the
  progress bar pick the new primary colour up.

  #alert[Alerts use the primary colour too.] *Strong text is an alert as well.*
]

== Config for a stretch <stretch>

#show: touying-set-config.with(config-methods(alert: (self: none, it) => underline(stroke: 2pt + rgb("#c8553d"), it)))

From here on #alert[alerts are underlined], because `touying-set-config` changed the
method for the rest of the deck.

A footnote on a slide.#footnote[Footnote numbers restart on every slide.] #pause
Another one.#footnote[This is the second on this slide.]

== Recalled

The slide "Config for a stretch" is shown again by `touying-recall`:

#touying-recall(<stretch>)

// The numbered equations and the figure come late in the deck on purpose: touying rewinds
// the frozen counters on every subslide to their value at the slide's start as the
// previous layout iteration saw it, so every animated slide that follows the first
// numbered equation costs one more iteration (five are allowed).
= Mathematics, code and a figure

== Code that grows

#touying-raw(```python
def height(t, constituents, h0=0.0):
    total = h0
    # pause
    for amp, speed, phase in constituents:
        total += amp * cos(speed * t - phase)
    # pause
    return total
```)

== LaTeX via mitex

#touying-mitex(mitex, `
  \eta(x, t) &= a \cos(kx - \omega t) \\
  c &= \pause \frac{\omega}{k} = \sqrt{g h} \\
  \lambda &= \pause c\,T \approx 440\ \mathrm{km}\ \text{for}\ h = 10\ \mathrm{m}
`)

== Equations with pauses

The height of the tide is a sum of harmonics:

$
  h(t) &= H_0 + sum_(k=1)^n f_k H_k cos(omega_k t + V_k - g_k) \
  &= pause H_0 + "M"_2 + "S"_2 + pause "K"_1 + "O"_1 + dots.c
$ <eq:harmonic>

#meanwhile

Here $H_k$ and $g_k$ are the constants of the port. #pause Four constituents give most
of the range in @eq:harmonic.

== A second numbered equation

$
  T_"M2" &= 12.4206 "h", quad T_"S2" = 12.0000 "h" \
  T_"beat" &= (1 / T_"S2" - 1 / T_"M2")^(-1) approx 14.77 "d"
$ <eq:beat>

The beat period of @eq:beat is the spring-neap cycle; compare @eq:harmonic on the
previous slide.

== A figure and a label

#figure(
  box(width: 60%, height: 3.2cm, {
    let n = 48
    for i in range(n) {
      let h = 1.6cm + 1.2cm * calc.sin(i / n * 4 * calc.pi) + 0.25cm * calc.sin(i / n * 2 * calc.pi)
      place(left + bottom, dx: i * 100% / n, rect(width: 100% / n - 1pt, height: h, fill: rgb("#0f4c75").lighten(calc.rem(i, 12) * 5%)))
    }
  }),
  caption: [Hourly heights over two days],
) <fig:heights>

@fig:heights is referenced on its own slide, and @eq:harmonic from two slides away.

#harbour-focus-slide[Mind the surge.]

#show: appendix

= Appendix

== Constituents

The slide total in the footer no longer grows.

#table(
  columns: (auto, 1fr, auto),
  table.header[Name][Origin][Period (h)],
  [M#sub[2]], [principal lunar], [12.42],
  [S#sub[2]], [principal solar], [12.00],
  [K#sub[1]], [luni-solar diurnal], [23.93],
  [O#sub[1]], [principal lunar diurnal], [25.82],
)

== Symbols

$ omega_k = (2 pi) / T_k $ <eq:omega>

Equation numbers continue through the appendix: @eq:omega.
