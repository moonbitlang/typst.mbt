// Logarithms of the `libm` crate (0.2, a port of musl): `log`, `log2`,
// `log10` and `log1p`, which upstream uses for `calc.log` and `calc.ln`
// (typst-library/src/foundations/calc.rs) and, through `asinh`/`acosh`/
// `atanh`, for the inverse hyperbolic functions. `@math.ln`/`log2`/`log10`
// are built differently from the same fdlibm kernel (`@math.ln` reduces with
// `frexp` and sums in another order, `@math.log2` is `ln(f) / LN2 + e`,
// `@math.log10` scales `ln(f)`), so they differ from upstream in the last
// place for some arguments; see `libm_wbtest.mbt`.

// origin: FreeBSD /usr/src/lib/msun/src/e_log.c, e_log2.c, e_log10.c,
// s_log1p.c
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunSoft, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

///|
const LIBM_LG1 : Double = 6.666666666666735130e-01 // 3FE55555 55555593

///|
const LIBM_LG2 : Double = 3.999999999940941908e-01 // 3FD99999 9997FA04

///|
const LIBM_LG3 : Double = 2.857142874366239149e-01 // 3FD24924 94229359

///|
const LIBM_LG4 : Double = 2.222219843214978396e-01 // 3FCC71C5 1D8E78AF

///|
const LIBM_LG5 : Double = 1.818357216161805012e-01 // 3FC74664 96CB03DE

///|
const LIBM_LG6 : Double = 1.531383769920937332e-01 // 3FC39A09 D078C69F

///|
const LIBM_LG7 : Double = 1.479819860511658591e-01 // 3FC2F112 DF3E5244

///|
/// `0x1p54`.
const LIBM_X1P54 : UInt64 = 0x4350000000000000UL

///|
/// `libm::log`: the natural logarithm of `x`.
///
/// Method :
///   1. Argument Reduction: find k and f such that
///                      x = 2^k * (1+f),
///         where  sqrt(2)/2 < 1+f < sqrt(2) .
///
///   2. Approximation of log(1+f).
///      Let s = f/(2+f) ; based on log(1+f) = log(1+s) - log(1-s)
///               = 2s + 2/3 s**3 + 2/5 s**5 + .....,
///               = 2s + s*R
///      We use a special Remez algorithm on [0,0.1716] to generate
///      a polynomial of degree 14 to approximate R (Lg1 to Lg7).
///
///   3. Finally,  log(x) = k*ln2 + log(1+f).
///                       = k*ln2_hi+(f-(hfsq-(s*(hfsq+R)+k*ln2_lo)))
///      Here ln2 is split into two floating point number:
///                   ln2_hi + ln2_lo,
///      where n*ln2_hi is always exact for |n| < 2000.
fn libm_log(x : Double) -> Double {
  let x1p54 = LIBM_X1P54.reinterpret_as_double() // 0x1p54 === 2 ^ 54
  let mut x = x
  let mut ui = x.reinterpret_as_uint64()
  let mut hx = (ui >> 32).to_uint()
  let mut k = 0
  if hx < 0x00100000 || hx >> 31 != 0 {
    // x < 2**-126
    if ui << 1 == 0 {
      return -1.0 / (x * x) // log(+-0)=-inf
    }
    if hx >> 31 != 0 {
      return (x - x) / 0.0 // log(-#) = NaN
    }
    // subnormal number, scale x up
    k -= 54
    x = x * x1p54
    ui = x.reinterpret_as_uint64()
    hx = (ui >> 32).to_uint()
  } else if hx >= 0x7ff00000 {
    return x
  } else if hx == 0x3ff00000 && ui << 32 == 0 {
    return 0.0
  }
  // reduce x into [sqrt(2)/2, sqrt(2)]
  hx = hx + (0x3ff00000 - 0x3fe6a09e)
  k += (hx >> 20).reinterpret_as_int() - 0x3ff
  hx = (hx & 0x000fffff) + 0x3fe6a09e
  ui = (hx.to_uint64() << 32) | (ui & 0xffffffffUL)
  x = ui.reinterpret_as_double()
  let f = x - 1.0
  let hfsq = 0.5 * f * f
  let s = f / (2.0 + f)
  let z = s * s
  let w = z * z
  let t1 = w * (LIBM_LG2 + w * (LIBM_LG4 + w * LIBM_LG6))
  let t2 = z * (LIBM_LG1 + w * (LIBM_LG3 + w * (LIBM_LG5 + w * LIBM_LG7)))
  let r = t2 + t1
  let dk = k.to_double()
  s * (hfsq + r) + dk * LIBM_LN2_LO - hfsq + f + dk * LIBM_LN2_HI
}

///|
/// `libm::log2`: the base 2 logarithm of `x`.
///
/// Return the base 2 logarithm of x.  See log.c for most comments.
///
/// Reduce x to 2^k (1+f) and calculate r = log(1+f) - f + f*f/2
/// as in log.c, then combine and scale in extra precision:
///    log2(x) = (f - f*f/2 + r)/log(2) + k
fn libm_log2(x : Double) -> Double {
  let ivln2hi = 1.44269504072144627571e+00 // 0x3ff71547, 0x65200000
  let ivln2lo = 1.67517131648865118353e-10 // 0x3de705fc, 0x2eefa200
  let x1p54 = LIBM_X1P54.reinterpret_as_double() // 0x1p54 === 2 ^ 54
  let mut x = x
  let mut ui = x.reinterpret_as_uint64()
  let mut hx = (ui >> 32).to_uint()
  let mut k = 0
  if hx < 0x00100000 || hx >> 31 > 0 {
    if ui << 1 == 0 {
      return -1.0 / (x * x) // log(+-0)=-inf
    }
    if hx >> 31 > 0 {
      return (x - x) / 0.0 // log(-#) = NaN
    }
    // subnormal number, scale x up
    k -= 54
    x = x * x1p54
    ui = x.reinterpret_as_uint64()
    hx = (ui >> 32).to_uint()
  } else if hx >= 0x7ff00000 {
    return x
  } else if hx == 0x3ff00000 && ui << 32 == 0 {
    return 0.0
  }
  // reduce x into [sqrt(2)/2, sqrt(2)]
  hx = hx + (0x3ff00000 - 0x3fe6a09e)
  k += (hx >> 20).reinterpret_as_int() - 0x3ff
  hx = (hx & 0x000fffff) + 0x3fe6a09e
  ui = (hx.to_uint64() << 32) | (ui & 0xffffffffUL)
  x = ui.reinterpret_as_double()
  let f = x - 1.0
  let hfsq = 0.5 * f * f
  let s = f / (2.0 + f)
  let z = s * s
  let w = z * z
  let t1 = w * (LIBM_LG2 + w * (LIBM_LG4 + w * LIBM_LG6))
  let t2 = z * (LIBM_LG1 + w * (LIBM_LG3 + w * (LIBM_LG5 + w * LIBM_LG7)))
  let r = t2 + t1
  // hi+lo = f - hfsq + s*(hfsq+R) ~ log(1+f)
  let mut hi = f - hfsq
  ui = hi.reinterpret_as_uint64()
  ui = ui & 0xffffffff_00000000UL
  hi = ui.reinterpret_as_double()
  let lo = f - hi - hfsq + s * (hfsq + r)
  let mut val_hi = hi * ivln2hi
  let mut val_lo = (lo + hi) * ivln2lo + lo * ivln2hi
  // spadd(val_hi, val_lo, y), except for not using double_t:
  let y = k.to_double()
  let w = y + val_hi
  val_lo = val_lo + (y - w + val_hi)
  val_hi = w
  val_lo + val_hi
}

///|
/// `libm::log10`: the base 10 logarithm of `x`.
///
/// Return the base 10 logarithm of x.  See log.c for most comments.
///
/// Reduce x to 2^k (1+f) and calculate r = log(1+f) - f + f*f/2
/// as in log.c, then combine and scale in extra precision:
///    log10(x) = (f - f*f/2 + r)/log(10) + k*log10(2)
fn libm_log10(x : Double) -> Double {
  let ivln10hi = 4.34294481878168880939e-01 // 0x3fdbcb7b, 0x15200000
  let ivln10lo = 2.50829467116452752298e-11 // 0x3dbb9438, 0xca9aadd5
  let log10_2hi = 3.01029995663611771306e-01 // 0x3FD34413, 0x509F6000
  let log10_2lo = 3.69423907715893078616e-13 // 0x3D59FEF3, 0x11F12B36
  let x1p54 = LIBM_X1P54.reinterpret_as_double() // 0x1p54 === 2 ^ 54
  let mut x = x
  let mut ui = x.reinterpret_as_uint64()
  let mut hx = (ui >> 32).to_uint()
  let mut k = 0
  if hx < 0x00100000 || hx >> 31 > 0 {
    if ui << 1 == 0 {
      return -1.0 / (x * x) // log(+-0)=-inf
    }
    if hx >> 31 > 0 {
      return (x - x) / 0.0 // log(-#) = NaN
    }
    // subnormal number, scale x up
    k -= 54
    x = x * x1p54
    ui = x.reinterpret_as_uint64()
    hx = (ui >> 32).to_uint()
  } else if hx >= 0x7ff00000 {
    return x
  } else if hx == 0x3ff00000 && ui << 32 == 0 {
    return 0.0
  }
  // reduce x into [sqrt(2)/2, sqrt(2)]
  hx = hx + (0x3ff00000 - 0x3fe6a09e)
  k += (hx >> 20).reinterpret_as_int() - 0x3ff
  hx = (hx & 0x000fffff) + 0x3fe6a09e
  ui = (hx.to_uint64() << 32) | (ui & 0xffffffffUL)
  x = ui.reinterpret_as_double()
  let f = x - 1.0
  let hfsq = 0.5 * f * f
  let s = f / (2.0 + f)
  let z = s * s
  let w = z * z
  let t1 = w * (LIBM_LG2 + w * (LIBM_LG4 + w * LIBM_LG6))
  let t2 = z * (LIBM_LG1 + w * (LIBM_LG3 + w * (LIBM_LG5 + w * LIBM_LG7)))
  let r = t2 + t1
  // See log2.c for details.
  // hi+lo = f - hfsq + s*(hfsq+R) ~ log(1+f)
  let mut hi = f - hfsq
  ui = hi.reinterpret_as_uint64()
  ui = ui & 0xffffffff_00000000UL
  hi = ui.reinterpret_as_double()
  let lo = f - hi - hfsq + s * (hfsq + r)
  // val_hi+val_lo ~ log10(1+f) + k*log10(2)
  let mut val_hi = hi * ivln10hi
  let dk = k.to_double()
  let y = dk * log10_2hi
  let mut val_lo = dk * log10_2lo + (lo + hi) * ivln10lo + lo * ivln10hi
  // Extra precision in for adding y is not strictly needed
  // since there is no very large cancellation near x = sqrt(2) or
  // x = 1/sqrt(2), but we do it anyway since it costs little on CPUs
  // with some parallelism and it reduces the error for many args.
  let w = y + val_hi
  val_lo = val_lo + (y - w + val_hi)
  val_hi = w
  val_lo + val_hi
}

///|
/// `libm::log1p`: the natural logarithm of `1 + x`.
///
/// Method :
///   1. Argument Reduction: find k and f such that
///                      1+x = 2^k * (1+f),
///         where  sqrt(2)/2 < 1+f < sqrt(2) .
///
///      Note. If k=0, then f=x is exact. However, if k!=0, then f
///      may not be representable exactly. In that case, a correction
///      term is need. Let u=1+x rounded. Let c = (1+x)-u, then
///      log(1+x) - log(u) ~ c/u. Thus, we proceed to compute log(u),
///      and add back the correction term c/u.
///
///   2. Approximation of log(1+f): See log.c
///
///   3. Finally, log1p(x) = k*ln2 + log(1+f) + c/u. See log.c
fn libm_log1p(x : Double) -> Double {
  let mut ui = x.reinterpret_as_uint64()
  let mut f = 0.0
  let mut c = 0.0
  let hx = (ui >> 32).to_uint()
  let mut k = 1
  if hx < 0x3fda827a || hx >> 31 > 0 {
    // 1+x < sqrt(2)+
    if hx >= 0xbff00000 {
      // x <= -1.0
      if x == -1.0 {
        return x / 0.0 // log1p(-1) = -inf
      }
      return (x - x) / 0.0 // log1p(x<-1) = NaN
    }
    if hx << 1 < 0x3ca00000 << 1 {
      // |x| < 2**-53
      // underflow if subnormal
      return x
    }
    if hx <= 0xbfd2bec4 {
      // sqrt(2)/2- <= 1+x < sqrt(2)+
      k = 0
      c = 0.0
      f = x
    }
  } else if hx >= 0x7ff00000 {
    return x
  }
  if k > 0 {
    ui = (1.0 + x).reinterpret_as_uint64()
    let mut hu = (ui >> 32).to_uint()
    hu = hu + (0x3ff00000 - 0x3fe6a09e)
    k = (hu >> 20).reinterpret_as_int() - 0x3ff
    // correction term ~ log(1+x)-log(u), avoid underflow in c/u
    if k < 54 {
      c = if k >= 2 {
        1.0 - (ui.reinterpret_as_double() - x)
      } else {
        x - (ui.reinterpret_as_double() - 1.0)
      }
      c = c / ui.reinterpret_as_double()
    } else {
      c = 0.0
    }
    // reduce u into [sqrt(2)/2, sqrt(2)]
    hu = (hu & 0x000fffff) + 0x3fe6a09e
    ui = (hu.to_uint64() << 32) | (ui & 0xffffffffUL)
    f = ui.reinterpret_as_double() - 1.0
  }
  let hfsq = 0.5 * f * f
  let s = f / (2.0 + f)
  let z = s * s
  let w = z * z
  let t1 = w * (LIBM_LG2 + w * (LIBM_LG4 + w * LIBM_LG6))
  let t2 = z * (LIBM_LG1 + w * (LIBM_LG3 + w * (LIBM_LG5 + w * LIBM_LG7)))
  let r = t2 + t1
  let dk = k.to_double()
  s * (hfsq + r) + (dk * LIBM_LN2_LO + c) - hfsq + f + dk * LIBM_LN2_HI
}
