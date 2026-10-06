// Adapters for the `tiny_skia_path::path_geometry` functions that tiny-skia
// uses, taking the `strict_num` wrappers as plain `Float`s and writing
// chopped curves at an offset (upstream passes `&mut dst[offset..]`).

///|
fn ts_new_t_values() -> Array[Float] {
  [0.5, 0.5, 0.5]
}

///|
fn ts_t(t : Float) -> @path.NormalizedF32Exclusive {
  @path.NormalizedF32Exclusive::new(t).unwrap()
}

///|
fn ts_chop_quad_at(
  src : ArrayView[@path.Point],
  t : Float,
  dst : Array[@path.Point],
) -> Unit {
  @path.chop_quad_at(src, ts_t(t), dst)
}

///|
fn ts_chop_cubic_at2(
  src : ArrayView[@path.Point],
  t : Float,
  dst : Array[@path.Point],
  dst_offset : Int,
) -> Unit {
  let tmp = Array::make(7, @path.Point::zero())
  @path.chop_cubic_at2(src, ts_t(t), tmp)
  for i in 0..<7 {
    dst[dst_offset + i] = tmp[i]
  }
}

///|
fn ts_valid_unit_divide(numer : Float, denom : Float) -> Float? {
  @path.valid_unit_divide(numer, denom).map(t => t.get())
}

///|
fn ts_find_unit_quad_roots(
  a : Float,
  b : Float,
  c : Float,
  roots : Array[Float],
) -> Int {
  let tmp = @path.new_t_values()
  let n = @path.find_unit_quad_roots(a, b, c, tmp)
  for i in 0..<n {
    roots[i] = tmp[i].get()
  }
  n
}

///|
fn ts_find_cubic_max_curvature(
  src : ArrayView[@path.Point],
  t_values : Array[Float],
) -> Int {
  let tmp = Array::make(3, @path.NormalizedF32::zero())
  let res = @path.find_cubic_max_curvature(src, tmp)
  for i in 0..<res.length() {
    t_values[i] = res[i].get()
  }
  res.length()
}

///|
/// `Point::normalize` (the point becomes zero if it cannot be normalized).
fn pt_normalize(p : @path.Point) -> @path.Point {
  p.normalize().0
}
