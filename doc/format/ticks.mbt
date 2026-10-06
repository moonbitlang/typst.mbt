///|
/// The powers of ten that are exact doubles.
let exact_pow10 : ReadOnlyArray[Double] = [
  1.0e0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9, 1.0e10, 1.0e11,
  1.0e12, 1.0e13, 1.0e14, 1.0e15, 1.0e16, 1.0e17, 1.0e18, 1.0e19, 1.0e20, 1.0e21,
  1.0e22,
]

///|
/// `10^e` for `e >= 0`: exact up to `10^22`, a product of exact powers (and
/// so only near the power, or infinite) above.
fn pow10(e : Int) -> Double {
  let mut e = e
  let mut r = 1.0
  while e > 22 {
    r = r * 1.0e22
    e -= 22
  }
  r * exact_pow10[e]
}

///|
/// `n × 10^e`. For an `n` that is exact (an integer, or a multiple of one
/// half, below `2^52`) and `|e| <= 22` this is one multiplication or one
/// division of exact doubles, hence the double nearest to the decimal
/// number: `scale10(3.0, -1)` is the double `0.3`, which `0.1 + 0.1 + 0.1`
/// and `3.0 * 0.1` are not.
fn scale10(n : Double, e : Int) -> Double {
  if e >= 0 {
    n * pow10(e)
  } else if e >= -308 {
    n / pow10(-e)
  } else {
    n / pow10(308) / pow10(-e - 308)
  }
}

///|
/// The mantissas of the steps, and 10 for the next power of ten. `k × 2.5`
/// is exact for every integer `k` below `2^51`.
let step_mantissas : ReadOnlyArray[Double] = [1.0, 2.0, 2.5, 5.0, 10.0]

///|
/// The next double above `x`, for `x != 0`.
fn next_up(x : Double) -> Double {
  let bits = x.reinterpret_as_uint64()
  (if x > 0.0 { bits + 1UL } else { bits - 1UL }).reinterpret_as_double()
}

///|
/// `x`, but zero for negative zero (which `to_string` would print as "-0").
fn positive_zero(x : Double) -> Double {
  if x == 0.0 {
    0.0
  } else {
    x
  }
}

///|
/// The largest count of intervals `ticks` aims for.
const MAX_TICK_COUNT : Int = 1000

///|
/// Round values for the axis of a chart: the multiples of a step that lie
/// between `lo` and `hi` (both included), in ascending order. The step is
/// the smallest of 1, 2, 2.5, 5 times a power of ten that is at least
/// `(hi - lo) / count`, so there are at most `count + 1` ticks (and at
/// least one when `count >= 2`, within the exact range described below):
///
/// - `ticks(0.0, 100.0, 4)` is `[0, 25, 50, 75, 100]`,
/// - `ticks(0.0, 1.0, 5)` is `[0, 0.2, 0.4, 0.6, 0.8, 1]`,
/// - `ticks(3.0, 97.0, 5)` is `[20, 40, 60, 80]`,
/// - `ticks(-1.0, 1.0, 4)` is `[-1, -0.5, 0, 0.5, 1]`.
///
/// Contract:
/// - Every tick `t` satisfies `lo <= t <= hi` as doubles; there is no
///   tolerance at the bounds (a bound that is itself a multiple of the step
///   is a tick). The ticks are strictly ascending. Zero is `0.0`, never
///   negative zero.
/// - Each tick is `k × step` computed from the integer `k`, not by adding
///   the step repeatedly. In the exact range, which is steps between
///   `1e-22` and `1e22` and bounds less than `1e15` steps from zero, it is
///   the double nearest to the decimal number: the double `0.3`, which
///   `to_string` prints as "0.3", and not the sum `0.30000000000000004`.
///   (It is still a double: `fixed(0.3, 20)` shows the digits of its exact
///   value.)
/// - Outside of the exact range a tick is only within a few units in the
///   last place of a multiple, so a bound that is meant as a multiple can
///   be missed; and where the doubles are farther apart than the step (a
///   range more than `9e15` steps from zero) only some of the multiples are
///   ticks, at most one for each double.
/// - "At least `(hi - lo) / count`" is taken with a relative tolerance of
///   `1e-9`, so that bounds such as 0.3 and 0.9, whose difference as
///   doubles is slightly more than 0.6, still get the step 0.2 for three
///   intervals.
/// - `count` is clamped to 1..=1000. With `count = 1` the step can be
///   larger than the range, and the result is empty if no multiple of it
///   falls inside (`ticks(1.1, 1.9, 1)`).
/// - Reversed bounds are swapped: `ticks(hi, lo, count)` is `ticks(lo, hi,
///   count)`, still ascending.
/// - `lo == hi` gives the one tick `[lo]`.
/// - A bound that is NaN or infinite gives `[]`, and so do bounds whose
///   difference is not a finite double (`-1e308` and `1e308`) or whose
///   step would not be one. The step is never below about `1e-300`, so a
///   narrower range has at most one tick.
pub fn ticks(lo : Double, hi : Double, count : Int) -> Array[Double] {
  if lo.is_nan() || lo.is_inf() || hi.is_nan() || hi.is_inf() {
    return []
  }
  let (lo, hi) = if lo <= hi { (lo, hi) } else { (hi, lo) }
  if lo == hi {
    return [positive_zero(lo)]
  }
  let count = if count < 1 {
    1
  } else if count > MAX_TICK_COUNT {
    MAX_TICK_COUNT
  } else {
    count
  }
  let span = hi - lo
  if span.is_inf() {
    return []
  }
  let target = span / count.to_double() * (1.0 - 1.0e-9)
  // The power of ten at or below the target: 10^e <= target < 10^(e + 1),
  // unless the target is outside of 1e-300..1e308.
  let mut e = 0
  while e < 308 && scale10(1.0, e + 1) <= target {
    e += 1
  }
  while e > -300 && scale10(1.0, e) > target {
    e -= 1
  }
  let mut mantissa = 1.0
  for candidate in step_mantissas[:] {
    mantissa = candidate
    if scale10(mantissa, e) >= target {
      break
    }
  }
  let step = scale10(mantissa, e)
  if step.is_inf() || step.is_nan() || step <= 0.0 {
    return []
  }
  // The first multiple at or above `lo`. The quotient is rounded, so it can
  // be off by one in either direction.
  let mut k = (lo / step).ceil()
  if scale10((k - 1.0) * mantissa, e) >= lo {
    k = k - 1.0
  } else if scale10(k * mantissa, e) < lo {
    k = k + 1.0
  }
  let out : Array[Double] = []
  let mut last = lo
  // One more round than there can be ticks; the loop ends earlier at `hi`.
  for _ in 0..<(count + 2) {
    let tick = scale10(k * mantissa, e)
    // Also ends the loop if the tick is not a number.
    if !(tick <= hi) || out.length() > count {
      break
    }
    // Outside of the exact range multiples can coincide as doubles: only
    // ascending ones are ticks.
    if tick >= lo && (out.length() == 0 || tick > last) {
      out.push(positive_zero(tick))
      last = tick
    }
    // From 2^53 on not every integer is a double: the next one that is.
    let next = k + 1.0
    k = if next > k { next } else { next_up(k) }
  }
  out
}
