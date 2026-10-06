// Port of `time/src/signed_duration.rs` (`time::Duration`, an alias of
// `time::SignedDuration`).

///|
/// A span of time with nanosecond precision.
///
/// Each `Duration` is composed of a whole number of seconds and a fractional
/// part represented in nanoseconds. The sign of the nanoseconds always
/// matches that of the seconds (or is zero).
pub struct Duration {
  priv seconds : Int64
  // Sign must match that of `seconds` (though this is not a safety requirement).
  priv nanoseconds : Int
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with @debug.Debug::{to_repr}

///|
let i64_min : Int64 = -9223372036854775808L

///|
let i64_max : Int64 = 9223372036854775807L

///|
fn checked_add_i64(a : Int64, b : Int64) -> Int64? {
  let r = a + b
  if (a >= 0L && b >= 0L && r < 0L) || (a < 0L && b < 0L && r >= 0L) {
    None
  } else {
    Some(r)
  }
}

///|
fn checked_sub_i64(a : Int64, b : Int64) -> Int64? {
  let r = a - b
  if (a >= 0L && b < 0L && r < 0L) || (a < 0L && b >= 0L && r >= 0L) {
    None
  } else {
    Some(r)
  }
}

///|
fn checked_mul_i64(a : Int64, b : Int64) -> Int64? {
  if a == 0L || b == 0L {
    return Some(0L)
  }
  if (a == -1L && b == i64_min) || (b == -1L && a == i64_min) {
    return None
  }
  let r = a * b
  if r / a != b {
    None
  } else {
    Some(r)
  }
}

///|
fn Duration::new_unchecked(seconds : Int64, nanoseconds : Int) -> Duration {
  { seconds, nanoseconds, }
}

///|
let duration_zero : Duration = Duration::new_unchecked(0L, 0)

///|
let duration_min : Duration = Duration::new_unchecked(i64_min, -999_999_999)

///|
let duration_max : Duration = Duration::new_unchecked(i64_max, 999_999_999)

///|
/// `Duration::ZERO`: equivalent to `0.seconds()`.
pub fn Duration::zero() -> Duration {
  duration_zero
}

///|
/// `Duration::MIN`: the minimum possible duration. Adding any negative
/// duration to this will cause an overflow.
pub fn Duration::minimum() -> Duration {
  duration_min
}

///|
/// `Duration::MAX`: the maximum possible duration. Adding any positive
/// duration to this will cause an overflow.
pub fn Duration::maximum() -> Duration {
  duration_max
}

///|
/// Check if a duration is exactly zero.
pub fn Duration::is_zero(self : Duration) -> Bool {
  self.seconds == 0L && self.nanoseconds == 0
}

///|
/// Check if a duration is negative.
pub fn Duration::is_negative(self : Duration) -> Bool {
  self.seconds < 0L || self.nanoseconds < 0
}

///|
/// Check if a duration is positive.
pub fn Duration::is_positive(self : Duration) -> Bool {
  self.seconds > 0L || self.nanoseconds > 0
}

///|
/// Get the absolute value of the duration. This method saturates the returned
/// value if it would otherwise overflow.
pub fn Duration::abs(self : Duration) -> Duration {
  if self.seconds == i64_min {
    duration_max
  } else {
    Duration::new_unchecked(self.seconds.abs(), self.nanoseconds.abs())
  }
}

///|
/// Create a new `Duration` with the provided seconds and nanoseconds. If
/// nanoseconds is at least ±10^9, it will wrap to the number of seconds.
///
/// Panics (aborts) if the duration overflows.
pub fn Duration::new(seconds : Int64, nanoseconds : Int) -> Duration {
  let mut seconds = match
    checked_add_i64(seconds, nanoseconds.to_int64() / 1_000_000_000L) {
    Some(s) => s
    None => abort("overflow constructing `time::SignedDuration`")
  }
  let mut nanoseconds = nanoseconds % 1_000_000_000
  if seconds > 0L && nanoseconds < 0 {
    // `seconds` cannot overflow here because it is positive.
    seconds -= 1L
    nanoseconds += 1_000_000_000
  } else if seconds < 0L && nanoseconds > 0 {
    // `seconds` cannot overflow here because it is negative.
    seconds += 1L
    nanoseconds -= 1_000_000_000
  }
  Duration::new_unchecked(seconds, nanoseconds)
}

///|
fn expect_overflow_constructing(value : Int64?) -> Int64 {
  match value {
    Some(v) => v
    None => abort("overflow constructing `time::SignedDuration`")
  }
}

///|
/// Create a new `Duration` with the given number of weeks.
pub fn Duration::weeks(weeks : Int64) -> Duration {
  Duration::seconds(
    expect_overflow_constructing(checked_mul_i64(weeks, 604_800L)),
  )
}

///|
/// Create a new `Duration` with the given number of days.
pub fn Duration::days(days : Int64) -> Duration {
  Duration::seconds(
    expect_overflow_constructing(checked_mul_i64(days, 86_400L)),
  )
}

///|
/// Create a new `Duration` with the given number of hours.
pub fn Duration::hours(hours : Int64) -> Duration {
  Duration::seconds(
    expect_overflow_constructing(checked_mul_i64(hours, 3_600L)),
  )
}

///|
/// Create a new `Duration` with the given number of minutes.
pub fn Duration::minutes(minutes : Int64) -> Duration {
  Duration::seconds(expect_overflow_constructing(checked_mul_i64(minutes, 60L)))
}

///|
/// Create a new `Duration` with the given number of seconds.
pub fn Duration::seconds(seconds : Int64) -> Duration {
  Duration::new_unchecked(seconds, 0)
}

///|
/// Create a new `Duration` with the given number of milliseconds.
pub fn Duration::milliseconds(milliseconds : Int64) -> Duration {
  Duration::new_unchecked(
    milliseconds / 1_000L,
    (milliseconds % 1_000L * 1_000_000L).to_int(),
  )
}

///|
/// Create a new `Duration` with the given number of microseconds.
pub fn Duration::microseconds(microseconds : Int64) -> Duration {
  Duration::new_unchecked(
    microseconds / 1_000_000L,
    (microseconds % 1_000_000L * 1_000L).to_int(),
  )
}

///|
/// Create a new `Duration` with the given number of nanoseconds.
pub fn Duration::nanoseconds(nanoseconds : Int64) -> Duration {
  Duration::new_unchecked(
    nanoseconds / 1_000_000_000L,
    (nanoseconds % 1_000_000_000L).to_int(),
  )
}

///|
priv enum FloatConstructorError {
  Nan
  NegOverflow
  PosOverflow
}

///|
/// Round `x >> k` to nearest, ties to even, as done by `try_from_secs!`.
/// Returns the rounded nanoseconds.
fn round_shifted(x : @bigint.BigInt, k : Int) -> UInt {
  let nanos = (x >> k).to_uint()
  let rem_mask = (@bigint.BigInt::from_int(1) << k) -
    @bigint.BigInt::from_int(1)
  let rem_msb_mask = @bigint.BigInt::from_int(1) << (k - 1)
  let rem = x & rem_mask
  let is_tie = rem == rem_msb_mask
  let is_even = (nanos & 1U) == 0U
  let rem_msb = (x & rem_msb_mask).is_zero()
  let add_ns = !(rem_msb || (is_even && is_tie))
  nanos + (if add_ns { 1U } else { 0U })
}

///|
/// Port of the `try_from_secs!` macro for `f64`.
fn Duration::try_seconds_f64(
  secs : Double,
) -> Result[Duration, FloatConstructorError] {
  let mant_bits = 52
  let min_exp = -1023
  let mant_mask : UInt64 = (1UL << mant_bits) - 1UL
  let exp_mask : UInt64 = (1UL << 11) - 1UL
  let bits = secs.reinterpret_as_uint64()
  let mant = (bits & mant_mask) | (mant_mask + 1UL)
  let exp = ((bits >> mant_bits) & exp_mask).to_int() + min_exp
  let (secs_u, nanos) : (UInt64, UInt) = if exp < -31 {
    // the input represents less than 1ns and can not be rounded to it
    (0UL, 0U)
  } else if exp < 0 {
    // the input is less than 1 second
    // t = mant << (44 + exp); nanos_tmp = 1e9 * t; nanos_offset = 96
    let t = @bigint.BigInt::from_uint64(mant) << (44 + exp)
    let nanos_tmp = @bigint.BigInt::from_int(1_000_000_000) * t
    let nanos = round_shifted(nanos_tmp, 96)
    if nanos != 1_000_000_000U {
      (0UL, nanos)
    } else {
      (1UL, 0U)
    }
  } else if exp < mant_bits {
    let secs_u = mant >> (mant_bits - exp)
    let t = (mant << exp) & mant_mask
    let nanos_tmp = @bigint.BigInt::from_int(1_000_000_000) *
      @bigint.BigInt::from_uint64(t)
    let nanos = round_shifted(nanos_tmp, mant_bits)
    if nanos != 1_000_000_000U {
      (secs_u, nanos)
    } else {
      (secs_u + 1UL, 0U)
    }
  } else if exp < 63 {
    // Change from std: The exponent here is 63 instead of 64,
    // because i64::MAX + 1 is 2^63.

    // the input has no fractional part
    (mant << (exp - mant_bits), 0U)
  } else if bits == i64_min.to_double().reinterpret_as_uint64() {
    return Ok(Duration::new_unchecked(i64_min, 0))
  } else if secs.is_nan() {
    return Err(Nan)
  } else if bits >> 63 == 1UL {
    return Err(NegOverflow)
  } else {
    return Err(PosOverflow)
  }
  let mask = bits.reinterpret_as_int64() >> 63
  let secs_signed = (secs_u.reinterpret_as_int64() ^ mask) - mask
  let mask32 = mask.to_int()
  let nanos_signed = (nanos.reinterpret_as_int() ^ mask32) - mask32
  Ok(Duration::new_unchecked(secs_signed, nanos_signed))
}

///|
/// Creates a new `Duration` from the specified number of seconds represented
/// as `f64`.
///
/// Panics (aborts) if the value is NaN or the duration overflows.
pub fn Duration::seconds_f64(seconds : Double) -> Duration {
  match Duration::try_seconds_f64(seconds) {
    Ok(duration) => duration
    Err(Nan) => abort("passed NaN to `time::SignedDuration::seconds_f64`")
    Err(NegOverflow | PosOverflow) =>
      abort("overflow constructing `time::SignedDuration`")
  }
}

///|
/// Creates a new `Duration` from the specified number of seconds represented
/// as `f64`. Any values that are out of bounds are saturated at the minimum
/// or maximum respectively. `NaN` gets turned into a `Duration` of 0 seconds.
pub fn Duration::saturating_seconds_f64(seconds : Double) -> Duration {
  match Duration::try_seconds_f64(seconds) {
    Ok(duration) => duration
    Err(Nan) => duration_zero
    Err(NegOverflow) => duration_min
    Err(PosOverflow) => duration_max
  }
}

///|
/// Creates a new `Duration` from the specified number of seconds represented
/// as `f64`. Returns `None` if the `Duration` can't be represented.
pub fn Duration::checked_seconds_f64(seconds : Double) -> Duration? {
  match Duration::try_seconds_f64(seconds) {
    Ok(duration) => Some(duration)
    Err(_) => None
  }
}

///|
/// Get the number of whole weeks in the duration.
pub fn Duration::whole_weeks(self : Duration) -> Int64 {
  self.whole_seconds() / 604_800L
}

///|
/// Get the number of whole days in the duration.
pub fn Duration::whole_days(self : Duration) -> Int64 {
  self.whole_seconds() / 86_400L
}

///|
/// Get the number of whole hours in the duration.
pub fn Duration::whole_hours(self : Duration) -> Int64 {
  self.whole_seconds() / 3_600L
}

///|
/// Get the number of whole minutes in the duration.
pub fn Duration::whole_minutes(self : Duration) -> Int64 {
  self.whole_seconds() / 60L
}

///|
/// Get the number of whole seconds in the duration.
pub fn Duration::whole_seconds(self : Duration) -> Int64 {
  self.seconds
}

///|
/// Get the number of fractional seconds in the duration.
pub fn Duration::as_seconds_f64(self : Duration) -> Double {
  self.seconds.to_double() + self.nanoseconds.to_double() / 1_000_000_000.0
}

///|
/// Get the number of milliseconds past the number of whole seconds.
pub fn Duration::subsec_milliseconds(self : Duration) -> Int {
  self.nanoseconds / 1_000_000
}

///|
/// Get the number of microseconds past the number of whole seconds.
pub fn Duration::subsec_microseconds(self : Duration) -> Int {
  self.nanoseconds / 1_000
}

///|
/// Get the number of nanoseconds past the number of whole seconds.
pub fn Duration::subsec_nanoseconds(self : Duration) -> Int {
  self.nanoseconds
}

///|
/// Computes `self + rhs`, returning `None` if an overflow occurred.
pub fn Duration::checked_add(self : Duration, rhs : Duration) -> Duration? {
  guard checked_add_i64(self.seconds, rhs.seconds) is Some(seconds) else {
    return None
  }
  Duration::normalize_checked(seconds, self.nanoseconds + rhs.nanoseconds)
}

///|
/// Computes `self - rhs`, returning `None` if an overflow occurred.
pub fn Duration::checked_sub(self : Duration, rhs : Duration) -> Duration? {
  guard checked_sub_i64(self.seconds, rhs.seconds) is Some(seconds) else {
    return None
  }
  Duration::normalize_checked(seconds, self.nanoseconds - rhs.nanoseconds)
}

///|
/// Shared overflow handling of `checked_add` and `checked_sub`.
fn Duration::normalize_checked(seconds : Int64, nanoseconds : Int) -> Duration? {
  let mut seconds = seconds
  let mut nanoseconds = nanoseconds
  if nanoseconds >= 1_000_000_000 || (seconds < 0L && nanoseconds > 0) {
    nanoseconds -= 1_000_000_000
    guard checked_add_i64(seconds, 1L) is Some(s) else { return None }
    seconds = s
  } else if nanoseconds <= -1_000_000_000 || (seconds > 0L && nanoseconds < 0) {
    nanoseconds += 1_000_000_000
    guard checked_sub_i64(seconds, 1L) is Some(s) else { return None }
    seconds = s
  }
  Some(Duration::new_unchecked(seconds, nanoseconds))
}

///|
/// Computes `-self`, returning `None` if an overflow occurred.
pub fn Duration::checked_neg(self : Duration) -> Duration? {
  if self.seconds == i64_min {
    None
  } else {
    Some(Duration::new_unchecked(-self.seconds, -self.nanoseconds))
  }
}

///|
pub impl Add for Duration with fn add(self, rhs) {
  match self.checked_add(rhs) {
    Some(d) => d
    None => abort("overflow when adding durations")
  }
}

///|
#deprecated("call as `Add::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Add::{add}

///|
pub impl Sub for Duration with fn sub(self, rhs) {
  match self.checked_sub(rhs) {
    Some(d) => d
    None => abort("overflow when subtracting durations")
  }
}

///|
#deprecated("call as `Sub::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Sub::{sub}

///|
pub impl Neg for Duration with fn neg(self) {
  match self.checked_neg() {
    Some(d) => d
    None => abort("overflow when negating duration")
  }
}

///|
#deprecated("call as `Neg::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Neg::{neg}

///|
/// `Mul<f64> for Duration`.
pub fn Duration::mul_f64(self : Duration, rhs : Double) -> Duration {
  Duration::seconds_f64(self.as_seconds_f64() * rhs)
}

///|
/// `Div<f64> for Duration`.
pub fn Duration::div_f64(self : Duration, rhs : Double) -> Duration {
  Duration::seconds_f64(self.as_seconds_f64() / rhs)
}

///|
/// `Div for Duration`.
pub fn Duration::div_duration(self : Duration, rhs : Duration) -> Double {
  self.as_seconds_f64() / rhs.as_seconds_f64()
}

///|
/// The `Display` implementation (without precision).
pub impl Show for Duration with fn output(self, logger) {
  if self.is_negative() {
    logger.write_string("-")
  }
  if self.is_zero() {
    logger.write_string("0s")
    return
  }
  let seconds = self.seconds.abs().reinterpret_as_uint64()
  let nanoseconds = self.nanoseconds.abs()
  fn item(name : String, value : UInt64) {
    if value != 0UL {
      logger.write_string(value.to_string())
      logger.write_string(name)
    }
  }

  item("d", seconds / 86_400UL)
  item("h", seconds / 3_600UL % 24UL)
  item("m", seconds / 60UL % 60UL)
  item("s", seconds % 60UL)
  item("ms", (nanoseconds / 1_000_000).to_uint64())
  item("µs", (nanoseconds / 1_000 % 1_000).to_uint64())
  item("ns", (nanoseconds % 1_000).to_uint64())
}

///|
pub extend Duration with Show::{to_string, output}
