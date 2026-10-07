// The module every chapter imports: configuration read from a file, the
// state and counters of the book, and its template.
#let config = json("../data/config.json")
#let mode = sys.inputs.at("mode", default: "draft")
#let notes = state("notes", 0)
#let theorems = counter("theorem")

// A footnote that is counted.
#let note(body) = {
  notes.update(n => n + 1)
  footnote(body)
}

#let theorem(body) = block(inset: 4pt, stroke: 0.5pt, width: 100%)[
  #theorems.step()
  *Theorem #context theorems.display().* #body
]

#let project(title: none, body) = {
  set page(
    paper: "a5",
    numbering: "1",
    header: context {
      let before = query(selector(heading.where(level: 1)).before(here()))
      if before.len() > 0 {
        emph(before.last().body)
      }
      h(1fr)
      [#mode, #datetime.today().display()]
    },
  )
  set heading(numbering: "1.1")
  set par(justify: true)
  set text(size: config.size * 1pt)
  align(center, text(1.6em, strong(title)))
  if mode == "final" {
    align(center)[Revision #sys.inputs.at("rev", default: "0")]
  }
  body
}
