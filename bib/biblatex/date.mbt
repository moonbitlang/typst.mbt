// Port of `biblatex/src/types/date.rs`.

///|
/// A date or a range of dates and their certainty and exactness.
pub(all) struct Date {
  /// The date or the date range.
  value : DateValue
  /// Indicates whether the sources are sure about the date.
  uncertain : Bool
  /// Indicates the specificity of the date value.
  approximate : Bool
} derive(Eq, Debug)

///|
/// A single date or a range of dates.
pub(all) enum DateValue {
  /// A single date.
  At(Datetime)
  /// A range of dates with known start, but open end.
  After(Datetime)
  /// A range of dates with open start, but known end.
  Before(Datetime)
  /// A range of dates with known start and end.
  Between(Datetime, Datetime)
} derive(Eq, Debug)

///|
/// Timezone-unaware date and time.
///
/// Must specify a year and may specify month, day, and time.
pub(all) struct Datetime {
  /// The year.
  ///
  /// AD years are counted starting from one and thus represented as exactly
  /// their year (e.g., 2000 AD is `2000`) whereas BC years are counted
  /// starting from zero downwards (e.g., 1000 BC is `999`)
  year : Int
  /// The month (starting at zero).
  month : Int?
  /// The day (starting at zero).
  day : Int?
  /// The timezone-unaware time.
  time : Time?
} derive(Eq, Debug)

///|
/// A potentially timezone aware time.
pub(all) struct Time {
  /// The hour (0-23).
  hour : Int
  /// The minute (0-59).
  minute : Int
  /// The second (0-59).
  second : Int
  /// An optional timezone offset.
  offset : TimeOffset?
} derive(Eq, Debug)

///|
/// A timezone offset.
pub(all) enum TimeOffset {
  /// Time is UTC. Do not assume an origin timezone.
  Utc
  /// Offset relative to UTC. Positiveness, hour, and minute.
  Offset(positive~ : Bool, hours~ : Int, minutes~ : Int)
} derive(Eq, Debug)

///|
fn err(start : Int, end : Int, kind : TypeErrorKind) -> TypeError {
  { span: { start, end, }, kind, }
}

///|

///|
/// Parse a date from chunks.
pub fn Date::parse(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Date, TypeError] {
  let span = chunks_span(chunks)
  let date = @unscanny.to_uppercase(format_verbatim(chunks))
  let mut date_trimmed = @unscanny.trim_end(date)
  let is_both = date_trimmed.has_suffix("%")
  let is_uncertain = is_both || date_trimmed.has_suffix("?")
  let is_approximate = is_both || date_trimmed.has_suffix("~")
  if is_uncertain || is_approximate {
    date_trimmed = date_trimmed[:date_trimmed.length() - 1].to_owned()
  }
  let off = (r : Result[Datetime, TypeError], amount : Int) => {
    match r {
      Ok(d) => Ok(d)
      Err(e) => Err(e.offset(amount))
    }
  }
  let value : DateValue = if date_trimmed.contains("X") {
    match Date::range_dates(date_trimmed) {
      Ok((d1, d2)) => Between(d1, d2)
      Err(e) => return Err(e.offset(span.start))
    }
  } else if date_trimmed.find("/") is Some(pos16) {
    let s1 = date_trimmed[:pos16].to_owned()
    let s2 = date_trimmed[pos16 + 1:].to_owned()
    let pos = @unscanny.len_utf8(s1)
    fn is_open_range(s : String) -> Bool {
      @unscanny.trim(s).is_empty() || s == ".."
    }

    match (is_open_range(s1), is_open_range(s2)) {
      (false, false) => {
        let d1 = match off(Datetime::parse(s1), span.start) {
          Ok(d) => d
          Err(e) => return Err(e)
        }
        let d2 = match off(Datetime::parse(s2), span.start + pos + 1) {
          Ok(d) => d
          Err(e) => return Err(e)
        }
        Between(d1, d2)
      }
      (false, true) =>
        match off(Datetime::parse(s1), span.start) {
          Ok(d) => After(d)
          Err(e) => return Err(e)
        }
      (true, false) =>
        match off(Datetime::parse(s2), span.start + pos + 1) {
          Ok(d) => Before(d)
          Err(e) => return Err(e)
        }
      (true, true) => return Err({ span, kind: UndefinedRange, })
    }
  } else {
    match off(Datetime::parse(date_trimmed), span.start) {
      Ok(d) => At(d)
      Err(e) => return Err(e)
    }
  }
  Ok({ approximate: is_approximate, uncertain: is_uncertain, value, })
}

///|
/// Create a new date from `year`, `month`, and `day` chunks.
pub fn Date::parse_three_fields(
  year : ArrayView[Spanned[Chunk]],
  month : ArrayView[Spanned[Chunk]]?,
  day : ArrayView[Spanned[Chunk]]?,
) -> Result[Date, TypeError] {
  let year_v = match get_year(@unscanny.Scanner::new(format_verbatim(year))) {
    Ok(y) => y
    Err(e) => return Err(e.offset(chunks_span(year).start))
  }
  let mut date_atom : Datetime = {
    year: year_v,
    month: None,
    day: None,
    time: None,
  }
  if month is Some(month) {
    let month = format_verbatim(month)
    let s = @unscanny.Scanner::new(month)
    s.eat_whitespace() |> ignore

    // There are two conventions for the `month` field.
    // (a) BibLaTeX prefers `1`. (§3.2 Fields of btxdoc.pdf)
    let m = match parse_unsigned_int(s, 1, 2) {
      // BibLaTeX starts at one, not zero
      Some(m) => Some(m - 1)
      None => {
        // (b) BibTeX prefers `January` or `jan`. (§2.2.2 Data Fields of
        // biblatex.pdf)
        let month = s.eat_while(c => c.is_ascii_alphabetic())
        match get_month_for_name(month) {
          Some(m) => Some(m)
          None => get_month_for_abbr(month).map(x => x.1)
        }
      }
    }
    date_atom = { ..date_atom, month: m, }
    match day {
      Some(day) => {
        let span = chunks_span(day)
        let day = format_verbatim(day)
        let day = match @unscanny.parse_u8(@unscanny.trim(day)) {
          Some(d) => d
          None =>
            if span.is_empty() {
              return Err({ span, kind: MissingNumber, })
            } else {
              return Err({ span, kind: InvalidNumber, })
            }
        }
        if !(day >= 1 && day <= 31) {
          return Err({ span, kind: DayOutOfRange, })
        }
        date_atom = { ..date_atom, day: Some(day - 1), }
      }
      None => {
        // Try to read the day from the month field.
        if s
          .eat_while(c => @unscanny.is_whitespace(c) || c is ('-' | '\u{00a0}'))
          .is_empty() {
          return Ok(Date::from_datetime(date_atom))
        }
        let day_start = s.cursor()
        let day = s.eat_while(c => c.is_ascii_digit())
        let day_span = { start: day_start, end: s.cursor(), }
        if day.is_empty() {
          return Err({ span: day_span, kind: MissingNumber, })
        }
        // Upstream unwraps; out-of-range values are reported as such.
        let day = match @unscanny.parse_u8(day) {
          Some(d) => d
          None => 256
        }
        if !(day >= 1 && day <= 31) {
          return Err({ span: day_span, kind: DayOutOfRange, })
        }
        date_atom = { ..date_atom, day: Some(day - 1), }
      }
    }
  }
  Ok(Date::from_datetime(date_atom))
}

///|
fn Date::from_datetime(atom : Datetime) -> Date {
  { approximate: false, uncertain: false, value: At(atom), }
}

///|
fn Date::range_dates(
  source : String,
) -> Result[(Datetime, Datetime), TypeError] {
  let s = @unscanny.Scanner::new(source)
  s.eat_whitespace() |> ignore
  let year_part = s.eat_while(c => c.is_ascii_digit())
  let sure_digits = year_part.length()
  if sure_digits < 2 ||
    @unscanny.len_utf8(s.eat_while_char('X')) + sure_digits != 4 {
    return Err(err(0, s.cursor(), WrongNumberOfDigits))
  }
  let mut variable = 1
  for _ in 0..<(4 - sure_digits) {
    variable *= 10
  }
  let year = @unscanny.parse_i32(year_part).unwrap() * variable
  variable -= 1
  if sure_digits != 4 {
    return Ok(
      (
        { year, month: None, day: None, time: None, },
        { year: year + variable, month: None, day: None, time: None, },
      ),
    )
  }
  if get_hyphen(s) is Err(e) {
    return Err(e)
  }
  let idx = s.cursor()
  match s.eat_while_char('X').length() {
    0 => ()
    2 => {
      s.eat_whitespace() |> ignore
      if !s.done() {
        if get_hyphen(s) is Err(e) {
          return Err(e)
        }
        if s.eat_while_char('X').length() != 2 {
          return Err(err(s.cursor(), s.cursor(), InvalidFormat))
        }
      }
      return Ok(
        (
          { year, month: Some(0), day: None, time: None, },
          { year, month: Some(11), day: None, time: None, },
        ),
      )
    }
    _ => return Err(err(idx, s.cursor(), WrongNumberOfDigits))
  }
  let month_start = s.cursor()
  let month = s.eat_while(c => c.is_ascii_digit())
  if month.length() != 2 {
    return Err(err(idx, s.cursor(), WrongNumberOfDigits))
  }
  let month = @unscanny.parse_i32(month).unwrap() - 1
  if month > 11 || month < 0 {
    return Err(err(month_start, s.cursor(), MonthOutOfRange))
  }
  if get_hyphen(s) is Err(e) {
    return Err(e)
  }
  if s.eat_while_char('X').length() == 2 {
    s.eat_whitespace() |> ignore
    if !s.done() {
      return Err(err(s.cursor(), s.cursor(), InvalidFormat))
    }
    return Ok(
      (
        { year, month: Some(month), day: Some(0), time: None, },
        { year, month: Some(month), day: Some(30), time: None, },
      ),
    )
  }
  Err(err(s.cursor(), s.cursor(), InvalidFormat))
}

///|
fn get_year(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  s.eat_whitespace() |> ignore
  let year_idx = s.cursor()
  let has_sign = s.eat_if_any(['-', '+'])
  s.eat_whitespace() |> ignore
  let digits = s.eat_while(c => c.is_ascii_digit())
  if digits.is_empty() || digits.length() > 4 {
    return Err(err(year_idx, s.cursor(), WrongNumberOfDigits))
  }

  // This is guaranteed to only contain digits, whitespace, and a sign.
  let year = match @unscanny.parse_i32(s.from(year_idx)) {
    Some(y) => y
    // Upstream panics here (whitespace after the sign).
    None => return Err(err(year_idx, s.cursor(), InvalidFormat))
  }
  match parse_era_marker(s) {
    Err(e) => return Err(e)
    Ok(Some(positive_era)) => {
      if has_sign {
        return Err(err(year_idx, s.cursor(), InvalidFormat))
      }
      if year == 0 {
        return Err(err(year_idx, s.cursor(), YearZeroCE))
      }
      if !positive_era {
        return Ok(-year + 1)
      }
    }
    Ok(None) => ()
  }
  Ok(year)
}

///|
fn parse_era_marker(s : @unscanny.Scanner) -> Result[Bool?, TypeError] {
  s.eat_whitespace() |> ignore
  let era_idx = s.cursor()
  if s.eat_if_str("AD") || s.eat_if_str("CE") {
    if s.peek() is Some(c) && @unscanny.is_alphanumeric(c) {
      return Err(err(era_idx, s.cursor(), InvalidFormat))
    }
    return Ok(Some(true))
  }
  if s.eat_if_str("BC") {
    s.eat_if('E') |> ignore
    if s.peek() is Some(c) && @unscanny.is_alphanumeric(c) {
      return Err(err(era_idx, s.cursor(), InvalidFormat))
    }
    return Ok(Some(false))
  }
  Ok(None)
}

///|
fn get_hyphen(s : @unscanny.Scanner) -> Result[Unit, TypeError] {
  s.eat_whitespace() |> ignore
  if s.eat_while_char('-').is_empty() {
    return Err(err(s.cursor(), s.cursor(), InvalidFormat))
  }
  s.eat_whitespace() |> ignore
  Ok(())
}

///|
/// `impl Type for Date`.
pub fn parse_date(
  chunks : ArrayView[Spanned[Chunk]],
) -> Result[Date, TypeError] {
  Date::parse(chunks)
}

///|
/// `impl Type for Date` (`to_chunks`).
pub fn date_to_chunks(date : Date) -> Chunks {
  let s = match date.value {
    At(date) => "\{date}"
    After(start) => "\{start}/.."
    Before(end) => "../\{end}"
    Between(start, end) => "\{start}/\{end}"
  }
  let suffix = match (date.approximate, date.uncertain) {
    (true, true) => "%"
    (true, false) => "~"
    (false, true) => "?"
    (false, false) => ""
  }
  [Spanned::detached(Chunk::Normal(s + suffix))]
}

///|
/// Parse a datetime from a string.
fn Datetime::parse(src : String) -> Result[Datetime, TypeError] {
  let s = @unscanny.Scanner::new(src)
  let pos = s.cursor()
  let year = match parse_short_year(s) {
    Ok(y) => y
    Err(_) => {
      s.jump(pos)
      match parse_year(s) {
        Ok(y) => y
        Err(e) => return Err(e)
      }
    }
  }
  s.eat_whitespace() |> ignore
  if s.done() {
    return Ok({ year, month: None, day: None, time: None, })
  }
  if parse_hyphen(s) is Err(e) {
    return Err(e)
  }
  let some_month = match parse_month(s) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let month = Some(some_month)
  s.eat_whitespace() |> ignore
  if s.done() {
    return Ok({ year, month, day: None, time: None, })
  }
  if parse_hyphen(s) is Err(e) {
    return Err(e)
  }
  let some_day = match parse_day(s) {
    Ok(d) => d
    Err(e) => return Err(e)
  }
  let day = Some(some_day)
  if some_day + 1 > days_in_month(some_month, year) {
    return Err(err(pos, s.cursor(), DayOutOfRange))
  }
  s.eat_whitespace() |> ignore
  if s.done() {
    return Ok({ year, month, day, time: None, })
  }
  if !s.eat_if('T') {
    return Err(err(pos, s.cursor(), InvalidFormat))
  }
  let hour = match parse_hour(s) {
    Ok(h) => h
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if s.done() {
    return Ok({
      year,
      month,
      day,
      time: Some({ hour, minute: 0, second: 0, offset: None, }),
    })
  }
  if parse_colon(s) is Err(e) {
    return Err(e)
  }
  let minute = match parse_minutes_or_seconds(s) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if s.done() {
    return Ok({
      year,
      month,
      day,
      time: Some({ hour, minute, second: 0, offset: None, }),
    })
  }
  if parse_colon(s) is Err(e) {
    return Err(e)
  }
  let second = match parse_minutes_or_seconds(s) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  s.eat_whitespace() |> ignore
  if s.done() {
    return Ok({
      year,
      month,
      day,
      time: Some({ hour, minute, second, offset: None, }),
    })
  }
  let offset = match parse_offset(s) {
    Ok(o) => o
    Err(e) => return Err(e)
  }
  Ok({
    year,
    month,
    day,
    time: Some({ hour, minute, second, offset: Some(offset), }),
  })
}

///|
fn pad_int(n : Int, width : Int) -> String {
  // Rust's `{:0width}` for signed integers (sign counts towards the width).
  let neg = n < 0
  let digits = (if neg { -n } else { n }).to_string()
  let w = if neg { width - 1 } else { width }
  let padded = if digits.length() < w {
    String::make(w - digits.length(), '0') + digits
  } else {
    digits
  }
  if neg {
    "-" + padded
  } else {
    padded
  }
}

///|
pub impl Show for Datetime with fn output(self, logger) {
  if self.year >= 0 {
    logger.write_string(pad_int(self.year, 4))
  } else {
    logger.write_string(pad_int(self.year, 5))
  }
  if self.month is Some(month) {
    match self.day {
      Some(day) =>
        logger.write_string("-\{pad_int(month + 1, 2)}-\{pad_int(day + 1, 2)}")
      None => logger.write_string("-\{pad_int(month + 1, 2)}")
    }
  }
}

///|
fn parse_int(s : @unscanny.Scanner, min_digits : Int, max_digits : Int) -> Int? {
  s.eat_whitespace() |> ignore
  let sign = s.eat_if_fn(c => c == '+' || c == '-')
  let positive = if sign { !s.before().has_suffix("-") } else { true }
  s.eat_whitespace() |> ignore
  let num = s.eat_while(@unscanny.is_numeric)
  let len = @unscanny.len_utf8(num)
  if len < min_digits || len > max_digits {
    return None
  }
  let n = @unscanny.parse_i32(num).unwrap_or(0)
  Some(if positive { n } else { -n })
}

///|
fn parse_unsigned_int(
  s : @unscanny.Scanner,
  min_digits : Int,
  max_digits : Int,
) -> Int? {
  s.eat_whitespace() |> ignore
  let num = s.eat_while(@unscanny.is_numeric)
  let len = @unscanny.len_utf8(num)
  if len < min_digits || len > max_digits {
    return None
  }
  Some(@unscanny.parse_i32(num).unwrap_or(0))
}

///|
/// Parse a string with a plus/minus and one to four digits into an integer.
fn parse_year(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  let pos = s.cursor()
  match parse_int(s, 4, 4) {
    Some(y) => Ok(y)
    None => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
fn parse_short_year(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  let pos = s.cursor()
  match parse_int(s, 2, 2) {
    Some(year) => Ok(if year < 50 { year + 2000 } else { year + 1900 })
    None => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
/// Parse the month in the 0-11 range.
fn parse_month(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  let pos = s.cursor()
  match parse_unsigned_int(s, 1, 2) {
    Some(month) =>
      if !(month >= 1 && month <= 12) {
        Err(err(pos, s.cursor(), MonthOutOfRange))
      } else {
        Ok(month - 1)
      }
    None => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
/// Parse the day in the 0-30 range.
fn parse_day(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  let pos = s.cursor()
  match parse_unsigned_int(s, 1, 2) {
    Some(day) =>
      if !(day >= 1 && day <= 31) {
        Err(err(pos, s.cursor(), DayOutOfRange))
      } else {
        Ok(day - 1)
      }
    None => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
/// Parse the hour in the 0-23 range.
fn parse_hour(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  let pos = s.cursor()
  match parse_unsigned_int(s, 1, 2) {
    Some(hour) =>
      if hour > 23 {
        Err(err(pos, s.cursor(), InvalidNumber))
      } else {
        Ok(hour)
      }
    None => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
/// Parse minutes or seconds in the 0-59 range.
fn parse_minutes_or_seconds(s : @unscanny.Scanner) -> Result[Int, TypeError] {
  let pos = s.cursor()
  match parse_unsigned_int(s, 1, 2) {
    Some(num) =>
      if num > 59 {
        Err(err(pos, s.cursor(), InvalidNumber))
      } else {
        Ok(num)
      }
    None => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
/// Parse an offset.
fn parse_offset(s : @unscanny.Scanner) -> Result[TimeOffset, TypeError] {
  s.eat_whitespace() |> ignore
  let pos = s.cursor()
  let c = s.eat()
  match c {
    Some('Z') => Ok(Utc)
    Some('+' | '-') => {
      let positive = c == Some('+')
      let hours = match parse_hour(s) {
        Ok(h) => h
        Err(e) => return Err(e)
      }
      s.eat_whitespace() |> ignore
      if s.done() {
        return Ok(Offset(positive~, hours~, minutes=0))
      }
      if parse_colon(s) is Err(e) {
        return Err(e)
      }
      match parse_minutes_or_seconds(s) {
        Ok(minutes) => Ok(Offset(positive~, hours~, minutes~))
        Err(e) => Err(e)
      }
    }
    _ => Err(err(pos, s.cursor(), InvalidFormat))
  }
}

///|
/// Parse a hyphen.
pub fn parse_hyphen(s : @unscanny.Scanner) -> Result[Unit, TypeError] {
  let pos = s.cursor()
  s.eat_whitespace() |> ignore
  if !s.eat_if('-') {
    return Err(err(pos, s.cursor(), InvalidFormat))
  }
  s.eat_while_char('-') |> ignore
  Ok(())
}

///|
/// Parse a colon.
pub fn parse_colon(s : @unscanny.Scanner) -> Result[Unit, TypeError] {
  let pos = s.cursor()
  s.eat_whitespace() |> ignore
  if !s.eat_if(':') {
    return Err(err(pos, s.cursor(), InvalidFormat))
  }
  Ok(())
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

///|
/// Used to resolve month abbreviations to their respective values.
pub fn get_month_for_abbr(month : String) -> (String, Int)? {
  match @unscanny.to_lowercase(month) {
    "jan" => Some(("January", 0))
    "feb" => Some(("February", 1))
    "mar" => Some(("March", 2))
    "apr" => Some(("April", 3))
    "may" => Some(("May", 4))
    "jun" => Some(("June", 5))
    "jul" => Some(("July", 6))
    "aug" => Some(("August", 7))
    "sep" => Some(("September", 8))
    "oct" => Some(("October", 9))
    "nov" => Some(("November", 10))
    "dec" => Some(("December", 11))
    _ => None
  }
}

///|
/// Used to resolve month names to their respective values.
fn get_month_for_name(month : String) -> Int? {
  match @unscanny.to_lowercase(month) {
    "january" => Some(0)
    "february" => Some(1)
    "march" => Some(2)
    "april" => Some(3)
    "may" => Some(4)
    "june" => Some(5)
    "july" => Some(6)
    "august" => Some(7)
    "september" => Some(8)
    "october" => Some(9)
    "november" => Some(10)
    "december" => Some(11)
    _ => None
  }
}
