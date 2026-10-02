// The C math library function that Rust's `f32::powf` calls (on native
// targets), for bit-identical results with upstream.

///|
extern "C" fn libm_powf(x : Float, y : Float) -> Float = "powf"
