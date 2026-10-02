// Port of `pxfm::powf::f_powf` (correctly rounded `f32` power) with the
// aarch64 backend (`GenPowfBackend` with `HAS_FMA = true`, `ERR = 64`).

///|
fn is_integerf(x : Float) -> Bool {
  round_ties_even_f32(x) == x
}

///|
fn is_odd_integerf(x : Float) -> Bool {
  (f32_as_i32(x) & 1) != 0
}

///|
fn larger_exponent(a : Double, b : Double) -> Bool {
  ((a.reinterpret_as_uint64() >> 52) & 0x7ffUL) >=
  ((b.reinterpret_as_uint64() >> 52) & 0x7ffUL)
}

///|
/// Calculates 2^(y * log2(x)) in double-double precision.
fn powf_dd(
  idx_x : Int,
  dx : Double,
  y6 : Double,
  lo6_hi : Double,
  exp2_hi_mid : DoubleDouble,
) -> Double {
  // Perform a second range reduction step:
  //   idx2 = round(2^14 * (dx  + 2^-8)) = round ( dx * 2^14 + 2^6)
  //   dx2 = (1 + dx) * r2 - 1
  let idx2 = f64_as_i64(
    round_f64(
      fma(
        dx,
        0x40d0000000000000UL.reinterpret_as_double(),
        0x4050000000000000UL.reinterpret_as_double(),
      ),
    ),
  ).to_int()
  let dx2 = fma(1.0 + dx, powf_r2[idx2].reinterpret_as_double(), -1.0) // Exact
  let coeffs : FixedArray[UInt64] = [
    0x3c7777d0ffda25e0UL, 0x3ff71547652b82feUL, 0xbc6777d101cf0a84UL, 0xbfe71547652b82feUL,
    0x3c7ce04b5140d867UL, 0x3fdec709dc3a03fdUL, 0x3c7137b47e635be5UL, 0xbfd71547652b82fbUL,
    0xbc5b5a30b3bdb318UL, 0x3fd2776c516a92a2UL, 0x3c62d2fbd081e657UL, 0xbfcec70af1929ca6UL,
  ]
  let c = (i : Int) => {
    DoubleDouble::from_bit_pair(coeffs[2 * i], coeffs[2 * i + 1])
  }
  let dx_dd = DoubleDouble::new(0.0, dx2)
  let p = dd_quick_polyeval6(dx_dd, c(0), c(1), c(2), c(3), c(4), c(5))
  // log2(1 + dx2) ~ dx2 * P(dx2)
  let log2_x_lo = DoubleDouble::quick_mult_f64(p, dx2)
  // Lower parts of (e_x - log2(r1)) of the first range reduction constant
  let log2_x_mid = DoubleDouble::new(
    log2_r_td[idx_x * 3].reinterpret_as_double(),
    log2_r_td[idx_x * 3 + 1].reinterpret_as_double(),
  )
  // -log2(r2) + lower part of (e_x - log2(r1))
  let log2_x_m = DoubleDouble::add(
    DoubleDouble::from_bit_pair(log2_r2_dd[idx2 * 2], log2_r2_dd[idx2 * 2 + 1]),
    log2_x_mid,
  )
  // log2(1 + dx2) - log2(r2) + lower part of (e_x - log2(r1))
  let log2_x = if larger_exponent(log2_x_m.hi, log2_x_lo.hi) {
    DoubleDouble::add(log2_x_m, log2_x_lo)
  } else {
    DoubleDouble::add(log2_x_lo, log2_x_m)
  }
  let lo6_hi_dd = DoubleDouble::new(0.0, lo6_hi)
  // 2^6 * y * (log2(1 + dx2) - log2(r2) + lower part of (e_x - log2(r1)))
  let prod = DoubleDouble::quick_mult_f64(log2_x, y6)
  // 2^6 * (y * log2(x) - (hi + mid)) = 2^6 * lo
  let lo6 = if larger_exponent(prod.hi, lo6_hi) {
    DoubleDouble::add(prod, lo6_hi_dd)
  } else {
    DoubleDouble::add(lo6_hi_dd, prod)
  }
  let exp2_coeffs : FixedArray[UInt64] = [
    0x0000000000000000UL, 0x3ff0000000000000UL, 0x3c1abc9e3b398024UL, 0x3f862e42fefa39efUL,
    0xbba5e43a5429bddbUL, 0x3f0ebfbdff82c58fUL, 0xbb2d33162491268fUL, 0x3e8c6b08d704a0c0UL,
    0x3a94fb32d240a14eUL, 0x3e03b2ab6fba4e77UL, 0x39ee84e916be83e0UL, 0x3d75d87fe78a6731UL,
    0xb989a447bfddc5e6UL, 0x3ce430912f86bfb8UL, 0xb8e31a55719de47fUL, 0x3c4ffcbfc588ded9UL,
    0xb850ba57164eb36bUL, 0x3bb62c034beb8339UL, 0xb7b8483eabd9642dUL, 0x3b1b5251ff97bee1UL,
  ]
  let ec = FixedArray::makei(10, i => {
    DoubleDouble::from_bit_pair(exp2_coeffs[2 * i], exp2_coeffs[2 * i + 1])
  })
  let pp = dd_quick_polyeval10(lo6, ec)
  let rr = DoubleDouble::quick_mult(exp2_hi_mid, pp)
  // Make sure the sum is normalized:
  let r = DoubleDouble::from_exact_add(rr.hi, rr.lo)
  let fraction_mask = (1UL << 52) - 1UL
  let mut r_bits = r.hi.reinterpret_as_uint64()
  if (r_bits & 0xfffffffUL) == 0UL && r.lo != 0.0 {
    let hi_sign = r.hi.reinterpret_as_uint64() >> 63
    let lo_sign = r.lo.reinterpret_as_uint64() >> 63
    if hi_sign == lo_sign {
      r_bits = r_bits + 1UL
    } else if (r_bits & fraction_mask) > 0UL {
      r_bits = r_bits - 1UL
    }
  }
  r_bits.reinterpret_as_double()
}

///|
/// Power function (`pxfm::f_powf`), max found ULP 0.5.
pub fn f_powf(x : Float, y : Float) -> Float {
  let mut x_u = x.reinterpret_as_uint()
  let x_abs = x_u & 0x7fffffffU
  let mut y = y
  let y_u = y.reinterpret_as_uint()
  let y_abs = y_u & 0x7fffffffU
  let mut x = x
  let nan : Float = Float::from_double(0.0 / 0.0)
  let inf : Float = Float::from_double(1.0 / 0.0)
  if (y_abs & 0x0007ffffU) == 0U || y_abs > 0x4f170000U {
    // y is signaling NaN
    if x.is_nan() || y.is_nan() {
      if y.abs() == 0.0 {
        return 1.0
      }
      if x == 1.0 {
        return 1.0
      }
      return nan
    }
    // Exceptional exponents.
    if y == 0.0 {
      return 1.0
    }
    if y_abs == 0x7f800000U {
      if x_abs > 0x7f800000U {
        // pow(NaN, +-Inf) = NaN
        return x
      }
      if x_abs == 0x3f800000U {
        // pow(+-1, +-Inf) = 1.0f
        return 1.0
      }
      if x == 0.0 && y_u == 0xff800000U {
        // pow(+-0, -Inf) = +inf and raise FE_DIVBYZERO
        return inf
      }
      return if (x_abs < 0x3f800000U) == (y_u == 0xff800000U) {
        inf
      } else {
        0.0
      }
    }
    match y_u {
      0x3f000000U => {
        // pow(x, 1/2) = sqrt(x)
        if x == 0.0 || x_u == 0xff800000U {
          return x * x
        }
        let r = x.sqrt()
        return if r.reinterpret_as_uint() != 0x80000000U { r } else { 0.0 }
      }
      0x3f800000U => return x // y = 1.0f
      0x40000000U => return x * x // y = 2.0f
      _ => {
        let is_int = is_integerf(y)
        if is_int && y_u > 0x40000000U && y_u <= 0x41c00000U {
          // Check for exact cases when 2 < y < 25 and y is an integer.
          let mut msb = if x_abs == 0U { 32 - 2 } else { x_abs.clz() }
          msb = if msb > 8 { msb } else { 8 }
          let mut lsb = if x_abs == 0U { 0 } else { x_abs.ctz() }
          lsb = if lsb > 23 { 23 } else { lsb }
          let extra_bits = 32 - 2 - lsb - msb
          let iter = f32_as_i32(y)
          if extra_bits * iter <= 23 + 2 {
            // The result is either exact or exactly half-way.
            // But it is exactly representable in double precision.
            let x_d = x.to_double()
            let mut result = x_d
            for _ in 1..<iter {
              result *= x_d
            }
            return Float::from_double(result)
          }
        }
        if y_abs > 0x4f170000U {
          // if y is NaN
          if y_abs > 0x7f800000U {
            if x_u == 0x3f800000U {
              return 1.0
            }
            return y
          }
          // x^y will be overflow / underflow in single precision.
          y = Float::reinterpret_from_uint((y_u & 0x80000000U) + 0x4f800000U)
        }
      }
    }
  }
  let e_bias = 127
  let mut ex = -e_bias
  let mut sign = 0UL
  if (x_u & 0x801fffffU) == 0U || x_u >= 0x7f800000U || x_u < 0x00800000U {
    if x.is_nan() {
      return nan
    }
    if x_u == 0x3f800000U {
      return 1.0
    }
    let x_is_neg = x.reinterpret_as_uint() > 0x80000000U
    if x == 0.0 {
      let out_is_neg = x_is_neg &&
        is_odd_integerf(Float::reinterpret_from_uint(y_u))
      if y_u > 0x80000000U {
        // pow(0, negative number) = inf
        return if x_is_neg { -inf } else { inf }
      }
      // pow(0, positive number) = 0
      return if out_is_neg { -0.0 } else { 0.0 }
    }
    if x_abs == 0x7f800000U {
      // x = +-Inf
      let out_is_neg = x_is_neg &&
        is_odd_integerf(Float::reinterpret_from_uint(y_u))
      if y_u >= 0x7fffffffU {
        return if out_is_neg { -0.0 } else { 0.0 }
      }
      return if out_is_neg { -inf } else { inf }
    }
    if x_abs > 0x7f800000U {
      // x is NaN.
      return x
    }
    // Normalize denormal inputs.
    if x_abs < 0x00800000U {
      ex = ex - 64
      x *= Float::reinterpret_from_uint(0x5f800000U)
    }
    // x is finite and negative, and y is a finite integer.
    if x.reinterpret_as_uint() >> 31 != 0U {
      if is_integerf(y) {
        x = -x
        if is_odd_integerf(y) {
          sign = 0x8000000000000000UL
        }
      } else {
        // pow( negative, non-integer ) = NaN
        return nan
      }
    }
  }
  // x^y = 2^( y * log2(x) )
  //     = 2^( y * ( e_x + log2(m_x) ) )
  // First we compute log2(x) = e_x + log2(m_x)
  x_u = x.reinterpret_as_uint()
  // Extract exponent field of x.
  ex = ex + (x_u >> 23).reinterpret_as_int()
  let e_x = ex.to_double()
  // Use the highest 7 fractional bits of m_x as the index for look up tables.
  let x_mant = x_u & ((1U << 23) - 1U)
  let idx_x = (x_mant >> (23 - 7)).reinterpret_as_int()
  // Add the hidden bit to the mantissa.
  // 1 <= m_x < 2
  let m_x = Float::reinterpret_from_uint(x_mant | 0x3f800000U)
  // Reduced argument for log2(m_x):
  //   dx = r * m_x - 1.
  // The computation is exact, and -2^-8 <= dx < 2^-7.
  let dx = fmaf(
    m_x,
    Float::reinterpret_from_uint(log_reduction_f32[idx_x]),
    -1.0,
  ).to_double() // Exact.
  // Degree-5 polynomial approximation:
  //   dx * P(dx) ~ log2(1 + dx)
  let coeffs : FixedArray[UInt64] = [
    0x3ff71547652b82feUL, 0xbfe71547652b7a07UL, 0x3fdec709dc458db1UL, 0xbfd715479c2266c9UL,
    0x3fd2776ae1ddf8f0UL, 0xbfce7b2178870157UL,
  ]
  let k = (i : Int) => coeffs[i].reinterpret_as_double()
  let dx2 = dx * dx // Exact
  let c0 = fma(dx, k(1), k(0))
  let c1 = fma(dx, k(3), k(2))
  let c2 = fma(dx, k(5), k(4))
  let p = f_polyeval3(dx2, c0, c1, c2)
  // s = e_x - log2(r) + dx * P(dx)
  let s = fma(dx, p, log2_r[idx_x].reinterpret_as_double() + e_x)
  // In the following computations:
  //   y6  = 2^6 * y
  //   hm  = 2^6 * (hi + mid) = round(2^6 * y * log2(x)) ~ round(y6 * s)
  //   lo6 = 2^6 * lo = 2^6 * (y - (hi + mid)) = y6 * log2(x) - hm.
  let y6 = (y * Float::reinterpret_from_uint(0x42800000U)).to_double() // Exact.
  let hm = round_f64(s * y6)
  // lo6 = 2^6 * lo.
  let lo6_hi = fma(
    y6,
    e_x + log2_r_td[idx_x * 3 + 2].reinterpret_as_double(),
    -hm,
  ) // Exact
  let lo6 = fma(
    y6,
    fma(dx, p, log2_r_td[idx_x * 3 + 1].reinterpret_as_double()),
    lo6_hi,
  )
  // |2^(hi + mid) - exp2_hi_mid| <= ulp(exp2_hi_mid) / 2
  // Clamp the exponent part into smaller range that fits double precision.
  let mut hm_i = hm.to_int64()
  hm_i = if hm_i > 1L << 15 {
    1L << 15
  } else if hm_i < -(1L << 15) {
    -(1L << 15)
  } else {
    hm_i
  }
  let idx_y = (hm_i & 0x3fL).to_int()
  // 2^hi
  let exp_hi_i = hm_i >> 6 << 52
  // 2^mid
  let exp_mid_i = exp2_mid1[idx_y * 2 + 1]
  // (-1)^sign * 2^hi * 2^mid
  let exp2_hi_mid_i = (exp_hi_i + exp_mid_i.reinterpret_as_int64()).reinterpret_as_uint64() +
    sign
  let exp2_hi_mid = exp2_hi_mid_i.reinterpret_as_double()
  // Degree-5 polynomial approximation P(lo6) ~ 2^(lo6 / 2^6) = 2^(lo).
  let exp2_coeffs : FixedArray[UInt64] = [
    0x3ff0000000000000UL, 0x3f862e42fefa39efUL, 0x3f0ebfbdff82a23aUL, 0x3e8c6b08d7076268UL,
    0x3e03b2ad33f8b48bUL, 0x3d75d870c4d84445UL,
  ]
  let e = (i : Int) => exp2_coeffs[i].reinterpret_as_double()
  let lo6_sqr = lo6 * lo6
  let d0 = fma(lo6, e(1), e(0))
  let d1 = fma(lo6, e(3), e(2))
  let d2 = fma(lo6, e(5), e(4))
  let pp = f_polyeval3(lo6_sqr, d0, d1, d2)
  let r = pp * exp2_hi_mid
  let r_u = r.reinterpret_as_uint64()
  let r_upper = Float::from_double((r_u + 64UL).reinterpret_as_double())
  let r_lower = Float::from_double((r_u - 64UL).reinterpret_as_double())
  if r_upper == r_lower {
    return r_upper
  }
  // Scale lower part of 2^(hi + mid)
  let exp2_hi_mid_dd = DoubleDouble::new(
    if idx_y != 0 {
      (exp_hi_i.reinterpret_as_uint64() + exp2_mid1[idx_y * 2]).reinterpret_as_double()
    } else {
      0.0
    },
    exp2_hi_mid,
  )
  let r_dd = powf_dd(idx_x, dx, y6, lo6_hi, exp2_hi_mid_dd)
  Float::from_double(r_dd)
}
