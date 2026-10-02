// Port of the parts of the `png` crate's encoder (v0.18.1, `src/encoder.rs`,
// `src/filter/mod.rs`, `src/filter/paeth.rs`) that the `image` crate's
// `PngEncoder` uses with its default settings (`CompressionType::Fast` =
// `DeflateCompression::FdeflateUltraFast`, `FilterType::Adaptive`).

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
/// The ICC profile chunk (`iCCP`) is not supported: upstream compresses it
/// with `flate2`'s default level, which is not ported.
pub fn encode_png(
  data : BytesView,
  width : Int,
  height : Int,
  color : PngColorType,
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
  let zlib_encoded = encode_image_data(data, width, height, color)
  write_chunk(w, b"IDAT", zlib_encoded[:])
  write_chunk(w, b"IEND", b""[:])
  w.to_bytes()
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
  let len = current.length()
  for i in 0..<len {
    let cur = current[i].to_int()
    let a = if i >= bpp { current[i - bpp].to_int() } else { 0 }
    let b = previous[i].to_int()
    let c = if i >= bpp { previous[i - bpp].to_int() } else { 0 }
    let pred = match filter {
      1 => a
      2 => b
      3 => (a + b) / 2
      4 => filter_paeth(a, b, c)
      _ => 0
    }
    output[i + 1] = ((cur - pred) & 0xFF).to_byte()
  }
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
    filter_row(filter, bpp, previous, current, output)
    let cost = sum_buffer(output)
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
