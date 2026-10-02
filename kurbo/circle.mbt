// Port of `kurbo` 0.13 `circle.rs` (the parts used by hayro).

///|
/// A circle.
pub(all) struct Circle {
  /// The center.
  center : Point
  /// The radius.
  radius : Double
} derive(Eq, Debug)

///|
/// A new circle from center and radius.
pub fn Circle::new(center : Point, radius : Double) -> Circle {
  { center, radius, }
}

///|
/// The winding number of a point (`Shape::winding`).
pub fn Circle::winding(self : Circle, pt : Point) -> Int {
  if pt.sub(self.center).hypot2() < self.radius * self.radius {
    1
  } else {
    0
  }
}

///|
/// Returns `true` if the point is inside the circle (`Shape::contains`).
pub fn Circle::contains(self : Circle, pt : Point) -> Bool {
  self.winding(pt) != 0
}
