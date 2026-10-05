// Inverse trigonometric functions of the `libm` crate (0.2, a port of musl),
// which upstream uses for `Angle::asin`/`acos`/`atan`/`atan2`
// (typst-library/src/layout/angle.rs), i.e. `calc.asin`, `calc.acos`,
// `calc.atan` and `calc.atan2`. See `libm_trig.mbt` and `libm_wbtest.mbt`.

// origin: FreeBSD /usr/src/lib/msun/src/e_asin.c, e_acos.c, s_atan.c,
// e_atan2.c
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunSoft, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

///|
const LIBM_PIO2_HI : Double = 1.57079632679489655800e+00 // 0x3FF921FB, 0x54442D18

///|
const LIBM_PIO2_LO : Double = 6.12323399573676603587e-17 // 0x3C91A626, 0x33145C07

///|
/// `0x1p-120`.
const LIBM_X1P_120 : UInt64 = 0x3870000000000000UL

///|
/// The rational approximation `R(x^2)` of `asin` and `acos` (`comp_r`, `r`).
fn libm_asin_r(z : Double) -> Double {
  // coefficients for R(x^2)
  let p_s0 = 1.66666666666666657415e-01 // 0x3FC55555, 0x55555555
  let p_s1 = -3.25565818622400915405e-01 // 0xBFD4D612, 0x03EB6F7D
  let p_s2 = 2.01212532134862925881e-01 // 0x3FC9C155, 0x0E884455
  let p_s3 = -4.00555345006794114027e-02 // 0xBFA48228, 0xB5688F3B
  let p_s4 = 7.91534994289814532176e-04 // 0x3F49EFE0, 0x7501B288
  let p_s5 = 3.47933107596021167570e-05 // 0x3F023DE1, 0x0DFDF709
  let q_s1 = -2.40339491173441421878e+00 // 0xC0033A27, 0x1C8A2D4B
  let q_s2 = 2.02094576023350569471e+00 // 0x40002AE5, 0x9C598AC8
  let q_s3 = -6.88283971605453293030e-01 // 0xBFE6066C, 0x1B8D0159
  let q_s4 = 7.70381505559019352791e-02 // 0x3FB3B8C5, 0xB12E9282
  let p = z *
    (p_s0 + z * (p_s1 + z * (p_s2 + z * (p_s3 + z * (p_s4 + z * p_s5)))))
  let q = 1.0 + z * (q_s1 + z * (q_s2 + z * (q_s3 + z * q_s4)))
  p / q
}

///|
/// `libm::asin`: the arc sine of `x`, in the range of -pi/2 to pi/2.
///
/// Method :
///      Since  asin(x) = x + x^3/6 + x^5*3/40 + x^7*15/336 + ...
///      we approximate asin(x) on [0,0.5] by
///              asin(x) = x + x*x^2*R(x^2)
///      where
///              R(x^2) is a rational approximation of (asin(x)-x)/x^3
///      and its remez error is bounded by
///              |(asin(x)-x)/x^3 - R(x^2)| < 2^(-58.75)
///
///      For x in [0.5,1]
///              asin(x) = pi/2-2*asin(sqrt((1-x)/2))
///      Let y = (1-x), z = y/2, s := sqrt(z), and pio2_hi+pio2_lo=pi/2;
///      then for x>0.98
///              asin(x) = pi/2 - 2*(s+s*z*R(z))
///                      = pio2_hi - (2*(s+s*z*R(z)) - pio2_lo)
///      For x<=0.98, let pio4_hi = pio2_hi/2, then
///              f = hi part of s;
///              c = sqrt(z) - f = (z-f*f)/(s+f)         ...f+c=sqrt(z)
///      and
///              asin(x) = pi/2 - 2*(s+s*z*R(z))
///                      = pio4_hi+(pio4-2s)-(2s*z*R(z)-pio2_lo)
///                      = pio4_hi+(pio4-2f)-(2s*z*R(z)-(pio2_lo+2c))
///
/// Special cases:
///      if x is NaN, return x itself;
///      if |x|>1, return NaN with invalid signal.
fn libm_asin(x : Double) -> Double {
  let mut x = x
  let hx = libm_high_word(x)
  let ix = hx & 0x7fffffff
  // |x| >= 1 or nan
  if ix >= 0x3ff00000 {
    let lx = x.reinterpret_as_uint64().to_uint()
    if ((ix - 0x3ff00000) | lx) == 0 {
      // asin(1) = +-pi/2 with inexact
      return x * LIBM_PIO2_HI + LIBM_X1P_120.reinterpret_as_double()
    } else {
      return 0.0 / (x - x)
    }
  }
  // |x| < 0.5
  if ix < 0x3fe00000 {
    // if 0x1p-1022 <= |x| < 0x1p-26, avoid raising underflow
    if ix >= 0x00100000 && ix < 0x3e500000 {
      return x
    } else {
      return x + x * libm_asin_r(x * x)
    }
  }
  // 1 > |x| >= 0.5
  let z = (1.0 - x.abs()) * 0.5
  let s = z.sqrt()
  let r = libm_asin_r(z)
  if ix >= 0x3fef3333 {
    // if |x| > 0.975
    x = LIBM_PIO2_HI - (2.0 * (s + s * r) - LIBM_PIO2_LO)
  } else {
    // f+c = sqrt(z)
    let f = libm_with_set_low_word(s, 0)
    let c = (z - f * f) / (s + f)
    x = 0.5 * LIBM_PIO2_HI -
      (2.0 * s * r - (LIBM_PIO2_LO - 2.0 * c) - (0.5 * LIBM_PIO2_HI - 2.0 * f))
  }
  if hx >> 31 != 0 {
    -x
  } else {
    x
  }
}

///|
/// `libm::acos`: the arc cosine of `x`, in the range of 0 to pi.
///
/// Method :
///      acos(x)  = pi/2 - asin(x)
///      acos(-x) = pi/2 + asin(x)
/// For |x|<=0.5
///      acos(x) = pi/2 - (x + x*x^2*R(x^2))     (see asin.c)
/// For x>0.5
///      acos(x) = pi/2 - (pi/2 - 2asin(sqrt((1-x)/2)))
///              = 2asin(sqrt((1-x)/2))
///              = 2s + 2s*z*R(z)        ...z=(1-x)/2, s=sqrt(z)
///              = 2f + (2c + 2s*z*R(z))
///     where f=hi part of s, and c = (z-f*f)/(s+f) is the correction term
///     for f so that f+c ~ sqrt(z).
/// For x<-0.5
///      acos(x) = pi - 2asin(sqrt((1-|x|)/2))
///              = pi - 0.5*(s+s*z*R(z)), where z=(1-|x|)/2,s=sqrt(z)
///
/// Special cases:
///      if x is NaN, return x itself;
///      if |x|>1, return NaN with invalid signal.
fn libm_acos(x : Double) -> Double {
  let x1p_120f = LIBM_X1P_120.reinterpret_as_double() // 0x1p-120 === 2 ^ -120
  let hx = libm_high_word(x)
  let ix = hx & 0x7fffffff
  // |x| >= 1 or nan
  if ix >= 0x3ff00000 {
    let lx = x.reinterpret_as_uint64().to_uint()
    if ((ix - 0x3ff00000) | lx) == 0 {
      // acos(1)=0, acos(-1)=pi
      if hx >> 31 != 0 {
        return 2.0 * LIBM_PIO2_HI + x1p_120f
      }
      return 0.0
    }
    return 0.0 / (x - x)
  }
  // |x| < 0.5
  if ix < 0x3fe00000 {
    if ix <= 0x3c600000 {
      // |x| < 2**-57
      return LIBM_PIO2_HI + x1p_120f
    }
    return LIBM_PIO2_HI - (x - (LIBM_PIO2_LO - x * libm_asin_r(x * x)))
  }
  // x < -0.5
  if hx >> 31 != 0 {
    let z = (1.0 + x) * 0.5
    let s = z.sqrt()
    let w = libm_asin_r(z) * s - LIBM_PIO2_LO
    return 2.0 * (LIBM_PIO2_HI - (s + w))
  }
  // x > 0.5
  let z = (1.0 - x) * 0.5
  let s = z.sqrt()
  // Set the low 4 bytes to zero
  let df = libm_with_set_low_word(s, 0)
  let c = (z - df * df) / (s + df)
  let w = libm_asin_r(z) * s + c
  2.0 * (df + w)
}

///|
let libm_atanhi : ReadOnlyArray[Double] = [
  4.63647609000806093515e-01, // atan(0.5)hi 0x3FDDAC67, 0x0561BB4F
   7.85398163397448278999e-01, // atan(1.0)hi 0x3FE921FB, 0x54442D18
   9.82793723247329054082e-01, // atan(1.5)hi 0x3FEF730B, 0xD281F69B
   1.57079632679489655800e+00, // atan(inf)hi 0x3FF921FB, 0x54442D18
]

///|
let libm_atanlo : ReadOnlyArray[Double] = [
  2.26987774529616870924e-17, // atan(0.5)lo 0x3C7A2B7F, 0x222F65E2
   3.06161699786838301793e-17, // atan(1.0)lo 0x3C81A626, 0x33145C07
   1.39033110312309984516e-17, // atan(1.5)lo 0x3C700788, 0x7AF0CBBD
   6.12323399573676603587e-17, // atan(inf)lo 0x3C91A626, 0x33145C07
]

///|
let libm_at : ReadOnlyArray[Double] = [
  3.33333333333329318027e-01, // 0x3FD55555, 0x5555550D
   -1.99999999998764832476e-01, // 0xBFC99999, 0x9998EBC4
   1.42857142725034663711e-01, // 0x3FC24924, 0x920083FF
   -1.11111104054623557880e-01, // 0xBFBC71C6, 0xFE231671
   9.09088713343650656196e-02, // 0x3FB745CD, 0xC54C206E
   -7.69187620504482999495e-02, // 0xBFB3B0F2, 0xAF749A6D
   6.66107313738753120669e-02, // 0x3FB10D66, 0xA0D03D51
   -5.83357013379057348645e-02, // 0xBFADDE2D, 0x52DEFD9A
   4.97687799461593236017e-02, // 0x3FA97B4B, 0x24760DEB
   -3.65315727442169155270e-02, // 0xBFA2B444, 0x2C6A6C2F
   1.62858201153657823623e-02, // 0x3F90AD3A, 0xE322DA11
]

///|
/// `libm::atan`: the arc tangent of `x`, in the range of -pi/2 to pi/2.
///
/// Method
///   1. Reduce x to positive by atan(x) = -atan(-x).
///   2. According to the integer k=4t+0.25 chopped, t=x, the argument
///      is further reduced to one of the following intervals and the
///      arctangent of t is evaluated by the corresponding formula:
///
///      [0,7/16]      atan(x) = t-t^3*(a1+t^2*(a2+...(a10+t^2*a11)...)
///      [7/16,11/16]  atan(x) = atan(1/2) + atan( (t-0.5)/(1+t/2) )
///      [11/16.19/16] atan(x) = atan( 1 ) + atan( (t-1)/(1+t) )
///      [19/16,39/16] atan(x) = atan(3/2) + atan( (t-1.5)/(1+1.5t) )
///      [39/16,INF]   atan(x) = atan(INF) + atan( -1/t )
fn libm_atan(x : Double) -> Double {
  let mut x = x
  let mut ix = libm_high_word(x)
  let sign = ix >> 31
  ix = ix & 0x7fff_ffff
  if ix >= 0x4410_0000 {
    if x.is_nan() {
      return x
    }
    let z = libm_atanhi[3] + 0x0380_0000UL.reinterpret_as_double() // 0x1p-120f
    return if sign != 0 { -z } else { z }
  }
  let mut id = -1
  if ix < 0x3fdc_0000 {
    // |x| < 0.4375
    if ix < 0x3e40_0000 {
      // |x| < 2^-27
      // raise underflow for subnormal x
      return x
    }
    id = -1
  } else {
    x = x.abs()
    if ix < 0x3ff30000 {
      // |x| < 1.1875
      if ix < 0x3fe60000 {
        // 7/16 <= |x| < 11/16
        x = (2.0 * x - 1.0) / (2.0 + x)
        id = 0
      } else {
        // 11/16 <= |x| < 19/16
        x = (x - 1.0) / (x + 1.0)
        id = 1
      }
    } else if ix < 0x40038000 {
      // |x| < 2.4375
      x = (x - 1.5) / (1.0 + 1.5 * x)
      id = 2
    } else {
      // 2.4375 <= |x| < 2^66
      x = -1.0 / x
      id = 3
    }
  }
  let at = libm_at
  let z = x * x
  let w = z * z
  // break sum from i=0 to 10 AT[i]z**(i+1) into odd and even poly
  let s1 = z *
    (at[0] + w * (at[2] + w * (at[4] + w * (at[6] + w * (at[8] + w * at[10])))))
  let s2 = w * (at[1] + w * (at[3] + w * (at[5] + w * (at[7] + w * at[9]))))
  if id < 0 {
    return x - x * (s1 + s2)
  }
  let z = libm_atanhi[id] - (x * (s1 + s2) - libm_atanlo[id] - x)
  if sign != 0 {
    -z
  } else {
    z
  }
}

///|
/// `libm::atan2`: the arc tangent of `y/x`, in the range of -pi to pi.
///
/// Method :
///      1. Reduce y to positive by atan2(y,x)=-atan2(-y,x).
///      2. Reduce x to positive by (if x and y are unexceptional):
///              ARG (x+iy) = arctan(y/x)           ... if x > 0,
///              ARG (x+iy) = pi - arctan[y/(-x)]   ... if x < 0,
///
/// Special cases:
///
///      ATAN2((anything), NaN ) is NaN;
///      ATAN2(NAN , (anything) ) is NaN;
///      ATAN2(+-0, +(anything but NaN)) is +-0  ;
///      ATAN2(+-0, -(anything but NaN)) is +-pi ;
///      ATAN2(+-(anything but 0 and NaN), 0) is +-pi/2;
///      ATAN2(+-(anything but INF and NaN), +INF) is +-0 ;
///      ATAN2(+-(anything but INF and NaN), -INF) is +-pi;
///      ATAN2(+-INF,+INF ) is +-pi/4 ;
///      ATAN2(+-INF,-INF ) is +-3pi/4;
///      ATAN2(+-INF, (anything but,0,NaN, and INF)) is +-pi/2;
fn libm_atan2(y : Double, x : Double) -> Double {
  let pi = 3.1415926535897931160E+00 // 0x400921FB, 0x54442D18
  let pi_lo = 1.2246467991473531772E-16 // 0x3CA1A626, 0x33145C07
  if x.is_nan() || y.is_nan() {
    return x + y
  }
  let mut ix = libm_high_word(x)
  let lx = x.reinterpret_as_uint64().to_uint()
  let mut iy = libm_high_word(y)
  let ly = y.reinterpret_as_uint64().to_uint()
  if ((ix - 0x3ff00000) | lx) == 0 {
    // x = 1.0
    return libm_atan(y)
  }
  let m = ((iy >> 31) & 1) | ((ix >> 30) & 2) // 2*sign(x)+sign(y)
  ix = ix & 0x7fffffff
  iy = iy & 0x7fffffff
  // when y = 0
  if (iy | ly) == 0 {
    return match m {
      0 | 1 => y // atan(+-0,+anything)=+-0
      2 => pi // atan(+0,-anything) = PI
      _ => -pi // atan(-0,-anything) =-PI
    }
  }
  // when x = 0
  if (ix | lx) == 0 {
    return if (m & 1) != 0 { -pi / 2.0 } else { pi / 2.0 }
  }
  // when x is INF
  if ix == 0x7ff00000 {
    if iy == 0x7ff00000 {
      return match m {
        0 => pi / 4.0 // atan(+INF,+INF)
        1 => -pi / 4.0 // atan(-INF,+INF)
        2 => 3.0 * pi / 4.0 // atan(+INF,-INF)
        _ => -3.0 * pi / 4.0 // atan(-INF,-INF)
      }
    } else {
      return match m {
        0 => 0.0 // atan(+...,+INF)
        1 => -0.0 // atan(-...,+INF)
        2 => pi // atan(+...,-INF)
        _ => -pi // atan(-...,-INF)
      }
    }
  }
  // |y/x| > 0x1p64
  if ix + (64 << 20) < iy || iy == 0x7ff00000 {
    return if (m & 1) != 0 { -pi / 2.0 } else { pi / 2.0 }
  }
  // z = atan(|y/x|) without spurious underflow
  let z = if (m & 2) != 0 && iy + (64 << 20) < ix {
    // |y/x| < 0x1p-64, x<0
    0.0
  } else {
    libm_atan((y / x).abs())
  }
  match m {
    0 => z // atan(+,+)
    1 => -z // atan(-,+)
    2 => pi - (z - pi_lo) // atan(+,-)
    _ => z - pi_lo - pi // atan(-,-)
  }
}
