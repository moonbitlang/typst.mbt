// Port of `typst-library/src/layout/fr.rs`.

///|
/// Defines how the remaining space in a layout is distributed.
pub(all) struct Fr(Scalar) derive(Default, Eq, Compare, Hash)

///|
pub extend Fr with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub fn Fr::zero() -> Fr {
  Fr(Scalar(0.0))
}

///|
pub fn Fr::one() -> Fr {
  Fr(Scalar(1.0))
}

///|
pub fn Fr::new(ratio : Double) -> Fr {
  Fr(Scalar::new(ratio))
}

///|
pub fn Fr::get(self : Fr) -> Double {
  self.0.0
}

///|
pub fn Fr::abs(self : Fr) -> Fr {
  Fr::new(self.get().abs())
}

///|
/// Determine this fraction's share in the remaining space.
pub fn Fr::share(self : Fr, total : Fr, remaining : Abs) -> Abs {
  let ratio = self.ratio_to(total)
  if !ratio.is_inf() && !ratio.is_nan() && remaining.is_finite() {
    remaining.times(ratio).max(Abs::zero())
  } else {
    Abs::zero()
  }
}

///|
pub fn Fr::repr(self : Fr) -> String {
  format_float_with_unit(self.get(), "fr")
}
