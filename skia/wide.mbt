// Lane semantics of `tiny-skia/src/wide/` as compiled for aarch64 with NEON
// (the upstream oracle's target): every SIMD operation is applied per lane.

///|
/// `vmaxq_f32`: NaN-propagating, `max(-0, +0) = +0`.
fn vmax(a : Float, b : Float) -> Float {
  if a != a {
    a
  } else if b != b {
    b
  } else if a > b {
    a
  } else if b > a {
    b
  } else if @path.is_sign_negative(a) {
    b
  } else {
    a
  }
}

///|
/// `vminq_f32`: NaN-propagating, `min(-0, +0) = -0`.
fn vmin(a : Float, b : Float) -> Float {
  if a != a {
    a
  } else if b != b {
    b
  } else if a < b {
    a
  } else if b < a {
    b
  } else if @path.is_sign_negative(a) {
    a
  } else {
    b
  }
}

///|
/// `f32x8::normalize`.
fn vnormalize(x : Float) -> Float {
  vmin(vmax(x, 0.0), 1.0)
}

///|
/// `vcvtq_s32_f32`: truncating, saturating, NaN maps to 0.
fn vtrunc_int(x : Float) -> Int {
  x.to_int()
}

///|
/// `vcvtnq_s32_f32`: round to nearest even, saturating, NaN maps to 0.
fn vround_int(x : Float) -> Int {
  @path.rintf(x).to_int()
}

///|
/// `f32x8::floor` (truncation round trip).
fn vfloor8(x : Float) -> Float {
  let roundtrip = Float::from_int(vtrunc_int(x))
  roundtrip - (if roundtrip > x { 1.0 } else { 0.0 })
}

///|
/// `f32x16::floor` (rounding round trip, used by lowp).
fn vfloor16(x : Float) -> Float {
  let roundtrip = @path.rintf(x)
  roundtrip - (if roundtrip > x { 1.0 } else { 0.0 })
}

///|
/// `f32x8::abs` (sign bit cleared).
fn vabs(x : Float) -> Float {
  @path.fabs(x)
}

///|
/// `Neg for f32x8`: `0 - x`.
fn vneg(x : Float) -> Float {
  0.0 - x
}

///|
/// `f32x8::powf`.
fn vpowf(x : Float, exp : Float) -> Float {
  let e = Float::from_int(x.reinterpret_as_int()) *
    ((1.0 : Float) / Float::from_int(1 << 23))
  let m = Float::reinterpret_from_uint(
    (x.reinterpret_as_uint() & 0x007fffff) | 0x3f000000,
  )
  let log2_x = e -
    (124.225514990 : Float) -
    (1.498030302 : Float) * m -
    (1.725879990 : Float) / ((0.3520887068 : Float) + m)
  let y = log2_x * exp
  let f = y - vfloor8(y)
  let mut a = y + (121.274057500 : Float)
  a = a - f * (1.490129070 : Float)
  a += (27.728023300 : Float) / ((4.84252568 : Float) - f)
  a *= Float::from_int(1 << 23)
  let inf_bits = Float::from_uint(@path.f32_infinity.reinterpret_as_uint())
  let r = Float::reinterpret_from_int(vround_int(vmin(vmax(a, 0.0), inf_bits)))
  if x == 0.0 || x == 1.0 {
    x
  } else {
    r
  }
}

///|
/// `FRECPE`: the ARM reciprocal estimate (8-bit precision).
fn frecpe(x : Float) -> Float {
  let bits = x.reinterpret_as_uint()
  let sign = bits & 0x80000000
  let exp = ((bits >> 23) & 0xFF).reinterpret_as_int()
  let mut fraction = bits & 0x7FFFFF
  if x != x {
    return Float::reinterpret_from_uint(bits | 0x400000)
  }
  if exp == 0xFF {
    // infinity
    return Float::reinterpret_from_uint(sign)
  }
  if exp == 0 && fraction == 0 {
    // zero
    return Float::reinterpret_from_uint(sign | 0x7F800000)
  }
  if (bits & 0x7FFFFFFF) < 0x00200000 {
    // |x| < 2^-128: overflow to infinity (round to nearest).
    return Float::reinterpret_from_uint(sign | 0x7F800000)
  }
  let mut e = exp
  if e == 0 {
    // denormal
    if (fraction & 0x400000) == 0 {
      e = -1
      fraction = (fraction & 0x1FFFFF) << 2
    } else {
      fraction = (fraction & 0x3FFFFF) << 1
    }
  }
  let scaled = (0x100U | (fraction >> 15)).reinterpret_as_int() // 9 bits
  let mut result_exp = 253 - e
  // RecipEstimate
  let a = scaled * 2 + 1
  let b = (1 << 19) / a
  let estimate = (b + 1) / 2
  let mut frac = (estimate & 0xFF).reinterpret_as_uint() << 15
  if result_exp == 0 {
    frac = 0x400000 | (frac >> 1)
  } else if result_exp == -1 {
    frac = 0x200000 | (frac >> 2)
    result_exp = 0
  }
  Float::reinterpret_from_uint(
    sign | ((result_exp & 0xFF).reinterpret_as_uint() << 23) | frac,
  )
}

///|
/// `FRECPS`: `2.0 - a * b` (fused).
fn frecps(a : Float, b : Float) -> Float {
  if (a.is_inf() && b == 0.0) || (a == 0.0 && b.is_inf()) {
    2.0
  } else {
    @path.fmaf(-a, b, 2.0)
  }
}

///|
/// `f32x4::recip_fast` on NEON: estimate plus one Newton-Raphson step.
fn vrecip_fast(x : Float) -> Float {
  let a = frecpe(x)
  frecps(x, a) * a
}
