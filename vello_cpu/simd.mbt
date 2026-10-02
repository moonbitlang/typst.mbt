// Lane semantics of the `fearless_simd` operations vello uses, as compiled
// for aarch64 with NEON (the upstream oracle's target). Every SIMD operation
// is applied per lane, so the vectorized upstream code is ported as scalar
// loops over the lanes.

///|
fn is_sign_negative(x : Float) -> Bool {
  x.reinterpret_as_int() < 0
}

///|
/// `vminq_f32` (`f32xN::min`): NaN-propagating, `min(-0, +0) = -0`.
fn vmin(a : Float, b : Float) -> Float {
  if a != a {
    a
  } else if b != b {
    b
  } else if a < b {
    a
  } else if b < a {
    b
  } else if is_sign_negative(a) {
    a
  } else {
    b
  }
}

///|
/// `vmaxq_f32` (`f32xN::max`): NaN-propagating, `max(-0, +0) = +0`.
fn vmax(a : Float, b : Float) -> Float {
  if a != a {
    a
  } else if b != b {
    b
  } else if a > b {
    a
  } else if b > a {
    b
  } else if is_sign_negative(a) {
    b
  } else {
    a
  }
}

///|
/// Rust's `f32::min` (IEEE minNum, `fminnm` on aarch64) and
/// `f32xN::min_precise` (`vminnmq_f32`): NaN operands are ignored.
fn fminnm(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if is_sign_negative(a) {
    a
  } else {
    b
  }
}

///|
/// Rust's `f32::max` (IEEE maxNum, `fmaxnm` on aarch64) and
/// `f32xN::max_precise` (`vmaxnmq_f32`).
fn fmaxnm(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if is_sign_negative(a) {
    b
  } else {
    a
  }
}

///|
/// Rust's `f64::min`.
fn dmin(a : Double, b : Double) -> Double {
  if a != a {
    b
  } else if b != b {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_int64() < 0 {
    a
  } else {
    b
  }
}

///|
/// Rust's `f64::max`.
fn dmax(a : Double, b : Double) -> Double {
  if a != a {
    b
  } else if b != b {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_int64() < 0 {
    b
  } else {
    a
  }
}

///|
/// Rust's `f32::clamp`.
fn fclamp(x : Float, lo : Float, hi : Float) -> Float {
  let mut x = x
  if x < lo {
    x = lo
  }
  if x > hi {
    x = hi
  }
  x
}

///|
/// `f32xN::mul_add(self, b, c)` (`vfmaq_f32`): `self * b + c`, fused.
fn madd(a : Float, b : Float, c : Float) -> Float {
  fmaf(a, b, c)
}

///|
/// `f32 as u8` (saturating, NaN maps to 0).
fn f32_as_u8(x : Float) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 255.0 {
    255
  } else {
    x.to_int()
  }
}

///|
/// `f32 as u16` (saturating, NaN maps to 0).
fn f32_as_u16(x : Float) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 65535.0 {
    65535
  } else {
    x.to_int()
  }
}

///|
/// `f32 as u32` / `vcvtq_u32_f32` (truncating, saturating, NaN maps to 0).
fn f32_as_u32(x : Float) -> UInt {
  if x != x || x <= 0.0 {
    0
  } else if x >= 4294967295.0 {
    4294967295
  } else {
    x.to_double().to_uint64().to_uint()
  }
}

///|
/// `f32 as i32` / `vcvtq_s32_f32` (truncating, saturating, NaN maps to 0).
fn f32_as_i32(x : Float) -> Int {
  if x != x {
    0
  } else {
    x.to_int()
  }
}

///|
/// `f32 as usize` (saturating, NaN maps to 0).
fn f32_as_usize(x : Float) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// `f64 as u16` (saturating, NaN maps to 0).
fn f64_as_u16(x : Double) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 65535.0 {
    65535
  } else {
    x.to_int()
  }
}

///|
/// `f64 as f32`.
fn f32(x : Double) -> Float {
  Float::from_double(x)
}

///|
/// `u16::saturating_sub`.
fn u16_sat_sub(a : Int, b : Int) -> Int {
  if a > b {
    a - b
  } else {
    0
  }
}

///|
/// `u16::saturating_add`.
fn u16_sat_add(a : Int, b : Int) -> Int {
  let s = a + b
  if s > 65535 {
    65535
  } else {
    s
  }
}

///|
/// `u16::saturating_mul`.
fn u16_sat_mul(a : Int, b : Int) -> Int {
  let s = a * b
  if s > 65535 {
    65535
  } else {
    s
  }
}

///|
/// `x.div_ceil(d)` for non-negative integers.
fn div_ceil(x : Int, d : Int) -> Int {
  (x + d - 1) / d
}

///|
/// `Div255Ext::div_255` on a `u16` lane: `(val + 255) >> 8` (wrapping add).
fn div_255(val : Int) -> Int {
  ((val + 255) & 0xFFFF) >> 8
}

///|
/// `normalized_mul` on `u8` lanes: `div_255(a * b)` (in `u16`).
fn norm_mul(a : Int, b : Int) -> Int {
  div_255((a * b) & 0xFFFF)
}

///|
/// `u8_to_f32(x) * (1.0 / 255.0)`.
fn u8_to_unit(x : Int) -> Float {
  Float::from_int(x) * ((1.0 : Float) / 255.0)
}

///|
/// `NumericVec::from_f32` for `u8x16`: `f32_to_u8(val.mul_add(255.0, 0.5))`.
fn unit_to_u8(x : Float) -> Int {
  (f32_as_u32(madd(x, 255.0, 0.5)) & 0xFF).reinterpret_as_int()
}

///|
/// `f32_to_u8` on a single lane (the low byte of `vcvtq_u32_f32`).
fn f32_to_u8_lane(x : Float) -> Int {
  (f32_as_u32(x) & 0xFF).reinterpret_as_int()
}
