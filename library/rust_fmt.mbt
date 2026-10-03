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
/// double: `x = 0.d1d2d3... * 10^exp` (digits without leading or trailing
/// zeros).
///
/// This is Rust's `core::num::flt2dec::strategy::dragon::format_shortest`
/// (which its Grisu fast path agrees with), including how it picks between
/// two equally short candidates: when the remaining digits are exactly half
/// way, it rounds up.
fn shortest_digits(x : Double) -> (String, Int) {
  match shortest_digits_fast(x) {
    Some(res) => res
    None => shortest_digits_dragon(x)
  }
}

///|
/// Fast path of [shortest_digits] (not upstream; performance): MoonBit's
/// `Double::to_string` also prints the shortest round-trip digits, choosing
/// the candidate closest to the exact value. The two only differ if two
/// shortest candidates are equally close (Rust rounds up, MoonBit to even),
/// which requires the shortest representation to have at least 16 digits:
/// with `n` digits and last-digit weight `10^j`, a tie needs the rounding
/// interval (about one ulp, at most `x * 2^-52`) to span `10^j`, so
/// `10^(j + n) > x >= 10^j * 2^52`, i.e. `10^n > 2^52`. So results with at
/// most 15 digits are taken as is, all others are recomputed exactly.
fn shortest_digits_fast(x : Double) -> (String, Int)? {
  let s = x.abs().to_string()
  let len = s.length()
  // Split off the exponent (`1e+21`, `5e-324`).
  let mut mant_end = len
  let mut exp10 = 0
  for i in 0..<len {
    if s.unsafe_get(i) == 'e' {
      mant_end = i
      let mut j = i + 1
      let mut neg = false
      if j < len && (s.unsafe_get(j) == '+' || s.unsafe_get(j) == '-') {
        neg = s.unsafe_get(j) == '-'
        j += 1
      }
      let mut e = 0
      while j < len {
        let d = s.unsafe_get(j).to_int() - '0'.to_int()
        guard d >= 0 && d <= 9 else { return None }
        e = e * 10 + d
        j += 1
      }
      exp10 = if neg { -e } else { e }
      break
    }
  }
  // The digits without the point, and the number of integer digits.
  let digits = StringBuilder()
  let mut int_len = mant_end
  let mut leading = 0
  let mut seen_nonzero = false
  let mut trailing_zeros = 0
  for i in 0..<mant_end {
    let c = s.unsafe_get(i)
    if c == '.' {
      int_len = i
      continue
    }
    guard c >= '0' && c <= '9' else { return None }
    if !seen_nonzero {
      if c == '0' {
        leading += 1
        continue
      }
      seen_nonzero = true
    }
    if c == '0' {
      trailing_zeros += 1
    } else {
      for _ in 0..<trailing_zeros {
        digits.write_char('0')
      }
      trailing_zeros = 0
      digits.write_char(c.unsafe_to_char())
    }
  }
  let digits = digits.to_string()
  guard digits.length() > 0 && digits.length() <= 15 else { return None }
  Some((digits, int_len - leading + exp10))
}

///|
/// The exact computation of [shortest_digits] (Rust's Dragon4 shortest
/// mode).
fn shortest_digits_dragon(x : Double) -> (String, Int) {
  // `flt2dec::decode`: the value is `mant * 2^exp`, its neighbors are
  // `(mant - minus) * 2^exp` and `(mant + plus) * 2^exp` (half way to the
  // adjacent floats), inclusive if the original mantissa is even.
  let bits = x.abs().reinterpret_as_uint64()
  let biased = ((bits >> 52) & 0x7FFUL).to_int()
  let frac = bits & 0xFFFFFFFFFFFFFUL
  let (raw_mant, raw_exp) = if biased == 0 {
    (frac << 1, -1075)
  } else {
    (frac | 0x10000000000000UL, biased - 1075)
  }
  shortest_digits_decoded(
    raw_mant,
    raw_exp,
    biased == 0,
    raw_mant == 0x10000000000000UL,
    x.abs(),
  )
}

///|
/// The shortest round-trip digits of an `f32` (see [shortest_digits]).
fn shortest_digits_f32(x : Float) -> (String, Int) {
  // `flt2dec::decode` for `f32`.
  let bits = x.abs().reinterpret_as_uint()
  let biased = ((bits >> 23) & 0xFF).reinterpret_as_int()
  let frac = (bits & 0x7FFFFF).to_uint64()
  let (raw_mant, raw_exp) = if biased == 0 {
    (frac << 1, -150)
  } else {
    (frac | 0x800000UL, biased - 150)
  }
  shortest_digits_decoded(
    raw_mant,
    raw_exp,
    biased == 0,
    raw_mant == 0x800000UL,
    x.abs().to_double(),
  )
}

///|
/// Rust's `impl Display for f32` (`{}`): shortest round-trip digits (for
/// `f32`), never using exponent notation.
pub fn rust_display_f32(x : Float) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x.reinterpret_as_uint() >> 31 == 1
  let sign = if neg { "-" } else { "" }
  if x.is_inf() {
    return sign + "inf"
  }
  if x == 0.0 {
    return sign + "0"
  }
  let (digits, point) = shortest_digits_f32(x)
  sign + place_point(digits, point, 0)
}

///|
/// Dragon4 shortest digits of `raw_mant * 2^raw_exp` (Rust's
/// `format_shortest` after `decode`); `approx` is the (absolute) value, used
/// for the initial exponent estimate only.
fn shortest_digits_decoded(
  raw_mant : UInt64,
  raw_exp : Int,
  subnormal : Bool,
  boundary : Bool,
  approx : Double,
) -> (String, Int) {
  let inclusive = (raw_mant & 1UL) == 0UL
  let (mant, minus, plus, exp) = if subnormal {
    (raw_mant, 1, 1, raw_exp)
  } else if boundary {
    (raw_mant << 2, 1, 2, raw_exp - 2)
  } else {
    (raw_mant << 1, 1, 1, raw_exp - 1)
  }
  let mut r = @bigint.BigInt::from_uint64(mant)
  let mut m_minus = @bigint.BigInt::from_int(minus)
  let mut m_plus = @bigint.BigInt::from_int(plus)
  let mut s = @bigint.BigInt::from_int(1)
  if exp < 0 {
    s = s << -exp
  } else {
    r = r << exp
    m_minus = m_minus << exp
    m_plus = m_plus << exp
  }
  // `a < b` with the bound inclusiveness (`cmp(a, b) < rounding`).
  let below = (a : @bigint.BigInt, b : @bigint.BigInt) => {
    if inclusive {
      a <= b
    } else {
      a < b
    }
  }
  // Find the exponent `k`: the smallest with `r + plus < 10^k * s` (or `<=`
  // if exclusive), comparing exactly by scaling the other side for negative
  // powers.
  let ten = @bigint.BigInt::from_int(10)
  let upper = r + m_plus
  let scaled_below = (k : Int) => {
    if k >= 0 {
      below(s * ten.pow(@bigint.BigInt::from_int(k)), upper)
    } else {
      below(s, upper * ten.pow(@bigint.BigInt::from_int(-k)))
    }
  }
  let mut k = @math.log10(approx).floor().to_int()
  while scaled_below(k) {
    k += 1
  }
  while !scaled_below(k - 1) {
    k -= 1
  }
  // Generate digits from the `10^(k-1)` position: scale the numerator side
  // instead of the denominator for negative positions.
  let (r0, mm0, mp0, s0) = if k - 1 >= 0 {
    (r, m_minus, m_plus, s * ten.pow(@bigint.BigInt::from_int(k - 1)))
  } else {
    let f = ten.pow(@bigint.BigInt::from_int(1 - k))
    (r * f, m_minus * f, m_plus * f, s)
  }
  let mut r = r0
  let mut m_minus = mm0
  let mut m_plus = mp0
  let scale = s0
  let digits = []
  let mut down = false
  let mut up = false
  for ;; {
    let d = r / scale
    r = r % scale
    digits.push(d.to_int())
    down = below(r, m_minus)
    up = below(scale, r + m_plus)
    if down || up {
      break
    }
    r = r * ten
    m_minus = m_minus * ten
    m_plus = m_plus * ten
  }
  // Round up if we stopped closer to (or exactly half way to) the upper
  // candidate.
  if up && (!down || r + r >= scale) {
    let mut i = digits.length() - 1
    while i >= 0 && digits[i] == 9 {
      digits[i] = 0
      i -= 1
    }
    if i < 0 {
      digits[0] = 1
      digits.push(0)
      k += 1
    } else {
      digits[i] += 1
    }
  }
  while digits.length() > 1 && digits[digits.length() - 1] == 0 {
    digits.pop() |> ignore
  }
  let buf = StringBuilder()
  for d in digits {
    buf.write_char(Int::unsafe_to_char(48 + d))
  }
  (buf.to_string(), k)
}

///|
/// Rust's `impl Display for f64` (`{}`): shortest round-trip digits, never
/// using exponent notation.
pub fn rust_display_f64(x : Double) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x < 0.0 || (x == 0.0 && 1.0 / x < 0.0)
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
/// Rust's `impl Debug for f64` (`{:?}`): like Display but always with a
/// fractional part, and in exponent notation when `|x| < 1e-4` or
/// `|x| >= 1e16`.
pub fn rust_debug_f64(x : Double) -> String {
  if x.is_nan() {
    return "NaN"
  }
  let neg = x < 0.0 || (x == 0.0 && 1.0 / x < 0.0)
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
  let neg = x < 0.0 || (x == 0.0 && 1.0 / x < 0.0)
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
    (
      mb * ten_p * @bigint.BigInt::from_int(2).pow(@bigint.BigInt::from_int(e)),
      @bigint.BigInt::from_int(1),
    )
  } else {
    (mb * ten_p, @bigint.BigInt::from_int(2).pow(@bigint.BigInt::from_int(-e)))
  }
  let q = num / den
  let r = num - q * den
  let twice = r * @bigint.BigInt::from_int(2)
  let q = if twice > den ||
    (
      twice == den &&
      q % @bigint.BigInt::from_int(2) != @bigint.BigInt::from_int(0)
    ) {
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
