// The C math library functions that Rust's `f32` methods call (on native
// targets), for bit-identical results with upstream.

///|
/// `f32::floor`.
pub extern "C" fn floorf(x : Float) -> Float = "floorf"

///|
/// `f32::ceil`.
pub extern "C" fn ceilf(x : Float) -> Float = "ceilf"

///|
/// `f32::trunc`.
pub extern "C" fn truncf(x : Float) -> Float = "truncf"

///|
/// `f32::round` (half away from zero).
pub extern "C" fn roundf(x : Float) -> Float = "roundf"

///|
/// Round half to even (`vrndnq_f32`).
pub extern "C" fn rintf(x : Float) -> Float = "rintf"

///|
/// `f32::sin`.
pub extern "C" fn sinf(x : Float) -> Float = "sinf"

///|
/// `f32::cos`.
pub extern "C" fn cosf(x : Float) -> Float = "cosf"

///|
/// `f32::tan`.
pub extern "C" fn tanf(x : Float) -> Float = "tanf"

///|
/// `f32::acos`.
pub extern "C" fn acosf(x : Float) -> Float = "acosf"

///|
/// `f32::atan2`.
pub extern "C" fn atan2f(y : Float, x : Float) -> Float = "atan2f"

///|
/// `f32::powf`.
pub extern "C" fn powf(x : Float, y : Float) -> Float = "powf"

///|
/// `f32::mul_add` (fused multiply-add).
pub extern "C" fn fmaf(x : Float, y : Float, z : Float) -> Float = "fmaf"

///|
/// `f32 % f32`.
pub extern "C" fn fmodf(x : Float, y : Float) -> Float = "fmodf"
