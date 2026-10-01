// Stand-ins for upstream `Decimal` methods (decimal.rs) used by the ports of
// calc.rs, int.rs and float.rs. They are replaced by the real port of
// decimal.rs (duplicates are dropped when merging it).

///|
/// Upstream `Decimal::abs`.
pub fn Decimal::abs(self : Decimal) -> Decimal {
  self
}

///|
/// Upstream `Decimal::floor`.
pub fn Decimal::floor(self : Decimal) -> Decimal {
  self
}

///|
/// Upstream `Decimal::ceil`.
pub fn Decimal::ceil(self : Decimal) -> Decimal {
  self
}

///|
/// Upstream `Decimal::trunc`.
pub fn Decimal::trunc(self : Decimal) -> Decimal {
  self
}

///|
/// Upstream `Decimal::fract`.
pub fn Decimal::fract(self : Decimal) -> Decimal {
  self
}

///|
/// Upstream `Decimal::round`.
pub fn Decimal::round(self : Decimal, digits : Int) -> Decimal? {
  ignore(self)
  ignore(digits)
  None
}

///|
/// Upstream `Decimal::checked_div_euclid`.
pub fn Decimal::checked_div_euclid(self : Decimal, other : Decimal) -> Decimal? {
  ignore(self)
  ignore(other)
  None
}

///|
/// Upstream `Decimal::checked_rem_euclid`.
pub fn Decimal::checked_rem_euclid(self : Decimal, other : Decimal) -> Decimal? {
  ignore(self)
  ignore(other)
  None
}

///|
/// Upstream `Decimal::checked_rem`.
pub fn Decimal::checked_rem(self : Decimal, other : Decimal) -> Decimal? {
  ignore(self)
  ignore(other)
  None
}

///|
/// Upstream `Decimal::checked_powi`.
pub fn Decimal::checked_powi(self : Decimal, other : Int64) -> Decimal? {
  ignore(self)
  ignore(other)
  None
}

///|
/// Upstream `TryFrom<Decimal> for i64`.
pub fn Decimal::to_i64(self : Decimal) -> Int64? {
  ignore(self)
  None
}

///|
/// Upstream `TryFrom<Decimal> for f64`.
pub fn Decimal::to_f64(self : Decimal) -> Double? {
  ignore(self)
  None
}
