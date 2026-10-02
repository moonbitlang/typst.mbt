// Port of `hayro-postscript/src/number.rs`.

///|
/// A PostScript number object (integer or real).
pub(all) enum Number {
  Integer(Int)
  Real(Float)
} derive(Eq, Debug)

///|
pub impl Show for Number with fn output(self, logger) {
  match self {
    Integer(v) => logger.write_string("Integer(\{v})")
    Real(v) => logger.write_string("Real(\{v})")
  }
}

///|
/// Return the value as an `i32`. Reals are truncated (saturating like Rust's
/// `as`).
pub fn Number::as_i32(self : Number) -> Int {
  match self {
    Integer(v) => v
    Real(v) => f32_to_i32_sat(v)
  }
}

///|
/// Return the value as an `f32`.
pub fn Number::as_f32(self : Number) -> Float {
  match self {
    Integer(v) => Float::from_int(v)
    Real(v) => v
  }
}

///|
/// Return the value as an `f64`.
pub fn Number::as_f64(self : Number) -> Double {
  match self {
    Integer(v) => v.to_double()
    Real(v) => v.to_double()
  }
}

///|
/// Rust's saturating `f32 as i32`.
fn f32_to_i32_sat(v : Float) -> Int {
  let d = v.to_double()
  if d.is_nan() {
    0
  } else if d >= 2147483647.0 {
    2147483647
  } else if d <= -2147483648.0 {
    -2147483648
  } else {
    d.to_int()
  }
}

///|
fn is_terminated(r : Reader) -> Bool {
  match r.peek_byte() {
    None => true
    Some(b) => is_whitespace(b) || is_delimiter(b)
  }
}

///|
fn is_ascii_digit(b : Byte) -> Bool {
  b >= b'0' && b <= b'9'
}

///|
fn is_ascii_alphanumeric(b : Byte) -> Bool {
  is_ascii_digit(b) || (b >= b'a' && b <= b'z') || (b >= b'A' && b <= b'Z')
}

///|
fn read_number(r : Reader) -> Result[Number, PsError] {
  let saved = r.offset()

  // Optional sign.
  guard r.peek_byte() is Some(first) else { return Err(SyntaxError) }
  let has_sign = first == b'+' || first == b'-'
  if has_sign {
    r.forward()
  }

  // Consume leading digits.
  let digit_start = r.offset()
  r.forward_while(is_ascii_digit)
  let has_digits = r.offset() > digit_start

  // Check if number is a radix number.
  if !has_sign && has_digits && r.peek_byte() == Some(b'#') {
    guard r.range(digit_start, r.offset()) is Some(base_bytes) else {
      return Err(SyntaxError)
    }
    guard parse_u32_decimal(base_bytes) is Some(base) else {
      return Err(SyntaxError)
    }
    if !(base >= 2U && base <= 36U) {
      return Err(SyntaxError)
    }

    // Skip `#`.
    r.forward()
    let num_start = r.offset()
    r.forward_while(is_ascii_alphanumeric)
    if r.offset() == num_start || !is_terminated(r) {
      return Err(SyntaxError)
    }
    guard r.range(num_start, r.offset()) is Some(num_bytes) else {
      return Err(SyntaxError)
    }
    guard i32_from_str_radix(num_bytes, base.reinterpret_as_int())
      is Some(value) else {
      return Err(SyntaxError)
    }
    return Ok(Integer(value))
  }

  // Check for real number indicators: `.` or `e`/`E`.
  let has_dot = r.peek_byte() == Some(b'.')
  if has_dot {
    r.forward() // skip '.'
    r.forward_while(is_ascii_digit)
  }

  // At this point we need at least some digits (before or after the dot).
  if !has_digits && !has_dot {
    return Err(SyntaxError)
  }
  let has_exponent = r.peek_byte() is Some(b'e' | b'E')
  if has_exponent {
    r.forward()

    // Optional exponent sign.
    if r.peek_byte() is Some(b'+' | b'-') {
      r.forward()
    }
    r.forward_while(is_ascii_digit)
  }
  if !is_terminated(r) {
    return Err(SyntaxError)
  }
  guard r.range(saved, r.offset()) is Some(token) else {
    return Err(SyntaxError)
  }
  if has_dot || has_exponent {
    guard parse_f32(token) is Some(value) else { return Err(SyntaxError) }
    Ok(Real(value))
  } else {
    if !has_digits {
      return Err(SyntaxError)
    }
    guard parse_i32_decimal(token) is Some(value) else {
      return Err(SyntaxError)
    }
    Ok(Integer(value))
  }
}

///|
/// `str::parse::<u32>()` on a string of ASCII digits.
fn parse_u32_decimal(bytes : BytesView) -> UInt? {
  if bytes.length() == 0 {
    return None
  }
  let mut v = 0UL
  for b in bytes {
    guard is_ascii_digit(b) else { return None }
    v = v * 10UL + (b - b'0').to_uint64()
    if v > 4294967295UL {
      return None
    }
  }
  Some(v.to_uint())
}

///|
/// `str::parse::<i32>()`: an optional sign followed by ASCII digits.
fn parse_i32_decimal(bytes : BytesView) -> Int? {
  let mut i = 0
  let mut neg = false
  if bytes.length() > 0 && (bytes[0] == b'+' || bytes[0] == b'-') {
    neg = bytes[0] == b'-'
    i = 1
  }
  if i >= bytes.length() {
    return None
  }
  let limit = if neg { 2147483648L } else { 2147483647L }
  let mut v = 0L
  while i < bytes.length() {
    let b = bytes[i]
    guard is_ascii_digit(b) else { return None }
    v = v * 10L + (b - b'0').to_int64()
    if v > limit {
      return None
    }
    i += 1
  }
  Some((if neg { -v } else { v }).to_int())
}

///|
/// `i32::from_str_radix` on a string of ASCII alphanumerics.
fn i32_from_str_radix(bytes : BytesView, radix : Int) -> Int? {
  if bytes.length() == 0 {
    return None
  }
  let mut v = 0L
  for b in bytes {
    let d = if is_ascii_digit(b) {
      (b - b'0').to_int()
    } else if b >= b'a' && b <= b'z' {
      (b - b'a').to_int() + 10
    } else if b >= b'A' && b <= b'Z' {
      (b - b'A').to_int() + 10
    } else {
      return None
    }
    if d >= radix {
      return None
    }
    v = v * radix.to_int64() + d.to_int64()
    if v > 2147483647L {
      return None
    }
  }
  Some(v.to_int())
}

///|
/// `str::parse::<f32>()` for the tokens accepted by `read_number` (an optional
/// sign, digits with an optional dot and an optional exponent).
///
/// Note: this parses to the nearest `f64` and rounds that to `f32`, which can
/// differ from Rust's direct decimal-to-`f32` rounding in extremely rare
/// halfway cases.
fn parse_f32(token : BytesView) -> Float? {
  let n = token.length()
  let mut i = 0
  let sign = if i < n && (token[i] == b'+' || token[i] == b'-') {
    i += 1
    if token[i - 1] == b'-' {
      "-"
    } else {
      ""
    }
  } else {
    ""
  }
  let int_start = i
  while i < n && is_ascii_digit(token[i]) {
    i += 1
  }
  let int_digits = token[int_start:i]
  let mut frac_digits = token[i:i]
  if i < n && token[i] == b'.' {
    i += 1
    let frac_start = i
    while i < n && is_ascii_digit(token[i]) {
      i += 1
    }
    frac_digits = token[frac_start:i]
  }
  if int_digits.length() + frac_digits.length() == 0 {
    return None
  }
  let mut exp = ""
  if i < n && (token[i] == b'e' || token[i] == b'E') {
    i += 1
    let mut exp_sign = ""
    if i < n && (token[i] == b'+' || token[i] == b'-') {
      if token[i] == b'-' {
        exp_sign = "-"
      }
      i += 1
    }
    let exp_start = i
    while i < n && is_ascii_digit(token[i]) {
      i += 1
    }
    if i == exp_start {
      return None
    }
    exp = "e" + exp_sign + ascii(token[exp_start:i])
  }
  if i != n {
    return None
  }
  let int_s = if int_digits.length() == 0 { "0" } else { ascii(int_digits) }
  let frac_s = if frac_digits.length() == 0 { "0" } else { ascii(frac_digits) }
  let s = sign + int_s + "." + frac_s + exp
  // The syntax has been validated, so an error can only be an overflow
  // (which Rust maps to infinity).
  let d = @string.parse_double(s) catch {
    _ => if sign == "-" { -@double.infinity } else { @double.infinity }
  }
  Some(Float::from_double(d))
}

///|
fn ascii(bytes : BytesView) -> String {
  let sb = StringBuilder()
  for b in bytes {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  sb.to_string()
}
