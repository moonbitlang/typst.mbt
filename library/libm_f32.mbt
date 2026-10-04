// Ports of the single-precision `libm` crate (0.2.16) functions that `palette`
// uses upstream (Typst builds `palette` with its `libm` feature), so color
// conversions match upstream bit for bit. `powf` and `cbrtf` are MoonBit's
// `@math` ports of the same musl sources.

// origin: FreeBSD /usr/src/lib/msun/src/s_atanf.c, e_atan2f.c, s_sincosf.c,
// k_sinf.c, k_cosf.c, e_rem_pio2f.c (via musl and the `libm` crate)
// ====================================================
// Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//
// Developed at SunPro, a Sun Microsystems, Inc. business.
// Permission to use, copy, modify, and distribute this
// software is freely granted, provided that this notice
// is preserved.
// ====================================================

///|
fn f32_powf(x : Float, y : Float) -> Float {
  @math.powf(x, y)
}

///|
fn f32_cbrt(x : Float) -> Float {
  @math.cbrtf(x)
}

///|
fn f32_sin(x : Float) -> Float {
  libm_sincosf(x).0
}

///|
fn f32_cos(x : Float) -> Float {
  libm_sincosf(x).1
}

///|
fn f32_atan2(y : Float, x : Float) -> Float {
  libm_atan2f(y, x)
}

///|
fn f32_hypot(x : Float, y : Float) -> Float {
  libm_hypotf(x, y)
}

///|
fn f32_bits(x : UInt) -> Float {
  Float::reinterpret_from_uint(x)
}

///|
/// `libm::hypotf`.
fn libm_hypotf(x : Float, y : Float) -> Float {
  let x1p90 = f32_bits(0x6c800000)
  let x1p_90 = f32_bits(0x12800000)
  let mut uxi = x.reinterpret_as_uint() & 0x7fffffff
  let mut uyi = y.reinterpret_as_uint() & 0x7fffffff
  if uxi < uyi {
    let uti = uxi
    uxi = uyi
    uyi = uti
  }
  let mut x = f32_bits(uxi)
  let mut y = f32_bits(uyi)
  if uyi == 0xffU << 23 {
    return y
  }
  if uxi >= 0xffU << 23 || uyi == 0 || uxi - uyi >= 25U << 23 {
    return x + y
  }
  let mut z : Float = 1.0
  if uxi >= (0x7fU + 60) << 23 {
    z = x1p90
    x = x * x1p_90
    y = y * x1p_90
  } else if uyi < (0x7fU - 60) << 23 {
    z = x1p_90
    x = x * x1p90
    y = y * x1p90
  }
  let xd = x.to_double()
  let yd = y.to_double()
  z * Float::from_double(xd * xd + yd * yd).sqrt()
}

///|
let atan_hi : ReadOnlyArray[Float] = [
  4.6364760399e-01, 7.8539812565e-01, 9.8279368877e-01, 1.5707962513e+00,
]

///|
let atan_lo : ReadOnlyArray[Float] = [
  5.0121582440e-09, 3.7748947079e-08, 3.4473217170e-08, 7.5497894159e-08,
]

///|
let atan_t : ReadOnlyArray[Float] = [
  3.3333328366e-01, -1.9999158382e-01, 1.4253635705e-01, -1.0648017377e-01, 6.1687607318e-02,
]

///|
/// `libm::atanf`.
fn libm_atanf(x : Float) -> Float {
  let x1p_120 = f32_bits(0x03800000)
  let mut x = x
  let ix0 = x.reinterpret_as_uint()
  let sign = ix0 >> 31 != 0
  let ix = ix0 & 0x7fffffff
  if ix >= 0x4c800000 {
    // if |x| >= 2**26
    if x.is_nan() {
      return x
    }
    let z = atan_hi[3] + x1p_120
    return if sign { -z } else { z }
  }
  let id = if ix < 0x3ee00000 {
    // |x| < 0.4375
    if ix < 0x39800000 {
      // |x| < 2**-12
      return x
    }
    -1
  } else {
    x = x.abs()
    if ix < 0x3f980000 {
      // |x| < 1.1875
      if ix < 0x3f300000 {
        // 7/16 <= |x| < 11/16
        x = ((2.0 : Float) * x - 1.0) / ((2.0 : Float) + x)
        0
      } else {
        // 11/16 <= |x| < 19/16
        x = (x - 1.0) / (x + 1.0)
        1
      }
    } else if ix < 0x401c0000 {
      // |x| < 2.4375
      x = (x - 1.5) / ((1.0 : Float) + (1.5 : Float) * x)
      2
    } else {
      // 2.4375 <= |x| < 2**26
      x = (-1.0 : Float) / x
      3
    }
  }
  // end of argument reduction
  let z = x * x
  let w = z * z
  // break sum from i=0 to 10 aT[i]z**(i+1) into odd and even poly
  let s1 = z * (atan_t[0] + w * (atan_t[2] + w * atan_t[4]))
  let s2 = w * (atan_t[1] + w * atan_t[3])
  if id < 0 {
    return x - x * (s1 + s2)
  }
  let z = atan_hi[id] - (x * (s1 + s2) - atan_lo[id] - x)
  if sign {
    -z
  } else {
    z
  }
}

///|
/// `libm::atan2f`.
fn libm_atan2f(y : Float, x : Float) -> Float {
  let pi : Float = 3.1415927410e+00
  let pi_lo : Float = -8.7422776573e-08
  if x.is_nan() || y.is_nan() {
    return x + y
  }
  let mut ix = x.reinterpret_as_uint()
  let mut iy = y.reinterpret_as_uint()
  if ix == 0x3f800000 {
    // x=1.0
    return libm_atanf(y)
  }
  let m = ((iy >> 31) & 1) | ((ix >> 30) & 2) // 2*sign(x)+sign(y)
  ix = ix & 0x7fffffff
  iy = iy & 0x7fffffff
  // when y = 0
  if iy == 0 {
    return match m {
      0 | 1 => y // atan(+-0,+anything)=+-0
      2 => pi // atan(+0,-anything) = pi
      _ => -pi // atan(-0,-anything) =-pi
    }
  }
  // when x = 0
  if ix == 0 {
    return if (m & 1) != 0 { -pi / 2.0 } else { pi / 2.0 }
  }
  // when x is INF
  if ix == 0x7f800000 {
    return if iy == 0x7f800000 {
      match m {
        0 => pi / 4.0
        1 => -pi / 4.0
        2 => (3.0 : Float) * pi / 4.0
        _ => (-3.0 : Float) * pi / 4.0
      }
    } else {
      match m {
        0 => 0.0
        1 => -0.0
        2 => pi
        _ => -pi
      }
    }
  }
  // |y/x| > 0x1p26
  if ix + (26U << 23) < iy || iy == 0x7f800000 {
    return if (m & 1) != 0 { -pi / 2.0 } else { pi / 2.0 }
  }
  // z = atan(|y/x|) with correct underflow
  let z : Float = if (m & 2) != 0 && iy + (26U << 23) < ix {
    // |y/x| < 0x1p-26, x < 0
    0.0
  } else {
    libm_atanf((y / x).abs())
  }
  match m {
    0 => z // atan(+,+)
    1 => -z // atan(-,+)
    2 => pi - (z - pi_lo) // atan(+,-)
    _ => z - pi_lo - pi // atan(-,-)
  }
}

///|
/// `libm` `k_sinf`: sin on [-pi/4, pi/4] in double precision.
fn libm_k_sinf(x : Double) -> Float {
  let s1 = -0.166666666416265235595
  let s2 = 0.0083333293858894631756
  let s3 = -0.000198393348360966317347
  let s4 = 0.0000027183114939898219064
  let z = x * x
  let w = z * z
  let r = s3 + z * s4
  let s = z * x
  Float::from_double(x + s * (s1 + z * s2) + s * w * r)
}

///|
/// `libm` `k_cosf`: cos on [-pi/4, pi/4] in double precision.
fn libm_k_cosf(x : Double) -> Float {
  let c0 = -0.499999997251031003120
  let c1 = 0.0416666233237390631894
  let c2 = -0.00138867637746099294692
  let c3 = 0.0000243904487962774090654
  let z = x * x
  let w = z * z
  let r = c2 + z * c3
  Float::from_double(1.0 + z * c0 + w * c1 + w * z * r)
}

///|
/// `libm` `rem_pio2f`: `x` reduced by multiples of pi/2.
fn libm_rem_pio2f(x : Float) -> (Int, Double) {
  let toint = 1.5 / 2.220446049250313e-16
  let inv_pio2 = 6.36619772367581382433e-01
  let pio2_1 = 1.57079631090164184570e+00
  let pio2_1t = 1.58932547735281966916e-08
  let x64 = x.to_double()
  let ix = x.reinterpret_as_uint() & 0x7fffffff
  if ix >= 0x7f800000 {
    // x is inf or NaN
    return (0, x64 - x64)
  }
  // TODO: `rem_pio2_large` for |x| >= 2^28*(pi/2); the medium-size reduction
  // is used for all finite inputs here.
  let tmp = x64 * inv_pio2 + toint
  let f_n = tmp - toint
  (f_n.to_int(), x64 - f_n * pio2_1 - f_n * pio2_1t)
}

///|
/// `libm::sincosf`.
fn libm_sincosf(x : Float) -> (Float, Float) {
  let pi_2 = @math.PI / 2.0
  let s1pio2 = 1.0 * pi_2
  let s2pio2 = 2.0 * pi_2
  let s3pio2 = 3.0 * pi_2
  let s4pio2 = 4.0 * pi_2
  let ix0 = x.reinterpret_as_uint()
  let sign = ix0 >> 31 != 0
  let ix = ix0 & 0x7fffffff
  let xd = x.to_double()
  // |x| ~<= pi/4
  if ix <= 0x3f490fda {
    // |x| < 2**-12
    if ix < 0x39800000 {
      return (x, 1.0)
    }
    return (libm_k_sinf(xd), libm_k_cosf(xd))
  }
  // |x| ~<= 5*pi/4
  if ix <= 0x407b53d1 {
    if ix <= 0x4016cbe3 {
      // |x| ~<= 3pi/4
      if sign {
        return (-libm_k_cosf(xd + s1pio2), libm_k_sinf(xd + s1pio2))
      } else {
        return (libm_k_cosf(s1pio2 - xd), libm_k_sinf(s1pio2 - xd))
      }
    } else if sign {
      return (-libm_k_sinf(xd + s2pio2), -libm_k_cosf(xd + s2pio2))
    } else {
      return (-libm_k_sinf(xd - s2pio2), -libm_k_cosf(xd - s2pio2))
    }
  }
  // |x| ~<= 9*pi/4
  if ix <= 0x40e231d5 {
    if ix <= 0x40afeddf {
      // |x| ~<= 7*pi/4
      if sign {
        return (libm_k_cosf(xd + s3pio2), -libm_k_sinf(xd + s3pio2))
      } else {
        return (-libm_k_cosf(xd - s3pio2), libm_k_sinf(xd - s3pio2))
      }
    } else if sign {
      return (libm_k_sinf(xd + s4pio2), libm_k_cosf(xd + s4pio2))
    } else {
      return (libm_k_sinf(xd - s4pio2), libm_k_cosf(xd - s4pio2))
    }
  }
  // sin(Inf or NaN) is NaN
  if ix >= 0x7f800000 {
    let rv = x - x
    return (rv, rv)
  }
  // general argument reduction needed
  let (n, y) = libm_rem_pio2f(x)
  let s = libm_k_sinf(y)
  let c = libm_k_cosf(y)
  match n & 3 {
    0 => (s, c)
    1 => (c, -s)
    2 => (-s, -c)
    _ => (-c, s)
  }
}
