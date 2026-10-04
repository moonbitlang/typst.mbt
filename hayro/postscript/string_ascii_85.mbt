// Port of `hayro-postscript/src/string/ascii_85.rs`.
// Keep in sync with `hayro-syntax/src/filter/ascii_85.rs`.

///|
let pow_85 : ReadOnlyArray[UInt64] = [52200625, 614125, 7225, 85, 1]

///|
fn ascii_85_decode_into(data : BytesView, out : Array[Byte]) -> Unit? {
  let reader = Reader::new(data)
  let read_byte = fn() -> Byte? {
    while true {
      guard reader.read_byte() is Some(b) else { return None }
      // White space characters should be ignored.
      if !is_whitespace(b) {
        return Some(b)
      }
    }
    None
  }
  let flush_group = fn(group : Array[Byte], decoded : Array[Byte]) -> Unit? {
    let output_len = match group.length() {
      0 => return Some(())
      1 => return None // A single character is not valid.
      n => n - 1
    }
    let digits : FixedArray[UInt64] = FixedArray::make(
      5,
      (b'u' - b'!').to_uint64(),
    )
    for i, b in group {
      digits[i] = (b - b'!').to_uint64()
    }
    // `checked_mul`/`checked_add` on `u32`.
    let mut value = 0UL
    for i in 0..<5 {
      value = value + digits[i] * pow_85[i]
      if value > 0xFFFFFFFFUL {
        return None
      }
    }
    let bytes : ReadOnlyArray[_] = [
      (value >> 24).to_byte(),
      (value >> 16).to_byte(),
      (value >> 8).to_byte(),
      value.to_byte(),
    ]
    for i in 0..<output_len {
      decoded.push(bytes[i])
    }
    group.clear()
    Some(())
  }
  let group = []
  while true {
    guard read_byte() is Some(b) else {
      // Be lenient and accept what we have (see PDFBOX-5910).
      guard flush_group(group, out) is Some(_) else { return None }
      return Some(())
    }
    match b {
      b'!'..=b'u' => {
        group.push(b)
        if group.length() == 5 {
          guard flush_group(group, out) is Some(_) else { return None }
        }
      }
      b'z' => {
        guard flush_group(group, out) is Some(_) else { return None }
        out.push(0)
        out.push(0)
        out.push(0)
        out.push(0)
      }
      b'~' => {
        // Technically requires a '>', but there is a PDF where it isn't
        // appended and decodes fine in other viewers.
        guard flush_group(group, out) is Some(_) else { return None }
        return Some(())
      }
      _ => return None // Invalid character.
    }
  }
  None
}
