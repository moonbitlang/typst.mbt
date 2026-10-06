// A minimal TOML reader, sufficient for package manifests (upstream uses the
// `toml` crate together with serde, see `PackageManifest` in `package.mbt`).
//
// Supported: comments, `[table]` and `[[array.of.tables]]` headers, bare,
// quoted and dotted keys, basic and literal strings (including multi-line
// ones), integers, floats, booleans, arrays and inline tables. Date-times are
// kept as raw strings. Error messages follow the `toml` crate where it
// matters for user-visible diagnostics.

///|
/// A parsed TOML value.
// A date-time keeps its text like `toml::Value::Datetime` keeps its value;
// no manifest field is a date-time, so only its type name is ever used.
#warnings("-unused_field")
priv enum TomlValue {
  TString(String)
  TInteger(Int64)
  TFloat(Double)
  TBoolean(Bool)
  TDatetime(String)
  TArray(Array[TomlValue])
  TTable(Map[String, TomlValue])
}

///|
/// A TOML parse or deserialization error (the `toml` crate's
/// `Error::message`).
priv suberror TomlError {
  TomlError(String)
}

///|
/// serde's `Unexpected` rendering of a value, for "invalid type" errors.
fn TomlValue::unexpected(self : TomlValue) -> String {
  match self {
    TString(s) => "string \{@unicode.rust_debug_str(s)}"
    TInteger(i) => "integer `\{i}`"
    TFloat(f) => "floating point `\{f}`"
    TBoolean(b) => "boolean `\{b}`"
    TDatetime(_) => "datetime"
    TArray(_) => "sequence"
    TTable(_) => "map"
  }
}

///|
priv struct TomlParser {
  text : String
  mut pos : Int
}

///|
/// Parse a TOML document into its root table.
fn toml_parse(text : String) -> Map[String, TomlValue] raise TomlError {
  let p : TomlParser = { text, pos: 0, }
  let root : Map[String, TomlValue] = Map([])
  let mut current = root
  while true {
    p.skip_ws_comments_newlines()
    if p.done() {
      break
    }
    if p.peek() == '[' {
      p.pos += 1
      let array = p.peek() == '['
      if array {
        p.pos += 1
      }
      p.skip_ws()
      let keys = p.key_path()
      p.skip_ws()
      p.expect(']')
      if array {
        p.expect(']')
      }
      p.line_end()
      current = toml_open_table(root, keys, array)
    } else {
      let keys = p.key_path()
      p.skip_ws()
      p.expect('=')
      p.skip_ws()
      let value = p.value()
      p.line_end()
      toml_insert(current, keys, value)
    }
  }
  root
}

///|
fn toml_open_table(
  root : Map[String, TomlValue],
  keys : Array[String],
  array : Bool,
) -> Map[String, TomlValue] raise TomlError {
  let mut table = root
  for i, key in keys {
    let last = i + 1 == keys.length()
    match table.get(key) {
      None => {
        let fresh : Map[String, TomlValue] = Map([])
        if last && array {
          table[key] = TArray([TTable(fresh)])
        } else {
          table[key] = TTable(fresh)
        }
        table = fresh
      }
      Some(TTable(t)) =>
        if last && array {
          raise TomlError("duplicate key `\{key}`")
        } else {
          table = t
        }
      Some(TArray(items)) if items.length() > 0 &&
        items[items.length() - 1] is TTable(t) =>
        if last && array {
          let fresh : Map[String, TomlValue] = Map([])
          items.push(TTable(fresh))
          table = fresh
        } else if last {
          raise TomlError("duplicate key `\{key}`")
        } else {
          table = t
        }
      Some(_) => raise TomlError("duplicate key `\{key}`")
    }
  }
  table
}

///|
fn toml_insert(
  table : Map[String, TomlValue],
  keys : Array[String],
  value : TomlValue,
) -> Unit raise TomlError {
  let mut table = table
  for i, key in keys {
    if i + 1 == keys.length() {
      if table.contains(key) {
        raise TomlError("duplicate key `\{key}`")
      }
      table[key] = value
    } else {
      match table.get(key) {
        None => {
          let fresh : Map[String, TomlValue] = Map([])
          table[key] = TTable(fresh)
          table = fresh
        }
        Some(TTable(t)) => table = t
        Some(_) => raise TomlError("duplicate key `\{key}`")
      }
    }
  }
}

///|
fn TomlParser::done(self : TomlParser) -> Bool {
  self.pos >= self.text.length()
}

///|
fn TomlParser::peek(self : TomlParser) -> Int {
  if self.done() {
    -1
  } else {
    self.text.code_unit_at(self.pos).to_int()
  }
}

///|
fn TomlParser::starts_with(self : TomlParser, s : String) -> Bool {
  self.text.length() - self.pos >= s.length() &&
  self.text.unsafe_substring(start=self.pos, end=self.pos + s.length()) == s
}

///|
fn TomlParser::expect(self : TomlParser, c : Char) -> Unit raise TomlError {
  if self.peek() != c.to_int() {
    raise TomlError(self.unexpected("`\{c}`"))
  }
  self.pos += 1
}

///|
fn TomlParser::unexpected(self : TomlParser, expected : String) -> String {
  if self.done() {
    "invalid TOML: unexpected end of input, expected \{expected}"
  } else {
    "invalid TOML: expected \{expected}"
  }
}

///|
fn TomlParser::skip_ws(self : TomlParser) -> Unit {
  while self.peek() == ' ' || self.peek() == '\t' {
    self.pos += 1
  }
}

///|
fn TomlParser::skip_comment(self : TomlParser) -> Unit {
  if self.peek() == '#' {
    while !self.done() && self.peek() != '\n' {
      self.pos += 1
    }
  }
}

///|
fn TomlParser::skip_ws_comments_newlines(self : TomlParser) -> Unit {
  while true {
    self.skip_ws()
    self.skip_comment()
    if self.peek() == '\n' || self.peek() == '\r' {
      self.pos += 1
    } else {
      break
    }
  }
}

///|
/// Expect the end of a line (after optional whitespace and a comment).
fn TomlParser::line_end(self : TomlParser) -> Unit raise TomlError {
  self.skip_ws()
  self.skip_comment()
  if self.starts_with("\r\n") {
    self.pos += 2
  } else if self.peek() == '\n' {
    self.pos += 1
  } else if !self.done() {
    raise TomlError(self.unexpected("newline"))
  }
}

///|
fn is_bare_key_char(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_'
}

///|
fn TomlParser::key(self : TomlParser) -> String raise TomlError {
  match self.peek() {
    '"' => self.basic_string()
    '\'' => self.literal_string()
    c if is_bare_key_char(c) => {
      let start = self.pos
      while is_bare_key_char(self.peek()) {
        self.pos += 1
      }
      self.text.unsafe_substring(start~, end=self.pos)
    }
    _ => raise TomlError(self.unexpected("key"))
  }
}

///|
fn TomlParser::key_path(self : TomlParser) -> Array[String] raise TomlError {
  let keys = [self.key()]
  while true {
    self.skip_ws()
    if self.peek() != '.' {
      break
    }
    self.pos += 1
    self.skip_ws()
    keys.push(self.key())
  }
  keys
}

///|
fn TomlParser::value(self : TomlParser) -> TomlValue raise TomlError {
  match self.peek() {
    '"' => TString(self.basic_string())
    '\'' => TString(self.literal_string())
    '[' => self.array()
    '{' => self.inline_table()
    _ =>
      if self.starts_with("true") {
        self.pos += 4
        TBoolean(true)
      } else if self.starts_with("false") {
        self.pos += 5
        TBoolean(false)
      } else {
        self.scalar()
      }
  }
}

///|
fn TomlParser::scalar(self : TomlParser) -> TomlValue raise TomlError {
  let start = self.pos
  while !self.done() {
    let c = self.peek()
    if c == ' ' ||
      c == '\t' ||
      c == '\n' ||
      c == '\r' ||
      c == '#' ||
      c == ',' ||
      c == ']' ||
      c == '}' {
      break
    }
    self.pos += 1
  }
  let raw = self.text.unsafe_substring(start~, end=self.pos)
  if raw.is_empty() {
    raise TomlError(self.unexpected("value"))
  }
  let digits = raw.replace_all(old="_", new="")
  if digits is ("inf" | "+inf") {
    return TFloat(@double.infinity)
  } else if digits == "-inf" {
    return TFloat(@double.neg_infinity)
  } else if digits is ("nan" | "+nan" | "-nan") {
    // `f64::NAN`, negated after a `-`.
    let nan = 0x7FF8000000000000L.reinterpret_as_double()
    return TFloat(if digits == "-nan" { -nan } else { nan })
  }
  let is_int = digits
    .iter()
    .all(c => (c >= '0' && c <= '9') || c == '+' || c == '-')
  if is_int {
    return TInteger(@string.parse_int64(digits, base=10)) catch {
      _ => raise TomlError("invalid TOML: invalid number")
    }
  }
  if digits.contains(":") ||
    (digits.length() >= 10 && digits.code_unit_at(4) == '-') {
    return TDatetime(raw)
  }
  TFloat(@string.parse_double(digits)) catch {
    _ => raise TomlError("invalid TOML: invalid number")
  }
}

///|
fn TomlParser::array(self : TomlParser) -> TomlValue raise TomlError {
  self.expect('[')
  let items = []
  while true {
    self.skip_ws_comments_newlines()
    if self.peek() == ']' {
      self.pos += 1
      break
    }
    items.push(self.value())
    self.skip_ws_comments_newlines()
    if self.peek() == ',' {
      self.pos += 1
    } else if self.peek() == ']' {
      self.pos += 1
      break
    } else {
      raise TomlError(self.unexpected("`,` or `]`"))
    }
  }
  TArray(items)
}

///|
fn TomlParser::inline_table(self : TomlParser) -> TomlValue raise TomlError {
  self.expect('{')
  let table : Map[String, TomlValue] = Map([])
  self.skip_ws()
  if self.peek() == '}' {
    self.pos += 1
    return TTable(table)
  }
  while true {
    self.skip_ws()
    let keys = self.key_path()
    self.skip_ws()
    self.expect('=')
    self.skip_ws()
    toml_insert(table, keys, self.value())
    self.skip_ws()
    if self.peek() == ',' {
      self.pos += 1
    } else if self.peek() == '}' {
      self.pos += 1
      break
    } else {
      raise TomlError(self.unexpected("`,` or `}`"))
    }
  }
  TTable(table)
}

///|
fn TomlParser::literal_string(self : TomlParser) -> String raise TomlError {
  let multi = self.starts_with("'''")
  let delim = if multi { "'''" } else { "'" }
  self.pos += delim.length()
  if multi && self.peek() == '\n' {
    self.pos += 1
  }
  let start = self.pos
  while !self.starts_with(delim) {
    if self.done() || (!multi && self.peek() == '\n') {
      raise TomlError("invalid TOML: unterminated string")
    }
    self.pos += 1
  }
  let s = self.text.unsafe_substring(start~, end=self.pos)
  self.pos += delim.length()
  s
}

///|
fn TomlParser::basic_string(self : TomlParser) -> String raise TomlError {
  let multi = self.starts_with("\"\"\"")
  let delim = if multi { "\"\"\"" } else { "\"" }
  self.pos += delim.length()
  if multi && self.peek() == '\n' {
    self.pos += 1
  }
  let out = StringBuilder()
  while !self.starts_with(delim) {
    if self.done() || (!multi && self.peek() == '\n') {
      raise TomlError("invalid TOML: unterminated string")
    }
    let c = self.peek()
    if c != '\\' {
      let start = self.pos
      while !self.done() &&
            self.peek() != '\\' &&
            !self.starts_with(delim) &&
            (multi || self.peek() != '\n') {
        self.pos += 1
      }
      out.write_string(self.text.unsafe_substring(start~, end=self.pos))
      continue
    }
    self.pos += 1
    let e = self.peek()
    self.pos += 1
    match e {
      'b' => out.write_char('\b')
      't' => out.write_char('\t')
      'n' => out.write_char('\n')
      'f' => out.write_char('\u{c}')
      'r' => out.write_char('\r')
      'e' => out.write_char('\u{1b}')
      '"' => out.write_char('"')
      '\\' => out.write_char('\\')
      'u' | 'U' => {
        let len = if e == 'u' { 4 } else { 8 }
        if self.pos + len > self.text.length() {
          raise TomlError("invalid TOML: invalid escape sequence")
        }
        let hex = self.text.unsafe_substring(start=self.pos, end=self.pos + len)
        self.pos += len
        let code = @string.parse_int(hex, base=16) catch {
          _ => raise TomlError("invalid TOML: invalid escape sequence")
        }
        out.write_char(Int::unsafe_to_char(code))
      }
      '\n' | ' ' | '\t' | '\r' if multi =>
        // Line ending backslash: trim all whitespace up to the next
        // non-whitespace character.
        while self.peek() is (' ' | '\t' | '\n' | '\r') {
          self.pos += 1
        }
      _ => raise TomlError("invalid TOML: invalid escape sequence")
    }
  }
  self.pos += delim.length()
  out.to_string()
}
