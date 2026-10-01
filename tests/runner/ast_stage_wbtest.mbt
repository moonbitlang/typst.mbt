///|
/// Expected strings produced by Rust's `format!("{:?}", v)` (rustc 1.97.1).
test "rust_debug_f64 matches Rust" {
  let cases : Array[(UInt64, String)] = [
    (0x3ff0000000000000UL, "1.0"),
    (0x3fb999999999999aUL, "0.1"),
    (0x4341c37937e08000UL, "1e16"),
    (0x430c6bf526340000UL, "1000000000000000.0"),
    (0x434aa535d3d0c000UL, "1.5e16"),
    (0x3f1a36e2eb1c432dUL, "0.0001"),
    (0x3f19f3c70c996b76UL, "9.9e-5"),
    (0x3ee4f8b588e368f1UL, "1e-5"),
    (0x441ac53a7e04bcdaUL, "1.2345678901234568e20"),
    (0x7e37e43c8800759cUL, "1e300"),
    (0x0000000000000001UL, "5e-324"),
    (0x0000000000000000UL, "0.0"),
    (0x8000000000000000UL, "-0.0"),
    (0x7ff0000000000000UL, "inf"),
    (0xfff0000000000000UL, "-inf"),
    (0x7ff8000000000000UL, "NaN"),
    (0x7fefffffffffffffUL, "1.7976931348623157e308"),
    (0x40c81cd6c8b43958UL, "12345.678"),
    (0x3fd3333333333334UL, "0.30000000000000004"),
    (0x4340000000000000UL, "9007199254740992.0"),
    (0x000fffffffffffffUL, "2.225073858507201e-308"),
    (0x4480f0cf064dd592UL, "1e22"),
    (0x45f8ee90ff6c373eUL, "1.2345678901234568e29"),
    (0x4370000000000000UL, "7.205759403792794e16"),
    (0xbff8000000000000UL, "-1.5"),
  ]
  for case in cases {
    let (bits, expected) = case
    assert_eq(rust_debug_f64(bits.reinterpret_as_double()), expected)
  }
}
