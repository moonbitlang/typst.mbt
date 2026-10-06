// Units (docs/edsl-design.md, section 6.3).

///|
/// Lengths and ratios: what Typst writes as `11pt`, `2em`, `50%` and their
/// sums. One type for the engine's `Length`, `Rel<Length>` and `Ratio`:
/// which of them a value is follows from Typst's own arithmetic, and
/// whether a field accepts it from the field's cast.
pub(all) enum Length {
  /// Explicit `auto`, where the field accepts it.
  Auto
  /// Explicit `none`, where the field accepts it.
  None
  Pt(Double)
  Mm(Double)
  Cm(Double)
  In(Double)
  /// Relative to the font size.
  Em(Double)
  /// A ratio: `Pct(50)` is `50%`.
  Pct(Double)
  /// `a + b`.
  Sum(Length, Length)
  /// `a - b`.
  Diff(Length, Length)
  /// `-a`.
  Neg(Length)
  /// `a * factor`.
  Scaled(Length, Double)
}

///|
pub impl Add for Length with fn add(self, other) {
  Sum(self, other)
}

///|
#deprecated("call as `Add::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with Add::{add}

///|
pub impl @builtin.Sub for Length with fn sub(self, other) {
  Diff(self, other)
}

///|
#deprecated("call as `Sub::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with @builtin.Sub::{sub}

///|
pub impl Neg for Length with fn neg(self) {
  Neg(self)
}

///|
#deprecated("call as `Neg::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with Neg::{neg}

///|
/// `self * factor`.
pub fn Length::scale(self : Length, factor : Double) -> Length {
  Scaled(self, factor)
}

///|
/// The length as a track or box size: `Rel(self)` of [Sizing]. For a helper
/// that computes a `Length` and passes it where a `Sizing` is expected
/// (`columns=[width.sizing(), Fr(1)]`).
pub fn Length::sizing(self : Length) -> Sizing {
  Rel(self)
}

///|
/// The length as a spacing: `Rel(self)` of [Spacing] (`V(gap.spacing())`).
pub fn Length::spacing(self : Length) -> Spacing {
  Rel(self)
}

///|
pub impl ToValue for Length with fn to_value(self) {
  match self {
    Auto => Value::auto()
    None => Value::none()
    Pt(v) => Value::of(VNumeric(v, @library.NumericUnit::Pt))
    Mm(v) => Value::of(VNumeric(v, @library.NumericUnit::Mm))
    Cm(v) => Value::of(VNumeric(v, @library.NumericUnit::Cm))
    In(v) => Value::of(VNumeric(v, @library.NumericUnit::In))
    Em(v) => Value::of(VNumeric(v, @library.NumericUnit::Em))
    Pct(v) => Value::of(VNumeric(v, @library.NumericUnit::Percent))
    Sum(a, b) => Value::of(VAdd(ToValue::to_value(a), ToValue::to_value(b)))
    Diff(a, b) => Value::of(VSub(ToValue::to_value(a), ToValue::to_value(b)))
    Neg(a) => Value::of(VNeg(ToValue::to_value(a)))
    Scaled(a, k) => Value::of(VMul(ToValue::to_value(a), Value::of(VFloat(k))))
  }
}

///|
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with ToValue::{to_value}

///|
/// The engine's `Spacing`: a length/ratio or a fraction of the remaining
/// space.
pub(all) enum Spacing {
  /// Explicit `auto`, where the field accepts it.
  Auto
  /// Explicit `none`, where the field accepts it.
  None
  Fr(Double)
  Pt(Double)
  Mm(Double)
  Cm(Double)
  In(Double)
  Em(Double)
  Pct(Double)
  /// Any composed length (`Rel(Pt(10) + Pct(50))`).
  Rel(Length)
}

///|
pub impl ToValue for Spacing with fn to_value(self) {
  match self {
    Auto => Value::auto()
    None => Value::none()
    Fr(v) => Value::of(VNumeric(v, @library.NumericUnit::Fr))
    Pt(v) => Value::of(VNumeric(v, @library.NumericUnit::Pt))
    Mm(v) => Value::of(VNumeric(v, @library.NumericUnit::Mm))
    Cm(v) => Value::of(VNumeric(v, @library.NumericUnit::Cm))
    In(v) => Value::of(VNumeric(v, @library.NumericUnit::In))
    Em(v) => Value::of(VNumeric(v, @library.NumericUnit::Em))
    Pct(v) => Value::of(VNumeric(v, @library.NumericUnit::Percent))
    Rel(length) => ToValue::to_value(length)
  }
}

///|
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Spacing with ToValue::{to_value}

///|
/// The engine's `Sizing` (also the size of a grid track): `auto`, a
/// length/ratio or a fraction.
pub(all) enum Sizing {
  Auto
  /// Explicit `none`, where the field accepts it.
  None
  Fr(Double)
  Pt(Double)
  Mm(Double)
  Cm(Double)
  In(Double)
  Em(Double)
  Pct(Double)
  /// Any composed length (`Rel(Pt(10) + Pct(50))`).
  Rel(Length)
}

///|
/// `count` tracks of the same size: `columns=Sizing::repeat(5)` is Typst's
/// `columns: 5` (five `auto` columns).
pub fn Sizing::repeat(count : Int, size? : Sizing = Auto) -> Array[Sizing] {
  Array::make(count, size)
}

///|
pub impl ToValue for Sizing with fn to_value(self) {
  match self {
    Auto => Value::auto()
    None => Value::none()
    Fr(v) => Value::of(VNumeric(v, @library.NumericUnit::Fr))
    Pt(v) => Value::of(VNumeric(v, @library.NumericUnit::Pt))
    Mm(v) => Value::of(VNumeric(v, @library.NumericUnit::Mm))
    Cm(v) => Value::of(VNumeric(v, @library.NumericUnit::Cm))
    In(v) => Value::of(VNumeric(v, @library.NumericUnit::In))
    Em(v) => Value::of(VNumeric(v, @library.NumericUnit::Em))
    Pct(v) => Value::of(VNumeric(v, @library.NumericUnit::Percent))
    Rel(length) => ToValue::to_value(length)
  }
}

///|
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Sizing with ToValue::{to_value}

///|
pub(all) enum Angle {
  Deg(Double)
  Rad(Double)
}

///|
pub impl ToValue for Angle with fn to_value(self) {
  match self {
    Deg(v) => Value::of(VNumeric(v, @library.NumericUnit::Deg))
    Rad(v) => Value::of(VNumeric(v, @library.NumericUnit::Rad))
  }
}

///|
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Angle with ToValue::{to_value}
