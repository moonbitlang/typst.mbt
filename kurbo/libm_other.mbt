// Fallbacks for `libm_native.mbt` on non-native targets (not bit-exact).

///|
fn libm_sin(x : Double) -> Double {
  @math.sin(x)
}

///|
fn libm_cos(x : Double) -> Double {
  @math.cos(x)
}

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
fn libm_ln(x : Double) -> Double {
  @math.ln(x)
}

///|
fn libm_log2(x : Double) -> Double {
  @math.log2(x)
}

///|
fn libm_cbrt(x : Double) -> Double {
  @math.cbrt(x)
}

///|
fn libm_hypot(x : Double, y : Double) -> Double {
  @math.hypot(x, y)
}

///|
fn libm_fmod(x : Double, y : Double) -> Double {
  x % y
}

///|
/// Not fused on non-native targets.
fn libm_fma(a : Double, b : Double, c : Double) -> Double {
  a * b + c
}

///|
fn libm_sincos_sin(x : Double) -> Double {
  @math.sin(x)
}

///|
fn libm_sincos_cos(x : Double) -> Double {
  @math.cos(x)
}
