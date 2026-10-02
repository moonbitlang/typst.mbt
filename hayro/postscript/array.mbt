// Port of `hayro-postscript/src/array.rs`.

///|
/// A PostScript array object (upstream `Array`).
pub struct PsArray {
  priv data : BytesView
} derive(Eq, Debug)

///|
pub impl Show for PsArray with fn output(self, logger) {
  logger.write_string("Array(\{self.data})")
}

///|
fn PsArray::new(data : BytesView) -> PsArray {
  { data, }
}

///|
/// Return a [`Scanner`] that iterates over the objects inside this array.
pub fn PsArray::objects(self : PsArray) -> Scanner {
  Scanner::new(self.data)
}

///|
fn parse_array(r : Reader) -> Result[BytesView, PsError] {
  guard r.forward_tag(b"[") is Some(_) else { return Err(SyntaxError) }
  let start = r.offset()
  match skip_array(r) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }
  let end = r.offset() - 1
  match r.range(start, end) {
    Some(d) => Ok(d)
    None => Err(SyntaxError)
  }
}

///|
fn skip_array(r : Reader) -> Result[Unit, PsError] {
  let mut depth = 1
  while depth > 0 {
    guard r.peek_byte() is Some(b) else { return Err(SyntaxError) }
    match b {
      b'[' => {
        r.forward()
        depth += 1
      }
      b']' => {
        r.forward()
        depth -= 1
      }
      b'(' => if parse_literal(r) is None { return Err(SyntaxError) }
      b'<' =>
        if r.peek_bytes(2) == Some(b"<~"[:]) {
          if parse_ascii85(r) is None {
            return Err(SyntaxError)
          }
        } else if r.peek_bytes(2) == Some(b"<<"[:]) {
          r.forward()
          r.forward()
        } else if parse_hex(r) is None {
          return Err(SyntaxError)
        }
      b'%' => skip_whitespace_and_comments(r)
      _ => r.forward()
    }
  }
  Ok(())
}
