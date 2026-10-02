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
extern "C" fn libm_cbrt(x : Double) -> Double = "cbrt"

///|
extern "C" fn libm_log2(x : Double) -> Double = "log2"

///|
extern "C" fn libm_hypot(x : Double, y : Double) -> Double = "hypot"
