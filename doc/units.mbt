// Units (docs/edsl-design.md, section 6.3).

///|
/// Lengths and ratios: what Typst writes as `11pt`, `2em`, `50%` and their
/// sums. One type for the engine's `Length`, `Rel<Length>` and `Ratio`:
/// which of them a value is follows from Typst's own arithmetic, and
/// whether a field accepts it from the field's cast.
pub(all) enum Length {
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
pub impl @builtin.Sub for Length with fn sub(self, other) {
  Diff(self, other)
}

///|
pub impl Neg for Length with fn neg(self) {
  Neg(self)
}

///|
/// `self * factor`.
pub fn Length::scale(self : Length, factor : Double) -> Length {
  Scaled(self, factor)
}

///|
pub impl ToValue for Length with fn to_value(self) {
  match self {
    Pt(v) => Value::of(VNumeric(v, @library.NumericUnit::Pt))
    Mm(v) => Value::of(VNumeric(v, @library.NumericUnit::Mm))
    Cm(v) => Value::of(VNumeric(v, @library.NumericUnit::Cm))
    In(v) => Value::of(VNumeric(v, @library.NumericUnit::In))
    Em(v) => Value::of(VNumeric(v, @library.NumericUnit::Em))
    Pct(v) => Value::of(VNumeric(v, @library.NumericUnit::Percent))
    Sum(a, b) => Value::of(VAdd(a.to_value(), b.to_value()))
    Diff(a, b) => Value::of(VSub(a.to_value(), b.to_value()))
    Neg(a) => Value::of(VNeg(a.to_value()))
    Scaled(a, k) => Value::of(VMul(a.to_value(), Value::of(VFloat(k))))
  }
}

///|
/// The engine's `Spacing`: a length/ratio or a fraction of the remaining
/// space.
pub(all) enum Spacing {
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
    Fr(v) => Value::of(VNumeric(v, @library.NumericUnit::Fr))
    Pt(v) => Value::of(VNumeric(v, @library.NumericUnit::Pt))
    Mm(v) => Value::of(VNumeric(v, @library.NumericUnit::Mm))
    Cm(v) => Value::of(VNumeric(v, @library.NumericUnit::Cm))
    In(v) => Value::of(VNumeric(v, @library.NumericUnit::In))
    Em(v) => Value::of(VNumeric(v, @library.NumericUnit::Em))
    Pct(v) => Value::of(VNumeric(v, @library.NumericUnit::Percent))
    Rel(length) => length.to_value()
  }
}

///|
/// The engine's `Sizing` (also the size of a grid track): `auto`, a
/// length/ratio or a fraction.
pub(all) enum Sizing {
  Auto
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
pub impl ToValue for Sizing with fn to_value(self) {
  match self {
    Auto => Value::auto()
    Fr(v) => Value::of(VNumeric(v, @library.NumericUnit::Fr))
    Pt(v) => Value::of(VNumeric(v, @library.NumericUnit::Pt))
    Mm(v) => Value::of(VNumeric(v, @library.NumericUnit::Mm))
    Cm(v) => Value::of(VNumeric(v, @library.NumericUnit::Cm))
    In(v) => Value::of(VNumeric(v, @library.NumericUnit::In))
    Em(v) => Value::of(VNumeric(v, @library.NumericUnit::Em))
    Pct(v) => Value::of(VNumeric(v, @library.NumericUnit::Percent))
    Rel(length) => length.to_value()
  }
}

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
