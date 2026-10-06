// Number parsing with the semantics of the Rust standard library functions
// serde_yaml uses (`{u64,i64,u128,i128}::from_str_radix`,
// `str::parse::<f64>()`).

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
/// A parsed integer: sign and 128-bit magnitude `hi * 2^64 + lo`.
priv struct Wide {
  negative : Bool
  hi : UInt64
  lo : UInt64
}

///|
/// The digits of Rust's `from_str_radix` for a 128-bit type: the sign is
/// split off like upstream (`-` only for signed types), every remaining
/// character must be a digit of `radix`, and the magnitude must fit into 128
/// bits. Range checks for the concrete type happen in the callers.
fn parse_wide(s : String, radix : Int, signed : Bool) -> Wide? {
  if s.is_empty() {
    return None
  }
  let first = s.code_unit_at(0).to_int()
  let (negative, start) = if (first == '+' || first == '-') && s.length() == 1 {
    return None
  } else if first == '+' {
    (false, 1)
  } else if first == '-' && signed {
    (true, 1)
  } else {
    (false, 0)
  }
  let r = radix.to_uint64()
  let mut hi = 0UL
  let mut lo = 0UL
  for i in start..<s.length() {
    guard ascii_to_digit(s.code_unit_at(i).to_int(), radix) is Some(d) else {
      return None
    }
    // (hi, lo) = (hi, lo) * r + d, failing on overflow beyond 128 bits.
    let lo_lo = (lo & 0xFFFF_FFFFUL) * r
    let lo_hi = (lo >> 32) * r + (lo_lo >> 32)
    let new_lo = (lo_hi << 32) | (lo_lo & 0xFFFF_FFFFUL)
    let carry = lo_hi >> 32
    if hi > 0xFFFF_FFFF_FFFF_FFFFUL / r {
      return None
    }
    let hi_mul = hi * r
    if hi_mul > 0xFFFF_FFFF_FFFF_FFFFUL - carry {
      return None
    }
    hi = hi_mul + carry
    lo = new_lo + d.to_uint64()
    if lo < new_lo {
      if hi == 0xFFFF_FFFF_FFFF_FFFFUL {
        return None
      }
      hi = hi + 1
    }
  }
  Some({ negative, hi, lo, })
}

///|
/// Rust's `u64::from_str_radix`.
fn u64_from_str_radix(s : String, radix : Int) -> UInt64? {
  match parse_wide(s, radix, false) {
    Some({ hi: 0, lo, .. }) => Some(lo)
    _ => None
  }
}

///|
/// Rust's `i64::from_str_radix`.
fn i64_from_str_radix(s : String, radix : Int) -> Int64? {
  match parse_wide(s, radix, true) {
    Some({ negative: false, hi: 0, lo, }) if lo <= 0x7FFF_FFFF_FFFF_FFFFUL =>
      Some(lo.reinterpret_as_int64())
    Some({ negative: true, hi: 0, lo, }) if lo <= 0x8000_0000_0000_0000UL =>
      Some((0UL - lo).reinterpret_as_int64())
    _ => None
  }
}

///|
/// Rust's `u128::from_str_radix`.
fn u128_from_str_radix(s : String, radix : Int) -> Wide? {
  parse_wide(s, radix, false)
}

///|
/// Rust's `i128::from_str_radix`.
fn i128_from_str_radix(s : String, radix : Int) -> Wide? {
  match parse_wide(s, radix, true) {
    Some({ negative: false, hi, .. } as w) if hi <= 0x7FFF_FFFF_FFFF_FFFFUL =>
      Some(w)
    Some({ negative: true, hi, lo, } as w) if hi < 0x8000_0000_0000_0000UL ||
      (hi == 0x8000_0000_0000_0000UL && lo == 0) => Some(w)
    _ => None
  }
}

///|
/// `value as f64` for a 128-bit integer (round to nearest, ties to even),
/// followed by Typst's `IntoValue` for `u128`/`i128` (an `Int` if the value
/// fits into `i64`).
fn Wide::into_data(self : Wide) -> @serde.Data {
  if self.hi == 0 {
    if !self.negative && self.lo <= 0x7FFF_FFFF_FFFF_FFFFUL {
      return Int(self.lo.reinterpret_as_int64())
    }
    if self.negative && self.lo <= 0x8000_0000_0000_0000UL {
      return Int((0UL - self.lo).reinterpret_as_int64())
    }
  }
  let magnitude = if self.hi == 0 {
    self.lo.to_double()
  } else {
    // Keep the top 64 bits and fold the rest into a sticky bit, which gives
    // the same rounding to 53 bits.
    let lz = self.hi.clz()
    let shift = 64 - lz
    let top = if lz == 0 {
      self.hi
    } else {
      (self.hi << lz) | (self.lo >> shift)
    }
    let rest = if lz == 0 { self.lo } else { self.lo << (64 - shift) }
    let top = if rest != 0 { top | 1 } else { top }
    let mut f = top.to_double()
    for _ in 0..<shift {
      f = f * 2.0
    }
    f
  }
  Float(if self.negative { -magnitude } else { magnitude })
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
