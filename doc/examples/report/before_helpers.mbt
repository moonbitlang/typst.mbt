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

// The helpers an author wrote for a status chip and for a framed table of
// data before the kit had `Chip` and `DataTable` (findings H4 and H5): the
// shape of the pills and of the table helpers of the ports.

///|
/// A status chip: a pill in a line of text. Its padding above and below is
/// an outset, so that the line keeps its height, and its spaces are
/// no-break spaces, so that it is not broken in a narrow column.
fn pill(label : String, outcome : Outcome) -> Box {
  let (soft, strong) = chip_paints(outcome)
  Box(
    Text(
      label.replace_all(old=" ", new="\u{00A0}"),
      size=Pt(7),
      weight=SemiBold,
      fill=strong,
    ),
    fill=soft,
    inset=Sides(x=Pt(4.2)),
    outset=Sides(y=Pt(2.1)),
    radius=Corners(all=Pt(7)),
  )
}

///|
/// A table in a rounded frame: a header that repeats on every page, rows
/// that are not split, a hairline under every row but the last, the
/// columns `num` to the right, the rows `mark` (of the body, from 0)
/// tinted.
fn framed_table(
  head : Array[String],
  rows : Array[Array[&IntoContent]],
  columns~ : Array[Sizing],
  num? : Array[Int] = [],
  mark? : Array[Int] = [],
) -> Block {
  let cells : Array[&IntoContent] = [
    TableHeader(
      head.map(h => {
        let cell : &IntoContent = Text(
          h.to_upper(),
          size=Pt(7),
          weight=SemiBold,
          fill=muted,
          tracking=Pt(0.35),
        )
        cell
      }),
    ),
  ]
  for row in rows {
    for cell in row {
      cells.push(cell)
    }
  }
  let last = rows.length()
  Block(
    Seq([
      SetText(size=Pt(8.6)),
      SetTableCell(breakable=false),
      Table(
        cells,
        columns~,
        align=Cells((x, _) => {
          if num.contains(x) {
            @doc.Alignment::Both(Right, Top)
          } else {
            Both(Left, Top)
          }
        }),
        inset=Cells::all(Sides(x=Pt(8), y=Pt(6))),
        fill=Cells((_, y) => {
          if y == 0 {
            sunk
          } else if mark.contains(y - 1) {
            tint
          } else {
            None
          }
        }),
        stroke=Cells((_, y) => {
          if y == last {
            Sides::none()
          } else {
            Sides(bottom=rule, rest=Stroke::none())
          }
        }),
      ),
    ]),
    stroke=hairline,
    radius=Corners(all=Pt(RADIUS)),
    clip=true,
    width=Pct(100),
  )
}
