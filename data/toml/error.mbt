///|
/// A `toml::de::Error` as Typst sees it.
///
/// `message` is exactly `error.message()` (the message without the source
/// snippet) and `span` is `error.span()` as UTF-8 byte offsets `(start, end)`
/// into the input. Serialization errors (`toml::ser::Error`) use the same
/// type with the error's `Display` output as message and no span.
pub(all) suberror TomlError {
  TomlError(message~ : String, span~ : (Int, Int)?)
} derive(Debug, Eq)

///|
/// `impl Display for StrContextValue` (winnow).
fn StrContextValue::to_display(self : StrContextValue) -> String {
  match self {
    CharLiteral('\n') => "newline"
    CharLiteral('`') => "'`'"
    CharLiteral(c) if c.to_int() < 0x20 || c.to_int() == 0x7f =>
      "`\{escape_debug_char(c)}`"
    CharLiteral(c) => "`\{c}`"
    StringLiteral(s) => "`\{s}`"
    Description(s) => s
  }
}

///|
/// `char::escape_debug` for the ASCII control characters.
fn escape_debug_char(c : Char) -> String {
  match c {
    '\t' => "\\t"
    '\r' => "\\r"
    '\n' => "\\n"
    _ => {
      let hex = c.to_int().to_string(radix=16)
      "\\u{\{hex}}"
    }
  }
}

///|
/// `impl Display for ContextError<StrContext>` (winnow 0.7.1).
fn ContextError::to_display(self : ContextError) -> String {
  let buf = StringBuilder()
  let mut expression : String? = None
  for c in self.context {
    if c is Label(l) {
      expression = Some(l)
      break
    }
  }
  let expected = []
  for c in self.context {
    if c is Expected(v) {
      expected.push(v)
    }
  }
  let mut newline = false
  if expression is Some(e) {
    newline = true
    buf.write_string("invalid \{e}")
  }
  if !expected.is_empty() {
    if newline {
      buf.write_char('\n')
    }
    newline = true
    buf.write_string("expected ")
    for k, e in expected {
      if k != 0 {
        buf.write_string(", ")
      }
      buf.write_string(e.to_display())
    }
  }
  if self.cause is Some(cause) {
    if newline {
      buf.write_char('\n')
    }
    buf.write_string(cause)
  }
  buf.to_string()
}

///|
/// `toml_edit::parser::error::CustomError` (as its `Display` output).
fn duplicate_key_error(key : String, table : Array[String]?) -> String {
  match table {
    Some(table) =>
      if table.is_empty() {
        "duplicate key `\{key}` in document root"
      } else {
        "duplicate key `\{key}` in table `\{table.join(".")}`"
      }
    None => "duplicate key `\{key}`"
  }
}

///|
/// `CustomError::duplicate_key(path, i)`: the key is shown with its default
/// representation (the parsed repr is span-based and thus unavailable).
fn duplicate_key_at(path : Array[String], i : Int) -> String {
  duplicate_key_error(to_key_repr(path[i]), Some(path[:i].to_owned()))
}

///|
/// `CustomError::extend_wrong_type(path, i, actual)`.
fn extend_wrong_type(path : Array[String], i : Int, actual : String) -> String {
  let key = path[:i + 1].to_owned().join(".")
  "dotted key `\{key}` attempted to extend non-table type (\{actual})"
}

///|
let out_of_range : String = "value is out of range"

///|
let recursion_limit_exceeded : String = "recursion limit exceeded"

///|
/// `TomlError::new`: turns the final parser error at byte `offset` into a
/// `TomlError` whose span covers the character at `offset` (empty at the end
/// of input).
fn toml_error_at(bytes : Bytes, offset : Int, err : ContextError) -> TomlError {
  let len = bytes.length()
  // Move back to a char boundary.
  let mut offset = if offset > len { len } else { offset }
  while offset > 0 && offset < len && (bytes[offset].to_int() & 0xC0) == 0x80 {
    offset -= 1
  }
  let char_len = if offset >= len {
    0
  } else {
    let b = bytes[offset].to_int()
    if b < 0x80 {
      1
    } else if b < 0xE0 {
      2
    } else if b < 0xF0 {
      3
    } else {
      4
    }
  }
  TomlError(message=err.to_display(), span=Some((offset, offset + char_len)))
}
