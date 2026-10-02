// Rust float semantics used by the port (not an upstream module).

///|
let pi : Double = @math.PI

///|
/// Rust `f64::to_degrees`.
fn f64_to_degrees(x : Double) -> Double {
  x * (180.0 / pi)
}

///|
/// Rust `f64::to_radians`.
fn f64_to_radians(x : Double) -> Double {
  x * (pi / 180.0)
}

///|
/// Rust `f64::round` (half away from zero).
fn f64_round(x : Double) -> Double {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let t = x.trunc()
  let d = x - t
  if d >= 0.5 {
    t + 1.0
  } else if d <= -0.5 {
    t - 1.0
  } else {
    t
  }
}

///|
/// Rust `f32::round` (half away from zero).
fn f32_round(x : Float) -> Float {
  if x != x {
    return x
  }
  let t = x.trunc()
  let d = x - t
  if d >= 0.5 {
    t + 1.0
  } else if d <= -0.5 {
    t - 1.0
  } else {
    t
  }
}

///|
/// Rust `x as u8` for `f64` (saturating, NaN -> 0).
fn f64_as_u8(x : Double) -> Byte {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 255.0 {
    255
  } else {
    x.to_int().to_byte()
  }
}

///|
/// Rust `x as u8` for `f32` (saturating, NaN -> 0).
fn f32_as_u8(x : Float) -> Byte {
  f64_as_u8(x.to_double())
}

///|
/// Rust `x as usize` for `f64` (saturating, NaN -> 0), clamped to `Int`.
fn f64_as_usize(x : Double) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// Rust `f64::max`.
fn f64_max(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

///|
/// Rust `f64::signum`.
fn f64_signum(x : Double) -> Double {
  if x.is_nan() {
    x
  } else if x.reinterpret_as_uint64() >> 63 == 1UL {
    -1.0
  } else {
    1.0
  }
}

///|
/// Rust `f64::is_sign_negative`.
fn f64_is_sign_negative(x : Double) -> Bool {
  x.reinterpret_as_uint64() >> 63 == 1UL
}

///|
/// Rust `f64::clamp`.
fn f64_clamp(x : Double, min : Double, max : Double) -> Double {
  let mut x = x
  if x < min {
    x = min
  }
  if x > max {
    x = max
  }
  x
}
