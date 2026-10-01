// Port of `typst-library/src/foundations/datetime.rs`.

///|
/// Represents a date, a time, or a combination of both.
///
/// Can be created by either specifying a custom datetime using this type's
/// constructor function or getting the current date with `datetime.today`.
pub(all) enum Datetime {
  /// Representation as a date.
  Date(@time.Date)
  /// Representation as a time.
  Time(@time.Time)
  /// Representation as a combination of date and time.
  Datetime(@time.PrimitiveDateTime)
} derive(Eq, Hash)

///|
/// Create a datetime from year, month, and day.
pub fn Datetime::from_ymd(year : Int, month : Int, day : Int) -> Datetime? {
  guard @time.Month::try_from_u8(month) is Some(month) else { return None }
  let date = @time.Date::from_calendar_date(year, month, day) catch {
    _ => return None
  }
  Some(Date(date))
}

///|
/// Create a datetime from hour, minute, and second.
pub fn Datetime::from_hms(hour : Int, minute : Int, second : Int) -> Datetime? {
  let time = @time.Time::from_hms(hour, minute, second) catch {
    _ => return None
  }
  Some(Time(time))
}

///|
/// Create a datetime from day and time.
pub fn Datetime::from_ymd_hms(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> Datetime? {
  guard @time.Month::try_from_u8(month) is Some(month) else { return None }
  let date = @time.Date::from_calendar_date(year, month, day) catch {
    _ => return None
  }
  let time = @time.Time::from_hms(hour, minute, second) catch {
    _ => return None
  }
  Some(Datetime(@time.PrimitiveDateTime::new(date, time)))
}

///|
/// Try to parse a dictionary as a TOML date.
pub fn Datetime::from_toml_dict(dict : Dict) -> Datetime? {
  if dict.len() != 1 {
    return None
  }
  guard dict.map.get("$__toml_private_datetime") is Some(Str(string)) else {
    return None
  }
  match toml_parse_datetime(string, true, true) {
    Some((y, mo, d, h, mi, s)) =>
      return Datetime::from_ymd_hms(y, mo, d, h, mi, s)
    None => ()
  }
  match toml_parse_datetime(string, true, false) {
    Some((y, mo, d, h, mi, s)) =>
      return Datetime::from_ymd_hms(y, mo, d, h, mi, s)
    None => ()
  }
  match toml_parse_date(string, 0) {
    Some(((y, mo, d), end)) if end == string.length() =>
      return Datetime::from_ymd(y, mo, d)
    _ => ()
  }
  match toml_parse_time(string, 0) {
    Some(((h, mi, s), end)) if end == string.length() =>
      return Datetime::from_hms(h, mi, s)
    _ => ()
  }
  None
}

///|
/// Parses `[year]-[month]-[day]T[hour]:[minute]:[second]` (optionally
/// followed by `Z`) like `time`'s parser with these format descriptions.
fn toml_parse_datetime(
  s : String,
  _with_t : Bool,
  with_z : Bool,
) -> (Int, Int, Int, Int, Int, Int)? {
  guard toml_parse_date(s, 0) is Some(((y, mo, d), i)) else { return None }
  guard i < s.length() && s.code_unit_at(i).to_int() == 'T'.to_int() else {
    return None
  }
  guard toml_parse_time(s, i + 1) is Some(((h, mi, sec), i)) else {
    return None
  }
  let i = if with_z {
    guard i < s.length() && s.code_unit_at(i).to_int() == 'Z'.to_int() else {
      return None
    }
    i + 1
  } else {
    i
  }
  if i != s.length() {
    return None
  }
  // The components must also form a valid date and time.
  guard @time.Month::try_from_u8(mo) is Some(month) else { return None }
  let _ = @time.Date::from_calendar_date(y, month, d) catch { _ => return None }
  let _ = @time.Time::from_hms(h, mi, sec) catch { _ => return None }
  Some((y, mo, d, h, mi, sec))
}

///|
/// Parses `n` ASCII digits starting at `i`.
fn toml_digits(s : String, i : Int, n : Int) -> Int? {
  if i + n > s.length() {
    return None
  }
  let mut v = 0
  for j in i..<(i + n) {
    let c = s.code_unit_at(j).to_int()
    if c < '0'.to_int() || c > '9'.to_int() {
      return None
    }
    v = v * 10 + (c - '0'.to_int())
  }
  Some(v)
}

///|
/// Parses `[year]-[month]-[day]` (a four digit year with optional sign, a
/// two digit month and day), returning the end index.
fn toml_parse_date(s : String, start : Int) -> ((Int, Int, Int), Int)? {
  let mut i = start
  let mut sign = 1
  if i < s.length() {
    let c = s.code_unit_at(i).to_int()
    if c == '-'.to_int() {
      sign = -1
      i += 1
    } else if c == '+'.to_int() {
      i += 1
    }
  }
  guard toml_digits(s, i, 4) is Some(year) else { return None }
  i += 4
  guard i < s.length() && s.code_unit_at(i).to_int() == '-'.to_int() else {
    return None
  }
  guard toml_digits(s, i + 1, 2) is Some(month) else { return None }
  i += 3
  guard i < s.length() && s.code_unit_at(i).to_int() == '-'.to_int() else {
    return None
  }
  guard toml_digits(s, i + 1, 2) is Some(day) else { return None }
  i += 3
  guard @time.Month::try_from_u8(month) is Some(m) else { return None }
  let _ = @time.Date::from_calendar_date(sign * year, m, day) catch {
    _ => return None
  }
  Some(((sign * year, month, day), i))
}

///|
/// Parses `[hour]:[minute]:[second]` (two digits each), returning the end
/// index.
fn toml_parse_time(s : String, start : Int) -> ((Int, Int, Int), Int)? {
  let mut i = start
  guard toml_digits(s, i, 2) is Some(hour) else { return None }
  i += 2
  guard i < s.length() && s.code_unit_at(i).to_int() == ':'.to_int() else {
    return None
  }
  guard toml_digits(s, i + 1, 2) is Some(minute) else { return None }
  i += 3
  guard i < s.length() && s.code_unit_at(i).to_int() == ':'.to_int() else {
    return None
  }
  guard toml_digits(s, i + 1, 2) is Some(second) else { return None }
  i += 3
  let _ = @time.Time::from_hms(hour, minute, second) catch { _ => return None }
  Some(((hour, minute, second), i))
}

///|
/// Which kind of variant this datetime stores.
pub fn Datetime::kind(self : Datetime) -> String {
  match self {
    Datetime(_) => "datetime"
    Date(_) => "date"
    Time(_) => "time"
  }
}

///|
/// Creates a new datetime (upstream `Datetime::construct`).
///
/// You can specify the datetime using a year, month, day, hour, minute, and
/// second.
fn impl_datetime_construct(
  year_ : I32?,
  month_ : @time.Month?,
  day_ : U8?,
  hour_ : U8?,
  minute_ : U8?,
  second_ : U8?,
) -> Datetime raise HintedError {
  fn format_missing_args(args : Array[String]) -> String {
    match args {
      [] => abort("unreachable")
      [arg] => "the \{arg} argument"
      [arg1, arg2] => "the \{arg1} and \{arg2} arguments"
      [.. args, tail] => "the \{args.join(", ")}, and \{tail} arguments"
    }
  }

  let time = match (hour_, minute_, second_) {
    (Some(hour), Some(minute), Some(second)) =>
      Some(
        @time.Time::from_hms(
          hour.0.to_int(),
          minute.0.to_int(),
          second.0.to_int(),
        ) catch {
          _ => bail("time is invalid")
        },
      )
    (None, None, None) => None
    (hour, minute, second) => {
      let args = []
      if hour is None {
        args.push("`hour`")
      }
      if minute is None {
        args.push("`minute`")
      }
      if second is None {
        args.push("`second`")
      }
      bail_hinted("time is incomplete", [
        "add \{format_missing_args(args)} to get a valid time",
      ])
    }
  }
  let date = match (year_, month_, day_) {
    (Some(year), Some(month), Some(day)) =>
      Some(
        @time.Date::from_calendar_date(year.0.to_int(), month, day.0.to_int()) catch {
          _ => bail("date is invalid")
        },
      )
    (None, None, None) => None
    (year, month, day) => {
      let args = []
      if year is None {
        args.push("`year`")
      }
      if month is None {
        args.push("`month`")
      }
      if day is None {
        args.push("`day`")
      }
      bail_hinted("date is incomplete", [
        "add \{format_missing_args(args)} to get a valid date",
      ])
    }
  }
  match (date, time) {
    (Some(date), Some(time)) =>
      Datetime(@time.PrimitiveDateTime::new(date, time))
    (Some(date), None) => Date(date)
    (None, Some(time)) => Time(time)
    (None, None) =>
      bail_hinted("at least one of date or time must be fully specified", [
        "add the `hour`, `minute`, and `second` arguments to get a valid time", "add the `year`, `month`, and `day` arguments to get a valid date",
      ])
  }
}

///|
/// Returns the current date (upstream `Datetime::today`).
fn impl_datetime_today(
  engine : Engine,
  offset_ : SmartTodayOffset,
) -> Datetime raise HintedError {
  let offset : Duration? = match offset_ {
    Auto => None
    Custom(v) => Some(v.0)
  }
  match engine.world.today(offset) {
    Some(d) => d
    None => bail("unable to get the current date")
  }
}

///|
fn impl_datetime_today__offset_default() -> SmartTodayOffset raise SourceError {
  Auto
}

///|
/// Displays the datetime in a specified format (upstream
/// `Datetime::display`).
fn impl_datetime_display(
  self_ : Datetime,
  pattern_ : SmartDisplayPattern,
) -> String raise HintedError {
  let pat = (s : String) => {
    @time.parse_borrowed_v2(s) catch {
      _ => abort("invalid built-in format description")
    }
  }
  try {
    match pattern_ {
      Auto =>
        match self_ {
          Date(date) => date.format(pat("[year]-[month]-[day]"))
          Time(time) => time.format(pat("[hour]:[minute]:[second]"))
          Datetime(datetime) =>
            datetime.format(
              pat("[year]-[month]-[day] [hour]:[minute]:[second]"),
            )
        }
      Custom(DisplayPattern(_, format)) =>
        match self_ {
          Date(date) => date.format_item(format)
          Time(time) => time.format_item(format)
          Datetime(datetime) => datetime.format_item(format)
        }
    }
  } catch {
    err => bail(format_time_format_error(err))
  }
}

///|
fn impl_datetime_display__pattern_default() -> SmartDisplayPattern raise SourceError {
  Auto
}

///|
/// The year if it was specified, or `{none}` for times without a date.
pub fn Datetime::year(self : Datetime) -> Int? {
  match self {
    Date(date) => Some(date.year())
    Time(_) => None
    Datetime(datetime) => Some(datetime.year())
  }
}

///|
/// The month if it was specified, or `{none}` for times without a date.
pub fn Datetime::month(self : Datetime) -> Int? {
  match self {
    Date(date) => Some(date.month().number())
    Time(_) => None
    Datetime(datetime) => Some(datetime.month().number())
  }
}

///|
/// The weekday (counting Monday as 1) or `{none}` for times without a date.
pub fn Datetime::weekday(self : Datetime) -> Int? {
  match self {
    Date(date) => Some(date.weekday().number_from_monday())
    Time(_) => None
    Datetime(datetime) => Some(datetime.weekday().number_from_monday())
  }
}

///|
/// The day if it was specified, or `{none}` for times without a date.
pub fn Datetime::day(self : Datetime) -> Int? {
  match self {
    Date(date) => Some(date.day())
    Time(_) => None
    Datetime(datetime) => Some(datetime.day())
  }
}

///|
/// The hour if it was specified, or `{none}` for dates without a time.
pub fn Datetime::hour(self : Datetime) -> Int? {
  match self {
    Date(_) => None
    Time(time) => Some(time.hour())
    Datetime(datetime) => Some(datetime.hour())
  }
}

///|
/// The minute if it was specified, or `{none}` for dates without a time.
pub fn Datetime::minute(self : Datetime) -> Int? {
  match self {
    Date(_) => None
    Time(time) => Some(time.minute())
    Datetime(datetime) => Some(datetime.minute())
  }
}

///|
/// The second if it was specified, or `{none}` for dates without a time.
pub fn Datetime::second(self : Datetime) -> Int? {
  match self {
    Date(_) => None
    Time(time) => Some(time.second())
    Datetime(datetime) => Some(datetime.second())
  }
}

///|
/// The ordinal (day of the year), or `{none}` for times without a date.
pub fn Datetime::ordinal(self : Datetime) -> Int? {
  match self {
    Datetime(datetime) => Some(datetime.ordinal())
    Date(date) => Some(date.ordinal())
    Time(_) => None
  }
}

///|
fn impl_datetime_year(self_ : Datetime) -> I32? raise HintedError {
  self_.year().map(v => I32(v.to_int64()))
}

///|
fn impl_datetime_month(self_ : Datetime) -> U8? raise HintedError {
  self_.month().map(v => U8(v.to_int64()))
}

///|
fn impl_datetime_weekday(self_ : Datetime) -> U8? raise HintedError {
  self_.weekday().map(v => U8(v.to_int64()))
}

///|
fn impl_datetime_day(self_ : Datetime) -> U8? raise HintedError {
  self_.day().map(v => U8(v.to_int64()))
}

///|
fn impl_datetime_hour(self_ : Datetime) -> U8? raise HintedError {
  self_.hour().map(v => U8(v.to_int64()))
}

///|
fn impl_datetime_minute(self_ : Datetime) -> U8? raise HintedError {
  self_.minute().map(v => U8(v.to_int64()))
}

///|
fn impl_datetime_second(self_ : Datetime) -> U8? raise HintedError {
  self_.second().map(v => U8(v.to_int64()))
}

///|
fn impl_datetime_ordinal(self_ : Datetime) -> U16? raise HintedError {
  self_.ordinal().map(v => U16(v.to_int64()))
}

///|
/// Upstream `Repr for Datetime`.
pub fn Datetime::repr(self : Datetime) -> String {
  let filtered = []
  let push = (name : String, v : Int?) => {
    if v is Some(v) {
      filtered.push("\{name}: \{repr_int(v.to_int64())}")
    }
  }
  push("year", self.year())
  push("month", self.month())
  push("day", self.day())
  push("hour", self.hour())
  push("minute", self.minute())
  push("second", self.second())
  "datetime" + pretty_array_like(filtered, false)
}

///|
/// Upstream `PartialOrd for Datetime`: only datetimes of the same kind can be
/// compared.
pub fn Datetime::partial_cmp(self : Datetime, other : Datetime) -> Int? {
  match (self, other) {
    (Datetime(a), Datetime(b)) => Some(a.compare(b))
    (Date(a), Date(b)) => Some(a.compare(b))
    (Time(a), Time(b)) => Some(a.compare(b))
    _ => None
  }
}

///|
/// Upstream `Add<Duration> for Datetime`.
pub fn Datetime::add_duration(self : Datetime, rhs : Duration) -> Datetime {
  let rhs = rhs.0
  match self {
    Datetime(datetime) => Datetime(datetime.add_duration(rhs))
    Date(date) => {
      let dt = @time.PrimitiveDateTime::new(date, @time.Time::midnight()).add_duration(
        rhs,
      )
      if dt.time() == @time.Time::midnight() {
        Date(dt.date())
      } else {
        Datetime(dt)
      }
    }
    Time(time) => Time(time.add_duration(rhs))
  }
}

///|
/// Upstream `Sub<Duration> for Datetime`.
pub fn Datetime::sub_duration(self : Datetime, rhs : Duration) -> Datetime {
  let rhs = rhs.0
  match self {
    Datetime(datetime) => Datetime(datetime.sub_duration(rhs))
    Date(date) => {
      let dt = @time.PrimitiveDateTime::new(date, @time.Time::midnight()).sub_duration(
        rhs,
      )
      if dt.time() == @time.Time::midnight() {
        Date(dt.date())
      } else {
        Datetime(dt)
      }
    }
    Time(time) => Time(time.sub_duration(rhs))
  }
}

///|
/// Upstream `Sub for Datetime`.
pub fn Datetime::sub_datetime(
  self : Datetime,
  rhs : Datetime,
) -> Duration raise HintedError {
  match (self, rhs) {
    (Datetime(a), Datetime(b)) => Duration(a.sub_date_time(b))
    (Date(a), Date(b)) => Duration(a.sub_date(b))
    (Time(a), Time(b)) => Duration(a.sub_time(b))
    (a, b) => bail("cannot subtract \{b.kind()} from \{a.kind()}")
  }
}

///|
/// A format description for displaying datetimes, together with its source
/// string.
pub struct DisplayPattern(String, @time.FormatItem)

///|
pub impl Reflect for DisplayPattern with fn input() {
  Type(Type::str())
}

///|
pub impl Reflect for DisplayPattern with fn output() {
  Type(Type::str())
}

///|
pub impl Reflect for DisplayPattern with fn castable(v) {
  v is (Str(_) | Symbol(_))
}

///|
pub impl IntoValue for DisplayPattern with fn into_value(self) {
  Str(self.0)
}

///|
pub impl FromValue for DisplayPattern with fn from_value(v) {
  let v : String = v.cast()
  let item = @time.parse_owned_v2(v) catch {
    err => bail(format_time_invalid_format_description_error(err))
  }
  DisplayPattern(v, item)
}

///|
/// `Smart<DisplayPattern>`.
pub(all) enum SmartDisplayPattern {
  Auto
  Custom(DisplayPattern)
}

///|
pub impl Reflect for SmartDisplayPattern with fn input() {
  DisplayPattern::input().union_with(Type(Type::auto()))
}

///|
pub impl Reflect for SmartDisplayPattern with fn output() {
  DisplayPattern::output().union_with(Type(Type::auto()))
}

///|
pub impl Reflect for SmartDisplayPattern with fn castable(v) {
  v is Auto || DisplayPattern::castable(v)
}

///|
pub impl IntoValue for SmartDisplayPattern with fn into_value(self) {
  match self {
    Auto => Auto
    Custom(v) => v.into_value()
  }
}

///|
pub impl FromValue for SmartDisplayPattern with fn from_value(v) {
  match v {
    Auto => Auto
    v if DisplayPattern::castable(v) => Custom(DisplayPattern::from_value(v))
    v => raise HintedError(SmartDisplayPattern::input().error(v))
  }
}

///|
/// Upstream `cast! { Month, v: u8 => .. }`.
pub impl Reflect for @time.Month with fn input() {
  U8::input()
}

///|
pub impl Reflect for @time.Month with fn output() {
  U8::output()
}

///|
pub impl Reflect for @time.Month with fn castable(v) {
  U8::castable(v)
}

///|
pub impl FromValue for @time.Month with fn from_value(v) {
  let v : U8 = v.cast()
  match @time.Month::try_from_u8(v.0.to_int()) {
    Some(m) => m
    None => bail("month is invalid")
  }
}

///|
pub impl IntoValue for @time.Month with fn into_value(self) {
  Int(self.number().to_int64())
}

///|
/// Formats a `time` formatting error.
fn format_time_format_error(error : @time.Format) -> String {
  match error {
    InvalidComponent(name) => "invalid component '\{name}'"
    InsufficientTypeInformation =>
      "failed to format datetime (insufficient information)"
    err => "failed to format datetime in the requested format (\{err})"
  }
}

///|
/// Formats an error in a `time` format description.
fn format_time_invalid_format_description_error(
  error : @time.InvalidFormatDescription,
) -> String {
  match error {
    UnclosedOpeningBracket(index~) =>
      "missing closing bracket for bracket at index \{index}"
    InvalidComponentName(name~, index~) =>
      "invalid component name '\{name}' at index \{index}"
    InvalidModifier(value~, index~) =>
      "invalid modifier '\{value}' at index \{index}"
    Expected(what~, index~) => "expected \{what} at index \{index}"
    MissingComponentName(index~) => "expected component name at index \{index}"
    MissingRequiredModifier(name~, index~) =>
      "missing required modifier \{name} for component at index \{index}"
    NotSupported(context~, what~, index~) =>
      "\{what} is not supported in \{context} at index \{index}"
    err => "failed to parse datetime format (\{err})"
  }
}

///|
/// A UTC offset for `datetime.today`: a duration or a number of hours.
pub struct TodayOffset(Duration)

///|
pub impl Reflect for TodayOffset with fn input() {
  CastInfo::Type(Type::duration()).union_with(CastInfo::Type(Type::int()))
}

///|
pub impl Reflect for TodayOffset with fn output() {
  CastInfo::Type(Type::duration()).union_with(CastInfo::Type(Type::int()))
}

///|
pub impl Reflect for TodayOffset with fn castable(v) {
  v is (Duration(_) | Int(_))
}

///|
pub impl IntoValue for TodayOffset with fn into_value(self) {
  Duration(self.0)
}

///|
pub impl FromValue for TodayOffset with fn from_value(v) {
  match v {
    Duration(d) => TodayOffset(d)
    Int(hours) => TodayOffset(Duration(@time.Duration::hours(hours)))
    v => raise HintedError(TodayOffset::input().error(v))
  }
}

///|
/// `Smart<TodayOffset>`.
pub(all) enum SmartTodayOffset {
  Auto
  Custom(TodayOffset)
}

///|
pub impl Reflect for SmartTodayOffset with fn input() {
  TodayOffset::input().union_with(Type(Type::auto()))
}

///|
pub impl Reflect for SmartTodayOffset with fn output() {
  TodayOffset::output().union_with(Type(Type::auto()))
}

///|
pub impl Reflect for SmartTodayOffset with fn castable(v) {
  v is Auto || TodayOffset::castable(v)
}

///|
pub impl IntoValue for SmartTodayOffset with fn into_value(self) {
  match self {
    Auto => Auto
    Custom(v) => v.into_value()
  }
}

///|
pub impl FromValue for SmartTodayOffset with fn from_value(v) {
  match v {
    Auto => Auto
    v if TodayOffset::castable(v) => Custom(TodayOffset::from_value(v))
    v => raise HintedError(SmartTodayOffset::input().error(v))
  }
}

///|
pub impl Reflect for Datetime with fn input() {
  Type(Type::datetime())
}

///|
pub impl Reflect for Datetime with fn output() {
  Type(Type::datetime())
}

///|
pub impl Reflect for Datetime with fn castable(v) {
  v is Datetime(_)
}

///|
pub impl IntoValue for Datetime with fn into_value(self) {
  Datetime(self)
}

///|
pub impl FromValue for Datetime with fn from_value(v) {
  match v {
    Datetime(d) => d
    v => raise HintedError(Datetime::input().error(v))
  }
}
