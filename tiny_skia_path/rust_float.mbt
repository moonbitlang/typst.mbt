// Helpers reproducing Rust's `f32`/`f64` primitive semantics (not an upstream
// module). Rust's `f32::min`/`max` lower to `llvm.minnum`/`maxnum`, which on
// aarch64 are `fminnm`/`fmaxnm`: a NaN operand is ignored and `-0 < +0`.

///|
/// Rust `f32::is_finite`.
fn is_finite(x : Float) -> Bool {
  x == x && x.abs() != @float.infinity
}

///|
/// Rust `f64::is_finite`.
fn is_finite_f64(x : Double) -> Bool {
  x == x && x.abs() != @double.infinity
}

///|
/// Rust `f32::min`.
fn fmin(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_int() < 0 {
    a
  } else {
    b
  }
}

///|
/// Rust `f32::max`.
fn fmax(a : Float, b : Float) -> Float {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_int() < 0 {
    b
  } else {
    a
  }
}

///|
/// Rust `f32::round` (half away from zero).
fn round_f32(x : Float) -> Float {
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    if x < 0.0 {
      t - 1.0
    } else {
      t + 1.0
    }
  } else {
    t
  }
}

///|
/// Rust `f32 as u32` (saturating, NaN -> 0).
fn f32_as_u32(x : Float) -> UInt {
  if x != x || x <= 0.0 {
    0
  } else if x >= 4294967296.0 {
    4294967295
  } else {
    x.to_double().to_int64().reinterpret_as_uint64().to_uint()
  }
}

///|
/// Rust `f32 as i32` (saturating, NaN -> 0).
fn f32_as_i32(x : Float) -> Int {
  x.to_int()
}

///|
/// Rust `f64 as i32` (saturating, NaN -> 0).
fn f64_as_i32(x : Double) -> Int {
  if x != x {
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
/// Rust `u32 as f32`.
fn u32_as_f32(x : UInt) -> Float {
  Float::from_uint(x)
}

///|
/// Rust `i32 as f32`.
fn i32_as_f32(x : Int) -> Float {
  Float::from_int(x)
}

///|
/// Rust `i32::saturating_sub`.
fn i32_saturating_sub(a : Int, b : Int) -> Int {
  let r = a.to_int64() - b.to_int64()
  if r > 2147483647L {
    2147483647
  } else if r < -2147483648L {
    -2147483648
  } else {
    r.to_int()
  }
}

///|
/// Rust `i32::saturating_add`.
fn i32_saturating_add(a : Int, b : Int) -> Int {
  let r = a.to_int64() + b.to_int64()
  if r > 2147483647L {
    2147483647
  } else if r < -2147483648L {
    -2147483648
  } else {
    r.to_int()
  }
}

///|
/// Rust `i32::checked_add`.
fn i32_checked_add(a : Int, b : Int) -> Int? {
  let r = a.to_int64() + b.to_int64()
  if r > 2147483647L || r < -2147483648L {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// Rust `i32::checked_sub`.
fn i32_checked_sub(a : Int, b : Int) -> Int? {
  let r = a.to_int64() - b.to_int64()
  if r > 2147483647L || r < -2147483648L {
    None
  } else {
    Some(r.to_int())
  }
}
