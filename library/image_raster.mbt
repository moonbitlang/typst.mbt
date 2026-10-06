// Port of `typst-library/src/visualize/image/raster.rs`: `RasterImage`.
//
// Exchange formats (PNG, JPEG, GIF, WebP) are decoded by the `codecs`
// package (ports of the decoders the `image` crate uses, driven like
// `image::DynamicImage::from_decoder`, and of `kamadak-exif`).

///|
/// Decoded pixels (upstream `image::DynamicImage`): 8-bit or 16-bit
/// (little-endian) samples in
/// row-major order with `color.channel_count()` channels.
pub struct DynamicImage {
  width : UInt
  height : UInt
  color : @codecs.ColorType
  buf : Bytes
} derive(Eq, Hash)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DynamicImage with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DynamicImage with Hash::{hash, hash_combine}

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
  priv dynamic : DynamicImage
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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RasterImage with Eq::{not_equal, equal}

///|
pub impl Hash for RasterImage with fn hash_combine(self, hasher) {
  hasher.combine(self.data)
  hasher.combine(self.format)
  hasher.combine(self.icc)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RasterImage with Hash::{hash, hash_combine}

///|
/// Decode a raster image.
pub fn RasterImage::new(
  data : Bytes,
  format : RasterFormat,
  icc : Smart[Bytes],
) -> RasterImage raise HintedError {
  match format {
    Exchange(format) => {
      let (info, buf) = decode_exchange(data, format) catch {
        @codecs.ImageError(err) => bail(format_image_error(err))
      }
      let mut dynamic = {
        width: info.width,
        height: info.height,
        color: info.color,
        buf,
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
        dynamic = dynamic.apply_rotation(rotation)
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
        dynamic,
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
        dynamic,
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
pub fn RasterImage::dynamic(self : RasterImage) -> DynamicImage {
  self.dynamic
}

///|
/// Access the ICC profile, if any.
pub fn RasterImage::icc(self : RasterImage) -> Bytes? {
  self.icc
}

///|
/// Decodes an image in an exchange format with the decoder upstream picks
/// (`JpegDecoder`, `PngDecoder`, `GifDecoder` or `WebPDecoder`): the header
/// information (dimensions, color type and ICC profile) and the pixels.
fn decode_exchange(
  data : Bytes,
  format : ExchangeFormat,
) -> (@codecs.ImageInfo, Bytes) raise @codecs.ImageError {
  match format {
    Jpg => @codecs.decode_jpeg(data[:])
    Png => @codecs.decode_png(data[:])
    Gif => @codecs.decode_gif_image(data[:])
    Webp => @codecs.decode_webp_image(data[:])
  }
}

///|
/// The number of bytes per pixel.
fn DynamicImage::bytes_per_pixel(self : DynamicImage) -> Int {
  let bytes = match self.color {
    L8 | La8 | Rgb8 | Rgba8 => 1
    L16 | La16 | Rgb16 | Rgba16 => 2
  }
  self.color.channel_count() * bytes
}

///|
/// Remaps the pixels: `f(x, y)` returns the source pixel of the target pixel
/// `(x, y)` in an image of the given size.
fn DynamicImage::remap(
  self : DynamicImage,
  width : UInt,
  height : UInt,
  f : (Int, Int) -> (Int, Int),
) -> DynamicImage {
  let bpp = self.bytes_per_pixel()
  let w = width.reinterpret_as_int()
  let sw = self.width.reinterpret_as_int()
  let buf = Bytes::makei(self.buf.length(), i => {
    let p = i / bpp
    let (sx, sy) = f(p % w, p / w)
    self.buf[(sy * sw + sx) * bpp + i % bpp]
  })
  { width, height, color: self.color, buf, }
}

///|
/// Apply an EXIF rotation to a dynamic image.
///
/// Like upstream, flips and 180° rotations are done in place through
/// `GenericImage` for `DynamicImage`, which passes every swapped pixel
/// through `Rgba<u8>`: 16-bit samples of those pixels are rounded to 8 bits
/// (lossless for 8-bit images). The 90° rotations are exact.
fn DynamicImage::apply_rotation(
  self : DynamicImage,
  rotation : UInt,
) -> DynamicImage {
  let w = self.width.reinterpret_as_int()
  let h = self.height.reinterpret_as_int()
  // Clockwise.
  let rotate90 = (img : DynamicImage) => {
    img.remap(img.height, img.width, (x, y) => (y, h - 1 - x))
  }
  let rotate270 = (img : DynamicImage) => {
    img.remap(img.height, img.width, (x, y) => (w - 1 - y, x))
  }
  match rotation {
    2 => self.swap_in_place(flip_horizontal_pairs(w, h))
    3 => self.swap_in_place(rotate180_pairs(w, h))
    4 => self.swap_in_place(flip_vertical_pairs(w, h))
    5 => rotate270(self.swap_in_place(flip_horizontal_pairs(w, h)))
    6 => rotate90(self)
    7 => rotate90(self.swap_in_place(flip_horizontal_pairs(w, h)))
    8 => rotate270(self)
    _ => self
  }
}

///|
/// The pixel pairs swapped by upstream `flip_horizontal_in_place`.
fn flip_horizontal_pairs(w : Int, h : Int) -> Array[((Int, Int), (Int, Int))] {
  let pairs = []
  for y in 0..<h {
    for x in 0..<(w / 2) {
      pairs.push(((x, y), (w - x - 1, y)))
    }
  }
  pairs
}

///|
/// The pixel pairs swapped by upstream `flip_vertical_in_place`.
fn flip_vertical_pairs(w : Int, h : Int) -> Array[((Int, Int), (Int, Int))] {
  let pairs = []
  for y in 0..<(h / 2) {
    for x in 0..<w {
      pairs.push(((x, y), (x, h - y - 1)))
    }
  }
  pairs
}

///|
/// The pixel pairs swapped by upstream `rotate180_in_place`.
fn rotate180_pairs(w : Int, h : Int) -> Array[((Int, Int), (Int, Int))] {
  let pairs = []
  for y in 0..<(h / 2) {
    for x in 0..<w {
      pairs.push(((x, y), (w - x - 1, h - y - 1)))
    }
  }
  if h % 2 != 0 {
    let middle = h / 2
    for x in 0..<(w / 2) {
      pairs.push(((x, middle), (w - x - 1, middle)))
    }
  }
  pairs
}

///|
/// Swaps pixel pairs through `Rgba<u8>` (upstream `get_pixel`/`put_pixel`
/// of `GenericImage for DynamicImage`).
fn DynamicImage::swap_in_place(
  self : DynamicImage,
  pairs : Array[((Int, Int), (Int, Int))],
) -> DynamicImage {
  let bpp = self.bytes_per_pixel()
  let sixteen = bpp / self.color.channel_count() == 2
  let w = self.width.reinterpret_as_int()
  let buf = FixedArray::makei(self.buf.length(), i => self.buf[i])
  // A sample after a roundtrip through `u8`.
  let quantize = (lo : Byte, hi : Byte) => {
    let v = lo.to_int() | (hi.to_int() << 8)
    let v8 = (v + 128) / 257
    let v = (v8 << 8) | v8
    (v.to_byte(), (v >> 8).to_byte())
  }
  let read = (x : Int, y : Int) => {
    let start = (y * w + x) * bpp
    let pixel = FixedArray::makei(bpp, k => buf[start + k])
    if sixteen {
      for k = 0; k < bpp; k = k + 2 {
        let (lo, hi) = quantize(pixel[k], pixel[k + 1])
        pixel[k] = lo
        pixel[k + 1] = hi
      }
    }
    pixel
  }
  let write = (x : Int, y : Int, pixel : FixedArray[Byte]) => {
    let start = (y * w + x) * bpp
    for k in 0..<bpp {
      buf[start + k] = pixel[k]
    }
  }
  for pair in pairs {
    let ((x1, y1), (x2, y2)) = pair
    let p1 = read(x1, y1)
    let p2 = read(x2, y2)
    write(x2, y2, p1)
    write(x1, y1, p2)
  }
  { ..self, buf: Bytes::makei(buf.length(), i => buf[i]), }
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
