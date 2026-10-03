// Port of the parts of the `png` crate's encoder (v0.18.1, `src/encoder.rs`,
// `src/filter/mod.rs`, `src/filter/paeth.rs`) that the `image` crate's
// `PngEncoder` uses with its default settings (`CompressionType::Fast` =
// `DeflateCompression::FdeflateUltraFast`, `FilterType::Adaptive`), and that
// `png::Encoder` uses with its own defaults (`Compression::Balanced` =
// `DeflateCompression::Level(6)` through flate2/zlib-rs, `Filter::Adaptive`).

///|
/// The color type of a PNG image.
pub(all) enum PngColorType {
  Grayscale
  Rgb
  Indexed
  GrayscaleAlpha
  Rgba
} derive(Eq, Debug)

///|
/// The numeric code of the color type.
pub fn PngColorType::code(self : PngColorType) -> Int {
  match self {
    Grayscale => 0
    Rgb => 2
    Indexed => 3
    GrayscaleAlpha => 4
    Rgba => 6
  }
}

///|
/// The color type with the given numeric code.
pub fn PngColorType::from_code(n : Int) -> PngColorType? {
  match n {
    0 => Some(Grayscale)
    2 => Some(Rgb)
    3 => Some(Indexed)
    4 => Some(GrayscaleAlpha)
    6 => Some(Rgba)
    _ => None
  }
}

///|
/// The number of samples per pixel.
pub fn PngColorType::samples(self : PngColorType) -> Int {
  match self {
    Grayscale | Indexed => 1
    Rgb => 3
    GrayscaleAlpha => 2
    Rgba => 4
  }
}

///|
let crc_table : FixedArray[UInt] = {
  let table = FixedArray::make(256, 0U)
  for n in 0..<256 {
    let mut c = n.reinterpret_as_uint()
    for _ in 0..<8 {
      c = if (c & 1) != 0 { 0xEDB88320U ^ (c >> 1) } else { c >> 1 }
    }
    table[n] = c
  }
  table
}

///|
/// The CRC-32 checksum of the given bytes (as used by PNG chunks).
pub fn crc32(parts : Array[BytesView]) -> UInt {
  let mut c = 0xFFFFFFFFU
  for part in parts {
    for byte in part {
      c = crc_table[((c ^ byte.to_uint()) & 0xFF).reinterpret_as_int()] ^
        (c >> 8)
    }
  }
  c ^ 0xFFFFFFFFU
}

///|
/// Writes a PNG chunk (length, type, data, CRC).
fn write_chunk(w : Buffer, name : Bytes, data : BytesView) -> Unit {
  write_u32_be(w, data.length().reinterpret_as_uint())
  w.write_bytes(name)
  w.write_bytesview(data)
  write_u32_be(w, crc32([name[:], data]))
}

///|
/// The PNG signature.
let png_signature : Bytes = b"\x89PNG\r\n\x1a\n"

///|
/// Encodes 8-bit image data as a PNG (upstream: `image::codecs::png::
/// PngEncoder::new(..).write_image(..)`).
///
/// The ICC profile chunk (`iCCP`) is not supported (upstream compresses it
/// with `flate2`'s default level, see [zlib_compress]).
pub fn encode_png(
  data : BytesView,
  width : Int,
  height : Int,
  color : PngColorType,
) -> Bytes {
  write_png(width, height, color, encode_image_data(data, width, height, color))
}

///|
/// Writes the PNG signature, the IHDR chunk, the compressed image data and
/// the IEND chunk.
fn write_png(
  width : Int,
  height : Int,
  color : PngColorType,
  zlib_encoded : Bytes,
) -> Bytes {
  let w = Buffer()
  w.write_bytes(png_signature)

  // Encode the IHDR chunk
  let ihdr = FixedArray::make(13, b'\x00')
  for i in 0..<4 {
    ihdr[i] = (width >> (8 * (3 - i))).to_byte()
    ihdr[4 + i] = (height >> (8 * (3 - i))).to_byte()
  }
  ihdr[8] = b'\x08' // bit depth
  ihdr[9] = color.code().to_byte()
  write_chunk(w, b"IHDR", Bytes::makei(13, i => ihdr[i])[:])
  write_zlib_encoded_idat(w, zlib_encoded[:])
  write_chunk(w, b"IEND", b""[:])
  w.to_bytes()
}

///|
/// The maximum length of an IDAT chunk (upstream `MAX_IDAT_CHUNK_LEN`).
const MAX_IDAT_CHUNK_LEN : Int = 0x7FFFFFFF

///|
/// Upstream `Writer::write_zlib_encoded_idat`.
fn write_zlib_encoded_idat(w : Buffer, zlib_encoded : BytesView) -> Unit {
  let mut i = 0
  while i < zlib_encoded.length() {
    let n = @cmp.minimum(MAX_IDAT_CHUNK_LEN, zlib_encoded.length() - i)
    write_chunk(w, b"IDAT", zlib_encoded[i:i + n])
    i += n
  }
}

///|
/// Encodes 8-bit image data as a PNG with the `png` crate's default settings
/// (upstream `png::Encoder::new(w, width, height)` with the given color type
/// and `BitDepth::Eight`, then `write_header()` and `write_image_data(data)`):
/// adaptive filtering and zlib level 6 (`Compression::Balanced`).
pub fn encode_png_balanced(
  data : BytesView,
  width : Int,
  height : Int,
  color : PngColorType,
) -> Bytes {
  write_png(
    width,
    height,
    color,
    encode_image_data_level(data, width, height, color, 6),
  )
}

///|
/// Filters and compresses the image data (upstream
/// `Writer::write_image_data` with `DeflateCompression::Level(level)`).
fn encode_image_data_level(
  data : BytesView,
  width : Int,
  height : Int,
  color : PngColorType,
  level : Int,
) -> Bytes {
  let bpp = color.samples()
  let in_len = width * bpp
  let mut prev = FixedArray::make(in_len, b'\x00')
  let current = FixedArray::make(in_len + 1, b'\x00')
  let line = FixedArray::make(in_len, b'\x00')
  let zlib = ZlibEncoder::new(level)
  let mut line = line
  for y in 0..<height {
    for i in 0..<in_len {
      line[i] = data[y * in_len + i]
    }
    let filter_type = adaptive_filter(bpp, prev, line, current)
    zlib.write_all(Bytes::make(1, filter_type.to_byte())[:])
    zlib.write_all(Bytes::from_array(current[1:])[:])
    // The current line becomes the previous one (instead of a copy).
    let next = prev
    prev = line
    line = next
  }
  zlib.finish()
}

///|
/// Filters and compresses the image data (upstream
/// `Writer::write_image_data` with `DeflateCompression::FdeflateUltraFast`).
fn encode_image_data(
  data : BytesView,
  width : Int,
  height : Int,
  color : PngColorType,
) -> Bytes {
  let bpp = color.samples()
  let in_len = width * bpp
  let mut prev = FixedArray::make(in_len, b'\x00')
  let compressor = Compressor::new()
  let current = FixedArray::make(in_len + 1, b'\x00')
  let line = FixedArray::make(in_len, b'\x00')
  for y in 0..<height {
    for i in 0..<in_len {
      line[i] = data[y * in_len + i]
    }
    let filter_type = adaptive_filter(bpp, prev, line, current)
    current[0] = filter_type.to_byte()
    compressor.write_data(Bytes::makei(in_len + 1, i => current[i])[:])
    prev = line.copy()
  }
  let compressed = compressor.finish()
  if compressed.length() >
    StoredOnlyCompressor::compressed_size((in_len + 1) * height) {
    // Write uncompressed data since the result from fast compression would
    // take more space than that.
    //
    // This is essentially a fallback to NoCompression.
    let compressor = StoredOnlyCompressor::new()
    for y in 0..<height {
      compressor.write_data(b"\x00"[:])
      compressor.write_data(data[y * in_len:(y + 1) * in_len])
    }
    compressor.finish()
  } else {
    compressed
  }
}

///|
/// Upstream `filter_paeth_fpnge`.
fn filter_paeth(a : Int, b : Int, c : Int) -> Int {
  let pa = @cmp.maximum(b, c) - @cmp.minimum(c, b)
  let pb = @cmp.maximum(a, c) - @cmp.minimum(c, a)
  let pc = if (a < c) == (c < b) {
    @cmp.maximum(pa, pb) - @cmp.minimum(pa, pb)
  } else {
    255
  }
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
/// Applies a row filter, writing the filtered row into `output[1..]` (upstream
/// `filter_internal`). Filter codes: 1 = Sub, 2 = Up, 3 = Avg, 4 = Paeth.
fn filter_row(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
) -> Unit {
  filter_row_cost(filter, bpp, previous, current, output, 0xFFFFFFFFFFFFFFFFUL)
  |> ignore
}

///|
/// [filter_row] that also computes [sum_buffer] of the output, giving up
/// (with a partially filtered row) once the cost exceeds `limit`.
/// Specialized loops without bounds checks (performance; same results).
fn filter_row_cost(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
  limit : UInt64,
) -> UInt64 {
  let len = current.length()
  guard previous.length() >= len && output.length() >= len + 1 && bpp >= 0 else {
    abort("index out of bounds")
  }
  let first = if bpp < len { bpp } else { len }
  // Sums of a row are below `2^63` (`255 * len`); the limit is clamped.
  let limit = if limit > 0x7FFFFFFFFFFFFFFFUL {
    0x7FFFFFFFFFFFFFFFL
  } else {
    limit.reinterpret_as_int64()
  }
  let mut sum = 0L
  match filter {
    1 => {
      for i in 0..<first {
        let v = current.unsafe_get(i).to_int()
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
      for i in first..<len {
        let v = (
            current.unsafe_get(i).to_int() -
            current.unsafe_get(i - bpp).to_int()
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    }
    2 =>
      for i in 0..<len {
        let v = (
            current.unsafe_get(i).to_int() - previous.unsafe_get(i).to_int()
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    3 => {
      for i in 0..<first {
        let v = (
            current.unsafe_get(i).to_int() - previous.unsafe_get(i).to_int() / 2
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
      for i in first..<len {
        let a = current.unsafe_get(i - bpp).to_int()
        let b = previous.unsafe_get(i).to_int()
        let v = (current.unsafe_get(i).to_int() - (a + b) / 2) & 0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    }
    4 => {
      for i in 0..<first {
        let v = (
            current.unsafe_get(i).to_int() -
            filter_paeth(0, previous.unsafe_get(i).to_int(), 0)
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
      for i in first..<len {
        let pred = filter_paeth(
          current.unsafe_get(i - bpp).to_int(),
          previous.unsafe_get(i).to_int(),
          previous.unsafe_get(i - bpp).to_int(),
        )
        let v = (current.unsafe_get(i).to_int() - pred) & 0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    }
    _ =>
      for i in 0..<len {
        let v = current.unsafe_get(i).to_int()
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
  }
  sum.reinterpret_as_uint64()
}

///|
/// Sum of the absolute values of the filtered bytes read as `i8`
/// (upstream `sum_buffer`).
fn sum_buffer(buf : FixedArray[Byte]) -> UInt64 {
  let mut sum = 0UL
  for i in 1..<buf.length() {
    let b = buf[i].to_int()
    sum += (if b >= 128 { 256 - b } else { b }).to_uint64()
  }
  sum
}

///|
/// Chooses the filter with the least `sum_buffer` cost (upstream
/// `adaptive_filter`). Returns the filter code; `output[1..]` holds the
/// filtered row.
fn adaptive_filter(
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
) -> Int {
  let mut min_cost = 0xFFFFFFFFFFFFFFFFUL
  let mut filter_choice = 0
  // Up, Sub, Avg, Paeth
  for filter in [2, 1, 3, 4] {
    // A filter whose cost exceeds the minimum so far cannot be chosen, so
    // its computation can stop early (its output is recomputed below if
    // needed).
    let cost = filter_row_cost(filter, bpp, previous, current, output, min_cost)
    if cost <= min_cost {
      min_cost = cost
      filter_choice = filter
      if cost == 0 {
        return filter_choice
      }
    }
  }
  if filter_choice != 4 {
    filter_row(filter_choice, bpp, previous, current, output)
  }
  filter_choice
}
