///|
/// The fast path of `shortest_digits` agrees with the exact algorithm.
test "shortest_digits fast path agrees with dragon" {
  let values : Array[Double] = [
    1.0, 0.1, 0.2, 0.3, 1.5, 2.5, 123.456, 1.0e21, 1.5e21, 1.0e-7, 2.5e-5, 5.0e-324,
    1.7976931348623157e308, 100.0, 0.000123, 1.0e16, 12345678901234567.0, 595.2756,
    841.8898, 0.5, 1.0e15, 9007199254740993.0, 1.0e-300, 3.0e-310,
  ]
  // Typical SVG/PDF coordinates: multiples of 1e-9 and simple fractions.
  for i in 1..<20000 {
    values.push(i.to_double() / 1000.0)
    values.push(i.to_double() * 0.123456789)
    values.push(i.to_double() / 7.0)
  }
  // Pseudo-random bit patterns (finite, non-zero).
  let mut state = 0x9E3779B97F4A7C15UL
  for _ in 0..<20000 {
    state = state * 6364136223846793005UL + 1442695040888963407UL
    let x = (state >> 1).reinterpret_as_double()
    if !x.is_nan() && !x.is_inf() && x != 0.0 {
      values.push(x)
    }
  }
  for x in values {
    match shortest_digits_fast(x) {
      Some(fast) =>
        if fast != shortest_digits_dragon(x) {
          fail("mismatch for \{x}: \{fast.0} \{fast.1}")
        }
      None => ()
    }
  }
}
