///|
test "typst datetime display behaviours" {
  let date = @time.Date::from_calendar_date(2023, April, 29)
  let fd = @time.parse_owned_v2(
    "[year] [month repr:long] [day] [week_number] [weekday]",
  )
  inspect(date.format_item(fd), content="2023 April 29 17 Saturday")
  inspect(
    date.format(@time.parse_borrowed_v2("[year repr:last_two]")),
    content="23",
  )
  let time = @time.Time::from_hms(14, 26, 50)
  inspect(
    time.format(@time.parse_borrowed_v2("[hour repr:12 padding:none]")),
    content="2",
  )
  inspect(
    @time.PrimitiveDateTime::new(date, time).format(
      @time.parse_borrowed_v2("[year]-[month]-[day] [hour]:[minute]:[second]"),
    ),
    content="2023-04-29 14:26:50",
  )
  let hour = @time.parse_borrowed_v2("[hour]")
  try date.format(hour) catch {
    InsufficientTypeInformation as e =>
      inspect(
        e,
        content="The type being formatted does not contain sufficient information to format a component.",
      )
    e => fail("unexpected error \{e}")
  } noraise {
    _ => fail("expected to fail")
  }
}

///|
test "typst format description errors" {
  let check = (s : String) => {
    try @time.parse_owned_v2(s) catch {
      e => "\{e} / \{Repr(e)}"
    } noraise {
      _ => "ok"
    }
  }
  inspect(
    check("[year"),
    content="unclosed opening bracket at byte index 0 / UnclosedOpeningBracket(index=0)",
  )
  inspect(
    check("[nothing]"),
    content=(
      #|invalid component name `nothing` at byte index 1 / InvalidComponentName(name="nothing", index=1)
    ),
  )
  inspect(
    check("[year wrong:last_two]"),
    content=(
      #|invalid modifier `wrong` at byte index 6 / InvalidModifier(value="wrong", index=6)
    ),
  )
  inspect(
    check("  []"),
    content="missing component name at byte index 2 / MissingComponentName(index=2)",
  )
  inspect(
    check("[ignore]"),
    content=(
      #|missing required modifier `count` for component at byte index 1 / MissingRequiredModifier(name="count", index=1)
    ),
  )
  inspect(
    check("[optional format:false [x]]"),
    content=(
      #|optional item with `format:false` is not supported in v1 and v2 format descriptions at byte index 0 / NotSupported(
      #|  what="optional item with `format:false`",
      #|  context="v1 and v2 format descriptions",
      #|  index=0,
      #|)
    ),
  )
  inspect(check("[optional [[year]]]"), content="ok")
}

///|
test "durations" {
  let d = @time.Duration::seconds(5L) +
    @time.Duration::minutes(4L) +
    @time.Duration::hours(3L) +
    @time.Duration::days(2L) +
    @time.Duration::weeks(1L)
  inspect(d, content="9d3h4m5s")
  inspect(d.whole_weeks(), content="1")
  inspect(d.whole_days(), content="9")
  inspect(-d, content="-9d3h4m5s")
  inspect(d.mul_f64(0.5), content="4d13h32m2s500ms")
  inspect(
    d.div_duration(@time.Duration::days(1L)),
    content=(
      #|9.127835648148148
    ),
  )
  inspect(
    @time.Duration::seconds_f64(-1.5).subsec_nanoseconds(),
    content="-500000000",
  )
}

///|
test "date and time arithmetic" {
  let date = @time.Date::from_calendar_date(2024, February, 28)
  inspect(
    date.checked_add(@time.Duration::days(1L)).unwrap(),
    content="2024-02-29",
  )
  inspect(date.weekday(), content="Wednesday")
  inspect(date.ordinal(), content="59")
  let dt = date.midnight().add_duration(@time.Duration::hours(-1L))
  inspect(dt, content="2024-02-27 23:00:00.0")
  inspect(dt.time() == @time.Time::midnight(), content="false")
  let t = @time.Time::from_hms(23, 30, 0).add_duration(
    @time.Duration::hours(1L),
  )
  inspect(t, content="0:30:00.0")
  inspect(
    @time.Date::from_calendar_date(2024, March, 1).sub_date(date),
    content="2d",
  )
  inspect(@time.Month::try_from_u8(13) is None, content="true")
  inspect(@time.Month::try_from_u8(12).unwrap(), content="December")
  try @time.Date::from_calendar_date(2023, February, 29) catch {
    e => inspect(e, content="day was not in range")
  } noraise {
    _ => fail("expected to fail")
  }
  try @time.Time::from_hms(24, 0, 0) catch {
    e => inspect(e, content="hour was not in range")
  } noraise {
    _ => fail("expected to fail")
  }
}
