// The C math library functions that Rust's `f32` methods (and the NEON
// instructions of fearless_simd) compute on native targets, for bit-identical
// results with upstream (see `math.mbt`). C compilers lower them to single
// instructions (`fmadd`, `frintm`, `frinta` on aarch64).

///|
/// `f32::mul_add` / NEON `vfmaq_f32` (fused multiply-add).
extern "C" fn fmaf(x : Float, y : Float, z : Float) -> Float = "fmaf"

///|
/// `f32::floor` / NEON `vrndmq_f32`.
extern "C" fn floorf(x : Float) -> Float = "floorf"

///|
/// `f32::round` (half-way cases away from zero).
extern "C" fn roundf(x : Float) -> Float = "roundf"
