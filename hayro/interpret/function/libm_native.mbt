// Rust's `f32` math methods call the platform's C math library (`sinf`,
// `powf`, ...). On native, call the same functions for bit-identical results.

///|
extern "C" fn sinf(x : Float) -> Float = "sinf"

///|
extern "C" fn cosf(x : Float) -> Float = "cosf"

///|
extern "C" fn powf(x : Float, y : Float) -> Float = "powf"

///|
extern "C" fn logf(x : Float) -> Float = "logf"

///|
extern "C" fn log10f(x : Float) -> Float = "log10f"

///|
extern "C" fn atan2f(y : Float, x : Float) -> Float = "atan2f"

///|
extern "C" fn fmodf(x : Float, y : Float) -> Float = "fmodf"
