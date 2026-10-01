// Generated arithmetic for scalar newtypes.

///|
pub impl Add for Em with fn add(self, other) {
  Em(self.0 + other.0)
}

///|
pub impl Sub for Em with fn sub(self, other) {
  Em(self.0 - other.0)
}

///|
pub impl Neg for Em with fn neg(self) {
  Em(-self.0)
}

///|
pub impl Numeric for Em with fn zero() {
  Em(Scalar(0.0))
}

///|
pub impl Numeric for Em with fn is_finite(self) {
  let x = self.0.0
  !x.is_inf() && !x.is_nan()
}

///|
pub impl Numeric for Em with fn scale(self, factor) {
  Em(Scalar::new(self.0.0 * factor))
}

///|
pub impl Numeric for Em with fn div_scale(self, factor) {
  Em(Scalar::new(self.0.0 / factor))
}

///|
pub fn Em::times(self : Em, factor : Double) -> Em {
  Em(Scalar::new(self.0.0 * factor))
}

///|
pub fn Em::div_by(self : Em, factor : Double) -> Em {
  Em(Scalar::new(self.0.0 / factor))
}

///|
pub fn Em::ratio_to(self : Em, other : Em) -> Double {
  self.0.0 / other.0.0
}

///|
pub impl Add for Angle with fn add(self, other) {
  Angle(self.0 + other.0)
}

///|
pub impl Sub for Angle with fn sub(self, other) {
  Angle(self.0 - other.0)
}

///|
pub impl Neg for Angle with fn neg(self) {
  Angle(-self.0)
}

///|
pub impl Numeric for Angle with fn zero() {
  Angle(Scalar(0.0))
}

///|
pub impl Numeric for Angle with fn is_finite(self) {
  let x = self.0.0
  !x.is_inf() && !x.is_nan()
}

///|
pub impl Numeric for Angle with fn scale(self, factor) {
  Angle(Scalar::new(self.0.0 * factor))
}

///|
pub impl Numeric for Angle with fn div_scale(self, factor) {
  Angle(Scalar::new(self.0.0 / factor))
}

///|
pub fn Angle::times(self : Angle, factor : Double) -> Angle {
  Angle(Scalar::new(self.0.0 * factor))
}

///|
pub fn Angle::div_by(self : Angle, factor : Double) -> Angle {
  Angle(Scalar::new(self.0.0 / factor))
}

///|
pub fn Angle::ratio_to(self : Angle, other : Angle) -> Double {
  self.0.0 / other.0.0
}

///|
pub impl Add for Ratio with fn add(self, other) {
  Ratio(self.0 + other.0)
}

///|
pub impl Sub for Ratio with fn sub(self, other) {
  Ratio(self.0 - other.0)
}

///|
pub impl Neg for Ratio with fn neg(self) {
  Ratio(-self.0)
}

///|
pub impl Numeric for Ratio with fn zero() {
  Ratio(Scalar(0.0))
}

///|
pub impl Numeric for Ratio with fn is_finite(self) {
  let x = self.0.0
  !x.is_inf() && !x.is_nan()
}

///|
pub impl Numeric for Ratio with fn scale(self, factor) {
  Ratio(Scalar::new(self.0.0 * factor))
}

///|
pub impl Numeric for Ratio with fn div_scale(self, factor) {
  Ratio(Scalar::new(self.0.0 / factor))
}

///|
pub fn Ratio::times(self : Ratio, factor : Double) -> Ratio {
  Ratio(Scalar::new(self.0.0 * factor))
}

///|
pub fn Ratio::div_by(self : Ratio, factor : Double) -> Ratio {
  Ratio(Scalar::new(self.0.0 / factor))
}

///|
pub fn Ratio::ratio_to(self : Ratio, other : Ratio) -> Double {
  self.0.0 / other.0.0
}

///|
pub impl Add for Fr with fn add(self, other) {
  Fr(self.0 + other.0)
}

///|
pub impl Sub for Fr with fn sub(self, other) {
  Fr(self.0 - other.0)
}

///|
pub impl Neg for Fr with fn neg(self) {
  Fr(-self.0)
}

///|
pub impl Numeric for Fr with fn zero() {
  Fr(Scalar(0.0))
}

///|
pub impl Numeric for Fr with fn is_finite(self) {
  let x = self.0.0
  !x.is_inf() && !x.is_nan()
}

///|
pub impl Numeric for Fr with fn scale(self, factor) {
  Fr(Scalar::new(self.0.0 * factor))
}

///|
pub impl Numeric for Fr with fn div_scale(self, factor) {
  Fr(Scalar::new(self.0.0 / factor))
}

///|
pub fn Fr::times(self : Fr, factor : Double) -> Fr {
  Fr(Scalar::new(self.0.0 * factor))
}

///|
pub fn Fr::div_by(self : Fr, factor : Double) -> Fr {
  Fr(Scalar::new(self.0.0 / factor))
}

///|
pub fn Fr::ratio_to(self : Fr, other : Fr) -> Double {
  self.0.0 / other.0.0
}
