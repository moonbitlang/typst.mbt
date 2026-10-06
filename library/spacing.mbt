// Port of the value-level parts of `typst-library/src/layout/spacing.rs`.

///|
/// Kinds of spacing.
pub(all) enum Spacing {
  /// Spacing specified in absolute terms and relative to the parent's size.
  Rel(Rel[Length])
  /// Spacing specified as a fraction of the remaining free space in the
  /// parent.
  Fr(Fr)
} derive(Eq, Hash)

///|
/// Spacing from a length (upstream `From<Length> for Spacing`).
pub fn Spacing::from_length(length : Length) -> Spacing {
  Rel(Rel::new(Ratio::zero(), length))
}

///|
/// Spacing from an em length (upstream `From<Em> for Spacing`).
pub fn Spacing::from_em(em : Em) -> Spacing {
  Spacing::from_length(Length::from_em(em))
}

///|
/// Whether this is fractional spacing.
pub fn Spacing::is_fractional(self : Spacing) -> Bool {
  self is Fr(_)
}

///|
/// Whether the spacing is actually no spacing.
pub fn Spacing::is_zero(self : Spacing) -> Bool {
  match self {
    Rel(rel) => rel.is_zero()
    Fr(fr) => fr.get() == 0.0
  }
}

///|
fn spacing_input() -> CastInfo {
  CastInfo::Type(Type::relative()).union_with(CastInfo::Type(Type::fraction()))
}

///|
pub impl Reflect for Spacing with fn input() {
  spacing_input()
}

///|
pub impl Reflect for Spacing with fn output() {
  spacing_input()
}

///|
pub impl Reflect for Spacing with fn castable(value) {
  value is (Relative(_) | Length(_) | Ratio(_) | Fraction(_))
}

///|
pub extend Spacing with Reflect::{output, input, castable}

///|
pub impl IntoValue for Spacing with fn into_value(self) {
  match self {
    Rel(rel) =>
      if rel.rel.is_zero() {
        Length(rel.abs)
      } else if rel.abs.is_zero() {
        Ratio(rel.rel)
      } else {
        Relative(rel)
      }
    Fr(fr) => Fraction(fr)
  }
}

///|
pub extend Spacing with IntoValue::{into_value}

///|
pub impl FromValue for Spacing with fn from_value(value) {
  match value {
    Relative(_) | Length(_) | Ratio(_) => Rel(Rel::from_value(value))
    Fraction(fr) => Fr(fr)
    _ => raise HintedError(spacing_input().error(value))
  }
}

///|
pub extend Spacing with FromValue::{from_value}

///|
/// How to size something along an axis (upstream `Sizing`,
/// `layout/container.rs`).
pub(all) enum Sizing {
  /// A track that fits its item's contents.
  Auto
  /// A size specified in absolute terms and relative to the parent's size.
  Rel(Rel[Length])
  /// A size specified as a fraction of the remaining free space in the
  /// parent.
  Fr(Fr)
} derive(Eq, Hash)

///|
pub impl Default for Sizing with fn default() {
  Auto
}

///|
pub extend Sizing with Default::{default}

///|
/// Whether this is an automatic size.
pub fn Sizing::is_auto(self : Sizing) -> Bool {
  self is Auto
}

///|
/// Whether this is fractional sizing.
pub fn Sizing::is_fractional(self : Sizing) -> Bool {
  self is Fr(_)
}

///|
fn sizing_input() -> CastInfo {
  CastInfo::Type(Type::auto())
  .union_with(CastInfo::Type(Type::relative()))
  .union_with(CastInfo::Type(Type::fraction()))
}

///|
pub impl Reflect for Sizing with fn input() {
  sizing_input()
}

///|
pub impl Reflect for Sizing with fn output() {
  sizing_input()
}

///|
pub impl Reflect for Sizing with fn castable(value) {
  value is (Value::Auto | Relative(_) | Length(_) | Ratio(_) | Fraction(_))
}

///|
pub extend Sizing with Reflect::{output, input, castable}

///|
pub impl IntoValue for Sizing with fn into_value(self) {
  match self {
    Auto => Value::Auto
    Rel(rel) => Relative(rel)
    Fr(fr) => Fraction(fr)
  }
}

///|
pub extend Sizing with IntoValue::{into_value}

///|
pub impl FromValue for Sizing with fn from_value(value) {
  match value {
    Value::Auto => Auto
    Relative(_) | Length(_) | Ratio(_) => Rel(Rel::from_value(value))
    Fraction(fr) => Fr(fr)
    _ => raise HintedError(sizing_input().error(value))
  }
}

///|
pub extend Sizing with FromValue::{from_value}
