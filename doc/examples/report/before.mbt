// The report with the hand-written helpers of `before_helpers.mbt`.

///|
fn before() -> Document {
  report(tile_row(tiles), note_cards(worked, 3), note_cards(to_change, 3))
}
