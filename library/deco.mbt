// Field hooks of the decoration elements of `typst-library/src/text/deco.rs`.
// Strokes and paints are ported with the visualize module.

///|
fn highlight_elem_top_edge_default() -> Value {
  TopEdge::Metric(Ascender).into_value()
}

///|
fn highlight_elem_bottom_edge_default() -> Value {
  BottomEdge::Metric(Descender).into_value()
}

///|
/// `Some(Color::from_u8(0xFF, 0xFD, 0x11, 0xA1).into())` (HighlightElem.fill).
fn highlight_elem_fill_default() -> Value {
  IntoValue::into_value(
    (Some(Solid(Color::from_u8(0xFF, 0xFD, 0x11, 0xA1))) : Paint?),
  )
}
