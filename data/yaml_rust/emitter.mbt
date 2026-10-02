// Port of `yaml_rust::emitter` (yaml-rust 0.4.5).
//
// Upstream writes into a `fmt::Write` and returns `EmitResult`; writing into a
// `StringBuilder` cannot fail and `BadHashmapKey` is never produced, so the
// emitter here does not raise.

///|
pub struct YamlEmitter {
  priv writer : StringBuilder
  priv best_indent : Int
  priv mut compact : Bool
  priv mut level : Int
}

///|
/// from serialize::json
fn escape_str(wr : StringBuilder, v : String) -> Unit {
  wr.write_string("\"")
  let mut start = 0
  // Only ASCII bytes are escaped, so UTF-16 code units work like upstream's
  // bytes.
  for i in 0..<v.length() {
    let escaped = match v.code_unit_at(i).to_int() {
      '"' => "\\\""
      '\\' => "\\\\"
      0x00 => "\\u0000"
      0x01 => "\\u0001"
      0x02 => "\\u0002"
      0x03 => "\\u0003"
      0x04 => "\\u0004"
      0x05 => "\\u0005"
      0x06 => "\\u0006"
      0x07 => "\\u0007"
      0x08 => "\\b"
      '\t' => "\\t"
      '\n' => "\\n"
      0x0b => "\\u000b"
      0x0c => "\\f"
      '\r' => "\\r"
      0x0e => "\\u000e"
      0x0f => "\\u000f"
      0x10 => "\\u0010"
      0x11 => "\\u0011"
      0x12 => "\\u0012"
      0x13 => "\\u0013"
      0x14 => "\\u0014"
      0x15 => "\\u0015"
      0x16 => "\\u0016"
      0x17 => "\\u0017"
      0x18 => "\\u0018"
      0x19 => "\\u0019"
      0x1a => "\\u001a"
      0x1b => "\\u001b"
      0x1c => "\\u001c"
      0x1d => "\\u001d"
      0x1e => "\\u001e"
      0x1f => "\\u001f"
      0x7f => "\\u007f"
      _ => continue
    }
    if start < i {
      wr.write_substring(v, start, i - start)
    }
    wr.write_string(escaped)
    start = i + 1
  }
  if start != v.length() {
    wr.write_substring(v, start, v.length() - start)
  }
  wr.write_string("\"")
}

///|
pub fn YamlEmitter::new(writer : StringBuilder) -> YamlEmitter {
  { writer, best_indent: 2, compact: true, level: -1, }
}

///|
/// Set 'compact inline notation' on or off, as described for block
/// [sequences](http://www.yaml.org/spec/1.2/spec.html#id2797382)
/// and
/// [mappings](http://www.yaml.org/spec/1.2/spec.html#id2798057).
///
/// In this form, blocks cannot have any properties (such as anchors
/// or tags), which should be OK, because this emitter doesn't
/// (currently) emit those anyways.
pub fn YamlEmitter::compact(self : YamlEmitter, compact : Bool) -> Unit {
  self.compact = compact
}

///|
/// Determine if this emitter is using 'compact inline notation'.
pub fn YamlEmitter::is_compact(self : YamlEmitter) -> Bool {
  self.compact
}

///|
pub fn YamlEmitter::dump(self : YamlEmitter, doc : Yaml) -> Unit {
  // write DocumentStart
  self.writer.write_string("---\n")
  self.level = -1
  self.emit_node(doc)
}

///|
fn YamlEmitter::write_indent(self : YamlEmitter) -> Unit {
  if self.level <= 0 {
    return
  }
  for _ in 0..<self.level {
    for _ in 0..<self.best_indent {
      self.writer.write_string(" ")
    }
  }
}

///|
fn YamlEmitter::emit_node(self : YamlEmitter, node : Yaml) -> Unit {
  match node {
    Array(v) => self.emit_array(v)
    Hash(h) => self.emit_hash(h)
    String(v) =>
      if need_quotes(v) {
        escape_str(self.writer, v)
      } else {
        self.writer.write_string(v)
      }
    Boolean(v) =>
      if v {
        self.writer.write_string("true")
      } else {
        self.writer.write_string("false")
      }
    Integer(v) => self.writer.write_string(v.to_string())
    Real(v) => self.writer.write_string(v)
    Null | BadValue => self.writer.write_string("~")
    // XXX(chenyh) Alias
    _ => ()
  }
}

///|
fn YamlEmitter::emit_array(self : YamlEmitter, v : Array[Yaml]) -> Unit {
  if v.is_empty() {
    self.writer.write_string("[]")
  } else {
    self.level += 1
    for cnt, x in v {
      if cnt > 0 {
        self.writer.write_string("\n")
        self.write_indent()
      }
      self.writer.write_string("-")
      self.emit_val(true, x)
    }
    self.level -= 1
  }
}

///|
fn YamlEmitter::emit_hash(
  self : YamlEmitter,
  h : LinkedHashMap[Yaml, Yaml],
) -> Unit {
  if h.is_empty() {
    self.writer.write_string("{}")
  } else {
    self.level += 1
    let mut cnt = 0
    for k, v in h.iter2() {
      let complex_key = match k {
        Hash(_) | Array(_) => true
        _ => false
      }
      if cnt > 0 {
        self.writer.write_string("\n")
        self.write_indent()
      }
      if complex_key {
        self.writer.write_string("?")
        self.emit_val(true, k)
        self.writer.write_string("\n")
        self.write_indent()
        self.writer.write_string(":")
        self.emit_val(true, v)
      } else {
        self.emit_node(k)
        self.writer.write_string(":")
        self.emit_val(false, v)
      }
      cnt += 1
    }
    self.level -= 1
  }
}

///|
/// Emit a yaml as a hash or array value: i.e., which should appear
/// following a ":" or "-", either after a space, or on a new line.
/// If `inline` is true, then the preceding characters are distinct
/// and short enough to respect the compact flag.
fn YamlEmitter::emit_val(self : YamlEmitter, inline : Bool, val : Yaml) -> Unit {
  match val {
    Array(v) => {
      if (inline && self.compact) || v.is_empty() {
        self.writer.write_string(" ")
      } else {
        self.writer.write_string("\n")
        self.level += 1
        self.write_indent()
        self.level -= 1
      }
      self.emit_array(v)
    }
    Hash(h) => {
      if (inline && self.compact) || h.is_empty() {
        self.writer.write_string(" ")
      } else {
        self.writer.write_string("\n")
        self.level += 1
        self.write_indent()
        self.level -= 1
      }
      self.emit_hash(h)
    }
    _ => {
      self.writer.write_string(" ")
      self.emit_node(val)
    }
  }
}

///|
/// Check if the string requires quoting.
/// Strings starting with any of the following characters must be quoted.
/// :, &, *, ?, |, -, <, >, =, !, %, @
/// Strings containing any of the following characters must be quoted.
/// {, }, [, ], ,, #, `
///
/// If the string contains any of the following control characters, it must be escaped with double quotes:
/// \0, \x01, \x02, \x03, \x04, \x05, \x06, \a, \b, \t, \n, \v, \f, \r, \x0e, \x0f, \x10, \x11, \x12, \x13, \x14, \x15, \x16, \x17, \x18, \x19, \x1a, \e, \x1c, \x1d, \x1e, \x1f, \N, \_, \L, \P
///
/// Finally, there are other cases when the strings must be quoted, no matter if you're using single or double quotes:
/// * When the string is true or false (otherwise, it would be treated as a boolean value);
/// * When the string is null or ~ (otherwise, it would be considered as a null value);
/// * When the string looks like a number, such as integers (e.g. 2, 14, etc.), floats (e.g. 2.6, 14.9) and exponential numbers (e.g. 12e7, etc.) (otherwise, it would be treated as a numeric value);
/// * When the string looks like a date (e.g. 2014-12-31) (otherwise it would be automatically converted into a Unix timestamp).
fn need_quotes(string : String) -> Bool {
  fn need_quotes_spaces(string : String) -> Bool {
    string.has_prefix(" ") || string.has_suffix(" ")
  }

  string == "" ||
  need_quotes_spaces(string) ||
  (match string.get_char(0) {
    Some('&' | '*' | '?' | '|' | '-' | '<' | '>' | '=' | '!' | '%' | '@') =>
      true
    _ => false
  }) ||
  string
  .iter()
  .any(c => {
    match c {
      ':'
      | '{'
      | '}'
      | '['
      | ']'
      | ','
      | '#'
      | '`'
      | '"'
      | '\''
      | '\\'
      | '\u{0}'..='\u{6}'
      | '\t'
      | '\n'
      | '\r'
      | '\u{e}'..='\u{1a}'
      | '\u{1c}'..='\u{1f}' => true
      _ => false
    }
  }) ||
  [
    // http://yaml.org/type/bool.html
    // Note: 'y', 'Y', 'n', 'N', is not quoted deliberately, as in libyaml. PyYAML also parse
    // them as string, not booleans, although it is violating the YAML 1.1 specification.
    // See https://github.com/dtolnay/serde-yaml/pull/83#discussion_r152628088.
    "yes", "Yes", "YES", "no", "No", "NO", "True", "TRUE", "true", "False", "FALSE",
    "false", "on", "On", "ON", "off", "Off", "OFF",
    // http://yaml.org/type/null.html
     "null", "Null", "NULL", "~",
  ].contains(string) ||
  string.has_prefix(".") ||
  string.has_prefix("0x") ||
  i64_from_str_radix(string, 10) is Some(_) ||
  rust_parse_f64(string) is Some(_)
}
