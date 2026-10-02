// Port of `typst-svg/src/image.rs`: rendering of images, images prepared
// for the web platform (`WebImage`) and the CSS `image-rendering`
// conversion.

///|
/// Render an image element.
fn SVGRenderer::render_image(
  _self : SVGRenderer,
  svg : SvgElem,
  state : State,
  image : @library.Image,
  size : @library.Axes[@library.Abs],
) -> Unit {
  // TODO: Images whose web preparation isn't ported (see `WebImage::new`)
  // are written with an empty data URL.
  let url = WebImage::new(image).to_base64_url() catch { _ => "data:," }
  let svg = svg.elem("image")
  if !state.transform.is_identity() {
    svg.attr("transform", SvgTransform(state.transform)) |> ignore
  }
  svg.attr("xlink:href", url) |> ignore
  svg.attr("width", size.x.to_pt()) |> ignore
  svg.attr("height", size.y.to_pt()) |> ignore
  svg.attr("preserveAspectRatio", "none") |> ignore
  if convert_image_scaling(image.scaling()) is Some(value) {
    svg.attr_with("style", attr => {
      attr.push_str("image-rendering: ")
      attr.push_str(value)
    })
    |> ignore
  }
  svg.end()
}

///|
/// Converts an image scaling to a CSS `image-rendering` property value.
pub fn convert_image_scaling(
  scaling : @library.Smart[@library.ImageScaling],
) -> String? {
  match scaling {
    Auto => None
    Custom(Smooth) =>
      // This is still experimental and not implemented in all major
      // browsers.
      // https://developer.mozilla.org/en-US/docs/Web/CSS/image-rendering#browser_compatibility
      Some("smooth")
    Custom(Pixelated) => Some("pixelated")
  }
}

///|
/// An image format supported on the web.
pub(all) enum WebImageFormat {
  Png
  Jpg
  Gif
  Webp
  Svg
} derive(Eq, Debug)

///|
/// The mime type for this format.
pub fn WebImageFormat::mime(self : WebImageFormat) -> String {
  match self {
    Png => "image/png"
    Jpg => "image/jpeg"
    Gif => "image/gif"
    Webp => "image/webp"
    Svg => "image/svg+xml"
  }
}

///|
/// The canonical extension used for this format.
pub fn WebImageFormat::extension(self : WebImageFormat) -> String {
  match self {
    Png => "png"
    Jpg => "jpg"
    Gif => "gif"
    Webp => "webp"
    Svg => "svg"
  }
}

///|
/// An image that is prepared for use in the web platform (SVG or HTML).
pub(all) struct WebImage {
  format : WebImageFormat
  data : Bytes
} derive(Eq, Debug)

///|
/// An error for image kinds whose web preparation is not ported yet.
pub(all) suberror WebImageError {
  WebImageError(String)
} derive(Debug)

///|
/// Prepare an image for embedding in SVG or HTML.
///
/// TODO: Not ported yet: pixel images with an ICC profile (upstream embeds it
/// as an `iCCP` chunk compressed with `flate2`'s default level). These raise
/// a [WebImageError].
pub fn WebImage::new(image : @library.Image) -> WebImage raise WebImageError {
  let (format, data) = match image.kind() {
    Raster(raster) =>
      match raster.format() {
        Exchange(format) =>
          (
            match format {
              Png => WebImageFormat::Png
              Jpg => Jpg
              Gif => Gif
              Webp => Webp
            },
            raster.data(),
          )
        Pixel(_) => {
          if raster.icc() is Some(_) {
            raise WebImageError(
              "embedding ICC profiles in PNG images is not yet ported",
            )
          }
          guard raster.dynamic() is Some(dynamic) else {
            abort("pixel images are always decoded")
          }
          let color : @codecs.PngColorType = match dynamic.color {
            L8 => Grayscale
            La8 => GrayscaleAlpha
            Rgb8 => Rgb
            Rgba8 => Rgba
            _ => abort("pixel images have 8-bit channels")
          }
          let png = @codecs.encode_png(
            dynamic.buf[:],
            dynamic.width.reinterpret_as_int(),
            dynamic.height.reinterpret_as_int(),
            color,
          )
          (WebImageFormat::Png, png)
        }
      }
    Svg(svg) => (WebImageFormat::Svg, svg.data())
    Pdf(pdf) => (WebImageFormat::Svg, @utf8.encode(pdf_to_svg(pdf)))
  }
  { format, data, }
}

///|
/// Turns the image into a base64 URL.
///
/// The format of the URL is `data:{mime};base64,`.
pub fn WebImage::to_base64_url(self : WebImage) -> String {
  "data:\{self.format.mime()};base64," + @base64.encode(self.data[:])
}

///|
/// Select the substitute for one of the 14 PDF standard fonts
/// (`typst_assets::pdf`).
fn select_standard_font(font : @hayro_interpret.StandardFont) -> (Bytes, Int)? {
  let bytes = match font {
    Helvetica => @pdf_fonts.sans()
    HelveticaBold => @pdf_fonts.sans_bold()
    HelveticaOblique => @pdf_fonts.sans_italic()
    HelveticaBoldOblique => @pdf_fonts.sans_bold_italic()
    Courier => @pdf_fonts.fixed()
    CourierBold => @pdf_fonts.fixed_bold()
    CourierOblique => @pdf_fonts.fixed_italic()
    CourierBoldOblique => @pdf_fonts.fixed_bold_italic()
    TimesRoman => @pdf_fonts.serif()
    TimesBold => @pdf_fonts.serif_bold()
    TimesItalic => @pdf_fonts.serif_italic()
    TimesBoldItalic => @pdf_fonts.serif_bold_italic()
    ZapfDingBats => @pdf_fonts.ding_bats()
    Symbol => @pdf_fonts.symbol()
  }
  Some((bytes, 0))
}

///|
// Keep this in sync with `typst-png`!
fn pdf_to_svg(pdf : @library.PdfImage) -> String {
  let interpreter_settings : @hayro_interpret.InterpreterSettings = {
    font_resolver: query => {
      match query {
        Standard(s) => select_standard_font(s)
        Fallback(f) => select_standard_font(f.pick_standard_font())
      }
    },
    cmap_resolver: _ => None,
    warning_sink: _ => (),
    render_annotations: false,
  }
  let cache = @hayro_svg.RenderCache::new()
  @hayro_svg.convert(pdf.page(), cache, interpreter_settings, {
    bg_color: [0, 0, 0, 0],
  })
}
