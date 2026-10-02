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
fn libm_sqrt(x : Double) -> Double {
  x.sqrt()
}

///|
fn libm_acos(x : Double) -> Double {
  @math.acos(x)
}

///|
fn libm_log2(x : Double) -> Double {
  @math.log2(x)
}

///|
fn libm_asin(x : Double) -> Double {
  @math.asin(x)
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

///|
fn libm_acosf(x : Float) -> Float {
  @math.acos(x.to_double()).to_float()
}

///|
fn libm_powf(x : Float, y : Float) -> Float {
  @math.pow(x.to_double(), y.to_double()).to_float()
}

///|
fn sincos_sin(x : Double) -> Double {
  @math.sin(x)
}

///|
fn sincos_cos(x : Double) -> Double {
  @math.cos(x)
}

///|
fn sincosf_sin(x : Float) -> Float {
  @math.sin(x.to_double()).to_float()
}

///|
fn sincosf_cos(x : Float) -> Float {
  @math.cos(x.to_double()).to_float()
}
