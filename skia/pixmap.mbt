// Port of `tiny-skia/src/pixmap.rs`.
//
// Pixels are stored as packed premultiplied RGBA `UInt`s (see `color.mbt`).
// `PixmapRef`/`PixmapMut` are not needed: a `Pixmap` is passed by reference.

///|
/// Number of bytes per pixel.
pub let bytes_per_pixel : Int = 4

///|
/// A container that owns premultiplied RGBA pixels.
///
/// The data is not aligned, therefore width == stride.
pub struct Pixmap {
  data : FixedArray[UInt]
  size : @path.IntSize
}

///|
/// Allocates a new pixmap.
///
/// A pixmap is filled with transparent black by default, aka (0, 0, 0, 0).
///
/// Zero size in an error.
///
/// Pixmap's width is limited by i32::MAX/4.
pub fn Pixmap::new(width : UInt, height : UInt) -> Pixmap? {
  guard @path.IntSize::from_wh(width, height) is Some(size) else { return None }
  guard data_len_for_size(size) is Some(len) else { return None }
  Some({ data: FixedArray::make(len, 0), size, })
}

///|
/// Creates a new pixmap by taking ownership over an image buffer
/// (premultiplied RGBA pixels).
pub fn Pixmap::from_vec(
  data : FixedArray[UInt],
  size : @path.IntSize,
) -> Pixmap? {
  guard data_len_for_size(size) is Some(len) else { return None }
  if data.length() != len {
    return None
  }
  Some({ data, size, })
}

///|
/// Creates a new pixmap from premultiplied RGBA bytes.
pub fn Pixmap::from_bytes(
  data : BytesView,
  width : UInt,
  height : UInt,
) -> Pixmap? {
  guard @path.IntSize::from_wh(width, height) is Some(size) else { return None }
  guard data_len_for_size(size) is Some(len) else { return None }
  if data.length() < len * 4 {
    return None
  }
  let pixels = FixedArray::make(len, 0U)
  for i in 0..<len {
    pixels[i] = data[i * 4].to_uint() |
      (data[i * 4 + 1].to_uint() << 8) |
      (data[i * 4 + 2].to_uint() << 16) |
      (data[i * 4 + 3].to_uint() << 24)
  }
  Some({ data: pixels, size, })
}

///|
/// Returns pixmap's width.
pub fn Pixmap::width(self : Pixmap) -> Int {
  self.size.width().reinterpret_as_int()
}

///|
/// Returns pixmap's height.
pub fn Pixmap::height(self : Pixmap) -> Int {
  self.size.height().reinterpret_as_int()
}

///|
pub fn Pixmap::size(self : Pixmap) -> @path.IntSize {
  self.size
}

///|
/// Fills the entire pixmap with a specified color.
pub fn Pixmap::fill(self : Pixmap, color : Color) -> Unit {
  let c = color.premultiply().to_color_u8().0
  self.data.fill(c)
}

///|
/// Returns the internal pixels (packed premultiplied RGBA).
pub fn Pixmap::pixels(self : Pixmap) -> FixedArray[UInt] {
  self.data
}

///|
/// Returns the internal data as RGBA bytes.
pub fn Pixmap::data(self : Pixmap) -> Bytes {
  let len = self.data.length()
  Bytes::makei(len * 4, i => (self.data[i >> 2] >> (8 * (i & 3))).to_byte())
}

///|
/// Returns a pixel color. Returns `None` when position is out of bounds.
pub fn Pixmap::pixel(
  self : Pixmap,
  x : UInt,
  y : UInt,
) -> PremultipliedColorU8? {
  let idx = self.size.width().to_uint64() * y.to_uint64() + x.to_uint64()
  if idx > 0xFFFFFFFFUL || idx >= self.data.length().to_uint64() {
    return None
  }
  Some(PremultipliedColorU8(self.data[idx.to_int()]))
}

///|
/// Returns a copy of the pixmap.
pub fn Pixmap::clone(self : Pixmap) -> Pixmap {
  { data: self.data.copy(), size: self.size, }
}

///|
/// Consumes the internal data with demultiplied RGBA bytes.
pub fn Pixmap::take_demultiplied(self : Pixmap) -> Bytes {
  // Demultiply alpha.
  //
  // RasterPipeline is 15% faster here, but produces slightly different
  // results due to rounding. So we stick with this method for now.
  let len = self.data.length()
  let out = FixedArray::make(len * 4, b'\x00')
  for i in 0..<len {
    let c = PremultipliedColorU8(self.data[i]).demultiply()
    out[i * 4] = c.red().to_byte()
    out[i * 4 + 1] = c.green().to_byte()
    out[i * 4 + 2] = c.blue().to_byte()
    out[i * 4 + 3] = c.alpha().to_byte()
  }
  Bytes::from_array(out)
}

///|
/// Returns a copy of the pixmap intersected by the provided rectangle.
pub fn Pixmap::clone_rect(self : Pixmap, rect : @path.IntRect) -> Pixmap? {
  guard self.rect().to_int_rect().intersect(rect) is Some(rect) else {
    return None
  }
  guard Pixmap::new(rect.width(), rect.height()) is Some(new) else {
    return None
  }
  let w = rect.width().reinterpret_as_int()
  let h = rect.height().reinterpret_as_int()
  for y in 0..<h {
    for x in 0..<w {
      let old_idx = (y + rect.y()) * self.width() + (x + rect.x())
      let new_idx = y * w + x
      new.data[new_idx] = self.data[old_idx]
    }
  }
  Some(new)
}

///|
fn Pixmap::rect(self : Pixmap) -> ScreenIntRect {
  int_size_to_screen_int_rect(self.size, 0, 0)
}

///|
/// Encodes pixmap into a PNG data (demultiplied RGBA, 8 bits), with the `png`
/// crate's default settings (adaptive filter, zlib level 6).
pub fn Pixmap::encode_png(self : Pixmap) -> Bytes {
  let demultiplied_data = self.take_demultiplied()
  @codecs.encode_png_balanced(
    demultiplied_data[:],
    self.width(),
    self.height(),
    Rgba,
  )
}

///|
/// Decodes a PNG data into a `Pixmap`.
///
/// Only 8-bit images are supported. Index PNGs are not supported.
pub fn Pixmap::decode_png(data : BytesView) -> Pixmap raise @codecs.ImageError {
  // `normalize_to_color8`: palette, low bit depths and tRNS expanded, 16-bit
  // stripped. `decode_png` already expands everything to 8/16-bit samples.
  let (info, buf) = @codecs.decode_png(data)
  let width = info.width
  let height = info.height
  guard @path.IntSize::from_wh(width, height) is Some(size) else {
    raise @codecs.ImageError("invalid image size")
  }
  guard data_len_for_size(size) is Some(len) else {
    raise @codecs.ImageError("image is too big")
  }
  let pixels = FixedArray::make(len, 0U)
  let channels = info.color.channel_count()
  let sixteen = info.color is (L16 | La16 | Rgb16 | Rgba16)
  // Samples are stored little-endian for 16-bit images; `strip16` keeps the
  // most significant byte.
  fn sample(i : Int) -> Int {
    if sixteen {
      buf[i * 2 + 1].to_int()
    } else {
      buf[i].to_int()
    }
  }

  for i in 0..<len {
    let base = i * channels
    let (r, g, b, a) = match channels {
      1 => {
        let v = sample(base)
        (v, v, v, alpha_u8_opaque)
      }
      2 => {
        let v = sample(base)
        (v, v, v, sample(base + 1))
      }
      3 => (sample(base), sample(base + 1), sample(base + 2), alpha_u8_opaque)
      _ => (sample(base), sample(base + 1), sample(base + 2), sample(base + 3))
    }
    // Premultiply alpha.
    pixels[i] = pack_rgba(
      premultiply_u8(r, a),
      premultiply_u8(g, a),
      premultiply_u8(b, a),
      a,
    )
  }
  { data: pixels, size, }
}

///|
fn data_len_for_size(size : @path.IntSize) -> Int? {
  let w = size.width().to_uint64()
  let h = size.height().to_uint64()
  // `min_row_bytes`: the row must fit into an `i32` in bytes.
  if w * 4UL > 0x7FFFFFFFUL {
    return None
  }
  let len = w * h
  if len * 4UL > 0x7FFFFFFFUL {
    // Not representable in a MoonBit array; upstream would try to allocate.
    return None
  }
  Some(len.to_int())
}

///|
/// A mutable view into a pixmap (or a mask) region (`SubPixmapMut`).
///
/// `offset` is the index of the region's top-left pixel in `pixels` (RGBA
/// pixmaps) or `bytes` (masks); `real_width` is the row stride.
priv struct SubPixmapMut {
  pixels : FixedArray[UInt]
  bytes : FixedArray[Byte]
  offset : Int
  size : @path.IntSize
  real_width : Int
}

///|
let empty_pixels : FixedArray[UInt] = []

///|
let empty_bytes : FixedArray[Byte] = []

///|
fn SubPixmapMut::offset_of(self : SubPixmapMut, dx : Int, dy : Int) -> Int {
  self.offset + self.real_width * dy + dx
}

///|
fn Pixmap::as_subpixmap(self : Pixmap) -> SubPixmapMut {
  {
    pixels: self.data,
    bytes: empty_bytes,
    offset: 0,
    size: self.size,
    real_width: self.width(),
  }
}

///|
fn Pixmap::subpixmap(self : Pixmap, rect : @path.IntRect) -> SubPixmapMut? {
  guard self.size.to_int_rect(0, 0).intersect(rect) is Some(rect) else {
    return None
  }
  let offset = rect.top() * self.width() + rect.left()
  Some({
    pixels: self.data,
    bytes: empty_bytes,
    offset,
    size: rect.size(),
    real_width: self.width(),
  })
}
