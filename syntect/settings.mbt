// Port of `syntect/src/highlighting/settings.rs`: reading a property list
// into a JSON-like `Settings` value (upstream `plist::from_reader` into a
// `serde_json::Value`).
//
// Only XML property lists are supported (the format of `.tmTheme` files),
// parsed with the port of roxmltree in `data/xml` and turned into the event
// stream of plist's `XmlReader`, which is then deserialized like plist's
// serde `Deserializer` feeding serde_json's `Value` visitor. Binary and
// ASCII property lists are reported as errors.

///|
/// A JSON value (upstream `serde_json::Value`).
pub(all) enum Settings {
  Null
  Bool(Bool)
  /// A number, with its JSON representation.
  Number(String)
  String(String)
  Array(Array[Settings])
  /// An object; keys are sorted as in serde_json's default `BTreeMap`.
  Object(Map[String, Settings])
} derive(Eq)

///|
/// The JSON representation (upstream `Value::to_string`).
pub impl Show for Settings with fn output(self, logger) {
  match self {
    Null => logger.write_string("null")
    Bool(b) => logger.write_string(if b { "true" } else { "false" })
    Number(n) => logger.write_string(n)
    String(s) => write_json_str(logger, s)
    Array(items) => {
      logger.write_char('[')
      for i, item in items {
        if i > 0 {
          logger.write_char(',')
        }
        item.output(logger)
      }
      logger.write_char(']')
    }
    Object(map) => {
      logger.write_char('{')
      let keys = map.keys().collect()
      keys.sort_by((a, b) => compare_str(a, b))
      for i, key in keys {
        if i > 0 {
          logger.write_char(',')
        }
        write_json_str(logger, key)
        logger.write_char(':')
        map[key].output(logger)
      }
      logger.write_char('}')
    }
  }
}

///|
pub extend Settings with Show::{to_string, output}

///|
fn write_json_str(logger : &Logger, s : String) -> Unit {
  logger.write_char('"')
  for c in s {
    match c {
      '"' => logger.write_string("\\\"")
      '\\' => logger.write_string("\\\\")
      '\n' => logger.write_string("\\n")
      '\r' => logger.write_string("\\r")
      '\t' => logger.write_string("\\t")
      '\u{08}' => logger.write_string("\\b")
      '\u{0C}' => logger.write_string("\\f")
      c if c.to_int() < 0x20 => {
        let hex = c.to_int().to_string(radix=16)
        logger.write_string("\\u")
        logger.write_string(
          "0000".unsafe_substring(start=0, end=4 - hex.length()),
        )
        logger.write_string(hex)
      }
      c => logger.write_char(c)
    }
  }
  logger.write_char('"')
}

///|
pub fn Settings::as_str(self : Settings) -> String? {
  match self {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// An error parsing a settings file
pub(all) suberror SettingsError {
  /// Incorrect Plist syntax (with plist's error message)
  Plist(String)
}

///|
pub impl Show for SettingsError with fn output(self, logger) {
  match self {
    Plist(e) => logger.write_string("Incorrect Plist syntax: \{e}")
  }
}

///|
/// A plist event (upstream `plist::stream::Event`).
priv enum PlistEvent {
  StartArray
  StartDictionary
  EndCollection
  Boolean(Bool)
  Data
  Date(String)
  Integer(String)
  Real(Double)
  String(String)
}

///|
pub fn read_plist(bytes : Bytes) -> Settings raise SettingsError {
  // A plist is binary if it starts with magic bytes.
  if bytes.length() >= 8 && bytes[0:8] == b"bplist00"[:] {
    raise Plist("binary property lists are not supported")
  }
  let text = @utf8.decode(bytes) catch { _ => raise Plist("invalid UTF-8") }
  let options : @xml.ParsingOptions = {
    ..@xml.ParsingOptions::default(),
    allow_dtd: true,
  }
  let doc = @xml.Document::parse_with_options(text, options) catch {
    e => raise Plist(e.to_string())
  }
  let events = []
  for child in doc.root().children() {
    plist_events(child, events)
  }
  let mut pos = 0
  fn next() -> PlistEvent raise SettingsError {
    guard events.get(pos) is Some(e) else {
      raise Plist("unexpected end of file")
    }
    pos += 1
    e
  }

  fn value(event : PlistEvent) -> Settings raise SettingsError {
    match event {
      StartArray => {
        let items = []
        while true {
          let e = next()
          if e is EndCollection {
            break
          }
          items.push(value(e))
        }
        Array(items)
      }
      StartDictionary => {
        let map = Map([])
        while true {
          let e = next()
          match e {
            EndCollection => break
            String(key) => map[key] = value(next())
            _ => raise Plist("invalid type: expected a string key")
          }
        }
        Object(map)
      }
      EndCollection => raise Plist("unexpected end of collection")
      Boolean(b) => Bool(b)
      Data =>
        raise Plist("invalid type: byte array, expected any valid JSON value")
      Date(s) => String(s)
      Integer(s) => Number(s)
      Real(f) =>
        if f.is_nan() || f.is_inf() {
          Null
        } else {
          Number(rust_f64_to_json(f))
        }
      String(s) => String(s)
    }
  }

  let root = value(next())
  if pos < events.length() {
    raise Plist("expected end of event stream")
  }
  root
}

///|
/// The events of plist's `XmlReader` for a node.
fn plist_events(
  node : @xml.Node,
  events : Array[PlistEvent],
) -> Unit raise SettingsError {
  if node.is_text() {
    if !node.text().unwrap_or("").iter().all(c => is_ws(c.to_int())) {
      raise Plist("unexpected characters, expected element")
    }
    return
  }
  if !node.is_element() {
    return
  }
  match node.tag_name().name() {
    "plist" => {
      for child in node.children() {
        plist_events(child, events)
      }
      return
    }
    "array" => {
      events.push(StartArray)
      for child in node.children() {
        plist_events(child, events)
      }
      events.push(EndCollection)
      return
    }
    "dict" => {
      events.push(StartDictionary)
      for child in node.children() {
        plist_events(child, events)
      }
      events.push(EndCollection)
      return
    }
    "key" | "string" => events.push(String(read_content(node)))
    "data" => {
      let encoded = read_content(node)
      if !is_base64(encoded) {
        raise Plist("invalid data string")
      }
      events.push(Data)
    }
    "date" => {
      let s = read_content(node)
      if !is_rfc3339(s) {
        raise Plist("invalid date string")
      }
      events.push(Date(s))
    }
    "integer" => {
      let s = read_content(node)
      if !is_plist_integer(s) {
        raise Plist("invalid integer string")
      }
      events.push(Integer(normalize_integer(s)))
    }
    "real" => {
      let s = read_content(node)
      let f = parse_rust_f64(s)
      match f {
        Some(f) => events.push(Real(f))
        None => raise Plist("invalid real string")
      }
    }
    "true" => {
      events.push(Boolean(true))
      for child in node.children() {
        plist_events(child, events)
      }
    }
    "false" => {
      events.push(Boolean(false))
      for child in node.children() {
        plist_events(child, events)
      }
    }
    _ => raise Plist("unknown XML element")
  }
}

///|
/// The text content of a value element (plist's `read_content`).
fn read_content(node : @xml.Node) -> String raise SettingsError {
  let content = StringBuilder()
  for child in node.children() {
    if child.is_element() {
      raise Plist("unexpected XML opening tag")
    }
    if child.is_text() {
      content.write_string(child.text().unwrap_or(""))
    }
  }
  content.to_string()
}

///|
fn is_base64(s : String) -> Bool {
  let mut n = 0
  let mut pad = 0
  for c in s {
    if c is (' ' | '\t' | '\n' | '\r' | '\u{0C}') {
      continue
    }
    if c == '=' {
      pad += 1
    } else if pad > 0 {
      return false
    } else if !(c is ('A'..='Z' | 'a'..='z' | '0'..='9' | '+' | '/')) {
      return false
    }
    n += 1
  }
  n % 4 == 0 && pad <= 2
}

///|
fn is_rfc3339(s : String) -> Bool {
  // YYYY-MM-DDTHH:MM:SS(.frac)?(Z|+HH:MM|-HH:MM)
  let digits = (start : Int, len : Int) => {
    if start + len > s.length() {
      return false
    }
    for i in start..<(start + len) {
      if !(s.code_unit_at(i).to_int() >= '0'.to_int() &&
        s.code_unit_at(i).to_int() <= '9'.to_int()) {
        return false
      }
    }
    true
  }
  let at = (i : Int, c : Char) => {
    i < s.length() && s.code_unit_at(i).to_int() == c.to_int()
  }
  if !(digits(0, 4) && at(4, '-') && digits(5, 2) && at(7, '-') && digits(8, 2)) {
    return false
  }
  if !((at(10, 'T') || at(10, 't')) &&
    digits(11, 2) &&
    at(13, ':') &&
    digits(14, 2) &&
    at(16, ':') &&
    digits(17, 2)) {
    return false
  }
  let mut i = 19
  if at(i, '.') {
    i += 1
    let start = i
    while digits(i, 1) {
      i += 1
    }
    if i == start {
      return false
    }
  }
  if at(i, 'Z') || at(i, 'z') {
    return i + 1 == s.length()
  }
  (at(i, '+') || at(i, '-')) &&
  digits(i + 1, 2) &&
  at(i + 3, ':') &&
  digits(i + 4, 2) &&
  i + 6 == s.length()
}

///|
fn is_plist_integer(s : String) -> Bool {
  if s.has_prefix("0x") {
    // `u64::from_str_radix(s.trim_start_matches("0x"), 16)`
    let mut hex = s.view()
    while hex.has_prefix("0x") {
      hex = hex[2:]
    }
    if hex.has_prefix("+") {
      hex = hex[1:]
    }
    if hex.is_empty() || hex.length() > 16 + count_leading_zeros(hex) {
      return false
    }
    hex.iter().all(c => c is ('0'..='9' | 'a'..='f' | 'A'..='F'))
  } else {
    parse_rust_i64(s) is Some(_) || parse_rust_u64(s) is Some(_)
  }
}

///|
fn count_leading_zeros(s : StringView) -> Int {
  let mut n = 0
  for c in s {
    if c != '0' {
      break
    }
    n += 1
  }
  n
}

///|
fn normalize_integer(s : String) -> String {
  if s.has_prefix("0x") {
    let mut t = s.view()
    while t.has_prefix("0x") {
      t = t[2:]
    }
    if t.has_prefix("+") {
      t = t[1:]
    }
    let mut v = 0UL
    for c in t {
      let d = if c >= '0' && c <= '9' {
        c.to_int() - '0'.to_int()
      } else if c >= 'a' && c <= 'f' {
        c.to_int() - 'a'.to_int() + 10
      } else {
        c.to_int() - 'A'.to_int() + 10
      }
      v = v * 16UL + d.to_uint64()
    }
    v.to_string()
  } else {
    match parse_rust_i64(s) {
      Some(v) => v.to_string()
      None => parse_rust_u64(s).unwrap_or(0UL).to_string()
    }
  }
}

///|
/// Rust's `str::parse::<f64>`.
fn parse_rust_f64(s : String) -> Double? {
  let lower = s.to_lower()
  match lower {
    "inf" | "+inf" | "infinity" | "+infinity" => return Some(@double.infinity)
    "-inf" | "-infinity" => return Some(@double.neg_infinity)
    "nan" | "+nan" | "-nan" => return Some(@double.not_a_number)
    _ => ()
  }
  // Rust accepts `[+-]digits[.digits][e[+-]digits]` with optional parts.
  let mut i = 0
  let n = s.length()
  let at = (i : Int) => if i < n { s.code_unit_at(i).to_int() } else { -1 }
  if at(i) == '+'.to_int() || at(i) == '-'.to_int() {
    i += 1
  }
  let mut digits = 0
  while at(i) >= '0'.to_int() && at(i) <= '9'.to_int() {
    i += 1
    digits += 1
  }
  if at(i) == '.'.to_int() {
    i += 1
    while at(i) >= '0'.to_int() && at(i) <= '9'.to_int() {
      i += 1
      digits += 1
    }
  }
  if digits == 0 {
    return None
  }
  if at(i) == 'e'.to_int() || at(i) == 'E'.to_int() {
    i += 1
    if at(i) == '+'.to_int() || at(i) == '-'.to_int() {
      i += 1
    }
    let start = i
    while at(i) >= '0'.to_int() && at(i) <= '9'.to_int() {
      i += 1
    }
    if i == start {
      return None
    }
  }
  if i != n {
    return None
  }
  try @string.parse_double(s) catch {
    _ => None
  } noraise {
    f => Some(f)
  }
}

///|
/// serde_json's representation of a finite `f64`.
fn rust_f64_to_json(f : Double) -> String {
  let s = f.to_string()
  if s.contains(".") || s.contains("e") || s.contains("E") {
    s
  } else {
    s + ".0"
  }
}

///|
/// Rust's `str::parse::<i64>`: an optional sign and decimal digits.
fn parse_rust_i64(s : String) -> Int64? {
  let (neg, digits) = if s.has_prefix("-") {
    (true, s.view()[1:])
  } else if s.has_prefix("+") {
    (false, s.view()[1:])
  } else {
    (false, s.view())
  }
  if digits.is_empty() || !digits.iter().all(c => c >= '0' && c <= '9') {
    return None
  }
  let text = if neg { "-" + digits.to_owned() } else { digits.to_owned() }
  try @string.parse_int64(text) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Rust's `str::parse::<u64>`: an optional `+` and decimal digits.
fn parse_rust_u64(s : String) -> UInt64? {
  let digits = if s.has_prefix("+") { s.view()[1:] } else { s.view() }
  if digits.is_empty() || !digits.iter().all(c => c >= '0' && c <= '9') {
    return None
  }
  try @string.parse_uint64(digits) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}
