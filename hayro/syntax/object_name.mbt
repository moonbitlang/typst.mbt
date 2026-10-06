// Port of `hayro-syntax/src/object/name.rs`: names.

///|
/// A PDF name object. The (unescaped) bytes are stored as a latin-1 string,
/// i.e. each char is one byte.
pub(all) struct Name(String) derive(Eq, Hash)

///|
/// Create a new name from a sequence of bytes.
pub fn Name::new(data : BytesView) -> Name? {
  if !bytes_contain(data, b'#') {
    Some(Name::new_unescaped(data))
  } else {
    Name::new_escaped(data)
  }
}

///|
/// Create a new name from an unescaped byte sequence.
pub fn Name::new_unescaped(data : BytesView) -> Name {
  Name(latin1_string(data))
}

///|
/// Create a name from a (latin-1) string.
pub fn Name::from_string(s : String) -> Name {
  Name(s)
}

///|
/// Create a new name from bytes that may contain escape sequences.
pub fn Name::new_escaped(data : BytesView) -> Name? {
  let result = StringBuilder()
  let r = Reader::new(data)
  while r.read_byte() is Some(b) {
    if b == b'#' {
      guard r.read_bytes(2) is Some(hex) else { return None }
      guard decode_hex_digit(hex[0]) is Some(hi) else { return None }
      guard decode_hex_digit(hex[1]) is Some(lo) else { return None }
      let v = (hi.to_int() << 4) | lo.to_int()
      result.write_char(v.unsafe_to_char())
    } else {
      result.write_char(b.to_int().unsafe_to_char())
    }
  }
  Some(Name(result.to_string()))
}

///|
/// The raw bytes of the name, as a latin-1 string.
pub fn Name::raw(self : Name) -> String {
  self.0
}

///|
/// The raw bytes of the name.
pub fn Name::as_bytes(self : Name) -> Bytes {
  latin1_bytes(self.0)
}

///|
/// Return a string representation of the name.
///
/// Returns a placeholder in case the name is not UTF-8 encoded.
pub fn Name::as_str(self : Name) -> String {
  let bytes = self.as_bytes()
  @utf8.decode(bytes) catch {
    _ => "{non-ascii key}"
  }
}

///|
pub impl Show for Name with fn output(self, logger) {
  logger.write_string(self.as_str())
}

///|
/// Order names by their bytes.
pub impl Compare for Name with fn compare(a, b) {
  compare_latin1(a.0, b.0)
}

///|
pub impl Readable for Name with fn read(r, _) {
  let start = r.offset()
  guard skip_name_like(r, true) is Some(_) else { return None }
  let end = r.offset()
  // Exclude leading solidus.
  guard r.range(start + 1, end) is Some(data) else { return None }
  Name::new(data)
}

///|
pub impl Skippable for Name with fn skip(r, _) {
  skip_name_like(r, true)
}

///|
pub impl ObjectLike for Name with fn from_object(o) {
  match o {
    Name(n) => Some(n)
    _ => None
  }
}

///|
// This method is shared by `Name` and the parser for content stream operators (which behave like
// names, except that they aren't preceded by a solidus.
pub fn skip_name_like(r : Reader, solidus : Bool) -> Unit? {
  // Note that we are not validating hex escape sequences here
  // (since this method can lie on the hot path), so it's possible
  // this method will yield invalid names. Validation needs to happen during actual
  // actual reading.
  if solidus {
    guard r.forward_tag(b"/") is Some(_) else { return None }
    r.forward_while(is_regular_character)
  } else {
    guard r.forward_while_1(is_regular_character) is Some(_) else {
      return None
    }
  }
  Some(())
}
