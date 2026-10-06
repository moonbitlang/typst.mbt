// Port of `hayro-syntax/src/object/string.rs`: strings.

///|
/// A PDF string object.
pub(all) struct PdfString(Bytes) derive(Eq, Hash)

///|
/// Returns the string data as a byte slice.
pub fn PdfString::as_bytes(self : PdfString) -> Bytes {
  self.0
}

///|
pub impl Show for PdfString with fn output(self, logger) {
  logger.write_string(self.0.to_string())
}

///|
pub impl Skippable for PdfString with fn skip(r, _) {
  skip_string(r)
}

///|
fn skip_string(r : Reader) -> Unit? {
  guard r.peek_byte() is Some(peeked) else { return None }
  match peeked {
    b'<' => skip_hex(r)
    b'(' => skip_literal(r)
    _ => None
  }
}

///|
pub impl Readable for PdfString with fn read(r, ctx) {
  guard r.peek_byte() is Some(peeked) else { return None }
  let decoded = match peeked {
    b'<' => read_hex(r)
    b'(' => read_literal(r)
    _ => None
  }
  guard decoded is Some(decoded) else { return None }
  // Apply decryption if needed.
  let final_data = if ctx.xref().needs_decryption(ctx) {
    if ctx.obj_number() is Some(obj_number) {
      ctx.xref().decrypt(obj_number, decoded[:], String).unwrap_or(decoded)
    } else {
      decoded
    }
  } else {
    decoded
  }
  Some(PdfString(final_data))
}

///|
pub extend PdfString with Readable::{read}

///|
pub impl ObjectLike for PdfString with fn from_object(o) {
  match o {
    String(s) => Some(s)
    _ => None
  }
}

///|
fn is_ascii_hexdigit(b : Byte) -> Bool {
  b is (b'0'..=b'9' | b'a'..=b'f' | b'A'..=b'F')
}

///|
fn skip_hex(r : Reader) -> Unit? {
  guard r.forward_tag(b"<") is Some(_) else { return None }
  while r.peek_byte() is Some(b) {
    let is_hex = is_ascii_hexdigit(b)
    let is_whitespace = is_white_space_character(b)
    if !is_hex && !is_whitespace {
      break
    }
    guard r.read_byte() is Some(_) else { return None }
  }
  guard r.forward_tag(b">") is Some(_) else { return None }
  Some(())
}

///|
fn read_hex(r : Reader) -> Bytes? {
  let start = r.offset()
  guard skip_hex(r) is Some(_) else { return None }
  let end = r.offset()
  // Exclude outer brackets.
  guard r.range(start + 1, end - 1) is Some(raw) else { return None }
  ascii_hex_decode(raw)
}

///|
fn skip_literal(r : Reader) -> Unit? {
  guard r.forward_tag(b"(") is Some(_) else { return None }
  let mut bracket_counter = 1
  while bracket_counter > 0 {
    guard r.read_byte() is Some(byte) else { return None }
    match byte {
      b'\\' => if r.read_byte() is None { return None }
      b'(' => bracket_counter += 1
      b')' => bracket_counter -= 1
      _ => ()
    }
  }
  Some(())
}

///|
fn is_octal_digit(byte : Byte) -> Bool {
  byte is (b'0'..=b'7')
}

///|
fn read_literal(r : Reader) -> Bytes? {
  let start = r.offset()
  guard skip_literal(r) is Some(_) else { return None }
  let end = r.offset()
  // Exclude outer parentheses.
  guard r.range(start + 1, end - 1) is Some(data) else { return None }
  let mut plain = true
  for b in data {
    if b is (b'\\' | b'\n' | b'\r') {
      plain = false
      break
    }
  }
  if plain {
    return Some(data.to_owned())
  }
  let r = Reader::new(data)
  let result = Buffer()
  while r.read_byte() is Some(byte) {
    match byte {
      b'\\' => {
        guard r.read_byte() is Some(next) else { return None }
        if is_octal_digit(next) {
          let second = r.read_byte()
          let third = r.read_byte()
          let digits : (Byte, Byte, Byte) = match (second, third) {
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
          let num = (digits.0.to_int() - 48) * 64 +
            (digits.1.to_int() - 48) * 8 +
            (digits.2.to_int() - 48)
          if num <= 255 {
            result.write_byte(num.to_byte())
          }
          // Otherwise: overflow occurred while parsing octal literal string.
        } else {
          match next {
            b'n' => result.write_byte(b'\n')
            b'r' => result.write_byte(b'\r')
            b't' => result.write_byte(b'\t')
            b'b' => result.write_byte(b'\x08')
            b'f' => result.write_byte(b'\x0c')
            b'(' => result.write_byte(b'(')
            b')' => result.write_byte(b')')
            b'\\' => result.write_byte(b'\\')
            b'\n' | b'\r' =>
              // A conforming reader shall disregard the REVERSE SOLIDUS
              // and the end-of-line marker following it when reading
              // the string; the resulting string value shall be
              // identical to that which would be read if the string
              // were not split.
              r.skip_eol_characters()
            _ => result.write_byte(next)
          }
        }
      }
      b'(' | b')' => result.write_byte(byte)
      // An end-of-line marker appearing within a literal string
      // without a preceding REVERSE SOLIDUS shall be treated as
      // a byte value of (0Ah), irrespective of whether the end-of-line
      // marker was a CARRIAGE RETURN (0Dh), a LINE FEED (0Ah), or both.
      b'\n' | b'\r' => {
        result.write_byte(b'\n')
        r.skip_eol_characters()
      }
      other => result.write_byte(other)
    }
  }
  Some(result.to_bytes())
}
