// `sinf`/`cosf` of the `libm` crate 0.2 (a port of musl/FreeBSD), which
// `typst-render/src/image.rs` uses. Only arguments with |x| <= 9*pi/4 are
// handled exactly (the renderer only passes `atan2f` results); larger ones
// fall back to the C library.

///|
let s1_pio2 : Double = 1.0 * (@math.PI / 2.0)

///|
let s2_pio2 : Double = 2.0 * (@math.PI / 2.0)

///|
let s3_pio2 : Double = 3.0 * (@math.PI / 2.0)

///|
let s4_pio2 : Double = 4.0 * (@math.PI / 2.0)

///|
fn k_sinf(x : Double) -> Float {
  let s1 = -0.166666666416265235595
  let s2 = 0.0083333293858894631756
  let s3 = -0.000198393348360966317347
  let s4 = 0.0000027183114939898219064
  let z = x * x
  let w = z * z
  let r = s3 + z * s4
  let s = z * x
  (x + s * (s1 + z * s2) + s * w * r).to_float()
}

///|
fn k_cosf(x : Double) -> Float {
  let c0 = -0.499999997251031003120
  let c1 = 0.0416666233237390631894
  let c2 = -0.00138867637746099294692
  let c3 = 0.0000243904487962774090654
  let z = x * x
  let w = z * z
  let r = c2 + z * c3
  (1.0 + z * c0 + w * c1 + w * z * r).to_float()
}

///|
/// `libm::sinf`.
fn musl_sinf(x : Float) -> Float {
  let x64 = x.to_double()
  let mut ix = x.reinterpret_as_uint()
  let sign = ix >> 31 != 0
  ix = ix & 0x7fffffff
  if ix <= 0x3f490fda {
    // |x| ~<= pi/4
    if ix < 0x39800000 {
      // |x| < 2**-12
      return x
    }
    return k_sinf(x64)
  }
  if ix <= 0x407b53d1 {
    // |x| ~<= 5*pi/4
    if ix <= 0x4016cbe3 {
      // |x| ~<= 3pi/4
      if sign {
        return -k_cosf(x64 + s1_pio2)
      } else {
        return k_cosf(x64 - s1_pio2)
      }
    }
    return k_sinf(if sign { -(x64 + s2_pio2) } else { -(x64 - s2_pio2) })
  }
  if ix <= 0x40e231d5 {
    // |x| ~<= 9*pi/4
    if ix <= 0x40afeddf {
      // |x| ~<= 7*pi/4
      if sign {
        return k_cosf(x64 + s3_pio2)
      } else {
        return -k_cosf(x64 - s3_pio2)
      }
    }
    return k_sinf(if sign { x64 + s4_pio2 } else { x64 - s4_pio2 })
  }
  // sin(Inf or NaN) is NaN; general argument reduction is not ported.
  @skia.sinf(x)
}

///|
/// `libm::cosf`.
fn musl_cosf(x : Float) -> Float {
  let x64 = x.to_double()
  let mut ix = x.reinterpret_as_uint()
  let sign = ix >> 31 != 0
  ix = ix & 0x7fffffff
  if ix <= 0x3f490fda {
    // |x| ~<= pi/4
    if ix < 0x39800000 {
      // |x| < 2**-12
      return 1.0
    }
    return k_cosf(x64)
  }
  if ix <= 0x407b53d1 {
    // |x| ~<= 5*pi/4
    if ix > 0x4016cbe3 {
      // |x|  ~> 3*pi/4
      return -k_cosf(if sign { x64 + s2_pio2 } else { x64 - s2_pio2 })
    } else if sign {
      return k_sinf(x64 + s1_pio2)
    } else {
      return k_sinf(s1_pio2 - x64)
    }
  }
  if ix <= 0x40e231d5 {
    // |x| ~<= 9*pi/4
    if ix > 0x40afeddf {
      // |x| ~> 7*pi/4
      return k_cosf(if sign { x64 + s4_pio2 } else { x64 - s4_pio2 })
    } else if sign {
      return k_sinf(-x64 - s3_pio2)
    } else {
      return k_sinf(x64 - s3_pio2)
    }
  }
  // cos(Inf or NaN) is NaN; general argument reduction is not ported.
  @skia.cosf(x)
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
let a_t : ReadOnlyArray[Float] = [
  3.3333328366e-01, -1.9999158382e-01, 1.4253635705e-01, -1.0648017377e-01, 6.1687607318e-02,
]

///|
/// `libm::atanf`.
fn musl_atanf(x : Float) -> Float {
  let mut x = x
  let x1p_120 = Float::reinterpret_from_uint(0x03800000)
  let mut ix = x.reinterpret_as_uint()
  let sign = ix >> 31 != 0
  ix = ix & 0x7fffffff
  if ix >= 0x4c800000 {
    // if |x| >= 2**26
    if x != x {
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
    x = @skia.fabs(x)
    if ix < 0x3f980000 {
      // |x| < 1.1875
      if ix < 0x3f300000 {
        //  7/16 <= |x| < 11/16
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
  let s1 = z * (a_t[0] + w * (a_t[2] + w * a_t[4]))
  let s2 = w * (a_t[1] + w * a_t[3])
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
fn musl_atan2f(y : Float, x : Float) -> Float {
  let pi : Float = 3.1415927410e+00
  let pi_lo : Float = -8.7422776573e-08
  if x != x || y != y {
    return x + y
  }
  let mut ix = x.reinterpret_as_uint()
  let mut iy = y.reinterpret_as_uint()
  if ix == 0x3f800000 {
    // x=1.0
    return musl_atanf(y)
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
        0 => pi / 4.0 // atan(+INF,+INF)
        1 => -pi / 4.0 // atan(-INF,+INF)
        2 => (3.0 : Float) * pi / 4.0 // atan(+INF,-INF)
        _ => (-3.0 : Float) * pi / 4.0 // atan(-INF,-INF)
      }
    } else {
      match m {
        0 => 0.0 // atan(+...,+INF)
        1 => -0.0 // atan(-...,+INF)
        2 => pi // atan(+...,-INF)
        _ => -pi // atan(-...,-INF)
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
    musl_atanf(@skia.fabs(y / x))
  }
  match m {
    0 => z // atan(+,+)
    1 => -z // atan(-,+)
    2 => pi - (z - pi_lo) // atan(+,-)
    _ => z - pi_lo - pi // atan(-,-)
  }
}
