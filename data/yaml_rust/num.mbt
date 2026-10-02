// Number parsing with the semantics of the Rust standard library functions
// yaml-rust uses (`i64::from_str_radix`, `str::parse::<i64>()`,
// `str::parse::<f64>()`).

///|
/// Rust's `char::to_digit` for a UTF-16 code unit.
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
/// Rust's `i64::from_str_radix` (also `str::parse::<i64>()` with radix 10):
/// an optional `+`/`-` followed by at least one digit, no overflow.
fn i64_from_str_radix(s : String, radix : Int) -> Int64? {
  let len = s.length()
  if len == 0 {
    return None
  }
  let first = s.code_unit_at(0).to_int()
  let (negative, start) = if first == '+' {
    (false, 1)
  } else if first == '-' {
    (true, 1)
  } else {
    (false, 0)
  }
  if start == len {
    return None
  }
  let r = radix.to_int64()
  let mut acc = 0L
  for i in start..<len {
    guard ascii_to_digit(s.code_unit_at(i).to_int(), radix) is Some(d) else {
      return None
    }
    let d = d.to_int64()
    if negative {
      // acc * r - d >= i64::MIN
      if acc < (-0x8000_0000_0000_0000L + d) / r {
        return None
      }
      acc = acc * r - d
    } else {
      // acc * r + d <= i64::MAX
      if acc > (0x7FFF_FFFF_FFFF_FFFFL - d) / r {
        return None
      }
      acc = acc * r + d
    }
  }
  Some(acc)
}

///|
/// ASCII case-insensitive equality with a lowercase ASCII literal.
fn eq_ignore_ascii_case(s : StringView, lower : String) -> Bool {
  if s.length() != lower.length() {
    return false
  }
  for i in 0..<s.length() {
    let mut c = s.code_unit_at(i).to_int()
    if c >= 'A' && c <= 'Z' {
      c = c + 32
    }
    if c != lower.code_unit_at(i).to_int() {
      return false
    }
  }
  true
}

///|
/// Rust's `str::parse::<f64>()`, `None` on a syntax error.
///
/// Accepted are an optional sign followed by `inf`, `infinity` or `nan` (in
/// any ASCII case), or by `digits[.digits][(e|E)[sign]digits]` where at least
/// one digit precedes the exponent.
fn rust_parse_f64(s : String) -> Double? {
  let len = s.length()
  let mut i = 0
  let mut negative = false
  if i < len && (s.code_unit_at(i) == '+' || s.code_unit_at(i) == '-') {
    negative = s.code_unit_at(i) == '-'
    i += 1
  }
  let rest = s.view(start_offset=i)
  if eq_ignore_ascii_case(rest, "inf") || eq_ignore_ascii_case(rest, "infinity") {
    return Some(if negative { @double.neg_infinity } else { @double.infinity })
  }
  if eq_ignore_ascii_case(rest, "nan") {
    return Some(@double.not_a_number)
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
