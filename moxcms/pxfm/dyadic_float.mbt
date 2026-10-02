// Port of `pxfm::dyadic_float` (128-bit dyadic floats) and the dyadic
// `log` / `exp` helpers used by `f_pow`'s accurate fallback
// (`pow_rational128`).

///|
/// Unsigned 128-bit integer emulation.
priv struct U128 {
  hi : UInt64
  lo : UInt64
}

///|
fn U128::new(hi : UInt64, lo : UInt64) -> U128 {
  { hi, lo, }
}

///|
fn U128::is_zero(self : U128) -> Bool {
  self.hi == 0UL && self.lo == 0UL
}

///|
/// `self.wrapping_shr(n)`.
fn U128::shr(self : U128, n : Int) -> U128 {
  let n = n & 127
  if n == 0 {
    self
  } else if n < 64 {
    { hi: self.hi >> n, lo: (self.lo >> n) | (self.hi << (64 - n)), }
  } else {
    { hi: 0UL, lo: self.hi >> (n - 64), }
  }
}

///|
/// `self.wrapping_shl(n)`.
fn U128::shl(self : U128, n : Int) -> U128 {
  let n = n & 127
  if n == 0 {
    self
  } else if n < 64 {
    { hi: (self.hi << n) | (self.lo >> (64 - n)), lo: self.lo << n, }
  } else {
    { hi: self.lo << (n - 64), lo: 0UL, }
  }
}

///|
fn U128::overflowing_add(a : U128, b : U128) -> (U128, Bool) {
  let lo = a.lo + b.lo
  let c = if lo < a.lo { 1UL } else { 0UL }
  let hi1 = a.hi + b.hi
  let o1 = hi1 < a.hi
  let hi = hi1 + c
  let o2 = hi < hi1
  ({ hi, lo, }, o1 || o2)
}

///|
fn U128::wrapping_add(a : U128, b : U128) -> U128 {
  U128::overflowing_add(a, b).0
}

///|
fn U128::wrapping_sub(a : U128, b : U128) -> U128 {
  let lo = a.lo - b.lo
  let borrow = if a.lo < b.lo { 1UL } else { 0UL }
  { hi: a.hi - b.hi - borrow, lo, }
}

///|
fn U128::ge(a : U128, b : U128) -> Bool {
  a.hi > b.hi || (a.hi == b.hi && a.lo >= b.lo)
}

///|
fn U128::leading_zeros(self : U128) -> Int {
  if self.hi != 0UL {
    self.hi.clz()
  } else {
    64 + self.lo.clz()
  }
}

///|
/// Full 64x64 -> 128 bit product.
fn mul_u64(a : UInt64, b : UInt64) -> U128 {
  let mask = 0xffffffffUL
  let a0 = a & mask
  let a1 = a >> 32
  let b0 = b & mask
  let b1 = b >> 32
  let p00 = a0 * b0
  let p01 = a0 * b1
  let p10 = a1 * b0
  let p11 = a1 * b1
  let mid = (p00 >> 32) + (p01 & mask) + (p10 & mask)
  let lo = (p00 & mask) | (mid << 32)
  let hi = p11 + (p01 >> 32) + (p10 >> 32) + (mid >> 32)
  { hi, lo, }
}

///|
fn mulhi_u128(a : U128, b : U128) -> U128 {
  let lo_lo = mul_u64(a.lo, b.lo)
  let lo_hi = mul_u64(a.lo, b.hi)
  let hi_lo = mul_u64(a.hi, b.lo)
  let hi_hi = mul_u64(a.hi, b.hi)
  let carry = lo_lo
    .shr(64)
    .wrapping_add(U128::new(0UL, lo_hi.lo))
    .wrapping_add(U128::new(0UL, hi_lo.lo))
  let mid = lo_hi
    .shr(64)
    .wrapping_add(hi_lo.shr(64))
    .wrapping_add(carry.shr(64))
  hi_hi.wrapping_add(mid)
}

///|
priv struct DyadicFloat128 {
  mut neg : Bool
  mut exponent : Int
  mut mantissa : U128
}

///|
fn dyadic(
  neg : Bool,
  exponent : Int,
  hi : UInt64,
  lo : UInt64,
) -> DyadicFloat128 {
  { neg, exponent, mantissa: U128::new(hi, lo), }
}

///|
fn DyadicFloat128::zero() -> DyadicFloat128 {
  { neg: false, exponent: 0, mantissa: U128::new(0UL, 0UL), }
}

///|
fn DyadicFloat128::copy(self : DyadicFloat128) -> DyadicFloat128 {
  { neg: self.neg, exponent: self.exponent, mantissa: self.mantissa, }
}

///|
fn DyadicFloat128::normalize(self : DyadicFloat128) -> Unit {
  if !self.mantissa.is_zero() {
    let shift_length = self.mantissa.leading_zeros()
    self.exponent -= shift_length
    self.mantissa = self.mantissa.shl(shift_length)
  }
}

///|
fn DyadicFloat128::new_from_f64(x : Double) -> DyadicFloat128 {
  let bits = x.reinterpret_as_uint64()
  let neg = bits >> 63 != 0UL
  let biased = ((bits >> 52) & 0x7ffUL).to_int()
  let sig = bits & 0xfffffffffffffUL
  let (exp, mant) = if x == 0.0 {
    (0, sig)
  } else if biased == 0 {
    // subnormal
    (1 - 1023, sig)
  } else {
    (biased - 1023, sig | (1UL << 52))
  }
  let r = { neg, exponent: exp - 52, mantissa: U128::new(0UL, mant), }
  r.normalize()
  r
}

///|
fn DyadicFloat128::shift_right(self : DyadicFloat128, amount : Int) -> Unit {
  if amount < 128 {
    self.exponent += amount
    self.mantissa = self.mantissa.shr(amount)
  } else {
    self.exponent = 0
    self.mantissa = U128::new(0UL, 0UL)
  }
}

///|
fn DyadicFloat128::shift_left(self : DyadicFloat128, amount : Int) -> Unit {
  if amount < 128 {
    self.exponent -= amount
    self.mantissa = self.mantissa.shl(amount)
  } else {
    self.exponent = 0
    self.mantissa = U128::new(0UL, 0UL)
  }
}

///|
fn DyadicFloat128::add(
  self : DyadicFloat128,
  rhs : DyadicFloat128,
) -> DyadicFloat128 {
  if self.mantissa.is_zero() {
    return rhs.copy()
  }
  if rhs.mantissa.is_zero() {
    return self.copy()
  }
  let a = self.copy()
  let b = rhs.copy()
  let exp_diff = a.exponent - b.exponent
  // If exponent difference is too large, b is negligible
  if exp_diff.abs() >= 128 {
    return if a.exponent > b.exponent { a } else { b }
  }
  // Align exponents
  if a.exponent > b.exponent {
    b.shift_right(a.exponent - b.exponent)
  } else if b.exponent > a.exponent {
    a.shift_right(b.exponent - a.exponent)
  }
  let result = DyadicFloat128::zero()
  if a.neg == b.neg {
    // Addition
    result.neg = a.neg
    result.exponent = a.exponent
    let (sum, is_overflow) = U128::overflowing_add(a.mantissa, b.mantissa)
    result.mantissa = sum
    if is_overflow {
      // Mantissa addition overflow.
      result.shift_right(1)
      result.mantissa = U128::new(
        result.mantissa.hi | (1UL << 63),
        result.mantissa.lo,
      )
    }
    // Result is already normalized.
    return result
  }
  // Subtraction
  if a.mantissa.ge(b.mantissa) {
    result.neg = a.neg
    result.exponent = a.exponent
    result.mantissa = a.mantissa.wrapping_sub(b.mantissa)
  } else {
    result.neg = b.neg
    result.exponent = b.exponent
    result.mantissa = b.mantissa.wrapping_sub(a.mantissa)
  }
  result.normalize()
  result
}

///|
fn DyadicFloat128::mul(
  self : DyadicFloat128,
  rhs : DyadicFloat128,
) -> DyadicFloat128 {
  let result = {
    neg: self.neg != rhs.neg,
    exponent: self.exponent + rhs.exponent + 128,
    mantissa: U128::new(0UL, 0UL),
  }
  if !(self.mantissa.is_zero() || rhs.mantissa.is_zero()) {
    result.mantissa = mulhi_u128(self.mantissa, rhs.mantissa)
    // Check the leading bit directly.
    if result.mantissa.hi >> 63 == 0UL {
      result.shift_left(1)
    }
  }
  result
}

///|
/// Multiply self by integer scalar `b`.
fn DyadicFloat128::mul_int64(
  self : DyadicFloat128,
  b : Int64,
) -> DyadicFloat128 {
  if b == 0L {
    return DyadicFloat128::zero()
  }
  let abs_b = (if b < 0L { -b } else { b }).reinterpret_as_uint64()
  let neg = (b < 0L) != self.neg
  let mut hi_prod = mul_u64(self.mantissa.hi, abs_b)
  let m = hi_prod.leading_zeros()
  hi_prod = hi_prod.shl(m)
  let mut lo_prod = mul_u64(self.mantissa.lo, abs_b)
  lo_prod = lo_prod.shl(m - 1).shr(63)
  let (product, overflow) = U128::overflowing_add(hi_prod, lo_prod)
  let result = { neg, exponent: self.exponent + 64 - m, mantissa: product, }
  if overflow {
    // Overflow means an implicit bit in the 129th place, which we shift down.
    let product = product.wrapping_add(U128::new(0UL, product.lo & 1UL))
    let shifted = product.shr(1)
    result.mantissa = U128::new(shifted.hi | (1UL << 63), shifted.lo)
    result.shift_right(1)
  }
  result.normalize()
  result
}

///|
fn DyadicFloat128::trunc_to_i64(self : DyadicFloat128) -> Int64 {
  if self.exponent <= -128 {
    return 0L
  }
  let hi = self.mantissa.hi
  let norm_exp = self.exponent + 127
  if norm_exp > 63 {
    return if self.neg { -9223372036854775808L } else { 9223372036854775807L }
  }
  let r = (hi >> (63 - norm_exp)).reinterpret_as_int64()
  if self.neg {
    -r
  } else {
    r
  }
}

///|
fn f64_from_parts(neg : Bool, exp : UInt64, mantissa : UInt64) -> Double {
  let r_sign = if neg { 1UL << 63 } else { 0UL }
  (r_sign | (exp << 52) | mantissa).reinterpret_as_double()
}

///|
fn DyadicFloat128::fast_as_f64(self : DyadicFloat128) -> Double {
  if self.mantissa.is_zero() {
    return if !self.neg { 0.0 } else { -0.0 }
  }
  // Assume that it is normalized, and output is also normal.
  let precision = 53
  let sig_mask = (1UL << 52) - 1UL
  let exp_bias = 1023
  let mut exp_hi = self.exponent + 127 + exp_bias
  if exp_hi > 2 * exp_bias {
    // Results overflow.
    let d_hi = f64_from_parts(self.neg, (2 * exp_bias).to_uint64(), 0UL)
    return 2.0 * d_hi
  }
  let mut denorm = false
  let mut shift = 128 - precision
  if exp_hi <= 0 {
    // Output is denormal.
    denorm = true
    shift = 128 - precision + (1 - exp_hi)
    exp_hi = exp_bias
  }
  let exp_lo = exp_hi - precision - 1
  let m_hi = if shift >= 128 {
    U128::new(0UL, 0UL)
  } else {
    self.mantissa.shr(shift)
  }
  let d_hi = f64_from_parts(self.neg, exp_hi.to_uint64(), m_hi.lo & sig_mask)
  let round_mask = if shift > 128 {
    U128::new(0UL, 0UL)
  } else {
    U128::new(0UL, 1UL).shl(shift - 1)
  }
  let sticky_mask = round_mask.wrapping_sub(U128::new(0UL, 1UL))
  let round_bit = (self.mantissa.hi & round_mask.hi) != 0UL ||
    (self.mantissa.lo & round_mask.lo) != 0UL
  let sticky_bit = (self.mantissa.hi & sticky_mask.hi) != 0UL ||
    (self.mantissa.lo & sticky_mask.lo) != 0UL
  let round_and_sticky = (if round_bit { 2 } else { 0 }) +
    (if sticky_bit { 1 } else { 0 })
  if exp_lo <= 0 {
    // d_lo is denormal, but the output is normal.
    let scale_up_exponent = 1 - exp_lo
    let scale_up_factor = f64_from_parts(
      false,
      (exp_bias + scale_up_exponent).to_uint64(),
      0UL,
    )
    let scale_down_factor = f64_from_parts(
      false,
      (exp_bias - scale_up_exponent).to_uint64(),
      0UL,
    )
    let d_lo = f64_from_parts(
      self.neg,
      (exp_lo + scale_up_exponent).to_uint64(),
      0UL,
    )
    return fma(d_lo, round_and_sticky.to_double(), d_hi * scale_up_factor) *
      scale_down_factor
  }
  let d_lo = f64_from_parts(self.neg, exp_lo.to_uint64(), 0UL)
  let r = fma(d_lo, round_and_sticky.to_double(), d_hi)
  if denorm {
    // Exponent before rounding is in denormal range, simply clear the
    // exponent field.
    let clear_exp = exp_hi.to_uint64() << 52
    let r_bits = r.reinterpret_as_uint64() - clear_exp
    return r_bits.reinterpret_as_double()
  }
  r
}

///|
/// Arithmetic (flooring) right shift of a big integer, like Rust's `i128 >>`.
fn floor_shr(x : @bigint.BigInt, n : Int) -> @bigint.BigInt {
  if x < 0N {
    -((-x + ((1N << n) - 1N)) >> n)
  } else {
    x >> n
  }
}

///|
/// Logarithm range reduction steps 2-4 (`log_range_reduction`).
fn log_range_reduction(
  m_x : Double,
  sum : DyadicFloat128,
) -> (DyadicFloat128, DyadicFloat128) {
  let v = (m_x * 0x43b0000000000000UL.reinterpret_as_double()).to_int64() // ulp = 2^-60
  // Range reduction - Step 2
  let idx2 = ((v + 0x10200000000000L) >> 46).to_int()
  let z0 = log_step_2[idx2]
  let mut sum = sum.add(z0)
  let s2 = log_s2[idx2].to_int64()
  let sv2 = s2 * v
  let spv2 = (s2 << 44) + v
  let vv2 = (spv2 << 16) + sv2
  // Range reduction - Step 3
  let idx3 = ((vv2 + 0x2840000000000000L) >> 55).to_int()
  sum = sum.add(log_step_3[idx3])
  let s3 = log_s3[idx3].to_int64()
  let spv3 = (s3 << 55) + vv2
  let sv3 = @bigint.BigInt::from_int64(s3) * @bigint.BigInt::from_int64(vv2)
  let vv3 = (@bigint.BigInt::from_int64(spv3) << 21) + sv3
  // Range reduction - Step 4
  let idx4 = (floor_shr(vv3, 68).to_int() + 131) >> 1
  let z4 = log_step_4[idx4]
  sum = sum.add(z4)
  let s4 = @bigint.BigInt::from_int(log_s4[idx4])
  let spv4 = (s4 << 69) + vv3
  let sv4 = s4 * vv3
  let vv4 = (spv4 << 28) + sv4
  let neg = vv4 < 0N
  let a = if neg { -vv4 } else { vv4 }
  let mask = (1N << 64) - 1N
  let z0 = {
    neg,
    exponent: -125,
    mantissa: U128::new((a >> 64).to_uint64(), (a & mask).to_uint64()),
  }
  z0.normalize()
  (z0, sum)
}

///|
fn log_accurate(e_x : Int, index : Int, m_x : Double) -> DyadicFloat128 {
  let big_coeffs : FixedArray[DyadicFloat128] = [
    dyadic(true, -129, 0x800000000006a710UL, 0xb59c58e5554d581cUL),
    dyadic(false, -129, 0xaaaaaaaaaaaaaabdUL, 0xde05c7c94ae9cbaeUL),
    dyadic(true, -128, 0x8000000000000000UL, 0x0000000000000000UL),
  ]
  let log_2 = dyadic(false, -128, 0xb17217f7d1cf79abUL, 0xc9e3b39803f2f6afUL)
  let e_x_f128 = DyadicFloat128::new_from_f64(e_x.to_double())
  let mut sum = log_2.mul(e_x_f128)
  sum = sum.add(log_step_1[index])
  let (v_f128, sum1) = log_range_reduction(m_x, sum)
  sum = sum1.add(v_f128)
  // Polynomial approximation
  let mut p = v_f128.mul(big_coeffs[0])
  p = v_f128.mul(p.add(big_coeffs[1]))
  p = v_f128.mul(p.add(big_coeffs[2]))
  p = v_f128.mul(p)
  sum.add(p)
}

///|
/// Assumes that NaN and infinities, negatives were filtered out.
fn log_dyadic(x : Double) -> DyadicFloat128 {
  let mut x_u = x.reinterpret_as_uint64()
  let mut x_e = -1023
  if x_u == 0x3ff0000000000000UL {
    // log2(1.0) = +0.0
    return DyadicFloat128::zero()
  }
  if x_u < 0x0010000000000000UL || x_u > 0x7fefffffffffffffUL {
    // Normalize denormal inputs.
    x_u = (x * 0x4330000000000000UL.reinterpret_as_double()).reinterpret_as_uint64()
    x_e -= 52
  }
  // Range reduction for log2(x_m):
  let shifted = (x_u >> 45).to_int()
  let index = shifted & 0x7f
  let r = log_range_reduction_table[index].reinterpret_as_double()
  // Add unbiased exponent. Add an extra 1 if the 8 leading fractional bits are
  // all 1's.
  x_e = x_e + ((x_u + (1UL << 45)) >> 52).to_int()
  // Set m = 1.mantissa.
  let x_m = (x_u & 0x000fffffffffffffUL) | 0x3ff0000000000000UL
  let m = x_m.reinterpret_as_double()
  let u = fma(r, m, -1.0) // exact
  log_accurate(x_e, index, u)
}

///|
fn exp_dyadic_poly(x : DyadicFloat128) -> DyadicFloat128 {
  let q_2 : FixedArray[DyadicFloat128] = [
    dyadic(false, -128, 0xffffffffffffffffUL, 0xffffffffffffffd0UL),
    dyadic(false, -127, 0x8000000000000000UL, 0x0000000000000088UL),
    dyadic(false, -128, 0x8000000000000000UL, 0x0000000c06f3cd29UL),
    dyadic(false, -130, 0xaaaaaaaaaaaaaaaaUL, 0xaaaaaa6a1e0776aeUL),
    dyadic(false, -132, 0xaaaaaaaaaaaaaaa3UL, 0x0000000000000000UL),
    dyadic(false, -134, 0x8888888888888897UL, 0x0000000000000000UL),
    dyadic(false, -137, 0xb60b60b932146a54UL, 0x0000000000000000UL),
    dyadic(false, -140, 0xd00d00cd98416862UL, 0x0000000000000000UL),
  ]
  let mut p = q_2[7]
  for i = 6; i >= 0; i = i - 1 {
    p = x.mul(p).add(q_2[i])
  }
  p
}

///|
/// Puts in r an approximation of exp(x), for |x| < 744.45, with relative
/// error < 2^-121.70.
fn exp_dyadic(x : DyadicFloat128) -> DyadicFloat128 {
  let ex = x.exponent + 127
  if ex >= 10 {
    // underflow or overflow
    return {
      neg: false,
      exponent: if x.neg {
        -1076
      } else {
        1025
      },
      mantissa: x.mantissa,
    }
  }
  let log2_inv = dyadic(false, -115, 0xb8aa3b295c17f0bcUL, 0UL)
  let log2 = dyadic(false, -128, 0xb17217f7d1cf79abUL, 0xc9e3b39803f2f6afUL)
  let mut bk = x.mul(log2_inv)
  let k = bk.trunc_to_i64() // k = trunc(K) [rounded towards zero, exact]
  bk = log2.mul_int64(k)
  bk.exponent -= 12
  bk.neg = !bk.neg
  let y = x.add(bk)
  let bm = k >> 12
  let i2 = ((k >> 6) & 0x3fL).to_int()
  let i1 = (k & 0x3fL).to_int()
  let mut r = exp_dyadic_poly(y)
  r = exp_t1_2_dyadic[i2].mul(r)
  r = exp_t2_2_dyadic[i1].mul(r)
  r.exponent += bm.to_int() // exact
  r
}

///|
fn pow_rational128(x : Double, y : Double, s : Double) -> Double {
  let f_y = DyadicFloat128::new_from_f64(y)
  let r = log_dyadic(x).mul(f_y)
  let result = exp_dyadic(r)
  // 2^R.ex <= R < 2^(R.ex+1)
  result.neg = s == -1.0
  result.fast_as_f64()
}
