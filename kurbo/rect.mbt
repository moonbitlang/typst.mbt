// Port of `kurbo` 0.13 `rect.rs` (the parts used by hayro).

///|
/// A rectangle.
pub(all) struct Rect {
  /// The minimum x coordinate (left edge).
  x0 : Double
  /// The minimum y coordinate (top edge in y-down spaces).
  y0 : Double
  /// The maximum x coordinate (right edge).
  x1 : Double
  /// The maximum y coordinate (bottom edge in y-down spaces).
  y1 : Double
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with @debug.Debug::{to_repr}

///|
/// The empty rectangle at the origin.
pub let rect_zero : Rect = { x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0, }

///|
/// A new rectangle from minimum and maximum coordinates.
pub fn Rect::new(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Rect {
  { x0, y0, x1, y1, }
}

///|
/// A new rectangle from two points.
///
/// The result will have non-negative width and height.
pub fn Rect::from_points(p0 : Point, p1 : Point) -> Rect {
  Rect::new(p0.x, p0.y, p1.x, p1.y).abs()
}

///|
/// The width of the rectangle.
pub fn Rect::width(self : Rect) -> Double {
  self.x1 - self.x0
}

///|
/// The height of the rectangle.
pub fn Rect::height(self : Rect) -> Double {
  self.y1 - self.y0
}

///|
/// Returns the minimum value for the x-coordinate of the rectangle.
pub fn Rect::min_x(self : Rect) -> Double {
  f64_min(self.x0, self.x1)
}

///|
/// Returns the maximum value for the x-coordinate of the rectangle.
pub fn Rect::max_x(self : Rect) -> Double {
  f64_max(self.x0, self.x1)
}

///|
/// Returns the minimum value for the y-coordinate of the rectangle.
pub fn Rect::min_y(self : Rect) -> Double {
  f64_min(self.y0, self.y1)
}

///|
/// Returns the maximum value for the y-coordinate of the rectangle.
pub fn Rect::max_y(self : Rect) -> Double {
  f64_max(self.y0, self.y1)
}

///|
/// The area of the rectangle.
pub fn Rect::area(self : Rect) -> Double {
  self.width() * self.height()
}

///|
/// Whether this rectangle has zero area.
pub fn Rect::is_zero_area(self : Rect) -> Bool {
  self.area() == 0.0
}

///|
/// Take absolute value of width and height.
pub fn Rect::abs(self : Rect) -> Rect {
  Rect::new(
    f64_min(self.x0, self.x1),
    f64_min(self.y0, self.y1),
    f64_max(self.x0, self.x1),
    f64_max(self.y0, self.y1),
  )
}

///|
/// The smallest rectangle enclosing two rectangles.
pub fn Rect::union(self : Rect, other : Rect) -> Rect {
  Rect::new(
    f64_min(self.x0, other.x0),
    f64_min(self.y0, other.y0),
    f64_max(self.x1, other.x1),
    f64_max(self.y1, other.y1),
  )
}

///|
/// Compute the union with one point.
pub fn Rect::union_pt(self : Rect, pt : Point) -> Rect {
  Rect::new(
    f64_min(self.x0, pt.x),
    f64_min(self.y0, pt.y),
    f64_max(self.x1, pt.x),
    f64_max(self.y1, pt.y),
  )
}

///|
/// The intersection of two rectangles.
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect {
  let x0 = f64_max(self.x0, other.x0)
  let y0 = f64_max(self.y0, other.y0)
  let x1 = f64_min(self.x1, other.x1)
  let y1 = f64_min(self.y1, other.y1)
  Rect::new(x0, y0, f64_max(x1, x0), f64_max(y1, y0))
}

///|
/// Expand a rectangle by a constant amount in both directions.
pub fn Rect::inflate(self : Rect, width : Double, height : Double) -> Rect {
  Rect::new(
    self.x0 - width,
    self.y0 - height,
    self.x1 + width,
    self.y1 + height,
  )
}

///|
/// The path elements of the rectangle (`Shape::path_elements`).
pub fn Rect::path_elements(self : Rect) -> Array[PathEl] {
  [
    MoveTo(Point::new(self.x0, self.y0)),
    LineTo(Point::new(self.x1, self.y0)),
    LineTo(Point::new(self.x1, self.y1)),
    LineTo(Point::new(self.x0, self.y1)),
    ClosePath,
  ]
}

///|
/// Convert to a Bézier path (`Shape::to_path`; the tolerance is unused).
pub fn Rect::to_path(self : Rect, _tolerance : Double) -> BezPath {
  BezPath::from_vec(self.path_elements())
}

///|
/// The smallest rectangle that encloses the shape (`Shape::bounding_box`).
pub fn Rect::bounding_box(self : Rect) -> Rect {
  self.abs()
}

///|
/// Is this rectangle finite?
pub fn Rect::is_finite(self : Rect) -> Bool {
  let fin = (x : Double) => !x.is_nan() && !x.is_inf()
  fin(self.x0) && fin(self.x1) && fin(self.y0) && fin(self.y1)
}

///|
/// Returns `true` if `point` lies within `self`.
pub fn Rect::contains(self : Rect, point : Point) -> Bool {
  point.x >= self.x0 &&
  point.x < self.x1 &&
  point.y >= self.y0 &&
  point.y < self.y1
}

///|
pub impl Default for Rect with fn default() {
  rect_zero
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Default::{default}
