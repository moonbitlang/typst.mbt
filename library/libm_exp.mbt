// Exponential functions of the `libm` crate (0.2, a port of musl): `exp`,
// `exp2`, `exp10`, `expm1` and their helpers, which upstream uses for
// `calc.exp`, `calc.pow` (typst-library/src/foundations/calc.rs) and
// `round_with_precision` (typst-utils/src/round.rs).
//
// `@math.exp`/`expm1` are ports of the same FreeBSD sources, but differ in
// details (`@math.exp(1.0)` is special-cased to the correctly rounded `e`,
// while `libm::exp(1.0)` is one ulp above it), and `@math` has no `exp2`.
// Results must match upstream bit for bit: they are printed with all digits
// (`#calc.exp(1)`), see `libm_wbtest.mbt`.

// origin: FreeBSD /usr/src/lib/msun/src/e_exp.c, s_expm1.c
// ====================================================
// Copyright (C) 2004 by Sun Microsystems, Inc. All rights reserved.
//
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

///|
const LIBM_LN2_HI : Double = 6.93147180369123816490e-01 // 0x3fe62e42, 0xfee00000

///|
const LIBM_LN2_LO : Double = 1.90821492927058770002e-10 // 0x3dea39ef, 0x35793c76

///|
const LIBM_INVLN2 : Double = 1.44269504088896338700e+00 // 0x3ff71547, 0x652b82fe

///|
const LIBM_P1 : Double = 1.66666666666666019037e-01 // 0x3FC55555, 0x5555553E

///|
const LIBM_P2 : Double = -2.77777777770155933842e-03 // 0xBF66C16C, 0x16BEBD93

///|
const LIBM_P3 : Double = 6.61375632143793436117e-05 // 0x3F11566A, 0xAF25DE2C

///|
const LIBM_P4 : Double = -1.65339022054652515390e-06 // 0xBEBBBD41, 0xC5D26BF1

///|
const LIBM_P5 : Double = 4.13813679705723846039e-08 // 0x3E663769, 0x72BEA4D0

///|
/// `0x1p1023`.
const LIBM_X1P1023 : UInt64 = 0x7fe0000000000000UL

///|
/// `with_set_high_word`.
fn libm_with_set_high_word(f : Double, hi : UInt) -> Double {
  let mut tmp = f.reinterpret_as_uint64()
  tmp = tmp & 0x00000000_ffffffffUL
  tmp = tmp | (hi.to_uint64() << 32)
  tmp.reinterpret_as_double()
}

///|
/// `with_set_low_word`.
fn libm_with_set_low_word(f : Double, lo : UInt) -> Double {
  let mut tmp = f.reinterpret_as_uint64()
  tmp = tmp & 0xffffffff_00000000UL
  tmp = tmp | lo.to_uint64()
  tmp.reinterpret_as_double()
}

///|
/// `libm::scalbn` (`generic::scalbn` for `f64`).
fn libm_scalbn(x : Double, n : Int) -> Double {
  let exp_max = 1023
  let exp_min = -1022
  let f_exp_max = LIBM_X1P1023.reinterpret_as_double() // 0x1p1023
  let f_exp_min = 0x0010000000000000UL.reinterpret_as_double() // 0x1p-1022
  let f_pow_subnorm = 0x4340000000000000UL.reinterpret_as_double() // 0x1p53
  let mut x = x
  let mut n = n
  // The goal is to multiply `x` by a scale factor that applies `n`. However,
  // there are cases where `2^n` is not representable by `F` but the result
  // should be, e.g. `x = 2^Emin` with `n = -EMin + 2` (one out of range of
  // 2^Emax). To get around this, reduce the magnitude of the final scale
  // operation by prescaling by the max/min power representable by `F`.
  if n > exp_max {
    x = x * f_exp_max
    n -= exp_max
    if n > exp_max {
      x = x * f_exp_max
      n -= exp_max
      if n > exp_max {
        n = exp_max
      }
    }
  } else if n < exp_min {
    let mul = f_exp_min * f_pow_subnorm
    let add = -exp_min - 53
    x = x * mul
    n += add
    if n < exp_min {
      x = x * mul
      n += add
      if n < exp_min {
        n = exp_min
      }
    }
  }
  let scale = ((0x3ff + n).to_uint64() << 52).reinterpret_as_double()
  x * scale
}

///|
/// `libm::exp`: the exponential of `x`.
///
/// Method
///   1. Argument reduction:
///      Reduce x to an r so that |r| <= 0.5*ln2 ~ 0.34658.
///      Given x, find r and integer k such that
///
///               x = k*ln2 + r,  |r| <= 0.5*ln2.
///
///      Here r will be represented as r = hi-lo for better
///      accuracy.
///
///   2. Approximation of exp(r) by a special rational function on
///      the interval [0,0.34658]:
///          R(r**2) = r*(exp(r)+1)/(exp(r)-1) = 2 + r*r/6 - r**4/360 + ...
///      approximated by a polynomial of degree 5 (P1 to P5), then
///                                 r*c(r)
///          exp(r) = 1 + r + ----------- ,  c(r) = r - (P1*r^2 + ... + P5*r^10).
///                                2 - c(r)
///
///   3. Scale back to obtain exp(x): exp(x) = 2^k * exp(r)
fn libm_exp(x : Double) -> Double {
  let x1p1023 = LIBM_X1P1023.reinterpret_as_double() // 0x1p1023 === 2 ^ 1023
  let mut x = x
  let mut hx = libm_high_word(x)
  let sign = (hx >> 31).reinterpret_as_int()
  hx = hx & 0x7fffffff // high word of |x|
  // special cases
  if hx >= 0x4086232b {
    // if |x| >= 708.39...
    if x.is_nan() {
      return x
    }
    if x > 709.782712893383973096 {
      // overflow if x!=inf
      x = x * x1p1023
      return x
    }
    if x < -708.39641853226410622 {
      // underflow if x!=-inf
      if x < -745.13321910194110842 {
        return 0.0
      }
    }
  }
  // argument reduction
  let mut hi = 0.0
  let mut lo = 0.0
  let mut k = 0
  if hx > 0x3fd62e42 {
    // if |x| > 0.5 ln2
    if hx >= 0x3ff0a2b2 {
      // if |x| >= 1.5 ln2
      k = (LIBM_INVLN2 * x + (if sign == 0 { 0.5 } else { -0.5 })).to_int()
    } else {
      k = 1 - sign - sign
    }
    hi = x - k.to_double() * LIBM_LN2_HI // k*ln2hi is exact here
    lo = k.to_double() * LIBM_LN2_LO
    x = hi - lo
  } else if hx > 0x3e300000 {
    // if |x| > 2**-28
    k = 0
    hi = x
    lo = 0.0
  } else {
    // inexact if x!=0
    return 1.0 + x
  }
  // x is now in primary range
  let xx = x * x
  let c = x -
    xx *
    (LIBM_P1 + xx * (LIBM_P2 + xx * (LIBM_P3 + xx * (LIBM_P4 + xx * LIBM_P5))))
  let y = 1.0 + (x * c / (2.0 - c) - lo + hi)
  if k == 0 {
    y
  } else {
    libm_scalbn(y, k)
  }
}

///|
/// `libm::exp2`: `2^x`.
///
/// Accuracy: Peak error < 0.503 ulp for normalized results.
///
/// Method: (accurate tables)
///
///   Reduce x:
///     x = k + y, for integer k and |y| <= 1/2.
///     Thus we have exp2(x) = 2**k * exp2(y).
///
///   Reduce y:
///     y = i/TBLSIZE + z - eps[i] for integer i near y * TBLSIZE.
///     Thus we have exp2(y) = exp2(i/TBLSIZE) * exp2(z - eps[i]),
///     with |z - eps[i]| <= 2**-9 + 2**-39 for the table used.
///
///   We compute exp2(i/TBLSIZE) via table lookup and exp2(z - eps[i]) via
///   a degree-5 minimax polynomial with maximum error under 1.3 * 2**-61.
///   The values in exp2t[] and eps[] are chosen such that
///   exp2t[i] = exp2(i/TBLSIZE + eps[i]), and eps[i] is a small offset such
///   that exp2t[i] is accurate to 2**-64.
///
///   Note that the range of i is +-TBLSIZE/2, so we actually index the tables
///   by i0 = i + TBLSIZE/2.  For cache efficiency, exp2t[] and eps[] are
///   virtual tables, interleaved in the real table tbl[].
fn libm_exp2(x : Double) -> Double {
  let tblsize = 256U
  let redux = 0x4338000000000000UL.reinterpret_as_double() / 256.0
  let p1 = 0x3fe62e42fefa39efUL.reinterpret_as_double()
  let p2 = 0x3fcebfbdff82c575UL.reinterpret_as_double()
  let p3 = 0x3fac6b08d704a0a6UL.reinterpret_as_double()
  let p4 = 0x3f83b2ab88f70400UL.reinterpret_as_double()
  let p5 = 0x3f55d88003875c74UL.reinterpret_as_double()
  let x1p1023 = LIBM_X1P1023.reinterpret_as_double()
  let mut x = x
  // Filter out exceptional cases.
  let ui = x.reinterpret_as_uint64()
  let ix = (ui >> 32).to_uint() & 0x7fffffff
  if ix >= 0x408ff000 {
    // |x| >= 1022 or nan
    if ix >= 0x40900000 && ui >> 63 == 0 {
      // x >= 1024 or nan
      // overflow
      x = x * x1p1023
      return x
    }
    if ix >= 0x7ff00000 {
      // -inf or -nan
      return -1.0 / x
    }
    if ui >> 63 != 0 {
      // x <= -1022
      // underflow
      if x <= -1075.0 {
        return 0.0
      }
    }
  } else if ix < 0x3c900000 {
    // |x| < 0x1p-54
    return 1.0 + x
  }
  // Reduce x, computing z, i0, and k.
  let ui = (x + redux).reinterpret_as_uint64()
  let mut i0 = ui.to_uint()
  i0 = i0 + tblsize / 2
  let ku = i0 / tblsize * tblsize
  let ki = ku.reinterpret_as_int() / 256
  i0 = i0 % tblsize
  let uf = ui.reinterpret_as_double() - redux
  let mut z = x - uf
  // Compute r = exp2(y) = exp2t[i0] * p(z - eps[i]).
  let i0 = i0.reinterpret_as_int()
  let t = libm_exp2_tbl[2 * i0].reinterpret_as_double() // exp2t[i0]
  z = z - libm_exp2_tbl[2 * i0 + 1].reinterpret_as_double() // eps[i0]
  let r = t + t * z * (p1 + z * (p2 + z * (p3 + z * (p4 + z * p5))))
  libm_scalbn(r, ki)
}

///|
/// `libm::modf`: the fractional and the integral part of `x`.
fn libm_modf(x : Double) -> (Double, Double) {
  let mut u = x.reinterpret_as_uint64()
  let e = ((u >> 52) & 0x7ffUL).to_int() - 0x3ff
  // no fractional part
  if e >= 52 {
    let rv2 = x
    if e == 0x400 && u << 12 != 0 {
      // nan
      return (x, rv2)
    }
    u = u & (1UL << 63)
    return (u.reinterpret_as_double(), rv2)
  }
  // no integral part
  if e < 0 {
    u = u & (1UL << 63)
    let rv2 = u.reinterpret_as_double()
    return (x, rv2)
  }
  let mask = 0xffffffffffffffffUL >> 12 >> e
  if (u & mask) == 0 {
    let rv2 = x
    u = u & (1UL << 63)
    return (u.reinterpret_as_double(), rv2)
  }
  u = u & (mask ^ 0xffffffffffffffffUL)
  let rv2 = u.reinterpret_as_double()
  (x - rv2, rv2)
}

///|
let libm_p10 : ReadOnlyArray[Double] = [
  1.0e-15, 1.0e-14, 1.0e-13, 1.0e-12, 1.0e-11, 1.0e-10, 1.0e-9, 1.0e-8, 1.0e-7, 1.0e-6,
  1.0e-5, 1.0e-4, 1.0e-3, 1.0e-2, 1.0e-1, 1.0e0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5,
  1.0e6, 1.0e7, 1.0e8, 1.0e9, 1.0e10, 1.0e11, 1.0e12, 1.0e13, 1.0e14, 1.0e15,
]

///|
/// `libm::exp10`: 10 raised to the power of `x`.
fn libm_exp10(x : Double) -> Double {
  let ln10 = 3.32192809488736234787031942948939
  let (y, n) = libm_modf(x)
  let u = n.reinterpret_as_uint64()
  // fabs(n) < 16 without raising invalid on nan
  if ((u >> 52) & 0x7ffUL) < 0x3ffUL + 4 {
    if y == 0.0 {
      return libm_p10[n.to_int() + 15]
    }
    let y = libm_exp2(ln10 * y)
    return y * libm_p10[n.to_int() + 15]
  }
  libm_pow(10.0, x)
}

///|
/// `libm::expm1`: `exp(x) - 1`, accurate even for small values of `x`
/// (origin: FreeBSD /usr/src/lib/msun/src/s_expm1.c).
fn libm_expm1(x : Double) -> Double {
  let o_threshold = 7.09782712893383973096e+02 // 0x40862E42, 0xFEFA39EF
  // Scaled Q's: Qn_here = 2**n * Qn_above, for R(2*z) where z = hxs = x*x/2:
  let q1 = -3.33333333333331316428e-02 // BFA11111 111110F4
  let q2 = 1.58730158725481460165e-03 // 3F5A01A0 19FE5585
  let q3 = -7.93650757867487942473e-05 // BF14CE19 9EAADBB7
  let q4 = 4.00821782732936239552e-06 // 3ED0CFCA 86E65239
  let q5 = -2.01099218183624371326e-07 // BE8AFDB7 6E09C32D
  let mut x = x
  let ui = x.reinterpret_as_uint64()
  let hx = (ui >> 32).to_uint() & 0x7fffffff
  let sign = (ui >> 63).to_int()
  // filter out huge and non-finite argument
  if hx >= 0x4043687A {
    // if |x|>=56*ln2
    if x.is_nan() {
      return x
    }
    if sign != 0 {
      return -1.0
    }
    if x > o_threshold {
      x = x * LIBM_X1P1023.reinterpret_as_double()
      return x
    }
  }
  // argument reduction
  let mut k = 0
  let mut c = 0.0
  if hx > 0x3fd62e42 {
    // if  |x| > 0.5 ln2
    let mut hi = 0.0
    let mut lo = 0.0
    if hx < 0x3FF0A2B2 {
      // and |x| < 1.5 ln2
      if sign == 0 {
        hi = x - LIBM_LN2_HI
        lo = LIBM_LN2_LO
        k = 1
      } else {
        hi = x + LIBM_LN2_HI
        lo = -LIBM_LN2_LO
        k = -1
      }
    } else {
      k = (LIBM_INVLN2 * x + (if sign != 0 { -0.5 } else { 0.5 })).to_int()
      let t = k.to_double()
      hi = x - t * LIBM_LN2_HI // t*ln2_hi is exact here
      lo = t * LIBM_LN2_LO
    }
    x = hi - lo
    c = hi - x - lo
  } else if hx < 0x3c900000 {
    // |x| < 2**-54, return x
    return x
  } else {
    c = 0.0
    k = 0
  }
  // x is now in primary range
  let hfx = 0.5 * x
  let hxs = x * hfx
  let r1 = 1.0 + hxs * (q1 + hxs * (q2 + hxs * (q3 + hxs * (q4 + hxs * q5))))
  let t = 3.0 - r1 * hfx
  let mut e = hxs * ((r1 - t) / (6.0 - x * t))
  if k == 0 {
    // c is 0
    return x - (x * e - hxs)
  }
  e = x * (e - c) - c
  e = e - hxs
  // exp(x) ~ 2^k (x_reduced - e + 1)
  if k == -1 {
    return 0.5 * (x - e) - 0.5
  }
  if k == 1 {
    if x < -0.25 {
      return -2.0 * (e - (x + 0.5))
    }
    return 1.0 + 2.0 * (x - e)
  }
  let twopk = ((0x3ff + k).to_uint64() << 52).reinterpret_as_double() // 2^k
  if !(0 <= k && k <= 56) {
    // suffice to return exp(x)-1
    let mut y = x - e + 1.0
    if k == 1024 {
      y = y * 2.0 * LIBM_X1P1023.reinterpret_as_double()
    } else {
      y = y * twopk
    }
    return y - 1.0
  }
  let uf = ((0x3ff - k).to_uint64() << 52).reinterpret_as_double() // 2^-k
  if k < 20 {
    (x - e + (1.0 - uf)) * twopk
  } else {
    (x - (e + uf) + 1.0) * twopk
  }
}

///|
/// `libm::expo2`: exp(x)/2 for x >= log(DBL_MAX), slightly better than
/// 0.5*exp(x/2)*exp(x/2). (`libm::k_expo2`, which `cosh` uses, is the same
/// computation.)
fn libm_expo2(x : Double) -> Double {
  // k is such that k*ln2 has minimal relative error and x - kln2 > log(DBL_MIN)
  let k = 2043
  let kln2 = 0x40962066151add8bUL.reinterpret_as_double()
  // note that k is odd and scale*scale overflows
  let scale = ((0x3ff + k / 2).to_uint64() << 52).reinterpret_as_double()
  // exp(x - k ln2) * 2**(k-1)
  libm_exp(x - kln2) * scale * scale
}
