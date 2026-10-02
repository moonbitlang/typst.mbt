// Native targets: the C library's correctly rounded `fma`/`fmaf` (a single
// instruction on aarch64), identical to the software emulation in
// `common.mbt` but much faster.

///|
extern "C" fn libm_fma(a : Double, b : Double, c : Double) -> Double = "fma"

///|
extern "C" fn libm_fmaf(a : Float, b : Float, c : Float) -> Float = "fmaf"

///|
/// Fused multiply-add `a * b + c` with a single rounding (Rust
/// `f64::mul_add`).
pub fn fma(a : Double, b : Double, c : Double) -> Double {
  libm_fma(a, b, c)
}

///|
/// Fused multiply-add `a * b + c` in single precision (Rust `f32::mul_add`).
pub fn fmaf(a : Float, b : Float, c : Float) -> Float {
  libm_fmaf(a, b, c)
}
