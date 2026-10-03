// Port of `hayro-jbig2/src/bitmap.rs`: bitmap representation for JBIG2
// decoding.
//
// "The variable whose value is the result of this decoding procedure is shown
// in Table 3." (6.2.3)
//
// "GBREG - The decoded region bitmap." (Table 3)

///|
// To guard better against malicious files, we limit bitmap dimensions
// to `u16::MAX`, which should be more than enough.
const MAX_DIMENSION : UInt = 0xFFFF

// The underlying word type for packed pixel storage is `u32` (`UInt`).

///|
const WORD_BITS : UInt = 32

///|
const WORD_BYTES : UInt = 4

///|
const WORD_SHIFT : UInt = 31

///|
/// A decoded bitmap with position information.
///
/// "Pixels decoded by the MMR decoder having the value 'black' shall be treated
/// as having the value 1. Pixels decoded by the MMR decoder having the value
/// 'white' shall be treated as having the value 0." (6.2.6)
///
/// (Bitmaps are shared by reference where upstream clones them; a bitmap is
/// never mutated after it has been stored in a dictionary or region list.)
priv struct Bitmap {
  /// Width in pixels.
  mut width : UInt
  /// Height in pixels.
  mut height : UInt
  /// Number of words per row.
  mut stride : UInt
  /// Packed pixel data, one bit per pixel, row-major order.
  /// Each row is padded to a word boundary.
  mut data : FixedArray[UInt]
  /// "This four-byte field gives the horizontal offset in pixels of the bitmap
  /// encoded in this segment relative to the page bitmap." (7.4.1.3)
  mut x_location : UInt
  /// "This four-byte field gives the vertical offset in pixels of the bitmap
  /// encoded in this segment relative to the page bitmap." (7.4.1.4)
  mut y_location : UInt
}

///|
fn Bitmap::default() -> Bitmap {
  { width: 0, height: 0, stride: 0, data: [], x_location: 0, y_location: 0, }
}

///|
/// Create a new bitmap filled with white pixels (false).
///
/// The bitmap is positioned at (0, 0).
fn Bitmap::new(width : UInt, height : UInt) -> Bitmap raise DecodeError {
  Bitmap::new_with(width, height, 0, 0, false)
}

///|
/// `width.div_ceil(WORD_BITS)`.
fn stride_of(width : UInt) -> UInt {
  (width >> 5) + (if (width & 31) != 0 { 1 } else { 0 })
}

///|
/// Create a new bitmap with full configuration.
fn Bitmap::new_with(
  width : UInt,
  height : UInt,
  x_location : UInt,
  y_location : UInt,
  default_pixel : Bool,
) -> Bitmap raise DecodeError {
  if width > MAX_DIMENSION || height > MAX_DIMENSION {
    raise Overflow(BitmapDimension)
  }
  let stride = stride_of(width)
  let default_word : UInt = if default_pixel { 0xFFFFFFFF } else { 0 }
  let data = FixedArray::make(
    stride.reinterpret_as_int() * height.reinterpret_as_int(),
    default_word,
  )
  { width, height, stride, data, x_location, y_location, }
}

///|
fn Bitmap::reinitialize(
  self : Bitmap,
  width : UInt,
  height : UInt,
  default_pixel : Bool,
) -> Unit raise DecodeError {
  if width > MAX_DIMENSION || height > MAX_DIMENSION {
    raise Overflow(BitmapDimension)
  }
  let stride = stride_of(width)
  let default_word : UInt = if default_pixel { 0xFFFFFFFF } else { 0 }
  self.width = width
  self.height = height
  self.stride = stride
  self.x_location = 0
  self.y_location = 0
  let len = stride.reinterpret_as_int() * height.reinterpret_as_int()
  if self.data.length() == len {
    self.data.fill(default_word)
  } else {
    self.data = FixedArray::make(len, default_word)
  }
}

///|
/// Get a pixel value at (x, y).
#inline
fn Bitmap::get_pixel(self : Bitmap, x : UInt, y : UInt) -> Int {
  if x >= self.width || y >= self.height {
    return 0
  }
  let word_idx = (y * self.stride + x / WORD_BITS).reinterpret_as_int()
  let bit_pos = (WORD_SHIFT - x % WORD_BITS).reinterpret_as_int()
  ((self.data[word_idx] >> bit_pos) & 1).reinterpret_as_int()
}

///|
/// Set a pixel value at (x, y).
#inline
fn Bitmap::set_pixel(self : Bitmap, x : UInt, y : UInt, value : Int) -> Unit {
  if x >= self.width || y >= self.height {
    return
  }
  let word_idx = (y * self.stride + x / WORD_BITS).reinterpret_as_int()
  let bit_pos = (WORD_SHIFT - x % WORD_BITS).reinterpret_as_int()
  self.data[word_idx] = self.data[word_idx] |
    (value.reinterpret_as_uint() << bit_pos)
}

///|
/// Combine another bitmap into this one at a specific location.
///
/// "These operators describe how the segment's bitmap is to be combined with
/// the page bitmap." (7.4.1.5)
///
/// Pixels outside the destination bitmap are ignored.
fn Bitmap::combine(
  self : Bitmap,
  other : Bitmap,
  x : Int,
  y : Int,
  operator : CombinationOperator,
) -> Unit {
  // TODO: Figure out how we can optimize this, especially since this is a
  // bottleneck for symbols/patterns.
  let dest_x_start = if x > 0 { x } else { 0 }
  let dest_x_end = {
    let e = x + other.width.reinterpret_as_int()
    let w = self.width.reinterpret_as_int()
    if e < w {
      e
    } else {
      w
    }
  }
  if dest_x_start >= dest_x_end {
    return
  }
  let src_x_start = (dest_x_start - x).reinterpret_as_uint()
  let dest_x_start = dest_x_start.reinterpret_as_uint()
  let dest_x_end = dest_x_end.reinterpret_as_uint()
  let first_word = dest_x_start / WORD_BITS
  let last_word = (dest_x_end - 1) / WORD_BITS
  for src_y in 0U..<other.height {
    let dest_y = y + src_y.reinterpret_as_int()
    if dest_y < 0 || dest_y >= self.height.reinterpret_as_int() {
      continue
    }
    let dest_y = dest_y.reinterpret_as_uint()
    for word_idx = first_word; word_idx <= last_word; word_idx = word_idx + 1 {
      let word_start_x = word_idx * WORD_BITS
      let word_end_x = word_start_x + WORD_BITS
      let px_start = if dest_x_start > word_start_x {
        dest_x_start
      } else {
        word_start_x
      }
      let px_end = if dest_x_end < word_end_x { dest_x_end } else { word_end_x }
      let bit_start = (px_start - word_start_x).reinterpret_as_int()
      let bit_end = px_end - word_start_x
      let mask : UInt = if bit_end == WORD_BITS {
        0xFFFFFFFFU >> bit_start
      } else {
        (0xFFFFFFFFU >> bit_start) &
        (0xFFFFFFFFU >> bit_end.reinterpret_as_int()).lnot()
      }
      let src_x_for_range = src_x_start + (px_start - dest_x_start)
      let src_word_idx = src_x_for_range / WORD_BITS
      let src_bit_offset = src_x_for_range % WORD_BITS
      let src_word1 = other.get_word(src_y, src_word_idx)
      let src_word2 = other.get_word(src_y, src_word_idx + 1)
      let src_raw = if src_bit_offset == 0 {
        src_word1
      } else {
        (src_word1 << src_bit_offset.reinterpret_as_int()) |
        (src_word2 >> (WORD_BITS - src_bit_offset).reinterpret_as_int())
      }
      let src_aligned = src_raw >> bit_start
      let dest_idx = (dest_y * self.stride + word_idx).reinterpret_as_int()
      let dest_word = self.data[dest_idx]
      let result = match operator {
        Or => dest_word | src_aligned
        And => dest_word & src_aligned
        Xor => dest_word ^ src_aligned
        Xnor => (dest_word ^ src_aligned).lnot()
        Replace => src_aligned
      }
      self.data[dest_idx] = (dest_word & mask.lnot()) | (result & mask)
    }
  }
}

///|
#inline
fn Bitmap::get_word(self : Bitmap, row : UInt, word_idx : UInt) -> UInt {
  if row >= self.height || word_idx >= self.stride {
    return 0
  }
  self.data[(row * self.stride + word_idx).reinterpret_as_int()]
}
