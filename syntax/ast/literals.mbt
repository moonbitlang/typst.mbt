// Identifiers and literals.

///|
/// Get the identifier.
pub fn Ident::get(self : Ident) -> String {
  self.node.leaf_text()
}

///|
/// Get the identifier as a string slice.
pub fn Ident::as_str(self : Ident) -> String {
  self.get()
}

///|
/// Get the boolean value.
pub fn BoolLit::get(self : BoolLit) -> Bool {
  self.node.leaf_text() == "true"
}

///|
pub using @syntax {type NonDecimalBase}

///|
/// Get the integer value.
///
/// We return a result because we still want to highlight and treat invalid
/// values like `9223372036854775808` as integers in the IDE.
pub fn IntLit::get(self : IntLit) -> Result[Int64, IntLiteralError] {
  let (base, digits) = strip_base_prefix(self.node.leaf_text())
  let radix = match base {
    Some(non_decimal) => non_decimal.get()
    None => 10
  }
  match i64_from_str_radix(digits, radix) {
    Ok(v) => Ok(v)
    // Only non-decimal integers should encounter this error kind.
    Err(InvalidDigit) => Err(InvalidDigit(base.unwrap_or(Hex), digits))
    // All other errors are actually positive overflow.
    Err(PosOverflow | NegOverflow | Empty) =>
      Err(
        PosOverflow(
          base~,
          max_plus_one=u64_from_str_radix(digits, radix) is Ok(v) &&
            v == 0x8000_0000_0000_0000UL,
        ),
      )
  }
}

///|
/// Possible errors for integer literals in the AST. Other integer errors are
/// handled in the lexer.
pub(all) enum IntLiteralError {
  PosOverflow(base~ : NonDecimalBase?, max_plus_one~ : Bool)
  InvalidDigit(NonDecimalBase, String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IntLiteralError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IntLiteralError with @debug.Debug::{to_repr}

///|
/// Try to strip a base prefix (`0x`, `0o`, `0b`) from the integer literal
/// and return the base and the remaining digits.
///
/// Upstream: `NonDecimalBase::strip_prefix`.
fn strip_base_prefix(text : String) -> (NonDecimalBase?, String) {
  let rest = if text.length() >= 2 {
    text.unsafe_substring(start=2, end=text.length())
  } else {
    ""
  }
  if text.has_prefix("0x") {
    (Some(Hex), rest)
  } else if text.has_prefix("0o") {
    (Some(Octal), rest)
  } else if text.has_prefix("0b") {
    (Some(Binary), rest)
  } else {
    (None, text)
  }
}

///|
/// Get the floating-point value.
pub fn FloatLit::get(self : FloatLit) -> Double {
  rust_parse_f64(self.node.leaf_text()).unwrap_or(0.0)
}

///|
/// Get the numeric value and unit.
pub fn Numeric::get(self : Numeric) -> (Double, NumericUnit) {
  let text = self.node.leaf_text()
  let mut split = text.length()
  while split > 0 {
    let c = text.code_unit_at(split - 1).to_int()
    guard (c >= 'a' && c <= 'z') || c == '%' else { break }
    split -= 1
  }
  let value = rust_parse_f64(text.unsafe_substring(start=0, end=split)).unwrap_or(
    0.0,
  )
  let unit = match text.unsafe_substring(start=split, end=text.length()) {
    "pt" => Pt
    "mm" => Mm
    "cm" => Cm
    "in" => In
    "deg" => Deg
    "rad" => Rad
    "em" => Em
    "fr" => Fr
    "%" => Percent
    _ => Percent
  }
  (value, unit)
}

///|
/// Unit of a numeric value.
pub(all) enum NumericUnit {
  /// Points.
  Pt
  /// Millimeters.
  Mm
  /// Centimeters.
  Cm
  /// Inches.
  In
  /// Radians.
  Rad
  /// Degrees.
  Deg
  /// Font-relative: `1em` is the same as the font size.
  Em
  /// Fractions: `fr`.
  Fr
  /// Percentage: `%`.
  Percent
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumericUnit with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumericUnit with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NumericUnit with @debug.Debug::{to_repr}

///|
/// Get the string value with resolved escape sequences.
pub fn Str::get(self : Str) -> String {
  let text = self.node.leaf_text()
  // Upstream would panic on text shorter than its two quotes (only possible
  // for placeholders).
  if text.length() < 2 {
    return ""
  }
  @syntax.unescape_str_literal(text)
}
