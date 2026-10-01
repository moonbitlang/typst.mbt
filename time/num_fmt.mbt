// Port of the parts of `time/src/num_fmt.rs` used here.

///|
/// Format a non-negative integer, left-padding it with `pad` up to `width`
/// characters.
fn pad_left(n : Int, width : Int, pad : Char) -> String {
  let s = n.to_string()
  let sb = StringBuilder()
  for _ in s.length()..<width {
    sb.write_char(pad)
  }
  sb.write_string(s)
  sb.to_string()
}

///|
/// Format a non-negative integer, zero-padded to `width` digits.
fn zero_pad(n : Int, width : Int) -> String {
  pad_left(n, width, '0')
}

///|
/// Obtain the nine-digit zero-padded string of `n`, a number of nanoseconds
/// (`subsecond_from_nanos`).
fn subsecond_from_nanos(n : Int) -> String {
  zero_pad(n, 9)
}

///|
/// The number of significant subsecond digits (at least one): nine minus the
/// number of trailing zeros among digits 2 through 9.
fn subsecond_significant_len(digits : String) -> Int {
  let mut len = 9
  while len > 1 && digits[len - 1] == '0' {
    len -= 1
  }
  len
}

///|
/// Obtain a string of 1 to 9 ASCII digits representing `n`, which is a number
/// of nanoseconds. Trailing zeros are truncated, but at least one digit is
/// always present.
fn truncated_subsecond_from_nanos(n : Int) -> String {
  let digits = subsecond_from_nanos(n)
  digits.view(end_offset=subsecond_significant_len(digits)).to_owned()
}
