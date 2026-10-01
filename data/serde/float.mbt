// Float formatting as done by the Rust crates the formats are built on:
// `ryu` (serde_json, serde_yaml) and `std`'s `Display`/`Debug` (toml).

///|
/// The shortest round-trip decimal digits and exponent of a finite, non-zero
/// double: `|x| = 0.d1d2d3... * 10^point` (digits without leading or trailing
/// zeros).
pub fn shortest_digits(x : Double) -> (String, Int) {
  // MoonBit's `to_string` produces the shortest round-trip representation,
  // either as plain decimal or with an `e` exponent.
  let s = x.abs().to_string()
  let (mantissa, exp) = match s.find("e") {
    Some(i) => {
      let e = s.unsafe_substring(start=i + 1, end=s.length())
      let e = if e.has_prefix("+") {
        e.unsafe_substring(start=1, end=e.length())
      } else {
        e
      }
      (
        s.unsafe_substring(start=0, end=i),
        @string.parse_int(e) catch {
          _ => 0
        },
      )
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
  let mut point = int_part.length() + exp
  let mut start = 0
  while start < all.length() - 1 && all.code_unit_at(start) == '0' {
    start += 1
    point -= 1
  }
  let mut end = all.length()
  while end > start + 1 && all.code_unit_at(end - 1) == '0' {
    end -= 1
  }
  (all.unsafe_substring(start~, end~), point)
}

///|
fn is_negative(x : Double) -> Bool {
  x < 0.0 || (x == 0.0 && 1.0 / x < 0.0)
}

///|
/// `ryu::Buffer::format_finite` for an `f64` (the caller handles NaN and
/// infinities).
pub fn format_ryu(x : Double) -> String {
  let sign = if is_negative(x) { "-" } else { "" }
  if x == 0.0 {
    return sign + "0.0"
  }
  let (digits, kk) = shortest_digits(x)
  let length = digits.length()
  let buf = StringBuilder()
  buf.write_string(sign)
  if length <= kk && kk <= 16 {
    // 1234e7 -> 12340000000.0
    buf.write_string(digits)
    for _ in length..<kk {
      buf.write_char('0')
    }
    buf.write_string(".0")
  } else if 0 < kk && kk <= 16 {
    // 1234e-2 -> 12.34
    buf.write_string(digits.unsafe_substring(start=0, end=kk))
    buf.write_char('.')
    buf.write_string(digits.unsafe_substring(start=kk, end=length))
  } else if -5 < kk && kk <= 0 {
    // 1234e-6 -> 0.001234
    buf.write_string("0.")
    for _ in 0..<-kk {
      buf.write_char('0')
    }
    buf.write_string(digits)
  } else if length == 1 {
    // 1e30
    buf.write_string(digits)
    buf.write_char('e')
    buf.write_string((kk - 1).to_string())
  } else {
    // 1234e30 -> 1.234e33
    buf.write_string(digits.unsafe_substring(start=0, end=1))
    buf.write_char('.')
    buf.write_string(digits.unsafe_substring(start=1, end=length))
    buf.write_char('e')
    buf.write_string((kk - 1).to_string())
  }
  buf.to_string()
}

///|
/// `zmij::Buffer::format_finite` for an `f64` (used by `serde_json`; the
/// caller handles NaN and infinities): fixed notation for decimal exponents
/// in `-5..=15`, otherwise `d.ddde+XX` / `d.ddde-X`.
pub fn format_zmij(x : Double) -> String {
  let sign = if is_negative(x) { "-" } else { "" }
  if x == 0.0 {
    return sign + "0.0"
  }
  let (digits, point) = shortest_digits(x)
  let dec_exp = point - 1
  let length = digits.length()
  let buf = StringBuilder()
  buf.write_string(sign)
  if dec_exp >= -5 && dec_exp <= 15 {
    if length - 1 <= dec_exp {
      // 1234e7 -> 12340000000.0
      buf.write_string(digits)
      for _ in length..<(dec_exp + 1) {
        buf.write_char('0')
      }
      buf.write_string(".0")
    } else if 0 <= dec_exp {
      // 1234e-2 -> 12.34
      buf.write_string(digits.unsafe_substring(start=0, end=dec_exp + 1))
      buf.write_char('.')
      buf.write_string(digits.unsafe_substring(start=dec_exp + 1, end=length))
    } else {
      // 1234e-6 -> 0.001234
      buf.write_string("0.")
      for _ in 0..<(-dec_exp - 1) {
        buf.write_char('0')
      }
      buf.write_string(digits)
    }
  } else {
    // 1234e30 -> 1.234e+33
    buf.write_string(digits.unsafe_substring(start=0, end=1))
    if length > 1 {
      buf.write_char('.')
      buf.write_string(digits.unsafe_substring(start=1, end=length))
    }
    buf.write_string(if dec_exp >= 0 { "e+" } else { "e-" })
    buf.write_string(dec_exp.abs().to_string())
  }
  buf.to_string()
}

///|
/// Place the decimal point into `digits` (`0.digits * 10^point`), padding
/// with zeros, and ensure at least `min_frac` fractional digits.
fn place_point(digits : String, point : Int, min_frac : Int) -> String {
  let buf = StringBuilder()
  let n = digits.length()
  if point <= 0 {
    buf.write_string("0.")
    for _ in 0..<-point {
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
/// Rust's `impl Display for f64` (`{}`): shortest round-trip digits, never
/// using exponent notation.
pub fn format_display(x : Double) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let sign = if is_negative(x) { "-" } else { "" }
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
/// Rust's `impl Debug for f64` (`{:?}`): like `Display` but always with a
/// fractional part, and in exponent notation when `|x| < 1e-4` or
/// `|x| >= 1e16`.
pub fn format_debug(x : Double) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let sign = if is_negative(x) { "-" } else { "" }
  if x.is_inf() {
    return sign + "inf"
  }
  if x == 0.0 {
    return sign + "0.0"
  }
  let a = x.abs()
  let (digits, point) = shortest_digits(x)
  if a < 1.0e-4 || a >= 1.0e16 {
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
test "format_ryu" {
  inspect(format_ryu(1.0), content="1.0")
  inspect(format_ryu(-0.0), content="-0.0")
  inspect(format_ryu(1.5), content="1.5")
  inspect(format_ryu(1.0e15), content="1000000000000000.0")
  inspect(format_ryu(1.0e16), content="1e16")
  inspect(format_ryu(1.25e16), content="1.25e16")
  inspect(format_ryu(18446744073709551615.0), content="1.8446744073709552e19")
  inspect(format_ryu(0.0001), content="0.0001")
  inspect(format_ryu(0.00001), content="0.00001")
  inspect(format_ryu(0.000001), content="1e-6")
  inspect(format_ryu(1.5e-7), content="1.5e-7")
  inspect(format_ryu(123.456), content="123.456")
}

///|
test "format_zmij" {
  inspect(format_zmij(1.0), content="1.0")
  inspect(format_zmij(-0.0), content="-0.0")
  inspect(format_zmij(1.0e20), content="1e+20")
  inspect(format_zmij(1.0e16), content="1e+16")
  inspect(format_zmij(1.0e15), content="1000000000000000.0")
  inspect(format_zmij(1.0e301), content="1e+301")
  inspect(format_zmij(1.5e-7), content="1.5e-7")
  inspect(format_zmij(0.00001), content="0.00001")
  inspect(format_zmij(0.000012), content="0.000012")
  inspect(format_zmij(0.000001), content="1e-6")
  inspect(format_zmij(123.456), content="123.456")
  inspect(format_zmij(0.1), content="0.1")
  inspect(format_zmij(1.2345678901234567e19), content="1.2345678901234567e+19")
}

///|
test "format_display_debug" {
  inspect(format_display(1.0), content="1")
  inspect(format_display(1.0e21), content="1000000000000000000000")
  inspect(format_debug(1.0), content="1.0")
  inspect(format_debug(1.0e16), content="1e16")
  inspect(format_debug(0.00001), content="1e-5")
}
