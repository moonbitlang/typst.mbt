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
