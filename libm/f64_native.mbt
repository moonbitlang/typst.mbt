// Rust's `f64::cbrt` on native targets.
//
// `f64::cbrt` is the C symbol `cbrt`. Rust's compiler-builtins defines that
// symbol itself, from its `libm` (`compiler-builtins/src/math/mod.rs`,
// `full_availability`), on every target but Windows and Apple's, and the
// linker takes it before the C library's. So on Linux `f64::cbrt` is
// `libm::cbrt`, the correctly rounded cube root ported in `cbrt.mbt`, and
// not glibc's, which is not correctly rounded; on macOS it is Apple's
// `cbrt`, which is not correctly rounded either (an ulp off `libm::cbrt` for
// 8% of random doubles, macOS 26.4), so there the port has to call it to
// give what upstream gives: with `cbrt.mbt` instead, 14 of the 3340 cases
// of `kurbo/stroke_oracle_test.mbt` differ.

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
