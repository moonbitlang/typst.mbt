///|
/// `f64_cbrt` is the port where Rust links compiler-builtins' `cbrt` (Linux),
/// and the C library's elsewhere (Apple's is within an ulp of the port).
test "f64_cbrt" {
  let rng = CbrtTestRng::{ state: 0x6636345f63627274UL, }
  for _ in 0..<20000 {
    let x = cbrt_test_sample(rng, 0, 2047, true)
    let port = cbrt_test_canon(cbrt(x))
    let got = cbrt_test_canon(f64_cbrt(x))
    if f64_cbrt_is_system() {
      assert_eq(got, cbrt_test_canon(system_cbrt(x)))
      assert_true(got == port || got == port + 1 || got + 1 == port)
    } else {
      assert_eq(got, port)
    }
  }
  assert_eq(f64_cbrt(27.0), 3.0)
  assert_eq(f64_cbrt(-0.125), -0.5)
}
