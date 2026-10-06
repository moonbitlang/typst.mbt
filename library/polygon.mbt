// Port of `typst-library/src/visualize/polygon.rs` (`polygon.regular`).

///|
fn impl_polygon_elem_regular__size_default() -> Length {
  Length::from_em(Em::new(1.0))
}

///|
/// Upstream `PartialOrd::lt` for lengths.
fn length_lt(a : Length, b : Length) -> Bool {
  a.partial_cmp(b) is Some(cmp) && cmp < 0
}

///|
/// A regular polygon, defined by its size and number of vertices.
fn impl_polygon_elem_regular(
  span : @syntax.Span,
  fill_ : Paint??,
  stroke_ : Smart[Stroke?]?,
  size_ : Length,
  vertices_ : U64,
) -> Content {
  let vertices = vertices_.0.to_double()
  let n = vertices_.0.to_int()
  let radius = size_.div_by(2.0)
  let angle = (i : Double) => {
    let offset = Angle::rad(@math.PI * (1.0 / 2.0 - 1.0 / vertices))
    let rotation = Angle::from_ratio(Ratio::new(i / vertices))
    offset + rotation
  }
  let mut min_x = radius
  let mut min_y = radius
  for v in 0..<=n {
    let a = angle(v.to_double())
    let v_x = radius.times(a.cos()) + radius
    let v_y = radius.times(a.sin()) + radius
    min_x = if length_lt(min_x, v_x) { min_x } else { v_x }
    min_y = if length_lt(min_y, v_y) { min_y } else { v_y }
  }
  let (horizontal_offset, vertical_offset) = (min_x, min_y)
  let points : Array[Value] = []
  for v in 0..<=n {
    let a = angle(v.to_double())
    let x = radius.times(a.cos()) + radius - horizontal_offset
    let y = radius.times(a.sin()) + radius - vertical_offset
    points.push(
      Axes::new((Rel::from_abs(x) : Rel[Length]), Rel::from_abs(y)).into_value(),
    )
  }
  let mut elem = Content::new(polygon_elem(), [
    (polygon_elem_vertices, Array(Arr::from_array(points))),
  ])
  if fill_ is Some(fill) {
    elem = elem.with_field(polygon_elem_fill, IntoValue::into_value(fill))
  }
  if stroke_ is Some(stroke) {
    elem = elem.with_field(polygon_elem_stroke, IntoValue::into_value(stroke))
  }
  elem.spanned(span)
}
