// Port of `svgtypes` 0.16.1 `src/directional_position.rs`.

///|
/// List of all SVG directional positions.
pub(all) enum DirectionalPosition {
  /// The `top` position.
  Top
  /// The `center` position.
  Center
  /// The `bottom` position.
  Bottom
  /// The `right` position.
  Right
  /// The `left` position.
  Left
} derive(Eq, Debug, Hash)

///|
/// Checks whether the value can be a horizontal position.
pub fn DirectionalPosition::is_horizontal(self : DirectionalPosition) -> Bool {
  self is (Center | Left | Right)
}

///|
/// Checks whether the value can be a vertical position.
pub fn DirectionalPosition::is_vertical(self : DirectionalPosition) -> Bool {
  self is (Center | Top | Bottom)
}

///|
/// `impl From<DirectionalPosition> for Length`.
pub fn Length::from_directional_position(value : DirectionalPosition) -> Length {
  match value {
    Left | Top => Length::new(0.0, LengthUnit::Percent)
    Right | Bottom => Length::new(100.0, LengthUnit::Percent)
    Center => Length::new(50.0, LengthUnit::Percent)
  }
}

///|
pub fn DirectionalPosition::from_str(
  text : String,
) -> DirectionalPosition raise SvgTypesError {
  let s = Stream::from(text)
  let dir_pos = s.parse_directional_position()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  dir_pos
}

///|
/// Parses a directional position [`left`, `center`, `right`, `bottom`, `top`] from the stream.
pub fn Stream::parse_directional_position(
  self : Stream,
) -> DirectionalPosition raise SvgTypesError {
  self.skip_spaces()
  if self.starts_with(b"left") {
    self.advance(4)
    Left
  } else if self.starts_with(b"right") {
    self.advance(5)
    Right
  } else if self.starts_with(b"top") {
    self.advance(3)
    Top
  } else if self.starts_with(b"bottom") {
    self.advance(6)
    Bottom
  } else if self.starts_with(b"center") {
    self.advance(6)
    Center
  } else {
    raise InvalidString(
      [self.slice_tail(), "left", "right", "top", "bottom", "center"],
      self.calc_char_pos(),
    )
  }
}
