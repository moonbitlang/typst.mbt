///|
/// `f64_cbrt` is the port on the targets without a C library.
test "f64_cbrt" {
  let rng = CbrtTestRng::{ state: 0x6636345f63627274UL, }
  for _ in 0..<20000 {
    let x = cbrt_test_sample(rng, 0, 2047, true)
    assert_eq(cbrt_test_canon(f64_cbrt(x)), cbrt_test_canon(cbrt(x)))
  }
  assert_eq(f64_cbrt(27.0), 3.0)
  assert_eq(f64_cbrt(-0.125), -0.5)
}
