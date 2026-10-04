// Port of `hayro-jbig2/src/decode/generic.rs`: generic region segment parsing
// and decoding (7.4.6, 6.2).

///|
/// Generic region decoding procedure (6.2).
fn generic_decode(
  header : GenericRegionHeader,
  ctx : ScratchBuffers,
) -> RegionBitmap raise DecodeError {
  let bitmap = Bitmap::new_with(
    header.region_info.width,
    header.region_info.height,
    header.region_info.x_location,
    header.region_info.y_location,
    false,
  )
  generic_decode_into(header, bitmap, ctx)
  { bitmap, combination_operator: header.region_info.combination_operator, }
}

///|
fn generic_decode_into(
  header : GenericRegionHeader,
  bitmap : Bitmap,
  ctx : ScratchBuffers,
) -> Unit raise DecodeError {
  let data = header.data
  if header.mmr {
    // "6.2.6 Decoding using MMR coding"
    let _ = decode_bitmap_mmr(bitmap, data)
  } else {
    let decoder = ArithmeticDecoder::new(data)
    let contexts = ctx.reset_contexts(1 << header.template.context_bits())

    // "6.2.5 Decoding using a template and arithmetic coding"
    decode_bitmap_arithmetic_coding(
      bitmap,
      decoder,
      contexts,
      header.template,
      header.tpgdon,
      header.adaptive_template_pixels,
    )
  }
}

///|
/// Parsed generic region segment header (7.4.6.1).
priv struct GenericRegionHeader {
  region_info : RegionSegmentInfo
  mmr : Bool
  template : Template
  tpgdon : Bool
  adaptive_template_pixels : FixedArray[AdaptiveTemplatePixel]
  data : BytesView
}

///|
/// Parse a generic region segment header (7.4.6.1).
fn generic_parse(
  reader : Reader,
  had_unknown_length : Bool,
) -> GenericRegionHeader raise DecodeError {
  let region_info = parse_region_segment_info(reader)
  let flags = ok_or(reader.read_byte(), eof).to_int()
  let mmr = (flags & 0x01) != 0
  let template = Template::from_byte(flags >> 1)
  let tpgdon = (flags & 0x08) != 0
  let ext_template = (flags & 0x10) != 0
  let adaptive_template_pixels = if mmr {
    FixedArray::make(4, AdaptiveTemplatePixel::default())
  } else {
    parse_adaptive_template_pixels(reader, template, ext_template)
  }
  let mut data = ok_or(reader.tail(), eof)

  // "As a special case, as noted in 7.2.7, an immediate generic region segment
  // may have an unknown length. In this case, it also indicates the height of
  // the generic region (i.e. the number of rows that have been decoded in this
  // segment; it must be no greater than the region segment bitmap height value
  // in the segment's region segment information field." (7.4.6.4)
  if had_unknown_length {
    // Length has already been validated during segment parsing.
    // (Upstream's `split_at(data.len() - 4)` panics if the region header
    // consumed part of the end sequence.)
    let split = data.length() - 4
    if split < 0 {
      abort("hayro-jbig2: generic region shorter than its row count")
    }
    let head = data[:split]
    let tail = data[split:]
    let row_count = (tail[0].to_uint() << 24) |
      (tail[1].to_uint() << 16) |
      (tail[2].to_uint() << 8) |
      tail[3].to_uint()
    if row_count > region_info.height {
      raise Region(InvalidDimension)
    }
    region_info.height = row_count
    data = head
  }
  { region_info, mmr, template, tpgdon, adaptive_template_pixels, data, }
}

///|
/// Parse adaptive template pixel positions (7.4.6.3).
fn parse_adaptive_template_pixels(
  reader : Reader,
  template : Template,
  // TODO: Find a test with this flag.
  _ext_template : Bool,
) -> FixedArray[AdaptiveTemplatePixel] raise DecodeError {
  let num_pixels = template.adaptive_template_pixels()
  let pixels = FixedArray::make(4, AdaptiveTemplatePixel::default())
  for i in 0..<num_pixels {
    let x = i8_of(ok_or(reader.read_byte(), eof))
    let y = i8_of(ok_or(reader.read_byte(), eof))

    // Validate AT pixel location (6.2.5.4, Figure 7).
    // AT pixels must reference already-decoded pixels:
    // - y must be <= 0 (current row or above)
    // - if y == 0, x must be < 0 (strictly to the left of current pixel)
    if y > 0 || (y == 0 && x >= 0) {
      raise Template(InvalidAtPixel)
    }
    pixels[i] = { x, y, }
  }
  pixels
}

///|
/// Whether the adaptive template pixels correspond to the default ones.
/// See Table 5.
fn has_default_at_pixels(
  template : Template,
  at_pixels : FixedArray[AdaptiveTemplatePixel],
) -> Bool {
  match template {
    Template0 =>
      at_pixels[0].x == 3 &&
      at_pixels[0].y == -1 &&
      at_pixels[1].x == -3 &&
      at_pixels[1].y == -1 &&
      at_pixels[2].x == 2 &&
      at_pixels[2].y == -2 &&
      at_pixels[3].x == -2 &&
      at_pixels[3].y == -2
    Template1 => at_pixels[0].x == 3 && at_pixels[0].y == -1
    Template2 => at_pixels[0].x == 2 && at_pixels[0].y == -1
    Template3 => at_pixels[0].x == 2 && at_pixels[0].y == -1
  }
}

///|
/// A decoder sink that writes decoded pixels into a `Bitmap`.
priv struct BitmapDecoder {
  bitmap : Bitmap
  mut x : UInt
  mut y : UInt
  /// Precomputed start index into `bitmap.data` for the current row.
  mut row_start : Int
  /// Accumulator for pixels emitted by `push_pixel`.
  mut buf : UInt
  /// Number of bits accumulated in `buf`.
  mut buf_len : UInt
}

///|
fn BitmapDecoder::new(bitmap : Bitmap) -> BitmapDecoder {
  { bitmap, x: 0, y: 0, row_start: 0, buf: 0, buf_len: 0, }
}

///|
#inline
fn BitmapDecoder::flush_buf(self : BitmapDecoder) -> Unit {
  if self.buf_len == 0 {
    return
  }
  let start_x = self.x - self.buf_len
  if start_x < self.bitmap.width {
    let word_idx = (start_x / WORD_BITS).reinterpret_as_int()
    let bit_in_word = start_x % WORD_BITS
    let shift = WORD_SHIFT - bit_in_word - (self.buf_len - 1)
    let idx = self.row_start + word_idx
    self.bitmap.data[idx] = self.bitmap.data[idx] |
      (self.buf << shift.reinterpret_as_int())
  }
  self.buf = 0
  self.buf_len = 0
}

///|
impl @ccitt.Decoder for BitmapDecoder with fn push_pixel(self, white) {
  self.buf = ((self.buf << 1) | (if white { 1 } else { 0 })) & 0xFF
  self.buf_len += 1
  self.x += 1
  if self.buf_len == 8 {
    self.flush_buf()
  }
}

///|
/// `byte_masks[i] = 0xFF << ((WORD_BYTES - 1 - i) * 8)`.
let byte_masks : ReadOnlyArray[UInt] = [
  0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF,
]

///|
impl @ccitt.Decoder for BitmapDecoder with fn push_pixel_chunk(
  self,
  white,
  chunk_count,
) {
  let word_bytes = WORD_BYTES.reinterpret_as_int()
  let row_start = self.row_start
  let end_x = {
    let e = self.x + chunk_count * 8
    if e < self.bitmap.width {
      e
    } else {
      self.bitmap.width
    }
  }
  let white_mask : UInt = if white { 0xFFFFFFFF } else { 0 }
  let start = (self.x / 8).reinterpret_as_int()
  let end = (end_x / 8).reinterpret_as_int()
  let first_full = (start + word_bytes - 1) / word_bytes
  let last_full = end / word_bytes
  let data = self.bitmap.data
  let head_end = if first_full * word_bytes < end {
    first_full * word_bytes
  } else {
    end
  }
  for b in start..<head_end {
    let idx = row_start + b / word_bytes
    data[idx] = data[idx] | (byte_masks[b % word_bytes] & white_mask)
  }
  if last_full > first_full {
    data.fill(
      white_mask,
      start=row_start + first_full,
      end=row_start + last_full,
    )
  }
  let tail_start = (if first_full > last_full { first_full } else { last_full }) *
    word_bytes
  for b in tail_start..<end {
    let idx = row_start + b / word_bytes
    data[idx] = data[idx] | (byte_masks[b % word_bytes] & white_mask)
  }
  self.x = end_x
}

///|
impl @ccitt.Decoder for BitmapDecoder with fn next_line(self) {
  self.flush_buf()
  self.x = 0
  self.y += 1
  self.row_start = (self.y * self.bitmap.stride).reinterpret_as_int()
}

///|
/// Decode a bitmap using MMR coding (6.2.6).
fn decode_bitmap_mmr(
  bitmap : Bitmap,
  data : BytesView,
) -> Int raise DecodeError {
  let width = bitmap.width
  let height = bitmap.height
  let decoder = BitmapDecoder::new(bitmap)
  let settings : @ccitt.DecodeSettings = {
    columns: width,
    rows: height,
    // "If the number of bytes contained in the encoded bitmap is known in
    // advance, then it is permissible for the data stream not to contain
    // an EOFB" (6.2.6). But it _can_ contain it, which is what this
    // flag indicates.
    end_of_block: true,
    end_of_line: false,
    rows_are_byte_aligned: false,
    encoding: Group4,
    // "Pixels decoded by the MMR decoder having the value 'black' shall be
    // treated as having the value 1. Pixels decoded by the MMR decoder
    // having the value 'white' shall be treated as having the value 0."
    // (6.2.6)
    //
    // hayro-ccitt uses 1 for white, 0 for black by default, so we need to
    // invert to match JBIG2 convention.
    invert_black: true,
  }

  // "An invocation of the generic region decoding procedure with MMR equal to
  // 1 shall consume an integral number of bytes, beginning and ending on a
  // byte boundary. This may involve skipping over some bits in the last byte
  // read." (6.2.6)
  //
  // hayro-ccitt already aligns to the byte boundary before returning, so
  // nothing else to do here.
  let context = @ccitt.DecoderContext::new(settings)
  @ccitt.decode(data, decoder, context) catch {
    _ => raise Region(InvalidMmrData)
  }
}

///|
#inline
fn Bitmap::get_row_byte(self : Bitmap, row : UInt, byte_idx : Int) -> UInt {
  let word_idx = byte_idx / 4
  let shift = (3 - byte_idx % 4) * 8
  (
    self.data[row.reinterpret_as_int() * self.stride.reinterpret_as_int() +
    word_idx] >>
    shift
  ) &
  0xff
}

///|
#inline
fn Bitmap::set_row_byte(
  self : Bitmap,
  row : UInt,
  byte_idx : Int,
  value : UInt,
) -> Unit {
  let word_idx = byte_idx / 4
  let shift = (3 - byte_idx % 4) * 8
  let idx = row.reinterpret_as_int() * self.stride.reinterpret_as_int() +
    word_idx
  let mask = 0xffU << shift
  self.data[idx] = (self.data[idx] & mask.lnot()) | ((value & 0xff) << shift)
}

///|
/// `copy_within(src..src + stride, y * stride)` for the TPGDON row copy.
#inline
fn Bitmap::copy_row_from_above(self : Bitmap, y : UInt) -> Unit {
  let stride = self.stride.reinterpret_as_int()
  let src = (y.reinterpret_as_int() - 1) * stride
  self.data.blit_to(
    self.data,
    len=stride,
    src_offset=src,
    dst_offset=src + stride,
  )
}

///|
/// The generic decoding loop for non-default AT pixels (upstream's
/// `decode_loop!` macro).
fn decode_loop(
  bitmap : Bitmap,
  decoder : ArithmeticDecoder,
  contexts : FixedArray[Byte],
  ctx_gatherer : ContextGatherer,
  tpgdon : Bool,
  sltp_context : Int,
) -> Unit {
  let width = bitmap.width
  let height = bitmap.height

  // "1) Set: LTP = 0" (6.2.5.7)
  let mut ltp = false

  // "3) Decode each row as follows:" (6.2.5.7)
  for y in 0U..<height {
    // "b) If TPGDON is 1, then decode a bit using the arithmetic entropy
    // coder" (6.2.5.7)
    if tpgdon {
      let sltp = decoder.read_bit(contexts, sltp_context)
      // "Let SLTP be the value of this bit. Set: LTP = LTP XOR SLTP" (6.2.5.7)
      ltp = ltp != (sltp != 0)
    }

    // "c) If LTP = 1 then set every pixel of the current row of GBREG equal
    // to the corresponding pixel of the row immediately above." (6.2.5.7)
    if ltp {
      // If y == 0, pixels remain the same.
      if y > 0 {
        bitmap.copy_row_from_above(y)
      }
    } else {
      // "d) If LTP = 0 then, from left to right, decode each pixel of the
      // current row of GBREG." (6.2.5.7)
      ctx_gatherer.start_row(bitmap, y)
      for x in 0U..<width {
        ctx_gatherer.maybe_reload_buffers(bitmap, x)
        let context_bits = ctx_gatherer.gather_custom(bitmap, x)
        let pixel = decoder.read_bit(contexts, context_bits)
        let value = pixel.reinterpret_as_int()
        if value != 0 {
          bitmap.set_pixel(x, y, value)
          ctx_gatherer.update_current_row(x, value)
        }
      }
    }
  }
}

///|
/// Upstream's `decode_default_template_fast_loop!` macro.
fn decode_default_template_fast_loop(
  bitmap : Bitmap,
  decoder : ArithmeticDecoder,
  contexts : FixedArray[Byte],
  tpgdon : Bool,
  sltp_context : Int,
  params : DefaultTemplateFastParams,
) -> Unit {
  let prev2_initial_shift = params.prev2_initial_shift
  let prev2_initial_mask = params.prev2_initial_mask
  let prev1_shift = params.prev1_shift
  let prev1_initial_mask = params.prev1_initial_mask
  let shift_mask = params.shift_mask
  let prev2_next_mask = params.prev2_next_mask
  let prev1_next_mask = params.prev1_next_mask
  let mut ltp = false
  let full_bytes = ((bitmap.width - 1) / 8).reinterpret_as_int()
  let last_byte_bits = (((bitmap.width - 1) & 7) + 1).reinterpret_as_int()
  for y in 0U..<bitmap.height {
    if tpgdon {
      let sltp = decoder.read_bit(contexts, sltp_context)
      ltp = ltp != (sltp != 0)
    }
    if ltp {
      if y > 0 {
        bitmap.copy_row_from_above(y)
      }
      continue
    }
    let has_prev2 = y >= 2
    let has_prev1 = y >= 1
    let mut val_prev2 = if has_prev2 {
      bitmap.get_row_byte(y - 2, 0) << prev2_initial_shift
    } else {
      0
    }
    let mut val_prev1 = if has_prev1 {
      bitmap.get_row_byte(y - 1, 0)
    } else {
      0
    }
    let mut context = (val_prev2 & prev2_initial_mask) |
      ((val_prev1 >> prev1_shift) & prev1_initial_mask)
    for byte_idx in 0..<full_bytes {
      val_prev2 = if has_prev2 {
        (val_prev2 << 8) |
        (bitmap.get_row_byte(y - 2, byte_idx + 1) << prev2_initial_shift)
      } else {
        0
      }
      val_prev1 = if has_prev1 {
        (val_prev1 << 8) | bitmap.get_row_byte(y - 1, byte_idx + 1)
      } else {
        0
      }
      let mut byte = 0U
      for bit = 7; bit >= 0; bit = bit - 1 {
        let pixel = decoder.read_bit(contexts, context.reinterpret_as_int())
        byte = byte | (pixel << bit)
        context = ((context & shift_mask) << 1) |
          pixel |
          ((val_prev2 >> bit) & prev2_next_mask) |
          ((val_prev1 >> (bit + prev1_shift)) & prev1_next_mask)
      }
      bitmap.set_row_byte(y, byte_idx, byte)
    }
    val_prev2 = val_prev2 << 8
    val_prev1 = val_prev1 << 8
    let mut byte = 0U
    for k in 0..<last_byte_bits {
      let pixel = decoder.read_bit(contexts, context.reinterpret_as_int())
      byte = byte | (pixel << (7 - k))
      context = ((context & shift_mask) << 1) |
        pixel |
        ((val_prev2 >> (7 - k)) & prev2_next_mask) |
        ((val_prev1 >> (7 + prev1_shift - k)) & prev1_next_mask)
    }
    bitmap.set_row_byte(y, full_bytes, byte)
  }
}

///|
/// Decode a bitmap using arithmetic coding (6.2.5).
fn decode_bitmap_arithmetic_coding(
  bitmap : Bitmap,
  decoder : ArithmeticDecoder,
  contexts : FixedArray[Byte],
  template : Template,
  tpgdon : Bool,
  adaptive_template_pixels : FixedArray[AdaptiveTemplatePixel],
) -> Unit {
  if bitmap.width == 0 || bitmap.height == 0 {
    return
  }
  let ctx_gatherer = ContextGatherer::new(template, adaptive_template_pixels)

  // See Figure 8 - 11.
  let sltp_context = match template {
    Template0 => 0b1001101100100101
    Template1 => 0b0011110010101
    Template2 => 0b0011100101
    Template3 => 0b0110010101
  }
  if ctx_gatherer.use_default_at {
    let params = match template {
      Template0 => default_template0_fast_params
      Template1 => default_template1_fast_params
      Template2 => default_template2_fast_params
      Template3 => default_template3_fast_params
    }
    decode_default_template_fast_loop(
      bitmap, decoder, contexts, tpgdon, sltp_context, params,
    )
  } else {
    decode_loop(bitmap, decoder, contexts, ctx_gatherer, tpgdon, sltp_context)
  }
}

///|
priv struct ContextGatherer {
  template : Template
  at_pixels : FixedArray[AdaptiveTemplatePixel]
  use_default_at : Bool
  /// Used in `maybe_reload_buffers` to determine how far to the right
  /// we might access pixels.
  max_right : UInt
  /// Current position.
  mut cur_y : UInt
  mut cur_x : UInt
  /// Pre-fetched pixel buffers for rows y-2, y-1, y.
  mut buf_m2 : UInt
  mut buf_m1 : UInt
  mut buf_cur : UInt
  /// The current context for all 3 rows.
  mut ctx : Int
}

///|
fn ContextGatherer::new(
  template : Template,
  at_pixels : FixedArray[AdaptiveTemplatePixel],
) -> ContextGatherer {
  let use_default_at = has_default_at_pixels(template, at_pixels)
  let max_right : UInt = match template {
    Template0 | Template1 => if use_default_at { 3 } else { 2 }
    Template2 | Template3 => if use_default_at { 2 } else { 1 }
  }
  {
    template,
    at_pixels,
    use_default_at,
    max_right,
    cur_y: 0,
    buf_m2: 0,
    buf_m1: 0,
    buf_cur: 0,
    cur_x: 0,
    ctx: 0,
  }
}

///|
const SHIFT_MASK_T0 : Int = 0b0110_0011_1100_1110

///|
const SHIFT_MASK_T1 : Int = 0b0001_1101_1110_0110

///|
const SHIFT_MASK_T2 : Int = 0b0000_0011_0111_0010

///|
const SHIFT_MASK_T3 : Int = 0b0000_0011_1100_1110

///|
const SHIFT_MASK_T0_DEFAULT : Int = 0b1111_0111_1110_1110

///|
const SHIFT_MASK_T1_DEFAULT : Int = 0b0001_1101_1111_0110

///|
const SHIFT_MASK_T2_DEFAULT : Int = 0b0000_0011_0111_1010

///|
const SHIFT_MASK_T3_DEFAULT : Int = 0b0000_0011_1110_1110

///|
fn ContextGatherer::start_row(
  self : ContextGatherer,
  bitmap : Bitmap,
  y : UInt,
) -> Unit {
  self.cur_y = y
  self.cur_x = 0
  self.buf_m2 = if y >= 2 { load_word(bitmap, y - 2, 0) } else { 0 }
  self.buf_m1 = if y >= 1 { load_word(bitmap, y - 1, 0) } else { 0 }
  self.buf_cur = 0

  // Start initializing the contexts. Note that this won't load all initial
  // pixels yet, those will only be loaded after our first call to `gather`.
  // See 6.2.5.3 for the pixel positions.
  self.ctx = if self.use_default_at {
    self.init_context_default()
  } else {
    self.init_context_custom()
  }
}

///|
fn ContextGatherer::init_context_custom(self : ContextGatherer) -> Int {
  match self.template {
    Template0 => {
      let m2 = get_buf_pixel(self.buf_m2, 0)
      let m1 = (get_buf_pixel(self.buf_m1, 0) << 1) |
        get_buf_pixel(self.buf_m1, 1)
      (m2 << 12) | (m1 << 5)
    }
    Template1 => {
      let m2 = (get_buf_pixel(self.buf_m2, 0) << 1) |
        get_buf_pixel(self.buf_m2, 1)
      let m1 = (get_buf_pixel(self.buf_m1, 0) << 1) |
        get_buf_pixel(self.buf_m1, 1)
      (m2 << 9) | (m1 << 4)
    }
    Template2 => {
      let m2 = get_buf_pixel(self.buf_m2, 0)
      let m1 = get_buf_pixel(self.buf_m1, 0)
      (m2 << 7) | (m1 << 3)
    }
    Template3 => {
      let m1 = get_buf_pixel(self.buf_m1, 0)
      m1 << 5
    }
  }
}

///|
fn ContextGatherer::init_context_default(self : ContextGatherer) -> Int {
  match self.template {
    Template0 =>
      (get_buf_pixel(self.buf_m2, 0) << 12) |
      (get_buf_pixel(self.buf_m2, 1) << 11) |
      (get_buf_pixel(self.buf_m1, 0) << 6) |
      (get_buf_pixel(self.buf_m1, 1) << 5) |
      (get_buf_pixel(self.buf_m1, 2) << 4)
    Template1 =>
      (get_buf_pixel(self.buf_m2, 0) << 10) |
      (get_buf_pixel(self.buf_m2, 1) << 9) |
      (get_buf_pixel(self.buf_m1, 0) << 5) |
      (get_buf_pixel(self.buf_m1, 1) << 4) |
      (get_buf_pixel(self.buf_m1, 2) << 3)
    Template2 =>
      (get_buf_pixel(self.buf_m2, 0) << 7) |
      (get_buf_pixel(self.buf_m1, 0) << 3) |
      (get_buf_pixel(self.buf_m1, 1) << 2)
    Template3 =>
      (get_buf_pixel(self.buf_m1, 0) << 5) |
      (get_buf_pixel(self.buf_m1, 1) << 4)
  }
}

///|
/// `ContextGatherer::load_word`.
#inline
fn load_word(bitmap : Bitmap, row_y : UInt, start_x : UInt) -> UInt {
  let word_idx = start_x / WORD_BITS
  if start_x % WORD_BITS == 0 {
    bitmap.get_word(row_y, word_idx)
  } else {
    let bit_offset = (start_x % WORD_BITS).reinterpret_as_int()
    let word1 = bitmap.get_word(row_y, word_idx)
    let word2 = bitmap.get_word(row_y, word_idx + 1)
    (word1 << bit_offset) | (word2 >> (32 - bit_offset))
  }
}

///|
/// `ContextGatherer::get_buf_pixel`.
#inline
fn get_buf_pixel(buf : UInt, pos : UInt) -> Int {
  if pos < WORD_BITS {
    ((buf >> (WORD_SHIFT - pos).reinterpret_as_int()) & 1).reinterpret_as_int()
  } else {
    0
  }
}

///|
#inline
fn ContextGatherer::maybe_reload_buffers(
  self : ContextGatherer,
  bitmap : Bitmap,
  x : UInt,
) -> Unit {
  if x + self.max_right >= self.cur_x + WORD_BITS {
    let new_start = if x >= 4 { x - 4 } else { 0 }
    self.cur_x = new_start
    self.buf_m2 = if self.cur_y >= 2 {
      load_word(bitmap, self.cur_y - 2, new_start)
    } else {
      0
    }
    self.buf_m1 = if self.cur_y >= 1 {
      load_word(bitmap, self.cur_y - 1, new_start)
    } else {
      0
    }
    self.buf_cur = load_word(bitmap, self.cur_y, new_start)
  }
}

///|
/// `(xi + d) as u32` for an AT pixel offset.
#inline
fn at_coord(v : Int, d : Int) -> UInt {
  (v + d).reinterpret_as_uint()
}

///|
/// Upstream's `gather_template{0,1,2,3}_custom` (picked per template by the
/// `decode_loop!` macro).
#inline
fn ContextGatherer::gather_custom(
  self : ContextGatherer,
  bitmap : Bitmap,
  x : UInt,
) -> Int {
  let bx = x - self.cur_x
  let xi = x.reinterpret_as_int()
  let yi = self.cur_y.reinterpret_as_int()
  let at = self.at_pixels
  match self.template {
    Template0 => {
      let new_pixels = (get_buf_pixel(self.buf_m2, bx + 1) << 12) |
        (get_buf_pixel(self.buf_m1, bx + 2) << 5) |
        get_buf_pixel(self.buf_cur, bx - 1) |
        // Note that the cast from i32 to u32 is deliberate here: Negative positions
        // should be resolved to 0, by casting negative i32 to u32 we end up with
        // a very large positive number which is guaranteed to be OOB. The same
        // applies to all other occurrences of this pattern (also in `generic_refinement.rs`).
        (bitmap.get_pixel(at_coord(xi, at[3].x), at_coord(yi, at[3].y)) << 15) |
        (bitmap.get_pixel(at_coord(xi, at[2].x), at_coord(yi, at[2].y)) << 11) |
        (bitmap.get_pixel(at_coord(xi, at[1].x), at_coord(yi, at[1].y)) << 10) |
        (bitmap.get_pixel(at_coord(xi, at[0].x), at_coord(yi, at[0].y)) << 4)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T0) | new_pixels
    }
    Template1 => {
      let new_pixels = (get_buf_pixel(self.buf_m2, bx + 2) << 9) |
        (get_buf_pixel(self.buf_m1, bx + 2) << 4) |
        get_buf_pixel(self.buf_cur, bx - 1) |
        (bitmap.get_pixel(at_coord(xi, at[0].x), at_coord(yi, at[0].y)) << 3)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T1) | new_pixels
    }
    Template2 => {
      let new_pixels = (get_buf_pixel(self.buf_m2, bx + 1) << 7) |
        (get_buf_pixel(self.buf_m1, bx + 1) << 3) |
        get_buf_pixel(self.buf_cur, bx - 1) |
        (bitmap.get_pixel(at_coord(xi, at[0].x), at_coord(yi, at[0].y)) << 2)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T2) | new_pixels
    }
    Template3 => {
      let new_pixels = (get_buf_pixel(self.buf_m1, bx + 1) << 5) |
        get_buf_pixel(self.buf_cur, bx - 1) |
        (bitmap.get_pixel(at_coord(xi, at[0].x), at_coord(yi, at[0].y)) << 4)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T3) | new_pixels
    }
  }
  self.ctx
}

///|
/// Upstream's `gather_template{0,1,2,3}_default` (picked per template by the
/// `gs_decode_loop!` macro of `gray_scale.rs`).
#inline
fn ContextGatherer::gather_default(
  self : ContextGatherer,
  _bitmap : Bitmap,
  x : UInt,
) -> Int {
  let bx = x - self.cur_x
  match self.template {
    Template0 => {
      let new_pixels = (get_buf_pixel(self.buf_m2, bx + 2) << 11) |
        (get_buf_pixel(self.buf_m1, bx + 3) << 4) |
        get_buf_pixel(self.buf_cur, bx - 1)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T0_DEFAULT) | new_pixels
    }
    Template1 => {
      let new_pixels = (get_buf_pixel(self.buf_m2, bx + 2) << 9) |
        (get_buf_pixel(self.buf_m1, bx + 3) << 3) |
        get_buf_pixel(self.buf_cur, bx - 1)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T1_DEFAULT) | new_pixels
    }
    Template2 => {
      let new_pixels = (get_buf_pixel(self.buf_m2, bx + 1) << 7) |
        (get_buf_pixel(self.buf_m1, bx + 2) << 2) |
        get_buf_pixel(self.buf_cur, bx - 1)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T2_DEFAULT) | new_pixels
    }
    Template3 => {
      let new_pixels = (get_buf_pixel(self.buf_m1, bx + 2) << 4) |
        get_buf_pixel(self.buf_cur, bx - 1)
      self.ctx = ((self.ctx << 1) & SHIFT_MASK_T3_DEFAULT) | new_pixels
    }
  }
  self.ctx
}

///|
/// Note: The caller must ensure that `gather` has been called for this `x`
/// first.
#inline
fn ContextGatherer::update_current_row(
  self : ContextGatherer,
  x : UInt,
  value : Int,
) -> Unit {
  let bit_pos = (WORD_SHIFT - (x - self.cur_x)).reinterpret_as_int()
  let mask = 1U << bit_pos
  self.buf_cur = (self.buf_cur & mask.lnot()) |
    (value.reinterpret_as_uint() << bit_pos)
}

///|
priv struct DefaultTemplateFastParams {
  prev2_initial_shift : Int
  prev2_initial_mask : UInt
  prev1_shift : Int
  prev1_initial_mask : UInt
  shift_mask : UInt
  prev2_next_mask : UInt
  prev1_next_mask : UInt
}

///|
let default_template0_fast_params : DefaultTemplateFastParams = {
  prev2_initial_shift: 6,
  prev2_initial_mask: 0xf800,
  prev1_shift: 0,
  prev1_initial_mask: 0x07f0,
  shift_mask: 0x7bf7,
  prev2_next_mask: 0x0800,
  prev1_next_mask: 0x0010,
}

///|
let default_template1_fast_params : DefaultTemplateFastParams = {
  prev2_initial_shift: 4,
  prev2_initial_mask: 0x1e00,
  prev1_shift: 1,
  prev1_initial_mask: 0x01f8,
  shift_mask: 0x0efb,
  prev2_next_mask: 0x0200,
  prev1_next_mask: 0x0008,
}

///|
let default_template2_fast_params : DefaultTemplateFastParams = {
  prev2_initial_shift: 1,
  prev2_initial_mask: 0x0380,
  prev1_shift: 3,
  prev1_initial_mask: 0x007c,
  shift_mask: 0x01bd,
  prev2_next_mask: 0x0080,
  prev1_next_mask: 0x0004,
}

///|
let default_template3_fast_params : DefaultTemplateFastParams = {
  prev2_initial_shift: 0,
  prev2_initial_mask: 0x0000,
  prev1_shift: 1,
  prev1_initial_mask: 0x03f0,
  shift_mask: 0x01f7,
  prev2_next_mask: 0x0000,
  prev1_next_mask: 0x0010,
}
