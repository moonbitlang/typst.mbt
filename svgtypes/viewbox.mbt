// Port of `svgtypes` 0.16.1 `src/viewbox.rs`.

///|
/// List of possible [`ViewBox`] parsing errors.
pub(all) suberror ViewBoxError {
  /// One of the numbers is invalid.
  InvalidNumber
  /// `ViewBox` has a negative or zero size.
  InvalidSize
} derive(Eq, Debug)

///|
/// Upstream's `Display`.
pub impl Show for ViewBoxError with fn output(self, logger) {
  match self {
    InvalidNumber => logger.write_string("viewBox contains an invalid number")
    InvalidSize => logger.write_string("viewBox has a negative or zero size")
  }
}

///|
/// Representation of the [`<viewBox>`] type.
///
/// [`<viewBox>`]: https://www.w3.org/TR/SVG2/coords.html#ViewBoxAttribute
pub(all) struct ViewBox {
  x : Double
  y : Double
  w : Double
  h : Double
} derive(Eq, Debug)

///|
/// Creates a new `ViewBox`.
pub fn ViewBox::new(x : Double, y : Double, w : Double, h : Double) -> ViewBox {
  { x, y, w, h, }
}

///|
pub fn ViewBox::from_str(text : String) -> ViewBox raise ViewBoxError {
  let s = Stream::from(text)
  let x = s.parse_list_number() catch { _ => raise ViewBoxError::InvalidNumber }
  let y = s.parse_list_number() catch { _ => raise ViewBoxError::InvalidNumber }
  let w = s.parse_list_number() catch { _ => raise ViewBoxError::InvalidNumber }
  let h = s.parse_list_number() catch { _ => raise ViewBoxError::InvalidNumber }
  if w <= 0.0 || h <= 0.0 {
    raise InvalidSize
  }
  ViewBox::new(x, y, w, h)
}
