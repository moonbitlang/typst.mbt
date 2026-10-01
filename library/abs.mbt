// Port of `typst-library/src/layout/abs.rs`.

///|
/// An absolute length.
pub(all) struct Abs(Scalar) derive(Default, Eq, Compare, Hash)

///|
pub(all) enum AbsUnit {
  Pt
  Mm
  Cm
  In
} derive(Eq, Hash, Debug)

///|
let abs_eps : Double = 1.0e-4

///|
fn AbsUnit::raw_scale(self : AbsUnit) -> Double {
  match self {
    Pt => 127.0
    Mm => 360.0
    Cm => 3600.0
    In => 9144.0
  }
}

///|
pub fn Abs::zero() -> Abs {
  Abs(Scalar(0.0))
}

///|
pub fn Abs::inf() -> Abs {
  Abs(Scalar(@double.infinity))
}

///|
pub fn Abs::raw(raw : Double) -> Abs {
  Abs(Scalar::new(raw))
}

///|
pub fn Abs::with_unit(val : Double, unit : AbsUnit) -> Abs {
  Abs(Scalar::new(val * unit.raw_scale()))
}

///|
pub fn Abs::pt(pt : Double) -> Abs {
  Abs::with_unit(pt, Pt)
}

///|
pub fn Abs::mm(mm : Double) -> Abs {
  Abs::with_unit(mm, Mm)
}

///|
pub fn Abs::cm(cm : Double) -> Abs {
  Abs::with_unit(cm, Cm)
}

///|
pub fn Abs::inches(inches : Double) -> Abs {
  Abs::with_unit(inches, In)
}

///|
pub fn Abs::to_raw(self : Abs) -> Double {
  self.0.0
}

///|
pub fn Abs::to_unit(self : Abs, unit : AbsUnit) -> Double {
  self.to_raw() / unit.raw_scale()
}

///|
pub fn Abs::to_pt(self : Abs) -> Double {
  self.to_unit(Pt)
}

///|
pub fn Abs::to_mm(self : Abs) -> Double {
  self.to_unit(Mm)
}

///|
pub fn Abs::to_cm(self : Abs) -> Double {
  self.to_unit(Cm)
}

///|
pub fn Abs::to_inches(self : Abs) -> Double {
  self.to_unit(In)
}

///|
pub fn Abs::abs(self : Abs) -> Abs {
  Abs::raw(self.to_raw().abs())
}

///|
pub fn Abs::min(self : Abs, other : Abs) -> Abs {
  if self.to_raw() <= other.to_raw() {
    self
  } else {
    other
  }
}

///|
pub fn Abs::max(self : Abs, other : Abs) -> Abs {
  if self.to_raw() >= other.to_raw() {
    self
  } else {
    other
  }
}

///|
/// Whether the other absolute length fits into this one (i.e. is smaller).
/// Allows for a bit of slack.
pub fn Abs::fits(self : Abs, other : Abs) -> Bool {
  self.to_raw() + abs_eps >= other.to_raw()
}

///|
/// Compares two absolute lengths for whether they are approximately equal.
pub fn Abs::approx_eq(self : Abs, other : Abs) -> Bool {
  self == other || (self.to_raw() - other.to_raw()).abs() < abs_eps
}

///|
/// Whether the size is close to zero or negative.
pub fn Abs::approx_empty(self : Abs) -> Bool {
  self.to_raw() <= abs_eps
}

///|
pub fn Abs::signum(self : Abs) -> Double {
  let x = self.to_raw()
  if x.is_nan() {
    x
  } else if x < 0.0 || (x == 0.0 && 1.0 / x < 0.0) {
    -1.0
  } else {
    1.0
  }
}

///|
pub impl Numeric for Abs with fn div_scale(self, factor) {
  self.div_by(factor)
}

///|
pub fn Abs::times(self : Abs, factor : Double) -> Abs {
  Abs(Scalar::new(self.to_raw() * factor))
}

///|
pub fn Abs::div_by(self : Abs, factor : Double) -> Abs {
  Abs(Scalar::new(self.to_raw() / factor))
}

///|
pub fn Abs::ratio_to(self : Abs, other : Abs) -> Double {
  self.to_raw() / other.to_raw()
}

///|
pub impl Add for Abs with fn add(self, other) {
  Abs(self.0 + other.0)
}

///|
pub impl Sub for Abs with fn sub(self, other) {
  Abs(self.0 - other.0)
}

///|
pub impl Neg for Abs with fn neg(self) {
  Abs(-self.0)
}

///|
pub impl Mod for Abs with fn mod(self, other) {
  Abs(Scalar::new(rust_rem(self.to_raw(), other.to_raw())))
}

///|
pub impl Numeric for Abs with fn zero() {
  Abs::zero()
}

///|
pub impl Numeric for Abs with fn is_finite(self) {
  !self.to_raw().is_inf() && !self.to_raw().is_nan()
}

///|
pub impl Numeric for Abs with fn scale(self, factor) {
  self.times(factor)
}

///|
pub fn Abs::repr(self : Abs) -> String {
  format_float_with_unit(self.to_pt(), "pt")
}
