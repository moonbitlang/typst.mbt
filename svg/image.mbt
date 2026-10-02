// Port of `typst-svg/src/image.rs`: images prepared for the web platform
// (`WebImage`) and the CSS `image-rendering` conversion. The SVG export of
// image frame items (`SVGRenderer::render_image`) is not ported yet.

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
/// TODO: Not ported yet: PDF images (upstream renders the page to SVG with
/// `hayro_svg`) and pixel images with an ICC profile (upstream embeds it as
/// an `iCCP` chunk compressed with `flate2`'s default level). These raise a
/// [WebImageError].
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
    Pdf(_) =>
      raise WebImageError(
        "converting PDF images to SVG is not yet ported (needs `hayro_svg`)",
      )
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
