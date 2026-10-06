// The helpers an author wrote for equally high rounded cards before the
// kit had `Cards` (finding H3 of docs/edsl-ports.md): the shape of the
// measured cards of the ports. Each card is built twice, once to be
// measured and once with the height of its row, and the width of a column
// is computed from the width of the page, typed in by hand.

///|
/// The width of the text area in points: the page (420pt) less its
/// margins (36pt on each side).
const TEXT_W : Double = 348

///|
/// A card around `body`: a rounded block that is not split. `height` is
/// given when its row has been measured.
fn framed(body : &IntoContent, height? : Sizing = Auto) -> Block {
  Block(
    body,
    width=Pct(100),
    height~,
    breakable=false,
    fill=surface,
    stroke=hairline,
    radius=Corners(all=Pt(RADIUS)),
    inset=Sides(all=Pt(INSET)),
  )
}

///|
/// Rows of `columns` cards, the cards of a row as high as the highest of
/// them. A card is its key and a function from its height to its block.
fn equal_rows(
  cards : Array[(String, (Sizing) -> Block)],
  columns : Int,
) -> Context {
  let width = (TEXT_W - GUTTER * (columns - 1).to_double()) /
    columns.to_double()
  Context(cx => {
    let cells : Array[&IntoContent] = []
    let mut start = 0
    while start < cards.length() {
      let end = if start + columns < cards.length() {
        start + columns
      } else {
        cards.length()
      }
      let mut height = 0.0
      for k in start..<end {
        let measured = cx.measure((cards[k].1)(Auto), width=Pt(width)).height
        height = if measured > height { measured } else { height }
      }
      for k in start..<end {
        cells.push(Keyed(cards[k].0, (cards[k].1)(Pt(height))))
      }
      start = end
    }
    Grid(cells, columns=Sizing::repeat(columns, size=Fr(1)), gutter=[Pt(GUTTER)])
  })
}

///|
/// The row of tiles.
fn tile_row(tiles : Array[Tile]) -> Context {
  equal_rows(
    tiles.map(tile => (tile.label, height => framed(tile_body(tile), height~))),
    tiles.length(),
  )
}

///|
/// The cards of some notes, `columns` to a row.
fn note_cards(notes : Array[Note], columns : Int) -> Context {
  equal_rows(
    notes.map(note => (note.id, height => framed(note_body(note), height~))),
    columns,
  )
}
