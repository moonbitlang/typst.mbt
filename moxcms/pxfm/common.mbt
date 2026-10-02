// Fused multiply-add and Rust float semantics helpers.
//
// `pxfm` (and `moxcms`) run on aarch64 where `f64::mul_add` / `f32::mul_add`
// are single-rounding hardware FMAs. MoonBit has no FMA primitive, so they are
// emulated exactly here.

///|
let two_pow_27_plus_1 : Double = 134217729.0

///|
/// Unbiased exponent of a finite normal double.
fn exponent_of(x : Double) -> Int {
  ((x.reinterpret_as_uint64() >> 52).to_int() & 0x7ff) - 1023
}

///|
/// `2^k` for `-1022 <= k <= 1023`.
fn pow2(k : Int) -> Double {
  ((k + 1023).to_uint64() << 52).reinterpret_as_double()
}

///|
/// Veltkamp split of `a` (|a| < 2^996).
fn split(a : Double) -> (Double, Double) {
  let t1 = two_pow_27_plus_1 * a
  let t2 = a - t1
  let hi = t1 + t2
  (hi, a - hi)
}

///|
/// Exact product `a * b = hi + lo` (Dekker), valid for 1 <= |a|, |b| < 2.
fn two_prod(a : Double, b : Double) -> (Double, Double) {
  let p = a * b
  let (ah, al) = split(a)
  let (bh, bl) = split(b)
  let err = ah * bh - p + ah * bl + al * bh + al * bl
  (p, err)
}

///|
/// Exact sum `a + b = s + e` (Knuth TwoSum).
fn two_sum(a : Double, b : Double) -> (Double, Double) {
  let s = a + b
  let bb = s - a
  let e = a - (s - bb) + (b - bb)
  (s, e)
}

///|
/// `a + b` rounded to odd (assuming no overflow).
fn add_round_to_odd(a : Double, b : Double) -> Double {
  let (s, e) = two_sum(a, b)
  if e == 0.0 || s == 0.0 {
    return s
  }
  let bits = s.reinterpret_as_uint64()
  if (bits & 1UL) != 0UL {
    return s
  }
  let toward_larger_magnitude = (e > 0.0) == (s > 0.0)
  (if toward_larger_magnitude { bits + 1UL } else { bits - 1UL }).reinterpret_as_double()
}

///|
/// Rounds `n * 2^q` (exact) to the nearest double (ties to even).
fn round_bigint_to_double(n : @bigint.BigInt, q : Int) -> Double {
  if n.is_zero() {
    return 0.0
  }
  let neg = n < 0N
  let m = if neg { -n } else { n }
  let l = m.bit_length()
  let e = l - 1 + q
  if e > 1023 {
    return if neg { -1.0 / 0.0 } else { 1.0 / 0.0 }
  }
  let mut lsb = if e >= -1022 { e - 52 } else { -1074 }
  let shift = lsb - q
  let mut mant = if shift <= 0 {
    m << -shift
  } else {
    let t = m >> shift
    let rem = m - (t << shift)
    let half = 1N << (shift - 1)
    if rem > half || (rem == half && (t & 1N) == 1N) {
      t + 1N
    } else {
      t
    }
  }
  if mant.bit_length() > 53 {
    mant = mant >> 1
    lsb += 1
  }
  let mant64 = mant.to_uint64()
  let bits = if mant64 < 0x10000000000000UL {
    // Subnormal (lsb == -1074) or zero.
    mant64
  } else {
    let biased = lsb + 52 + 1023
    if biased >= 2047 {
      return if neg { -1.0 / 0.0 } else { 1.0 / 0.0 }
    }
    (biased.to_uint64() << 52) | (mant64 & 0xfffffffffffffUL)
  }
  let bits = if neg { bits | 0x8000000000000000UL } else { bits }
  bits.reinterpret_as_double()
}

///|
/// Decomposes a finite nonzero double into `(sign_negative, m, q)` with
/// `|x| = m * 2^q`.
fn decompose(x : Double) -> (Bool, UInt64, Int) {
  let bits = x.reinterpret_as_uint64()
  let neg = bits >> 63 != 0UL
  let be = (bits >> 52).to_int() & 0x7ff
  let frac = bits & 0xfffffffffffffUL
  if be == 0 {
    (neg, frac, -1074)
  } else {
    (neg, frac | 0x10000000000000UL, be - 1075)
  }
}

///|
/// Exact FMA through big integers (slow path for extreme exponents).
fn fma_exact(a : Double, b : Double, c : Double) -> Double {
  let (na, ma, qa) = decompose(a)
  let (nb, mb, qb) = decompose(b)
  let (nc, mc, qc) = decompose(c)
  let qp = qa + qb
  let p = @bigint.BigInt::from_uint64(ma) * @bigint.BigInt::from_uint64(mb)
  let p = if na != nb { -p } else { p }
  let cc = @bigint.BigInt::from_uint64(mc)
  let cc = if nc { -cc } else { cc }
  let qmin = if qp < qc { qp } else { qc }
  let sum = (p << (qp - qmin)) + (cc << (qc - qmin))
  round_bigint_to_double(sum, qmin)
}

///|
/// Fused multiply-add `a * b + c` with a single rounding (Rust
/// `f64::mul_add`).
pub fn fma(a : Double, b : Double, c : Double) -> Double {
  if a.is_nan() || b.is_nan() || c.is_nan() || a.is_inf() || b.is_inf() {
    return a * b + c
  }
  if c.is_inf() {
    return c
  }
  if a == 0.0 || b == 0.0 {
    // The product is an exact zero.
    return a * b + c
  }
  if c == 0.0 {
    // RN(a * b + 0) = RN(a * b), including the sign of an underflowed zero.
    return a * b
  }
  let ea = exponent_of(a)
  let eb = exponent_of(b)
  let ec = exponent_of(c)
  if ea == -1023 || eb == -1023 || ec == -1023 {
    return fma_exact(a, b, c)
  }
  let ep = ea + eb
  if ep < -900 || ep > 900 || ec < -900 || ec > 900 {
    return fma_exact(a, b, c)
  }
  // Boldo & Melquiond, "Emulation of FMA and correctly-rounded sums: proved
  // algorithms using rounding to odd".
  let (ph, pl) = two_prod(a * pow2(-ea), b * pow2(-eb))
  let scale = pow2(ep)
  let ph = ph * scale
  let pl = pl * scale
  let (th, tl) = two_sum(c, ph)
  let v = add_round_to_odd(tl, pl)
  th + v
}

///|
/// Fused multiply-add `a * b + c` in single precision (Rust `f32::mul_add`).
pub fn fmaf(a : Float, b : Float, c : Float) -> Float {
  // The product of two floats is exact in double precision; rounding the sum
  // to odd in double precision and then to nearest in single precision gives
  // the correctly rounded result.
  let p = a.to_double() * b.to_double()
  let cd = c.to_double()
  if p.is_nan() || cd.is_nan() || p.is_inf() || cd.is_inf() {
    return Float::from_double(p + cd)
  }
  Float::from_double(add_round_to_odd(p, cd))
}
