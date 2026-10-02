// Port of `typst-library/src/visualize/image/raster.rs`: `RasterImage`.
//
// Exchange formats (PNG, JPEG, GIF, WebP) are read by the header parsers of
// the `codecs` package (ports of the `image` crate's decoders' header
// handling and of `kamadak-exif`), which yield everything upstream observes
// without the pixels: dimensions, color type, ICC profile, EXIF orientation
// and pixel density. Decoding the pixels of exchange formats (needed for PNG
// export and for re-encoding) is not ported yet; `RasterImage::dynamic`
// returns `None` for them.

///|
/// Decoded pixels (upstream `image::DynamicImage`): 8-bit samples in
/// row-major order with `color.channel_count()` channels.
pub struct DynamicImage {
  width : UInt
  height : UInt
  color : @codecs.ColorType
  buf : Bytes
} derive(Eq, Hash)

///|
/// A decoded raster image.
pub struct RasterImage {
  priv data : Bytes
  priv format : RasterFormat
  /// The pixel width after applying the EXIF rotation.
  priv width : UInt
  /// The pixel height after applying the EXIF rotation.
  priv height : UInt
  priv color : @codecs.ColorType
  priv dynamic : DynamicImage?
  priv exif_rotation : UInt?
  priv icc : Bytes?
  priv dpi : Double?
}

///|
/// The image is fully defined by data, format, and ICC profile (upstream
/// `Hash for RasterImageInner`).
pub impl Eq for RasterImage with fn equal(self, other) {
  self.data == other.data &&
  self.format == other.format &&
  self.icc == other.icc
}

///|
pub impl Hash for RasterImage with fn hash_combine(self, hasher) {
  hasher.combine(self.data)
  hasher.combine(self.format)
  hasher.combine(self.icc)
}

///|
/// Decode a raster image.
pub fn RasterImage::new(
  data : Bytes,
  format : RasterFormat,
  icc : Smart[Bytes],
) -> RasterImage raise HintedError {
  match format {
    Exchange(format) => {
      let decode = match format {
        Jpg => @codecs.jpeg_image_info
        Png => @codecs.png_image_info
        Gif => @codecs.gif_image_info
        Webp => @codecs.webp_image_info
      }
      let info = decode(data[:]) catch {
        @codecs.ImageError(err) => bail(format_image_error(err))
      }
      let icc = match icc {
        Custom(icc) => Some(icc)
        Auto =>
          match info.icc {
            Some(icc) if !icc.is_empty() => Some(icc)
            _ => None
          }
      }
      let exif = Some(@codecs.read_exif_from_container(data[:])) catch {
        _ => None
      }

      // Apply rotation from EXIF metadata.
      let mut width = info.width
      let mut height = info.height
      let mut exif_rot : UInt? = None
      if exif.bind(exif_rotation) is Some(rotation) {
        if rotation is (5 | 6 | 7 | 8) {
          // These rotations transpose the image.
          width = info.height
          height = info.width
        }
        exif_rot = Some(rotation)
      }

      // Extract pixel density.
      let dpi = determine_dpi(data[:], exif)
      {
        data,
        format: Exchange(format),
        width,
        height,
        color: info.color,
        dynamic: None,
        exif_rotation: exif_rot,
        icc,
        dpi,
      }
    }
    Pixel(format) => {
      if format.width.get() == 0 || format.height.get() == 0 {
        bail("zero-sized images are not allowed")
      }
      let (channels, color) : (UInt64, @codecs.ColorType) = match
        format.encoding {
        Rgb8 => (3, Rgb8)
        Rgba8 => (4, Rgba8)
        Luma8 => (1, L8)
        Lumaa8 => (2, La8)
      }
      let width = format.width.get().reinterpret_as_uint64()
      let height = format.height.get().reinterpret_as_uint64()
      let expected_size = width * height * channels
      if expected_size > 0xFFFFFFFFUL {
        bail("pixel dimensions are too large")
      }
      if expected_size != data.length().to_uint64() {
        bail("pixel dimensions and pixel data do not match")
      }
      let width = width.to_uint()
      let height = height.to_uint()
      let dynamic = { width, height, color, buf: data, }
      {
        data,
        format: Pixel(format),
        width,
        height,
        color,
        dynamic: Some(dynamic),
        exif_rotation: None,
        icc: icc.custom(),
        dpi: None,
      }
    }
  }
}

///|
/// Create a raster image with optional properties set to the default.
pub fn RasterImage::plain(
  data : Bytes,
  format : RasterFormat,
) -> RasterImage raise HintedError {
  RasterImage::new(data, format, Auto)
}

///|
/// The raw image data.
pub fn RasterImage::data(self : RasterImage) -> Bytes {
  self.data
}

///|
/// The image's format.
pub fn RasterImage::format(self : RasterImage) -> RasterFormat {
  self.format
}

///|
/// The image's pixel width.
pub fn RasterImage::width(self : RasterImage) -> UInt {
  self.width
}

///|
/// The image's pixel height.
pub fn RasterImage::height(self : RasterImage) -> UInt {
  self.height
}

///|
/// The color type of the decoded image.
pub fn RasterImage::color(self : RasterImage) -> @codecs.ColorType {
  self.color
}

///|
/// The EXIF orientation value of the original image.
///
/// The [`dynamic`](Self::dynamic) image already has this factored in. This
/// value is only relevant to consumers of the raw [`data`](Self::data).
pub fn RasterImage::exif_rotation(self : RasterImage) -> UInt? {
  self.exif_rotation
}

///|
/// The image's pixel density in pixels per inch, if known.
///
/// This is guaranteed to be positive.
pub fn RasterImage::dpi(self : RasterImage) -> Double? {
  self.dpi
}

///|
/// Access the underlying dynamic image.
///
/// TODO: Only available for pixel formats; the pixels of exchange formats
/// are not decoded yet.
pub fn RasterImage::dynamic(self : RasterImage) -> DynamicImage? {
  self.dynamic
}

///|
/// Access the ICC profile, if any.
pub fn RasterImage::icc(self : RasterImage) -> Bytes? {
  self.icc
}

///|
/// Try to get the rotation from the EXIF metadata.
fn exif_rotation(exif : @codecs.Exif) -> UInt? {
  exif
  .get_field(Tiff, @codecs.exif_tag_orientation, 0)
  .bind(value => value.get_uint(0))
}

///|
/// Try to determine the DPI (dots per inch) of the image.
///
/// This is guaranteed to be a positive value, or `None` if invalid or
/// unspecified.
fn determine_dpi(data : BytesView, exif : @codecs.Exif?) -> Double? {
  // Try to extract the DPI from the EXIF metadata. If that doesn't yield
  // anything, fall back to specialized procedures for extracting JPEG or PNG
  // DPI metadata. GIF does not have any.
  let dpi = match exif.bind(exif_dpi) {
    Some(dpi) => Some(dpi)
    None =>
      match jpeg_dpi(data) {
        Some(dpi) => Some(dpi)
        None => png_dpi(data)
      }
  }
  match dpi {
    Some(dpi) if dpi > 0.0 => Some(dpi)
    _ => None
  }
}

///|
/// Try to get the DPI from the EXIF metadata.
fn exif_dpi(exif : @codecs.Exif) -> Double? {
  fn axis(tag : Int) -> Double? {
    guard exif.get_field(Tiff, tag, 0) is Some(Rational(rational)) else {
      return None
    }
    guard rational is [(num, denom), ..] else { return None }
    Some(num.to_double() / denom.to_double())
  }

  // Upstream `max_by` with `partial_cmp(..).unwrap_or(Equal)`: the later
  // element wins ties and incomparable pairs.
  match
    (axis(@codecs.exif_tag_x_resolution), axis(@codecs.exif_tag_y_resolution)) {
    (Some(x), Some(y)) => Some(if x > y { x } else { y })
    (Some(x), None) => Some(x)
    (None, y) => y
  }
}

///|
/// Tries to extract the DPI from raw JPEG data (by inspecting the JFIF APP0
/// section).
fn jpeg_dpi(data : BytesView) -> Double? {
  fn validate_at(index : Int, expect : Bytes) -> Bool {
    index <= data.length() &&
    data.length() - index >= expect.length() &&
    data[index:index + expect.length()] == expect[:]
  }

  fn u16_at(index : Int) -> Int? {
    if index + 2 > data.length() {
      None
    } else {
      Some((data[index].to_int() << 8) | data[index + 1].to_int())
    }
  }

  guard validate_at(0, b"\xFF\xD8\xFF\xE0\x00") else { return None }
  guard validate_at(6, b"JFIF\x00") else { return None }
  guard validate_at(11, b"\x01") else { return None }
  guard u16_at(4) is Some(len) else { return None }
  if len < 16 {
    return None
  }
  guard data.length() > 13 else { return None }
  let units = data[13].to_int()
  guard u16_at(14) is Some(x) else { return None }
  guard u16_at(16) is Some(y) else { return None }
  let dpu = (if x > y { x } else { y }).to_double()
  match units {
    1 => Some(dpu) // already inches
    2 => Some(dpu * 2.54) // cm -> inches
    _ => None
  }
}

///|
/// Tries to extract the DPI from raw PNG data.
fn png_dpi(data : BytesView) -> Double? {
  let info = @codecs.read_png_info(data) catch { _ => return None }
  guard info.pixel_dims is Some(dims) else { return None }
  let dpu = (if dims.xppu > dims.yppu { dims.xppu } else { dims.yppu }).to_double()
  if dims.meter {
    Some(dpu * 0.0254) // meter -> inches
  } else {
    None
  }
}

///|
/// Format the user-facing raster graphic decoding error message.
fn format_image_error(error : String) -> String {
  "failed to decode image (\{error})"
}
