// Fallbacks for `libm_native.mbt` on non-native targets (not bit-exact).

///|
fn libm_cosf(x : Float) -> Float {
  Float::from_double(@math.cos(x.to_double()))
}

///|
fn libm_acosf(x : Float) -> Float {
  Float::from_double(@math.acos(x.to_double()))
}

///|
fn libm_powf(x : Float, y : Float) -> Float {
  Float::from_double(@math.pow(x.to_double(), y.to_double()))
}

///|
fn libm_sincosf_sin(x : Float) -> Float {
  Float::from_double(@math.sin(x.to_double()))
}

///|
fn libm_sincosf_cos(x : Float) -> Float {
  libm_cosf(x)
}
