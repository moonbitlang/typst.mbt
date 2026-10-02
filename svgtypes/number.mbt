// Port of `svgtypes` 0.16.1 `src/number.rs`.

///|
/// An [SVG number](https://www.w3.org/TR/SVG2/types.html#InterfaceSVGNumber).
pub(all) struct Number(Double) derive(Eq, Debug)

///|
pub fn Number::from_str(text : String) -> Number raise SvgTypesError {
  let s = Stream::from(text)
  let n = s.parse_number()
  s.skip_spaces()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  Number(n)
}

///|
/// Parses number from the stream.
///
/// This method will detect a number length and then
/// will pass a substring to the `f64::from_str` method.
///
/// <https://www.w3.org/TR/SVG2/types.html#InterfaceSVGNumber>
///
/// # Errors
///
/// Returns only `InvalidNumber`.
pub fn Stream::parse_number(self : Stream) -> Double raise SvgTypesError {
  // Strip off leading whitespaces.
  self.skip_spaces()
  let start = self.pos()
  if self.at_end() {
    raise InvalidNumber(self.calc_char_pos_at(start))
  }
  self.parse_number_impl() catch {
    _ => raise InvalidNumber(self.calc_char_pos_at(start))
  }
}

///|
fn Stream::parse_number_impl(self : Stream) -> Double raise SvgTypesError {
  let start = self.pos()
  let mut c = self.curr_byte()

  // Consume sign.
  if is_sign(c) {
    self.advance(1)
    c = self.curr_byte()
  }

  // Consume integer.
  match c {
    b'0'..=b'9' => self.skip_digits()
    b'.' => ()
    _ => raise InvalidNumber(0)
  }

  // Consume fraction.
  if self.curr_byte_opt() == Some(b'.') {
    self.advance(1)
    self.skip_digits()
  }
  if self.curr_byte_opt() is Some(c) && (c == b'e' || c == b'E') {
    let c2 = self.next_byte()
    // Check for `em`/`ex`.
    if c2 != b'm' && c2 != b'x' {
      self.advance(1)
      match self.curr_byte() {
        b'+' | b'-' => {
          self.advance(1)
          self.skip_digits()
        }
        b'0'..=b'9' => self.skip_digits()
        _ => raise InvalidNumber(0)
      }
    }
  }
  let s = self.slice_back(start)

  // Use the default f64 parser now.
  // (`f64::from_str` overflows to inf, which is an error below; MoonBit's
  // parser raises instead.)
  let n = @string.parse_double(s) catch { _ => raise InvalidNumber(0) }
  // inf, nan, etc. are an error.
  if !n.is_nan() && !n.is_inf() {
    return n
  }
  raise InvalidNumber(0)
}

///|
/// Parses number from a list of numbers.
pub fn Stream::parse_list_number(self : Stream) -> Double raise SvgTypesError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  let n = self.parse_number()
  self.skip_spaces()
  self.parse_list_separator()
  n
}

///|
/// A pull-based [`<list-of-numbers>`] parser.
///
/// [`<list-of-numbers>`]: https://www.w3.org/TR/SVG2/types.html#InterfaceSVGNumberList
pub struct NumberListParser(Stream)

///|
pub fn NumberListParser::from(v : String) -> NumberListParser {
  NumberListParser(Stream::from(v))
}

///|
pub fn NumberListParser::next(
  self : NumberListParser,
) -> Result[Double, SvgTypesError]? {
  if self.0.at_end() {
    None
  } else {
    let v = try self.0.parse_list_number() |> Ok catch {
      e => Err(e)
    }
    if v is Err(_) {
      self.0.jump_to_end()
    }
    Some(v)
  }
}

///|
pub fn NumberListParser::iter(
  self : NumberListParser,
) -> Iter[Result[Double, SvgTypesError]] {
  Iter::new(() => self.next())
}
