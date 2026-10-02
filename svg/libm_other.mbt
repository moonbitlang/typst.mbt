// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn libm_atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
fn libm_pow(x : Double, y : Double) -> Double {
  @math.pow(x, y)
}

///|
fn libm_tan(x : Double) -> Double {
  @math.tan(x)
}

///|
fn libm_cbrt(x : Double) -> Double {
  @math.cbrt(x)
}

///|
fn libm_log2(x : Double) -> Double {
  @math.log2(x)
}

///|
fn libm_hypot(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}
