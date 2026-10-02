// `f32::sin`/`f32::cos` of the same argument, merged by LLVM into one
// `sincosf` call (`__sincosf_stret` on Apple); the C stubs live in `usvg`
// (`sincos_stub.c`).

///|
extern "C" fn sincosf_sin(x : Float) -> Float = "usvg_sincosf_sin"

///|
extern "C" fn sincosf_cos(x : Float) -> Float = "usvg_sincosf_cos"
