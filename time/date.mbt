// Port of `time/src/date.rs`.

///|
/// Date in the proleptic Gregorian calendar.
///
/// By default, years between ±9999 inclusive are representable.
pub struct Date {
  // |     x      | xxxxxxxxxxxxxxxxxxxxx |       x       | xxxxxxxxx |
  // |   1 bit    |        21 bits        |     1 bit     |  9 bits   |
  // | unassigned |         year          | is leap year? |  ordinal  |
  // The year is 15 bits when `large-dates` is not enabled.
  priv value : Int
} derive(Eq, Compare, Hash, Debug)

///|
let days_cumulative_common_leap : FixedArray[FixedArray[Int]] = [
  [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334],
  [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335],
]

///|
/// Construct a `Date` from its internal representation, the validity of which
/// must be guaranteed by the caller.
fn Date::from_parts(year : Int, is_leap_year : Bool, ordinal : Int) -> Date {
  { value: (year << 10) | ((if is_leap_year { 1 } else { 0 }) << 9) | ordinal, }
}

///|
/// Construct a `Date` from the year and ordinal values, the validity of which
/// must be guaranteed by the caller.
fn Date::from_ordinal_date_unchecked(year : Int, ordinal : Int) -> Date {
  Date::from_parts(year, range_validated_is_leap_year(year), ordinal)
}

///|
let date_min : Date = Date::from_ordinal_date_unchecked(MIN_YEAR, 1)

///|
let date_max : Date = Date::from_ordinal_date_unchecked(
  MAX_YEAR,
  range_validated_days_in_year(MAX_YEAR),
)

///|
/// `Date::MIN`: the minimum valid `Date`.
pub fn Date::minimum() -> Date {
  date_min
}

///|
/// `Date::MAX`: the maximum valid `Date`.
pub fn Date::maximum() -> Date {
  date_max
}

///|
fn ensure_year_ranged(year : Int) -> Unit raise ComponentRange {
  if year < MIN_YEAR || year > MAX_YEAR {
    raise ComponentRange::unconditional("year")
  }
}

///|
/// Attempt to create a `Date` from the year, month, and day.
pub fn Date::from_calendar_date(
  year : Int,
  month : Month,
  day : Int,
) -> Date raise ComponentRange {
  ensure_year_ranged(year)
  let is_leap_year = range_validated_is_leap_year(year)
  match day {
    1..=28 => ()
    29..=31 if day <= days_in_month_leap(month.number(), is_leap_year) => ()
    _ => raise ComponentRange::conditional("day")
  }
  Date::from_parts(
    year,
    is_leap_year,
    days_cumulative_common_leap[if is_leap_year { 1 } else { 0 }][month.number() -
    1] +
    day,
  )
}

///|
/// Attempt to create a `Date` from the year and ordinal day number.
pub fn Date::from_ordinal_date(
  year : Int,
  ordinal : Int,
) -> Date raise ComponentRange {
  ensure_year_ranged(year)
  let is_leap_year = range_validated_is_leap_year(year)
  match ordinal {
    1..=365 => ()
    366 if is_leap_year => ()
    _ => raise ComponentRange::conditional("ordinal")
  }
  Date::from_parts(year, is_leap_year, ordinal)
}

///|
/// Attempt to create a `Date` from the ISO year, week, and weekday.
pub fn Date::from_iso_week_date(
  year : Int,
  week : Int,
  weekday : Weekday,
) -> Date raise ComponentRange {
  ensure_year_ranged(year)
  match week {
    1..=52 => ()
    53 if week <= weeks_in_year(year) => ()
    _ => raise ComponentRange::conditional("week")
  }
  let adj_year = year - 1
  let raw = 365 * adj_year +
    div_floor(adj_year, 4) -
    div_floor(adj_year, 100) +
    div_floor(adj_year, 400)
  let jan_4 = match raw % 7 {
    -6 | 1 => 8
    -5 | 2 => 9
    -4 | 3 => 10
    -3 | 4 => 4
    -2 | 5 => 5
    -1 | 6 => 6
    _ => 7
  }
  let ordinal = week * 7 + weekday.number_from_monday() - jan_4
  if ordinal <= 0 {
    return Date::from_ordinal_date_unchecked(
      year - 1,
      ordinal + range_validated_days_in_year(year - 1),
    )
  }
  let is_leap_year = range_validated_is_leap_year(year)
  let days_in_year = if is_leap_year { 366 } else { 365 }
  if ordinal > days_in_year {
    // Issue #777
    if year == MAX_YEAR {
      raise ComponentRange::conditional("weekday")
    }
    Date::from_ordinal_date_unchecked(year + 1, ordinal - days_in_year)
  } else {
    Date::from_parts(year, is_leap_year, ordinal)
  }
}

///|
/// Create a `Date` from the Julian day number.
pub fn Date::from_julian_day(julian_day : Int) -> Date raise ComponentRange {
  if julian_day < date_min.to_julian_day() ||
    julian_day > date_max.to_julian_day() {
    raise ComponentRange::unconditional("julian_day")
  }
  Date::from_julian_day_unchecked(julian_day)
}

///|
/// Create a `Date` from the Julian day number, the validity of which must be
/// guaranteed by the caller.
fn Date::from_julian_day_unchecked(julian_day : Int) -> Date {
  let eras : UInt = 5_949
  // Rata Die shift:
  let d_shift : UInt = 146097U * eras - 1_721_060U
  // Year shift:
  let y_shift : UInt = 400U * eras
  let cen_mul : UInt = ((4UL << 47) / 146_097UL).to_uint()
  let jul_mul : UInt = ((4UL << 40) / 1_461UL + 1UL).to_uint()
  let cen_cut : UInt = ((365UL << 32) / 36_525UL).to_uint()
  let day = julian_day.reinterpret_as_uint() + d_shift
  let c_n = (day.to_uint64() * cen_mul.to_uint64()) >> 15
  let cen = (c_n >> 32).to_uint()
  let cpt = c_n.to_uint()
  let ijy = cpt > cen_cut || cen % 4U == 0U
  let jul = day - cen / 4U + cen
  let y_n = (jul.to_uint64() * jul_mul.to_uint64()) >> 8
  let yrs = (y_n >> 32).to_uint()
  let ypt = y_n.to_uint()
  let year = (yrs - y_shift).reinterpret_as_int()
  let ordinal = ((ypt.to_uint64() * 1_461UL) >> 34).to_int() +
    (if ijy { 1 } else { 0 })
  let leap = yrs % 4U == 0U && ijy
  Date::from_parts(year, leap, ordinal)
}

///|
/// Whether `is_leap_year(self.year())` is `true`.
fn Date::is_in_leap_year(self : Date) -> Bool {
  ((self.value >> 9) & 1) == 1
}

///|
/// Get the year of the date.
pub fn Date::year(self : Date) -> Int {
  self.value >> 10
}

///|
/// Get the month.
pub fn Date::month(self : Date) -> Month {
  self.to_calendar_date().1
}

///|
/// Get the day of the month. The returned value will always be in the range
/// `1..=31`.
pub fn Date::day(self : Date) -> Int {
  self.to_calendar_date().2
}

///|
/// Get the day of the year. The returned value will always be in the range
/// `1..=366` (`1..=365` for common years).
pub fn Date::ordinal(self : Date) -> Int {
  self.value & 0x1FF
}

///|
/// Get the ISO 8601 year and week number.
fn Date::iso_year_week(self : Date) -> (Int, Int) {
  let (year, ordinal) = self.to_ordinal_date()
  match (ordinal + 10 - self.weekday().number_from_monday()) / 7 {
    0 => (year - 1, weeks_in_year(year - 1))
    53 if weeks_in_year(year) == 52 => (year + 1, 1)
    week => (year, week)
  }
}

///|
/// Get the ISO week number. The returned value will always be in the range
/// `1..=53`.
pub fn Date::iso_week(self : Date) -> Int {
  self.iso_year_week().1
}

///|
/// Get the week number where week 1 begins on the first Sunday. The returned
/// value will always be in the range `0..=53`.
pub fn Date::sunday_based_week(self : Date) -> Int {
  (self.ordinal() - self.weekday().number_days_from_sunday() + 6) / 7
}

///|
/// Get the week number where week 1 begins on the first Monday. The returned
/// value will always be in the range `0..=53`.
pub fn Date::monday_based_week(self : Date) -> Int {
  (self.ordinal() - self.weekday().number_days_from_monday() + 6) / 7
}

///|
/// Get the year, month, and day.
pub fn Date::to_calendar_date(self : Date) -> (Int, Month, Int) {
  let (year, ordinal) = self.to_ordinal_date()
  let jan_feb_len = 59 + (if self.is_in_leap_year() { 1 } else { 0 })
  let (month_adj, ordinal_adj) = if ordinal <= jan_feb_len {
    (0, 0)
  } else {
    (2, jan_feb_len)
  }
  let ordinal = ordinal - ordinal_adj
  let month = (ordinal * 268 + 8031) >> 13
  let days_in_preceding_months = (month * 3917 - 3866) >> 7
  let day = ordinal - days_in_preceding_months
  let month = month + month_adj
  (year, Month::from_number(month) catch { _ => panic() }, day)
}

///|
/// Get the year and ordinal day number.
pub fn Date::to_ordinal_date(self : Date) -> (Int, Int) {
  (self.year(), self.ordinal())
}

///|
/// Get the ISO 8601 year, week number, and weekday.
pub fn Date::to_iso_week_date(self : Date) -> (Int, Int, Weekday) {
  let (year, week) = self.iso_year_week()
  (year, week, self.weekday())
}

///|
/// Get the weekday.
pub fn Date::weekday(self : Date) -> Weekday {
  match self.to_julian_day() % 7 {
    -6 | 1 => Tuesday
    -5 | 2 => Wednesday
    -4 | 3 => Thursday
    -3 | 4 => Friday
    -2 | 5 => Saturday
    -1 | 6 => Sunday
    _ => Monday
  }
}

///|
/// Get the next calendar date.
pub fn Date::next_day(self : Date) -> Date? {
  let is_last_day_of_year = (self.value & 0x3FF) is (365 | 878)
  if is_last_day_of_year {
    if self.value == date_max.value {
      None
    } else {
      Some(Date::from_ordinal_date_unchecked(self.year() + 1, 1))
    }
  } else {
    Some(self.add_days_unchecked(1))
  }
}

///|
/// Get the previous calendar date.
pub fn Date::previous_day(self : Date) -> Date? {
  if self.ordinal() != 1 {
    Some(self.add_days_unchecked(-1))
  } else if self.value == date_min.value {
    None
  } else {
    let year = self.year() - 1
    let is_leap_year = range_validated_is_leap_year(year)
    let ordinal = if is_leap_year { 366 } else { 365 }
    Some(Date::from_parts(year, is_leap_year, ordinal))
  }
}

///|
/// Get the Julian day for the date.
pub fn Date::to_julian_day(self : Date) -> Int {
  let (year, ordinal) = self.to_ordinal_date()
  // The algorithm requires a non-negative year. Add the lowest value to make it so. This is
  // adjusted for at the end with the final subtraction.
  let adj_year = year + 999_999
  let century = adj_year / 100
  let days_before_year = (1461L * adj_year.to_int64() / 4L).to_int() -
    century +
    century / 4
  days_before_year + ordinal - 363_521_075
}

///|
fn Date::add_days_unchecked(self : Date, days : Int) -> Date {
  { value: self.value + days, }
}

///|
fn checked_add_i32(a : Int, b : Int) -> Int? {
  let r = a.to_int64() + b.to_int64()
  if r < -2147483648L || r > 2147483647L {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// Computes `self + duration`, returning `None` if an overflow occurred.
pub fn Date::checked_add(self : Date, duration : Duration) -> Date? {
  let whole_days = duration.whole_days()
  if whole_days < -2147483648L || whole_days > 2147483647L {
    return None
  }
  let year = self.year()
  let is_leap_year = self.is_in_leap_year()
  let ordinal = self.ordinal()
  let days_in_year = if is_leap_year { 366 } else { 365 }
  let whole_days = whole_days.to_int()

  // Fast path for when the result is in the same year.
  if checked_add_i32(ordinal, whole_days) is Some(new_ordinal) &&
    new_ordinal >= 1 &&
    new_ordinal <= days_in_year {
    return Some(Date::from_parts(year, is_leap_year, new_ordinal))
  }
  guard checked_add_i32(self.to_julian_day(), whole_days) is Some(julian_day) else {
    return None
  }
  try Date::from_julian_day(julian_day) catch {
    _ => None
  } noraise {
    date => Some(date)
  }
}

///|
/// Computes `self - duration`, returning `None` if an overflow occurred.
pub fn Date::checked_sub(self : Date, duration : Duration) -> Date? {
  let whole_days = duration.whole_days()
  if whole_days < -2147483648L || whole_days > 2147483647L {
    return None
  }
  let year = self.year()
  let is_leap_year = self.is_in_leap_year()
  let ordinal = self.ordinal()
  let days_in_year = if is_leap_year { 366 } else { 365 }
  let whole_days = whole_days.to_int()

  // Fast path for when the result is in the same year.
  if checked_sub_i32(ordinal, whole_days) is Some(new_ordinal) &&
    new_ordinal >= 1 &&
    new_ordinal <= days_in_year {
    return Some(Date::from_parts(year, is_leap_year, new_ordinal))
  }
  guard checked_sub_i32(self.to_julian_day(), whole_days) is Some(julian_day) else {
    return None
  }
  try Date::from_julian_day(julian_day) catch {
    _ => None
  } noraise {
    date => Some(date)
  }
}

///|
fn checked_sub_i32(a : Int, b : Int) -> Int? {
  let r = a.to_int64() - b.to_int64()
  if r < -2147483648L || r > 2147483647L {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// Computes `self + duration`, saturating value on overflow.
pub fn Date::saturating_add(self : Date, duration : Duration) -> Date {
  if self.checked_add(duration) is Some(date) {
    date
  } else if duration.is_negative() {
    date_min
  } else {
    date_max
  }
}

///|
/// Computes `self - duration`, saturating value on overflow.
pub fn Date::saturating_sub(self : Date, duration : Duration) -> Date {
  if self.checked_sub(duration) is Some(date) {
    date
  } else if duration.is_negative() {
    date_max
  } else {
    date_min
  }
}

///|
/// Create a `PrimitiveDateTime` using the existing date. The `Time` component
/// will be set to midnight.
pub fn Date::midnight(self : Date) -> PrimitiveDateTime {
  PrimitiveDateTime::new(self, Time::midnight())
}

///|
/// Create a `PrimitiveDateTime` using the existing date and the provided
/// `Time`.
pub fn Date::with_time(self : Date, time : Time) -> PrimitiveDateTime {
  PrimitiveDateTime::new(self, time)
}

///|
/// Attempt to create a `PrimitiveDateTime` using the existing date and the
/// provided time.
pub fn Date::with_hms(
  self : Date,
  hour : Int,
  minute : Int,
  second : Int,
) -> PrimitiveDateTime raise ComponentRange {
  PrimitiveDateTime::new(self, Time::from_hms(hour, minute, second))
}

///|
/// `Add<Duration> for Date`.
///
/// Aborts with `overflow adding duration to date` on overflow.
pub fn Date::add_duration(self : Date, duration : Duration) -> Date {
  match self.checked_add(duration) {
    Some(date) => date
    None => abort("overflow adding duration to date")
  }
}

///|
/// `Sub<Duration> for Date`.
///
/// Aborts with `overflow subtracting duration from date` on overflow.
pub fn Date::sub_duration(self : Date, duration : Duration) -> Date {
  match self.checked_sub(duration) {
    Some(date) => date
    None => abort("overflow subtracting duration from date")
  }
}

///|
/// `Sub for Date`: the duration between two dates.
pub fn Date::sub_date(self : Date, other : Date) -> Duration {
  Duration::days((self.to_julian_day() - other.to_julian_day()).to_int64())
}

///|
/// `Display for Date`.
pub impl Show for Date with fn output(self, logger) {
  let (year, month, day) = self.to_calendar_date()
  if year < 0 {
    logger.write_string("-")
  }
  logger.write_string(zero_pad(year.abs(), 4))
  logger.write_string("-")
  logger.write_string(zero_pad(month.number(), 2))
  logger.write_string("-")
  logger.write_string(zero_pad(day, 2))
}
