// Port of the `std::fmt::Write` sink as used by hayagriva and helpers that
// reproduce the exact sequence of `write_str` calls Rust's formatting
// machinery performs. This matters because the CSL rendering context
// (`Context::push_str`) post-processes every single write (punctuation
// pulling, duplicate affix removal, ...).

///|
/// Rust's `std::fmt::Write`.
pub(open) trait FmtWrite {
  fn write_str(Self, String) -> Unit
  fn write_char(Self, Char) -> Unit
}

///|
/// A plain string buffer (Rust's `String` as a `fmt::Write`).
pub struct StrBuf {
  priv buf : StringBuilder
}

///|
pub fn StrBuf::new() -> StrBuf {
  { buf: StringBuilder(), }
}

///|
pub fn StrBuf::to_string(self : StrBuf) -> String {
  self.buf.to_string()
}

///|
pub impl FmtWrite for StrBuf with fn write_str(self, s) {
  self.buf.write_string(s)
}

///|
pub impl FmtWrite for StrBuf with fn write_char(self, c) {
  self.buf.write_char(c)
}

///|
pub extend StrBuf with FmtWrite::{write_str, write_char}

///|
/// Format a value into a string with a writer function.
fn fmt_to_string(f : (StrBuf) -> Unit) -> String {
  let b = StrBuf::new()
  f(b)
  b.to_string()
}

///|
/// `write!(w, "{}", n)` for a signed integer: the sign is written
/// separately from the digits (`Formatter::pad_integral`).
fn[W : FmtWrite] fmt_int(w : W, n : Int64) -> Unit {
  if n < 0L {
    w.write_char('-')
    w.write_str(abs_digits(n))
  } else {
    w.write_str(n.to_string())
  }
}

///|
/// The decimal digits of `|n|`.
fn abs_digits(n : Int64) -> String {
  if n == -9223372036854775807L - 1L {
    "9223372036854775808"
  } else if n < 0L {
    (-n).to_string()
  } else {
    n.to_string()
  }
}

///|
/// `write!(w, "{:0width$}", n)` for a signed integer: sign, then the padding
/// zeros one char at a time, then the digits.
fn[W : FmtWrite] fmt_int_zero_pad(w : W, n : Int64, width : Int) -> Unit {
  let digits = abs_digits(n)
  let len = digits.length() + (if n < 0L { 1 } else { 0 })
  if len >= width {
    if n < 0L {
      w.write_char('-')
    }
    w.write_str(digits)
  } else {
    if n < 0L {
      w.write_char('-')
    }
    for _ in 0..<(width - len) {
      w.write_char('0')
    }
    w.write_str(digits)
  }
}

///|
/// The string of `format!("{:0width$}", n)`.
fn int_zero_pad(n : Int64, width : Int) -> String {
  fmt_to_string(b => fmt_int_zero_pad(b, n, width))
}
