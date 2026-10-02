// The C math library functions that Rust's float methods call (on native
// targets), for bit-identical results with upstream.

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
extern "C" fn libm_sqrt(x : Double) -> Double = "sqrt"

///|
extern "C" fn libm_acos(x : Double) -> Double = "acos"

///|
extern "C" fn libm_asin(x : Double) -> Double = "asin"

///|
extern "C" fn libm_sinf(x : Float) -> Float = "sinf"

///|
extern "C" fn libm_cosf(x : Float) -> Float = "cosf"

///|
extern "C" fn libm_tanf(x : Float) -> Float = "tanf"

///|
extern "C" fn libm_atan2f(y : Float, x : Float) -> Float = "atan2f"

///|
extern "C" fn libm_acosf(x : Float) -> Float = "acosf"

///|
extern "C" fn libm_powf(x : Float, y : Float) -> Float = "powf"

///|
/// Part of Rust's `sin_cos` (see `sincos_stub.c`).
extern "C" fn sincos_sin(x : Double) -> Double = "usvg_sincos_sin"

///|
/// Part of Rust's `sin_cos` (see `sincos_stub.c`).
extern "C" fn sincos_cos(x : Double) -> Double = "usvg_sincos_cos"

///|
/// Part of Rust's `sin_cos` (see `sincos_stub.c`).
extern "C" fn sincosf_sin(x : Float) -> Float = "usvg_sincosf_sin"

///|
/// Part of Rust's `sin_cos` (see `sincos_stub.c`).
extern "C" fn sincosf_cos(x : Float) -> Float = "usvg_sincosf_cos"
