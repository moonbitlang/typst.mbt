// Fallbacks for `libm_native.mbt` on non-native targets.

///|
fn sincosf_sin(x : Float) -> Float {
  @skia.sinf(x)
}

///|
fn sincosf_cos(x : Float) -> Float {
  @skia.cosf(x)
}
