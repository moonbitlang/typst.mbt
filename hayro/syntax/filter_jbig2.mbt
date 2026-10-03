// Port of `hayro-syntax/src/filter/jbig2.rs` (on `hayro/jbig2`).

///|
/// Packs the pixels into 1-bit rows (upstream's `BitWriterDecoder`).
priv struct Jbig2BitWriterDecoder {
  writer : BitWriter
}

///|
impl @jbig2.Decoder for Jbig2BitWriterDecoder with fn push_pixel(self, black) {
  let _ = self.writer.write(if black { 0 } else { 1 })
}

///|
impl @jbig2.Decoder for Jbig2BitWriterDecoder with fn push_pixel_chunk(
  self,
  black,
  chunk_count,
) {
  let byte_value : Byte = if black { 0x00 } else { 0xFF }
  let _ = self.writer.fill_bytes(byte_value, chunk_count.reinterpret_as_int())
}

///|
impl @jbig2.Decoder for Jbig2BitWriterDecoder with fn next_line(self) {
  // Images need to be padded to the byte boundary after each row.
  self.writer.align()
}

///|
/// Expands the pixels to 8-bit luma (upstream's `Luma8Decoder`).
priv struct Jbig2Luma8Decoder {
  output : FixedArray[Byte]
  mut pos : Int
}

///|
impl @jbig2.Decoder for Jbig2Luma8Decoder with fn push_pixel(self, black) {
  if black {
    self.output[self.pos] = 0x00
  }
  self.pos += 1
}

///|
impl @jbig2.Decoder for Jbig2Luma8Decoder with fn push_pixel_chunk(
  self,
  black,
  chunk_count,
) {
  let count = chunk_count.reinterpret_as_int() * 8
  if black {
    // (upstream panics if the range is out of bounds)
    if self.pos + count > self.output.length() {
      panic()
    }
    self.output.fill(0x00, start=self.pos, end=self.pos + count)
  }
  self.pos += count
}

///|
impl @jbig2.Decoder for Jbig2Luma8Decoder with fn next_line(_self) {

}

///|
/// Decode JBIG2 data from a PDF stream.
///
/// The `params` dictionary may contain a `JBIG2Globals` entry pointing to
/// a stream with shared symbol dictionaries.
fn jbig2_decode(
  data : BytesView,
  params : Dict,
  image_params : ImageDecodeParams,
) -> FilterResult? {
  let globals = match (params.get("JBIG2Globals") : Stream?) {
    Some(g) => g.decoded().to_option()
    None => None
  }
  let image = @jbig2.Image::new_embedded(data, globals) catch {
    _ => return None
  }
  let width = image.width()
  let height = image.height()

  // Whenever possible (if we don't have an indexed color space), we convert
  // the data as 8-bit instead of 1-bit, so that it can be easier converted
  // into an RGBA8 image.

  // We need to invert the color because JBIG2 uses black = 1 and
  // white = 0, but PDF uses the opposite.
  let (decoded, bpc) = if image_params.is_indexed {
    let row_bytes = (width.to_int64() + 7) / 8
    let len = row_bytes * height.to_int64()
    // (upstream's `vec!` aborts on such an allocation)
    if len > 0x7FFFFFFFL {
      abort("hayro-syntax: JBIG2 image too large")
    }
    let packed = FixedArray::make(len.to_int(), b'\x00')
    let writer = BitWriter::new(packed, 0, 1)
    let decoder : Jbig2BitWriterDecoder = { writer, }
    image.decode(decoder) catch {
      _ => return None
    }
    (packed, 1)
  } else {
    let len = width.to_int64() * height.to_int64()
    if len > 0x7FFFFFFFL {
      abort("hayro-syntax: JBIG2 image too large")
    }
    let decoder : Jbig2Luma8Decoder = {
      output: FixedArray::make(len.to_int(), b'\xFF'),
      pos: 0,
    }
    image.decode(decoder) catch {
      _ => return None
    }
    (decoder.output, 8)
  }
  Some({
    data: Bytes::from_array(decoded)[:],
    image_data: Some({
      alpha: None,
      color_space: Some(Gray),
      bits_per_component: bpc,
      width: width.reinterpret_as_int(),
      height: height.reinterpret_as_int(),
    }),
  })
}
