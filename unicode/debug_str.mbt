///|
/// Format a string exactly like Rust's `impl Debug for str` (with quotes).
pub fn rust_debug_str(s : StringView) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  let mut i = 0
  let mut first = true
  while i < s.length() {
    let (c, next) = decode_at(s, i)
    write_rust_escaped(buf, c, first)
    first = false
    i = next
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn write_rust_escaped(buf : StringBuilder, c : Int, first : Bool) -> Unit {
  match c {
    0 => buf.write_string("\\0")
    '\t' => buf.write_string("\\t")
    '\r' => buf.write_string("\\r")
    '\n' => buf.write_string("\\n")
    '"' => buf.write_string("\\\"")
    '\\' => buf.write_string("\\\\")
    _ => {
      let table = if first {
        debug_escape_first_table
      } else {
        debug_escape_table
      }
      if in_ranges(table, c) {
        buf.write_string("\\u{")
        buf.write_string(c.to_string(radix=16))
        buf.write_char('}')
      } else {
        buf.write_char(Int::unsafe_to_char(c))
      }
    }
  }
}

///|
/// Format a char exactly like Rust's `impl Debug for char` (with quotes).
pub fn rust_debug_char(c : Char) -> String {
  let buf = StringBuilder()
  buf.write_char('\'')
  match c {
    '\'' => buf.write_string("\\'")
    '"' => buf.write_char('"')
    _ => write_rust_escaped(buf, c.to_int(), true)
  }
  buf.write_char('\'')
  buf.to_string()
}
