// `toml_datetime` 0.6.8 types with their `Display` impls, and the date-time
// grammar of `toml_edit::parser::datetime`.

///|
/// `toml_datetime::Date`.
priv struct Date {
  year : Int
  month : Int
  day : Int
}

///|
/// `toml_datetime::Time`.
priv struct Time {
  hour : Int
  minute : Int
  second : Int
  nanosecond : Int
}

///|
/// `toml_datetime::Offset`.
priv enum Offset {
  Z
  Custom(minutes~ : Int)
}

///|
/// `toml_datetime::Datetime`.
priv struct Datetime {
  date : Date?
  time : Time?
  offset : Offset?
}

///|
/// Formats `n` with at least `width` digits (zero-padded).
fn pad(n : Int, width : Int) -> String {
  let s = n.to_string()
  if s.length() >= width {
    s
  } else {
    "0".repeat(width - s.length()) + s
  }
}

///|
/// `impl Display for Datetime` (and for `Date`, `Time`, `Offset`).
fn Datetime::to_display(self : Datetime) -> String {
  let buf = StringBuilder()
  if self.date is Some(date) {
    buf.write_string(
      "\{pad(date.year, 4)}-\{pad(date.month, 2)}-\{pad(date.day, 2)}",
    )
  }
  if self.time is Some(time) {
    if self.date is Some(_) {
      buf.write_char('T')
    }
    buf.write_string(
      "\{pad(time.hour, 2)}:\{pad(time.minute, 2)}:\{pad(time.second, 2)}",
    )
    if time.nanosecond != 0 {
      let s = pad(time.nanosecond, 9)
      let mut end = s.length()
      while end > 0 && s[end - 1] == '0' {
        end -= 1
      }
      buf.write_char('.')
      buf.write_string(s.unsafe_substring(start=0, end~))
    }
  }
  match self.offset {
    Some(Z) => buf.write_char('Z')
    Some(Custom(minutes~)) => {
      let (sign, minutes) = if minutes < 0 {
        ('-', -minutes)
      } else {
        ('+', minutes)
      }
      buf.write_char(sign)
      buf.write_string("\{pad(minutes / 60, 2)}:\{pad(minutes % 60, 2)}")
    }
    None => ()
  }
  buf.to_string()
}

///|
fn is_digit(b : Int) -> Bool {
  b >= '0' && b <= '9'
}

///|
/// Parses a run of ASCII digits.
fn digits_value(i : Input, start : Int, end : Int) -> Int {
  let mut v = 0
  for k in start..<end {
    v = v * 10 + (i.bytes[k].to_int() - '0')
  }
  v
}

///|
/// `date_time`:
/// `date-time = offset-date-time / local-date-time / local-date / local-time`
fn date_time(i : Input) -> Datetime raise ErrMode {
  alt(i, [
    i => {
      context(
        i,
        i => {
          let date = full_date(i)
          let rest = opt(i, i => {
            ignore(time_delim(i))
            let time = partial_time(i)
            let offset = opt(i, time_offset)
            (time, offset)
          })
          match rest {
            Some((time, offset)) =>
              { date: Some(date), time: Some(time), offset, }
            None => { date: Some(date), time: None, offset: None, }
          }
        },
        [Label("date-time")],
      )
    },
    i => {
      context(
        i,
        i => { date: None, time: Some(partial_time(i)), offset: None, },
        [Label("time")],
      )
    },
  ])
}

///|
/// `full_date`: `full-date = date-fullyear "-" date-month "-" date-mday`
fn full_date(i : Input) -> Date raise ErrMode {
  let year = date_fullyear(i)
  byte(i, '-')
  let month = cut_err(i, date_month)
  cut_err(i, i => byte(i, '-'))
  let day_start = i.pos
  let day = cut_err(i, date_mday)
  let is_leap_year = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let max_days_in_month = match month {
    2 => if is_leap_year { 29 } else { 28 }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  if max_days_in_month < day {
    i.pos = day_start
    raise Cut(ContextError::external(out_of_range))
  }
  { year, month, day, }
}

///|
/// `partial_time`:
/// `partial-time = time-hour ":" time-minute ":" time-second [time-secfrac]`
fn partial_time(i : Input) -> Time raise ErrMode {
  let hour = time_hour(i)
  byte(i, ':')
  cut_err(i, i => {
    let minute = time_minute(i)
    byte(i, ':')
    let second = time_second(i)
    let nanosecond = opt(i, time_secfrac).unwrap_or(0)
    { hour, minute, second, nanosecond, }
  })
}

///|
/// `time_offset`: `time-offset = "Z" / time-numoffset`,
/// `time-numoffset = ( "+" / "-" ) time-hour ":" time-minute`
fn time_offset(i : Input) -> Offset raise ErrMode {
  context(
    i,
    i => {
      alt(i, [
        i => {
          ignore(one_of(i, b => b == 'Z' || b == 'z'))
          Z
        },
        i => {
          let start = i.pos
          let sign = one_of(i, b => b == '+' || b == '-')
          let (hours, minutes) = cut_err(i, i => {
            let h = time_hour(i)
            byte(i, ':')
            let m = time_minute(i)
            (h, m)
          })
          let sign = if sign == '+' { 1 } else { -1 }
          let minutes = sign * (hours * 60 + minutes)
          if minutes < -24 * 60 || minutes > 24 * 60 {
            raise map_failure(i, start, None)
          }
          Custom(minutes~)
        },
      ])
    },
    [Label("time offset")],
  )
}

///|
/// `date_fullyear`: `date-fullyear = 4DIGIT`
fn date_fullyear(i : Input) -> Int raise ErrMode {
  let start = unsigned_digits(i, 4, 4)
  digits_value(i, start, i.pos)
}

///|
/// A two-digit field with a range check (`date_month`, `date_mday`,
/// `time_hour`, `time_minute`, `time_second`).
fn ranged_2digit(i : Input, min : Int, max : Int) -> Int raise ErrMode {
  let start = unsigned_digits(i, 2, 2)
  let d = digits_value(i, start, i.pos)
  if d < min || d > max {
    raise map_failure(i, start, Some(out_of_range))
  }
  d
}

///|
/// `date-month = 2DIGIT ; 01-12`
fn date_month(i : Input) -> Int raise ErrMode {
  ranged_2digit(i, 1, 12)
}

///|
/// `date-mday = 2DIGIT ; 01-28, 01-29, 01-30, 01-31 based on month/year`
fn date_mday(i : Input) -> Int raise ErrMode {
  ranged_2digit(i, 1, 31)
}

///|
/// `time-delim = "T" / %x20 ; T, t, or space`
fn time_delim(i : Input) -> Int raise ErrMode {
  one_of(i, b => b == 'T' || b == 't' || b == ' ')
}

///|
/// `time-hour = 2DIGIT ; 00-23`
fn time_hour(i : Input) -> Int raise ErrMode {
  ranged_2digit(i, 0, 23)
}

///|
/// `time-minute = 2DIGIT ; 00-59`
fn time_minute(i : Input) -> Int raise ErrMode {
  ranged_2digit(i, 0, 59)
}

///|
/// `time-second = 2DIGIT ; 00-58, 00-59, 00-60 based on leap second rules`
fn time_second(i : Input) -> Int raise ErrMode {
  ranged_2digit(i, 0, 60)
}

///|
/// `time-secfrac = "." 1*DIGIT`; truncated to nanosecond precision.
fn time_secfrac(i : Input) -> Int raise ErrMode {
  byte(i, '.')
  let start = unsigned_digits(i, 1, 0x7FFF_FFFF)
  let max_digits = 9
  let end = if i.pos - start > max_digits { start + max_digits } else { i.pos }
  let v = digits_value(i, start, end)
  let num_digits = end - start
  let mut scale = 1
  for _ in num_digits..<9 {
    scale *= 10
  }
  v * scale
}

///|
/// `unsigned_digits::<MIN, MAX>`: returns the start of the digits.
fn unsigned_digits(i : Input, min : Int, max : Int) -> Int raise ErrMode {
  take_while_m_n(i, min, max, is_digit)
}
