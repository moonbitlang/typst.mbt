///|
/// The exact decimal expansion of the magnitude of a finite double:
/// `0.d1 d2 .. dn × 10^point`, most significant digit first, `d1 != 0`
/// (no digits at all for zero).
///
/// Every finite double is `m × 2^e` with an integer `m < 2^53`, so it has a
/// finite decimal expansion: `m × 2^e` is an integer for `e >= 0`, and
/// `m × 5^k / 10^k` for `e = -k < 0`. Both are one big integer, which only
/// has to be multiplied by small numbers; rounding is then done on its
/// digits, without any floating-point operation.
priv struct Decimal {
  digits : Array[Int]
  point : Int
}

///|
/// The base of the limbs of the big integer: nine decimal digits each, the
/// least significant limb first.
const LIMB : UInt64 = 1_000_000_000UL

///|
/// `limbs := limbs × factor`, for `factor < 2^31`.
///
/// A limb is below `10^9 < 2^30` and the carry below `2^31`, so the sum
/// below is less than `2^62`.
fn mul_small(limbs : Array[UInt64], factor : UInt64) -> Unit {
  let mut carry = 0UL
  for i in 0..<limbs.length() {
    let t = limbs[i] * factor + carry
    limbs[i] = t % LIMB
    carry = t / LIMB
  }
  while carry > 0UL {
    limbs.push(carry % LIMB)
    carry = carry / LIMB
  }
}

///|
/// The expansion of `|x|`. `x` must be finite.
fn Decimal::of(x : Double) -> Decimal {
  let bits = x.reinterpret_as_uint64()
  let biased = ((bits >> 52) & 0x7FFUL).to_int()
  let fraction = bits & 0x000F_FFFF_FFFF_FFFFUL
  // |x| = m × 2^e (subnormal numbers have no implicit leading bit).
  let (m, e) = if biased == 0 {
    (fraction, -1074)
  } else {
    (fraction | (1UL << 52), biased - 1075)
  }
  if m == 0UL {
    return { digits: [], point: 0, }
  }
  let limbs : Array[UInt64] = []
  let mut rest = m
  while rest > 0UL {
    limbs.push(rest % LIMB)
    rest = rest / LIMB
  }
  if e >= 0 {
    let mut left = e
    while left > 0 {
      let step = if left > 29 { 29 } else { left }
      mul_small(limbs, 1UL << step)
      left -= step
    }
  } else {
    // 5^13 = 1220703125 < 2^31.
    let mut left = -e
    while left >= 13 {
      mul_small(limbs, 1220703125UL)
      left -= 13
    }
    let mut factor = 1UL
    for _ in 0..<left {
      factor = factor * 5UL
    }
    mul_small(limbs, factor)
  }
  // The top limb is not zero: `mul_small` only pushes non-zero carries, and
  // neither did the loop that split `m`.
  let digits : Array[Int] = []
  for i = limbs.length() - 1; i >= 0; i = i - 1 {
    let limb = limbs[i].to_int()
    let mut div = 100_000_000
    let mut started = i < limbs.length() - 1
    while div > 0 {
      let d = limb / div % 10
      if started || d != 0 {
        started = true
        digits.push(d)
      }
      div = div / 10
    }
  }
  { digits, point: digits.length() + (if e < 0 { e } else { 0 }), }
}

///|
/// The digits of the integer nearest to `|x| × 10^scale`, a tie going to the
/// larger one (half away from zero, since this is the magnitude); most
/// significant first, without leading zeros, and no digits for zero.
///
/// `|x| × 10^scale` is `0.d1 d2 .. × 10^keep`: the first `keep` digits are
/// its integer part, and it is at least half a unit above that integer
/// exactly when the next digit is 5 or more, because the expansion is the
/// whole number and not an approximation of it.
fn Decimal::rounded(self : Decimal, scale : Int) -> Array[Int] {
  let n = self.digits.length()
  let keep = self.point + scale
  // `keep < 0`: the value is below `10^keep <= 0.1`.
  if n == 0 || keep < 0 {
    return []
  }
  let out : Array[Int] = []
  for i in 0..<keep {
    out.push(if i < n { self.digits[i] } else { 0 })
  }
  if keep < n && self.digits[keep] >= 5 {
    let mut i = keep - 1
    while i >= 0 && out[i] == 9 {
      out[i] = 0
      i -= 1
    }
    if i >= 0 {
      out[i] += 1
    } else {
      out.insert(0, 1)
    }
  }
  out
}
