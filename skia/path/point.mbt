// Port of `Point` from `tiny-skia-path/src/lib.rs` and of `f32x2`
// (`f32x2_t.rs`), which is represented by `Point` as well.

///|
/// A point.
///
/// Doesn't guarantee to be finite.
pub(all) struct Point {
  x : Float
  y : Float
} derive(Eq, Debug, Default)

///|
/// Creates a new `Point`.
pub fn Point::from_xy(x : Float, y : Float) -> Point {
  { x, y, }
}

///|
/// Creates a point at 0x0 position.
pub fn Point::zero() -> Point {
  { x: 0.0, y: 0.0, }
}

///|
/// `f32x2::splat`.
pub fn Point::splat(v : Float) -> Point {
  { x: v, y: v, }
}

///|
/// Returns true if x and y are both zero.
pub fn Point::is_zero(self : Point) -> Bool {
  self.x == 0.0 && self.y == 0.0
}

///|
/// Returns true if both x and y are measurable values.
pub fn Point::is_finite(self : Point) -> Bool {
  is_finite(self.x * self.y)
}

///|
/// Checks that two `Point`s are almost equal.
pub fn Point::almost_equal(self : Point, other : Point) -> Bool {
  !(self - other).can_normalize()
}

///|
/// Checks that two `Point`s are almost equal using the specified tolerance.
pub fn Point::equals_within_tolerance(
  self : Point,
  other : Point,
  tolerance : Float,
) -> Bool {
  is_nearly_zero_within_tolerance(self.x - other.x, tolerance) &&
  is_nearly_zero_within_tolerance(self.y - other.y, tolerance)
}

///|
/// Scales (x, y) so that length() returns one, while preserving ratio of x to
/// y, if possible. Returns `None` (the zero vector upstream) if the prior
/// length is nearly zero.
pub fn Point::normalize(self : Point) -> Point? {
  set_point_length(self.x, self.y, 1.0)
}

///|
pub fn Point::can_normalize(self : Point) -> Bool {
  is_finite(self.x) && is_finite(self.y) && (self.x != 0.0 || self.y != 0.0)
}

///|
/// Returns the Euclidean distance from origin.
pub fn Point::length(self : Point) -> Float {
  let mag2 = self.x * self.x + self.y * self.y
  if is_finite(mag2) {
    mag2.sqrt()
  } else {
    let xx = self.x.to_double()
    let yy = self.y.to_double()
    (xx * xx + yy * yy).sqrt().to_float()
  }
}

///|
/// Scales vector so that its length is `length`, if possible.
///
/// Upstream mutates the point and returns whether it succeeded; on failure
/// the point becomes zero. Here the new point is returned on success.
pub fn Point::set_length(self : Point, length : Float) -> Point? {
  set_point_length(self.x, self.y, length)
}

///|
/// Returns the Euclidean distance between two points.
pub fn Point::distance(self : Point, other : Point) -> Float {
  (self - other).length()
}

///|
/// Returns the dot product of two points.
pub fn Point::dot(self : Point, other : Point) -> Float {
  self.x * other.x + self.y * other.y
}

///|
/// Returns the cross product of vector and vec.
pub fn Point::cross(self : Point, other : Point) -> Float {
  self.x * other.y - self.y * other.x
}

///|
pub fn Point::distance_to_sqd(self : Point, pt : Point) -> Float {
  let dx = self.x - pt.x
  let dy = self.y - pt.y
  dx * dx + dy * dy
}

///|
pub fn Point::length_sqd(self : Point) -> Float {
  self.dot(self)
}

///|
/// Returns the point scaled by `scale`.
pub fn Point::scaled(self : Point, scale : Float) -> Point {
  { x: self.x * scale, y: self.y * scale, }
}

///|
pub fn Point::swap_coords(self : Point) -> Point {
  { x: self.y, y: self.x, }
}

///|
pub fn Point::rotate_cw(self : Point) -> Point {
  { x: -self.y, y: self.x, }
}

///|
pub fn Point::rotate_ccw(self : Point) -> Point {
  { x: self.y, y: -self.x, }
}

///|
/// `set_point_length`. We have to worry about 2 tricky conditions:
/// 1. underflow of mag2 (compared against nearlyzero^2)
/// 2. overflow of mag2 (compared w/ isfinite)
///
/// Returns `None` if the result is not finite or zero (upstream sets the
/// point to zero and returns false).
fn set_point_length(x : Float, y : Float, length : Float) -> Point? {
  // our mag2 step overflowed to infinity, so use doubles instead.
  // much slower, but needed when x or y are very large, other wise we
  // divide by inf. and return (0,0) vector.
  let xx = x.to_double()
  let yy = y.to_double()
  let dmag = (xx * xx + yy * yy).sqrt()
  let dscale = length.to_double() / dmag
  let x = x * dscale.to_float()
  let y = y * dscale.to_float()

  // check if we're not finite, or we're zero-length
  if !is_finite(x) || !is_finite(y) || (x == 0.0 && y == 0.0) {
    return None
  }
  Some({ x, y, })
}

///|
/// Like [set_point_length], but also returns the original length.
pub fn set_point_length_with_orig(
  x : Float,
  y : Float,
  length : Float,
) -> (Point, Float)? {
  let xx = x.to_double()
  let yy = y.to_double()
  let dmag = (xx * xx + yy * yy).sqrt()
  let dscale = length.to_double() / dmag
  let x = x * dscale.to_float()
  let y = y * dscale.to_float()
  if !is_finite(x) || !is_finite(y) || (x == 0.0 && y == 0.0) {
    return None
  }
  Some(({ x, y, }, dmag.to_float()))
}

///|
pub impl Neg for Point with fn neg(self) {
  { x: -self.x, y: -self.y, }
}

///|
pub impl Add for Point with fn add(self, other) {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
pub impl Sub for Point with fn sub(self, other) {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
pub impl Mul for Point with fn mul(self, other) {
  { x: self.x * other.x, y: self.y * other.y, }
}

///|
pub impl Div for Point with fn div(self, other) {
  { x: self.x / other.x, y: self.y / other.y, }
}

// f32x2

///|
fn pmax(a : Float, b : Float) -> Float {
  if a < b {
    b
  } else {
    a
  }
}

///|
fn pmin(a : Float, b : Float) -> Float {
  if b < a {
    b
  } else {
    a
  }
}

///|
/// `f32x2::abs`.
pub fn Point::abs(self : Point) -> Point {
  { x: fabs(self.x), y: fabs(self.y), }
}

///|
/// `f32x2::min`.
pub fn Point::min(self : Point, other : Point) -> Point {
  { x: pmin(self.x, other.x), y: pmin(self.y, other.y), }
}

///|
/// `f32x2::max`.
pub fn Point::max(self : Point, other : Point) -> Point {
  { x: pmax(self.x, other.x), y: pmax(self.y, other.y), }
}

///|
/// `f32x2::max_component`.
pub fn Point::max_component(self : Point) -> Float {
  pmax(self.x, self.y)
}
