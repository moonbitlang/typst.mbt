// Port of `hayro-postscript/src/string/ascii_hex.rs`.
// Keep in sync with `hayro-syntax/src/filter/ascii_hex.rs`.

///|
fn ascii_hex_decode_into(data : BytesView, out : Array[Byte]) -> Unit? {
  let mut has_whitespace = false
  for b in data {
    if is_whitespace(b) {
      has_whitespace = true
      break
    }
  }
  if !has_whitespace {
    // Fast path, don't need to worry about white spaces.
    let mut i = 0
    while i + 1 < data.length() {
      guard decode_hex_digit(data[i]) is Some(hi) else { return None }
      guard decode_hex_digit(data[i + 1]) is Some(lo) else { return None }
      out.push((hi << 4) | lo)
      i += 2
    }
    if i < data.length() {
      guard decode_hex_digit(data[i]) is Some(hi) else { return None }
      out.push(hi << 4)
    }
  } else {
    // Slow path, need to strip white spaces.
    let mut idx = 0
    let read_byte = fn() -> Byte? {
      while idx < data.length() {
        let b = data[idx]
        idx += 1
        if !is_whitespace(b) {
          return Some(b)
        }
      }
      None
    }
    while true {
      let hi = read_byte()
      let lo = read_byte()
      match (hi, lo) {
        (Some(hi), Some(lo)) => {
          guard decode_hex_digit(hi) is Some(hi) else { return None }
          guard decode_hex_digit(lo) is Some(lo) else { return None }
          out.push((hi << 4) | lo)
        }
        (Some(hi), None) => {
          guard decode_hex_digit(hi) is Some(hi) else { return None }
          out.push(hi << 4)
          break
        }
        (None, _) => break
      }
    }
  }
  Some(())
}

///|
fn decode_hex_digit(c : Byte) -> Byte? {
  match c {
    b'0'..=b'9' => Some(c - b'0')
    b'A'..=b'F' => Some(c - b'A' + 10)
    b'a'..=b'f' => Some(c - b'a' + 10)
    _ => None
  }
}
