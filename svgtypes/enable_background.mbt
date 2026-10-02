// Port of `svgtypes` 0.16.1 `src/enable_background.rs`.

///|
/// Representation of the [`enable-background`] attribute.
///
/// [`enable-background`]: https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty
pub(all) enum EnableBackground {
  Accumulate
  New
  NewWithRegion(x~ : Double, y~ : Double, width~ : Double, height~ : Double)
} derive(Eq, Debug)

///|
pub fn EnableBackground::from_str(
  text : String,
) -> EnableBackground raise SvgTypesError {
  let s = Stream::from(text)
  s.skip_spaces()
  if s.starts_with(b"accumulate") {
    s.advance(10)
    s.skip_spaces()
    if !s.at_end() {
      raise UnexpectedData(s.calc_char_pos())
    }
    Accumulate
  } else if s.starts_with(b"new") {
    s.advance(3)
    s.skip_spaces()
    if s.at_end() {
      return New
    }
    let x = s.parse_list_number()
    let y = s.parse_list_number()
    let width = s.parse_list_number()
    let height = s.parse_list_number()
    s.skip_spaces()
    if !s.at_end() {
      raise UnexpectedData(s.calc_char_pos())
    }

    // Region size must be valid;
    if !(width > 0.0 && height > 0.0) {
      raise InvalidValue
    }
    NewWithRegion(x~, y~, width~, height~)
  } else {
    raise InvalidValue
  }
}
