// Port of `svgtypes` 0.16.1 `src/angle.rs`.

///|
/// List of all SVG angle units.
pub(all) enum AngleUnit {
  Degrees
  Gradians
  Radians
  Turns
} derive(Eq, Debug, Hash)

///|
/// Representation of the [`<angle>`] type.
///
/// [`<angle>`]: https://www.w3.org/TR/css-values-3/#angles
pub(all) struct Angle {
  number : Double
  unit : AngleUnit
} derive(Eq, Debug)

///|
/// Constructs a new angle.
pub fn Angle::new(number : Double, unit : AngleUnit) -> Angle {
  { number, unit, }
}

///|
/// Converts angle to degrees.
pub fn Angle::to_degrees(self : Angle) -> Double {
  match self.unit {
    Degrees => self.number
    Gradians => self.number * 180.0 / 200.0
    Radians => f64_to_degrees(self.number)
    Turns => self.number * 360.0
  }
}

///|
pub fn Angle::from_str(text : String) -> Angle raise SvgTypesError {
  let s = Stream::from(text)
  let l = s.parse_angle()
  if !s.at_end() {
    raise UnexpectedData(s.calc_char_pos())
  }
  Angle::new(l.number, l.unit)
}

///|
/// Parses angle from the stream.
///
/// <https://www.w3.org/TR/SVG2/types.html#InterfaceSVGAngle>
///
/// # Notes
///
/// - Suffix must be lowercase, otherwise it will be an error.
pub fn Stream::parse_angle(self : Stream) -> Angle raise SvgTypesError {
  self.skip_spaces()
  let n = self.parse_number()
  if self.at_end() {
    return Angle::new(n, Degrees)
  }
  let u = if self.starts_with(b"deg") {
    self.advance(3)
    AngleUnit::Degrees
  } else if self.starts_with(b"grad") {
    self.advance(4)
    AngleUnit::Gradians
  } else if self.starts_with(b"rad") {
    self.advance(3)
    AngleUnit::Radians
  } else if self.starts_with(b"turn") {
    self.advance(4)
    AngleUnit::Turns
  } else {
    AngleUnit::Degrees
  }
  Angle::new(n, u)
}
