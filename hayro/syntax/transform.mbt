// Port of `hayro-syntax/src/transform.rs`: 2D affine transformations.

///|
/// A 2D affine transform.
pub(all) struct Transform(FixedArray[Double]) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Transform with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Transform with @debug.Debug::{to_repr}

///|
pub fn Transform::new(c : FixedArray[Double]) -> Transform {
  Transform(c)
}

///|
/// The identity transform.
pub fn Transform::identity() -> Transform {
  Transform::scale(1.0)
}

///|
pub fn Transform::scale(s : Double) -> Transform {
  Transform([s, 0.0, 0.0, s, 0.0, 0.0])
}

///|
pub fn Transform::rotate_cw_90() -> Transform {
  Transform([0.0, 1.0, -1.0, 0.0, 0.0, 0.0])
}

///|
pub fn Transform::rotate_ccw_90() -> Transform {
  Transform([0.0, -1.0, 1.0, 0.0, 0.0, 0.0])
}

///|
pub fn Transform::translate(x : Double, y : Double) -> Transform {
  Transform([1.0, 0.0, 0.0, 1.0, x, y])
}

///|
/// Get the coefficients of the transform.
pub fn Transform::as_coeffs(self : Transform) -> FixedArray[Double] {
  self.0
}

///|
pub impl Mul for Transform with fn mul(self, other) {
  let a = self.0
  let b = other.0
  Transform([
    a[0] * b[0] + a[2] * b[1],
    a[1] * b[0] + a[3] * b[1],
    a[0] * b[2] + a[2] * b[3],
    a[1] * b[2] + a[3] * b[3],
    a[0] * b[4] + a[2] * b[5] + a[4],
    a[1] * b[4] + a[3] * b[5] + a[5],
  ])
}

///|
#deprecated("call as `Mul::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Transform with Mul::{mul}
