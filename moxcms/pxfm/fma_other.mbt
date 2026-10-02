// Non-native targets: exact software emulation (see `common.mbt`).

///|
/// Fused multiply-add `a * b + c` with a single rounding (Rust
/// `f64::mul_add`).
pub fn fma(a : Double, b : Double, c : Double) -> Double {
  soft_fma(a, b, c)
}

///|
/// Fused multiply-add `a * b + c` in single precision (Rust `f32::mul_add`).
pub fn fmaf(a : Float, b : Float, c : Float) -> Float {
  soft_fmaf(a, b, c)
}
