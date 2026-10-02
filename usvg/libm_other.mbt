// Fallbacks for `libm_native.mbt` on non-native targets.

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
fn libm_sinf(x : Float) -> Float {
  @math.sin(x.to_double()).to_float()
}

///|
fn libm_cosf(x : Float) -> Float {
  @math.cos(x.to_double()).to_float()
}

///|
fn libm_tanf(x : Float) -> Float {
  @math.tan(x.to_double()).to_float()
}

///|
fn libm_atan2f(y : Float, x : Float) -> Float {
  @math.atan2(y.to_double(), x.to_double()).to_float()
}
