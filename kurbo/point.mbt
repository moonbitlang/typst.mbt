// Port of the parts of `kurbo` 0.13 (`point.rs`, `vec2.rs`) used by hayro.

///|
/// Rust's `f64::min`: if one argument is NaN, the other is returned.
pub fn f64_min(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else {
    b
  }
}

///|
/// Rust's `f64::max`: if one argument is NaN, the other is returned.
pub fn f64_max(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// A 2D point.
pub(all) struct Point {
  /// The x coordinate.
  x : Double
  /// The y coordinate.
  y : Double
} derive(Eq, Debug)

///|
/// The point (0, 0).
pub let point_zero : Point = { x: 0.0, y: 0.0, }

///|
/// Create a new `Point` with the provided `x` and `y` coordinates.
pub fn Point::new(x : Double, y : Double) -> Point {
  { x, y, }
}

///|
/// Convert this point into a `Vec2`.
pub fn Point::to_vec2(self : Point) -> Vec2 {
  { x: self.x, y: self.y, }
}

///|
/// Linearly interpolate between two points.
pub fn Point::lerp(self : Point, other : Point, t : Double) -> Point {
  self.to_vec2().lerp(other.to_vec2(), t).to_point()
}

///|
/// Determine the midpoint of two points.
pub fn Point::midpoint(self : Point, other : Point) -> Point {
  Point::new(0.5 * (self.x + other.x), 0.5 * (self.y + other.y))
}

///|
/// Is this point finite?
pub fn Point::is_finite(self : Point) -> Bool {
  !self.x.is_nan() && !self.x.is_inf() && !self.y.is_nan() && !self.y.is_inf()
}

///|
/// `Point + Vec2`.
pub fn Point::add_vec(self : Point, v : Vec2) -> Point {
  Point::new(self.x + v.x, self.y + v.y)
}

///|
/// `Point - Vec2`.
pub fn Point::sub_vec(self : Point, v : Vec2) -> Point {
  Point::new(self.x - v.x, self.y - v.y)
}

///|
/// `Point - Point`.
pub fn Point::sub(self : Point, other : Point) -> Vec2 {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
/// A 2D vector.
pub(all) struct Vec2 {
  /// The x-coordinate.
  x : Double
  /// The y-coordinate.
  y : Double
} derive(Eq, Debug)

///|
/// The vector (0, 0).
pub let vec2_zero : Vec2 = { x: 0.0, y: 0.0, }

///|
/// Create a new vector.
pub fn Vec2::new(x : Double, y : Double) -> Vec2 {
  { x, y, }
}

///|
/// Convert this vector into a `Point`.
pub fn Vec2::to_point(self : Vec2) -> Point {
  { x: self.x, y: self.y, }
}

///|
/// Magnitude squared of vector.
pub fn Vec2::hypot2(self : Vec2) -> Double {
  self.x * self.x + self.y * self.y
}

///|
/// Magnitude of vector.
pub fn Vec2::hypot(self : Vec2) -> Double {
  self.hypot2().sqrt()
}

///|
/// Dot product of two vectors.
pub fn Vec2::dot(self : Vec2, other : Vec2) -> Double {
  self.x * other.x + self.y * other.y
}

///|
/// Cross product of two vectors.
pub fn Vec2::cross(self : Vec2, other : Vec2) -> Double {
  self.x * other.y - self.y * other.x
}

///|
/// Linearly interpolate between two vectors.
pub fn Vec2::lerp(self : Vec2, other : Vec2, t : Double) -> Vec2 {
  self + (other - self).scale(t)
}

///|
/// `Vec2 * f64`.
pub fn Vec2::scale(self : Vec2, s : Double) -> Vec2 {
  { x: self.x * s, y: self.y * s, }
}

///|
pub impl Add for Vec2 with fn add(self, other) {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
pub impl Sub for Vec2 with fn sub(self, other) {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
pub impl Neg for Vec2 with fn neg(self) {
  { x: -self.x, y: -self.y, }
}
