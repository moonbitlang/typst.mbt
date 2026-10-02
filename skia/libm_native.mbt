// The C math library functions that Rust's `f64` methods call (on native
// targets), for bit-identical results with upstream.

///|
extern "C" fn libm_acos(x : Double) -> Double = "acos"

///|
extern "C" fn libm_cos(x : Double) -> Double = "cos"
