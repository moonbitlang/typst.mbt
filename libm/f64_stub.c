// Which `cbrt` Rust's `f64::cbrt` reaches on this platform (see
// `f64_native.mbt`): the system's on Windows and Apple targets, the one of
// Rust's own compiler-builtins (its `libm`, ported in `cbrt.mbt`)
// everywhere else.

#include <moonbit.h>
#include <stdint.h>

MOONBIT_FFI_EXPORT
int32_t typst_libm_f64_cbrt_is_system(void) {
#if defined(__APPLE__) || defined(_WIN32)
  return 1;
#else
  return 0;
#endif
}
