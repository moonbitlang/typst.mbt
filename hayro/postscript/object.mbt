// Port of `hayro-postscript/src/object.rs`.

///|
/// A PostScript object.
pub(all) enum Object {
  /// A number object.
  Number(Number)
  /// A name object.
  Name(Name)
  /// A string object.
  String(PsString)
  /// An array object.
  Array(PsArray)
} derive(Eq, Debug)

///|
pub impl Show for Object with fn output(self, logger) {
  match self {
    Number(n) => logger.write_string("Number(\{n})")
    Name(n) => logger.write_string("Name(\{n})")
    String(s) => logger.write_string("String(\{s})")
    Array(a) => logger.write_string("Array(\{a})")
  }
}

///|
fn read_object(r : Reader) -> Result[Object, PsError] {
  skip_whitespace_and_comments(r)
  guard r.peek_byte() is Some(b) else { return Err(SyntaxError) }
  match b {
    b'(' =>
      match parse_literal(r) {
        Some(s) => Ok(String(PsString::from_literal(s)))
        None => Err(SyntaxError)
      }
    b'<' =>
      if r.peek_bytes(2) == Some(b"<~"[:]) {
        match parse_ascii85(r) {
          Some(s) => Ok(String(PsString::from_ascii85(s)))
          None => Err(SyntaxError)
        }
      } else if r.peek_bytes(2) == Some(b"<<"[:]) {
        // TODO: Proper dict support. For now, skip `<<` and return
        // the next object so callers see the inner tokens.
        r.forward()
        r.forward()
        // TODO: This can easily overflow the stack if we have nested <<<<<.
        read_object(r)
      } else {
        match parse_hex(r) {
          Some(s) => Ok(String(PsString::from_hex(s)))
          None => Err(SyntaxError)
        }
      }
    b'/' =>
      match parse_literal_name(r) {
        Some(s) => Ok(Name(Name::new(s, true)))
        None => Err(SyntaxError)
      }
    b'[' =>
      match parse_array(r) {
        Ok(d) => Ok(Array(PsArray::new(d)))
        Err(e) => Err(e)
      }
    b'>' =>
      if r.peek_bytes(2) == Some(b">>"[:]) {
        // TODO: Proper dict support. Skip `>>` closing delimiter.
        r.forward()
        r.forward()
        read_object(r)
      } else {
        Err(SyntaxError)
      }
    b'{' => {
      r.forward()
      Err(UnsupportedType)
    }
    b'.' | b'+' | b'-' | b'0'..=b'9' =>
      match read_number(r) {
        Ok(n) => Ok(Number(n))
        Err(e) => Err(e)
      }
    _ =>
      match parse_executable_name(r) {
        Some(s) => Ok(Name(Name::new(s, false)))
        None => Err(SyntaxError)
      }
  }
}

///|
fn at_end(r : Reader) -> Bool {
  skip_whitespace_and_comments(r)
  r.peek_byte() is None
}

///|
fn skip_whitespace_and_comments(r : Reader) -> Unit {
  while true {
    match r.peek_byte() {
      Some(b) if is_whitespace(b) => r.forward()
      Some(b'%') => {
        r.forward()
        r.forward_while(fn(b) { !is_eol(b) })
      }
      _ => return
    }
  }
}
