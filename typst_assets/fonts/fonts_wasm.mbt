///|
fn font_count() -> Int {
  fonts_base64.length()
}

///|
/// Decodes a base64 multi-line string (line breaks are skipped).
fn font_data(index : Int) -> Bytes {
  let (chunks, len) = fonts_base64[index]
  let out = FixedArray::make(len, b'\x00')
  let mut o = 0
  let mut acc = 0
  let mut bits = 0
  for text in chunks {
    for i in 0..<text.length() {
      if o >= len {
        break
      }
      let c = text.code_unit_at(i).to_int()
      let v = if c >= 'A'.to_int() && c <= 'Z'.to_int() {
        c - 'A'.to_int()
      } else if c >= 'a'.to_int() && c <= 'z'.to_int() {
        c - 'a'.to_int() + 26
      } else if c >= '0'.to_int() && c <= '9'.to_int() {
        c - '0'.to_int() + 52
      } else if c == '+'.to_int() {
        62
      } else if c == '/'.to_int() {
        63
      } else {
        continue
      }
      acc = ((acc << 6) | v) & 0xFFFFFF
      bits += 6
      if bits >= 8 {
        bits -= 8
        out[o] = ((acc >> bits) & 0xFF).to_byte()
        o += 1
      }
    }
  }
  Bytes::from_array(out)
}
