// Port of `tiny-skia-path/src/path_geometry.rs`.
//
// `f32x2` values are represented by `Point`; `NormalizedF32` and
// `NormalizedF32Exclusive` by `Float`.

///|
/// use for : eval(t) == A * t^2 + B * t + C
pub(all) struct QuadCoeff {
  a : Point
  b : Point
  c : Point
} derive(Debug)

///|
pub fn QuadCoeff::from_points(points : ArrayView[Point]) -> QuadCoeff {
  let c = points[0]
  let p1 = points[1]
  let p2 = points[2]
  let b = times_2(p1 - c)
  let a = p2 - times_2(p1) + c
  { a, b, c, }
}

///|
pub fn QuadCoeff::eval(self : QuadCoeff, t : Point) -> Point {
  (self.a * t + self.b) * t + self.c
}

///|
pub(all) struct CubicCoeff {
  a : Point
  b : Point
  c : Point
  d : Point
} derive(Debug)

///|
pub fn CubicCoeff::from_points(points : ArrayView[Point]) -> CubicCoeff {
  let p0 = points[0]
  let p1 = points[1]
  let p2 = points[2]
  let p3 = points[3]
  let three = Point::splat(3.0)
  {
    a: p3 + three * (p1 - p2) - p0,
    b: three * (p2 - times_2(p1) + p0),
    c: three * (p1 - p0),
    d: p0,
  }
}

///|
pub fn CubicCoeff::eval(self : CubicCoeff, t : Point) -> Point {
  ((self.a * t + self.b) * t + self.c) * t + self.d
}

///|
/// TODO: to a custom type?
pub fn new_t_values() -> Array[Float] {
  [0.5, 0.5, 0.5]
}

///|
pub fn chop_quad_at(
  src : ArrayView[Point],
  t : Float,
  dst : Array[Point],
) -> Unit {
  let p0 = src[0]
  let p1 = src[1]
  let p2 = src[2]
  let tt = Point::splat(t)
  let p01 = interp(p0, p1, tt)
  let p12 = interp(p1, p2, tt)
  dst[0] = p0
  dst[1] = p01
  dst[2] = interp(p01, p12, tt)
  dst[3] = p12
  dst[4] = p2
}

///|
/// From Numerical Recipes in C.
///
/// Q = -1/2 (B + sign(B) sqrt[B*B - 4*A*C])
/// x1 = Q / A
/// x2 = C / Q
pub fn find_unit_quad_roots(
  a : Float,
  b : Float,
  c : Float,
  roots : Array[Float],
) -> Int {
  if a == 0.0 {
    if valid_unit_divide(-c, b) is Some(r) {
      roots[0] = r
      return 1
    } else {
      return 0
    }
  }

  // use doubles so we don't overflow temporarily trying to compute R
  let mut dr = b.to_double() * b.to_double() -
    4.0 * a.to_double() * c.to_double()
  if dr < 0.0 {
    return 0
  }
  dr = dr.sqrt()
  let r = dr.to_float()
  if !is_finite(r) {
    return 0
  }
  let q = if b < 0.0 { -(b - r) / 2.0 } else { -(b + r) / 2.0 }
  let mut roots_offset = 0
  if valid_unit_divide(q, a) is Some(r) {
    roots[roots_offset] = r
    roots_offset += 1
  }
  if valid_unit_divide(c, q) is Some(r) {
    roots[roots_offset] = r
    roots_offset += 1
  }
  if roots_offset == 2 {
    if roots[0] > roots[1] {
      let tmp = roots[0]
      roots[0] = roots[1]
      roots[1] = tmp
    } else if roots[0] == roots[1] {
      // nearly-equal?
      roots_offset -= 1 // skip the double root
    }
  }
  roots_offset
}

///|
pub fn chop_cubic_at2(
  src : ArrayView[Point],
  t : Float,
  dst : Array[Point],
  dst_offset : Int,
) -> Unit {
  let p0 = src[0]
  let p1 = src[1]
  let p2 = src[2]
  let p3 = src[3]
  let tt = Point::splat(t)
  let ab = interp(p0, p1, tt)
  let bc = interp(p1, p2, tt)
  let cd = interp(p2, p3, tt)
  let abc = interp(ab, bc, tt)
  let bcd = interp(bc, cd, tt)
  let abcd = interp(abc, bcd, tt)
  dst[dst_offset + 0] = p0
  dst[dst_offset + 1] = ab
  dst[dst_offset + 2] = abc
  dst[dst_offset + 3] = abcd
  dst[dst_offset + 4] = bcd
  dst[dst_offset + 5] = cd
  dst[dst_offset + 6] = p3
}

///|
/// Quad'(t) = At + B, where
/// A = 2(a - 2b + c)
/// B = 2(b - a)
/// Solve for t, only if it fits between 0 < t < 1
pub fn find_quad_extrema(a : Float, b : Float, c : Float) -> Float? {
  // At + B == 0
  // t = -B / A
  valid_unit_divide(a - b, a - b - b + c)
}

///|
pub fn valid_unit_divide(numer : Float, denom : Float) -> Float? {
  let mut numer = numer
  let mut denom = denom
  if numer < 0.0 {
    numer = -numer
    denom = -denom
  }
  if denom == 0.0 || numer == 0.0 || numer >= denom {
    return None
  }
  let r = numer / denom
  normalized_f32_exclusive(r)
}

///|
fn interp(v0 : Point, v1 : Point, t : Point) -> Point {
  v0 + (v1 - v0) * t
}

///|
fn times_2(value : Point) -> Point {
  value + value
}

///|
/// F(t)    = a (1 - t) ^ 2 + 2 b t (1 - t) + c t ^ 2
/// F'(t)   = 2 (b - a) + 2 (a - 2b + c) t
/// F''(t)  = 2 (a - 2b + c)
///
/// A = 2 (b - a)
/// B = 2 (a - 2b + c)
///
/// Maximum curvature for a quadratic means solving
/// Fx' Fx'' + Fy' Fy'' = 0
///
/// t = - (Ax Bx + Ay By) / (Bx ^ 2 + By ^ 2)
pub fn find_quad_max_curvature(src : ArrayView[Point]) -> Float {
  let ax = src[1].x - src[0].x
  let ay = src[1].y - src[0].y
  let bx = src[0].x - src[1].x - src[1].x + src[2].x
  let by = src[0].y - src[1].y - src[1].y + src[2].y
  let mut numer = -(ax * bx + ay * by)
  let mut denom = bx * bx + by * by
  if denom < 0.0 {
    numer = -numer
    denom = -denom
  }
  if numer <= 0.0 {
    return 0.0
  }
  if numer >= denom {
    // Also catches denom=0
    return 1.0
  }
  let t = numer / denom
  normalized_f32(t).unwrap()
}

///|
pub fn eval_quad_at(src : ArrayView[Point], t : Float) -> Point {
  QuadCoeff::from_points(src).eval(Point::splat(t))
}

///|
pub fn eval_quad_tangent_at(src : ArrayView[Point], tol : Float) -> Point {
  // The derivative equation is 2(b - a +(a - 2b +c)t). This returns a
  // zero tangent vector when t is 0 or 1, and the control point is equal
  // to the end point. In this case, use the quad end points to compute the
  // tangent.
  if (tol == 0.0 && src[0] == src[1]) || (tol == 1.0 && src[1] == src[2]) {
    return src[2] - src[0]
  }
  let p0 = src[0]
  let p1 = src[1]
  let p2 = src[2]
  let b = p1 - p0
  let a = p2 - p1 - b
  let t = a * Point::splat(tol) + b
  t + t
}

///|
/// Looking for F' dot F'' == 0
///
/// A = b - a
/// B = c - 2b + a
/// C = d - 3c + 3b - a
///
/// F' = 3Ct^2 + 6Bt + 3A
/// F'' = 6Ct + 6B
///
/// F' dot F'' -> CCt^3 + 3BCt^2 + (2BB + CA)t + AB
///
/// Returns the number of values written to `t_values`.
pub fn find_cubic_max_curvature(
  src : ArrayView[Point],
  t_values : Array[Float],
) -> Int {
  let coeff_x = formulate_f1_dot_f2([src[0].x, src[1].x, src[2].x, src[3].x])
  let coeff_y = formulate_f1_dot_f2([src[0].y, src[1].y, src[2].y, src[3].y])
  for i in 0..<4 {
    coeff_x[i] = coeff_x[i] + coeff_y[i]
  }
  solve_cubic_poly(coeff_x, t_values)
}

///|
fn formulate_f1_dot_f2(src : Array[Float]) -> Array[Float] {
  let a = src[1] - src[0]
  let b = src[2] - (2.0 : Float) * src[1] + src[0]
  let c = src[3] + (3.0 : Float) * (src[1] - src[2]) - src[0]
  [c * c, (3.0 : Float) * b * c, (2.0 : Float) * b * b + c * a, a * b]
}

///|
fn solve_cubic_poly(coeff : Array[Float], t_values : Array[Float]) -> Int {
  if is_nearly_zero(coeff[0]) {
    // we're just a quadratic
    let tmp_t = new_t_values()
    let count = find_unit_quad_roots(coeff[1], coeff[2], coeff[3], tmp_t)
    for i in 0..<count {
      t_values[i] = tmp_t[i]
    }
    return count
  }
  let inva = invert(coeff[0])
  let a = coeff[1] * inva
  let b = coeff[2] * inva
  let c = coeff[3] * inva
  let q = (a * a - b * 3.0) / 9.0
  let r = (
      (2.0 : Float) * a * a * a - (9.0 : Float) * a * b + (27.0 : Float) * c
    ) /
    54.0
  let q3 = q * q * q
  let r2_minus_q3 = r * r - q3
  let adiv3 = a / 3.0
  if r2_minus_q3 < 0.0 {
    // we have 3 real roots
    // the divide/root can, due to finite precisions, be slightly outside of
    // -1...1
    let theta = acosf(bound(r / q3.sqrt(), -1.0, 1.0))
    let neg2_root_q = (-2.0 : Float) * q.sqrt()
    t_values[0] = normalized_f32_clamped(
      neg2_root_q * cosf(theta / 3.0) - adiv3,
    )
    t_values[1] = normalized_f32_clamped(
      neg2_root_q * cosf((theta + (2.0 : Float) * float_pi) / 3.0) - adiv3,
    )
    t_values[2] = normalized_f32_clamped(
      neg2_root_q * cosf((theta - (2.0 : Float) * float_pi) / 3.0) - adiv3,
    )

    // now sort the roots
    sort_array3(t_values)
    collapse_duplicates3(t_values)
  } else {
    // we have 1 real root
    let mut a = fabs(r) + r2_minus_q3.sqrt()
    a = scalar_cube_root(a)
    if r > 0.0 {
      a = -a
    }
    if a != 0.0 {
      a += q / a
    }
    t_values[0] = normalized_f32_clamped(a - adiv3)
    1
  }
}

///|
fn sort_array3(array : Array[Float]) -> Unit {
  fn swap(i : Int, j : Int) {
    let t = array[i]
    array[i] = array[j]
    array[j] = t
  }

  if array[0] > array[1] {
    swap(0, 1)
  }
  if array[1] > array[2] {
    swap(1, 2)
  }
  if array[0] > array[1] {
    swap(0, 1)
  }
}

///|
fn collapse_duplicates3(array : Array[Float]) -> Int {
  let mut len = 3
  if array[1] == array[2] {
    len = 2
  }
  if array[0] == array[1] {
    len = 1
  }
  len
}

///|
fn scalar_cube_root(x : Float) -> Float {
  powf(x, 0.3333333)
}

///|
/// This is SkEvalCubicAt split into three functions.
pub fn eval_cubic_pos_at(src : ArrayView[Point], t : Float) -> Point {
  CubicCoeff::from_points(src).eval(Point::splat(t))
}

///|
/// This is SkEvalCubicAt split into three functions.
pub fn eval_cubic_tangent_at(src : ArrayView[Point], t : Float) -> Point {
  // The derivative equation returns a zero tangent vector when t is 0 or 1,
  // and the adjacent control point is equal to the end point. In this case,
  // use the next control point or the end points to compute the tangent.
  if (t == 0.0 && src[0] == src[1]) || (t == 1.0 && src[2] == src[3]) {
    let mut tangent = if t == 0.0 { src[2] - src[0] } else { src[3] - src[1] }
    if tangent.x == 0.0 && tangent.y == 0.0 {
      tangent = src[3] - src[0]
    }
    tangent
  } else {
    eval_cubic_derivative(src, t)
  }
}

///|
fn eval_cubic_derivative(src : ArrayView[Point], t : Float) -> Point {
  let p0 = src[0]
  let p1 = src[1]
  let p2 = src[2]
  let p3 = src[3]
  let coeff : QuadCoeff = {
    a: p3 + Point::splat(3.0) * (p1 - p2) - p0,
    b: times_2(p2 - times_2(p1) + p0),
    c: p1 - p0,
  }
  coeff.eval(Point::splat(t))
}

///|
/// Cubic'(t) = At^2 + Bt + C, where
/// A = 3(-a + 3(b - c) + d)
/// B = 6(a - 2b + c)
/// C = 3(b - a)
/// Solve for t, keeping only those that fit between 0 < t < 1
pub fn find_cubic_extrema(
  a : Float,
  b : Float,
  c : Float,
  d : Float,
  t_values : Array[Float],
) -> Int {
  // we divide A,B,C by 3 to simplify
  let aa = d - a + 3.0 * (b - c)
  let bb = (2.0 : Float) * (a - b - b + c)
  let cc = b - a
  find_unit_quad_roots(aa, bb, cc, t_values)
}

///|
/// http://www.faculty.idc.ac.il/arik/quality/appendixA.html
///
/// Inflection means that curvature is zero.
/// Curvature is [F' x F''] / [F'^3]
/// So we solve F'x X F''y - F'y X F''y == 0
/// After some canceling of the cubic term, we get
/// A = b - a
/// B = c - 2b + a
/// C = d - 3c + 3b - a
/// (BxCy - ByCx)t^2 + (AxCy - AyCx)t + AxBy - AyBx == 0
///
/// Returns the number of values written to `t_values`.
pub fn find_cubic_inflections(
  src : ArrayView[Point],
  t_values : Array[Float],
) -> Int {
  let ax = src[1].x - src[0].x
  let ay = src[1].y - src[0].y
  let bx = src[2].x - 2.0 * src[1].x + src[0].x
  let by = src[2].y - 2.0 * src[1].y + src[0].y
  let cx = src[3].x + 3.0 * (src[1].x - src[2].x) - src[0].x
  let cy = src[3].y + 3.0 * (src[1].y - src[2].y) - src[0].y
  find_unit_quad_roots(
    bx * cy - by * cx,
    ax * cy - ay * cx,
    ax * by - ay * bx,
    t_values,
  )
}

///|
/// Return location (in t) of cubic cusp, if there is one.
/// Note that classify cubic code does not reliably return all cusp'd cubics,
/// so it is not called here.
pub fn find_cubic_cusp(src : ArrayView[Point]) -> Float? {
  // When the adjacent control point matches the end point, it behaves as if
  // the cubic has a cusp: there's a point of max curvature where the
  // derivative goes to zero. Ideally, this would be where t is zero or one,
  // but math error makes not so. It is not uncommon to create cubics this
  // way; skip them.
  if src[0] == src[1] {
    return None
  }
  if src[2] == src[3] {
    return None
  }

  // Cubics only have a cusp if the line segments formed by the control and
  // end points cross. Detect crossing if line ends are on opposite sides of
  // plane formed by the other line.
  if on_same_side(src, 0, 2) || on_same_side(src, 2, 0) {
    return None
  }

  // Cubics may have multiple points of maximum curvature, although at most
  // only one is a cusp.
  let t_values : Array[Float] = [0.0, 0.0, 0.0]
  let n = find_cubic_max_curvature(src, t_values)
  for i in 0..<n {
    let test_t = t_values[i]
    if (0.0 : Float) >= test_t || test_t >= 1.0 {
      // no need to consider max curvature on the end
      continue
    }

    // A cusp is at the max curvature, and also has a derivative close to
    // zero. Choose the 'close to zero' meaning by comparing the derivative
    // length with the overall cubic size.
    let d_pt = eval_cubic_derivative(src, test_t)
    let d_pt_magnitude = d_pt.length_sqd()
    let precision = calc_cubic_precision(src)
    if d_pt_magnitude < precision {
      // All three max curvature t values may be close to the cusp;
      // return the first one.
      return Some(normalized_f32_exclusive_bounded(test_t))
    }
  }
  None
}

///|
/// Returns true if both points src[testIndex], src[testIndex+1] are in the
/// same half plane defined by the line segment src[lineIndex],
/// src[lineIndex+1].
fn on_same_side(
  src : ArrayView[Point],
  test_index : Int,
  line_index : Int,
) -> Bool {
  let origin = src[line_index]
  let line = src[line_index + 1] - origin
  let c0 = line.cross(src[test_index] - origin)
  let c1 = line.cross(src[test_index + 1] - origin)
  c0 * c1 >= 0.0
}

///|
/// Returns a constant proportional to the dimensions of the cubic.
/// Constant found through experimentation -- maybe there's a better way....
fn calc_cubic_precision(src : ArrayView[Point]) -> Float {
  (
    src[1].distance_to_sqd(src[0]) +
    src[2].distance_to_sqd(src[1]) +
    src[3].distance_to_sqd(src[2])
  ) *
  1.0e-8
}

///|
pub(all) struct Conic {
  points : FixedArray[Point]
  weight : Float
}

///|
pub fn Conic::new(
  pt0 : Point,
  pt1 : Point,
  pt2 : Point,
  weight : Float,
) -> Conic {
  { points: [pt0, pt1, pt2], weight, }
}

///|
pub fn Conic::from_points(points : ArrayView[Point], weight : Float) -> Conic {
  { points: [points[0], points[1], points[2]], weight, }
}

///|
fn Conic::compute_quad_pow2(self : Conic, tolerance : Float) -> Int? {
  if tolerance < 0.0 || !is_finite(tolerance) {
    return None
  }
  if !self.points[0].is_finite() ||
    !self.points[1].is_finite() ||
    !self.points[2].is_finite() {
    return None
  }

  // Limit the number of suggested quads to approximate a conic
  let max_conic_to_quad_pow2 = 4

  // "High order approximation of conic sections by quadratic splines"
  // by Michael Floater, 1993
  let a = self.weight - 1.0
  let k = a / (4.0 * (2.0 + a))
  let x = k * (self.points[0].x - 2.0 * self.points[1].x + self.points[2].x)
  let y = k * (self.points[0].y - 2.0 * self.points[1].y + self.points[2].y)
  let mut error = (x * x + y * y).sqrt()
  let mut pow2 = 0
  for _ in 0..<max_conic_to_quad_pow2 {
    if error <= tolerance {
      break
    }
    error *= 0.25
    pow2 += 1
  }

  // Unlike Skia, we always expect `pow2` to be at least 1.
  // Otherwise it produces ugly results.
  Some(if pow2 > 1 { pow2 } else { 1 })
}

///|
/// Chop this conic into N quads, stored continuously in pts[], where
/// N = 1 << pow2. The amount of storage needed is (1 + 2 * N)
pub fn Conic::chop_into_quads_pow2(
  self : Conic,
  pow2 : Int,
  points : Array[Point],
) -> Int {
  points[0] = self.points[0]
  let _ = subdivide(self, points, 1, pow2)
  let quad_count = 1 << pow2
  let pt_count = 2 * quad_count + 1
  let mut any_non_finite = false
  for i in 0..<pt_count {
    if !points[i].is_finite() {
      any_non_finite = true
      break
    }
  }
  if any_non_finite {
    // if we generated a non-finite, pin ourselves to the middle of the hull,
    // as our first and last are already on the first/last pts of the hull.
    for i in 1..<(pt_count - 1) {
      points[i] = self.points[1]
    }
  }
  1 << pow2
}

///|
fn Conic::chop(self : Conic) -> (Conic, Conic) {
  let scale = Point::splat(invert(1.0 + self.weight))
  let new_w = subdivide_weight_value(self.weight)
  let p0 = self.points[0]
  let p1 = self.points[1]
  let p2 = self.points[2]
  let ww = Point::splat(self.weight)
  let wp1 = ww * p1
  let m = (p0 + times_2(wp1) + p2) * scale * Point::splat(0.5)
  let mut m_pt = m
  if !m_pt.is_finite() {
    let w_d = self.weight.to_double()
    let w_2 = w_d * 2.0
    let scale_half = 1.0 / (1.0 + w_d) * 0.5
    m_pt = {
      x: ((
        self.points[0].x.to_double() +
        w_2 * self.points[1].x.to_double() +
        self.points[2].x.to_double()
      ) *
      scale_half).to_float(),
      y: ((
        self.points[0].y.to_double() +
        w_2 * self.points[1].y.to_double() +
        self.points[2].y.to_double()
      ) *
      scale_half).to_float(),
    }
  }
  (
    { points: [self.points[0], (p0 + wp1) * scale, m_pt], weight: new_w, },
    { points: [m_pt, (wp1 + p2) * scale, self.points[2]], weight: new_w, },
  )
}

///|
/// Returns the number of conics written to `dst` (5 slots).
pub fn Conic::build_unit_arc(
  u_start : Point,
  u_stop : Point,
  dir : PathDirection,
  user_transform : Transform,
  dst : Array[Conic],
) -> Int? {
  // rotate by x,y so that u_start is (1.0)
  let x = u_start.dot(u_stop)
  let mut y = u_start.cross(u_stop)
  let abs_y = fabs(y)

  // check for (effectively) coincident vectors
  // this can happen if our angle is nearly 0 or nearly 180 (y == 0)
  // ... we use the dot-prod to distinguish between 0 and 180 (x > 0)
  if abs_y <= scalar_nearly_zero &&
    x > 0.0 &&
    ((y >= 0.0 && dir == CW) || (y <= 0.0 && dir == CCW)) {
    return None
  }
  if dir == CCW {
    y = -y
  }

  // We decide to use 1-conic per quadrant of a circle. What quadrant does
  // [xy] lie in?
  //      0 == [0  .. 90)
  //      1 == [90 ..180)
  //      2 == [180..270)
  //      3 == [270..360)
  //
  let mut quadrant = 0
  if y == 0.0 {
    quadrant = 2 // 180
  } else if x == 0.0 {
    quadrant = if y > 0.0 { 1 } else { 3 } // 90 / 270
  } else {
    if y < 0.0 {
      quadrant += 2
    }
    if (x < 0.0) != (y < 0.0) {
      quadrant += 1
    }
  }
  let quadrant_points = [
    Point::from_xy(1.0, 0.0),
    Point::from_xy(1.0, 1.0),
    Point::from_xy(0.0, 1.0),
    Point::from_xy(-1.0, 1.0),
    Point::from_xy(-1.0, 0.0),
    Point::from_xy(-1.0, -1.0),
    Point::from_xy(0.0, -1.0),
    Point::from_xy(1.0, -1.0),
  ]
  let quadrant_weight = scalar_root_2_over_2
  let mut conic_count = quadrant
  for i in 0..<conic_count {
    dst[i] = Conic::from_points(quadrant_points[i * 2:], quadrant_weight)
  }

  // Now compute any remaining (sub-90-degree) arc for the last conic
  let final_pt = Point::from_xy(x, y)
  let last_q = quadrant_points[quadrant * 2] // will already be a unit-vector
  let dot = last_q.dot(final_pt)
  if dot < 1.0 {
    let off_curve = Point::from_xy(last_q.x + x, last_q.y + y)
    // compute the bisector vector, and then rescale to be the off-curve
    // point. we compute its length from cos(theta/2) = length / 1, using half-
    // angle identity we get length = sqrt(2 / (1 + cos(theta)). We already
    // have cos() when to computed the dot. This is nice, since our computed
    // weight is cos(theta/2) as well!
    let cos_theta_over_2 = (((1.0 : Float) + dot) / 2.0).sqrt()
    let off_curve = match off_curve.set_length(invert(cos_theta_over_2)) {
      Some(p) => p
      None => Point::zero()
    }
    if !last_q.almost_equal(off_curve) {
      dst[conic_count] = Conic::new(
        last_q, off_curve, final_pt, cos_theta_over_2,
      )
      conic_count += 1
    }
  }

  // now handle counter-clockwise and the initial unitStart rotation
  let mut transform = Transform::from_sin_cos(u_start.y, u_start.x)
  if dir == CCW {
    transform = transform.pre_scale(1.0, -1.0)
  }
  transform = transform.post_concat(user_transform)
  for i in 0..<conic_count {
    let conic = dst[i]
    let pts = [conic.points[0], conic.points[1], conic.points[2]]
    transform.map_points(pts)
    dst[i] = { points: [pts[0], pts[1], pts[2]], weight: conic.weight, }
  }
  if conic_count == 0 {
    None
  } else {
    Some(conic_count)
  }
}

///|
fn subdivide_weight_value(w : Float) -> Float {
  ((0.5 : Float) + w * 0.5).sqrt()
}

///|
/// Writes the subdivided points to `points[offset..]` and returns the new
/// offset.
fn subdivide(
  src : Conic,
  points : Array[Point],
  offset : Int,
  level : Int,
) -> Int {
  if level == 0 {
    points[offset] = src.points[1]
    points[offset + 1] = src.points[2]
    offset + 2
  } else {
    let (dst0, dst1) = src.chop()
    let start_y = src.points[0].y
    let end_y = src.points[2].y
    if between(start_y, src.points[1].y, end_y) {
      // If the input is monotonic and the output is not, the scan converter
      // hangs. Ensure that the chopped conics maintain their y-order.
      let mid_y = dst0.points[2].y
      if !between(start_y, mid_y, end_y) {
        // If the computed midpoint is outside the ends, move it to the
        // closer one.
        let closer_y = if fabs(mid_y - start_y) < fabs(mid_y - end_y) {
          start_y
        } else {
          end_y
        }
        dst0.points[2] = { x: dst0.points[2].x, y: closer_y, }
        dst1.points[0] = { x: dst1.points[0].x, y: closer_y, }
      }
      if !between(start_y, dst0.points[1].y, dst0.points[2].y) {
        // If the 1st control is not between the start and end, put it at the
        // start. This also reduces the quad to a line.
        dst0.points[1] = { x: dst0.points[1].x, y: start_y, }
      }
      if !between(dst1.points[0].y, dst1.points[1].y, end_y) {
        // If the 2nd control is not between the start and end, put it at the
        // end. This also reduces the quad to a line.
        dst1.points[1] = { x: dst1.points[1].x, y: end_y, }
      }
    }
    let level = level - 1
    let offset = subdivide(dst0, points, offset, level)
    subdivide(dst1, points, offset, level)
  }
}

///|
/// This was originally developed and tested for pathops: see SkOpTypes.h
/// returns true if (a <= b <= c) || (a >= b >= c)
fn between(a : Float, b : Float, c : Float) -> Bool {
  (a - b) * (c - b) <= 0.0
}

///|
pub struct AutoConicToQuads {
  points : Array[Point]
  len : Int // the number of quads
}

///|
pub fn AutoConicToQuads::compute(
  pt0 : Point,
  pt1 : Point,
  pt2 : Point,
  weight : Float,
) -> AutoConicToQuads? {
  let conic = Conic::new(pt0, pt1, pt2, weight)
  guard conic.compute_quad_pow2(0.25) is Some(pow2) else { return None }
  let points = Array::make(64, Point::zero())
  let len = conic.chop_into_quads_pow2(pow2, points)
  Some({ points, len, })
}
