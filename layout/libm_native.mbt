// The C math library functions that Rust's `f64` methods call (on native
// targets), for bit-identical results with upstream where the core `@math`
// implementations differ in the last place.
//
// `f64::cbrt` is not among them: Rust links its own on Linux, see
// `@libm.f64_cbrt` (`libm/f64_native.mbt`).

///|
extern "C" fn libm_atan2(y : Double, x : Double) -> Double = "atan2"

///|
extern "C" fn libm_sin(x : Double) -> Double = "sin"

///|
extern "C" fn libm_cos(x : Double) -> Double = "cos"
