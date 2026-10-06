// Port of `typst-library/src/foundations/repr.rs`.

///|
/// The Unicode minus sign.
pub let minus_sign : String = "\u{2212}"

///|
/// Returns the string representation of a value.
fn impl_repr(value_ : Value) -> String {
  value_.repr()
}

///|
/// Format an integer in a base. Negative numbers use the Unicode minus sign.
pub fn format_int_with_base(n : Int64, base : Int64) -> String {
  if n == 0L {
    return "0"
  }
  let digits = "0123456789abcdefghijklmnopqrstuvwxyz"
  let negative = n < 0L
  // Work with negative numbers to handle `i64::MIN`.
  let mut n = if n > 0L { -n } else { n }
  let buf = []
  while n != 0L {
    let d = (-(n % base)).to_int()
    buf.push(digits.code_unit_at(d))
    n = n / base
  }
  let out = StringBuilder()
  if negative {
    out.write_string(minus_sign)
  }
  for i = buf.length() - 1; i >= 0; i = i - 1 {
    out.write_char(Int::unsafe_to_char(buf[i].to_int()))
  }
  out.to_string()
}

///|
/// Converts a float to a string representation with a specific precision and
/// a unit, all with a single allocation.
///
/// The returned string is always valid Typst code. As such, it might not be a
/// float literal. For example, it may return `"float.inf"`.
pub fn format_float(
  value : Double,
  precision? : Int,
  force_separator : Bool,
  unit : String,
) -> String {
  let value = match precision {
    Some(p) => round_with_precision(value, p)
    None => value
  }
  let unit_multiplication = if unit.is_empty() { "" } else { " * 1" }
  if value.is_nan() {
    "float.nan\{unit_multiplication}\{unit}"
  } else if value.is_inf() {
    let sign = if value < 0.0 { "-" } else { "" }
    "\{sign}float.inf\{unit_multiplication}\{unit}"
  } else if force_separator {
    rust_debug_f64(value) + unit
  } else {
    rust_display_f64(value) + unit
  }
}

///|
/// Converts a float to a string representation with a precision of three
/// decimal places. This is intended to be used as part of a larger structure
/// containing multiple float components, such as colors.
pub fn format_float_component(value : Double) -> String {
  format_float(value, precision=3, false, "")
}

///|
/// Converts a float to a string representation with a precision of two
/// decimal places, followed by a unit.
pub fn format_float_with_unit(value : Double, unit : String) -> String {
  format_float(value, precision=2, false, unit)
}

///|
/// Converts a float to a string that can be used to display the float as
/// text.
pub fn display_float(value : Double) -> String {
  if value.is_nan() {
    "NaN"
  } else if value.is_inf() {
    let sign = if value < 0.0 { minus_sign } else { "" }
    "\{sign}∞"
  } else if value < 0.0 {
    minus_sign + rust_display_f64(value.abs())
  } else {
    rust_display_f64(value.abs())
  }
}

///|
/// Formats pieces separated with commas and a final "and" or "or".
pub fn separated_list(pieces : ArrayView[String], last : String) -> String {
  let buf = StringBuilder()
  let n = pieces.length()
  for i, part in pieces {
    if i == 0 {
      ()
    } else if i == 1 && n == 2 {
      buf.write_char(' ')
      buf.write_string(last)
      buf.write_char(' ')
    } else if i + 1 == n {
      buf.write_string(", ")
      buf.write_string(last)
      buf.write_char(' ')
    } else {
      buf.write_string(", ")
    }
    buf.write_string(part)
  }
  buf.to_string()
}

///|
/// Formats a comma-separated list.
///
/// Tries to format horizontally, but falls back to vertical formatting if the
/// pieces are too long.
pub fn pretty_comma_list(
  pieces : ArrayView[String],
  trailing_comma : Bool,
) -> String {
  let max_width = 50
  let buf = StringBuilder()
  let mut len = 0
  for p in pieces {
    len += @syntax.utf8_len(p)
  }
  len += 2 * (if pieces.length() > 0 { pieces.length() - 1 } else { 0 })
  if len <= max_width {
    for i, piece in pieces {
      if i > 0 {
        buf.write_string(", ")
      }
      buf.write_string(piece)
    }
    if trailing_comma {
      buf.write_char(',')
    }
  } else {
    for piece in pieces {
      buf.write_string(rust_trim(piece))
      buf.write_string(",\n")
    }
  }
  buf.to_string()
}

///|
/// Formats an array-like construct.
///
/// Tries to format horizontally, but falls back to vertical formatting if the
/// pieces are too long.
pub fn pretty_array_like(
  parts : ArrayView[String],
  trailing_comma : Bool,
) -> String {
  let list = pretty_comma_list(parts, trailing_comma)
  let buf = StringBuilder()
  buf.write_char('(')
  if list.contains("\n") {
    buf.write_char('\n')
    for i, line in rust_lines(list) {
      if i > 0 {
        buf.write_char('\n')
      }
      buf.write_string("  ")
      buf.write_string(line)
    }
    buf.write_char('\n')
  } else {
    buf.write_string(list)
  }
  buf.write_char(')')
  buf.to_string()
}

///|
/// Rust's `str::trim` (Unicode whitespace on both ends).
pub fn rust_trim(s : String) -> String {
  rust_trim_end(rust_trim_start(s))
}

///|
/// Rust's `str::trim_start`.
pub fn rust_trim_start(s : String) -> String {
  let mut i = 0
  while i < s.length() {
    let { cp: c, idx: next, } = @unicode.decode_at(s, i)
    if !@unicode.is_whitespace(Int::unsafe_to_char(c)) {
      break
    }
    i = next
  }
  s.unsafe_substring(start=i, end=s.length())
}

///|
/// Rust's `str::trim_end`.
pub fn rust_trim_end(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    let { cp: c, idx: prev, } = @unicode.decode_before(s, end)
    if !@unicode.is_whitespace(Int::unsafe_to_char(c)) {
      break
    }
    end = prev
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// Rust's `str::lines`: split on `\n` (dropping a preceding `\r`), without a
/// final empty line.
pub fn rust_lines(text : String) -> Array[String] {
  let out = []
  let mut start = 0
  for i in 0..<text.length() {
    if text.code_unit_at(i) == '\n' {
      let mut end = i
      if end > start && text.code_unit_at(end - 1) == '\r' {
        end -= 1
      }
      out.push(text.unsafe_substring(start~, end~))
      start = i + 1
    }
  }
  if start < text.length() {
    let mut end = text.length()
    if end > start && text.code_unit_at(end - 1) == '\r' {
      end -= 1
    }
    out.push(text.unsafe_substring(start~, end~))
  }
  out
}
