// Port of the parts of `serde_json` 1.0.151 `ser.rs` used by
// `serde_json::to_string` and `serde_json::to_string_pretty` for Typst values
// (`CompactFormatter` and `PrettyFormatter` with two-space indentation).

///|
/// Serialize a value as compact JSON (upstream `serde_json::to_string`) or
/// pretty-printed JSON (upstream `serde_json::to_string_pretty`).
pub fn to_string(value : @serde.Data, pretty~ : Bool) -> String {
  let buf = StringBuilder()
  write_value(buf, value, pretty, 0)
  buf.to_string()
}

///|
fn write_indent(buf : StringBuilder, level : Int) -> Unit {
  for _ in 0..<level {
    buf.write_string("  ")
  }
}

///|
fn write_value(
  buf : StringBuilder,
  value : @serde.Data,
  pretty : Bool,
  level : Int,
) -> Unit {
  match value {
    None => buf.write_string("null")
    Bool(b) => buf.write_string(if b { "true" } else { "false" })
    Int(i) => buf.write_string(i.to_string())
    Float(f) =>
      // Non-finite floats are serialized as `null`.
      if f.is_nan() || f.is_inf() {
        buf.write_string("null")
      } else {
        buf.write_string(@serde.format_zmij(f))
      }
    Str(s) => format_escaped_str(buf, s)
    Bytes(bytes) => {
      // `serialize_bytes` writes an array of numbers.
      buf.write_char('[')
      let mut first = true
      for b in bytes {
        begin_value(buf, first, pretty, level + 1)
        first = false
        buf.write_string(b.to_int().to_string())
      }
      end_container(buf, first, pretty, level, ']')
    }
    Seq(items) => {
      buf.write_char('[')
      let mut first = true
      for item in items {
        begin_value(buf, first, pretty, level + 1)
        first = false
        write_value(buf, item, pretty, level + 1)
      }
      end_container(buf, first, pretty, level, ']')
    }
    Map(entries) => {
      buf.write_char('{')
      let mut first = true
      for entry in entries {
        let (key, value) = entry
        begin_value(buf, first, pretty, level + 1)
        first = false
        format_escaped_str(buf, key)
        buf.write_string(if pretty { ": " } else { ":" })
        write_value(buf, value, pretty, level + 1)
      }
      end_container(buf, first, pretty, level, '}')
    }
  }
}

///|
/// `begin_array_value` / `begin_object_key`.
fn begin_value(
  buf : StringBuilder,
  first : Bool,
  pretty : Bool,
  level : Int,
) -> Unit {
  if pretty {
    buf.write_string(if first { "\n" } else { ",\n" })
    write_indent(buf, level)
  } else if !first {
    buf.write_char(',')
  }
}

///|
/// `end_array` / `end_object`.
fn end_container(
  buf : StringBuilder,
  empty : Bool,
  pretty : Bool,
  level : Int,
  close : Char,
) -> Unit {
  if pretty && !empty {
    buf.write_char('\n')
    write_indent(buf, level)
  }
  buf.write_char(close)
}

///|
/// Write a string with JSON escapes (upstream `format_escaped_str`).
fn format_escaped_str(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  for c in s {
    match c {
      '"' => buf.write_string("\\\"")
      '\\' => buf.write_string("\\\\")
      '\u{08}' => buf.write_string("\\b")
      '\u{0C}' => buf.write_string("\\f")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      c if c.to_int() < 0x20 => {
        let hex = "0123456789abcdef"
        let n = c.to_int()
        buf.write_string("\\u00")
        buf.write_char(hex[n >> 4].unsafe_to_char())
        buf.write_char(hex[n & 0xF].unsafe_to_char())
      }
      c => buf.write_char(c)
    }
  }
  buf.write_char('"')
}
