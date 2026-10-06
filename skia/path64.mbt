// Port of `tiny-skia/src/path64/` (mod.rs, point64.rs, cubic64.rs,
// quad64.rs, line_cubic_intersections.rs). The code is from SkPathOpsTypes,
// SkPathOpsCubic, SkPathOpsQuad and SkDLineCubicIntersection.

///|
let dbl_epsilon : Double = 2.220446049250313e-16

///|
let dbl_epsilon_err : Double = dbl_epsilon * 4.0

///|
let flt_epsilon_half : Double = (f32_epsilon / 2.0).to_double()

///|
let flt_epsilon_cubed : Double = (f32_epsilon * f32_epsilon * f32_epsilon).to_double()

///|
let flt_epsilon_inverse : Double = 1.0 / f32_epsilon.to_double()

///|
/// Works just like SkTPin, returning `max` for NaN/inf
fn bound64(x : Double, min : Double, max : Double) -> Double {
  dmax(dmin(max, x), min)
}

///|
fn between64(x : Double, a : Double, b : Double) -> Bool {
  (a - x) * (b - x) <= 0.0
}

///|
// Only used by the `debug_assert!` of `between` upstream
// (path64/mod.rs:51).
#warnings("-unused_value")
fn precisely_zero(x : Double) -> Bool {
  x.abs() < dbl_epsilon_err
}

///|
fn approximately_zero_or_more(x : Double) -> Bool {
  x > -dbl_epsilon
}

///|
fn approximately_one_or_less(x : Double) -> Bool {
  x < 1.0 + dbl_epsilon
}

///|
fn approximately_zero(x : Double) -> Bool {
  x.abs() < dbl_epsilon
}

///|
fn approximately_zero_inverse(x : Double) -> Bool {
  x.abs() > flt_epsilon_inverse
}

///|
fn approximately_zero_cubed(x : Double) -> Bool {
  x.abs() < flt_epsilon_cubed
}

///|
fn approximately_zero_half(x : Double) -> Bool {
  x < flt_epsilon_half
}

///|
fn approximately_zero_when_compared_to(x : Double, other : Double) -> Bool {
  x == 0.0 || x.abs() < (other * f32_epsilon.to_double()).abs()
}

///|
/// Use this for comparing Ts in the range of 0 to 1. For general numbers
/// (larger and smaller) use AlmostEqualUlps instead.
fn approximately_equal(x : Double, other : Double) -> Bool {
  approximately_zero(x - other)
}

///|
fn approximately_equal_half(x : Double, other : Double) -> Bool {
  approximately_zero_half(x - other)
}

///|
fn almost_dequal_ulps64(x : Double, other : Double) -> Bool {
  let max = scalar_max.to_double()
  if x.abs() < max && other.abs() < max {
    almost_dequal_ulps(x.to_float(), other.to_float())
  } else {
    (x - other).abs() / dmax(x.abs(), other.abs()) <
    (f32_epsilon * 16.0).to_double()
  }
}

///|
fn cube_root(x : Double) -> Double {
  if approximately_zero_cubed(x) {
    return 0.0
  }
  let result = halley_cbrt3d(x.abs())
  if x < 0.0 {
    -result
  } else {
    result
  }
}

///|
/// cube root approximation using 3 iterations of Halley's method (double)
fn halley_cbrt3d(d : Double) -> Double {
  let mut a = cbrt_5d(d)
  a = cbrta_halleyd(a, d)
  a = cbrta_halleyd(a, d)
  cbrta_halleyd(a, d)
}

///|
/// cube root approximation using bit hack for 64-bit float
/// adapted from Kahan's cbrt
fn cbrt_5d(d : Double) -> Double {
  let b1 : UInt = 715094163
  let hi = (d.reinterpret_as_uint64() >> 32).to_uint()
  let t_hi = hi / 3 + b1
  (t_hi.to_uint64() << 32).reinterpret_as_double()
}

///|
/// iterative cube root approximation using Halley's method (double)
fn cbrta_halleyd(a : Double, r : Double) -> Double {
  let a3 = a * a * a
  a * (a3 + r + r) / (a3 + a3 + r)
}

///|
fn interp64(a : Double, b : Double, t : Double) -> Double {
  a + (b - a) * t
}

// point64.rs

///|
enum SearchAxis {
  X
  Y
} derive(Eq)

///|
struct Point64 {
  x : Double
  y : Double
} derive(Eq)

///|
fn Point64::from_point(p : @path.Point) -> Point64 {
  { x: p.x.to_double(), y: p.y.to_double(), }
}

///|
fn Point64::to_point(self : Point64) -> @path.Point {
  @path.Point::from_xy(self.x.to_float(), self.y.to_float())
}

///|
fn Point64::axis_coord(self : Point64, axis : SearchAxis) -> Double {
  match axis {
    X => self.x
    Y => self.y
  }
}

// cubic64.rs

///|
let pi64 : Double = 3.141592653589793

///|
priv struct Cubic64 {
  points : FixedArray[Point64]
}

///|
fn Cubic64::as_f64_slice(self : Cubic64) -> FixedArray[Double] {
  [
    self.points[0].x,
    self.points[0].y,
    self.points[1].x,
    self.points[1].y,
    self.points[2].x,
    self.points[2].y,
    self.points[3].x,
    self.points[3].y,
  ]
}

///|
fn Cubic64::point_at_t(self : Cubic64, t : Double) -> Point64 {
  if t == 0.0 {
    return self.points[0]
  }
  if t == 1.0 {
    return self.points[3]
  }
  let one_t = 1.0 - t
  let one_t2 = one_t * one_t
  let a = one_t2 * one_t
  let b = 3.0 * one_t2 * t
  let t2 = t * t
  let c = 3.0 * one_t * t2
  let d = t2 * t
  {
    x: a * self.points[0].x +
    b * self.points[1].x +
    c * self.points[2].x +
    d * self.points[3].x,
    y: a * self.points[0].y +
    b * self.points[1].y +
    c * self.points[2].y +
    d * self.points[3].y,
  }
}

///|
fn Cubic64::search_roots(
  self : Cubic64,
  extrema : Int,
  axis_intercept : Double,
  x_axis : SearchAxis,
  extreme_ts : FixedArray[Double],
  valid_roots : FixedArray[Double],
) -> Int {
  let mut extrema = extrema
  extrema += self.find_inflections(extreme_ts, extrema)
  extreme_ts[extrema] = 0.0
  extrema += 1
  extreme_ts[extrema] = 1.0
  // `extreme_ts[0..extrema].sort_by(cmp_f64)` (stable).
  for i in 1..<extrema {
    let v = extreme_ts[i]
    let mut j = i
    while j > 0 && extreme_ts[j - 1] > v {
      extreme_ts[j] = extreme_ts[j - 1]
      j -= 1
    }
    extreme_ts[j] = v
  }
  let mut valid_count = 0
  let mut index = 0
  while index < extrema {
    let min = extreme_ts[index]
    index += 1
    let max = extreme_ts[index]
    if min == max {
      continue
    }
    let new_t = self.binary_search(min, max, axis_intercept, x_axis)
    if new_t >= 0.0 {
      if valid_count >= 3 {
        return 0
      }
      valid_roots[valid_count] = new_t
      valid_count += 1
    }
  }
  valid_count
}

///|
fn Cubic64::find_inflections(
  self : Cubic64,
  t_values : FixedArray[Double],
  offset : Int,
) -> Int {
  let ax = self.points[1].x - self.points[0].x
  let ay = self.points[1].y - self.points[0].y
  let bx = self.points[2].x - 2.0 * self.points[1].x + self.points[0].x
  let by = self.points[2].y - 2.0 * self.points[1].y + self.points[0].y
  let cx = self.points[3].x +
    3.0 * (self.points[1].x - self.points[2].x) -
    self.points[0].x
  let cy = self.points[3].y +
    3.0 * (self.points[1].y - self.points[2].y) -
    self.points[0].y
  quad64_roots_valid_t(
    bx * cy - by * cx,
    ax * cy - ay * cx,
    ax * by - ay * bx,
    t_values,
    offset,
  )
}

///|
/// give up when changing t no longer moves point
/// also, copy point rather than recompute it when it does change
fn Cubic64::binary_search(
  self : Cubic64,
  min : Double,
  max : Double,
  axis_intercept : Double,
  x_axis : SearchAxis,
) -> Double {
  let mut t = (min + max) / 2.0
  let mut step = (t - min) / 2.0
  let mut cubic_at_t = self.point_at_t(t)
  let mut calc_pos = cubic_at_t.axis_coord(x_axis)
  let mut calc_dist = calc_pos - axis_intercept
  while true {
    let prior_t = dmax(min, t - step)
    let less_pt = self.point_at_t(prior_t)
    if approximately_equal_half(less_pt.x, cubic_at_t.x) &&
      approximately_equal_half(less_pt.y, cubic_at_t.y) {
      return -1.0 // binary search found no point at this axis intercept
    }
    let less_dist = less_pt.axis_coord(x_axis) - axis_intercept
    let last_step = step
    step /= 2.0
    let ok = if calc_dist > 0.0 {
      calc_dist > less_dist
    } else {
      calc_dist < less_dist
    }
    if ok {
      t = prior_t
    } else {
      let next_t = t + last_step
      if next_t > max {
        return -1.0
      }
      let more_pt = self.point_at_t(next_t)
      if approximately_equal_half(more_pt.x, cubic_at_t.x) &&
        approximately_equal_half(more_pt.y, cubic_at_t.y) {
        return -1.0 // binary search found no point at this axis intercept
      }
      let more_dist = more_pt.axis_coord(x_axis) - axis_intercept
      let ok = if calc_dist > 0.0 {
        calc_dist <= more_dist
      } else {
        calc_dist >= more_dist
      }
      if ok {
        continue
      }
      t = next_t
    }
    let test_at_t = self.point_at_t(t)
    cubic_at_t = test_at_t
    calc_pos = cubic_at_t.axis_coord(x_axis)
    calc_dist = calc_pos - axis_intercept
    if approximately_equal(calc_pos, axis_intercept) {
      break
    }
  }
  t
}

///|
fn Cubic64::chop_at(self : Cubic64, t : Double) -> FixedArray[Point64] {
  let p = self.points
  if t == 0.5 {
    [
      p[0],
      { x: (p[0].x + p[1].x) / 2.0, y: (p[0].y + p[1].y) / 2.0, },
      {
        x: (p[0].x + 2.0 * p[1].x + p[2].x) / 4.0,
        y: (p[0].y + 2.0 * p[1].y + p[2].y) / 4.0,
      },
      {
        x: (p[0].x + 3.0 * (p[1].x + p[2].x) + p[3].x) / 8.0,
        y: (p[0].y + 3.0 * (p[1].y + p[2].y) + p[3].y) / 8.0,
      },
      {
        x: (p[1].x + 2.0 * p[2].x + p[3].x) / 4.0,
        y: (p[1].y + 2.0 * p[2].y + p[3].y) / 4.0,
      },
      { x: (p[2].x + p[3].x) / 2.0, y: (p[2].y + p[3].y) / 2.0, },
      p[3],
    ]
  } else {
    let xs = interp_cubic_coords(p[0].x, p[1].x, p[2].x, p[3].x, t)
    let ys = interp_cubic_coords(p[0].y, p[1].y, p[2].y, p[3].y, t)
    FixedArray::makei(7, i => { x: xs[i], y: ys[i], })
  }
}

///|
/// classic one t subdivision
fn interp_cubic_coords(
  s0 : Double,
  s1 : Double,
  s2 : Double,
  s3 : Double,
  t : Double,
) -> FixedArray[Double] {
  let ab = interp64(s0, s1, t)
  let bc = interp64(s1, s2, t)
  let cd = interp64(s2, s3, t)
  let abc = interp64(ab, bc, t)
  let bcd = interp64(bc, cd, t)
  let abcd = interp64(abc, bcd, t)
  [s0, ab, abc, abcd, bcd, cd, s3]
}

///|
fn cubic64_coefficients(
  src : FixedArray[Double],
  offset : Int,
) -> (Double, Double, Double, Double) {
  let mut a = src[offset + 6] // d
  let mut b = src[offset + 4] * 3.0 // 3*c
  let mut c = src[offset + 2] * 3.0 // 3*b
  let d = src[offset + 0] // a
  a -= d - c + b // A =   -a + 3*b - 3*c + d
  b += 3.0 * d - 2.0 * c // B =  3*a - 6*b + 3*c
  c -= 3.0 * d // C = -3*a + 3*b
  (a, b, c, d)
}

///|
/// from SkGeometry.cpp (and Numeric Solutions, 5.6)
fn cubic64_roots_valid_t(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  t : FixedArray[Double],
) -> Int {
  let s = FixedArray::make(3, 0.0)
  let real_roots = cubic64_roots_real(a, b, c, d, s)
  let mut found_roots = quad64_push_valid_ts(s, real_roots, t, 0)
  for index in 0..<real_roots {
    let t_value = s[index]
    if !approximately_one_or_less(t_value) && between64(t_value, 1.0, 1.00005) {
      let mut skip = false
      for idx2 in 0..<found_roots {
        if approximately_equal(t[idx2], 1.0) {
          skip = true
          break
        }
      }
      if skip {
        continue
      }
      t[found_roots] = 1.0
      found_roots += 1
    } else if !approximately_zero_or_more(t_value) &&
      between64(t_value, -0.00005, 0.0) {
      let mut skip = false
      for idx2 in 0..<found_roots {
        if approximately_equal(t[idx2], 0.0) {
          skip = true
          break
        }
      }
      if skip {
        continue
      }
      t[found_roots] = 0.0
      found_roots += 1
    }
  }
  found_roots
}

///|
fn cubic64_roots_real(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  s : FixedArray[Double],
) -> Int {
  if approximately_zero(a) &&
    approximately_zero_when_compared_to(a, b) &&
    approximately_zero_when_compared_to(a, c) &&
    approximately_zero_when_compared_to(a, d) {
    // we're just a quadratic
    return quad64_roots_real(b, c, d, s)
  }
  if approximately_zero_when_compared_to(d, a) &&
    approximately_zero_when_compared_to(d, b) &&
    approximately_zero_when_compared_to(d, c) {
    // 0 is one root
    let mut num = quad64_roots_real(a, b, c, s)
    for i in 0..<num {
      if approximately_zero(s[i]) {
        return num
      }
    }
    s[num] = 0.0
    num += 1
    return num
  }
  if approximately_zero(a + b + c + d) {
    // 1 is one root
    let mut num = quad64_roots_real(a, a + b, -d, s)
    for i in 0..<num {
      if almost_dequal_ulps64(s[i], 1.0) {
        return num
      }
    }
    s[num] = 1.0
    num += 1
    return num
  }
  let inv_a = 1.0 / a
  let a = b * inv_a
  let b = c * inv_a
  let c = d * inv_a
  let a2 = a * a
  let q = (a2 - b * 3.0) / 9.0
  let r = (2.0 * a2 * a - 9.0 * a * b + 27.0 * c) / 54.0
  let r2 = r * r
  let q3 = q * q * q
  let r2_minus_q3 = r2 - q3
  let adiv3 = a / 3.0
  let mut offset = 0
  if r2_minus_q3 < 0.0 {
    // we have 3 real roots

    // the divide/root can, due to finite precisions, be slightly outside of
    // -1...1
    let theta = libm_acos(bound64(r / q3.sqrt(), -1.0, 1.0))
    let neg2_root_q = -2.0 * q.sqrt()
    let mut rr = neg2_root_q * libm_cos(theta / 3.0) - adiv3
    s[offset] = rr
    offset += 1
    rr = neg2_root_q * libm_cos((theta + 2.0 * pi64) / 3.0) - adiv3
    if !almost_dequal_ulps64(s[0], rr) {
      s[offset] = rr
      offset += 1
    }
    rr = neg2_root_q * libm_cos((theta - 2.0 * pi64) / 3.0) - adiv3
    if !almost_dequal_ulps64(s[0], rr) &&
      (offset == 1 || !almost_dequal_ulps64(s[1], rr)) {
      s[offset] = rr
      offset += 1
    }
  } else {
    // we have 1 real root
    let sqrt_r2_minus_q3 = r2_minus_q3.sqrt()
    let mut a = r.abs() + sqrt_r2_minus_q3
    a = cube_root(a)
    if r > 0.0 {
      a = -a
    }
    if a != 0.0 {
      a += q / a
    }
    let mut r2 = a - adiv3
    s[offset] = r2
    offset += 1
    if almost_dequal_ulps64(r2, q3) {
      r2 = -a / 2.0 - adiv3
      if !almost_dequal_ulps64(s[0], r2) {
        s[offset] = r2
        offset += 1
      }
    }
  }
  offset
}

///|
/// Cubic64'(t) = At^2 + Bt + C, where
/// A = 3(-a + 3(b - c) + d)
/// B = 6(a - 2b + c)
/// C = 3(b - a)
/// Solve for t, keeping only those that fit between 0 < t < 1
fn cubic64_find_extrema(
  src : FixedArray[Double],
  offset : Int,
  t_values : FixedArray[Double],
) -> Int {
  // we divide A,B,C by 3 to simplify
  let a = src[offset + 0]
  let b = src[offset + 2]
  let c = src[offset + 4]
  let d = src[offset + 6]
  let a2 = d - a + 3.0 * (b - c)
  let b2 = 2.0 * (a - b - b + c)
  let c2 = b - a
  quad64_roots_valid_t(a2, b2, c2, t_values, 0)
}

// quad64.rs

///|
fn quad64_push_valid_ts(
  s : FixedArray[Double],
  real_roots : Int,
  t : FixedArray[Double],
  t_offset : Int,
) -> Int {
  let mut found_roots = 0
  for index in 0..<real_roots {
    let mut t_value = s[index]
    if approximately_zero_or_more(t_value) && approximately_one_or_less(t_value) {
      t_value = bound64(t_value, 0.0, 1.0)
      let mut skip = false
      for idx2 in 0..<found_roots {
        if approximately_equal(t[t_offset + idx2], t_value) {
          skip = true
          break
        }
      }
      if skip {
        continue
      }
      t[t_offset + found_roots] = t_value
      found_roots += 1
    }
  }
  found_roots
}

///|
/// note: caller expects multiple results to be sorted smaller first
fn quad64_roots_valid_t(
  a : Double,
  b : Double,
  c : Double,
  t : FixedArray[Double],
  t_offset : Int,
) -> Int {
  let s = FixedArray::make(3, 0.0)
  let real_roots = quad64_roots_real(a, b, c, s)
  quad64_push_valid_ts(s, real_roots, t, t_offset)
}

///|
/// Numeric Solutions (5.6) suggests to solve the quadratic by computing
///     Q = -1/2(B + sgn(B)Sqrt(B^2 - 4 A C))
/// and using the roots
///     t1 = Q / A
///     t2 = C / Q
///
/// this does not discard real roots <= 0 or >= 1
fn quad64_roots_real(
  a : Double,
  b : Double,
  c : Double,
  s : FixedArray[Double],
) -> Int {
  if a == 0.0 {
    return quad64_handle_zero(b, c, s)
  }
  let p = b / (2.0 * a)
  let q = c / a
  if approximately_zero(a) &&
    (approximately_zero_inverse(p) || approximately_zero_inverse(q)) {
    return quad64_handle_zero(b, c, s)
  }

  // normal form: x^2 + px + q = 0
  let p2 = p * p
  if !almost_dequal_ulps64(p2, q) && p2 < q {
    return 0
  }
  let mut sqrt_d = 0.0
  if p2 > q {
    sqrt_d = (p2 - q).sqrt()
  }
  s[0] = sqrt_d - p
  s[1] = -sqrt_d - p
  1 + (if !almost_dequal_ulps64(s[0], s[1]) { 1 } else { 0 })
}

///|
fn quad64_handle_zero(b : Double, c : Double, s : FixedArray[Double]) -> Int {
  if approximately_zero(b) {
    s[0] = 0.0
    if c == 0.0 {
      1
    } else {
      0
    }
  } else {
    s[0] = -c / b
    1
  }
}

// line_cubic_intersections.rs

///|
fn horizontal_intersect(
  cubic : Cubic64,
  axis_intercept : Double,
  roots : FixedArray[Double],
) -> Int {
  let (a, b, c, d) = cubic64_coefficients(cubic.as_f64_slice(), 1)
  let d = d - axis_intercept
  let mut count = cubic64_roots_valid_t(a, b, c, d, roots)
  let mut index = 0
  while index < count {
    let calc_pt = cubic.point_at_t(roots[index])
    if !approximately_equal(calc_pt.y, axis_intercept) {
      let extreme_ts = FixedArray::make(6, 0.0)
      let extrema = cubic64_find_extrema(cubic.as_f64_slice(), 1, extreme_ts)
      count = cubic.search_roots(extrema, axis_intercept, Y, extreme_ts, roots)
      break
    }
    index += 1
  }
  count
}

///|
fn vertical_intersect(
  cubic : Cubic64,
  axis_intercept : Double,
  roots : FixedArray[Double],
) -> Int {
  let (a, b, c, d) = cubic64_coefficients(cubic.as_f64_slice(), 0)
  let d = d - axis_intercept
  let mut count = cubic64_roots_valid_t(a, b, c, d, roots)
  let mut index = 0
  while index < count {
    let calc_pt = cubic.point_at_t(roots[index])
    if !approximately_equal(calc_pt.x, axis_intercept) {
      let extreme_ts = FixedArray::make(6, 0.0)
      let extrema = cubic64_find_extrema(cubic.as_f64_slice(), 0, extreme_ts)
      count = cubic.search_roots(extrema, axis_intercept, X, extreme_ts, roots)
      break
    }
    index += 1
  }
  count
}
