// The C math library functions that Rust's `f32` methods call (on native
// targets), for bit-identical results with upstream.

///|
extern "C" fn libm_cosf(x : Float) -> Float = "cosf"

///|
extern "C" fn libm_acosf(x : Float) -> Float = "acosf"

///|
extern "C" fn libm_powf(x : Float, y : Float) -> Float = "powf"

///|
/// `sin` part of LLVM's merged `sincosf` (`__sincosf_stret` on Apple).
extern "C" fn libm_sincosf_sin(x : Float) -> Float = "tiny_skia_path_sincosf_sin"

///|
/// `cos` part of LLVM's merged `sincosf` (`__sincosf_stret` on Apple).
extern "C" fn libm_sincosf_cos(x : Float) -> Float = "tiny_skia_path_sincosf_cos"
