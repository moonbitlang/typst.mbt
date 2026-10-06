// Port of `svgtypes` 0.16.1 `src/length.rs`.

///|
/// List of all SVG length units.
pub(all) enum LengthUnit {
  None
  Em
  Ex
  Px
  In
  Cm
  Mm
  Pt
  Pc
  Percent
} derive(Eq, Debug, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LengthUnit with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LengthUnit with @debug.Debug::{to_repr}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LengthUnit with Hash::{hash, hash_combine}

///|
/// Representation of the [`<length>`] type.
///
/// [`<length>`]: https://www.w3.org/TR/SVG2/types.html#InterfaceSVGLength
pub(all) struct Length {
  number : Double
  unit : LengthUnit
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Length with @debug.Debug::{to_repr}

///|
/// Constructs a new length.
pub fn Length::new(number : Double, unit : LengthUnit) -> Length {
  { number, unit, }
}

///|
/// Constructs a new length with `LengthUnit::None`.
pub fn Length::new_number(number : Double) -> Length {
  { number, unit: LengthUnit::None, }
}

///|
/// Constructs a new length with a zero number.
///
/// Shorthand for: `Length::new(0.0, Unit::None)`.
pub fn Length::zero() -> Length {
  { number: 0.0, unit: LengthUnit::None, }
}

///|
pub impl Default for Length with fn default() {
  Length::zero()
}

///|
pub extend Length with Default::{default}

///|
pub fn Length::from_str(text : String) -> Length raise SvgTypesError {
  let s = Stream::from(text)
  let l = s.parse_length()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  Length::new(l.number, l.unit)
}

///|
/// Parses length from the stream.
///
/// <https://www.w3.org/TR/SVG2/types.html#InterfaceSVGLength>
///
/// # Notes
///
/// - Suffix must be lowercase, otherwise it will be an error.
pub fn Stream::parse_length(self : Stream) -> Length raise SvgTypesError {
  self.skip_spaces()
  let n = self.parse_number()
  if self.at_end() {
    return Length::new(n, LengthUnit::None)
  }
  let u = if self.starts_with(b"%") {
    LengthUnit::Percent
  } else if self.starts_with(b"em") {
    LengthUnit::Em
  } else if self.starts_with(b"ex") {
    LengthUnit::Ex
  } else if self.starts_with(b"px") {
    LengthUnit::Px
  } else if self.starts_with(b"in") {
    LengthUnit::In
  } else if self.starts_with(b"cm") {
    LengthUnit::Cm
  } else if self.starts_with(b"mm") {
    LengthUnit::Mm
  } else if self.starts_with(b"pt") {
    LengthUnit::Pt
  } else if self.starts_with(b"pc") {
    LengthUnit::Pc
  } else {
    LengthUnit::None
  }
  match u {
    LengthUnit::Percent => self.advance(1)
    LengthUnit::None => ()
    _ => self.advance(2)
  }
  Length::new(n, u)
}

///|
/// Parses length from a list of lengths.
pub fn Stream::parse_list_length(self : Stream) -> Length raise SvgTypesError {
  if self.at_end() {
    raise UnexpectedEndOfStream
  }
  let l = self.parse_length()
  self.skip_spaces()
  self.parse_list_separator()
  l
}

///|
/// A pull-based [`<list-of-length>`] parser.
///
/// [`<list-of-length>`]: https://www.w3.org/TR/SVG2/types.html#InterfaceSVGLengthList
pub struct LengthListParser(Stream)

///|
pub fn LengthListParser::from(v : String) -> LengthListParser {
  LengthListParser(Stream::from(v))
}

///|
pub fn LengthListParser::next(
  self : LengthListParser,
) -> Result[Length, SvgTypesError]? {
  if self.0.at_end() {
    None
  } else {
    let v = try self.0.parse_list_length() |> Ok catch {
      e => Err(e)
    }
    if v is Err(_) {
      self.0.jump_to_end()
    }
    Some(v)
  }
}

///|
pub fn LengthListParser::iter(
  self : LengthListParser,
) -> Iter[Result[Length, SvgTypesError]] {
  Iter::new(() => self.next())
}
