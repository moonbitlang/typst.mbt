// Port of `hayro-postscript/src/name.rs`.

///|
/// A PostScript name object.
pub struct Name {
  priv data : BytesView
  priv literal : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Name with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Name with @debug.Debug::{to_repr}

///|
pub impl Show for Name with fn output(self, logger) {
  logger.write_string("Name(\{self.data}, literal=\{self.literal})")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Name with Show::{to_string, output}

///|
fn Name::new(data : BytesView, literal : Bool) -> Name {
  { data, literal, }
}

///|
/// Returns `true` if this is a literal name.
pub fn Name::is_literal(self : Name) -> Bool {
  self.literal
}

///|
/// Returns the name as a string if it is valid UTF-8, or
/// `None` if it contains non-ASCII bytes.
pub fn Name::as_str(self : Name) -> String? {
  Some(@utf8.decode(self.data)) catch {
    _ => None
  }
}

///|
/// The raw (undecoded) bytes of the name.
pub fn Name::data(self : Name) -> BytesView {
  self.data
}

///|
/// Decode the name into `out`, replacing any previous contents.
pub fn Name::decode_into(
  self : Name,
  out : Array[Byte],
) -> Result[Unit, PsError] {
  out.clear()

  // Fast path: no escape sequences.
  let mut has_escape = false
  for b in self.data {
    if b == b'#' {
      has_escape = true
      break
    }
  }
  if !has_escape {
    for b in self.data {
      out.push(b)
    }
    return Ok(())
  }

  // Slow path: Process escape sequences.
  let inner = Reader::new(self.data)
  while inner.read_byte() is Some(b) {
    if b == b'#' {
      guard inner.read_bytes(2) is Some(hex) else { return Err(SyntaxError) }
      guard decode_hex_digit(hex[0]) is Some(hi) else {
        return Err(SyntaxError)
      }
      guard decode_hex_digit(hex[1]) is Some(lo) else {
        return Err(SyntaxError)
      }
      out.push((hi << 4) | lo)
    } else {
      out.push(b)
    }
  }
  Ok(())
}

///|
/// Decode the name.
pub fn Name::decode(self : Name) -> Result[Bytes, PsError] {
  let out = []
  match self.decode_into(out) {
    Ok(_) => Ok(Bytes::from_array(out))
    Err(e) => Err(e)
  }
}

///|
fn parse_literal_name(r : Reader) -> BytesView? {
  guard r.forward_tag(b"/") is Some(_) else { return None }
  let start = r.offset()
  while r.eat(is_regular) is Some(_) {

  }
  r.range(start, r.offset())
}

///|
fn parse_executable_name(r : Reader) -> BytesView? {
  let start = r.offset()
  r.forward_while(is_regular)
  if r.offset() == start {
    return None
  }
  r.range(start, r.offset())
}
