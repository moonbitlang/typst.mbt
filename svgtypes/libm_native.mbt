// The C math library functions that Rust's `f64` methods call (on native
// targets), for bit-identical results with upstream where the core `@math`
// implementations differ in the last place.

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_pow(x : Double, y : Double) -> Double = "pow"

///|
extern "C" fn libm_tan(x : Double) -> Double = "tan"

///|
extern "C" fn sincos_sin(x : Double) -> Double = "svgtypes_sincos_sin"

///|
extern "C" fn sincos_cos(x : Double) -> Double = "svgtypes_sincos_cos"

///|
/// Rust `f64::sin_cos` (LLVM merges it into one `sincos` call, which on
/// Apple platforms is `__sincos_stret`; see `sincos_stub.c`).
fn libm_sin_cos(x : Double) -> (Double, Double) {
  (sincos_sin(x), sincos_cos(x))
}
