// Fallbacks for `libm_native.mbt` on non-native targets (not bit-exact).

///|
fn fmaf(x : Float, y : Float, z : Float) -> Float {
  Float::from_double(x.to_double() * y.to_double() + z.to_double())
}
