// The C math library functions that Rust's `f32` methods call on native
// targets, for bit-identical results with upstream.

///|
/// `f32::mul_add` / NEON `vfmaq_f32` (fused multiply-add).
extern "C" fn fmaf(x : Float, y : Float, z : Float) -> Float = "fmaf"
