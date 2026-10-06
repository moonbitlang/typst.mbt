// Port of `hayagriva/src/types/time.rs`.

///|
/// A date that can be as coarse as a year and as fine-grained as a day.
pub(all) struct Date {
  /// The year (1 B.C.E. is represented as 0 and so forth).
  year : Int
  /// The optional month (0-11).
  month : Int?
  /// The optional day (0-30).
  day : Int?
  /// Whether the date is approximate.
  approximate : Bool
  /// The season. Between 1 and 4 (inclusive).
  season : @citationberg.Season?
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Date with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Date with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Date with @debug.Debug::{to_repr}

///|
/// Order two dates according to the CSL specification.
pub fn Date::csl_cmp(self : Date, other : Date) -> Int {
  let ord_fn = (a : Int?, b : Int?) => {
    match (a, b) {
      (Some(a), Some(b)) => compare_int(a, b)
      (Some(_), None) => 1
      (None, Some(_)) => -1
      (None, None) => compare_bool(self.approximate, other.approximate)
    }
  }
  let c = compare_int(self.year, other.year)
  if c != 0 {
    return c
  }
  let c = ord_fn(self.month, other.month)
  if c != 0 {
    return c
  }
  ord_fn(self.day, other.day)
}

///|
fn compare_bool(a : Bool, b : Bool) -> Int {
  match (a, b) {
    (false, true) => -1
    (true, false) => 1
    _ => 0
  }
}

///|
/// This error can occur when trying to get a date from a string.
pub(all) enum DateError {
  /// The string does not conform to the date interval.
  UnknownFormat
  /// The month is out of bounds.
  MonthOutOfBounds
  /// The day is out of bounds.
  DayOutOfBounds(Int)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DateError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DateError with @debug.Debug::{to_repr}

///|
pub impl Show for DateError with fn output(self, logger) {
  match self {
    UnknownFormat => logger.write_string("date format unknown")
    MonthOutOfBounds => logger.write_string("month not in interval 1-12")
    DayOutOfBounds(d) => logger.write_string("month has no day \{d}")
  }
}

///|
pub extend DateError with Show::{to_string, output}

///|
/// Parse a date from a string.
pub fn Date::from_str(source : String) -> Result[Date, DateError] {
  let s = @unscanny.Scanner::new(source)
  s.eat_whitespace() |> ignore
  let approx = s.eat_if('~')
  let idx = s.cursor()
  match parse_full_date(s) {
    Ok((year, month, day)) =>
      return Ok({
        year,
        month: Some(month),
        day: Some(day),
        approximate: approx,
        season: None,
      })
    Err(UnknownFormat) => s.jump(idx)
    Err(e) => return Err(e)
  }
  match parse_month_with_year(s) {
    Ok((year, month)) =>
      return Ok({
        year,
        month: Some(month),
        day: None,
        approximate: approx,
        season: None,
      })
    Err(UnknownFormat) => s.jump(idx)
    Err(e) => return Err(e)
  }
  let year = match parse_year(s) {
    Ok(y) => y
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if !s.done() {
    return Err(UnknownFormat)
  }
  Ok({ year, month: None, day: None, approximate: approx, season: None, })
}

///|
/// Get a date from an integer.
pub fn Date::from_year(year : Int) -> Date {
  { year, month: None, day: None, approximate: false, season: None, }
}

///|
/// Returns the year as a human-readable gregorian year with controllable
/// pre- and postfixes denominating the year's positivity.
pub fn Date::display_year_opt(
  self : Date,
  secular : Bool,
  periods : Bool,
  designate_positive : Bool,
  ad_prefix : Bool,
) -> String {
  let np_postfix = match (secular, periods) {
    (true, false) => "BCE"
    (true, true) => "B.C.E."
    (false, false) => "BC"
    (false, true) => "B.C."
  }
  let positive_dn = match (periods, ad_prefix) {
    (true, false) => "C.E."
    (false, false) => "CE"
    (true, true) => "A.D."
    (false, true) => "AD"
  }
  if self.year > 0 {
    if designate_positive && ad_prefix {
      "\{positive_dn} \{self.year}"
    } else if designate_positive && !ad_prefix {
      "\{self.year} \{positive_dn}"
    } else {
      self.year.to_string()
    }
  } else {
    "\{-(self.year.to_int64() - 1L)} \{np_postfix}"
  }
}

///|
/// Returns the year as a human-readable gregorian year.
pub fn Date::display_year(self : Date) -> String {
  self.display_year_opt(true, false, false, false)
}

///|
pub impl Show for Date with fn output(self, logger) {
  if self.approximate {
    logger.write_char('~')
  }
  logger.write_string(int_zero_pad(self.year.to_int64(), 4))
  if self.month is Some(month) {
    logger.write_string("-" + int_zero_pad((month + 1).to_int64(), 2))
    if self.day is Some(day) {
      logger.write_string("-" + int_zero_pad((day + 1).to_int64(), 2))
    }
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Date with Show::{to_string, output}

///|
/// A duration.
pub(all) struct Duration {
  /// Days (24 hours).
  days : Int
  /// Hours (60 minutes).
  hours : Int
  /// Minutes (60 seconds).
  minutes : Int
  /// Seconds (1000 milliseconds).
  seconds : Int
  /// Milliseconds.
  milliseconds : Int
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Duration with @debug.Debug::{to_repr}

///|
/// Errors that can occur when parsing a string to a duration
pub(all) enum DurationError {
  /// The string is malformed.
  Malformed
  /// The value is out of bounds when another, subsequent value is present
  /// (i.e. `01:61:48`).
  TooLarge
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationError with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationError with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationError with @debug.Debug::{to_repr}

///|
pub impl Show for DurationError with fn output(self, logger) {
  logger.write_string(
    match self {
      Malformed => "duration string malformed"
      TooLarge => "out of bounds value when greater order value is specified"
    },
  )
}

///|
pub extend DurationError with Show::{to_string, output}

///|
fn Duration::scan(
  s : @unscanny.Scanner,
  require_end : Bool,
) -> Result[Duration, DurationError] {
  let mut days = 0
  let mut hours = 0
  let mut minutes = 0
  let mut seconds = 0
  let mut milliseconds = 0
  let idx = s.cursor()
  let colons = @unscanny.count_char(s.eat_while(c => c != '-'), ':')
  s.jump(idx)
  if !(colons >= 1 && colons <= 3) {
    return Err(Malformed)
  }
  let start = 3 - colons
  for i in start..<5 {
    match i {
      0 =>
        days = match parse_unsigned_int_min(s, 1, 2147483647) {
          Some(v) => v
          None => return Err(Malformed)
        }
      1 =>
        hours = match
          (if start == i {
            parse_unsigned_int_min(s, 2, 2147483647)
          } else {
            parse_unsigned_int_min(s, 2, 2)
          }) {
          Some(v) => v
          None => return Err(Malformed)
        }
      2 =>
        minutes = match
          (if start == i {
            parse_unsigned_int_min(s, 2, 2147483647)
          } else {
            parse_unsigned_int_min(s, 2, 2)
          }) {
          Some(v) => v
          None => return Err(Malformed)
        }
      3 =>
        seconds = match parse_unsigned_int_min(s, 2, 2) {
          Some(v) if v <= 255 => v
          _ => return Err(Malformed)
        }
      4 => {
        s.eat_whitespace() |> ignore
        let num = s.eat_while(@unscanny.is_numeric)
        if num.is_empty() {
          return Err(Malformed)
        }
        let ms = match parse_fraction("0." + num) {
          Some(v) => v
          None => return Err(Malformed)
        }
        milliseconds = (ms * 1000.0).round().to_int()
      }
      _ => abort("unreachable")
    }
    if s.done() {
      if i < 3 {
        return Err(Malformed)
      } else {
        break
      }
    }
    s.eat_whitespace() |> ignore
    if i < 3 && !s.eat_if(':') {
      return Err(Malformed)
    } else if i == 3 {
      if s.peek() == Some('-') {
        break
      }
      if !s.eat_if(',') {
        return Err(Malformed)
      }
    }
  }
  s.eat_whitespace() |> ignore
  if require_end && !s.done() {
    return Err(Malformed)
  }
  let mut i = start
  while i >= 0 {
    match i {
      0 => ()
      1 => {
        days = hours / 24
        hours = hours % 24
      }
      2 => {
        hours += minutes / 60
        minutes = minutes % 60
      }
      _ => abort("unreachable")
    }
    i -= 1
  }
  if hours >= 24 || minutes >= 60 || seconds >= 60 || milliseconds >= 1000 {
    return Err(TooLarge)
  }
  Ok({ days, hours, minutes, seconds, milliseconds, })
}

///|
/// Parse `0.<digits>` like Rust's `str::parse::<f64>` (ASCII digits only).
fn parse_fraction(s : String) -> Double? {
  if !s.iter().all(c => c.is_ascii_digit() || c == '.') {
    return None
  }
  Some(@string.parse_double(s)) catch {
    _ => None
  }
}

///|
/// Get the duration in milliseconds.
fn Duration::total_milliseconds(self : Duration) -> Int64 {
  self.milliseconds.to_int64() +
  self.seconds.to_int64() * 1000L +
  self.minutes.to_int64() * 60L * 1000L +
  self.hours.to_int64() * 60L * 60L * 1000L +
  self.days.to_int64() * 24L * 60L * 60L * 1000L
}

///|
/// `impl Ord for Duration`.
pub fn Duration::cmp(self : Duration, other : Duration) -> Int {
  self.total_milliseconds().compare(other.total_milliseconds())
}

///|
/// `impl FromStr for Duration`.
pub fn Duration::from_str(s : String) -> Result[Duration, DurationError] {
  Duration::scan(@unscanny.Scanner::new(s), true)
}

///|
pub impl Show for Duration with fn output(self, logger) {
  if self.days > 0 {
    logger.write_string("\{self.days}:")
  }
  if self.hours > 0 {
    logger.write_string(int_zero_pad(self.hours.to_int64(), 2) + ":")
  }
  logger.write_string(
    int_zero_pad(self.minutes.to_int64(), 2) +
    ":" +
    int_zero_pad(self.seconds.to_int64(), 2),
  )
  if self.milliseconds > 0 {
    logger.write_string("," + int_zero_pad(self.milliseconds.to_int64(), 3))
  }
}

///|
pub extend Duration with Show::{to_string, output}

///|
/// An half-open interval of durations.
pub(all) struct DurationRange {
  /// The start of the interval.
  start : Duration
  /// The end of the interval.
  end : Duration
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationRange with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationRange with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationRange with @debug.Debug::{to_repr}

///|
/// Create a new duration range.
pub fn DurationRange::new(start : Duration, end : Duration?) -> DurationRange {
  { start, end: end.unwrap_or(start), }
}

///|
fn DurationRange::scan(
  s : @unscanny.Scanner,
) -> Result[DurationRange, DurationError] {
  let start = match Duration::scan(s, false) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let hyphens = s.eat_while_char('-')
  if hyphens.is_empty() {
    s.eat_whitespace() |> ignore
    if s.done() {
      return Ok(DurationRange::new(start, None))
    } else {
      return Err(Malformed)
    }
  }
  match Duration::scan(s, true) {
    Ok(end) => Ok({ start, end, })
    Err(e) => Err(e)
  }
}

///|
pub impl Show for DurationRange with fn output(self, logger) {
  logger.write_string(self.start.to_string())
  if self.start != self.end {
    logger.write_string("-" + self.end.to_string())
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DurationRange with Show::{to_string, output}

///|
/// `impl FromStr for DurationRange`.
pub fn DurationRange::from_str(
  s : String,
) -> Result[DurationRange, DurationError] {
  DurationRange::scan(@unscanny.Scanner::new(s))
}

///|
fn parse_int_digits(s : @unscanny.Scanner, min : Int, max : Int) -> Int? {
  s.eat_whitespace() |> ignore
  let sign = s.eat_if_fn(c => c == '+' || c == '-')
  let positive = if sign { !s.before().has_suffix("-") } else { true }
  s.eat_whitespace() |> ignore
  let num = s.eat_while(@unscanny.is_numeric)
  let len = @unscanny.len_utf8(num)
  if len < min || len > max {
    return None
  }
  match @unscanny.parse_i32(num) {
    Some(n) => Some(if positive { n } else { -n })
    None => None
  }
}

///|
/// `parse_unsigned_int` with a digit count range; parses into a `u32` (or
/// `u8` where the caller checks).
fn parse_unsigned_int_min(s : @unscanny.Scanner, min : Int, max : Int) -> Int? {
  s.eat_whitespace() |> ignore
  let num = s.eat_while(@unscanny.is_numeric)
  let len = @unscanny.len_utf8(num)
  if len < min || len > max {
    return None
  }
  match @unscanny.parse_u32(num) {
    Some(v) if v <= 2147483647L => Some(v.to_int())
    _ => None
  }
}

///|
/// Parse a string with a plus/minus and one to four digits into an integer.
fn parse_year(s : @unscanny.Scanner) -> Result[Int, DateError] {
  match parse_int_digits(s, 4, 4) {
    Some(y) => Ok(y)
    None => Err(UnknownFormat)
  }
}

///|
fn parse_short_year(s : @unscanny.Scanner) -> Result[Int, DateError] {
  match parse_int_digits(s, 2, 2) {
    Some(year) => Ok(if year < 50 { year + 2000 } else { year + 1900 })
    None => Err(UnknownFormat)
  }
}

///|
fn parse_u8_digits(s : @unscanny.Scanner, min : Int, max : Int) -> Int? {
  match parse_unsigned_int_min(s, min, max) {
    Some(v) if v <= 255 => Some(v)
    _ => None
  }
}

///|
fn parse_month(s : @unscanny.Scanner) -> Result[Int, DateError] {
  guard parse_u8_digits(s, 1, 2) is Some(month) else {
    return Err(UnknownFormat)
  }
  if !(month >= 1 && month <= 12) {
    return Err(MonthOutOfBounds)
  }
  Ok(month - 1)
}

///|
fn parse_day(s : @unscanny.Scanner) -> Result[Int, DateError] {
  guard parse_u8_digits(s, 1, 2) is Some(day) else { return Err(UnknownFormat) }
  if !(day >= 1 && day <= 31) {
    return Err(MonthOutOfBounds)
  }
  Ok(day - 1)
}

///|
fn parse_month_with_year(
  s : @unscanny.Scanner,
) -> Result[(Int, Int), DateError] {
  let year = match parse_year(s) {
    Ok(y) => y
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if !s.eat_if('-') {
    return Err(UnknownFormat)
  }
  let month = match parse_month(s) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if !s.done() {
    return Err(UnknownFormat)
  }
  Ok((year, month))
}

///|
fn parse_full_date(s : @unscanny.Scanner) -> Result[(Int, Int, Int), DateError] {
  let idx = s.cursor()
  let year = match parse_short_year(s) {
    Ok(y) => y
    Err(_) => {
      s.jump(idx)
      match parse_year(s) {
        Ok(y) => y
        Err(e) => return Err(e)
      }
    }
  }
  s.eat_whitespace() |> ignore
  if !s.eat_if('-') {
    return Err(UnknownFormat)
  }
  let month = match parse_month(s) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if !s.eat_if('-') {
    return Err(UnknownFormat)
  }
  let day = match parse_day(s) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  if day + 1 > days_in_month(month, year) {
    return Err(DayOutOfBounds(day + 1))
  }
  s.eat_whitespace() |> ignore
  if !s.done() {
    return Err(UnknownFormat)
  }
  Ok((year, month, day))
}

///|
fn days_in_month(month : Int, year : Int) -> Int {
  if month == 1 {
    if year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) {
      29
    } else {
      28
    }
  } else if month < 7 {
    31 - month % 2
  } else {
    30 + month % 2
  }
}
