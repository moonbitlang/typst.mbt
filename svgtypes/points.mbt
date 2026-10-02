// Port of `svgtypes` 0.16.1 `src/points.rs`.

///|
/// A pull-based [`<list-of-points>`] parser.
///
/// Use it for the `points` attribute of the `polygon` and `polyline` elements.
///
/// # Errors
///
/// - Stops on a first invalid character. Follows the same rules as paths parser.
///
/// # Notes
///
/// - If data contains an odd number of coordinates - the last one will be ignored.
///   As SVG spec states.
/// - It doesn't validate that there are more than two coordinate pairs,
///   which is required by the SVG spec.
///
/// [`<list-of-points>`]: https://www.w3.org/TR/SVG11/shapes.html#PointsBNF
pub struct PointsParser(Stream)

///|
pub fn PointsParser::from(v : String) -> PointsParser {
  PointsParser(Stream::from(v))
}

///|
pub fn PointsParser::next(self : PointsParser) -> (Double, Double)? {
  if self.0.at_end() {
    None
  } else {
    let x = self.0.parse_list_number() catch { _ => return None }
    let y = self.0.parse_list_number() catch { _ => return None }
    Some((x, y))
  }
}

///|
pub fn PointsParser::iter(self : PointsParser) -> Iter[(Double, Double)] {
  Iter::new(() => self.next())
}
