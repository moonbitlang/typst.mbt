// Port of `hayro-postscript/src/string/literal.rs`.
// Keep in sync with `hayro-syntax/src/object/string.rs` (`read_literal`).

///|
fn literal_decode_into(data : BytesView, out : Array[Byte]) -> Unit? {
  let r = Reader::new(data)
  while r.read_byte() is Some(byte) {
    match byte {
      b'\\' => {
        guard r.read_byte() is Some(next) else { return None }
        if is_octal_digit(next) {
          let second = r.read_byte()
          let third = r.read_byte()
          let bytes : (Byte, Byte, Byte) = match (second, third) {
            (Some(n1), Some(n2)) =>
              match (is_octal_digit(n1), is_octal_digit(n2)) {
                (true, true) => (next, n1, n2)
                (true, _) => {
                  r.jump(r.offset() - 1)
                  (b'0', next, n1)
                }
                _ => {
                  r.jump(r.offset() - 2)
                  (b'0', b'0', next)
                }
              }
            (Some(n1), None) =>
              if is_octal_digit(n1) {
                (b'0', next, n1)
              } else {
                r.jump(r.offset() - 1)
                (b'0', b'0', next)
              }
            _ => (b'0', b'0', next)
          }
          // `u8::from_str_radix(str, 8)`: values above 255 are dropped.
          let num = (bytes.0 - b'0').to_int() * 64 +
            (bytes.1 - b'0').to_int() * 8 +
            (bytes.2 - b'0').to_int()
          if num <= 255 {
            out.push(num.to_byte())
          }
        } else {
          match next {
            b'n' => out.push(b'\x0a')
            b'r' => out.push(b'\x0d')
            b't' => out.push(b'\x09')
            b'b' => out.push(b'\x08')
            b'f' => out.push(b'\x0c')
            b'(' => out.push(b'(')
            b')' => out.push(b')')
            b'\\' => out.push(b'\\')
            b'\n' | b'\r' =>
              // "If the \ is followed immediately by a newline
              // (CR, LF, or CR-LF pair), the scanner ignores
              // both the initial \ and the newline; this breaks
              // a string into multiple lines without including
              // the newline character as part of the string."
              r.skip_eol()
            _ => out.push(next)
          }
        }
      }
      b'(' | b')' => out.push(byte)
      // "But if a newline appears without a preceding \, the result is
      // equivalent to \n."
      b'\n' | b'\r' => {
        out.push(b'\n')
        r.skip_eol()
      }
      other => out.push(other)
    }
  }
  Some(())
}

///|
fn is_octal_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'7'
}
