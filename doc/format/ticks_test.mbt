///|
/// The ticks as text, with up to six decimals.
fn tick_text(lo : Double, hi : Double, count : Int) -> String {
  let parts = []
  for t in @format.ticks(lo, hi, count) {
    parts.push(@format.fixed(t, 6, trim=true))
  }
  parts.join(" ")
}

///|
test "ticks" {
  assert_eq(tick_text(0.0, 100.0, 4), "0 25 50 75 100")
  assert_eq(tick_text(0.0, 100.0, 5), "0 20 40 60 80 100")
  assert_eq(tick_text(0.0, 100.0, 10), "0 10 20 30 40 50 60 70 80 90 100")
  assert_eq(tick_text(0.0, 1.0, 5), "0 0.2 0.4 0.6 0.8 1")
  assert_eq(tick_text(0.0, 1.0, 4), "0 0.25 0.5 0.75 1")
  assert_eq(tick_text(0.0, 1.0, 2), "0 0.5 1")
  assert_eq(tick_text(0.0, 1.0, 1), "0 1")
  assert_eq(tick_text(3.0, 97.0, 5), "20 40 60 80")
  assert_eq(tick_text(-1.0, 1.0, 4), "-1 -0.5 0 0.5 1")
  assert_eq(tick_text(-50.0, 50.0, 4), "-50 -25 0 25 50")
  assert_eq(tick_text(-97.0, -3.0, 5), "-80 -60 -40 -20")
  assert_eq(tick_text(0.0, 7.0, 5), "0 2 4 6")
  assert_eq(tick_text(0.0, 12.0, 5), "0 2.5 5 7.5 10")
  assert_eq(tick_text(0.0, 23.0, 5), "0 5 10 15 20")
  assert_eq(tick_text(0.0, 45.0, 5), "0 10 20 30 40")
  assert_eq(tick_text(1200.0, 4700.0, 4), "2000 3000 4000")
  assert_eq(tick_text(0.0, 5.4e6, 5), "0 2000000 4000000")
  assert_eq(tick_text(0.0, 0.003, 3), "0 0.001 0.002 0.003")
  assert_eq(tick_text(0.0012, 0.0047, 4), "0.002 0.003 0.004")
  // Bounds that are multiples of the step are ticks.
  assert_eq(tick_text(10.0, 20.0, 4), "10 12.5 15 17.5 20")
  assert_eq(tick_text(0.1, 0.5, 4), "0.1 0.2 0.3 0.4 0.5")
}

///|
test "ticks: the doubles nearest to the multiples" {
  // Not sums of the step: 0.1 + 0.2 is 0.30000000000000004.
  assert_eq(@format.ticks(0.0, 0.5, 5), [0.0, 0.1, 0.2, 0.3, 0.4, 0.5])
  assert_eq(@format.ticks(0.0, 0.3, 3), [0.0, 0.1, 0.2, 0.3])
  assert_eq(@format.ticks(0.5, 0.9, 4), [0.5, 0.6, 0.7, 0.8, 0.9])
  assert_eq(@format.ticks(-0.3, 0.3, 6), [-0.3, -0.2, -0.1, 0.0, 0.1, 0.2, 0.3])
  assert_eq(@format.ticks(0.0, 0.075, 3), [0.0, 0.025, 0.05, 0.075])
  assert_eq(@format.ticks(1.0e-7, 4.0e-7, 3), [1.0e-7, 2.0e-7, 3.0e-7, 4.0e-7])
  assert_eq(@format.ticks(1.0e15, 4.0e15, 3), [1.0e15, 2.0e15, 3.0e15, 4.0e15])
  // The difference of the doubles 0.9 and 0.3 is above 0.6, and a third of
  // it above 0.2: the step is 0.2 all the same.
  assert_true((0.9 - 0.3) / 3.0 > 0.2)
  assert_eq(@format.ticks(0.3, 0.9, 3), [0.4, 0.6, 0.8])
  assert_eq(@format.ticks(0.1, 0.7, 3), [0.2, 0.4, 0.6])
  // No tolerance at the bounds: this sum is below 0.8.
  let below = 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1 + 0.1
  assert_true(below < 0.8)
  assert_eq(@format.ticks(0.0, below, 4), [0.0, 0.2, 0.4, 0.6])
  assert_eq(@format.ticks(0.0, 0.8, 4), [0.0, 0.2, 0.4, 0.6, 0.8])
  // Zero is never negative zero.
  for t in @format.ticks(-1.0, 1.0, 4) {
    assert_true(t != 0.0 || t.reinterpret_as_uint64() == 0UL)
  }
  assert_eq(@format.ticks(-0.5, 0.0, 1)[1].reinterpret_as_uint64(), 0UL)
  assert_eq(@format.ticks(-0.0, 1.0, 1)[0].reinterpret_as_uint64(), 0UL)
}

///|
test "ticks: degenerate arguments" {
  let nan = 0x7FF8000000000000UL.reinterpret_as_double()
  let inf = 0x7FF0000000000000UL.reinterpret_as_double()
  // Equal bounds: the one tick.
  assert_eq(@format.ticks(5.0, 5.0, 4), [5.0])
  assert_eq(@format.ticks(0.3, 0.3, 4), [0.3])
  assert_eq(@format.ticks(0.0, 0.0, 0), [0.0])
  assert_eq(@format.ticks(-0.0, 0.0, 4)[0].reinterpret_as_uint64(), 0UL)
  assert_eq(@format.ticks(0.0, -0.0, 4).length(), 1)
  // Reversed bounds: the same ticks, ascending.
  assert_eq(@format.ticks(100.0, 0.0, 4), [0.0, 25.0, 50.0, 75.0, 100.0])
  assert_eq(@format.ticks(1.0, -1.0, 4), @format.ticks(-1.0, 1.0, 4))
  // Not finite: nothing.
  assert_eq(@format.ticks(nan, 1.0, 4), [])
  assert_eq(@format.ticks(0.0, nan, 4), [])
  assert_eq(@format.ticks(nan, nan, 4), [])
  assert_eq(@format.ticks(0.0, inf, 4), [])
  assert_eq(@format.ticks(-inf, 0.0, 4), [])
  assert_eq(@format.ticks(-inf, inf, 4), [])
  assert_eq(@format.ticks(inf, inf, 4), [])
  // The difference of the bounds is not finite, or the step would not be.
  assert_eq(@format.ticks(-1.0e308, 1.0e308, 4), [])
  assert_eq(@format.ticks(0.0, 1.5e308, 1), [])
  // Above 1e22 a tick is near its multiple, not the nearest double: the
  // bound 1.5e308 may be missed.
  let huge = @format.ticks(0.0, 1.5e308, 3)
  assert_true(huge.length() == 3 || huge.length() == 4)
  assert_eq(huge[0], 0.0)
  assert_true((huge[1] / 5.0e307 - 1.0).abs() < 1.0e-12)
  assert_true((huge[2] / 1.0e308 - 1.0).abs() < 1.0e-12)
  // The count is clamped to 1..=1000.
  assert_eq(@format.ticks(0.0, 1.0, 0), [0.0, 1.0])
  assert_eq(@format.ticks(0.0, 1.0, -7), [0.0, 1.0])
  assert_eq(@format.ticks(0.0, 1.0, -2147483648), [0.0, 1.0])
  assert_eq(@format.ticks(0.0, 1.0, 1000).length(), 1001)
  assert_eq(@format.ticks(0.0, 1.0, 2147483647), @format.ticks(0.0, 1.0, 1000))
  // One interval: the step can be larger than the range.
  assert_eq(@format.ticks(1.1, 1.9, 1), [])
  assert_eq(@format.ticks(0.9, 1.9, 1), [1.0])
  assert_eq(@format.ticks(1.0, 2.0, 1), [1.0, 2.0])
  // Ranges below what a step can be (never below about 1e-300).
  assert_eq(@format.ticks(0.0, 5.0e-324, 4), [0.0])
  assert_eq(@format.ticks(1.0e-310, 2.0e-310, 4), [])
  assert_eq(@format.ticks(-1.0e-310, 2.0e-310, 4), [0.0])
  let tiny = @format.ticks(0.0, 2.5e-300, 5)
  assert_eq(tiny.length(), 3)
  assert_eq(tiny[0], 0.0)
  assert_true((tiny[1] / 1.0e-300 - 1.0).abs() < 1.0e-12)
  assert_true((tiny[2] / 2.0e-300 - 1.0).abs() < 1.0e-12)
  // Bounds whose doubles are farther apart than the step: no tick twice.
  let wide = @format.ticks(1.0e18, 1.0e18 + 1024.0, 1000)
  assert_true(wide.length() >= 1 && wide.length() <= 1001)
  for i in 1..<wide.length() {
    assert_true(wide[i] > wide[i - 1])
  }
}

///|
test "ticks: within the bounds, ascending, a round step" {
  let mut state = 0x853C49E6748FEA9BUL
  fn next() -> UInt64 {
    state = state * 6364136223846793005UL + 1442695040888963407UL
    state >> 11
  }

  for round in 0..<3000 {
    let scale = [1.0, 1.0e-3, 100.0, 1.0e6, 1.0e-9, 1.0e12][round % 6]
    let a = (next().to_double() / 9007199254740992.0 * 2.0 - 1.0) * scale
    let width = next().to_double() / 9007199254740992.0 * scale
    // Half of the ranges start at a round number.
    let lo = if round % 2 == 0 {
      a
    } else {
      (a / scale * 10.0).floor() * scale / 10.0
    }
    let hi = lo + width
    let count = 1 + (next() % 12UL).to_int()
    let ticks = @format.ticks(lo, hi, count)
    let label = "ticks(\{lo}, \{hi}, \{count})"
    assert_true(ticks.length() <= count + 1, msg=label)
    if hi > lo && count >= 2 {
      assert_true(ticks.length() >= 1, msg=label)
    }
    for i, t in ticks {
      assert_true(t >= lo && t <= hi, msg=label)
      if i > 0 {
        assert_true(t > ticks[i - 1], msg=label)
      }
    }
    assert_eq(@format.ticks(hi, lo, count), ticks)
    if ticks.length() >= 2 {
      let step = ticks[1] - ticks[0]
      // Evenly spaced (the differences of rounded doubles, hence nearly).
      for i in 2..<ticks.length() {
        let d = ticks[i] - ticks[i - 1]
        assert_true((d - step).abs() <= 1.0e-6 * step, msg=label)
      }
      // 1, 2, 2.5 or 5 times a power of ten.
      let mut mantissa = step
      while mantissa >= 10.0 {
        mantissa = mantissa / 10.0
      }
      while mantissa < 1.0 {
        mantissa = mantissa * 10.0
      }
      let mut round_step = false
      for m in [1.0, 2.0, 2.5, 5.0, 10.0] {
        if (mantissa - m).abs() < 1.0e-6 {
          round_step = true
        }
      }
      assert_true(round_step, msg="\{label}: step \{step}")
      // At least a `count`th of the range, and less than twice the
      // smallest round step would have to be.
      let least = (hi - lo) / count.to_double()
      assert_true(step >= least * (1.0 - 1.0e-6), msg=label)
      assert_true(step <= 2.0 * least * (1.0 + 1.0e-6), msg=label)
      // Every multiple in the range is there: none below the first or above
      // the last one (a bound may be within rounding of a multiple that it
      // excludes: the differences are those of rounded doubles).
      let slack = 1.0e-6 * step
      assert_true(ticks[0] - step < lo + slack, msg=label)
      assert_true(ticks[ticks.length() - 1] + step > hi - slack, msg=label)
    }
  }
}
