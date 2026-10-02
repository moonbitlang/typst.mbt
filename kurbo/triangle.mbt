// Port of `kurbo` 0.13 `triangle.rs` (the parts used by hayro).

///|
/// Triangle
pub(all) struct Triangle {
  /// vertex a.
  a : Point
  /// vertex b.
  b : Point
  /// vertex c.
  c : Point
} derive(Eq, Debug)

///|
/// A new [`Triangle`] from three vertices ([`Point`]s).
pub fn Triangle::new(a : Point, b : Point, c : Point) -> Triangle {
  { a, b, c, }
}

///|
/// A new [`Triangle`] from three float vertex coordinates.
pub fn Triangle::from_coords(
  a : (Double, Double),
  b : (Double, Double),
  c : (Double, Double),
) -> Triangle {
  { a: Point::new(a.0, a.1), b: Point::new(b.0, b.1), c: Point::new(c.0, c.1), }
}

///|
/// The centroid of the [`Triangle`].
pub fn Triangle::centroid(self : Triangle) -> Point {
  (self.a.to_vec2() + self.b.to_vec2() + self.c.to_vec2())
  .scale(1.0 / 3.0)
  .to_point()
}

///|
/// The area of the [`Triangle`].
pub fn Triangle::area(self : Triangle) -> Double {
  0.5 * self.b.sub(self.a).cross(self.c.sub(self.a))
}

///|
/// Rust's `f64::signum`.
fn f64_signum(x : Double) -> Double {
  if x.is_nan() {
    x
  } else if x.reinterpret_as_uint64() >> 63 != 0 {
    -1.0
  } else {
    1.0
  }
}

///|
/// The winding number of a point (`Shape::winding`).
pub fn Triangle::winding(self : Triangle, pt : Point) -> Int {
  let s0 = f64_signum(self.b.sub(self.a).cross(pt.sub(self.a)))
  let s1 = f64_signum(self.c.sub(self.b).cross(pt.sub(self.b)))
  let s2 = f64_signum(self.a.sub(self.c).cross(pt.sub(self.c)))
  if s0 == s1 && s1 == s2 {
    s0.to_int()
  } else {
    0
  }
}

///|
/// Returns `true` if the point is inside the triangle (`Shape::contains`).
pub fn Triangle::contains(self : Triangle, pt : Point) -> Bool {
  self.winding(pt) != 0
}

///|
/// The smallest rectangle that encloses the triangle (`Shape::bounding_box`).
pub fn Triangle::bounding_box(self : Triangle) -> Rect {
  Rect::new(
    f64_min(self.a.x, f64_min(self.b.x, self.c.x)),
    f64_min(self.a.y, f64_min(self.b.y, self.c.y)),
    f64_max(self.a.x, f64_max(self.b.x, self.c.x)),
    f64_max(self.a.y, f64_max(self.b.y, self.c.y)),
  )
}
