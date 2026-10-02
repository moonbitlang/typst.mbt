// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn libm_acos(x : Double) -> Double {
  @math.acos(x)
}

///|
fn libm_cos(x : Double) -> Double {
  @math.cos(x)
}
