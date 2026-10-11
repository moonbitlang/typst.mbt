// The elements of `main.typ`.
#let parts = counter("part")
#let tally = counter("tally")

// A part starts a page and steps its counter.
#let part(title) = {
  pagebreak(weak: true)
  parts.step()
  heading(level: 1, title)
}

// The header of a page: the last part that started before or on it, and
// how many there are.
#let running() = {
  let before = query(heading.where(level: 1).before(here())).filter(it => (
    it.numbering != none
  ))
  let title = if before.len() > 0 { before.last().body } else [Pages]
  set text(7pt)
  [#title #h(1fr) part #parts.get().first() of #parts.final().first()]
}

// Reads a file when it is called, which is when the footer is laid out.
#let fact() = read("fact.txt").trim()

// A page of its own with the same content every time.
#let leaf(body) = page(
  width: 120pt,
  height: 60pt,
  margin: 10pt,
  header: none,
  footer: none,
  body,
)
