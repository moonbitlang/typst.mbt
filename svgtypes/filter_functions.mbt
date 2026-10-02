// Port of `svgtypes` 0.16.1 `src/filter_functions.rs`.

///|
/// Representation of the [`<filter-function>`] | [`<url>`] type.
///
/// Note that [`Length`] values in this enum do not contain % values.
/// They are disallowed by the spec.
///
/// [`<filter-function>`]: https://www.w3.org/TR/filter-effects-1/#filter-functions
/// [`<url>`]: https://www.w3.org/TR/filter-effects-1/#typedef-filter-url
pub(all) enum FilterValue {
  /// Cannot be negative and/or have a percentage units.
  Blur(Length)
  /// `color`: `currentColor` will be resolved as `None`,
  /// because it should be processed in the same way.
  /// `dx`/`dy`: Cannot have a percentage units.
  /// `std_dev`: Cannot be negative and/or have a percentage units.
  DropShadow(color~ : Color?, dx~ : Length, dy~ : Length, std_dev~ : Length)
  /// Normalized value. Cannot be negative.
  Brightness(Double)
  /// Normalized value. Cannot be negative.
  Contrast(Double)
  /// Normalized value. Cannot be negative.
  Grayscale(Double)
  HueRotate(Angle)
  /// Normalized value. Cannot be negative.
  Invert(Double)
  /// Normalized value. Cannot be negative.
  Opacity(Double)
  /// Normalized value. Cannot be negative.
  Sepia(Double)
  /// Normalized value. Cannot be negative.
  Saturate(Double)
  /// Cannot be empty.
  Url(String)
} derive(Eq, Debug)

///|
/// A list of possible [`FilterValueListParser`] errors.
pub(all) suberror FilterValueListParserError {
  /// Lengths with percentage values are not allowed.
  PercentageValue(Int)
  /// Some values cannot be negative.
  NegativeValue(Int)
  /// An invalid angle value.
  InvalidAngle(Int)
  /// Drop shadow offset values must be set.
  MissingDropShadowOffset(Int)
  /// Usually indicates an empty url.
  InvalidUrl(Int)
  /// Other errors.
  StreamErrors(SvgTypesError)
} derive(Eq, Debug)

///|
/// Upstream's `Display`.
pub impl Show for FilterValueListParserError with fn output(self, logger) {
  match self {
    PercentageValue(pos) =>
      logger.write_string("a percentage value detected at position \{pos}")
    NegativeValue(pos) =>
      logger.write_string("a negative value detected at position \{pos}")
    InvalidAngle(pos) =>
      logger.write_string("an invalid angle at position \{pos}")
    MissingDropShadowOffset(pos) =>
      logger.write_string(
        "drop-shadow offset values are expected at position \{pos}",
      )
    InvalidUrl(pos) => logger.write_string("an invalid url at position \{pos}")
    StreamErrors(e) => Show::output(e, logger)
  }
}

///|
/// A pull-based [`<filter-value-list>`] parser.
///
/// When value is set to `none`, the parser will return `None` immediately.
/// Meaning that an empty string and `none` will produce the same results.
///
/// [`<filter-value-list>`]: https://www.w3.org/TR/filter-effects-1/#typedef-filter-value-list
pub struct FilterValueListParser {
  priv stream : Stream
}

///|
pub fn FilterValueListParser::from(text : String) -> FilterValueListParser {
  { stream: Stream::from(text), }
}

///|
pub fn FilterValueListParser::next(
  self : FilterValueListParser,
) -> Result[FilterValue, FilterValueListParserError]? {
  self.stream.skip_spaces()
  if self.stream.at_end() {
    // an empty attribute is still a valid value
    return None
  }
  if self.stream.starts_with(b"none") {
    self.stream.advance(4)
    self.stream.skip_spaces()
    if self.stream.at_end() {
      return None
    } else {
      self.stream.jump_to_end()
      return Some(Err(StreamErrors(InvalidValue)))
    }
  }
  let res = try self.parse_next() |> Ok catch {
    e => Err(e)
  }
  if res is Err(_) {
    self.stream.jump_to_end()
  }
  Some(res)
}

///|
pub fn FilterValueListParser::iter(
  self : FilterValueListParser,
) -> Iter[Result[FilterValue, FilterValueListParserError]] {
  Iter::new(() => self.next())
}

///|
/// `?` on a stream `Error` (`From<Error> for FilterValueListParserError`).
fn[T] lift(
  f : () -> T raise SvgTypesError,
) -> T raise FilterValueListParserError {
  f() catch {
    e => raise StreamErrors(e)
  }
}

///|
fn FilterValueListParser::parse_next(
  self : FilterValueListParser,
) -> FilterValue raise FilterValueListParserError {
  let s = self.stream
  let start = s.pos()
  let name = s.consume_ascii_ident()
  s.skip_spaces()
  lift(() => s.consume_byte(b'('))
  s.skip_spaces()
  let value = match name {
    "blur" =>
      if s.is_curr_byte_eq(b')') {
        FilterValue::Blur(Length::zero())
      } else {
        let value = parse_filter_positive_length(s)
        FilterValue::Blur(value)
      }
    "drop-shadow" => parse_drop_shadow_func(s)
    "hue-rotate" =>
      if s.is_curr_byte_eq(b')') {
        FilterValue::HueRotate(Angle::new(0.0, AngleUnit::Degrees))
      } else {
        let value = parse_filter_angle(s)
        FilterValue::HueRotate(value)
      }
    "brightness" => FilterValue::Brightness(parse_generic_color_func(s))
    "contrast" => FilterValue::Contrast(parse_generic_color_func(s))
    "grayscale" => FilterValue::Grayscale(parse_generic_color_func(s))
    "invert" => FilterValue::Invert(parse_generic_color_func(s))
    "opacity" => FilterValue::Opacity(parse_generic_color_func(s))
    "saturate" => FilterValue::Saturate(parse_generic_color_func(s))
    "sepia" => FilterValue::Sepia(parse_generic_color_func(s))
    "url" => {
      lift(() => s.consume_byte(b'#'))
      let link = s.consume_bytes((_, c) => c != b' ' && c != b')')
      if !link.is_empty() {
        FilterValue::Url(link)
      } else {
        raise InvalidUrl(s.calc_char_pos_at(start))
      }
    }
    _ => raise StreamErrors(UnexpectedData(s.calc_char_pos_at(start)))
  }
  s.skip_spaces()
  lift(() => s.consume_byte(b')'))
  s.skip_spaces()
  value
}

///|
fn parse_drop_shadow_func(
  s : Stream,
) -> FilterValue raise FilterValueListParserError {
  if s.is_curr_byte_eq(b')') {
    let pos = s.calc_char_pos()
    raise MissingDropShadowOffset(pos)
  }

  // Color can be set before and after lengths.
  let mut color : Color? = None
  let mut is_current_color = false
  if s.try_parse_color() is Some(c) {
    color = Some(c)
    s.skip_spaces()
  } else if s.starts_with(b"currentColor") {
    is_current_color = true
    s.advance(12)
    s.skip_spaces()
  }

  // Offset is the only mandatory value.
  let dx = parse_filter_length(s)
  s.skip_spaces()
  let dy = parse_filter_length(s)
  s.skip_spaces()

  // std_dev is optional
  let mut std_dev = Length::zero()
  try parse_filter_positive_length(s) catch {
    _ => ()
  } noraise {
    v => {
      std_dev = v
      s.skip_spaces()
    }
  }

  // Try to parse a color after length, if it wasn't set before.
  if color is None && !is_current_color {
    if s.try_parse_color() is Some(c) {
      color = Some(c)
      s.skip_spaces()
    } else if s.starts_with(b"currentColor") {
      s.advance(12)
    }
  }
  FilterValue::DropShadow(color~, dx~, dy~, std_dev~)
}

///|
fn parse_generic_color_func(
  s : Stream,
) -> Double raise FilterValueListParserError {
  if s.is_curr_byte_eq(b')') {
    1.0
  } else {
    let start = s.pos()
    let value = lift(() => s.parse_number_or_percent())
    if f64_is_sign_negative(value) {
      let pos = s.calc_char_pos_at(start)
      raise NegativeValue(pos)
    }
    value
  }
}

///|
fn parse_filter_length(s : Stream) -> Length raise FilterValueListParserError {
  let start = s.pos()
  let value = lift(() => s.parse_length())
  if value.unit == LengthUnit::Percent {
    let pos = s.calc_char_pos_at(start)
    raise PercentageValue(pos)
  }
  value
}

///|
fn parse_filter_positive_length(
  s : Stream,
) -> Length raise FilterValueListParserError {
  let start = s.pos()
  let value = lift(() => s.parse_length())
  if f64_is_sign_negative(value.number) {
    let pos = s.calc_char_pos_at(start)
    raise NegativeValue(pos)
  }
  if value.unit == LengthUnit::Percent {
    let pos = s.calc_char_pos_at(start)
    raise PercentageValue(pos)
  }
  value
}

///|
/// Just like a normal angle, but units are mandatory.
fn parse_filter_angle(s : Stream) -> Angle raise FilterValueListParserError {
  s.skip_spaces()
  let start = s.pos()
  let n = lift(() => s.parse_number())
  let u = if s.starts_with(b"deg") {
    s.advance(3)
    AngleUnit::Degrees
  } else if s.starts_with(b"grad") {
    s.advance(4)
    AngleUnit::Gradians
  } else if s.starts_with(b"rad") {
    s.advance(3)
    AngleUnit::Radians
  } else if s.starts_with(b"turn") {
    s.advance(4)
    AngleUnit::Turns
  } else if n == 0.0 {
    // Only zero value allowed to be unit-less.
    AngleUnit::Degrees
  } else {
    let pos = s.calc_char_pos_at(start)
    raise InvalidAngle(pos)
  }
  Angle::new(n, u)
}
