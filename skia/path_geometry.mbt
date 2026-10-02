// Port of `tiny-skia/src/path_geometry.rs`.

///|
/// Returns the number of chops (0 or 1); `dst` receives 3 or 5 points.
fn chop_quad_at_x_extrema(
  src : ArrayView[@path.Point],
  dst : Array[@path.Point],
) -> Int {
  let a = src[0].x
  let mut b = src[1].x
  let c = src[2].x
  if is_not_monotonic(a, b, c) {
    if @path.valid_unit_divide(a - b, a - b - b + c) is Some(t_value) {
      @path.chop_quad_at(src, t_value, dst)

      // flatten double quad extrema
      dst[1] = { x: dst[2].x, y: dst[1].y, }
      dst[3] = { x: dst[2].x, y: dst[3].y, }
      return 1
    }

    // if we get here, we need to force dst to be monotonic, even though
    // we couldn't compute a unit_divide value (probably underflow).
    b = if @path.fabs(a - b) < @path.fabs(b - c) { a } else { c }
  }
  dst[0] = @path.Point::from_xy(a, src[0].y)
  dst[1] = @path.Point::from_xy(b, src[1].y)
  dst[2] = @path.Point::from_xy(c, src[2].y)
  0
}

///|
fn chop_quad_at_y_extrema(
  src : ArrayView[@path.Point],
  dst : Array[@path.Point],
) -> Int {
  let a = src[0].y
  let mut b = src[1].y
  let c = src[2].y
  if is_not_monotonic(a, b, c) {
    if @path.valid_unit_divide(a - b, a - b - b + c) is Some(t_value) {
      @path.chop_quad_at(src, t_value, dst)

      // flatten double quad extrema
      dst[1] = { x: dst[1].x, y: dst[2].y, }
      dst[3] = { x: dst[3].x, y: dst[2].y, }
      return 1
    }

    // if we get here, we need to force dst to be monotonic, even though
    // we couldn't compute a unit_divide value (probably underflow).
    b = if @path.fabs(a - b) < @path.fabs(b - c) { a } else { c }
  }
  dst[0] = @path.Point::from_xy(src[0].x, a)
  dst[1] = @path.Point::from_xy(src[1].x, b)
  dst[2] = @path.Point::from_xy(src[2].x, c)
  0
}

///|
fn is_not_monotonic(a : Float, b : Float, c : Float) -> Bool {
  let ab = a - b
  let mut bc = b - c
  if ab < 0.0 {
    bc = -bc
  }
  ab == 0.0 || bc < 0.0
}

///|
fn chop_cubic_at_x_extrema(
  src : ArrayView[@path.Point],
  dst : Array[@path.Point],
) -> Int {
  let t_values = @path.new_t_values()
  let n = find_cubic_extrema(src[0].x, src[1].x, src[2].x, src[3].x, t_values)
  chop_cubic_at(src, t_values, n, dst, 0)
  if n != 0 {
    // we do some cleanup to ensure our X extrema are flat
    dst[2] = { x: dst[3].x, y: dst[2].y, }
    dst[4] = { x: dst[3].x, y: dst[4].y, }
    if n == 2 {
      dst[5] = { x: dst[6].x, y: dst[5].y, }
      dst[7] = { x: dst[6].x, y: dst[7].y, }
    }
  }
  n
}

///|
fn chop_cubic_at_y_extrema(
  src : ArrayView[@path.Point],
  dst : Array[@path.Point],
) -> Int {
  let t_values = @path.new_t_values()
  let n = find_cubic_extrema(src[0].y, src[1].y, src[2].y, src[3].y, t_values)
  chop_cubic_at(src, t_values, n, dst, 0)
  if n != 0 {
    // we do some cleanup to ensure our Y extrema are flat
    dst[2] = { x: dst[2].x, y: dst[3].y, }
    dst[4] = { x: dst[4].x, y: dst[3].y, }
    if n == 2 {
      dst[5] = { x: dst[5].x, y: dst[6].y, }
      dst[7] = { x: dst[7].x, y: dst[6].y, }
    }
  }
  n
}

///|
/// Cubic'(t) = At^2 + Bt + C, where
/// A = 3(-a + 3(b - c) + d)
/// B = 6(a - 2b + c)
/// C = 3(b - a)
/// Solve for t, keeping only those that fit between 0 < t < 1
fn find_cubic_extrema(
  a : Float,
  b : Float,
  c : Float,
  d : Float,
  t_values : Array[Float],
) -> Int {
  // we divide A,B,C by 3 to simplify
  let na = d - a + (3.0 : Float) * (b - c)
  let nb = (2.0 : Float) * (a - b - b + c)
  let nc = b - a
  @path.find_unit_quad_roots(na, nb, nc, t_values)
}

///|
/// http://code.google.com/p/skia/issues/detail?id=32
///
/// This test code would fail when we didn't check the return result of
/// valid_unit_divide in SkChopCubicAt(... NormalizedF32Exclusives[], int
/// roots). The reason is that after the first chop, the parameters to
/// valid_unit_divide are equal (thanks to finite float precision and rounding
/// in the subtracts). Thus even though the 2nd NormalizedF32Exclusive looks
/// < 1.0, after we renormalize it, we end up with 1.0, hence the need to
/// check and just return the last cubic as a degenerate clump of 4 points in
/// the same place.
fn chop_cubic_at(
  src : ArrayView[@path.Point],
  t_values : Array[Float],
  t_len : Int,
  dst : Array[@path.Point],
  dst_base : Int,
) -> Unit {
  if t_len == 0 {
    // nothing to chop
    dst[dst_base + 0] = src[0]
    dst[dst_base + 1] = src[1]
    dst[dst_base + 2] = src[2]
    dst[dst_base + 3] = src[3]
  } else {
    let mut t = t_values[0]
    let tmp = [src[0], src[1], src[2], src[3]]
    let mut src = src
    let mut dst_offset = dst_base
    for i in 0..<t_len {
      @path.chop_cubic_at2(src, t, dst, dst_offset)
      if i == t_len - 1 {
        break
      }
      dst_offset += 3
      // have src point to the remaining cubic (after the chop)
      tmp[0] = dst[dst_offset + 0]
      tmp[1] = dst[dst_offset + 1]
      tmp[2] = dst[dst_offset + 2]
      tmp[3] = dst[dst_offset + 3]
      src = tmp[:]

      // watch out in case the renormalized t isn't in range
      let n = @path.valid_unit_divide(
        t_values[i + 1] - t_values[i],
        1.0 - t_values[i],
      )
      match n {
        Some(n) => t = n
        None => {
          // if we can't, just create a degenerate cubic
          dst[dst_offset + 4] = src[3]
          dst[dst_offset + 5] = src[3]
          dst[dst_offset + 6] = src[3]
          break
        }
      }
    }
  }
}

///|
fn chop_cubic_at_max_curvature(
  src : ArrayView[@path.Point],
  t_values : Array[Float],
  dst : Array[@path.Point],
) -> Int {
  let roots : Array[Float] = [0.0, 0.0, 0.0]
  let n = @path.find_cubic_max_curvature(src, roots)

  // Throw out values not inside 0..1.
  let mut count = 0
  for i in 0..<n {
    let root = roots[i]
    if (0.0 : Float) < root && root < 1.0 {
      t_values[count] = @path.normalized_f32_exclusive_bounded(root)
      count += 1
    }
  }
  if count == 0 {
    for i in 0..<4 {
      dst[i] = src[i]
    }
  } else {
    chop_cubic_at(src, t_values, count, dst, 0)
  }
  count + 1
}

///|
fn chop_mono_cubic_at_x_dchop(
  src : ArrayView[@path.Point],
  x : Float,
  dst : Array[@path.Point],
) -> Bool {
  cubic_dchop_at_intercept(src, x, true, dst)
}

///|
fn chop_mono_cubic_at_y_dchop(
  src : ArrayView[@path.Point],
  y : Float,
  dst : Array[@path.Point],
) -> Bool {
  cubic_dchop_at_intercept(src, y, false, dst)
}

///|
fn cubic_dchop_at_intercept(
  src : ArrayView[@path.Point],
  intercept : Float,
  is_vertical : Bool,
  dst : Array[@path.Point],
) -> Bool {
  let cubic : Cubic64 = {
    points: [
      Point64::from_point(src[0]),
      Point64::from_point(src[1]),
      Point64::from_point(src[2]),
      Point64::from_point(src[3]),
    ],
  }
  let roots = FixedArray::make(3, 0.0)
  let count = if is_vertical {
    vertical_intersect(cubic, intercept.to_double(), roots)
  } else {
    horizontal_intersect(cubic, intercept.to_double(), roots)
  }
  if count > 0 {
    let pair = cubic.chop_at(roots[0])
    for i in 0..<7 {
      dst[i] = pair[i].to_point()
    }
    true
  } else {
    false
  }
}
