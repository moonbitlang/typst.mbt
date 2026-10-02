// Port of `typst-library/src/layout/size.rs`.
//
// Upstream `Size` is a type alias for `Axes<Abs>`; here the methods are
// defined on `Axes[Abs]` (`Size` is the corresponding type alias).

///|
/// A size in 2D.
pub type Size = Axes[Abs]

///|
/// The zero size (upstream `Size::zero`).
pub fn Axes::zero_size() -> Axes[Abs] {
  { x: Abs::zero(), y: Abs::zero(), }
}

///|
/// Whether the other size fits into this one (smaller width and height).
pub fn Axes::fits(self : Axes[Abs], other : Axes[Abs]) -> Bool {
  self.x.fits(other.x) && self.y.fits(other.y)
}

///|
/// Convert to a point.
pub fn Axes::to_point(self : Axes[Abs]) -> Point {
  Point::new(self.x, self.y)
}

///|
/// Converts to a ratio of width to height.
pub fn Axes::aspect_ratio(self : Axes[Abs]) -> Ratio {
  Ratio::new(self.x.ratio_to(self.y))
}

///|
/// Whether both components are zero (upstream `Numeric::is_zero`).
pub fn Axes::is_zero_size(self : Axes[Abs]) -> Bool {
  self.x == Abs::zero() && self.y == Abs::zero()
}

///|
/// Whether both components are finite (upstream `Numeric::is_finite`).
pub fn Axes::is_finite_size(self : Axes[Abs]) -> Bool {
  self.x.is_finite() && self.y.is_finite()
}

///|
/// Component-wise addition (upstream `Size + Size`).
pub fn Axes::add_size(self : Axes[Abs], other : Axes[Abs]) -> Axes[Abs] {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
/// Component-wise subtraction (upstream `Size - Size`).
pub fn Axes::sub_size(self : Axes[Abs], other : Axes[Abs]) -> Axes[Abs] {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
/// Component-wise negation (upstream `-Size`).
pub fn Axes::neg_size(self : Axes[Abs]) -> Axes[Abs] {
  { x: -self.x, y: -self.y, }
}

///|
/// Multiply both components by a factor (upstream `Size * f64`).
pub fn Axes::times(self : Axes[Abs], factor : Double) -> Axes[Abs] {
  { x: self.x.times(factor), y: self.y.times(factor), }
}

///|
/// Divide both components by a factor (upstream `Size / f64`).
pub fn Axes::div_by(self : Axes[Abs], factor : Double) -> Axes[Abs] {
  { x: self.x.div_by(factor), y: self.y.div_by(factor), }
}
