// Port of `typst-library/src/foundations/duration.rs`.

///|
/// Represents a positive or negative span of time.
pub struct Duration(@time.Duration) derive(Eq, Hash, Compare)

///|
/// Whether the duration is empty / zero.
pub fn Duration::is_zero(self : Duration) -> Bool {
  self.0.is_zero()
}

///|
/// Decomposes the time into whole weeks, days, hours, minutes, and seconds.
pub fn Duration::decompose(self : Duration) -> FixedArray[Int64] {
  let mut tmp = self.0
  let weeks = tmp.whole_weeks()
  tmp = tmp - @time.Duration::weeks(weeks)
  let days = tmp.whole_days()
  tmp = tmp - @time.Duration::days(days)
  let hours = tmp.whole_hours()
  tmp = tmp - @time.Duration::hours(hours)
  let minutes = tmp.whole_minutes()
  tmp = tmp - @time.Duration::minutes(minutes)
  let seconds = tmp.whole_seconds()
  [weeks, days, hours, minutes, seconds]
}

///|
/// Creates a new duration (upstream `Duration::construct`).
///
/// You can specify the duration using weeks, days, hours, minutes and
/// seconds. You can also get a duration by subtracting two datetimes.
fn impl_duration_construct(
  seconds_ : Int64,
  minutes_ : Int64,
  hours_ : Int64,
  days_ : Int64,
  weeks_ : Int64,
) -> Duration {
  Duration(
    @time.Duration::seconds(seconds_) +
    @time.Duration::minutes(minutes_) +
    @time.Duration::hours(hours_) +
    @time.Duration::days(days_) +
    @time.Duration::weeks(weeks_),
  )
}

///|
/// The duration expressed in seconds.
///
/// This function returns the total duration represented in seconds as a
/// floating-point number rather than the second component of the duration.
pub fn Duration::seconds(self : Duration) -> Double {
  self.0.as_seconds_f64()
}

///|
/// The duration expressed in minutes.
pub fn Duration::minutes(self : Duration) -> Double {
  self.seconds() / 60.0
}

///|
/// The duration expressed in hours.
pub fn Duration::hours(self : Duration) -> Double {
  self.seconds() / 3600.0
}

///|
/// The duration expressed in days.
pub fn Duration::days(self : Duration) -> Double {
  self.seconds() / 86400.0
}

///|
/// The duration expressed in weeks.
pub fn Duration::weeks(self : Duration) -> Double {
  self.seconds() / 604800.0
}

///|
fn impl_duration_seconds(self_ : Duration) -> Double {
  self_.seconds()
}

///|
fn impl_duration_minutes(self_ : Duration) -> Double {
  self_.minutes()
}

///|
fn impl_duration_hours(self_ : Duration) -> Double {
  self_.hours()
}

///|
fn impl_duration_days(self_ : Duration) -> Double {
  self_.days()
}

///|
fn impl_duration_weeks(self_ : Duration) -> Double {
  self_.weeks()
}

///|
/// Upstream `Repr for Duration`.
pub fn Duration::repr(self : Duration) -> String {
  let parts = self.decompose()
  let names : ReadOnlyArray[_] = [
    "weeks", "days", "hours", "minutes", "seconds",
  ]
  let vec = []
  for i, v in parts {
    if v != 0L {
      vec.push("\{names[i]}: \{repr_int(v)}")
    }
  }
  "duration" + pretty_array_like(vec, false)
}

///|
/// Upstream `Add for Duration`.
pub fn Duration::add(self : Duration, other : Duration) -> Duration {
  Duration(self.0 + other.0)
}

///|
/// Upstream `Sub for Duration`.
pub fn Duration::sub(self : Duration, other : Duration) -> Duration {
  Duration(self.0 - other.0)
}

///|
/// Upstream `Neg for Duration`.
pub fn Duration::neg(self : Duration) -> Duration {
  Duration(-self.0)
}

///|
/// Upstream `Mul<f64> for Duration`.
pub fn Duration::mul(self : Duration, rhs : Double) -> Duration {
  Duration(self.0.mul_f64(rhs))
}

///|
/// Upstream `Div<f64> for Duration`.
pub fn Duration::div(self : Duration, rhs : Double) -> Duration {
  Duration(self.0.div_f64(rhs))
}

///|
/// Upstream `Div for Duration`.
pub fn Duration::div_duration(self : Duration, rhs : Duration) -> Double {
  self.0.div_duration(rhs.0)
}

///|
pub impl Reflect for Duration with fn input() {
  Type(Type::duration())
}

///|
pub impl Reflect for Duration with fn output() {
  Type(Type::duration())
}

///|
pub impl Reflect for Duration with fn castable(v) {
  v is Duration(_)
}

///|
pub extend Duration with Reflect::{output, input, castable}

///|
pub impl IntoValue for Duration with fn into_value(self) {
  Duration(self)
}

///|
pub impl FromValue for Duration with fn from_value(v) {
  match v {
    Duration(d) => d
    v => raise HintedError(Duration::input().error(v))
  }
}
