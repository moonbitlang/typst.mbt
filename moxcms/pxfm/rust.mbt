// Rust float semantics (rounding, saturating `as` casts, `min`/`max`) used by
// `pxfm` and `moxcms`.

///|
/// Rust `f64::round` (half away from zero).
pub fn round_f64(x : Double) -> Double {
  if x.is_nan() || x.is_inf() || x.abs() >= 4503599627370496.0 {
    return x
  }
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    if x > 0.0 {
      t + 1.0
    } else {
      t - 1.0
    }
  } else {
    t
  }
}

///|
/// Rust `f32::round` (half away from zero).
pub fn round_f32(x : Float) -> Float {
  if x.is_nan() || x.is_inf() || x.abs() >= 8388608.0 {
    return x
  }
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    if x > 0.0 {
      t + 1.0
    } else {
      t - 1.0
    }
  } else {
    t
  }
}

///|
/// Rust `f64::round_ties_even`.
pub fn round_ties_even_f64(x : Double) -> Double {
  if x.is_nan() || x.is_inf() || x.abs() >= 4503599627370496.0 {
    return x
  }
  let t = x.trunc()
  let d = (x - t).abs()
  if d > 0.5 || (d == 0.5 && (t * 0.5).trunc() != t * 0.5) {
    if x > 0.0 {
      t + 1.0
    } else {
      t - 1.0
    }
  } else {
    t
  }
}

///|
/// Rust `f32::round_ties_even`.
pub fn round_ties_even_f32(x : Float) -> Float {
  if x.is_nan() || x.is_inf() || x.abs() >= 8388608.0 {
    return x
  }
  let t = x.trunc()
  let d = (x - t).abs()
  if d > 0.5 || (d == 0.5 && (t * 0.5).trunc() != t * 0.5) {
    if x > 0.0 {
      t + 1.0
    } else {
      t - 1.0
    }
  } else {
    t
  }
}

///|
/// Rust `f32::max` (a NaN operand is ignored).
pub fn max_f32(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 && a.reinterpret_as_uint() == 0U {
    a
  } else {
    b
  }
}

///|
/// Rust `f32::min` (a NaN operand is ignored).
pub fn min_f32(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 && a.reinterpret_as_uint() != 0U {
    a
  } else {
    b
  }
}

///|
/// Rust `f64::max` (a NaN operand is ignored).
pub fn max_f64(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a == 0.0 && a.reinterpret_as_uint64() == 0UL {
    a
  } else {
    b
  }
}

///|
/// Rust `f64::min` (a NaN operand is ignored).
pub fn min_f64(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a == 0.0 && a.reinterpret_as_uint64() != 0UL {
    a
  } else {
    b
  }
}

///|
/// Rust `x as i64` for `f64` (saturating, NaN -> 0).
pub fn f64_as_i64(x : Double) -> Int64 {
  if x.is_nan() {
    0L
  } else if x >= 9223372036854775807.0 {
    9223372036854775807L
  } else if x <= -9223372036854775808.0 {
    -9223372036854775808L
  } else {
    x.to_int64()
  }
}

///|
/// Rust `x as i32` for `f64` (saturating, NaN -> 0).
pub fn f64_as_i32(x : Double) -> Int {
  if x.is_nan() {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else if x <= -2147483648.0 {
    -2147483648
  } else {
    x.to_int()
  }
}

///|
/// Rust `x as u16` for `f64` (saturating, NaN -> 0).
pub fn f64_as_u16(x : Double) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 65535.0 {
    65535
  } else {
    x.to_int()
  }
}

///|
/// Rust `x as i32` for `f32` (saturating, NaN -> 0).
pub fn f32_as_i32(x : Float) -> Int {
  f64_as_i32(x.to_double())
}

///|
/// Rust `x as u32` for `f32` (saturating, NaN -> 0), as `Int64`.
pub fn f32_as_u32(x : Float) -> Int64 {
  let d = x.to_double()
  if d.is_nan() || d <= 0.0 {
    0L
  } else if d >= 4294967295.0 {
    4294967295L
  } else {
    d.to_int64()
  }
}

///|
/// Rust `x as u16` for `f32` (saturating, NaN -> 0).
pub fn f32_as_u16(x : Float) -> Int {
  f64_as_u16(x.to_double())
}

///|
/// Rust `x as i16` for `f32` (saturating, NaN -> 0).
pub fn f32_as_i16(x : Float) -> Int {
  let d = x.to_double()
  if d.is_nan() {
    0
  } else if d >= 32767.0 {
    32767
  } else if d <= -32768.0 {
    -32768
  } else {
    d.to_int()
  }
}

///|
/// Rust `x as u8` for `f32` (saturating, NaN -> 0).
pub fn f32_as_u8(x : Float) -> Int {
  let d = x.to_double()
  if d.is_nan() || d <= 0.0 {
    0
  } else if d >= 255.0 {
    255
  } else {
    d.to_int()
  }
}
