// Port of `svgtypes` 0.16.1 `src/transform_origin.rs`.

///|
priv enum Position {
  Length(Length)
  DirectionalPosition(DirectionalPosition)
}

///|
fn Position::is_vertical(self : Position) -> Bool {
  match self {
    Length(_) => true
    DirectionalPosition(dp) => dp.is_vertical()
  }
}

///|
fn Position::is_horizontal(self : Position) -> Bool {
  match self {
    Length(_) => true
    DirectionalPosition(dp) => dp.is_horizontal()
  }
}

///|
/// `impl From<Position> for Length`.
fn Position::into_length(self : Position) -> Length {
  match self {
    Length(l) => l
    DirectionalPosition(dp) => Length::from_directional_position(dp)
  }
}

///|
/// Representation of the [`<transform-origin>`] type.
///
/// [`<transform-origin>`]: https://drafts.csswg.org/css-transforms/#transform-origin-property
pub(all) struct TransformOrigin {
  /// The x offset of the transform origin.
  x_offset : Length
  /// The y offset of the transform origin.
  y_offset : Length
  /// The z offset of the transform origin.
  z_offset : Length
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TransformOrigin with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TransformOrigin with @debug.Debug::{to_repr}

///|
/// Constructs a new transform origin.
pub fn TransformOrigin::new(
  x_offset : Length,
  y_offset : Length,
  z_offset : Length,
) -> TransformOrigin {
  { x_offset, y_offset, z_offset, }
}

///|
/// List of possible [`TransformOrigin`] parsing errors.
pub(all) suberror TransformOriginError {
  /// One of the numbers is invalid.
  MissingParameters
  /// One of the parameters is invalid.
  InvalidParameters
  /// z-index is not a percentage.
  ZIndexIsPercentage
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TransformOriginError with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TransformOriginError with @debug.Debug::{to_repr}

///|
/// Upstream's `Display`.
pub impl Show for TransformOriginError with fn output(self, logger) {
  match self {
    MissingParameters =>
      logger.write_string("transform origin doesn't have enough parameters")
    InvalidParameters =>
      logger.write_string("transform origin has invalid parameters")
    ZIndexIsPercentage => logger.write_string("z-index cannot be a percentage")
  }
}

///|
pub extend TransformOriginError with Show::{to_string, output}

///|
fn parse_part(stream : Stream) -> Position? {
  try stream.parse_directional_position() catch {
    _ =>
      try stream.parse_length() catch {
        _ => None
      } noraise {
        l => Some(Length(l))
      }
  } noraise {
    dp => Some(DirectionalPosition(dp))
  }
}

///|
pub fn TransformOrigin::from_str(
  text : String,
) -> TransformOrigin raise TransformOriginError {
  let stream = Stream::from(text)
  if stream.at_end() {
    raise MissingParameters
  }
  let first_arg = parse_part(stream)
  let mut second_arg : Position? = None
  let mut third_arg : Length? = None
  if !stream.at_end() {
    stream.skip_spaces()
    stream.parse_list_separator()
    second_arg = match parse_part(stream) {
      Some(p) => Some(p)
      None => raise InvalidParameters
    }
  }
  if !stream.at_end() {
    stream.skip_spaces()
    stream.parse_list_separator()
    third_arg = Some(
      stream.parse_length() catch {
        _ => raise InvalidParameters
      },
    )
  }
  stream.skip_spaces()
  if !stream.at_end() {
    raise InvalidParameters
  }
  match (first_arg, second_arg, third_arg) {
    (Some(p), None, None) => {
      let (x_offset, y_offset) = if p.is_horizontal() {
        (p.into_length(), Length::from_directional_position(Center))
      } else {
        (Length::from_directional_position(Center), p.into_length())
      }
      TransformOrigin::new(x_offset, y_offset, Length::new(0.0, LengthUnit::Px))
    }
    (Some(p1), Some(p2), length) => {
      if length is Some(length) && length.unit == LengthUnit::Percent {
        raise ZIndexIsPercentage
      }
      let length = length.unwrap_or(Length::new(0.0, LengthUnit::Px))
      let check = (pos : Position) => {
        match pos {
          Length(_) => true
          DirectionalPosition(dp) => dp == Center
        }
      }
      let only_keyword_is_center = check(p1) && check(p2)
      if only_keyword_is_center {
        TransformOrigin::new(p1.into_length(), p2.into_length(), length)
      } else if p1.is_horizontal() && p2.is_vertical() {
        // There is at least one of `left`, `right`, `top`, or `bottom`
        TransformOrigin::new(p1.into_length(), p2.into_length(), length)
      } else if p1.is_vertical() && p2.is_horizontal() {
        TransformOrigin::new(p2.into_length(), p1.into_length(), length)
      } else {
        raise InvalidParameters
      }
    }
    // Upstream: `unreachable!()` (reachable for e.g. "-left", where
    // upstream panics).
    _ => abort("internal error: entered unreachable code")
  }
}
