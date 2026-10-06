// Fallback for `libm_native.mbt` on non-native targets.

///|
fn libm_powf(x : Float, y : Float) -> Float {
  // Like the deprecated `Float::pow`: a `Double` power, rounded. (`@math.pow`
  // and the deprecated `Double::pow` only differ for a base of +-1 with an
  // infinite or NaN exponent; the only caller passes 1/6.)
  Float::from_double(@math.pow(x.to_double(), y.to_double()))
}

///|
fn f32_floor(x : Float) -> Float {
  x.floor()
}

///|
fn f32_ceil(x : Float) -> Float {
  x.ceil()
}
