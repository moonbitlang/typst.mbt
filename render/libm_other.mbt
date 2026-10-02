// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn libm_atan2(y : Double, x : Double) -> Double {
  @math.atan2(y, x)
}

///|
fn libm_hypot(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}
