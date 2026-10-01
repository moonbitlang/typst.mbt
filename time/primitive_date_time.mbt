// Port of `time/src/plain_date_time.rs` (`time::PrimitiveDateTime`, an alias
// of `time::PlainDateTime`).

///|
/// Combined date and time.
pub struct PrimitiveDateTime {
  // The order of these fields matters for the derived `Compare`.
  priv date : Date
  priv time : Time
} derive(Eq, Compare, Hash, Debug)

///|
/// Create a new `PrimitiveDateTime` from the provided `Date` and `Time`.
pub fn PrimitiveDateTime::new(date : Date, time : Time) -> PrimitiveDateTime {
  { date, time, }
}

///|
/// `PrimitiveDateTime::MIN`: the smallest value that can be represented.
pub fn PrimitiveDateTime::minimum() -> PrimitiveDateTime {
  { date: date_min, time: time_midnight, }
}

///|
/// `PrimitiveDateTime::MAX`: the largest value that can be represented.
pub fn PrimitiveDateTime::maximum() -> PrimitiveDateTime {
  { date: date_max, time: time_max, }
}

///|
/// Get the `Date` component of the `PrimitiveDateTime`.
pub fn PrimitiveDateTime::date(self : PrimitiveDateTime) -> Date {
  self.date
}

///|
/// Get the `Time` component of the `PrimitiveDateTime`.
pub fn PrimitiveDateTime::time(self : PrimitiveDateTime) -> Time {
  self.time
}

///|
/// Get the year of the date.
pub fn PrimitiveDateTime::year(self : PrimitiveDateTime) -> Int {
  self.date.year()
}

///|
/// Get the month of the date.
pub fn PrimitiveDateTime::month(self : PrimitiveDateTime) -> Month {
  self.date.month()
}

///|
/// Get the day of the date.
pub fn PrimitiveDateTime::day(self : PrimitiveDateTime) -> Int {
  self.date.day()
}

///|
/// Get the day of the year.
pub fn PrimitiveDateTime::ordinal(self : PrimitiveDateTime) -> Int {
  self.date.ordinal()
}

///|
/// Get the ISO week number.
pub fn PrimitiveDateTime::iso_week(self : PrimitiveDateTime) -> Int {
  self.date.iso_week()
}

///|
/// Get the week number where week 1 begins on the first Sunday.
pub fn PrimitiveDateTime::sunday_based_week(self : PrimitiveDateTime) -> Int {
  self.date.sunday_based_week()
}

///|
/// Get the week number where week 1 begins on the first Monday.
pub fn PrimitiveDateTime::monday_based_week(self : PrimitiveDateTime) -> Int {
  self.date.monday_based_week()
}

///|
/// Get the year, month, and day.
pub fn PrimitiveDateTime::to_calendar_date(
  self : PrimitiveDateTime,
) -> (Int, Month, Int) {
  self.date.to_calendar_date()
}

///|
/// Get the weekday.
pub fn PrimitiveDateTime::weekday(self : PrimitiveDateTime) -> Weekday {
  self.date.weekday()
}

///|
/// Get the Julian day for the date.
pub fn PrimitiveDateTime::to_julian_day(self : PrimitiveDateTime) -> Int {
  self.date.to_julian_day()
}

///|
/// Get the clock hour.
pub fn PrimitiveDateTime::hour(self : PrimitiveDateTime) -> Int {
  self.time.hour()
}

///|
/// Get the minute within the hour.
pub fn PrimitiveDateTime::minute(self : PrimitiveDateTime) -> Int {
  self.time.minute()
}

///|
/// Get the second within the minute.
pub fn PrimitiveDateTime::second(self : PrimitiveDateTime) -> Int {
  self.time.second()
}

///|
/// Get the nanoseconds within the second.
pub fn PrimitiveDateTime::nanosecond(self : PrimitiveDateTime) -> Int {
  self.time.nanosecond()
}

///|
/// Computes `self + duration`, returning `None` if an overflow occurred.
pub fn PrimitiveDateTime::checked_add(
  self : PrimitiveDateTime,
  duration : Duration,
) -> PrimitiveDateTime? {
  let (date_adjustment, time) = self.time.adjusting_add(duration)
  guard self.date.checked_add(duration) is Some(date) else { return None }
  let date = match date_adjustment {
    Previous => date.previous_day()
    Next => date.next_day()
    None_ => Some(date)
  }
  guard date is Some(date) else { return None }
  Some({ date, time, })
}

///|
/// Computes `self - duration`, returning `None` if an overflow occurred.
pub fn PrimitiveDateTime::checked_sub(
  self : PrimitiveDateTime,
  duration : Duration,
) -> PrimitiveDateTime? {
  let (date_adjustment, time) = self.time.adjusting_sub(duration)
  guard self.date.checked_sub(duration) is Some(date) else { return None }
  let date = match date_adjustment {
    Previous => date.previous_day()
    Next => date.next_day()
    None_ => Some(date)
  }
  guard date is Some(date) else { return None }
  Some({ date, time, })
}

///|
/// Computes `self + duration`, saturating value on overflow.
pub fn PrimitiveDateTime::saturating_add(
  self : PrimitiveDateTime,
  duration : Duration,
) -> PrimitiveDateTime {
  if self.checked_add(duration) is Some(datetime) {
    datetime
  } else if duration.is_negative() {
    PrimitiveDateTime::minimum()
  } else {
    PrimitiveDateTime::maximum()
  }
}

///|
/// Computes `self - duration`, saturating value on overflow.
pub fn PrimitiveDateTime::saturating_sub(
  self : PrimitiveDateTime,
  duration : Duration,
) -> PrimitiveDateTime {
  if self.checked_sub(duration) is Some(datetime) {
    datetime
  } else if duration.is_negative() {
    PrimitiveDateTime::maximum()
  } else {
    PrimitiveDateTime::minimum()
  }
}

///|
/// `Add<Duration> for PrimitiveDateTime`.
///
/// Aborts with `resulting value is out of range` on overflow.
pub fn PrimitiveDateTime::add_duration(
  self : PrimitiveDateTime,
  duration : Duration,
) -> PrimitiveDateTime {
  match self.checked_add(duration) {
    Some(datetime) => datetime
    None => abort("resulting value is out of range")
  }
}

///|
/// `Sub<Duration> for PrimitiveDateTime`.
///
/// Aborts with `resulting value is out of range` on overflow.
pub fn PrimitiveDateTime::sub_duration(
  self : PrimitiveDateTime,
  duration : Duration,
) -> PrimitiveDateTime {
  match self.checked_sub(duration) {
    Some(datetime) => datetime
    None => abort("resulting value is out of range")
  }
}

///|
/// `Sub for PrimitiveDateTime`.
pub fn PrimitiveDateTime::sub_date_time(
  self : PrimitiveDateTime,
  rhs : PrimitiveDateTime,
) -> Duration {
  self.date.sub_date(rhs.date) + self.time.sub_time(rhs.time)
}

///|
/// `Display for PrimitiveDateTime`.
pub impl Show for PrimitiveDateTime with fn output(self, logger) {
  Show::output(self.date, logger)
  logger.write_string(" ")
  Show::output(self.time, logger)
}
