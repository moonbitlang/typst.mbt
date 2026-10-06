// The report with the hand-written helpers of `before_helpers.mbt`.

///|
fn before() -> Document {
  report(
    tile_row(tiles),
    note_cards(worked, 3),
    note_cards(to_change, 3),
    bed_table_before(bed_columns),
  )
}

///|
/// The table of the beds in `columns`.
fn bed_table_before(columns : Array[Sizing]) -> Block {
  framed_table(bed_head, bed_rows(pill), columns~, num=[3], mark=[best_bed()])
}
