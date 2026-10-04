// Port of `time/src/formatting/{mod,formattable,component_provider}.rs`.

///|
let month_names : ReadOnlyArray[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
let weekday_names : ReadOnlyArray[String] = [
  "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
]

///|
/// A value that can supply components for formatting (`ComponentProvider`).
priv enum Provider {
  /// `Date`: supplies date components.
  ProvideDate(Date)
  /// `Time`: supplies time components.
  ProvideTime(Time)
  /// `PrimitiveDateTime`: supplies date and time components.
  ProvideDateTime(Date, Time)
}

///|
fn Provider::date(self : Provider) -> Date? {
  match self {
    ProvideDate(date) | ProvideDateTime(date, _) => Some(date)
    ProvideTime(_) => None
  }
}

///|
fn Provider::time(self : Provider) -> Time? {
  match self {
    ProvideTime(time) | ProvideDateTime(_, time) => Some(time)
    ProvideDate(_) => None
  }
}

///|
fn format_two_digits(
  output : StringBuilder,
  value : Int,
  padding : Padding,
) -> Unit {
  output.write_string(
    match padding {
      Space => pad_left(value, 2, ' ')
      Zero => pad_left(value, 2, '0')
      None_ => value.to_string()
    },
  )
}

///|
fn format_three_digits(
  output : StringBuilder,
  value : Int,
  padding : Padding,
) -> Unit {
  output.write_string(
    match padding {
      Space => pad_left(value, 3, ' ')
      Zero => pad_left(value, 3, '0')
      None_ => value.to_string()
    },
  )
}

///|
fn format_four_digits(
  output : StringBuilder,
  value : Int,
  padding : Padding,
) -> Unit {
  output.write_string(
    match padding {
      Space => pad_left(value, 4, ' ')
      Zero => pad_left(value, 4, '0')
      None_ => value.to_string()
    },
  )
}

///|
fn fmt_sign(
  output : StringBuilder,
  is_negative : Bool,
  sign_is_mandatory : Bool,
) -> Unit {
  if is_negative {
    output.write_string("-")
  } else if sign_is_mandatory {
    output.write_string("+")
  }
}

///|
fn fmt_year_full_extended_range(
  output : StringBuilder,
  full_year : Int,
  padding : Padding,
  sign_is_mandatory : Bool,
) -> Unit {
  fmt_sign(output, full_year < 0, sign_is_mandatory || full_year >= 10_000)
  let value = full_year.abs()
  if value <= 9_999 {
    format_four_digits(output, value, padding)
  } else if value <= 99_999 {
    output.write_string(zero_pad(value, 5))
  } else {
    output.write_string(zero_pad(value, 6))
  }
}

///|
fn fmt_year_full_standard_range(
  output : StringBuilder,
  full_year : Int,
  padding : Padding,
  sign_is_mandatory : Bool,
) -> Unit raise Format {
  if full_year < -9_999 || full_year > 9_999 {
    raise ComponentRange(ComponentRange::conditional("year"))
  }
  fmt_sign(output, full_year < 0, sign_is_mandatory)
  format_four_digits(output, full_year.abs(), padding)
}

///|
fn fmt_year_century_extended_range(
  output : StringBuilder,
  year : Int,
  padding : Padding,
  sign_is_mandatory : Bool,
) -> Unit {
  let century = year / 100
  fmt_sign(output, year < 0, sign_is_mandatory || century >= 100)
  let century = century.abs()
  if century <= 99 {
    format_two_digits(output, century, padding)
  } else if century <= 999 {
    format_three_digits(output, century, padding)
  } else {
    format_four_digits(output, century, padding)
  }
}

///|
fn fmt_year_century_standard_range(
  output : StringBuilder,
  year : Int,
  padding : Padding,
  sign_is_mandatory : Bool,
) -> Unit raise Format {
  let is_negative = year < 0
  let century = year / 100
  if century < -99 || century > 99 {
    raise ComponentRange(ComponentRange::conditional("year"))
  }
  fmt_sign(output, is_negative, sign_is_mandatory)
  format_two_digits(output, century.abs(), padding)
}

///|
fn fmt_subsecond(
  output : StringBuilder,
  nanos : Int,
  digits : SubsecondDigits,
) -> Unit {
  let s = subsecond_from_nanos(nanos)
  let len = match digits {
    One => 1
    Two => 2
    Three => 3
    Four => 4
    Five => 5
    Six => 6
    Seven => 7
    Eight => 8
    Nine => 9
    OneOrMore => subsecond_significant_len(s)
  }
  output.write_string(s.view(end_offset=len).to_owned())
}

///|
/// Format a single component (`Component::format_into`).
fn Component::format_into(
  self : Component,
  output : StringBuilder,
  value : Provider,
) -> Unit raise Format {
  match self {
    Ignore(_) => return
    End(_) => return
    _ => ()
  }
  if value.date() is Some(date) {
    match self {
      Day(padding~) => return format_two_digits(output, date.day(), padding)
      MonthShort(_) =>
        return output.write_string(
          date.month().name().view(end_offset=3).to_owned(),
        )
      MonthLong(_) => return output.write_string(date.month().name())
      MonthNumerical(padding~) =>
        return format_two_digits(output, date.month().number(), padding)
      Ordinal(padding~) =>
        return format_three_digits(output, date.ordinal(), padding)
      WeekdayShort(_) =>
        return output.write_string(
          date.weekday().name().view(end_offset=3).to_owned(),
        )
      WeekdayLong(_) => return output.write_string(date.weekday().name())
      WeekdaySunday(one_indexed~) =>
        return output.write_string(
          (date.weekday().number_days_from_sunday() +
          (if one_indexed { 1 } else { 0 })).to_string(),
        )
      WeekdayMonday(one_indexed~) =>
        return output.write_string(
          (date.weekday().number_days_from_monday() +
          (if one_indexed { 1 } else { 0 })).to_string(),
        )
      WeekNumberIso(padding~) =>
        return format_two_digits(output, date.iso_week(), padding)
      WeekNumberSunday(padding~) =>
        return format_two_digits(output, date.sunday_based_week(), padding)
      WeekNumberMonday(padding~) =>
        return format_two_digits(output, date.monday_based_week(), padding)
      CalendarYearFullExtendedRange(padding~, sign_is_mandatory~) =>
        return fmt_year_full_extended_range(
          output,
          date.year(),
          padding,
          sign_is_mandatory,
        )
      CalendarYearFullStandardRange(padding~, sign_is_mandatory~) =>
        return fmt_year_full_standard_range(
          output,
          date.year(),
          padding,
          sign_is_mandatory,
        )
      IsoYearFullExtendedRange(padding~, sign_is_mandatory~) =>
        return fmt_year_full_extended_range(
          output,
          date.iso_year_week().0,
          padding,
          sign_is_mandatory,
        )
      IsoYearFullStandardRange(padding~, sign_is_mandatory~) =>
        return fmt_year_full_standard_range(
          output,
          date.iso_year_week().0,
          padding,
          sign_is_mandatory,
        )
      CalendarYearCenturyExtendedRange(padding~, sign_is_mandatory~) =>
        return fmt_year_century_extended_range(
          output,
          date.year(),
          padding,
          sign_is_mandatory,
        )
      CalendarYearCenturyStandardRange(padding~, sign_is_mandatory~) =>
        return fmt_year_century_standard_range(
          output,
          date.year(),
          padding,
          sign_is_mandatory,
        )
      IsoYearCenturyExtendedRange(padding~, sign_is_mandatory~) =>
        return fmt_year_century_extended_range(
          output,
          date.iso_year_week().0,
          padding,
          sign_is_mandatory,
        )
      IsoYearCenturyStandardRange(padding~, sign_is_mandatory~) =>
        return fmt_year_century_standard_range(
          output,
          date.iso_year_week().0,
          padding,
          sign_is_mandatory,
        )
      CalendarYearLastTwo(padding~) =>
        return format_two_digits(output, date.year().abs() % 100, padding)
      IsoYearLastTwo(padding~) =>
        return format_two_digits(
          output,
          date.iso_year_week().0.abs() % 100,
          padding,
        )
      _ => ()
    }
  }
  if value.time() is Some(time) {
    match self {
      Hour12(padding~) =>
        return format_two_digits(output, (time.hour() + 11) % 12 + 1, padding)
      Hour24(padding~) => return format_two_digits(output, time.hour(), padding)
      Minute(padding~) =>
        return format_two_digits(output, time.minute(), padding)
      Period(is_uppercase~, ..) =>
        return output.write_string(
          match (time.hour() < 12, is_uppercase) {
            (true, false) => "am"
            (true, true) => "AM"
            (false, false) => "pm"
            (false, true) => "PM"
          },
        )
      Second(padding~) =>
        return format_two_digits(output, time.second(), padding)
      Subsecond(digits~) =>
        return fmt_subsecond(output, time.nanosecond(), digits)
      _ => ()
    }
  }
  // None of `Date`, `Time` and `PrimitiveDateTime` supply offset or timestamp
  // components.
  raise InsufficientTypeInformation
}

///|
/// Format a format item (`Sealed::format_into` for `OwnedFormatItem`).
fn FormatItem::format_into(
  self : FormatItem,
  output : StringBuilder,
  value : Provider,
) -> Unit raise Format {
  match self {
    StringLiteral(literal) => output.write_string(literal)
    Component(component) => component.format_into(output, value)
    Compound(items) => format_items_into(items, output, value)
    Optional(item) => item.format_into(output, value)
    First(items) =>
      match items {
        [] => ()
        [item, ..] => item.format_into(output, value)
      }
  }
}

///|
fn format_items_into(
  items : ArrayView[FormatItem],
  output : StringBuilder,
  value : Provider,
) -> Unit raise Format {
  for item in items {
    item.format_into(output, value)
  }
}

///|
fn format_items(
  items : ArrayView[FormatItem],
  value : Provider,
) -> String raise Format {
  let output = StringBuilder()
  format_items_into(items, output, value)
  output.to_string()
}

///|
/// Format the `Date` using the provided format description (a sequence of
/// items, as returned by `parse_borrowed_v2`).
pub fn Date::format(
  self : Date,
  format : ArrayView[FormatItem],
) -> String raise Format {
  format_items(format, ProvideDate(self))
}

///|
/// Format the `Date` using the provided format item (as returned by
/// `parse_owned_v2`).
pub fn Date::format_item(
  self : Date,
  format : FormatItem,
) -> String raise Format {
  format_items([format], ProvideDate(self))
}

///|
/// Format the `Time` using the provided format description.
pub fn Time::format(
  self : Time,
  format : ArrayView[FormatItem],
) -> String raise Format {
  format_items(format, ProvideTime(self))
}

///|
/// Format the `Time` using the provided format item.
pub fn Time::format_item(
  self : Time,
  format : FormatItem,
) -> String raise Format {
  format_items([format], ProvideTime(self))
}

///|
/// Format the `PrimitiveDateTime` using the provided format description.
pub fn PrimitiveDateTime::format(
  self : PrimitiveDateTime,
  format : ArrayView[FormatItem],
) -> String raise Format {
  format_items(format, ProvideDateTime(self.date, self.time))
}

///|
/// Format the `PrimitiveDateTime` using the provided format item.
pub fn PrimitiveDateTime::format_item(
  self : PrimitiveDateTime,
  format : FormatItem,
) -> String raise Format {
  format_items([format], ProvideDateTime(self.date, self.time))
}
