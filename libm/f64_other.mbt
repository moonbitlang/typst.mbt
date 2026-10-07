// Rust's `f64::cbrt` on the targets without a C library (wasm, wasm-gc, js):
// like on Rust's own wasm targets, it is the `cbrt` of compiler-builtins
// (see `f64_native.mbt`).

///|
/// Rust's `f64::cbrt`: `cbrt` on the targets where Rust links its own, the
/// C library's on Windows and Apple targets.
pub fn f64_cbrt(x : Double) -> Double {
  cbrt(x)
}
