// Rust's `f64::cbrt` on native targets.
//
// `f64::cbrt` is the C symbol `cbrt` (`library/std/src/num/f64.rs:646`:
// `core::f64::math::cbrt`, an `extern "C"` declaration). Rust's
// compiler-builtins defines that symbol itself, weakly, from its `libm`
// (`compiler-builtins/src/math/mod.rs`, `full_availability`), on every
// target but Windows and Apple's, and where the C library is a shared
// object the definition in the executable wins. So on the glibc targets
// (x86_64-unknown-linux-gnu, what the oracle is built for on Linux)
// `f64::cbrt` is `libm::cbrt`, the correctly rounded cube root ported in
// `cbrt.mbt`, and not glibc's, which is not correctly rounded; on macOS it
// is Apple's `cbrt`, which is not correctly rounded either (an ulp off
// `libm::cbrt` for 8% of random doubles, macOS 26.4), so there the port has
// to call it to give what upstream gives: with `cbrt.mbt` instead, 14 of the
// 3340 cases of `kurbo/stroke_oracle_test.mbt` differ.
//
// Not covered: a Rust binary that links its C library statically (the musl
// targets by default) may resolve `cbrt` to that library's, since its
// archive can come before compiler-builtins' on the link line. The C
// preprocessor cannot tell such a build of the port from a glibc one, and
// no expectation of this repository is made by such a binary: every Linux
// build of the port follows the glibc targets.

///|
extern "C" fn system_cbrt(x : Double) -> Double = "cbrt"

///|
extern "C" fn f64_cbrt_is_system_ffi() -> Int = "typst_libm_f64_cbrt_is_system"

///|
/// Whether `f64_cbrt` is the C library's `cbrt` on this platform (Windows and
/// Apple targets).
fn f64_cbrt_is_system() -> Bool {
  f64_cbrt_is_system_ffi() != 0
}

///|
/// Rust's `f64::cbrt`: `cbrt` on the targets where Rust links its own, the
/// C library's on Windows and Apple targets.
pub fn f64_cbrt(x : Double) -> Double {
  if f64_cbrt_is_system() {
    system_cbrt(x)
  } else {
    cbrt(x)
  }
}
