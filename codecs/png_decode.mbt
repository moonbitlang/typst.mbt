// Port of the header-reading parts of the `png` crate (v0.18.1,
// `src/decoder/stream.rs`): the chunks before the image data (`IHDR`,
// `pHYs`, `tRNS`, `iCCP`). Pixel decoding is not ported.

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
/// Reads the chunks of a PNG up to the first `IDAT` chunk (upstream
/// `png::Decoder::read_info`, without CRC validation).
pub fn read_png_info(data : BytesView) -> PngInfo raise ImageError {
  if !starts_with(data, png_signature[:]) {
    decoding_error("Png", "Invalid PNG signature.")
  }
  let mut pos = 8
  let mut info : PngInfo? = None
  let mut pixel_dims = None
  let mut trns = false
  let mut icc_profile = None
  let mut have_iccp = false
  while true {
    if pos + 8 > data.length() {
      decoding_error("Png", "Unexpected end of data before image end.")
    }
    let len = u32_be(data, pos).reinterpret_as_int()
    let ty = data[pos + 4:pos + 8].to_owned()
    let start = pos + 8
    if len < 0 || start + len + 4 > data.length() {
      decoding_error("Png", "Unexpected end of data within a chunk.")
    }
    let chunk = data[start:start + len]
    if info is None && ty != b"IHDR" {
      decoding_error("Png", "IHDR chunk missing")
    }
    match ty {
      b"IHDR" => {
        if len != 13 {
          decoding_error("Png", "Invalid IHDR chunk")
        }
        let bit_depth = chunk[8].to_int()
        guard PngColorType::from_code(chunk[9].to_int()) is Some(color_type) else {
          decoding_error("Png", "invalid color type (\{chunk[9].to_int()})")
        }
        info = Some({
          width: u32_be(chunk, 0),
          height: u32_be(chunk, 4),
          bit_depth,
          color_type,
          interlaced: chunk[12] != b'\x00',
          trns: false,
          pixel_dims: None,
          icc_profile: None,
        })
      }
      b"pHYs" =>
        if len == 9 && pixel_dims is None && chunk[8].to_int() <= 1 {
          pixel_dims = Some({
            xppu: u32_be(chunk, 0),
            yppu: u32_be(chunk, 4),
            meter: chunk[8] == b'\x01',
          })
        }
      b"tRNS" => trns = true
      b"iCCP" =>
        if !have_iccp {
          have_iccp = true
          // Errors in the chunk's contents are ignored (upstream
          // `let _ = self.parse_iccp_raw()`).
          icc_profile = parse_iccp(chunk)
        }
      b"IDAT" => break
      _ => ()
    }
    pos = start + len + 4
  }
  guard info is Some(info) else { abort("unreachable") }
  { ..info, trns, pixel_dims, icc_profile, }
}

///|
/// Parses an `iCCP` chunk: a profile name (1-79 bytes), a null separator,
/// the compression method (0) and the zlib-compressed profile (upstream
/// `parse_iccp_raw`).
fn parse_iccp(chunk : BytesView) -> Bytes? {
  let mut i = 0
  while true {
    if i >= chunk.length() {
      return None
    }
    let raw = chunk[i]
    if (raw == b'\x00' && i == 0) || (raw != b'\x00' && i == 80) {
      return None
    }
    if raw == b'\x00' {
      break
    }
    i += 1
  }
  if i + 1 >= chunk.length() || chunk[i + 1] != b'\x00' {
    return None
  }
  Some(zlib_decompress(chunk[i + 2:])) catch {
    _ => None
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
