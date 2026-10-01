// Number formatting and arithmetic helpers that reproduce Rust `std`
// behavior exactly (Typst's reprs and messages are built from these).

///|
/// Rust's `f64::round`: round half away from zero.
pub fn rust_round(x : Double) -> Double {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let t = x.trunc()
  let diff = (x - t).abs()
  if diff >= 0.5 {
    t + (if x < 0.0 { -1.0 } else { 1.0 })
  } else {
    t
  }
}

///|
/// Exact `10^n` for the exponents `libm::exp10` is used with.
pub fn exp10(n : Int) -> Double {
  if n == 0 {
    return 1.0
  }
  @string.parse_double("1e\{n}") catch {
    _ => @math.pow(10.0, n.to_double())
  }
}

///|
/// The shortest round-trip decimal digits and exponent of a finite, non-zero
/// double: `x = 0.d1d2d3... * 10^exp` (digits without leading zeros).
fn shortest_digits(x : Double) -> (String, Int) {
  // MoonBit's `to_string` produces the shortest round-trip representation
  // (like Rust), either as plain decimal or with an `e` exponent.
  let s = x.abs().to_string()
  let (mantissa, exp) = match s.find("e") {
    Some(i) => {
      let e = s.unsafe_substring(start=i + 1, end=s.length())
      let e = if e.has_prefix("+") {
        e.unsafe_substring(start=1, end=e.length())
      } else {
        e
      }
      (s.unsafe_substring(start=0, end=i), @string.parse_int(e) catch { _ => 0 })
    }
    None => (s, 0)
  }
  let (int_part, frac_part) = match mantissa.find(".") {
    Some(i) =>
      (
        mantissa.unsafe_substring(start=0, end=i),
        mantissa.unsafe_substring(start=i + 1, end=mantissa.length()),
      )
    None => (mantissa, "")
  }
  let all = int_part + frac_part
  // Position of the decimal point relative to `all`.
  let mut point = int_part.length() + exp
  // Strip leading zeros.
  let mut start = 0
  while start < all.length() - 1 && all.code_unit_at(start) == '0' {
    start += 1
    point -= 1
  }
  // Strip trailing zeros.
  let mut end = all.length()
  while end > start + 1 && all.code_unit_at(end - 1) == '0' {
    end -= 1
  }
  (all.unsafe_substring(start~, end~), point)
}

///|
/// Rust's `impl Display for f64` (`{}`): shortest round-trip digits, never
/// using exponent notation.
pub fn rust_display_f64(x : Double) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x < 0.0 || (x == 0.0 && (1.0 / x) < 0.0)
  let sign = if neg { "-" } else { "" }
  if x.is_inf() {
    return sign + "inf"
  }
  if x == 0.0 {
    return sign + "0"
  }
  let (digits, point) = shortest_digits(x)
  sign + place_point(digits, point, 0)
}

///|
/// Place the decimal point into `digits` (`0.digits * 10^point`), padding
/// with zeros, and ensure at least `min_frac` fractional digits.
fn place_point(digits : String, point : Int, min_frac : Int) -> String {
  let buf = StringBuilder()
  let n = digits.length()
  if point <= 0 {
    buf.write_string("0.")
    for _ in 0..<(-point) {
      buf.write_char('0')
    }
    buf.write_string(digits)
  } else if point >= n {
    buf.write_string(digits)
    for _ in 0..<(point - n) {
      buf.write_char('0')
    }
    if min_frac > 0 {
      buf.write_char('.')
      for _ in 0..<min_frac {
        buf.write_char('0')
      }
    }
  } else {
    buf.write_string(digits.unsafe_substring(start=0, end=point))
    buf.write_char('.')
    buf.write_string(digits.unsafe_substring(start=point, end=n))
  }
  buf.to_string()
}

///|
/// Rust's `impl Debug for f64` (`{:?}`): like Display but always with a
/// fractional part, and in exponent notation when `|x| < 1e-4` or
/// `|x| >= 1e16`.
pub fn rust_debug_f64(x : Double) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x < 0.0 || (x == 0.0 && (1.0 / x) < 0.0)
  let sign = if neg { "-" } else { "" }
  if x.is_inf() {
    return sign + "inf"
  }
  if x == 0.0 {
    return sign + "0.0"
  }
  let a = x.abs()
  let (digits, point) = shortest_digits(x)
  if a < 1.0e-4 || a >= 1.0e16 {
    // LowerExp: d[.ddd]e<exp>
    let exp = point - 1
    let mantissa = if digits.length() == 1 {
      digits
    } else {
      digits.unsafe_substring(start=0, end=1) +
      "." +
      digits.unsafe_substring(start=1, end=digits.length())
    }
    sign + mantissa + "e" + exp.to_string()
  } else {
    sign + place_point(digits, point, 1)
  }
}

///|
/// Rust's `{:.prec}` formatting of a double (round half to even on the exact
/// binary value, like Rust's `format_exact`).
pub fn rust_fixed_f64(x : Double, prec : Int) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x < 0.0 || (x == 0.0 && (1.0 / x) < 0.0)
  let sign = if neg { "-" } else { "" }
  if x.is_inf() {
    return sign + "inf"
  }
  sign + exact_fixed(x.abs(), prec)
}

///|
/// Exact decimal expansion of a non-negative finite double rounded to `prec`
/// fractional digits with round-half-to-even.
fn exact_fixed(a : Double, prec : Int) -> String {
  // Decompose a = m * 2^e exactly.
  let bits = a.reinterpret_as_uint64()
  let exp_bits = ((bits >> 52) & 0x7FF).to_int()
  let frac = bits & 0xFFFFFFFFFFFFF
  let (m, e) = if exp_bits == 0 {
    (frac, -1074)
  } else {
    (frac | (1UL << 52), exp_bits - 1075)
  }
  // value = m * 2^e; scaled = value * 10^prec as an exact big rational.
  let mb = @bigint.BigInt::from_uint64(m)
  let ten_p = @bigint.BigInt::from_int(10).pow(@bigint.BigInt::from_int(prec))
  let (num, den) = if e >= 0 {
    (mb * ten_p * @bigint.BigInt::from_int(2).pow(@bigint.BigInt::from_int(e)), @bigint.BigInt::from_int(1))
  } else {
    (mb * ten_p, @bigint.BigInt::from_int(2).pow(@bigint.BigInt::from_int(-e)))
  }
  let q = num / den
  let r = num - q * den
  let twice = r * @bigint.BigInt::from_int(2)
  let q = if twice > den ||
    (twice == den && q % @bigint.BigInt::from_int(2) != @bigint.BigInt::from_int(0)) {
    q + @bigint.BigInt::from_int(1)
  } else {
    q
  }
  let digits = q.to_string()
  if prec == 0 {
    return digits
  }
  let padded = if digits.length() <= prec {
    let buf = StringBuilder()
    for _ in 0..<(prec + 1 - digits.length()) {
      buf.write_char('0')
    }
    buf.write_string(digits)
    buf.to_string()
  } else {
    digits
  }
  let split = padded.length() - prec
  padded.unsafe_substring(start=0, end=split) +
  "." +
  padded.unsafe_substring(start=split, end=padded.length())
}

///|
/// Port of `typst_utils::round_with_precision`.
pub fn round_with_precision(value : Double, precision : Int) -> Double {
  if value.is_inf() ||
    value.is_nan() ||
    (precision >= 0 && value.abs() >= 9007199254740992.0) ||
    precision >= 15 {
    return value
  }
  if precision < -308 {
    return value * 0.0
  }
  if precision > 0 {
    let offset = exp10(precision)
    rust_round(value * offset) / offset
  } else {
    let offset = exp10(-precision)
    rust_round(value / offset) * offset
  }
}
