// Port of `svgtypes` 0.16.1 `src/aspect_ratio.rs`.

///|
/// Representation of the `align` value of the [`preserveAspectRatio`] attribute.
///
/// [`preserveAspectRatio`]: https://www.w3.org/TR/SVG11/coords.html#PreserveAspectRatioAttribute
pub(all) enum Align {
  None
  XMinYMin
  XMidYMin
  XMaxYMin
  XMinYMid
  XMidYMid
  XMaxYMid
  XMinYMax
  XMidYMax
  XMaxYMax
} derive(Eq, Debug, Hash)

///|
/// Representation of the [`preserveAspectRatio`] attribute.
///
/// SVG 2 removed the `defer` keyword, but we still support it.
///
/// [`preserveAspectRatio`]: https://www.w3.org/TR/SVG11/coords.html#PreserveAspectRatioAttribute
pub(all) struct AspectRatio {
  /// `<defer>` value. (Upstream's `defer`; a keyword in MoonBit.)
  ///
  /// Set to `true` when `defer` value is present.
  defer_ : Bool
  /// `<align>` value.
  align : Align
  /// `<meetOrSlice>` value.
  ///
  /// - Set to `true` when `slice` value is present.
  /// - Set to `false` when `meet` value is present or value is not set at all.
  slice : Bool
} derive(Eq, Debug, Hash)

///|
pub fn AspectRatio::from_str(text : String) -> AspectRatio raise SvgTypesError {
  let s = Stream::from(text)
  s.skip_spaces()
  let defer_ = s.starts_with(b"defer")
  if defer_ {
    s.advance(5)
    s.consume_byte(b' ')
    s.skip_spaces()
  }
  let start = s.pos()
  let align = s.consume_ascii_ident()
  let align = match align {
    "none" => Align::None
    "xMinYMin" => Align::XMinYMin
    "xMidYMin" => Align::XMidYMin
    "xMaxYMin" => Align::XMaxYMin
    "xMinYMid" => Align::XMinYMid
    "xMidYMid" => Align::XMidYMid
    "xMaxYMid" => Align::XMaxYMid
    "xMinYMax" => Align::XMinYMax
    "xMidYMax" => Align::XMidYMax
    "xMaxYMax" => Align::XMaxYMax
    _ => raise UnexpectedData(s.calc_char_pos_at(start))
  }
  s.skip_spaces()
  let mut slice = false
  if !s.at_end() {
    let start = s.pos()
    let v = s.consume_ascii_ident()
    match v {
      "meet" => ()
      "slice" => slice = true
      "" => ()
      _ => raise UnexpectedData(s.calc_char_pos_at(start))
    }
  }
  { defer_, align, slice, }
}

///|
pub impl Default for AspectRatio with fn default() {
  { defer_: false, align: Align::XMidYMid, slice: false, }
}

///|
pub extend AspectRatio with Default::{default}
