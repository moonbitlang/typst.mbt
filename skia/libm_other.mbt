// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn libm_acos(x : Double) -> Double {
  @math.acos(x)
}

///|
fn libm_cos(x : Double) -> Double {
  @math.cos(x)
}

///|
pub fn floorf(x : Float) -> Float {
  x.floor()
}

///|
pub fn ceilf(x : Float) -> Float {
  x.ceil()
}

///|
pub fn truncf(x : Float) -> Float {
  x.trunc()
}

///|
pub fn roundf(x : Float) -> Float {
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    t + (if x < 0 { -1.0 } else { 1.0 })
  } else {
    t
  }
}

///|
pub fn rintf(x : Float) -> Float {
  let f = x.floor()
  let d = x - f
  if d > 0.5 {
    f + 1.0
  } else if d < 0.5 {
    f
  } else if (f * 0.5).floor() == f * 0.5 {
    f
  } else {
    f + 1.0
  }
}

///|
pub fn sinf(x : Float) -> Float {
  Float::from_double(@math.sin(x.to_double()))
}

///|
pub fn cosf(x : Float) -> Float {
  Float::from_double(@math.cos(x.to_double()))
}

///|
pub fn tanf(x : Float) -> Float {
  Float::from_double(@math.tan(x.to_double()))
}

///|
pub fn acosf(x : Float) -> Float {
  Float::from_double(@math.acos(x.to_double()))
}

///|
pub fn atan2f(y : Float, x : Float) -> Float {
  Float::from_double(@math.atan2(y.to_double(), x.to_double()))
}

///|
pub fn powf(x : Float, y : Float) -> Float {
  Float::from_double(@math.pow(x.to_double(), y.to_double()))
}

///|
pub fn fmaf(x : Float, y : Float, z : Float) -> Float {
  Float::from_double(x.to_double() * y.to_double() + z.to_double())
}

///|
pub fn fmodf(x : Float, y : Float) -> Float {
  let xd = x.to_double()
  let yd = y.to_double()
  Float::from_double(xd - (xd / yd).trunc() * yd)
}
