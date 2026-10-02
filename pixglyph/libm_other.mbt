// Fallback for `libm_native.mbt` on non-native targets.

///|
fn libm_powf(x : Float, y : Float) -> Float {
  x.pow(y)
}
