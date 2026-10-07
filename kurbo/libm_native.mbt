// The C math library functions that Rust's `f64` methods call (on native
// targets), for bit-identical results with upstream.
//
// `f64::cbrt` is not among them: Rust links its own on Linux, see
// `@libm.f64_cbrt` (`libm/f64_native.mbt`).

///|
extern "C" fn libm_sin(x : Double) -> Double = "sin"

///|
extern "C" fn libm_cos(x : Double) -> Double = "cos"

///|
extern "C" fn libm_tan(x : Double) -> Double = "tan"

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_pow(x : Double, y : Double) -> Double = "pow"

///|
extern "C" fn libm_ln(x : Double) -> Double = "log"

///|
extern "C" fn libm_log2(x : Double) -> Double = "log2"

///|
extern "C" fn libm_hypot(x : Double, y : Double) -> Double = "hypot"

///|
extern "C" fn libm_fmod(x : Double, y : Double) -> Double = "fmod"

///|
/// `f64::mul_add` (a fused multiply-add with a single rounding).
extern "C" fn libm_fma(a : Double, b : Double, c : Double) -> Double = "fma"

///|
extern "C" fn libm_sincos_sin(x : Double) -> Double = "kurbo_sincos_sin"

///|
extern "C" fn libm_sincos_cos(x : Double) -> Double = "kurbo_sincos_cos"
