// Port of `typst-library/src/layout/em.rs`.

///|
/// A length that is relative to the font size.
///
/// `1em` is the same as the font size.
pub(all) struct Em(Scalar) derive(Default, Eq, Compare, Hash)

///|
pub extend Em with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub fn Em::zero() -> Em {
  Em(Scalar(0.0))
}

///|
pub fn Em::one() -> Em {
  Em(Scalar(1.0))
}

///|
pub fn Em::new(em : Double) -> Em {
  Em(Scalar::new(em))
}

///|
/// Create an em length from font units at the given units per em.
pub fn Em::from_units(units : Double, units_per_em : Double) -> Em {
  Em(Scalar::new(units / units_per_em))
}

///|
/// Convert an absolute length at the given font size to an em length.
pub fn Em::from_abs(length : Abs, font_size : Abs) -> Em {
  let result = length.ratio_to(font_size)
  if !result.is_inf() && !result.is_nan() {
    Em(Scalar::new(result))
  } else {
    Em::zero()
  }
}

///|
/// Convert a length at the given font size to an em length.
pub fn Em::from_length(length : Length, font_size : Abs) -> Em {
  length.em + Em::from_abs(length.abs, font_size)
}

///|
/// The number of em units.
pub fn Em::get(self : Em) -> Double {
  self.0.0
}

///|
/// The absolute value of this em length.
pub fn Em::abs(self : Em) -> Em {
  Em::new(self.get().abs())
}

///|
/// Convert to an absolute length at the given font size.
pub fn Em::at(self : Em, font_size : Abs) -> Abs {
  let resolved = font_size.times(self.get())
  if resolved.is_finite() {
    resolved
  } else {
    Abs::zero()
  }
}

///|
pub fn Em::repr(self : Em) -> String {
  format_float_with_unit(self.get(), "em")
}

///|
pub fn Abs::is_finite(self : Abs) -> Bool {
  let x = self.to_raw()
  !x.is_inf() && !x.is_nan()
}

///|
pub fn Abs::is_zero(self : Abs) -> Bool {
  self.to_raw() == 0.0
}

///|
pub fn Em::is_zero(self : Em) -> Bool {
  self.get() == 0.0
}

///|
pub impl IntoValue for Em with fn into_value(self) {
  Length(Length::from_em(self))
}
