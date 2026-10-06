// Port of `typst-library/src/foundations/decimal.rs`.

///|
/// A fixed-point decimal number type.
///
/// This type should be used for precise arithmetic operations on numbers
/// represented in base 10. A typical use case is representing currency.
pub struct Decimal(RustDecimal)

///|
/// Hashes all parts explicitly so that the scale is also considered (upstream
/// hashes `serialize()`): `123.314 == 123.31400`, but their hashes differ.
pub impl Hash for Decimal with fn hash_combine(self, hasher) {
  self.0.hash_combine(hasher)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Decimal with Hash::{hash, hash_combine}

///|
pub impl Eq for Decimal with fn equal(self, other) {
  self.0.cmp(other.0) == 0
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Decimal with Eq::{not_equal, equal}

///|
pub impl Compare for Decimal with fn compare(self, other) {
  self.0.cmp(other.0)
}

///|
pub extend Decimal with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub let decimal_zero : Decimal = Decimal::Decimal(rd_zero)

///|
pub let decimal_one : Decimal = Decimal::Decimal(rd_one)

///|
/// Whether this decimal value is zero.
pub fn Decimal::is_zero(self : Decimal) -> Bool {
  self.0.is_zero()
}

///|
/// Whether this decimal value is negative.
pub fn Decimal::is_negative(self : Decimal) -> Bool {
  self.0.negative
}

///|
/// Whether this decimal has fractional part equal to zero (is an integer).
pub fn Decimal::is_integer(self : Decimal) -> Bool {
  self.0.is_integer()
}

///|
/// Computes the absolute value of this decimal.
pub fn Decimal::abs(self : Decimal) -> Decimal {
  Decimal::Decimal(self.0.abs())
}

///|
/// Computes the largest integer less than or equal to this decimal.
///
/// A decimal is returned as this may not be within `i64`'s range of values.
pub fn Decimal::floor(self : Decimal) -> Decimal {
  Decimal::Decimal(self.0.floor())
}

///|
/// Computes the smallest integer greater than or equal to this decimal.
///
/// A decimal is returned as this may not be within `i64`'s range of values.
pub fn Decimal::ceil(self : Decimal) -> Decimal {
  Decimal::Decimal(self.0.ceil())
}

///|
/// Returns the integer part of this decimal.
pub fn Decimal::trunc(self : Decimal) -> Decimal {
  Decimal::Decimal(self.0.trunc())
}

///|
/// Returns the fractional part of this decimal (with the integer part set to
/// zero).
pub fn Decimal::fract(self : Decimal) -> Decimal {
  Decimal::Decimal(self.0.fract())
}

///|
/// Rounds this decimal up to the specified amount of digits with the
/// traditional rounding rules, using the "midpoint away from zero" strategy
/// (6.5 -> 7, -6.5 -> -7).
///
/// If given a negative amount of digits, rounds to integer digits instead
/// with the same rounding strategy. For example, rounding to -3 digits will
/// turn 34567.89 into 35000.00 and -34567.89 into -35000.00.
///
/// Note that this can return `None` when using negative digits where the
/// rounded number would overflow the available range for decimals.
pub fn Decimal::round(self : Decimal, digits : Int) -> Decimal? {
  // Positive digits can be handled by just rounding with rust_decimal.
  if digits >= 0 {
    return Some(Decimal::Decimal(self.0.round_dp_away_from_zero(digits)))
  }

  // We received negative digits, so we round to integer digits.
  let num = self.0
  let old_scale = num.scale
  let digits = -digits.to_int64()
  let scaled : RustDecimal? = if old_scale.to_int64() + digits >
    rd_max_scale.to_int64() {
    None
  } else {
    // Same as dividing by 10^digits.
    num.set_scale(old_scale + digits.to_int())
  }
  let ten_to_digits = RustDecimal::from_i64(10L).checked_powi(digits)
  guard (scaled, ten_to_digits) is (Some(num), Some(ten_to_digits)) else {
    // Scaling more than any possible amount of integer digits.
    return Some(
      Decimal::Decimal(RustDecimal::raw(big_zero, self.is_negative(), 0)),
    )
  }

  // Round to this integer digit.
  let num = num.round_dp_away_from_zero(0)

  // Multiply by 10^digits again, which can overflow and fail.
  num.checked_mul(ten_to_digits).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to add two decimals.
///
/// Returns `None` on overflow or underflow.
pub fn Decimal::checked_add(self : Decimal, other : Decimal) -> Decimal? {
  self.0.checked_add(other.0).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to subtract a decimal from another.
///
/// Returns `None` on overflow or underflow.
pub fn Decimal::checked_sub(self : Decimal, other : Decimal) -> Decimal? {
  self.0.checked_sub(other.0).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to multiply two decimals.
///
/// Returns `None` on overflow or underflow.
pub fn Decimal::checked_mul(self : Decimal, other : Decimal) -> Decimal? {
  self.0.checked_mul(other.0).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to divide two decimals.
///
/// Returns `None` if `other` is zero, as well as on overflow or underflow.
pub fn Decimal::checked_div(self : Decimal, other : Decimal) -> Decimal? {
  self.0.checked_div(other.0).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to obtain the quotient of Euclidean division between two
/// decimals. Implemented similarly to [`f64::div_euclid`].
///
/// The returned quotient is truncated and adjusted if the remainder was
/// negative.
///
/// Returns `None` if `other` is zero, as well as on overflow or underflow.
pub fn Decimal::checked_div_euclid(self : Decimal, other : Decimal) -> Decimal? {
  guard self.0.checked_div(other.0) is Some(q) else { return None }
  let q = q.trunc()
  if self.0.checked_rem(other.0) is Some(r) && r.negative {
    return if !other.0.negative {
      q.checked_sub(rd_one).map(x => Decimal::Decimal(x))
    } else {
      q.checked_add(rd_one).map(x => Decimal::Decimal(x))
    }
  }
  Some(Decimal::Decimal(q))
}

///|
/// Attempts to obtain the remainder of Euclidean division between two
/// decimals. Implemented similarly to [`f64::rem_euclid`].
///
/// The returned decimal `r` is non-negative within the range
/// `0.0 <= r < other.abs()`.
///
/// Returns `None` if `other` is zero, as well as on overflow or underflow.
pub fn Decimal::checked_rem_euclid(self : Decimal, other : Decimal) -> Decimal? {
  guard self.0.checked_rem(other.0) is Some(r) else { return None }
  if r.negative {
    r.checked_add(other.0.abs()).map(x => Decimal::Decimal(x))
  } else {
    Some(Decimal::Decimal(r))
  }
}

///|
/// Attempts to calculate the remainder of the division of two decimals.
///
/// Returns `None` if `other` is zero, as well as on overflow or underflow.
pub fn Decimal::checked_rem(self : Decimal, other : Decimal) -> Decimal? {
  self.0.checked_rem(other.0).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to take one decimal to the power of an integer.
///
/// Returns `None` for invalid operands, as well as on overflow or underflow.
pub fn Decimal::checked_powi(self : Decimal, other : Int64) -> Decimal? {
  self.0.checked_powi(other).map(x => Decimal::Decimal(x))
}

///|
/// Restrict a decimal to an interval (Rust's `Ord::clamp`).
pub fn Decimal::clamp(self : Decimal, min : Decimal, max : Decimal) -> Decimal {
  if min > max {
    abort("assertion failed: min <= max")
  }
  if self < min {
    min
  } else if self > max {
    max
  } else {
    self
  }
}

///|
/// Parse a decimal from a string exactly (upstream `FromStr for Decimal`).
pub fn Decimal::from_str(s : String) -> Decimal? {
  RustDecimal::from_str_exact(s).map(x => Decimal::Decimal(x))
}

///|
/// Conversion from an integer (upstream `From<i64> for Decimal`).
pub fn Decimal::from_int(i : Int64) -> Decimal {
  Decimal::Decimal(RustDecimal::from_i64(i))
}

///|
/// Attempts to convert a float to a decimal (upstream
/// `TryFrom<f64> for Decimal`).
///
/// This can fail if the float is infinite or NaN, or otherwise cannot be
/// represented by a decimal number.
pub fn Decimal::try_from_f64(value : Double) -> Decimal? {
  RustDecimal::from_f64_retain(value).map(x => Decimal::Decimal(x))
}

///|
/// Attempts to convert a decimal to a float (upstream
/// `TryFrom<Decimal> for f64`, which never fails).
pub fn Decimal::to_f64(self : Decimal) -> Double? {
  Some(self.0.to_f64())
}

///|
/// Attempts to convert a decimal to an integer (upstream
/// `TryFrom<Decimal> for i64`): truncates the fractional part and fails on
/// overflow or underflow.
pub fn Decimal::to_i64(self : Decimal) -> Int64? {
  self.0.to_i64()
}

///|
/// Upstream `Display for Decimal`: uses the Unicode minus sign.
pub fn Decimal::to_string(self : Decimal) -> String {
  if self.0.negative {
    minus_sign + self.0.abs_to_string()
  } else {
    self.0.abs_to_string()
  }
}

///|
pub impl Show for Decimal with fn output(self, logger) {
  logger.write_string(self.to_string())
}
// No `extend` for this impl, nothing is left to name: `to_string` is a regular
// method of the type, and the `extend` of `Reflect` makes `output` one.

///|
/// Upstream `Repr for Decimal`.
pub fn Decimal::repr(self : Decimal) -> String {
  "decimal(" + repr_str(self.0.to_string()) + ")"
}

///|
/// Upstream `Neg for Decimal`.
pub fn Decimal::neg(self : Decimal) -> Decimal {
  Decimal::Decimal(self.0.neg())
}

///|
/// Converts a value to a `decimal` (upstream `Decimal::construct`).
fn impl_decimal_construct(
  engine : Engine,
  value_ : @syntax.Spanned[ToDecimal],
) -> Decimal raise SourceError {
  match value_.v {
    Str(str) =>
      match Decimal::from_str(str.replace_all(old=minus_sign, new="-")) {
        Some(d) => d
        None => bail_at(value_.span, "invalid decimal: \{str}")
      }
    Int(int) => Decimal::from_int(int)
    Float(float) => {
      warn_on_float_literal(engine, value_.span)
      match Decimal::try_from_f64(float) {
        Some(d) => d
        None =>
          bail_at(
            value_.span,
            "float is not a valid decimal: \{format_float(float, true, "")}",
          )
      }
    }
    Decimal(decimal) => decimal
  }
}

///|
/// Emits a warning when a decimal is constructed from a float literal.
fn warn_on_float_literal(engine : Engine, span : @syntax.Span) -> Unit {
  guard span.id() is Some(id) else { return }
  let source = engine.world.source(id) catch { _ => return }
  guard source.find(span) is Some(node) else { return }
  if node.kind() == @syntax.SyntaxKind::Float {
    engine.sink.warn(
      SourceDiagnostic::warning_at(
        span, "creating a decimal using imprecise float literal",
      ).with_hint(
        "use a string in the decimal constructor to avoid loss of precision: `decimal(\{repr_str(node.get().leaf_text())})`",
      ),
    )
  }
}

///|
/// A value that can be cast to a decimal.
pub(all) enum ToDecimal {
  /// A decimal to be converted to itself.
  Decimal(Decimal)
  /// A string with the decimal's representation.
  Str(String)
  /// An integer to be converted to the equivalent decimal.
  Int(Int64)
  /// A float to be converted to the equivalent decimal.
  Float(Double)
}

///|
pub impl Reflect for ToDecimal with fn input() {
  Union([
    Type(Type::decimal()),
    Type(Type::int()),
    Type(Type::bool()),
    Type(Type::float()),
    Type(Type::str()),
  ])
}

///|
pub impl Reflect for ToDecimal with fn output() {
  Union([
    Type(Type::decimal()),
    Type(Type::int()),
    Type(Type::bool()),
    Type(Type::float()),
    Type(Type::str()),
  ])
}

///|
pub impl Reflect for ToDecimal with fn castable(v) {
  v is (Decimal(_) | Int(_) | Bool(_) | Float(_) | Str(_) | Symbol(_))
}

///|
pub extend ToDecimal with Reflect::{output, input, castable}

///|
pub impl FromValue for ToDecimal with fn from_value(v) {
  match v {
    Decimal(d) => Decimal(d)
    Int(i) => Int(i)
    Bool(b) => Int(if b { 1L } else { 0L })
    Float(f) => Float(f)
    Str(_) | Symbol(_) => Str(v.cast())
    v => raise HintedError(ToDecimal::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ToDecimal with FromValue::{from_value}

///|
pub impl Reflect for Decimal with fn input() {
  Type(Type::decimal())
}

///|
pub impl Reflect for Decimal with fn output() {
  Type(Type::decimal())
}

///|
pub impl Reflect for Decimal with fn castable(v) {
  v is Decimal(_)
}

///|
pub extend Decimal with Reflect::{output, input, castable}

///|
pub impl IntoValue for Decimal with fn into_value(self) {
  Decimal(self)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Decimal with IntoValue::{into_value}

///|
pub impl FromValue for Decimal with fn from_value(v) {
  match v {
    Decimal(d) => d
    v => raise HintedError(Decimal::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Decimal with FromValue::{from_value}
