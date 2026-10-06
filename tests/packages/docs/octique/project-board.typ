// octique 0.1.1: Octicons as SVG images built from strings (image from
// bytes, format "svg", recoloured by string replacement). Icons inline in
// paragraphs and headings, as list markers, in a status table, in a sized
// and coloured gallery, inside show rules, links, a page header and an
// outline; the raw SVG source through octique-svg. Many small SVG images.

#import "@preview/octique:0.1.1": *

#let brand = rgb("#0969da")
#let ok = rgb("#1a7f37")
#let bad = rgb("#cf222e")
#let warn = rgb("#9a6700")
#let merged = rgb("#8250df")

#set page(
  width: 16cm,
  height: 22cm,
  margin: (x: 1.6cm, top: 2cm, bottom: 1.6cm),
  header: context {
    set text(9pt, fill: gray)
    octique-inline("repo", color: gray)
    [ kiln-controller #h(1fr) ]
    octique-inline("book", color: gray)
    [ maintainer notes, p. #counter(page).display()]
  },
)
#set heading(numbering: "1.")
#set par(justify: true)
#show link: it => {
  it
  h(2pt)
  octique-inline("link-external", color: brand, width: 0.7em, height: 0.7em, baseline: 0%)
}
#show "TODO": box(inset: (x: 2pt), {
  octique-inline("alert", color: warn)
  text(fill: warn, weight: "bold")[ todo]
})

#align(center)[
  #octique("flame", color: rgb("#bc4c00"), width: 2.4em)
  #v(-0.4em)
  #text(17pt, weight: "bold")[Kiln controller]

  Firmware for a pottery kiln
  #octique-inline("dot-fill", color: ok) stable
  #octique-inline("tag") v2.3
  #octique-inline("law") MIT
]

#outline(title: [Contents], depth: 1)

= #octique-inline("home") Where things are

The source lives in one repository #octique-inline("repo"). Work happens on
branches #octique-inline("git-branch"), is proposed as pull requests
#octique-inline("git-pull-request", color: ok) and lands by merging
#octique-inline("git-merge", color: merged). An icon in a sentence is a
box with a baseline shift, so it sits on the line like a letter does, at
the size of the text around it: #text(7pt)[small #octique-inline("gear")],
normal #octique-inline("gear"), #text(15pt)[large #octique-inline("gear")].

The project page is at #link("https://example.org/kiln")[example.org/kiln].
TODO move the wiki.

#let item(icon, color: black, body) = grid(
  columns: (1.4em, 1fr),
  octique-inline(icon, color: color),
  body,
)

#item("file-directory-fill", color: brand)[`firmware/` the controller itself, C for a small ARM core.]
#item("file-directory-fill", color: brand)[`profiles/` firing curves as CSV: bisque, glaze, crystal.]
#item("file-code")[`tools/plot.py` draws a curve from a log.]
#item("lock", color: warn)[`secrets/` is not in the repository; ask a maintainer.]
#item("trash", color: bad)[`legacy/` goes away with v3.]

= #octique-inline("tasklist") State of the work

The table is the board of the current milestone. The state column shows
only icons; the legend is in @tab-legend.

#let state = (
  open: octique-inline("issue-opened", color: ok),
  closed: octique-inline("issue-closed", color: merged),
  draft: octique-inline("git-pull-request-draft", color: gray),
  review: octique-inline("code-review", color: brand),
  blocked: octique-inline("blocked", color: bad),
)
#let who(..names) = names.pos().map(n => [#octique-inline("person", width: 0.8em, height: 0.8em) #n]).join([, ])
#let stars(n) = range(5).map(i => octique-inline(if i < n { "star-fill" } else { "star" }, color: rgb("#bf8700"), width: 0.8em, height: 0.8em)).join()

#figure(
  table(
    columns: (auto, 1fr, auto, auto),
    align: (center + horizon, left + horizon, left + horizon, center + horizon),
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt } else { 0.3pt + luma(200) }),
    table.header[][*Task*][*Who*][*Weight*],
    state.closed, [Thermocouple cold-junction compensation], who("Ines"), stars(4),
    state.closed, [Ramp segments with hold times], who("Ines", "Tomas"), stars(5),
    state.review, [PID autotune at 600 °C], who("Tomas"), stars(3),
    state.open, [Door switch debounce], who("Yuki"), stars(1),
    state.draft, [Profile upload over USB], who("Yuki", "Ines"), stars(3),
    state.blocked, [Relay board rev. C support #octique-inline("hourglass", color: gray)], who("Tomas"), stars(2),
    state.open, [Cool-down alarm #octique-inline("bell", color: warn)], who("Ines"), stars(1),
  ),
  caption: [Milestone 2.4.],
) <tab-board>

#figure(
  grid(
    columns: 5,
    column-gutter: 1.2em,
    row-gutter: 4pt,
    align: center,
    ..state.values(),
    ..state.keys().map(k => text(8pt, k)),
  ),
  caption: [Legend of the state icons.],
  kind: table,
) <tab-legend>

== Checks

Every pull request runs four checks. Their last results on the main
branch:

#grid(
  columns: (1fr, 1fr),
  row-gutter: 6pt,
  [#octique-inline("check-circle-fill", color: ok) build, 2 targets],
  [#octique-inline("check-circle-fill", color: ok) unit tests, 214 passed],
  [#octique-inline("x-circle-fill", color: bad) hardware-in-the-loop, relay 3 stuck],
  [#octique-inline("skip", color: gray) long firing simulation, skipped],
)

#pagebreak()

= #octique-inline("paintbrush") Icons as pictures

== Sizes and colours

`octique` returns a plain image whose width and height can be any length.
The colour is substituted into the SVG source before it is decoded, so
each colour gives a different image.

#let sizes = (8pt, 12pt, 18pt, 27pt, 40pt)
#let hues = (black, brand, ok, bad, merged)
#figure(
  grid(
    columns: sizes.len() + 1,
    align: center + horizon,
    column-gutter: 10pt,
    row-gutter: 8pt,
    [], ..sizes.map(s => text(8pt)[#s]),
    ..("rocket", "beaker", "mortar-board").map(name => (
      raw(name),
      ..sizes.zip(hues).map(((s, c)) => octique(name, color: c, width: s)),
    )).flatten(),
  ),
  caption: [Three icons at five sizes; each column has its colour.],
  kind: image,
) <fig-sizes>

A row of icons can serve as a small chart. Firing 12 was rated on five
points by three people:
#stars(4) #h(1em) #stars(5) #h(1em) #stars(2).

== A gallery

The package has more than three hundred icons. A selection, drawn in a
grid with the name below each:

#let gallery = (
  "alert", "archive", "bell", "book", "bug", "calendar", "clock", "cloud", "code", "comment",
  "cpu", "database", "device-desktop", "download", "eye", "file", "filter", "flame", "gear", "gift",
  "globe", "graph", "heart", "history", "image", "inbox", "key", "light-bulb", "location", "mail",
  "megaphone", "moon", "package", "pencil", "pin", "plug", "pulse", "search", "server", "shield",
  "squirrel", "sun", "telescope", "terminal", "tools", "trophy", "unlock", "upload", "zap", "zoom-in",
)

#grid(
  columns: (1fr,) * 10,
  row-gutter: 9pt,
  align: center,
  ..gallery.enumerate().map(((i, name)) => stack(
    spacing: 3pt,
    octique(name, color: color.hsv(i * 7deg, 75%, 70%), width: 1.5em),
    text(5pt, name),
  )),
)

== The source of an icon

`octique-svg` gives the SVG text itself. It is #octique-svg("dot-fill").len()
bytes for the smallest icon and #octique-svg("squirrel").len() for the
squirrel. The text can be shown, or decoded again with other settings:

#block(fill: luma(245), inset: 6pt, radius: 3pt, width: 100%, text(7pt, raw(octique-svg("dash"), lang: "xml", block: true)))

#grid(
  columns: 4,
  column-gutter: 1.5em,
  align: horizon,
  image(bytes(octique-svg("north-star")), width: 2cm),
  image(bytes(octique-svg("north-star").replace("#000000", "#bf8700")), width: 1.2cm, height: 2cm, fit: "stretch"),
  rotate(30deg, image(bytes(octique-svg("north-star")), width: 1.4cm)),
  box(fill: black, inset: 6pt, radius: 4pt, image(bytes(octique-svg("north-star").replace("#000000", "#ffffff")), width: 1.2cm)),
)

Compare @tab-board, @tab-legend and @fig-sizes.
