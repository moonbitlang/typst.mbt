// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn libm_atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
fn libm_sin(x : Double) -> Double {
  @math.sin(x)
}

///|
fn libm_cos(x : Double) -> Double {
  @math.cos(x)
}
