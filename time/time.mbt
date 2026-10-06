// Port of the subset of the `time` crate (0.3.55) used by Typst.
//
// This file ports `time/src/time.rs`.

///|
/// The clock time within a given date. Nanosecond precision.
///
/// All minutes are assumed to have exactly 60 seconds; no attempt is made to
/// handle leap seconds (either positive or negative).
pub struct Time {
  // The order of these fields matters for the derived `Compare`.
  priv hour : Int
  priv minute : Int
  priv second : Int
  priv nanosecond : Int
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Time with Eq::{not_equal, equal}

///|
pub extend Time with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Time with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Time with @debug.Debug::{to_repr}

///|
fn Time::from_hms_nanos_unchecked(
  hour : Int,
  minute : Int,
  second : Int,
  nanosecond : Int,
) -> Time {
  { hour, minute, second, nanosecond, }
}

///|
let time_midnight : Time = Time::from_hms_nanos_unchecked(0, 0, 0, 0)

///|
let time_max : Time = Time::from_hms_nanos_unchecked(23, 59, 59, 999_999_999)

///|
/// `Time::MIDNIGHT`: a `Time` that is exactly midnight. This is the smallest
/// possible value for a `Time`.
pub fn Time::midnight() -> Time {
  time_midnight
}

///|
/// `Time::MAX`: the largest possible value for a `Time`.
pub fn Time::maximum() -> Time {
  time_max
}

///|
fn ensure_ranged(
  value : Int,
  max : Int,
  name : String,
) -> Int raise ComponentRange {
  if value < 0 || value > max {
    raise ComponentRange::unconditional(name)
  }
  value
}

///|
/// Attempt to create a `Time` from the hour, minute, and second.
pub fn Time::from_hms(
  hour : Int,
  minute : Int,
  second : Int,
) -> Time raise ComponentRange {
  Time::from_hms_nanos_unchecked(
    ensure_ranged(hour, 23, "hour"),
    ensure_ranged(minute, 59, "minute"),
    ensure_ranged(second, 59, "second"),
    0,
  )
}

///|
/// Attempt to create a `Time` from the hour, minute, second, and nanosecond.
pub fn Time::from_hms_nano(
  hour : Int,
  minute : Int,
  second : Int,
  nanosecond : Int,
) -> Time raise ComponentRange {
  Time::from_hms_nanos_unchecked(
    ensure_ranged(hour, 23, "hour"),
    ensure_ranged(minute, 59, "minute"),
    ensure_ranged(second, 59, "second"),
    ensure_ranged(nanosecond, 999_999_999, "nanosecond"),
  )
}

///|
/// Get the clock hour, minute, and second.
pub fn Time::as_hms(self : Time) -> (Int, Int, Int) {
  (self.hour, self.minute, self.second)
}

///|
/// Get the clock hour. The returned value will always be in the range `0..24`.
pub fn Time::hour(self : Time) -> Int {
  self.hour
}

///|
/// Get the minute within the hour. The returned value will always be in the
/// range `0..60`.
pub fn Time::minute(self : Time) -> Int {
  self.minute
}

///|
/// Get the second within the minute. The returned value will always be in the
/// range `0..60`.
pub fn Time::second(self : Time) -> Int {
  self.second
}

///|
/// Get the milliseconds within the second.
pub fn Time::millisecond(self : Time) -> Int {
  self.nanosecond / 1_000_000
}

///|
/// Get the microseconds within the second.
pub fn Time::microsecond(self : Time) -> Int {
  self.nanosecond / 1_000
}

///|
/// Get the nanoseconds within the second. The returned value will always be
/// in the range `0..1_000_000_000`.
pub fn Time::nanosecond(self : Time) -> Int {
  self.nanosecond
}

///|
/// Port of the `cascade!` macro: returns the adjusted `from` and the carry to
/// add to `to`.
fn cascade(from : Int, min : Int, max : Int) -> (Int, Int) {
  if from >= max {
    (from - (max - min), 1)
  } else if from < min {
    (from + (max - min), -1)
  } else {
    (from, 0)
  }
}

///|
/// Add the sub-day time of the `Duration` to the `Time`. Wraps on overflow,
/// returning whether the date needs to be adjusted.
fn Time::adjusting_add(
  self : Time,
  duration : Duration,
) -> (DateAdjustment, Time) {
  let nanoseconds = self.nanosecond + duration.subsec_nanoseconds()
  let seconds = self.second + (duration.whole_seconds() % 60L).to_int()
  let minutes = self.minute + (duration.whole_minutes() % 60L).to_int()
  let hours = self.hour + (duration.whole_hours() % 24L).to_int()
  Time::adjust(nanoseconds, seconds, minutes, hours)
}

///|
/// Subtract the sub-day time of the `Duration` from the `Time`. Wraps on
/// overflow, returning whether the date needs to be adjusted.
fn Time::adjusting_sub(
  self : Time,
  duration : Duration,
) -> (DateAdjustment, Time) {
  let nanoseconds = self.nanosecond - duration.subsec_nanoseconds()
  let seconds = self.second - (duration.whole_seconds() % 60L).to_int()
  let minutes = self.minute - (duration.whole_minutes() % 60L).to_int()
  let hours = self.hour - (duration.whole_hours() % 24L).to_int()
  Time::adjust(nanoseconds, seconds, minutes, hours)
}

///|
/// The shared cascading tail of `adjusting_add` and `adjusting_sub`.
fn Time::adjust(
  nanoseconds : Int,
  seconds : Int,
  minutes : Int,
  hours : Int,
) -> (DateAdjustment, Time) {
  let (nanoseconds, carry) = cascade(nanoseconds, 0, 1_000_000_000)
  let (seconds, carry) = cascade(seconds + carry, 0, 60)
  let (minutes, carry) = cascade(minutes + carry, 0, 60)
  let mut hours = hours + carry
  let mut date_adjustment = DateAdjustment::None_
  if hours >= 24 {
    hours -= 24
    date_adjustment = DateAdjustment::Next
  } else if hours < 0 {
    hours += 24
    date_adjustment = DateAdjustment::Previous
  }
  (
    date_adjustment,
    Time::from_hms_nanos_unchecked(hours, minutes, seconds, nanoseconds),
  )
}

///|
/// Return the duration until `other` (wrapping into the next day if
/// necessary).
pub fn Time::duration_until(self : Time, other : Time) -> Duration {
  let nanoseconds = other.nanosecond - self.nanosecond
  let seconds = other.second - self.second
  let minutes = other.minute - self.minute
  let hours = other.hour - self.hour
  let total_seconds = hours * 3600 + minutes * 60 + seconds
  let (nanoseconds, carry) = cascade(nanoseconds, 0, 1_000_000_000)
  let mut total_seconds = total_seconds + carry
  if total_seconds < 0 {
    total_seconds += 86_400
  }
  Duration::new_unchecked(total_seconds.to_int64(), nanoseconds)
}

///|
/// Return the duration since `other` (wrapping into the previous day if
/// necessary).
pub fn Time::duration_since(self : Time, other : Time) -> Duration {
  other.duration_until(self)
}

///|
/// `Add<Duration> for Time`: add the sub-day time of the `Duration` to the
/// `Time`. Wraps on overflow.
pub fn Time::add_duration(self : Time, duration : Duration) -> Time {
  self.adjusting_add(duration).1
}

///|
/// `Sub<Duration> for Time`: subtract the sub-day time of the `Duration` from
/// the `Time`. Wraps on overflow.
pub fn Time::sub_duration(self : Time, duration : Duration) -> Time {
  self.adjusting_sub(duration).1
}

///|
/// `Sub for Time`: subtract two `Time`s, returning the `Duration` between.
/// This assumes both `Time`s are in the same calendar day.
pub fn Time::sub_time(self : Time, rhs : Time) -> Duration {
  let hour_diff = self.hour - rhs.hour
  let minute_diff = self.minute - rhs.minute
  let second_diff = self.second - rhs.second
  let nanosecond_diff = self.nanosecond - rhs.nanosecond
  let seconds = hour_diff * 3600 + minute_diff * 60 + second_diff
  let (seconds, nanoseconds) = if seconds > 0 && nanosecond_diff < 0 {
    (seconds - 1, nanosecond_diff + 1_000_000_000)
  } else if seconds < 0 && nanosecond_diff > 0 {
    (seconds + 1, nanosecond_diff - 1_000_000_000)
  } else {
    (seconds, nanosecond_diff)
  }
  Duration::new_unchecked(seconds.to_int64(), nanoseconds)
}

///|
/// `Display for Time`.
pub impl Show for Time with fn output(self, logger) {
  logger.write_string(self.hour.to_string())
  logger.write_string(":")
  logger.write_string(zero_pad(self.minute, 2))
  logger.write_string(":")
  logger.write_string(zero_pad(self.second, 2))
  logger.write_string(".")
  logger.write_string(truncated_subsecond_from_nanos(self.nanosecond))
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Time with Show::{to_string, output}
