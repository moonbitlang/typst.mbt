// Port of `vello_common/src/pixmap.rs` and `vello_common/src/mask.rs`.

///|
/// A pixmap of premultiplied RGBA8 values backed by a byte buffer.
pub struct Pixmap {
  /// Width of the pixmap in pixels.
  width : Int
  /// Height of the pixmap in pixels.
  height : Int
  /// Buffer of the pixmap in RGBA8 format.
  buf : FixedArray[Byte]
  /// Whether the pixmap may have alpha values that are not 255.
  may_have_transparency : Bool
}

///|
/// Create a new pixmap with the given width and height in pixels.
///
/// All pixels are initialized to transparent black.
pub fn Pixmap::new(width : Int, height : Int) -> Pixmap {
  {
    width,
    height,
    buf: FixedArray::make(width * height * 4, b'\x00'),
    may_have_transparency: true,
  }
}

///|
/// Create a new pixmap with the given premultiplied RGBA8 data, recording
/// whether it may have transparent pixels.
pub fn Pixmap::from_parts_with_opacity(
  data : FixedArray[Byte],
  width : Int,
  height : Int,
  may_have_transparency : Bool,
) -> Pixmap {
  guard data.length() == width * height * 4 else {
    abort("Expected `data` to have length of exactly `width * height`")
  }
  { width, height, buf: data, may_have_transparency }
}

///|
/// Create a new pixmap with the given premultiplied RGBA8 data.
pub fn Pixmap::from_parts(
  data : FixedArray[Byte],
  width : Int,
  height : Int,
) -> Pixmap {
  Pixmap::from_parts_with_opacity(data, width, height, true)
}

///|
pub fn Pixmap::width(self : Pixmap) -> Int {
  self.width
}

///|
pub fn Pixmap::height(self : Pixmap) -> Int {
  self.height
}

///|
/// The premultiplied RGBA8 bytes of the pixmap.
pub fn Pixmap::data(self : Pixmap) -> FixedArray[Byte] {
  self.buf
}

///|
/// Whether the pixmap may have alpha values that are not 255.
pub fn Pixmap::may_have_transparency(self : Pixmap) -> Bool {
  self.may_have_transparency
}

///|
/// The packed pixel (`PremulRgba8::to_u32`, little endian) at an index.
fn Pixmap::sample_idx(self : Pixmap, idx : UInt) -> UInt {
  let i = idx.reinterpret_as_int() * 4
  let b = self.buf
  b[i].to_uint() |
  (b[i + 1].to_uint() << 8) |
  (b[i + 2].to_uint() << 16) |
  (b[i + 3].to_uint() << 24)
}

///|
/// The alpha of the pixel at `(x, y)`.
fn Pixmap::sample_alpha(self : Pixmap, x : Int, y : Int) -> Int {
  self.buf[(self.width * y + x) * 4 + 3].to_int()
}

///|
/// A mask (alpha or luminance) with one byte per pixel.
pub struct Mask {
  priv data : FixedArray[Byte]
  priv width : Int
  priv height : Int
}

///|
/// Create a new alpha mask from the pixmap.
pub fn Mask::new_alpha(pixmap : Pixmap) -> Mask {
  Mask::new_with(pixmap, true)
}

///|
/// Create a new luminance mask from the pixmap.
pub fn Mask::new_luminance(pixmap : Pixmap) -> Mask {
  Mask::new_with(pixmap, false)
}

///|
/// Create a new mask from the given alpha data.
pub fn Mask::from_parts(data : FixedArray[Byte], width : Int, height : Int) -> Mask {
  guard data.length() == width * height else {
    abort("`data` should have `width * height` length")
  }
  { data, width, height }
}

///|
fn Mask::new_with(pixmap : Pixmap, alpha_mask : Bool) -> Mask {
  let n = pixmap.width * pixmap.height
  let data = FixedArray::make(n, b'\x00')
  let buf = pixmap.buf
  for i in 0..<n {
    if alpha_mask {
      data[i] = buf[i * 4 + 3]
    } else {
      let r = Float::from_int(buf[i * 4].to_int()) / 255.0
      let g = Float::from_int(buf[i * 4 + 1].to_int()) / 255.0
      let b = Float::from_int(buf[i * 4 + 2].to_int()) / 255.0
      // See CSS Masking Module Level 1 § 7.10.1 and Filter Effects Module
      // Level 1 § 9.6. Note r, g and b are premultiplied by alpha.
      let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
      data[i] = f32_as_u8(luma * 255.0 + 0.5).to_byte()
    }
  }
  { data, width: pixmap.width, height: pixmap.height }
}

///|
/// Return the width of the mask.
pub fn Mask::width(self : Mask) -> Int {
  self.width
}

///|
/// Return the height of the mask.
pub fn Mask::height(self : Mask) -> Int {
  self.height
}

///|
/// Sample the value at a specific location.
pub fn Mask::sample(self : Mask, x : Int, y : Int) -> Int {
  self.data[y * self.width + x].to_int()
}
