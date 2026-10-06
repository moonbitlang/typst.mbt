// Number parsing with exactly the semantics of the Rust standard library
// functions upstream uses (`from_str_radix`, `str::parse::<f64>()`).

///|
/// Rust's `std::num::IntErrorKind`.
priv enum IntErrorKind {
  Empty
  InvalidDigit
  PosOverflow
  NegOverflow
}

///|
/// Rust's `char::to_digit` for ASCII code units.
fn ascii_to_digit(c : Int, radix : Int) -> Int? {
  let d = if c >= '0' && c <= '9' {
    c - '0'
  } else if c >= 'a' && c <= 'z' {
    c - 'a' + 10
  } else if c >= 'A' && c <= 'Z' {
    c - 'A' + 10
  } else {
    return None
  }
  if d < radix {
    Some(d)
  } else {
    None
  }
}

///|
/// Split off the sign like Rust's `from_str_radix` does.
fn split_sign(s : String, signed : Bool) -> Result[(Bool, Int), IntErrorKind] {
  if s.is_empty() {
    return Err(Empty)
  }
  let first = s.code_unit_at(0).to_int()
  if (first == '+' || first == '-') && s.length() == 1 {
    Err(InvalidDigit)
  } else if first == '+' {
    Ok((true, 1))
  } else if first == '-' && signed {
    Ok((false, 1))
  } else {
    Ok((true, 0))
  }
}

///|
/// Rust's `i64::from_str_radix`.
fn i64_from_str_radix(s : String, radix : Int) -> Result[Int64, IntErrorKind] {
  let (positive, start) = match split_sign(s, true) {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let r = radix.to_int64()
  let mut result = 0L
  for i in start..<s.length() {
    // Like upstream, the multiplication is checked before the digit, but
    // its overflow is only reported after an invalid digit.
    let mul_ok = if positive {
      result <= @int64.MAX_VALUE / r
    } else {
      result >= @int64.MIN_VALUE / r
    }
    guard ascii_to_digit(s.code_unit_at(i).to_int(), radix) is Some(x) else {
      return Err(InvalidDigit)
    }
    guard mul_ok else {
      return Err(if positive { PosOverflow } else { NegOverflow })
    }
    result = result * r
    let x = x.to_int64()
    if positive {
      guard result <= @int64.MAX_VALUE - x else { return Err(PosOverflow) }
      result = result + x
    } else {
      guard result >= @int64.MIN_VALUE + x else { return Err(NegOverflow) }
      result = result - x
    }
  }
  Ok(result)
}

///|
/// Rust's `u64::from_str_radix`.
fn u64_from_str_radix(s : String, radix : Int) -> Result[UInt64, IntErrorKind] {
  let start = match split_sign(s, false) {
    Ok((_, start)) => start
    Err(e) => return Err(e)
  }
  let r = radix.to_uint64()
  let max = 0xFFFF_FFFF_FFFF_FFFFUL
  let mut result = 0UL
  for i in start..<s.length() {
    let mul_ok = result <= max / r
    guard ascii_to_digit(s.code_unit_at(i).to_int(), radix) is Some(x) else {
      return Err(InvalidDigit)
    }
    guard mul_ok else { return Err(PosOverflow) }
    result = result * r
    let x = x.to_uint64()
    guard result <= max - x else { return Err(PosOverflow) }
    result = result + x
  }
  Ok(result)
}

///|
/// Rust's `str::parse::<f64>()`, `None` on a syntax error.
///
/// Accepted are an optional sign followed by `inf`, `infinity` or `nan` (in
/// any case), or by `digits[.digits][(e|E)[sign]digits]` where at least one
/// digit precedes the exponent. Values too large for an `f64` become
/// infinite, too small ones become zero (with correct rounding).
fn rust_parse_f64(s : String) -> Double? {
  let len = s.length()
  let mut i = 0
  let mut negative = false
  if i < len && (s.code_unit_at(i) == '+' || s.code_unit_at(i) == '-') {
    negative = s.code_unit_at(i) == '-'
    i += 1
  }
  let rest = s.unsafe_substring(start=i, end=len).to_lower()
  if rest == "inf" || rest == "infinity" {
    return Some(if negative { @double.neg_infinity } else { @double.infinity })
  }
  if rest == "nan" {
    // `f64::NAN` (MoonBit's `not_a_number` has another payload), negated
    // after a `-` like upstream.
    let nan = 0x7FF8000000000000L.reinterpret_as_double()
    return Some(if negative { -nan } else { nan })
  }
  // Validate the grammar ourselves: MoonBit's parser also accepts `_`.
  let is_digit = (j : Int) => {
    j < len && s.code_unit_at(j) >= '0' && s.code_unit_at(j) <= '9'
  }
  let mut digits = 0
  while is_digit(i) {
    i += 1
    digits += 1
  }
  if i < len && s.code_unit_at(i) == '.' {
    i += 1
    while is_digit(i) {
      i += 1
      digits += 1
    }
  }
  if digits == 0 {
    return None
  }
  if i < len && (s.code_unit_at(i) == 'e' || s.code_unit_at(i) == 'E') {
    i += 1
    if i < len && (s.code_unit_at(i) == '+' || s.code_unit_at(i) == '-') {
      i += 1
    }
    let exp_start = i
    while is_digit(i) {
      i += 1
    }
    if i == exp_start {
      return None
    }
  }
  if i != len {
    return None
  }
  Some(
    @string.parse_double(s) catch {
      // The syntax is valid, so this can only be an overflow.
      _ => if negative { @double.neg_infinity } else { @double.infinity }
    },
  )
}
