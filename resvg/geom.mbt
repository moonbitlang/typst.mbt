// Port of `resvg/src/geom.rs`.

///|
/// Fits the current rect into the specified bounds.
fn fit_to_rect(r : @path.IntRect, bounds : @path.IntRect) -> @path.IntRect? {
  let mut left = r.left()
  if left < bounds.left() {
    left = bounds.left()
  }
  let mut top = r.top()
  if top < bounds.top() {
    top = bounds.top()
  }
  let mut right = r.right()
  if right > bounds.right() {
    right = bounds.right()
  }
  let mut bottom = r.bottom()
  if bottom > bounds.bottom() {
    bottom = bounds.bottom()
  }
  @path.IntRect::from_ltrb(left, top, right, bottom)
}

///|
/// `i32::checked_sub`.
fn checked_sub_i32(a : Int, b : Int) -> Int? {
  let r = a.to_int64() - b.to_int64()
  if r < -2147483648L || r > 2147483647L {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// `u32::checked_add`.
fn checked_add_u32(a : UInt, b : UInt) -> UInt? {
  let r = a.to_uint64() + b.to_uint64()
  if r > 0xFFFFFFFFUL {
    None
  } else {
    Some(r.to_uint())
  }
}

///|
/// `x as u8` for an `f32` (saturating, NaN maps to 0).
fn f32_to_u8(x : Float) -> Int {
  @skia.f32_to_u8(x)
}

///|
/// `x as u8` for an `f64` (saturating, NaN maps to 0).
fn f64_to_u8(x : Double) -> Int {
  if x != x {
    0
  } else if x >= 255.0 {
    255
  } else if x <= 0.0 {
    0
  } else {
    x.to_int()
  }
}

///|
/// `x as i32` for an `f64` (saturating, NaN maps to 0).
fn f64_to_i32(x : Double) -> Int {
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
/// `x as i64` for an `f64` (saturating, NaN maps to 0).
fn f64_to_i64(x : Double) -> Int64 {
  if x != x {
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
/// `x as i32` for an `f32` (saturating, NaN maps to 0).
fn f32_to_i32(x : Float) -> Int {
  f64_to_i32(x.to_double())
}

///|
/// `x as u32` for an `f32` (saturating, NaN maps to 0).
fn f32_to_u32(x : Float) -> UInt {
  @skia.f32_to_u32(x)
}

///|
fn i32_to_f32(x : Int) -> Float {
  Float::from_int(x)
}

///|
fn u32_to_f32(x : UInt) -> Float {
  @skia.u32_to_f32(x)
}
