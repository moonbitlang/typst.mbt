// The report with the kit's `Cards`, `DataTable` and `Chip`.

///|
using @kit {type Cards, type DataTable, type Chip}

///|
/// Rounded cards around `bodies`, `columns` to a row.
fn cards(bodies : Array[Seq], columns : Int) -> Cards {
  Cards(
    bodies.map(body => body as &IntoContent),
    columns=Sizing::repeat(columns, size=Fr(1)),
    gutter=[Pt(GUTTER)],
    fill=surface,
    stroke=hairline,
    inset=Sides(all=Pt(INSET)),
    radius=Corners(all=Pt(RADIUS)),
  )
}

///|
/// A status chip.
fn chip(label : String, outcome : Outcome) -> Text {
  let (soft, strong) = chip_paints(outcome)
  Text(
    Chip(label, fill=soft, radius=Corners(all=Pt(7))),
    size=Pt(7),
    weight=SemiBold,
    fill=strong,
  )
}

///|
/// A table in a rounded frame, with its header in small capitals and the
/// rows `mark` (of the body, from 0) tinted.
fn data_table(
  head : Array[String],
  rows : Array[Array[&IntoContent]],
  columns~ : Array[Sizing],
  align~ : Cells[@doc.Alignment],
  mark? : Array[Int] = [],
) -> Seq {
  let fill : Cells[Paint] = Cells((_, y) => {
    if y == 0 {
      sunk
    } else if mark.contains(y - 1) {
      tint
    } else {
      None
    }
  })
  Seq([
    ShowSet(Select::table_cell(), SetText(size=Pt(8.6))),
    ShowSet(
      Select::table_cell(y=0),
      SetText(size=Pt(7), weight=SemiBold, fill=muted, tracking=Pt(0.35)),
    ),
    DataTable(
      head.map(h => h.to_upper() as &IntoContent),
      rows,
      columns~,
      inset=Cells::all(Sides(x=Pt(8), y=Pt(6))),
      align~,
      fill~,
      stroke=rule,
      radius=Corners(all=Pt(RADIUS)),
    ),
  ])
}

///|
fn after() -> Document {
  report(
    cards(tiles.map(tile_body), tiles.length()),
    cards(worked.map(note_body), 3),
    cards(to_change.map(note_body), 3),
    bed_table_after(bed_columns),
  )
}

///|
/// The table of the beds in `columns`.
fn bed_table_after(columns : Array[Sizing]) -> Seq {
  data_table(
    bed_head,
    bed_rows(chip),
    columns~,
    align=Cells::columns([Left, Left, Left, Right, Left]),
    mark=[best_bed()],
  )
}
