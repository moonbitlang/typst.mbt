// Port of `typst-library/src/layout/ratio.rs`.

///|
/// A ratio of a whole.
pub(all) struct Ratio(Scalar) derive(Default, Eq, Compare, Hash)

///|
pub extend Ratio with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub fn Ratio::zero() -> Ratio {
  Ratio(Scalar(0.0))
}

///|
pub fn Ratio::one() -> Ratio {
  Ratio(Scalar(1.0))
}

///|
pub fn Ratio::new(ratio : Double) -> Ratio {
  Ratio(Scalar::new(ratio))
}

///|
pub fn Ratio::get(self : Ratio) -> Double {
  self.0.0
}

///|
pub fn Ratio::is_zero(self : Ratio) -> Bool {
  self.0.0 == 0.0
}

///|
pub fn Ratio::is_one(self : Ratio) -> Bool {
  self.0.0 == 1.0
}

///|
pub fn Ratio::abs(self : Ratio) -> Ratio {
  Ratio::new(self.get().abs())
}

///|
/// Return the ratio of the given `whole`.
pub fn[T : Numeric] Ratio::of(self : Ratio, whole : T) -> T {
  let resolved = whole.scale(self.get())
  if resolved.is_finite() {
    resolved
  } else {
    T::zero()
  }
}

///|
/// The reciprocal of the ratio.
pub fn Ratio::recip(self : Ratio) -> Ratio {
  Ratio::new(1.0 / self.get())
}

///|
pub fn Ratio::mul_ratio(self : Ratio, other : Ratio) -> Ratio {
  Ratio(self.0 * other.0)
}

///|
pub fn Ratio::repr(self : Ratio) -> String {
  format_float_with_unit(self.get() * 100.0, "%")
}
