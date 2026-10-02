// Port of `typst-library/src/layout/point.rs`.

///|
/// A point in 2D.
pub(all) struct Point {
  /// The x coordinate.
  x : Abs
  /// The y coordinate.
  y : Abs
} derive(Eq, Hash, Default)

///|
/// The origin point.
pub fn Point::zero() -> Point {
  { x: Abs::zero(), y: Abs::zero(), }
}

///|
/// Create a new point from x and y coordinates.
pub fn Point::new(x : Abs, y : Abs) -> Point {
  { x, y, }
}

///|
/// Create an instance with two equal components.
pub fn Point::splat(value : Abs) -> Point {
  { x: value, y: value, }
}

///|
/// Create a new point with y set to zero.
pub fn Point::with_x(x : Abs) -> Point {
  { x, y: Abs::zero(), }
}

///|
/// Create a new point with x set to zero.
pub fn Point::with_y(y : Abs) -> Point {
  { x: Abs::zero(), y, }
}

///|
/// The component-wise minimum of this and another point.
pub fn Point::min(self : Point, other : Point) -> Point {
  { x: self.x.min(other.x), y: self.y.min(other.y), }
}

///|
/// The component-wise maximum of this and another point.
pub fn Point::max(self : Point, other : Point) -> Point {
  { x: self.x.max(other.x), y: self.y.max(other.y), }
}

///|
/// Maps the point with the given function.
pub fn Point::map(self : Point, f : (Abs) -> Abs) -> Point {
  { x: f(self.x), y: f(self.y), }
}

///|
/// The distance between this point and the origin.
pub fn Point::hypot(self : Point) -> Abs {
  // The `sqrt` function is defined by IEEE-754 and thus deterministic.
  let x = self.x.to_raw()
  let y = self.y.to_raw()
  Abs::raw((x * x + y * y).sqrt())
}

///|
/// The point divided by its distance to the origin.
pub fn Point::normalized(self : Point) -> Point {
  self.div_by(self.hypot().to_raw())
}

///|
/// Rotate the point 90 degrees counter-clockwise.
pub fn Point::rot90ccw(self : Point) -> Point {
  { x: self.y, y: -self.x, }
}

///|
/// Transform the point with the given transformation.
///
/// In the event that one of the coordinates is infinite, the result will be
/// zero.
pub fn Point::transform(self : Point, ts : Transform) -> Point {
  Point::new(
    ts.sx.of(self.x) + ts.kx.of(self.y) + ts.tx,
    ts.ky.of(self.x) + ts.sy.of(self.y) + ts.ty,
  )
}

///|
/// Transforms the point with the given transformation, without accounting
/// for infinite values.
pub fn Point::transform_inf(self : Point, ts : Transform) -> Point {
  Point::new(
    self.x.times(ts.sx.get()) + self.y.times(ts.kx.get()) + ts.tx,
    self.x.times(ts.ky.get()) + self.y.times(ts.sy.get()) + ts.ty,
  )
}

///|
/// Convert to a size.
pub fn Point::to_size(self : Point) -> Axes[Abs] {
  Axes::new(self.x, self.y)
}

///|
/// Whether both coordinates are zero (upstream `Numeric::is_zero`).
pub fn Point::is_zero(self : Point) -> Bool {
  self == Point::zero()
}

///|
/// Whether both coordinates are finite.
pub fn Point::is_finite(self : Point) -> Bool {
  self.x.is_finite() && self.y.is_finite()
}

///|
/// The component for the given axis (upstream `Get<Axis>`).
pub fn Point::get(self : Point, axis : Axis) -> Abs {
  match axis {
    X => self.x
    Y => self.y
  }
}

///|
/// The point with the component for the given axis replaced.
pub fn Point::with_axis(self : Point, axis : Axis, v : Abs) -> Point {
  match axis {
    X => { ..self, x: v, }
    Y => { ..self, y: v, }
  }
}

///|
/// Multiply both coordinates by a factor.
pub fn Point::times(self : Point, factor : Double) -> Point {
  { x: self.x.times(factor), y: self.y.times(factor), }
}

///|
/// Divide both coordinates by a factor.
pub fn Point::div_by(self : Point, factor : Double) -> Point {
  { x: self.x.div_by(factor), y: self.y.div_by(factor), }
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
pub impl Neg for Point with fn neg(self) {
  { x: -self.x, y: -self.y, }
}

///|
/// Upstream `Debug for Point`.
pub impl Show for Point with fn output(self, logger) {
  logger.write_string(
    "Point(\{rust_debug_f64(self.x.to_pt())}pt, \{rust_debug_f64(self.y.to_pt())}pt)",
  )
}

///|
pub impl Fingerprint for Point with fn fingerprint(self, state) {
  state.write_f64(self.x.to_pt())
  state.write_f64(self.y.to_pt())
}
