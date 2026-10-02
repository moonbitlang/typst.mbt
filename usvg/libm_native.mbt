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
extern "C" fn libm_sinf(x : Float) -> Float = "sinf"

///|
extern "C" fn libm_cosf(x : Float) -> Float = "cosf"

///|
extern "C" fn libm_tanf(x : Float) -> Float = "tanf"

///|
extern "C" fn libm_atan2f(y : Float, x : Float) -> Float = "atan2f"
