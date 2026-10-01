// Strict UTF-8 validation and decoding (like Rust's `std::str::from_utf8`).

///|
/// The index up to which `bytes` is valid UTF-8 and the length of the
/// invalid sequence (`None` if the input ends unexpectedly), or `None` if
/// all bytes are valid (Rust's `Utf8Error::valid_up_to` / `error_len`).
pub fn utf8_error(bytes : BytesView) -> (Int, Int?)? {
  let n = bytes.length()
  let mut i = 0
  while i < n {
    let first = bytes[i].to_int()
    if first < 0x80 {
      i += 1
      continue
    }
    let width = if first >= 0xC2 && first <= 0xDF {
      2
    } else if first >= 0xE0 && first <= 0xEF {
      3
    } else if first >= 0xF0 && first <= 0xF4 {
      4
    } else {
      return Some((i, Some(1)))
    }
    if i + 1 >= n {
      return Some((i, None))
    }
    let second = bytes[i + 1].to_int()
    let second_ok = match width {
      2 => second >= 0x80 && second <= 0xBF
      3 =>
        (first == 0xE0 && second >= 0xA0 && second <= 0xBF) ||
        (first >= 0xE1 && first <= 0xEC && second >= 0x80 && second <= 0xBF) ||
        (first == 0xED && second >= 0x80 && second <= 0x9F) ||
        (first >= 0xEE && first <= 0xEF && second >= 0x80 && second <= 0xBF)
      _ =>
        (first == 0xF0 && second >= 0x90 && second <= 0xBF) ||
        (first >= 0xF1 && first <= 0xF3 && second >= 0x80 && second <= 0xBF) ||
        (first == 0xF4 && second >= 0x80 && second <= 0x8F)
    }
    if !second_ok {
      return Some((i, Some(1)))
    }
    for k in 2..<width {
      if i + k >= n {
        return Some((i, None))
      }
      let b = bytes[i + k].to_int()
      if b < 0x80 || b > 0xBF {
        return Some((i, Some(k)))
      }
    }
    i += width
  }
  None
}

///|
/// Whether the bytes are valid UTF-8.
pub fn valid_utf8(bytes : BytesView) -> Bool {
  utf8_error(bytes) is None
}

///|
/// Decode valid UTF-8 bytes, or return `None` if they are invalid.
pub fn decode_utf8(bytes : BytesView) -> String? {
  if !valid_utf8(bytes) {
    return None
  }
  Some(@utf8.decode(bytes)) catch {
    _ => None
  }
}

///|
test "utf8_error" {
  inspect(utf8_error(b"abc"), content="None")
  inspect(utf8_error(b"a\xffb"), content="Some((1, Some(1)))")
  inspect(utf8_error(b"a\xe2\x82"), content="Some((1, None))")
  inspect(utf8_error(b"a\xe2\x82x"), content="Some((1, Some(2)))")
  inspect(utf8_error(b"\xed\xa0\x80"), content="Some((0, Some(1)))")
  inspect(decode_utf8(b"h\xc3\xa9").unwrap(), content="hé")
}
