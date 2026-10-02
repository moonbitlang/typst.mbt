// The C math library functions that Rust's `f32` methods call (on native
// targets), for bit-identical results with upstream.

///|
extern "C" fn libm_sinf(x : Float) -> Float = "sinf"

///|
extern "C" fn libm_expf(x : Float) -> Float = "expf"
