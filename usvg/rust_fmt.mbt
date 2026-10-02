// Copies of the Rust float formatting helpers of `library/rust_fmt.mbt`
// (`impl Display for f32/f64`), which usvg cannot import.

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
fn rust_display_f32(x : Float) -> String {
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
fn rust_display_f64(x : Double) -> String {
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
