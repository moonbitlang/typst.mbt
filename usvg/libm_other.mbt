// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn libm_tan(x : Double) -> Double {
  @math.tan(x)
}

///|
fn libm_atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
fn libm_pow(x : Double, y : Double) -> Double {
  @math.pow(x, y)
}

///|
fn libm_log2(x : Double) -> Double {
  @math.log2(x)
}

///|
fn libm_atan2f(y : Float, x : Float) -> Float {
  Float::from_double(@math.atan2(y.to_double(), x.to_double()))
}

///|
fn sincos_sin(x : Double) -> Double {
  @math.sin(x)
}

///|
fn sincos_cos(x : Double) -> Double {
  @math.cos(x)
}
