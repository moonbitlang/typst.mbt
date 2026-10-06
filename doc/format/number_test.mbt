///|
/// The double with these bits.
fn bits(b : UInt64) -> Double {
  b.reinterpret_as_double()
}

///|
let nan : Double = bits(0x7FF8000000000000UL)

///|
let inf : Double = bits(0x7FF0000000000000UL)

///|
let neg_inf : Double = bits(0xFFF0000000000000UL)

///|
/// Deterministic pseudo-random numbers (xorshift64*): the properties below
/// are checked on the same inputs on every target.
priv struct Rng {
  mut state : UInt64
}

///|
fn Rng::next(self : Rng) -> UInt64 {
  let mut x = self.state
  x = x ^ (x >> 12)
  x = x ^ (x << 25)
  x = x ^ (x >> 27)
  self.state = x
  x * 0x2545F4914F6CDD1DUL
}

///|
/// A number in `0..n`.
fn Rng::below(self : Rng, n : Int) -> Int {
  (self.next() >> 33).to_int() % n
}

///|
/// A double in `[0, 1)`.
fn Rng::unit(self : Rng) -> Double {
  (self.next() >> 11).to_double() / 9007199254740992.0
}

///|
/// A finite double: any bit pattern, or a value of a report's magnitude.
fn Rng::double(self : Rng) -> Double {
  let sign = if self.below(3) == 0 { -1.0 } else { 1.0 }
  match self.below(4) {
    0 => {
      let x = bits(self.next())
      if x.is_nan() || x.is_inf() {
        0.0
      } else {
        x
      }
    }
    1 => sign * self.unit()
    2 => sign * self.unit() * 1.0e6
    _ => sign * self.below(1000000).to_double() / 1000.0
  }
}

///|
/// The rows of a table that `f` does not reproduce, as text.
fn mismatches(
  table : ArrayView[(UInt64, Int, String)],
  f : (Double, Int) -> String,
) -> Array[String] {
  let out = []
  for row in table {
    let (b, digits, expected) = row
    let got = f(bits(b), digits)
    if got != expected {
      out.push("\{bits(b)} at \{digits}: \{got}, expected \{expected}")
    }
  }
  out
}

///|
test "fixed: the well-known cases" {
  // 1.005 is the double 1.00499999999999989..., not a tie.
  assert_eq(@format.fixed(1.005, 2), "1.00")
  assert_eq(@format.fixed(1.015, 2), "1.01")
  assert_eq(@format.fixed(1.025, 2), "1.02")
  assert_eq(@format.fixed(2.675, 2), "2.67")
  assert_eq(@format.fixed(8.345, 2), "8.35")
  // Real ties (the values are doubles) go away from zero.
  assert_eq(@format.fixed(0.5, 0), "1")
  assert_eq(@format.fixed(1.5, 0), "2")
  assert_eq(@format.fixed(2.5, 0), "3")
  assert_eq(@format.fixed(-0.5, 0), "-1")
  assert_eq(@format.fixed(-1.5, 0), "-2")
  assert_eq(@format.fixed(-2.5, 0), "-3")
  assert_eq(@format.fixed(0.125, 2), "0.13")
  assert_eq(@format.fixed(-0.125, 2), "-0.13")
  assert_eq(@format.fixed(0.375, 2), "0.38")
  // Just below and just above a tie.
  assert_eq(@format.fixed(0.49999999999999994, 0), "0")
  assert_eq(@format.fixed(0.5000000000000001, 0), "1")
  assert_eq(@format.fixed(2.4999999999999996, 0), "2")
  // The carry runs through the whole number.
  assert_eq(@format.fixed(9.995, 2), "9.99")
  assert_eq(@format.fixed(9.9951, 2), "10.00")
  assert_eq(@format.fixed(999.5, 0), "1000")
  assert_eq(@format.fixed(0.99, 1), "1.0")
  assert_eq(@format.fixed(0.05, 0), "0")
  assert_eq(@format.fixed(0.06, 1), "0.1")
  assert_eq(@format.fixed(0.04, 1), "0.0")
  // Plain values.
  assert_eq(@format.fixed(0.0, 0), "0")
  assert_eq(@format.fixed(0.0, 3), "0.000")
  assert_eq(@format.fixed(1.0, 2), "1.00")
  assert_eq(@format.fixed(123.456, 0), "123")
  assert_eq(@format.fixed(123.456, 1), "123.5")
  assert_eq(@format.fixed(123.456, 2), "123.46")
  assert_eq(@format.fixed(-123.456, 2), "-123.46")
  assert_eq(@format.fixed(0.1 + 0.2, 2), "0.30")
  assert_eq(@format.fixed(0.1 + 0.2, 17), "0.30000000000000004")
}

///|
test "fixed: sign" {
  // "-" exactly when x < 0: also when the result is zero, and not for
  // negative zero (JavaScript's rule).
  assert_eq(@format.fixed(-0.0, 0), "0")
  assert_eq(@format.fixed(-0.0, 2), "0.00")
  assert_eq(@format.fixed(-0.001, 2), "-0.00")
  assert_eq(@format.fixed(-0.4, 0), "-0")
  assert_eq(@format.fixed(-5.0e-324, 3), "-0.000")
  assert_eq(@format.fixed(-0.006, 2), "-0.01")
}

///|
test "fixed: more digits than a double has" {
  // More than 17 significant digits: the digits of the exact value.
  assert_eq(@format.fixed(0.1, 20), "0.10000000000000000555")
  assert_eq(
    @format.fixed(0.1, 55),
    "0.1000000000000000055511151231257827021181583404541015625",
  )
  assert_eq(
    @format.fixed(0.1, 60),
    "0.100000000000000005551115123125782702118158340454101562500000",
  )
  assert_eq(@format.fixed(1.005, 20), "1.00499999999999989342")
  assert_eq(@format.fixed(123.456, 20), "123.45600000000000306954")
  assert_eq(@format.fixed(1.0e-20, 20), "0.00000000000000000001")
  assert_eq(@format.fixed(1.0e-21, 20), "0.00000000000000000000")
  // The double 5e-21 is below 5e-21, the double 6e-21 is not a tie.
  assert_eq(@format.fixed(5.0e-21, 20), "0.00000000000000000000")
  assert_eq(@format.fixed(6.0e-21, 20), "0.00000000000000000001")
  assert_eq(@format.fixed(9007199254740993.0, 1), "9007199254740992.0")
  assert_eq(@format.fixed(1.0e20, 0), "100000000000000000000")
}

///|
test "fixed: no exponent notation" {
  // JavaScript gives "1e+21" from here on.
  assert_eq(@format.fixed(1.0e21, 0), "1000000000000000000000")
  assert_eq(@format.fixed(1.0e21, 2), "1000000000000000000000.00")
  assert_eq(@format.fixed(-1.0e21, 1), "-1000000000000000000000.0")
  // 1e23 is not a double: the nearest one is written.
  assert_eq(@format.fixed(1.0e23, 0), "99999999999999991611392")
  let max = @format.fixed(bits(0x7FEFFFFFFFFFFFFFUL), 0)
  assert_eq(max.length(), 309)
  assert_true(max.has_prefix("17976931348623157081452742373170435679807056"))
  assert_true(max.has_suffix("4124858368"))
}

///|
test "fixed: digits are clamped to 0..=100" {
  assert_eq(@format.fixed(1.25, -1), "1")
  assert_eq(@format.fixed(1.25, -2147483648), "1")
  assert_eq(@format.fixed(2.5, -5), "3")
  assert_eq(@format.fixed(0.5, 100), "0.5" + "0".repeat(99))
  assert_eq(@format.fixed(0.5, 101), @format.fixed(0.5, 100))
  assert_eq(@format.fixed(0.5, 2147483647), @format.fixed(0.5, 100))
  assert_eq(@format.fixed(5.0e-324, 2147483647), "0." + "0".repeat(100))
  for digits in 0..<=20 {
    let text = @format.fixed(1.0 / 3.0, digits)
    assert_eq(text.length(), if digits == 0 { 1 } else { digits + 2 })
    assert_true("0.33333333333333331483".has_prefix(text[:text.length() - 1]))
  }
}

///|
test "fixed: not finite" {
  assert_eq(@format.fixed(nan, 2), "NaN")
  assert_eq(@format.fixed(-nan, 2), "NaN")
  assert_eq(@format.fixed(inf, 2), "∞")
  assert_eq(@format.fixed(neg_inf, 2), "-∞")
  assert_eq(@format.fixed(inf, 2, trim=true), "∞")
  assert_eq(@format.fixed(nan, -1, trim=true), "NaN")
}

///|
test "fixed: trim" {
  assert_eq(@format.fixed(2.5, 2, trim=true), "2.5")
  assert_eq(@format.fixed(3.0, 2, trim=true), "3")
  assert_eq(@format.fixed(0.0, 2, trim=true), "0")
  assert_eq(@format.fixed(0.25, 2, trim=true), "0.25")
  assert_eq(@format.fixed(0.05, 3, trim=true), "0.05")
  assert_eq(@format.fixed(0.004, 2, trim=true), "0")
  assert_eq(@format.fixed(-0.004, 2, trim=true), "-0")
  assert_eq(@format.fixed(100.0, 2, trim=true), "100")
  assert_eq(@format.fixed(100.0, 0, trim=true), "100")
  assert_eq(@format.fixed(1200.0, 0, trim=true), "1200")
  assert_eq(@format.fixed(10.10, 2, trim=true), "10.1")
  assert_eq(@format.fixed(-7.50, 1, trim=true), "-7.5")
  assert_eq(@format.fixed(0.1 + 0.2, 10, trim=true), "0.3")
  assert_eq(@format.fixed(1.0e21, 3, trim=true), "1000000000000000000000")
}

///|
test "fixed: JavaScript's toFixed below 1e21" {
  let wrong = mismatches(fixed_js_cases[:], (x, digits) => {
    @format.fixed(x, digits)
  })
  assert_eq(wrong, [])
  assert_true(fixed_js_cases.length() > 2000)
}

///|
test "fixed: all digits from 1e21 on" {
  let wrong = []
  for row in fixed_large_cases[:] {
    let (b, digits, expected, js) = row
    let got = @format.fixed(bits(b), digits)
    if got != expected {
      wrong.push("\{bits(b)} at \{digits}: \{got}, expected \{expected}")
    }
    // What the table says about JavaScript: it has an exponent there.
    assert_true(js.contains("e+"))
  }
  assert_eq(wrong, [])
  assert_true(fixed_large_cases.length() > 200)
}

///|
test "fixed: within half a unit of the value" {
  // The text, read back, is at most half a unit of its last place from x.
  // Checked with doubles, for values whose spacing (at most 1.2e-10 below
  // 1e6) is far below the unit, so that the check itself is not in doubt.
  let rng = { state: 0x9E3779B97F4A7C15UL, }
  for _ in 0..<4000 {
    let x = (if rng.below(2) == 0 { -1.0 } else { 1.0 }) *
      rng.unit() *
      [1.0, 10.0, 1000.0, 1.0e6][rng.below(4)]
    let digits = rng.below(7)
    let text = @format.fixed(x, digits)
    let back = @string.parse_double(text)
    let mut unit = 1.0
    for _ in 0..<digits {
      unit = unit / 10.0
    }
    assert_true(
      (back - x).abs() <= 0.5 * unit * (1.0 + 1.0e-6),
      msg="\{x} at \{digits}: \{text}",
    )
    // The shape: an optional sign, digits, and `digits` decimals.
    let unsigned = if text.has_prefix("-") {
      assert_true(x < 0.0)
      text.length() - 1
    } else {
      assert_true(x >= 0.0)
      text.length()
    }
    match text.find(".") {
      None => assert_eq(digits, 0)
      Some(at) => {
        assert_eq(text.length() - at - 1, digits)
        assert_true(digits > 0 && unsigned > digits + 1)
      }
    }
  }
}

///|
test "fixed: symmetric, and monotonic in the value" {
  let rng = { state: 0xD1B54A32D192ED03UL, }
  for _ in 0..<3000 {
    let x = rng.double().abs()
    let digits = rng.below(8)
    let text = @format.fixed(x, digits)
    if x > 0.0 {
      assert_eq(@format.fixed(-x, digits), "-" + text)
    }
    // The next double up never has a smaller text (same length here means
    // the texts compare like the numbers).
    let up = @format.fixed(bits(x.reinterpret_as_uint64() + 1UL), digits)
    if up.length() == text.length() {
      assert_true(up >= text, msg="\{x} at \{digits}: \{text} then \{up}")
    } else {
      assert_true(up.length() > text.length())
    }
    // Trimming removes zeros only.
    let trimmed = @format.fixed(x, digits, trim=true)
    assert_true(text.has_prefix(trimmed))
    assert_true(!trimmed.has_suffix("."))
    assert_true(!(trimmed.contains(".") && trimmed.has_suffix("0")))
    for ch in text[trimmed.length():] {
      assert_true(ch == '0' || ch == '.')
    }
  }
}

///|
test "grouped" {
  assert_eq(@format.grouped(0.0), "0")
  assert_eq(@format.grouped(999.0), "999")
  assert_eq(@format.grouped(1000.0), "1,000")
  assert_eq(@format.grouped(999.5), "1,000")
  assert_eq(@format.grouped(999.4), "999")
  assert_eq(@format.grouped(1234567.0), "1,234,567")
  assert_eq(@format.grouped(-1234.5), "-1,235")
  assert_eq(@format.grouped(-999.0), "-999")
  assert_eq(@format.grouped(-100000.0), "-100,000")
  assert_eq(@format.grouped(1234567.891, digits=2), "1,234,567.89")
  // The decimals are not grouped.
  assert_eq(@format.grouped(1234.56789, digits=5), "1,234.56789")
  assert_eq(@format.grouped(0.123456, digits=6), "0.123456")
  assert_eq(@format.grouped(-0.4), "-0")
  assert_eq(@format.grouped(-0.0), "0")
  // Other separators.
  assert_eq(
    @format.grouped(1234567.0, sep="\u{2009}"),
    "1\u{2009}234\u{2009}567",
  )
  assert_eq(@format.grouped(1234567.0, sep="'"), "1'234'567")
  assert_eq(@format.grouped(1234567.5, digits=1, sep=""), "1234567.5")
  assert_eq(@format.grouped(1234567.0, sep=", "), "1, 234, 567")
  // Clamped digits, large values, values that are not finite.
  assert_eq(@format.grouped(1234.5, digits=-3), "1,235")
  assert_eq(@format.grouped(1.0e21), "1,000,000,000,000,000,000,000")
  assert_eq(@format.grouped(nan), "NaN")
  assert_eq(@format.grouped(inf, digits=2), "∞")
  assert_eq(@format.grouped(neg_inf, sep="."), "-∞")
}

///|
test "grouped: toFixed with separators" {
  let wrong = mismatches(grouped_cases[:], (x, digits) => {
    @format.grouped(x, digits~)
  })
  assert_eq(wrong, [])
  // Most of the rows have a separator: the table is about grouping.
  let mut separated = 0
  for row in grouped_cases[:] {
    if row.2.contains(",") {
      separated += 1
    }
  }
  assert_true(separated > 300 && grouped_cases.length() > 400)
}

///|
test "grouped: without the separators it is fixed" {
  let rng = { state: 0x94D049BB133111EBUL, }
  for _ in 0..<3000 {
    let x = rng.double()
    let digits = rng.below(6)
    let plain = @format.fixed(x, digits)
    let text = @format.grouped(x, digits~)
    assert_eq(text.replace_all(old=",", new=""), plain)
    assert_eq(@format.grouped(x, digits~, sep=""), plain)
    assert_eq(
      @format.grouped(x, digits~, sep="\u{202F}").replace_all(
        old="\u{202F}",
        new=",",
      ),
      text,
    )
    // Groups: one to three digits, then threes, up to the point.
    let whole = match text.find(".") {
      None => text
      Some(at) => {
        assert_true(!text[at:].contains(","))
        text[:at].to_owned()
      }
    }
    let whole = match whole.strip_prefix("-") {
      Some(rest) => rest.to_owned()
      None => whole
    }
    for i, group in whole.split(",").collect() {
      if i == 0 {
        assert_true(group.length() >= 1 && group.length() <= 3)
      } else {
        assert_eq(group.length(), 3)
      }
    }
  }
}

///|
test "grouped_int" {
  assert_eq(@format.grouped_int(0), "0")
  assert_eq(@format.grouped_int(7), "7")
  assert_eq(@format.grouped_int(999), "999")
  assert_eq(@format.grouped_int(1000), "1,000")
  assert_eq(@format.grouped_int(-999), "-999")
  assert_eq(@format.grouped_int(-1000), "-1,000")
  assert_eq(@format.grouped_int(1234567), "1,234,567")
  assert_eq(@format.grouped_int(123456), "123,456")
  assert_eq(@format.grouped_int(12345), "12,345")
  assert_eq(@format.grouped_int(1234567, sep=""), "1234567")
  assert_eq(
    @format.grouped_int(-1234567, sep="\u{2009}"),
    "-1\u{2009}234\u{2009}567",
  )
  assert_eq(
    @format.grouped_int(9223372036854775807),
    "9,223,372,036,854,775,807",
  )
  assert_eq(
    @format.grouped_int(-9223372036854775807 - 1),
    "-9,223,372,036,854,775,808",
  )
  let n : Int = 48213
  assert_eq(@format.grouped_int(n.to_int64()), "48,213")
  // JavaScript's `toLocaleString("en-US")`.
  let wrong = []
  for row in grouped_int_cases[:] {
    let (b, expected) = row
    let n = b.reinterpret_as_int64()
    let got = @format.grouped_int(n)
    if got != expected {
      wrong.push("\{n}: \{got}, expected \{expected}")
    }
    assert_eq(got.replace_all(old=",", new=""), n.to_string())
    // An integer-valued double is grouped the same way.
    if n > -9007199254740992L && n < 9007199254740992L {
      assert_eq(@format.grouped(n.to_double()), got)
    }
  }
  assert_eq(wrong, [])
  assert_true(grouped_int_cases.length() > 100)
}

///|
test "percent" {
  assert_eq(@format.percent(0.956), "95.6%")
  assert_eq(@format.percent(0.5), "50.0%")
  assert_eq(@format.percent(0.5, digits=0), "50%")
  assert_eq(@format.percent(1.0), "100.0%")
  assert_eq(@format.percent(1.5), "150.0%")
  assert_eq(@format.percent(0.0), "0.0%")
  assert_eq(@format.percent(-0.0412), "-4.1%")
  assert_eq(@format.percent(0.12345, digits=2), "12.35%")
  assert_eq(@format.percent(0.12345, digits=3), "12.345%")
  assert_eq(@format.percent(12.0, digits=0), "1200%")
  // The exact value of x times 100: 0.045 is below 0.045, although the
  // double `100.0 * 0.045` is 4.5 and would round up.
  assert_eq(100.0 * 0.045, 4.5)
  assert_eq(@format.fixed(100.0 * 0.045, 0), "5")
  assert_eq(@format.percent(0.045, digits=0), "4%")
  // Real ties.
  assert_eq(@format.percent(0.125, digits=0), "13%")
  assert_eq(@format.percent(-0.125, digits=0), "-13%")
  assert_eq(@format.percent(0.0078125, digits=4), "0.7813%")
  // Sign, clamping, values that are not finite.
  assert_eq(@format.percent(-0.0001), "-0.0%")
  assert_eq(@format.percent(-0.0), "0.0%")
  assert_eq(@format.percent(0.5, digits=-1), "50%")
  assert_eq(@format.percent(0.5, digits=1000), "50." + "0".repeat(100) + "%")
  assert_eq(@format.percent(nan), "NaN")
  assert_eq(@format.percent(inf), "∞%")
  assert_eq(@format.percent(neg_inf, digits=3), "-∞%")
  // No overflow where `100.0 * x` would be infinite.
  let max = @format.percent(bits(0x7FEFFFFFFFFFFFFFUL), digits=0)
  assert_eq(max.length(), 312)
  assert_true(max.has_prefix("179769313486231570814527423731704356798070"))
  assert_true(max.has_suffix("412485836800%"))
}

///|
test "percent: the exact value times 100" {
  let wrong = mismatches(percent_cases[:], (x, digits) => {
    @format.percent(x, digits~)
  })
  assert_eq(wrong, [])
  assert_true(percent_cases.length() > 800)
}

///|
test "compact" {
  assert_eq(@format.compact(1234.0), "1.2k")
  assert_eq(@format.compact(5.4e6), "5.4M")
  assert_eq(@format.compact(2.0e9), "2.0B")
  assert_eq(@format.compact(2.0e9, digits=0), "2B")
  assert_eq(@format.compact(-1500.0), "-1.5k")
  assert_eq(@format.compact(12345678.0, digits=2), "12.35M")
  // Below a thousand: no suffix, the decimals are kept.
  assert_eq(@format.compact(0.0), "0.0")
  assert_eq(@format.compact(950.0), "950.0")
  assert_eq(@format.compact(950.0, digits=0), "950")
  assert_eq(@format.compact(0.25), "0.3")
  assert_eq(@format.compact(12.0, digits=0), "12")
  assert_eq(@format.compact(999.0, digits=0), "999")
  assert_eq(@format.compact(999.4, digits=0), "999")
  // The unit is chosen after rounding.
  assert_eq(@format.compact(999.5, digits=0), "1k")
  assert_eq(@format.compact(999.94), "999.9")
  assert_eq(@format.compact(999.95), "1.0k")
  assert_eq(@format.compact(1000.0), "1.0k")
  assert_eq(@format.compact(999949.0), "999.9k")
  assert_eq(@format.compact(999950.0), "1.0M")
  assert_eq(@format.compact(999499.0, digits=0), "999k")
  assert_eq(@format.compact(999500.0, digits=0), "1M")
  assert_eq(@format.compact(999949999.0), "999.9M")
  assert_eq(@format.compact(999950000.0), "1.0B")
  assert_eq(@format.compact(-999950.0), "-1.0M")
  // A billion is the largest unit.
  assert_eq(@format.compact(1.0e12), "1000.0B")
  assert_eq(@format.compact(2.5e13), "25000.0B")
  assert_eq(@format.compact(1.0e21, digits=0), "1000000000000B")
  // Sign, clamping, values that are not finite.
  assert_eq(@format.compact(-0.04), "-0.0")
  assert_eq(@format.compact(-0.0), "0.0")
  assert_eq(@format.compact(1500.0, digits=-4), "2k")
  assert_eq(@format.compact(1500.0, digits=200), "1.5" + "0".repeat(99) + "k")
  assert_eq(@format.compact(nan), "NaN")
  assert_eq(@format.compact(inf), "∞")
  assert_eq(@format.compact(neg_inf, digits=0), "-∞")
}

///|
test "compact: the exact value in the unit chosen after rounding" {
  let wrong = mismatches(compact_cases[:], (x, digits) => {
    @format.compact(x, digits~)
  })
  assert_eq(wrong, [])
  assert_true(compact_cases.length() > 900)
}

///|
test "compact: below a thousand in its unit" {
  let rng = { state: 0xBF58476D1CE4E5B9UL, }
  for _ in 0..<3000 {
    let x = rng.double()
    let digits = rng.below(4)
    let text = @format.compact(x, digits~)
    let (number, unit) = if text.has_suffix("k") {
      (text[:text.length() - 1].to_owned(), 1.0e3)
    } else if text.has_suffix("M") {
      (text[:text.length() - 1].to_owned(), 1.0e6)
    } else if text.has_suffix("B") {
      (text[:text.length() - 1].to_owned(), 1.0e9)
    } else {
      (text, 1.0)
    }
    let value = @string.parse_double(number).abs()
    if x.abs() < 1.0e11 {
      assert_true(value < 1000.0, msg="\{x}: \{text}")
      assert_true(unit == 1.0 || value >= 1.0, msg="\{x}: \{text}")
      // Within half a unit of the last place (and the rounding of doubles).
      let mut half = 0.5
      for _ in 0..<digits {
        half = half / 10.0
      }
      assert_true(
        (value - x.abs() / unit).abs() <= half * (1.0 + 1.0e-6) + 1.0e-9,
        msg="\{x}: \{text}",
      )
    }
    assert_eq(text.has_prefix("-"), x < 0.0)
  }
}
