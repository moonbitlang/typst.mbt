// Fallbacks for `imageops_libm_native.mbt` on non-native targets.

///|
fn libm_sinf(x : Float) -> Float {
  @math.sinf(x)
}

///|
fn libm_expf(x : Float) -> Float {
  @math.expf(x)
}
