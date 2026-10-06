// Port of `hayro-syntax/src/filter/ccitt.rs` (on `hayro/ccitt`).

///|
/// Packs the pixels into 1-bit rows (white = 1), each row padded to the byte
/// boundary.
priv struct CcittBitPackDecoder {
  output : @buffer.Buffer
  mut decoded_rows : UInt
  mut buffer : Int
  mut bit_count : Int
}

///|
fn CcittBitPackDecoder::push_bit(
  self : CcittBitPackDecoder,
  white : Bool,
) -> Unit {
  let bit = if white { 1 } else { 0 }
  self.buffer = ((self.buffer << 1) | bit) & 0xFF
  self.bit_count += 1
  if self.bit_count == 8 {
    self.output.write_byte(self.buffer.to_byte())
    self.buffer = 0
    self.bit_count = 0
  }
}

///|
fn CcittBitPackDecoder::flush(self : CcittBitPackDecoder) -> Unit {
  if self.bit_count > 0 {
    let padded = (self.buffer << (8 - self.bit_count)) & 0xFF
    self.output.write_byte(padded.to_byte())
    self.buffer = 0
    self.bit_count = 0
  }
}

///|
impl @ccitt.Decoder for CcittBitPackDecoder with fn push_pixel(self, white) {
  self.push_bit(white)
}

///|
impl @ccitt.Decoder for CcittBitPackDecoder with fn push_pixel_chunk(
  self,
  white,
  chunk_count,
) {
  let byte : Byte = if white { b'\xFF' } else { b'\x00' }
  for _ in 0U..<chunk_count {
    self.output.write_byte(byte)
  }
}

///|
impl @ccitt.Decoder for CcittBitPackDecoder with fn next_line(self) {
  self.decoded_rows += 1
  self.flush()
}

///|
/// Decodes into 8-bit luma (white = 0xFF).
priv struct CcittLuma8Decoder {
  output : FixedArray[Byte]
  mut idx : Int
  mut decoded_rows : UInt
}

///|
impl @ccitt.Decoder for CcittLuma8Decoder with fn push_pixel(self, white) {
  if !white {
    self.output[self.idx] = b'\x00'
  }
  self.idx += 1
}

///|
impl @ccitt.Decoder for CcittLuma8Decoder with fn push_pixel_chunk(
  self,
  white,
  chunk_count,
) {
  let len = chunk_count.reinterpret_as_int() * 8
  if !white {
    // (upstream panics if the range is out of bounds)
    if self.idx + len > self.output.length() {
      panic()
    }
    self.output.fill(b'\x00', start=self.idx, end=self.idx + len)
  }
  self.idx += len
}

///|
impl @ccitt.Decoder for CcittLuma8Decoder with fn next_line(self) {
  self.decoded_rows += 1
}

///|
fn ccitt_decode(
  data : BytesView,
  params : Dict,
  image_params : ImageDecodeParams,
) -> FilterResult? {
  let k = (params.get("K") : Int?).unwrap_or(0)
  let columns = match (params.get("Columns") : UInt64?) {
    Some(c) => c.to_uint()
    None => 1728U
  }
  let rows = match (params.get("Rows") : UInt?) {
    Some(r) => r
    None => image_params.height.reinterpret_as_uint()
  }
  let output_len = columns.to_uint64() * rows.to_uint64()
  let end_of_block = (params.get("EndOfBlock") : Bool?).unwrap_or(true)
  let settings : @ccitt.DecodeSettings = {
    columns,
    rows,
    end_of_block,
    end_of_line: (params.get("EndOfLine") : Bool?).unwrap_or(false),
    rows_are_byte_aligned: (params.get("EncodedByteAlign") : Bool?).unwrap_or(
      false,
    ),
    encoding: if k < 0 {
      Group4
    } else if k == 0 {
      Group3_1D
    } else {
      Group3_2D(k=k.reinterpret_as_uint())
    },
    invert_black: (params.get("BlackIs1") : Bool?).unwrap_or(false),
  }

  // Whenever possible (if we don't have an indexed color space), we convert
  // the data as 8-bit instead of 1-bit, so that it can be easier converted
  // into an RGBA8 image.
  let (decoded, bpc) = if image_params.is_indexed {
    let decoder : CcittBitPackDecoder = {
      output: Buffer(),
      decoded_rows: 0,
      buffer: 0,
      bit_count: 0,
    }
    let context = @ccitt.DecoderContext::new(settings)
    let failed = try @ccitt.decode(data, decoder, context) catch {
      _ => true
    } noraise {
      _ => false
    }

    // If we decoded at least one row, let's be lenient and return what we got.
    // See also 0001763.pdf.
    if failed && decoder.decoded_rows == 0 {
      return None
    }
    (decoder.output.to_bytes(), 1)
  } else {
    let decoder : CcittLuma8Decoder = {
      output: FixedArray::make(output_len.to_int(), b'\xFF'),
      idx: 0,
      decoded_rows: 0,
    }
    let context = @ccitt.DecoderContext::new(settings)
    let failed = try @ccitt.decode(data, decoder, context) catch {
      _ => true
    } noraise {
      _ => false
    }
    if failed && decoder.decoded_rows == 0 {
      return None
    }
    let output = decoder.output
    // `truncate(idx)` on failure.
    let len = if failed && decoder.idx < output.length() {
      decoder.idx
    } else {
      output.length()
    }
    (Bytes::makei(len, i => output[i]), 8)
  }
  Some({
    data: decoded[:],
    image_data: Some({
      alpha: None,
      color_space: Some(Gray),
      bits_per_component: bpc,
      width: settings.columns.reinterpret_as_int(),
      height: rows.reinterpret_as_int(),
    }),
  })
}
