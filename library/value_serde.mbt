// Port of the serde impls of Typst values (upstream `impl Serialize for
// Value` / `impl Deserialize for Value` in `foundations/value.rs`, and the
// impls for `Bytes`, `Symbol`, `Content`, `NoneValue`, `Array` and `Dict`).
// The data formats exchange values as an `@serde.Data` tree.

///|
/// Serialize a value into the serde data model (upstream `impl Serialize for
/// Value`). `human_readable` is the serializer's `is_human_readable()`.
pub fn Value::to_serde(self : Value, human_readable : Bool) -> @serde.Data {
  match self {
    None => None
    Bool(v) => Bool(v)
    Int(v) => Int(v)
    Float(v) => Float(v)
    Str(v) => Str(v)
    // Upstream `impl Serialize for Bytes`.
    Bytes(v) => if human_readable { Str(v.repr()) } else { Bytes(v.0) }
    // Upstream `impl Serialize for Symbol`.
    Symbol(v) => Str(v.get())
    // Upstream `impl Serialize for Content`.
    Content(v) => {
      let entries = [("func", @serde.Data::Str(v.func().name()))]
      for key, value in v.fields().iter() {
        entries.push((key, value.to_serde(human_readable)))
      }
      Map(entries)
    }
    Array(v) => Seq(v.items.map(item => item.to_serde(human_readable)))
    Dict(v) => {
      let entries = []
      for key, value in v.iter() {
        entries.push((key, value.to_serde(human_readable)))
      }
      Map(entries)
    }
    // Fall back to repr() for other things.
    other => Str(other.repr())
  }
}

///|
/// Serialize a dictionary into the serde data model (upstream `impl
/// Serialize for Dict`).
pub fn Dict::to_serde(self : Dict, human_readable : Bool) -> @serde.Data {
  Value::Dict(self).to_serde(human_readable)
}

///|
/// Deserialize a value from the serde data model (upstream `ValueVisitor`).
pub fn Value::from_serde(data : @serde.Data) -> Value {
  match data {
    None => None
    Bool(v) => Bool(v)
    Int(v) => Int(v)
    Float(v) => Float(v)
    Str(v) => Str(v)
    Bytes(v) => Bytes(BytesValue(v))
    Seq(items) => Array(Arr::from_array(items.map(Value::from_serde)))
    Map(entries) => {
      let dict = Dict::from_serde_entries(entries)
      match datetime_from_toml_dict(dict) {
        None => Dict(dict)
        Some(datetime) => Datetime(datetime)
      }
    }
  }
}

///|
/// Deserialize a dictionary from serde map entries (upstream `impl
/// Deserialize for Dict`: an `IndexMap` where later duplicates replace the
/// value but keep the position of the first occurrence).
pub fn Dict::from_serde_entries(entries : Array[(String, @serde.Data)]) -> Dict {
  let dict = Dict::new()
  for entry in entries {
    let (key, value) = entry
    dict.insert(key, Value::from_serde(value))
  }
  dict
}

///|
/// Try to parse a dictionary as a TOML date (upstream
/// `Datetime::from_toml_dict`).
fn datetime_from_toml_dict(dict : Dict) -> Datetime? {
  if dict.len() != 1 {
    return None
  }
  let value = dict.get(@serde.toml_datetime_field) catch { _ => return None }
  guard value is Str(string) else { return None }
  let chars = string.to_array()
  // `[year]-[month]-[day]T[hour]:[minute]:[second]Z`,
  // `[year]-[month]-[day]T[hour]:[minute]:[second]`, `[year]-[month]-[day]`
  // and `[hour]:[minute]:[second]`, each matching the full string.
  let n = chars.length()
  if (n == 20 && chars[19] == 'Z') || n == 19 {
    if parse_toml_date(chars, 0) is Some((y, m, d)) &&
      chars[10] == 'T' &&
      parse_toml_time(chars, 11) is Some((hh, mm, ss)) {
      return datetime_from_ymd_hms(y, m, d, hh, mm, ss)
    }
  }
  if n == 10 && parse_toml_date(chars, 0) is Some((y, m, d)) {
    return datetime_from_ymd(y, m, d)
  }
  if n == 8 && parse_toml_time(chars, 0) is Some((hh, mm, ss)) {
    return datetime_from_hms(hh, mm, ss)
  }
  None
}

///|
fn parse_fixed_digits(chars : Array[Char], start : Int, len : Int) -> Int? {
  let mut v = 0
  for i in start..<(start + len) {
    let c = chars[i]
    guard c >= '0' && c <= '9' else { return None }
    v = v * 10 + (c.to_int() - '0'.to_int())
  }
  Some(v)
}

///|
/// Parse `[year]-[month]-[day]` (with a valid calendar date) at `start`.
fn parse_toml_date(chars : Array[Char], start : Int) -> (Int, Int, Int)? {
  guard chars.length() >= start + 10 else { return None }
  guard chars[start + 4] == '-' && chars[start + 7] == '-' else { return None }
  guard parse_fixed_digits(chars, start, 4) is Some(y) &&
    parse_fixed_digits(chars, start + 5, 2) is Some(m) &&
    parse_fixed_digits(chars, start + 8, 2) is Some(d) else {
    return None
  }
  guard m >= 1 && m <= 12 && d >= 1 && d <= days_in_month(y, m) else {
    return None
  }
  Some((y, m, d))
}

///|
/// Parse `[hour]:[minute]:[second]` (in range) at `start`.
fn parse_toml_time(chars : Array[Char], start : Int) -> (Int, Int, Int)? {
  guard chars.length() >= start + 8 else { return None }
  guard chars[start + 2] == ':' && chars[start + 5] == ':' else { return None }
  guard parse_fixed_digits(chars, start, 2) is Some(h) &&
    parse_fixed_digits(chars, start + 3, 2) is Some(m) &&
    parse_fixed_digits(chars, start + 6, 2) is Some(s) else {
    return None
  }
  guard h <= 23 && m <= 59 && s <= 59 else { return None }
  Some((h, m, s))
}

///|
fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 =>
      if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

// TODO(area E): the following constructors stand in for upstream
// `Datetime::from_ymd`, `Datetime::from_hms` and `Datetime::from_ymd_hms`
// until `foundations/datetime.rs` is ported; they only build the placeholder
// (which carries just the repr).

///|
fn datetime_from_parts(parts : Array[(String, Int)]) -> Datetime? {
  let parts = parts.map(part => "\{part.0}: \{part.1}")
  Some({ repr_: "datetime" + pretty_array_like(parts, false) })
}

///|
fn datetime_from_ymd(year : Int, month : Int, day : Int) -> Datetime? {
  datetime_from_parts([("year", year), ("month", month), ("day", day)])
}

///|
fn datetime_from_hms(hour : Int, minute : Int, second : Int) -> Datetime? {
  datetime_from_parts([("hour", hour), ("minute", minute), ("second", second)])
}

///|
fn datetime_from_ymd_hms(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
  second : Int,
) -> Datetime? {
  datetime_from_parts([
    ("year", year),
    ("month", month),
    ("day", day),
    ("hour", hour),
    ("minute", minute),
    ("second", second),
  ])
}
