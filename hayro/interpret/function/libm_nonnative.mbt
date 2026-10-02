// Fallbacks for the C math functions used on native (see `libm_native.mbt`).

///|
fn sinf(x : Float) -> Float {
  @math.sinf(x)
}

///|
fn cosf(x : Float) -> Float {
  @math.cosf(x)
}

///|
fn powf(x : Float, y : Float) -> Float {
  @math.powf(x, y)
}

///|
fn logf(x : Float) -> Float {
  @math.lnf(x)
}

///|
fn log10f(x : Float) -> Float {
  Float::from_double(@math.log10(x.to_double()))
}

///|
fn atan2f(y : Float, x : Float) -> Float {
  @math.atan2f(y, x)
}

///|
fn fmodf(x : Float, y : Float) -> Float {
  x.mod(y)
}
