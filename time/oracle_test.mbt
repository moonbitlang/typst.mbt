// Differential tests against the outputs of the Rust `time` crate (0.3.55),
// recorded in `oracle_data_test.mbt` by a small Rust harness. Regenerate with
//   cargo run --release --manifest-path time/oracle_harness/Cargo.toml \
//     > time/oracle_data_test.mbt

///|
fn padding_repr(p : @time.Padding) -> String {
  match p {
    Space => "Space"
    Zero => "Zero"
    None_ => "None"
  }
}

///|
fn digits_repr(d : @time.SubsecondDigits) -> String {
  match d {
    One => "One"
    Two => "Two"
    Three => "Three"
    Four => "Four"
    Five => "Five"
    Six => "Six"
    Seven => "Seven"
    Eight => "Eight"
    Nine => "Nine"
    OneOrMore => "OneOrMore"
  }
}

///|
/// Mirror Rust's `{:?}` of a `Component`.
fn component_repr(c : @time.Component) -> String {
  fn s(name : String, fields : Array[(String, String)]) -> String {
    let fs = fields.map(f => "\{f.0}: \{f.1}").join(", ")
    "\{name}(\{name} { \{fs} })"
  }

  match c {
    Day(padding~) => s("Day", [("padding", padding_repr(padding))])
    MonthShort(case_sensitive~) =>
      s("MonthShort", [("case_sensitive", case_sensitive.to_string())])
    MonthLong(case_sensitive~) =>
      s("MonthLong", [("case_sensitive", case_sensitive.to_string())])
    MonthNumerical(padding~) =>
      s("MonthNumerical", [("padding", padding_repr(padding))])
    Ordinal(padding~) => s("Ordinal", [("padding", padding_repr(padding))])
    WeekdayShort(case_sensitive~) =>
      s("WeekdayShort", [("case_sensitive", case_sensitive.to_string())])
    WeekdayLong(case_sensitive~) =>
      s("WeekdayLong", [("case_sensitive", case_sensitive.to_string())])
    WeekdaySunday(one_indexed~) =>
      s("WeekdaySunday", [("one_indexed", one_indexed.to_string())])
    WeekdayMonday(one_indexed~) =>
      s("WeekdayMonday", [("one_indexed", one_indexed.to_string())])
    WeekNumberIso(padding~) =>
      s("WeekNumberIso", [("padding", padding_repr(padding))])
    WeekNumberSunday(padding~) =>
      s("WeekNumberSunday", [("padding", padding_repr(padding))])
    WeekNumberMonday(padding~) =>
      s("WeekNumberMonday", [("padding", padding_repr(padding))])
    CalendarYearFullExtendedRange(padding~, sign_is_mandatory~) =>
      s("CalendarYearFullExtendedRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    CalendarYearFullStandardRange(padding~, sign_is_mandatory~) =>
      s("CalendarYearFullStandardRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    IsoYearFullExtendedRange(padding~, sign_is_mandatory~) =>
      s("IsoYearFullExtendedRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    IsoYearFullStandardRange(padding~, sign_is_mandatory~) =>
      s("IsoYearFullStandardRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    CalendarYearCenturyExtendedRange(padding~, sign_is_mandatory~) =>
      s("CalendarYearCenturyExtendedRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    CalendarYearCenturyStandardRange(padding~, sign_is_mandatory~) =>
      s("CalendarYearCenturyStandardRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    IsoYearCenturyExtendedRange(padding~, sign_is_mandatory~) =>
      s("IsoYearCenturyExtendedRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    IsoYearCenturyStandardRange(padding~, sign_is_mandatory~) =>
      s("IsoYearCenturyStandardRange", [
        ("padding", padding_repr(padding)),
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    CalendarYearLastTwo(padding~) =>
      s("CalendarYearLastTwo", [("padding", padding_repr(padding))])
    IsoYearLastTwo(padding~) =>
      s("IsoYearLastTwo", [("padding", padding_repr(padding))])
    Hour12(padding~) => s("Hour12", [("padding", padding_repr(padding))])
    Hour24(padding~) => s("Hour24", [("padding", padding_repr(padding))])
    Minute(padding~) => s("Minute", [("padding", padding_repr(padding))])
    Period(is_uppercase~, case_sensitive~) =>
      s("Period", [
        ("is_uppercase", is_uppercase.to_string()),
        ("case_sensitive", case_sensitive.to_string()),
      ])
    Second(padding~) => s("Second", [("padding", padding_repr(padding))])
    Subsecond(digits~) => s("Subsecond", [("digits", digits_repr(digits))])
    OffsetHour(sign_is_mandatory~, padding~) =>
      s("OffsetHour", [
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
        ("padding", padding_repr(padding)),
      ])
    OffsetMinute(padding~) =>
      s("OffsetMinute", [("padding", padding_repr(padding))])
    OffsetSecond(padding~) =>
      s("OffsetSecond", [("padding", padding_repr(padding))])
    Ignore(count~) => s("Ignore", [("count", count.to_string())])
    UnixTimestampSecond(sign_is_mandatory~) =>
      s("UnixTimestampSecond", [
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    UnixTimestampMillisecond(sign_is_mandatory~) =>
      s("UnixTimestampMillisecond", [
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    UnixTimestampMicrosecond(sign_is_mandatory~) =>
      s("UnixTimestampMicrosecond", [
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    UnixTimestampNanosecond(sign_is_mandatory~) =>
      s("UnixTimestampNanosecond", [
        ("sign_is_mandatory", sign_is_mandatory.to_string()),
      ])
    End(trailing_input~) =>
      s("End", [
        (
          "trailing_input",
          match trailing_input {
            Prohibit => "Prohibit"
            Discard => "Discard"
          },
        ),
      ])
  }
}

///|
fn item_repr(item : @time.FormatItem) -> String {
  match item {
    StringLiteral(s) => "L(\{s})"
    Component(c) => "C(\{component_repr(c)})"
    Compound(items) => "[\{items.map(item_repr).join(",")}]"
    Optional(item) => "O(\{item_repr(item)})"
    First(items) => "F[\{items.map(item_repr).join(",")}]"
  }
}

///|
fn oracle_dates_values() -> Array[@time.Date] {
  let d = (y, m, d) => {
    try! @time.Date::from_calendar_date(
      y,
      @time.Month::try_from_u8(m).unwrap(),
      d,
    )
  }
  [
    d(2023, 4, 29),
    d(2024, 2, 29),
    d(2021, 1, 1),
    d(2020, 12, 31),
    d(2027, 1, 3),
    d(1, 1, 1),
    d(0, 3, 5),
    d(-1, 6, 15),
    d(-50, 6, 15),
    d(-150, 6, 15),
    d(-9999, 1, 1),
    d(9999, 12, 31),
    d(905, 9, 7),
  ]
}

///|
fn oracle_times_values() -> Array[@time.Time] {
  [
    try! @time.Time::from_hms(14, 26, 50),
    try! @time.Time::from_hms(0, 0, 0),
    try! @time.Time::from_hms(12, 0, 5),
    try! @time.Time::from_hms(23, 59, 59),
    try! @time.Time::from_hms_nano(1, 2, 3, 456_000_000),
    try! @time.Time::from_hms_nano(9, 8, 7, 1),
    try! @time.Time::from_hms_nano(11, 59, 0, 120_000),
  ]
}

///|
fn[T : Show] opt_repr(x : T?) -> String {
  match x {
    Some(v) => "Some(\{v})"
    None => "None"
  }
}

///|
fn report(name : String, mismatches : Array[String]) -> Unit raise {
  if !mismatches.is_empty() {
    for i, m in mismatches {
      if i < 20 {
        println(m)
      }
    }
    fail("\{name}: \{mismatches.length()} mismatches")
  }
}

///|
test "oracle: format description parsing" {
  let mismatches = []
  for case in oracle_patterns {
    let (pattern, expected_borrowed, expected_owned) = case
    let borrowed = try @time.parse_borrowed_v2(pattern) catch {
      e => "err:\{e}"
    } noraise {
      items => "ok:[\{items.map(item_repr).join(",")}]"
    }
    if borrowed != expected_borrowed {
      mismatches.push(
        "borrowed \{pattern}\n  got:  \{borrowed}\n  want: \{expected_borrowed}",
      )
    }
    let owned = try @time.parse_owned_v2(pattern) catch {
      e => "err:\{e}"
    } noraise {
      item => "ok:\{item_repr(item)}"
    }
    if owned != expected_owned {
      mismatches.push(
        "owned \{pattern}\n  got:  \{owned}\n  want: \{expected_owned}",
      )
    }
  }
  report("parse", mismatches)
}

///|
fn show_format(f : () -> String raise @time.Format) -> String {
  try f() catch {
    e => "err:\{e}"
  } noraise {
    s => "ok:\{s}"
  }
}

///|
test "oracle: formatting" {
  let dates = oracle_dates_values()
  let times = oracle_times_values()
  let mismatches = []
  for case in oracle_formats {
    let (pattern, expected) = case
    let item = @time.parse_owned_v2(pattern)
    let got = []
    for date in dates {
      got.push(show_format(() => date.format_item(item)))
    }
    for time in times {
      got.push(show_format(() => time.format_item(item)))
    }
    for i, date in dates {
      let dt = @time.PrimitiveDateTime::new(date, times[i % times.length()])
      got.push(show_format(() => dt.format_item(item)))
    }
    for i, g in got {
      if g != expected[i] {
        mismatches.push(
          "format \{pattern} value=\{i}\n  got:  \{g}\n  want: \{expected[i]}",
        )
      }
    }
  }
  report("format", mismatches)
}

///|
test "oracle: dates" {
  let durs = [
    @time.Duration::days(1L),
    @time.Duration::days(-1L),
    @time.Duration::days(400L),
    @time.Duration::days(-4000L),
    @time.Duration::hours(25L),
    @time.Duration::new(-86_399L, -999_999_999),
    @time.Duration::weeks(10_000_000L),
  ]
  let mismatches = []
  for case in oracle_dates {
    let (jd, expected) = case
    let d = try! @time.Date::from_julian_day(jd)
    let parts = [
      d.year().to_string(),
      d.month().number().to_string(),
      d.day().to_string(),
      d.ordinal().to_string(),
      d.weekday().number_from_monday().to_string(),
      d.iso_week().to_string(),
      d.sunday_based_week().to_string(),
      d.monday_based_week().to_string(),
      d.to_julian_day().to_string(),
      d.to_string(),
      d.to_iso_week_date().0.to_string(),
      @time.weeks_in_year(d.year()).to_string(),
      opt_repr(d.next_day()),
      opt_repr(d.previous_day()),
    ]
    for du in durs {
      parts.push(opt_repr(d.checked_add(du)))
      parts.push(opt_repr(d.checked_sub(du)))
    }
    let got = parts.join("|")
    if got != expected {
      mismatches.push("date jd=\{jd}\n  got:  \{got}\n  want: \{expected}")
    }
  }
  report("dates", mismatches)
}

///|
test "oracle: calendar dates" {
  let mismatches = []
  for case in oracle_calendar {
    let (y, m, d, expected) = case
    let got = try
      @time.Date::from_calendar_date(y, @time.Month::try_from_u8(m).unwrap(), d)
    catch {
      e => "err:\{e}|\{e.is_conditional()}"
    } noraise {
      date => "ok:\{date}"
    }
    if got != expected {
      mismatches.push(
        "calendar \{y}-\{m}-\{d}\n  got:  \{got}\n  want: \{expected}",
      )
    }
  }
  report("calendar", mismatches)
}

///|
fn duration_debug(d : @time.Duration) -> String {
  "SignedDuration { seconds: \{d.whole_seconds()}, nanoseconds: \{d.subsec_nanoseconds()} }"
}

///|
test "oracle: seconds_f64" {
  let mismatches = []
  for case in oracle_f64 {
    let (bits, expected) = case
    let f = bits.reinterpret_as_double()
    let got = match @time.Duration::checked_seconds_f64(f) {
      Some(d) => "\{d.whole_seconds()}|\{d.subsec_nanoseconds()}|\{d}"
      None =>
        "none|\{duration_debug(@time.Duration::saturating_seconds_f64(f))}"
    }
    if got != expected {
      mismatches.push("f64 \{f}\n  got:  \{got}\n  want: \{expected}")
    }
  }
  report("f64", mismatches)
}

///|
test "oracle: time and datetime arithmetic" {
  let dates = oracle_dates_values()
  let times = oracle_times_values()
  let mismatches = []
  for case in oracle_arith {
    let (ti, di, secs, nanos, expected) = case
    let du = @time.Duration::new(secs, nanos)
    let t = times[ti]
    let dt = @time.PrimitiveDateTime::new(dates[di], t)
    let got = "\{t.add_duration(du)}|\{t.sub_duration(du)}|\{opt_repr(dt.checked_add(du))}|\{opt_repr(dt.checked_sub(du))}"
    if got != expected {
      mismatches.push(
        "arith t=\{ti} d=\{di} \{secs}s\{nanos}ns\n  got:  \{got}\n  want: \{expected}",
      )
    }
  }
  report("arith", mismatches)
}

///|
test "oracle: differences" {
  let dates = oracle_dates_values()
  let times = oracle_times_values()
  let n = times.length()
  let mismatches = []
  for case in oracle_diff {
    let (i, j, expected) = case
    let a = @time.PrimitiveDateTime::new(dates[i], times[i % n])
    let b = @time.PrimitiveDateTime::new(dates[j], times[j % n])
    let d = a.sub_date_time(b)
    let got = "\{dates[i].sub_date(dates[j])}|\{times[i % n].sub_time(times[j % n])}|\{d}|\{d.whole_weeks()}|\{times[i % n].duration_until(times[j % n])}"
    if got != expected {
      mismatches.push("diff \{i} \{j}\n  got:  \{got}\n  want: \{expected}")
    }
  }
  report("diff", mismatches)
}

///|
test "oracle: duration operations" {
  let mismatches = []
  for case in oracle_duration_ops {
    let (secs, nanos, f, expected) = case
    let d = @time.Duration::new(secs, nanos)
    let div = d.div_duration(@time.Duration::new(1L, 250_000_000))
    let parts = [
      d.to_string(),
      d.whole_weeks().to_string(),
      d.whole_days().to_string(),
      d.whole_hours().to_string(),
      d.whole_minutes().to_string(),
      d.whole_seconds().to_string(),
      d.subsec_nanoseconds().to_string(),
      d.as_seconds_f64().reinterpret_as_uint64().to_string(),
      d.mul_f64(f).to_string(),
      d.div_f64(f).to_string(),
      div.reinterpret_as_uint64().to_string(),
      (-d).to_string(),
      d.abs().to_string(),
    ]
    let got = parts.join("|")
    if got != expected {
      mismatches.push(
        "duration \{secs} \{nanos} \{f}\n  got:  \{got}\n  want: \{expected}",
      )
    }
  }
  report("duration", mismatches)
}
