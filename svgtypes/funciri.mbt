// Port of `svgtypes` 0.16.1 `src/funciri.rs`.

///|
/// Representation of the [`<IRI>`] type.
///
/// [`<IRI>`]: https://www.w3.org/TR/SVG11/types.html#DataTypeIRI
pub(all) struct IRI(String) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IRI with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IRI with @debug.Debug::{to_repr}

///|
/// Parsers a `IRI` from a string.
///
/// By the SVG spec, the ID must contain only [Name] characters,
/// but since no one fallows this it will parse any characters.
///
/// [Name]: https://www.w3.org/TR/xml/#NT-Name
pub fn IRI::from_str(text : String) -> IRI raise SvgTypesError {
  let s = Stream::from(text)
  let link = s.parse_iri()
  s.skip_spaces()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  IRI(link)
}

///|
/// Representation of the [`<FuncIRI>`] type.
///
/// [`<FuncIRI>`]: https://www.w3.org/TR/SVG11/types.html#DataTypeFuncIRI
pub(all) struct FuncIRI(String) derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncIRI with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncIRI with @debug.Debug::{to_repr}

///|
/// Parsers a `FuncIRI` from a string.
///
/// By the SVG spec, the ID must contain only [Name] characters,
/// but since no one fallows this it will parse any characters.
///
/// [Name]: https://www.w3.org/TR/xml/#NT-Name
pub fn FuncIRI::from_str(text : String) -> FuncIRI raise SvgTypesError {
  let s = Stream::from(text)
  let link = s.parse_func_iri()
  s.skip_spaces()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  FuncIRI(link)
}

///|
pub fn Stream::parse_iri(self : Stream) -> String raise SvgTypesError {
  self.skip_spaces()
  self.consume_byte(b'#')
  let link = self.consume_bytes((_, c) => c != b' ')
  if link.is_empty() {
    raise InvalidValue
  }
  link
}

///|
pub fn Stream::parse_func_iri(self : Stream) -> String raise SvgTypesError {
  self.skip_spaces()
  self.consume_string(b"url(")
  self.skip_spaces()
  let quote = match self.curr_byte_opt() {
    Some(b'\'') | Some(b'"') => self.curr_byte_opt()
    _ => None
  }
  if quote is Some(_) {
    self.advance(1)
    self.skip_spaces()
  }
  self.consume_byte(b'#')
  let link = match quote {
    Some(quote) => rust_trim_end(self.consume_bytes((_, c) => c != quote))
    None => self.consume_bytes((_, c) => c != b' ' && c != b')')
  }
  if link.is_empty() {
    raise InvalidValue
  }
  // Non-paired quotes is an error.
  if link.contains_char('\'') || link.contains_char('"') {
    raise InvalidValue
  }
  self.skip_spaces()
  if quote is Some(quote) {
    self.consume_byte(quote)
    self.skip_spaces()
  }
  self.consume_byte(b')')
  link
}

///|
/// Rust `str::trim_end` (Unicode `White_Space`).
fn rust_trim_end(s : String) -> String {
  let mut end = s.length()
  while end > 0 {
    // Step back over one char (a surrogate pair counts as one).
    let mut start = end - 1
    let cu = s.code_unit_at(start).to_int()
    if cu >= 0xDC00 && cu <= 0xDFFF && start > 0 {
      let hi = s.code_unit_at(start - 1).to_int()
      if hi >= 0xD800 && hi <= 0xDBFF {
        start -= 1
      }
    }
    match s.get_char(start) {
      Some(c) if @unicode.is_whitespace(c) => end = start
      _ => break
    }
  }
  s.unsafe_substring(start=0, end~)
}

///|
/// Rust `str::trim` (Unicode `White_Space`).
fn rust_trim(s : String) -> String {
  let s = rust_trim_end(s)
  let mut start = 0
  while start < s.length() {
    match s.get_char(start) {
      Some(c) if @unicode.is_whitespace(c) =>
        start += if c.to_int() > 0xFFFF { 2 } else { 1 }
      _ => break
    }
  }
  s.unsafe_substring(start~, end=s.length())
}
