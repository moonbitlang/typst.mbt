// Rust's `f64::sin_cos` (and adjacent `x.cos()` / `x.sin()` calls on the same
// argument) are merged by LLVM into a single `sincos` call; on Apple
// platforms that is `__sincos_stret`, which can differ from `sin`/`cos` in
// the last place. These stubs reproduce that for bit-identical results.

#include <math.h>
#include <moonbit.h>

MOONBIT_FFI_EXPORT
double kurbo_sincos_sin(double x) {
#if defined(__APPLE__)
  return __sincos_stret(x).__sinval;
#else
  return sin(x);
#endif
}

MOONBIT_FFI_EXPORT
double kurbo_sincos_cos(double x) {
#if defined(__APPLE__)
  return __sincos_stret(x).__cosval;
#else
  return cos(x);
#endif
}
