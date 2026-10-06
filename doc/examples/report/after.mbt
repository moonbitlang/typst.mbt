// The report with the kit's `Cards`.

///|
using @kit {type Cards}

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
fn after() -> Document {
  report(
    cards(tiles.map(tile_body), tiles.length()),
    cards(worked.map(note_body), 3),
    cards(to_change.map(note_body), 3),
  )
}
