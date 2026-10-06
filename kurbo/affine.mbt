// Port of `kurbo` 0.13 `affine.rs` (the parts used by hayro).

///|
/// A 2D affine transform.
pub(all) struct Affine(FixedArray[Double]) derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Affine with @debug.Debug::{to_repr}

///|
pub impl Eq for Affine with fn equal(self, other) {
  let a = self.0
  let b = other.0
  a[0] == b[0] &&
  a[1] == b[1] &&
  a[2] == b[2] &&
  a[3] == b[3] &&
  a[4] == b[4] &&
  a[5] == b[5]
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Affine with Eq::{not_equal, equal}

///|
/// Construct an affine transform from coefficients.
///
/// The coefficients are `[a b c d e f]`, representing the matrix
/// `| a c e |`, `| b d f |`, `| 0 0 1 |`.
pub fn Affine::new(c : FixedArray[Double]) -> Affine {
  Affine([c[0], c[1], c[2], c[3], c[4], c[5]])
}

///|
/// The identity transform.
pub fn Affine::identity() -> Affine {
  Affine::scale(1.0)
}

///|
/// An affine transform representing uniform scaling.
pub fn Affine::scale(s : Double) -> Affine {
  Affine([s, 0.0, 0.0, s, 0.0, 0.0])
}

///|
/// An affine transform representing non-uniform scaling with different
/// scale values for x and y.
pub fn Affine::scale_non_uniform(s_x : Double, s_y : Double) -> Affine {
  Affine([s_x, 0.0, 0.0, s_y, 0.0, 0.0])
}

///|
/// An affine transform representing translation.
pub fn Affine::translate(x : Double, y : Double) -> Affine {
  Affine([1.0, 0.0, 0.0, 1.0, x, y])
}

///|
/// An affine transform representing a translation by a vector.
pub fn Affine::translate_vec(v : Vec2) -> Affine {
  Affine::translate(v.x, v.y)
}

///|
/// Get the coefficients of the transform.
pub fn Affine::as_coeffs(self : Affine) -> FixedArray[Double] {
  let c = self.0
  [c[0], c[1], c[2], c[3], c[4], c[5]]
}

///|
/// Compute the determinant of this transform.
pub fn Affine::determinant(self : Affine) -> Double {
  self.0[0] * self.0[3] - self.0[1] * self.0[2]
}

///|
/// Compute the inverse transform.
///
/// Produces NaN values when the determinant is zero.
pub fn Affine::inverse(self : Affine) -> Affine {
  let inv_det = 1.0 / self.determinant()
  let c = self.0
  Affine([
    inv_det * c[3],
    -inv_det * c[1],
    -inv_det * c[2],
    inv_det * c[0],
    inv_det * (c[2] * c[5] - c[3] * c[4]),
    inv_det * (c[1] * c[4] - c[0] * c[5]),
  ])
}

///|
/// Compute the bounding box of a transformed rectangle.
pub fn Affine::transform_rect_bbox(self : Affine, rect : Rect) -> Rect {
  let p00 = self.apply(Point::new(rect.x0, rect.y0))
  let p01 = self.apply(Point::new(rect.x0, rect.y1))
  let p10 = self.apply(Point::new(rect.x1, rect.y0))
  let p11 = self.apply(Point::new(rect.x1, rect.y1))
  Rect::from_points(p00, p01).union(Rect::from_points(p10, p11))
}

///|
/// Is this affine transform finite?
pub fn Affine::is_finite(self : Affine) -> Bool {
  let fin = (x : Double) => !x.is_nan() && !x.is_inf()
  fin(self.0[0]) &&
  fin(self.0[1]) &&
  fin(self.0[2]) &&
  fin(self.0[3]) &&
  fin(self.0[4]) &&
  fin(self.0[5])
}

///|
/// Return the translation component of the affine transformation.
pub fn Affine::translation(self : Affine) -> Vec2 {
  { x: self.0[4], y: self.0[5], }
}

///|
/// `Affine * Point`.
pub fn Affine::apply(self : Affine, other : Point) -> Point {
  let c = self.0
  Point::new(
    c[0] * other.x + c[2] * other.y + c[4],
    c[1] * other.x + c[3] * other.y + c[5],
  )
}

///|
/// `Affine * Affine`.
pub impl Mul for Affine with fn mul(self, other) {
  let s = self.0
  let o = other.0
  Affine([
    s[0] * o[0] + s[2] * o[1],
    s[1] * o[0] + s[3] * o[1],
    s[0] * o[2] + s[2] * o[3],
    s[1] * o[2] + s[3] * o[3],
    s[0] * o[4] + s[2] * o[5] + s[4],
    s[1] * o[4] + s[3] * o[5] + s[5],
  ])
}

///|
#deprecated("call as `Mul::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Affine with Mul::{mul}

///|
/// Pre-scale (`self * Affine::scale(scale)`).
pub fn Affine::pre_scale(self : Affine, scale : Double) -> Affine {
  self * Affine::scale(scale)
}

///|
/// Pre-translate (`self * Affine::translate(trans)`).
pub fn Affine::pre_translate(self : Affine, trans : Vec2) -> Affine {
  self * Affine::translate_vec(trans)
}

///|
/// Post-translate (`Affine::translate(trans) * self`).
pub fn Affine::then_translate(self : Affine, trans : Vec2) -> Affine {
  let c = self.as_coeffs()
  c[4] += trans.x
  c[5] += trans.y
  Affine(c)
}

///|
/// Post-scale (`Affine::scale(scale) * self`).
pub fn Affine::then_scale(self : Affine, scale : Double) -> Affine {
  Affine::scale(scale) * self
}

///|
pub impl Default for Affine with fn default() {
  Affine::identity()
}

///|
pub extend Affine with Default::{default}
