// Numbers as text. Every function here follows one rounding contract, the
// one of JavaScript's `Number.prototype.toFixed`:
//
//   The result is the decimal number with the requested count of decimals
//   that is nearest to the exact value of the double. If two are equally
//   near, it is the one farther from zero (half away from zero).
//
// "The exact value of the double" is not the number in the source text:
// `1.005` is the double 1.00499999999999989341858963598497211933135986328125,
// so `fixed(1.005, 2)` is "1.00", while `fixed(0.125, 2)` is "0.13" and
// `fixed(2.5, 0)` is "3" (0.125 and 2.5 are doubles, and real ties). The
// rounding is done on the exact decimal expansion (`decimal.mbt`), never by
// `x * 10^digits + 0.5`, which is wrong whenever that product is not exact.
//
// Shared rules:
// - Sign: "-" exactly when `x < 0`. So a negative value that rounds to zero
//   keeps its sign (`fixed(-0.001, 2)` is "-0.00", as in JavaScript and C),
//   and negative zero has none (`fixed(-0.0, 2)` is "0.00").
// - `digits` is clamped to 0..=100 (below 0 is 0, above 100 is 100).
// - Not a number is "NaN", the infinities are "∞" and "-∞" (U+221E).
// - No exponent notation, at any magnitude: `fixed(1.0e21, 0)` is
//   "1000000000000000000000" (JavaScript switches to "1e+21" there).
// - Nothing here panics or raises, for any argument.

///|
/// The largest count of decimals (JavaScript's limit for `toFixed`).
const MAX_DIGITS : Int = 100

///|
fn clamp_digits(digits : Int) -> Int {
  if digits < 0 {
    0
  } else if digits > MAX_DIGITS {
    MAX_DIGITS
  } else {
    digits
  }
}

///|
/// "NaN", "∞" or "-∞" for a value that is not finite.
fn non_finite(x : Double) -> String? {
  if x.is_nan() {
    Some("NaN")
  } else if x.is_pos_inf() {
    Some("∞")
  } else if x.is_neg_inf() {
    Some("-∞")
  } else {
    None
  }
}

///|
/// Writes the integer with the decimal digits `n` (most significant first,
/// none for zero) as a number whose last `digits` digits are decimals, with
/// `sep` between groups of three digits of the integer part.
fn write_number(
  buf : StringBuilder,
  n : Array[Int],
  digits : Int,
  sep : String,
) -> Unit {
  let whole = n.length() - digits
  if whole <= 0 {
    buf.write_char('0')
  } else {
    for i in 0..<whole {
      if i > 0 && (whole - i) % 3 == 0 {
        buf.write_string(sep)
      }
      buf.write_char((n[i] + 48).unsafe_to_char())
    }
  }
  if digits > 0 {
    buf.write_char('.')
    for i in whole..<n.length() {
      // `i < 0`: a zero between the point and the first digit.
      let digit = if i < 0 { 0 } else { n[i] }
      buf.write_char((digit + 48).unsafe_to_char())
    }
  }
}

///|
/// `x` with exactly `digits` decimals: the nearest such decimal number to
/// the exact value of `x`, half away from zero.
///
/// This is JavaScript's `x.toFixed(digits)`, character for character, for
/// every finite `x` with `|x| < 1e21` and `digits` in 0..=100. Outside of
/// that it differs on purpose: no exponent notation for larger values (all
/// their digits are written), "∞"/"-∞" for the infinities, and `digits` is
/// clamped to 0..=100 where JavaScript throws.
///
/// - `fixed(1.005, 2)` is "1.00": the double 1.005 is below 1.005.
/// - `fixed(0.5, 0)` is "1", `fixed(1.5, 0)` "2", `fixed(2.5, 0)` "3",
///   `fixed(-0.5, 0)` "-1": real ties go away from zero.
/// - `fixed(-0.001, 2)` is "-0.00" and `fixed(-0.0, 2)` is "0.00": the sign
///   is written exactly when `x < 0`.
///
/// With `trim=true` the zeros at the end of the decimals are dropped, and
/// the point if no decimal is left: `fixed(2.50, 2, trim=true)` is "2.5",
/// `fixed(3.0, 2, trim=true)` is "3" (an axis label). `digits` is then the
/// largest count of decimals.
pub fn fixed(x : Double, digits : Int, trim~ : Bool = false) -> String {
  if non_finite(x) is Some(s) {
    return s
  }
  let mut digits = clamp_digits(digits)
  let n = Decimal::of(x).rounded(digits)
  if trim {
    // The last decimal is the last digit of `n` (a zero if `n` has none).
    while digits > 0 && (n.length() == 0 || n[n.length() - 1] == 0) {
      n.pop() |> ignore
      digits -= 1
    }
  }
  let buf = StringBuilder()
  if x < 0.0 {
    buf.write_char('-')
  }
  write_number(buf, n, digits, "")
  buf.to_string()
}

///|
/// `fixed(x, digits)` with `sep` between groups of three digits of the
/// integer part, counted from the point: `grouped(1234567.891, digits=2)`
/// is "1,234,567.89", `grouped(-1234.5)` is "-1,235", `grouped(999.5)` is
/// "1,000". The decimals are not grouped, and the point is always ".".
///
/// `sep` may be any string (a thin space, "'", or "" for no grouping, which
/// gives `fixed(x, digits)`). Rounding, sign, clamping of `digits` and the
/// values that are not finite ("NaN", "∞", "-∞", without separators) are
/// those of `fixed`.
pub fn grouped(x : Double, digits~ : Int = 0, sep~ : String = ",") -> String {
  if non_finite(x) is Some(s) {
    return s
  }
  let digits = clamp_digits(digits)
  let buf = StringBuilder()
  if x < 0.0 {
    buf.write_char('-')
  }
  write_number(buf, Decimal::of(x).rounded(digits), digits, sep)
  buf.to_string()
}

///|
/// The integer `n` with `sep` between groups of three digits:
/// `grouped_int(1234567)` is "1,234,567", `grouped_int(-1000)` is "-1,000",
/// `grouped_int(999)` is "999". Every `Int64` is accepted, the smallest
/// included. For an `Int` write `grouped_int(n.to_int64())`.
pub fn grouped_int(n : Int64, sep~ : String = ",") -> String {
  let text = n.to_string()
  let buf = StringBuilder()
  let digits = if n < 0L {
    buf.write_char('-')
    text.length() - 1
  } else {
    text.length()
  }
  let start = text.length() - digits
  for i in 0..<digits {
    if i > 0 && (digits - i) % 3 == 0 {
      buf.write_string(sep)
    }
    buf.write_char(text.unsafe_get(start + i).unsafe_to_char())
  }
  buf.to_string()
}

///|
/// The ratio `x` as a percentage with `digits` decimals: `percent(0.956)` is
/// "95.6%", `percent(0.5, digits=0)` is "50%", `percent(-0.0412)` is
/// "-4.1%", `percent(1.5)` is "150.0%".
///
/// The value that is rounded is the exact value of `x` times one hundred,
/// not the double `100.0 * x`: no rounding error of a multiplication is in
/// the result. (It can therefore differ from `fixed(100.0 * x, digits)` in
/// the last digit: `0.045` is a double just below 0.045, so `percent(0.045,
/// digits=0)` is "4%", while the product `100.0 * 0.045` rounds up to the
/// double 4.5.) Rounding, sign and clamping of `digits` are those of
/// `fixed`.
///
/// Not finite: "NaN" (no sign, no suffix), "∞%" and "-∞%".
pub fn percent(x : Double, digits~ : Int = 1) -> String {
  if x.is_nan() {
    return "NaN"
  }
  if x.is_pos_inf() {
    return "∞%"
  }
  if x.is_neg_inf() {
    return "-∞%"
  }
  let digits = clamp_digits(digits)
  let buf = StringBuilder()
  if x < 0.0 {
    buf.write_char('-')
  }
  // Two more places: the exact value times 100.
  write_number(buf, Decimal::of(x).rounded(digits + 2), digits, "")
  buf.write_char('%')
  buf.to_string()
}

///|
/// The units of `compact`, a thousand apart.
let compact_units : ReadOnlyArray[String] = ["", "k", "M", "B"]

///|
/// `x` in one of the units one, thousand ("k"), million ("M") and billion
/// ("B"), with `digits` decimals: the smallest of them in which the rounded
/// magnitude is below 1000, and a billion if there is none.
/// `compact(1234.0)` is "1.2k", `compact(5.4e6)` is "5.4M", `compact(2.0e9,
/// digits=0)` is "2B", `compact(-1500.0)` is "-1.5k".
///
/// - Below a thousand there is no suffix, and the decimals are kept:
///   `compact(950.0)` is "950.0", `compact(0.25)` is "0.3"; use `digits=0`
///   for counts (`compact(950.0, digits=0)` is "950").
/// - The unit is chosen after rounding, so "1000.0k" is never written, and
///   a value is not moved up before it reaches a thousand ("950.0", not
///   "1.0k"):
///   `compact(999_949.0)` is "999.9k", `compact(999_950.0)` is "1.0M", and
///   `compact(999.95)` is "1.0k" (the double 999.95 is above 999.95).
/// - A billion is the largest unit: `compact(2.5e13)` is "25000.0B", without
///   grouping.
/// - The value that is rounded is the exact value of `x` divided by the
///   unit (no floating-point division). Rounding, sign and clamping of
///   `digits` are those of `fixed`.
///
/// Not finite: "NaN", "∞" and "-∞", without a suffix.
pub fn compact(x : Double, digits~ : Int = 1) -> String {
  if non_finite(x) is Some(s) {
    return s
  }
  let digits = clamp_digits(digits)
  let decimal = Decimal::of(x)
  let buf = StringBuilder()
  if x < 0.0 {
    buf.write_char('-')
  }
  let last = compact_units.length() - 1
  for unit in 0..<=last {
    let n = decimal.rounded(digits - 3 * unit)
    // Less than 1000 in this unit: at most three digits before the point.
    if unit == last || n.length() <= digits + 3 {
      write_number(buf, n, digits, "")
      buf.write_string(compact_units[unit])
      break
    }
  }
  buf.to_string()
}
