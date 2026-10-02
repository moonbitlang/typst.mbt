// Fallbacks for `libm_native.mbt` on non-native targets (not bit-exact for
// the transcendental functions).

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
  @math.sin(x.to_double()).to_float()
}

///|
pub fn cosf(x : Float) -> Float {
  @math.cos(x.to_double()).to_float()
}

///|
pub fn tanf(x : Float) -> Float {
  @math.tan(x.to_double()).to_float()
}

///|
pub fn acosf(x : Float) -> Float {
  @math.acos(x.to_double()).to_float()
}

///|
pub fn atan2f(y : Float, x : Float) -> Float {
  @math.atan2(y.to_double(), x.to_double()).to_float()
}

///|
pub fn powf(x : Float, y : Float) -> Float {
  @math.pow(x.to_double(), y.to_double()).to_float()
}

///|
pub fn fmaf(x : Float, y : Float, z : Float) -> Float {
  (x.to_double() * y.to_double() + z.to_double()).to_float()
}

///|
pub fn fmodf(x : Float, y : Float) -> Float {
  let xd = x.to_double()
  let yd = y.to_double()
  (xd - (xd / yd).trunc() * yd).to_float()
}
