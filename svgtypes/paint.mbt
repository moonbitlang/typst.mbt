// Port of `svgtypes` 0.16.1 `src/paint.rs`.

///|
/// Representation of the fallback part of the [`<paint>`] type.
///
/// Used by the [`Paint`] type.
///
/// [`<paint>`]: https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint
pub(all) enum PaintFallback {
  /// The `none` value.
  None
  /// The `currentColor` value.
  CurrentColor
  /// [`<color>`] value.
  ///
  /// [`<color>`]: https://www.w3.org/TR/css-color-3/
  Color(Color)
} derive(Eq, Debug)

///|
/// Representation of the [`<paint>`] type.
///
/// `<icccolor>` isn't supported.
///
/// [`<paint>`]: https://www.w3.org/TR/SVG2/painting.html#SpecifyingPaint
pub(all) enum Paint {
  /// The `none` value.
  None
  /// The `inherit` value.
  Inherit
  /// The `currentColor` value.
  CurrentColor
  /// [`<color>`] value.
  ///
  /// [`<color>`]: https://www.w3.org/TR/css-color-3/
  Color(Color)
  /// [`<FuncIRI>`] value with an optional fallback.
  ///
  /// [`<FuncIRI>`]: https://www.w3.org/TR/SVG11/types.html#DataTypeFuncIRI
  FuncIRI(String, PaintFallback?)
  /// The `context-fill` value.
  ContextFill
  /// The `context-stroke` value.
  ContextStroke
} derive(Eq, Debug)

///|
/// Parses a `Paint` from a string.
pub fn Paint::from_str(text : String) -> Paint raise SvgTypesError {
  let text = rust_trim(text)
  match text {
    "none" => Paint::None
    "inherit" => Paint::Inherit
    "currentColor" => Paint::CurrentColor
    "context-fill" => Paint::ContextFill
    "context-stroke" => Paint::ContextStroke
    _ => {
      let s = Stream::from(text)
      if s.starts_with(b"url(") {
        let link = s.parse_func_iri() catch { _ => raise InvalidValue }
        s.skip_spaces()

        // get fallback
        if !s.at_end() {
          let fallback = s.slice_tail()
          match fallback {
            "none" => Paint::FuncIRI(link, Some(PaintFallback::None))
            "currentColor" =>
              Paint::FuncIRI(link, Some(PaintFallback::CurrentColor))
            _ => {
              let color = Color::from_str(fallback)
              Paint::FuncIRI(link, Some(PaintFallback::Color(color)))
            }
          }
        } else {
          Paint::FuncIRI(link, Option::None)
        }
      } else {
        Paint::Color(Color::from_str(text) catch { _ => raise InvalidValue })
      }
    }
  }
}
