// Port of `hayro-interpret/src/convert.rs`.

///|
fn convert_transform(
  a : @hayro_syntax.Number,
  b : @hayro_syntax.Number,
  c : @hayro_syntax.Number,
  d : @hayro_syntax.Number,
  e : @hayro_syntax.Number,
  f : @hayro_syntax.Number,
) -> @kurbo.Affine {
  @kurbo.Affine::new([
    a.as_f64(),
    b.as_f64(),
    c.as_f64(),
    d.as_f64(),
    e.as_f64(),
    f.as_f64(),
  ])
}

///|
fn convert_line_cap(lc : @hayro_syntax.Number) -> @kurbo.Cap {
  match lc.as_i64() {
    0L => Butt
    1L => Round
    2L => Square
    _ => Butt
  }
}

///|
fn convert_line_join(lc : @hayro_syntax.Number) -> @kurbo.Join {
  match lc.as_i64() {
    0L => Miter
    1L => Round
    2L => Bevel
    _ => Miter
  }
}
