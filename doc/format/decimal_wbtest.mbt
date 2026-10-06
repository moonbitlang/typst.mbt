///|
fn digits_text(digits : Array[Int]) -> String {
  let buf = StringBuilder()
  for d in digits {
    buf.write_string(d.to_string())
  }
  buf.to_string()
}

///|
test "Decimal::of: the exact expansion" {
  for row in decimal_cases[:] {
    let (bits, digits, point) = row
    let x = bits.reinterpret_as_double()
    let decimal = Decimal::of(x)
    assert_eq(digits_text(decimal.digits), digits)
    assert_eq(decimal.point, point)
    // The sign is not part of it.
    let negative = Decimal::of(-x)
    assert_eq(negative.digits, decimal.digits)
    assert_eq(negative.point, decimal.point)
  }
  let zero = Decimal::of(0.0)
  assert_eq(zero.digits, [])
  assert_eq(Decimal::of(-0.0).digits, [])
  // The smallest double: 5^1074 has 751 digits, after 323 zeros.
  let least = Decimal::of(5.0e-324)
  assert_eq(least.digits.length(), 751)
  assert_eq(least.point, -323)
  // The largest: an integer of 309 digits.
  let most = Decimal::of(0x7FEFFFFFFFFFFFFFUL.reinterpret_as_double())
  assert_eq(most.digits.length(), 309)
  assert_eq(most.point, 309)
}

///|
test "Decimal::rounded" {
  // 0.125 × 10^scale.
  let eighth = Decimal::of(0.125)
  assert_eq(eighth.rounded(-1), [])
  assert_eq(eighth.rounded(0), [])
  assert_eq(eighth.rounded(1), [1])
  assert_eq(eighth.rounded(2), [1, 3])
  assert_eq(eighth.rounded(3), [1, 2, 5])
  assert_eq(eighth.rounded(5), [1, 2, 5, 0, 0])
  // The first digit after the point decides at scale 0.
  assert_eq(Decimal::of(0.5).rounded(0), [1])
  assert_eq(Decimal::of(0.49999999999999994).rounded(0), [])
  assert_eq(Decimal::of(0.05).rounded(0), [])
  assert_eq(Decimal::of(0.05).rounded(-1), [])
  // Carries.
  assert_eq(Decimal::of(999.5).rounded(0), [1, 0, 0, 0])
  assert_eq(Decimal::of(999.4).rounded(0), [9, 9, 9])
  assert_eq(Decimal::of(0.96).rounded(1), [1, 0])
  assert_eq(Decimal::of(1999.5).rounded(0), [2, 0, 0, 0])
  // Negative scales: thousands and millions.
  assert_eq(Decimal::of(1500.0).rounded(-3), [2])
  assert_eq(Decimal::of(1499.0).rounded(-3), [1])
  assert_eq(Decimal::of(499.0).rounded(-3), [])
  assert_eq(Decimal::of(500.0).rounded(-3), [1])
  assert_eq(Decimal::of(999_950.0).rounded(-2), [1, 0, 0, 0, 0])
  assert_eq(Decimal::of(0.0).rounded(5), [])
  assert_eq(Decimal::of(0.0).rounded(-5), [])
}
