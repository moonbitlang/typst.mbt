// The C math library functions that Rust's `f64` methods call (on native
// targets), for bit-identical results with upstream where the core `@math`
// implementations differ in the last place.

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_cbrt(x : Double) -> Double = "cbrt"

///|
extern "C" fn libm_sin(x : Double) -> Double = "sin"

///|
extern "C" fn libm_cos(x : Double) -> Double = "cos"
