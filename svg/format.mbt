// Port of the export options of `typst-svg/src/format.rs` (the `SvgFormat`
// element itself is generated into the library's `elems_gen.mbt`).

///|
/// Document settings for SVG export (upstream
/// `SvgFormatOptions<Complete>`).
pub(all) struct SvgFormatOptions {
  pretty : @library.SpannedValue[Bool]
} derive(Eq)

///|
/// The SVG format options configured by a document (upstream
/// `options.get::<SvgFormat>()`).
pub fn SvgFormatOptions::get(
  options : @library.DocumentFormatOptions,
) -> SvgFormatOptions {
  let o = options.get(@library.svg_format_elem())
  let pretty = o.get(@library.svg_format_elem_pretty)
  { pretty: { v: pretty.v is Bool(true), span: pretty.span, }, }
}

///|
/// Partially specified document settings for SVG export (upstream
/// `SvgFormatOptions<Partial>`).
pub(all) struct PartialSvgFormatOptions {
  pretty : Bool?
} derive(Eq, Default)

///|
/// Resolves the partial options to complete ones, given defaults.
pub fn PartialSvgFormatOptions::resolve(
  self : PartialSvgFormatOptions,
  default : SvgFormatOptions,
) -> SvgFormatOptions {
  {
    pretty: match self.pretty {
      Some(v) => @library.SpannedValue::detached(v)
      None => default.pretty
    },
  }
}
