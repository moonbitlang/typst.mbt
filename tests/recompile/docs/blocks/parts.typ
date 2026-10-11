// The parts of the blocks document.
#let swatch(color) = box(width: 6pt, height: 6pt, fill: color)

// A table of the rows of a CSV file. It is called in a `context`, so the
// file is read by the layout of the block that the call stands in.
#let ledger() = {
  let rows = csv("rows.csv")
  table(
    columns: rows.first().len(),
    table.header(..rows.first().map(strong)),
    ..rows.slice(1).flatten(),
  )
}

// What the document says about itself: its headings, its pages, and where
// it ends.
#let summary() = context {
  let headings = query(heading)
  let end = query(<end>)
  let place = if end.len() > 0 {
    let position = end.first().location().position()
    [page #position.page at #calc.round(position.y.pt())]
  } else [nowhere]
  [#headings.len() headings on #counter(page).final().first() pages; the
    last one is "#headings.last().body"; the document ends on #place.]
}
