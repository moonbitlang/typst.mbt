// The C math library functions that Rust's float methods call (on native
// targets), for bit-identical results with upstream.

///|
extern "C" fn libm_tan(x : Double) -> Double = "tan"

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_pow(x : Double, y : Double) -> Double = "pow"

///|
extern "C" fn libm_log2(x : Double) -> Double = "log2"

///|
extern "C" fn libm_atan2f(y : Float, x : Float) -> Float = "atan2f"

///|
/// Part of Rust's `sin_cos` (see `sincos_stub.c`).
extern "C" fn sincos_sin(x : Double) -> Double = "usvg_sincos_sin"

///|
/// Part of Rust's `sin_cos` (see `sincos_stub.c`).
extern "C" fn sincos_cos(x : Double) -> Double = "usvg_sincos_cos"
