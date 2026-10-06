// Port of `tiny-skia-path` 0.12.0 `src/lib.rs`.
//
// A tiny-skia Bezier path implementation.
//
// Provides a memory-efficient Bezier path container, path builder, path
// stroker and path dasher. Note that all types use single precision floats
// (`f32` -> `Float`), just like Skia.
//
// `Point` is an immutable value here: upstream's in-place mutators
// (`normalize`, `set_length`, `scale`, ...) return the updated point instead
// (paired with the `bool` result where upstream returns one).

///|
/// A point.
///
/// Doesn't guarantee to be finite.
pub(all) struct Point {
  x : Float
  y : Float
} derive(Eq, Debug, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with Default::{default}

///|
/// Creates a new `Point`.
pub fn Point::from_xy(x : Float, y : Float) -> Point {
  { x, y, }
}

///|
/// Creates a new `Point` from `f32x2`.
pub fn Point::from_f32x2(r : F32x2) -> Point {
  Point::from_xy(r.x(), r.y())
}

///|
/// Converts a `Point` into a `f32x2`.
pub fn Point::to_f32x2(self : Point) -> F32x2 {
  F32x2::new(self.x, self.y)
}

///|
/// Creates a point at 0x0 position.
pub fn Point::zero() -> Point {
  { x: 0.0, y: 0.0, }
}

///|
/// Returns true if x and y are both zero.
pub fn Point::is_zero(self : Point) -> Bool {
  self.x == 0.0 && self.y == 0.0
}

///|
/// Returns true if both x and y are measurable values.
///
/// Both values are other than infinities and NaN.
pub fn Point::is_finite(self : Point) -> Bool {
  is_finite(self.x * self.y)
}

///|
/// Checks that two `Point`s are almost equal.
fn Point::almost_equal(self : Point, other : Point) -> Bool {
  !(self - other).can_normalize()
}

///|
/// Checks that two `Point`s are almost equal using the specified tolerance.
fn Point::equals_within_tolerance(
  self : Point,
  other : Point,
  tolerance : Float,
) -> Bool {
  is_nearly_zero_within_tolerance(self.x - other.x, tolerance) &&
  is_nearly_zero_within_tolerance(self.y - other.y, tolerance)
}

///|
/// Scales (fX, fY) so that length() returns one, while preserving ratio of fX
/// to fY, if possible.
///
/// If prior length is nearly zero, returns (0, 0) and false; otherwise
/// returns the scaled vector and true.
pub fn Point::normalize(self : Point) -> (Point, Bool) {
  Point::set_length_from(self.x, self.y, 1.0)
}

///|
/// Returns (x, y) scaled so length() returns one, and so that (x, y)
/// is proportional to (x, y).
///
/// If (x, y) length is nearly zero, returns (0, 0) and false.
pub fn Point::set_normalize(x : Float, y : Float) -> (Point, Bool) {
  Point::set_length_from(x, y, 1.0)
}

///|
fn Point::can_normalize(self : Point) -> Bool {
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
    Float::from_double((xx * xx + yy * yy).sqrt())
  }
}

///|
/// Scales vector so that distanceToOrigin() returns length, if possible.
///
/// If former length is nearly zero, returns (0, 0) and false.
pub fn Point::set_length(self : Point, length : Float) -> (Point, Bool) {
  Point::set_length_from(self.x, self.y, length)
}

///|
/// Returns (x, y) scaled to length, if possible.
///
/// If former length is nearly zero, returns (0, 0) and false.
pub fn Point::set_length_from(
  x : Float,
  y : Float,
  length : Float,
) -> (Point, Bool) {
  set_point_length(x, y, length)
}

///|
/// Returns the Euclidean distance from origin.
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
///
/// Vector and vec form three-dimensional vectors with z-axis value equal to
/// zero. The cross product is a three-dimensional vector with x-axis and
/// y-axis values equal to zero. The cross product z-axis component is
/// returned.
pub fn Point::cross(self : Point, other : Point) -> Float {
  self.x * other.y - self.y * other.x
}

///|
fn Point::distance_to_sqd(self : Point, pt : Point) -> Float {
  let dx = self.x - pt.x
  let dy = self.y - pt.y
  dx * dx + dy * dy
}

///|
fn Point::length_sqd(self : Point) -> Float {
  self.dot(self)
}

///|
/// Scales Point by scale.
pub fn Point::scale(self : Point, scale : Float) -> Point {
  Point::from_xy(self.x * scale, self.y * scale)
}

///|
fn Point::scaled(self : Point, scale : Float) -> Point {
  Point::from_xy(self.x * scale, self.y * scale)
}

///|
fn Point::swap_coords(self : Point) -> Point {
  { x: self.y, y: self.x, }
}

///|
fn Point::rotate_cw(self : Point) -> Point {
  let p = self.swap_coords()
  { x: -p.x, y: p.y, }
}

///|
fn Point::rotate_ccw(self : Point) -> Point {
  let p = self.swap_coords()
  { x: p.x, y: -p.y, }
}

///|
// We have to worry about 2 tricky conditions:
// 1. underflow of mag2 (compared against nearlyzero^2)
// 2. overflow of mag2 (compared w/ isfinite)
//
// If we underflow, we return false. If we overflow, we compute again using
// doubles, which is much slower (3x in a desktop test) but will not overflow.
fn set_point_length(x : Float, y : Float, length : Float) -> (Point, Bool) {
  // our mag2 step overflowed to infinity, so use doubles instead.
  // much slower, but needed when x or y are very large, other wise we
  // divide by inf. and return (0,0) vector.
  let xx = x.to_double()
  let yy = y.to_double()
  let dmag = (xx * xx + yy * yy).sqrt()
  let dscale = length.to_double() / dmag
  let x = x * Float::from_double(dscale)
  let y = y * Float::from_double(dscale)

  // check if we're not finite, or we're zero-length
  if !is_finite(x) || !is_finite(y) || (x == 0.0 && y == 0.0) {
    return (Point::zero(), false)
  }
  (Point::from_xy(x, y), true)
}

///|
pub impl Neg for Point with fn neg(self) {
  { x: -self.x, y: -self.y, }
}

///|
#deprecated("call as `Neg::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with Neg::{neg}

///|
pub impl Add for Point with fn add(self, other) {
  Point::from_xy(self.x + other.x, self.y + other.y)
}

///|
#deprecated("call as `Add::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with Add::{add}

///|
pub impl Sub for Point with fn sub(self, other) {
  Point::from_xy(self.x - other.x, self.y - other.y)
}

///|
#deprecated("call as `Sub::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with Sub::{sub}

///|
pub impl Mul for Point with fn mul(self, other) {
  Point::from_xy(self.x * other.x, self.y * other.y)
}

///|
#deprecated("call as `Mul::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Point with Mul::{mul}
