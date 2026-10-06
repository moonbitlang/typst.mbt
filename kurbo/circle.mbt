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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Circle with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Circle with @debug.Debug::{to_repr}

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
