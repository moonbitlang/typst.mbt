// The C math library function that Rust's `f32::powf` calls (on native
// targets), for bit-identical results with upstream.

///|
extern "C" fn libm_powf(x : Float, y : Float) -> Float = "powf"

///|
/// `f32::floor` (exact; clang compiles it to one instruction, while the core
/// helper is a call).
extern "C" fn f32_floor(x : Float) -> Float = "floorf"

///|
/// `f32::ceil`.
extern "C" fn f32_ceil(x : Float) -> Float = "ceilf"
