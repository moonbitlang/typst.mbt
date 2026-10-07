// The header of a PNG as the `png` crate (v0.18.1) reports it after
// `Decoder::read_info`: what the chunks before the image data say (`IHDR`,
// `pHYs`, `tRNS`, `iCCP`). The decoder is in `png_stream.mbt` and
// `png_reader.mbt`.

///|
/// Physical pixel dimensions (upstream `png::PixelDimensions`).
pub(all) struct PixelDimensions {
  /// Pixels per unit, X axis
  xppu : UInt
  /// Pixels per unit, Y axis
  yppu : UInt
  /// Whether the unit is the meter (`png::Unit::Meter`) rather than
  /// unspecified.
  meter : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PixelDimensions with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PixelDimensions with @debug.Debug::{to_repr}

///|
/// PNG header information (upstream `png::Info`, partially).
pub(all) struct PngInfo {
  width : UInt
  height : UInt
  bit_depth : Int
  color_type : PngColorType
  interlaced : Bool
  /// Whether a `tRNS` chunk is present.
  trns : Bool
  /// The `pHYs` chunk.
  pixel_dims : PixelDimensions?
  /// The decompressed ICC profile of the `iCCP` chunk.
  icc_profile : Bytes?
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PngInfo with @debug.Debug::{to_repr}

///|
/// Reads the chunks of a PNG up to the first `IDAT` chunk (upstream
/// `png::Decoder::read_info`): the signature, the CRC of every chunk and
/// the contents of the chunks are checked as in `decode_png`.
///
/// `limits=Unlimited` (the default) is `png::StreamingDecoder::new()`, with
/// which Typst reads the pixel dimensions; `limits=Default` is
/// `png::Decoder::new`, with which krilla reads the metadata.
pub fn read_png_info(
  data : BytesView,
  limits? : PngLimits = Unlimited,
) -> PngInfo raise ImageError {
  let reader = PngReader::read_info(data, limits.limits()) catch {
    err => raise image_error_from_png(err)
  }
  let info = reader.info()
  {
    width: info.width,
    height: info.height,
    bit_depth: info.bit_depth,
    color_type: info.color_type,
    interlaced: info.interlaced,
    trns: info.trns is Some(_),
    pixel_dims: info.pixel_dims,
    icc_profile: info.icc_profile,
  }
}

///|
/// The color type after upstream `image`'s `Transformations::EXPAND`.
pub fn PngInfo::output_color_type(self : PngInfo) -> ColorType {
  let sixteen = self.bit_depth == 16
  match self.color_type {
    Grayscale =>
      match (self.trns, sixteen) {
        (false, false) => L8
        (true, false) => La8
        (false, true) => L16
        (true, true) => La16
      }
    GrayscaleAlpha => if sixteen { La16 } else { La8 }
    Rgb =>
      match (self.trns, sixteen) {
        (false, false) => Rgb8
        (true, false) => Rgba8
        (false, true) => Rgb16
        (true, true) => Rgba16
      }
    Indexed => if self.trns { Rgba8 } else { Rgb8 }
    Rgba => if sixteen { Rgba16 } else { Rgba8 }
  }
}

///|
/// Header information as reported by upstream `image::codecs::png::
/// PngDecoder`.
pub fn png_image_info(data : BytesView) -> ImageInfo raise ImageError {
  let info = read_png_info(data)
  {
    width: info.width,
    height: info.height,
    color: info.output_color_type(),
    icc: info.icc_profile,
  }
}
