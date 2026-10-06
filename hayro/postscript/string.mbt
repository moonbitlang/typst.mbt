// Port of `hayro-postscript/src/string.rs`.

///|
priv enum StringInner {
  Literal(BytesView)
  Hex(BytesView)
  Ascii85(BytesView)
} derive(Eq, Debug)

///|
/// A PostScript string object (upstream `String`).
pub struct PsString {
  priv inner : StringInner
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PsString with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PsString with @debug.Debug::{to_repr}

///|
pub impl Show for PsString with fn output(self, logger) {
  match self.inner {
    Literal(d) => logger.write_string("Literal(\{d})")
    Hex(d) => logger.write_string("Hex(\{d})")
    Ascii85(d) => logger.write_string("Ascii85(\{d})")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PsString with Show::{to_string, output}

///|
fn PsString::from_literal(data : BytesView) -> PsString {
  { inner: Literal(data), }
}

///|
fn PsString::from_hex(data : BytesView) -> PsString {
  { inner: Hex(data), }
}

///|
fn PsString::from_ascii85(data : BytesView) -> PsString {
  { inner: Ascii85(data), }
}

///|
/// Decode the string content into `out`, replacing any previous contents.
pub fn PsString::decode_into(
  self : PsString,
  out : Array[Byte],
) -> Result[Unit, PsError] {
  out.clear()
  let res = match self.inner {
    Literal(data) => literal_decode_into(data, out)
    Hex(data) => ascii_hex_decode_into(data, out)
    Ascii85(data) => ascii_85_decode_into(data, out)
  }
  match res {
    Some(_) => Ok(())
    None => Err(SyntaxError)
  }
}

///|
/// Decode the string content.
pub fn PsString::decode(self : PsString) -> Result[Bytes, PsError] {
  let out = []
  match self.decode_into(out) {
    Ok(_) => Ok(Bytes::from_array(out))
    Err(e) => Err(e)
  }
}

///|
fn parse_literal(r : Reader) -> BytesView? {
  let start = r.offset()
  guard skip_literal(r) is Some(_) else { return None }
  let end = r.offset()
  // Exclude outer parentheses.
  r.range(start + 1, end - 1)
}

///|
fn parse_hex(r : Reader) -> BytesView? {
  guard r.forward_tag(b"<") is Some(_) else { return None }
  let start = r.offset()
  while r.read_byte() is Some(b) {
    if b == b'>' {
      return r.range(start, r.offset() - 1)
    }
  }
  None
}

///|
fn parse_ascii85(r : Reader) -> BytesView? {
  guard r.forward_tag(b"<~") is Some(_) else { return None }
  let start = r.offset()
  while true {
    guard r.read_byte() is Some(b) else { return None }
    if b == b'~' {
      let end = r.offset() - 1
      guard r.forward_tag(b">") is Some(_) else { return None }
      return r.range(start, end)
    }
  }
  None
}

///|
fn skip_literal(r : Reader) -> Unit? {
  guard r.forward_tag(b"(") is Some(_) else { return None }
  let mut depth = 1
  while depth > 0 {
    guard r.read_byte() is Some(byte) else { return None }
    match byte {
      b'\\' => {
        guard r.read_byte() is Some(_) else { return None }
      }
      b'(' => depth += 1
      b')' => depth -= 1
      _ => ()
    }
  }
  Some(())
}
