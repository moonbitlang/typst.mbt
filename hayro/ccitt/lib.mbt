// Port of `hayro-ccitt/src/lib.rs` (hayro rev d8e24e2, hayro-ccitt 0.3.0): a
// decoder for CCITT fax-encoded images.
//
// This crate implements the CCITT Group 3 and Group 4 fax compression algorithms
// as defined in ITU-T Recommendations T.4 and T.6. These encodings are commonly
// used for bi-level (black and white) images in PDF documents and fax transmissions.
//
// The main entry point is the [`decode`] function, which takes encoded data, a
// [`DecoderContext`], and outputs the decoded pixels through a [`Decoder`] trait
// that can be implemented according to your needs.

///|
/// An error that can occur during CCITT decoding.
pub(all) suberror DecodeError {
  /// Unexpected end of input while reading bits.
  UnexpectedEof
  /// Invalid Huffman code sequence was encountered during decoding.
  InvalidCode
  /// A scanline didn't have the expected number of pixels.
  LineLengthMismatch
  /// Arithmetic overflow in run length or position calculation.
  Overflow
} derive(Eq)

///|
pub impl Show for DecodeError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnexpectedEof => "unexpected end of input"
      InvalidCode => "invalid CCITT code sequence"
      LineLengthMismatch => "scanline length mismatch"
      Overflow => "arithmetic overflow in position calculation"
    },
  )
}

///|
/// The encoding mode for CCITT fax decoding.
pub(all) enum EncodingMode {
  /// Group 4 (MMR).
  Group4
  /// Group 3 1D (MH).
  Group3_1D
  /// Group 3 2D (MR).
  Group3_2D(k~ : UInt)
} derive(Eq, Debug)

///|
/// Settings to apply during decoding.
pub(all) struct DecodeSettings {
  /// How many columns the image has (i.e. its width).
  columns : UInt
  /// How many rows the image has (i.e. its height).
  ///
  /// In case `end_of_block` has been set to true, decoding will run until
  /// the given number of rows have been decoded, or the `end_of_block` marker
  /// has been encountered, whichever occurs first.
  rows : UInt
  /// Whether the stream _MAY_ contain an end-of-block marker
  /// (It doesn't have to. In that case this is set to `true` but there are
  /// no end-of-block markers, hayro-ccitt will still use the value of `rows`
  /// to determine when to stop decoding).
  end_of_block : Bool
  /// Whether the stream contains end-of-line markers.
  end_of_line : Bool
  /// Whether the data in the stream for each row is aligned to the byte
  /// boundary.
  rows_are_byte_aligned : Bool
  /// The encoding mode used by the image.
  encoding : EncodingMode
  /// Whether black and white should be inverted.
  invert_black : Bool
}

///|
/// A decoder for CCITT images.
pub(open) trait Decoder {
  /// Push a single pixel with the given color.
  fn push_pixel(Self, white : Bool) -> Unit
  /// Push multiple chunks of 8 pixels of the same color.
  ///
  /// The `chunk_count` parameter indicates how many 8-pixel chunks to push.
  /// For example, if this method is called with `white = true` and
  /// `chunk_count = 10`, 80 white pixels are pushed (10 × 8 = 80).
  ///
  /// You can assume that this method is only called if the number of already
  /// pushed pixels is a multiple of 8 (i.e. byte-aligned).
  fn push_pixel_chunk(Self, white : Bool, chunk_count : UInt) -> Unit
  /// Called when a row has been completed.
  fn next_line(Self) -> Unit
}

///|
/// Pixel color in a bi-level (black and white) image.
priv enum Color {
  /// White pixel.
  White
  /// Black pixel.
  Black
} derive(Eq)

///|
/// Returns the opposite color.
fn Color::opposite(self : Color) -> Color {
  match self {
    White => Black
    Black => White
  }
}

///|
/// Returns true if this color is white.
fn Color::is_white(self : Color) -> Bool {
  self is White
}

///|
/// Represents a color change at a specific index in a line.
priv struct ColorChange {
  idx : UInt
  color : Color
}

///|
/// Decode the given image using the provided decoder context and decoder.
///
/// If decoding was successful, the number of bytes that have been read in total
/// is returned.
///
/// If an error is returned, it means that the file is somehow malformed.
/// However, even if that's the case, it is possible that a number
/// of rows were decoded successfully and written into the decoder, so those
/// can still be used, but the image might be truncated.
pub fn[D : Decoder] decode(
  data : BytesView,
  decoder : D,
  ctx : DecoderContext,
) -> Int raise DecodeError {
  ctx.reset()
  let reader = BitReader::new(data)
  match ctx.settings.encoding {
    Group4 => decode_group4(ctx, reader, decoder)
    Group3_1D => decode_group3_1d(ctx, reader, decoder)
    Group3_2D(..) => decode_group3_2d(ctx, reader, decoder)
  }
  reader.align()
  reader.byte_pos()
}

///|
/// Group 3 1D decoding (T.4 Section 4.1).
fn[D : Decoder] decode_group3_1d(
  ctx : DecoderContext,
  reader : BitReader,
  decoder : D,
) -> Unit raise DecodeError {
  // It seems like PDF producers are a bit sloppy with the `end_of_line` flag,
  // so we just always try to read one.
  ignore(reader.read_eol_if_available())
  while true {
    decode_1d_line(ctx, reader, decoder)
    ctx.next_line(reader, decoder)
    if group3_check_eob(ctx, reader) {
      break
    }
  }
}

///|
/// Group 3 2D decoding (T.4 Section 4.2).
fn[D : Decoder] decode_group3_2d(
  ctx : DecoderContext,
  reader : BitReader,
  decoder : D,
) -> Unit raise DecodeError {
  // It seems like PDF producers are a bit sloppy with the `end_of_line` flag,
  // so we just always try to read one.
  ignore(reader.read_eol_if_available())
  while true {
    let tag_bit = reader.read_bit()
    if tag_bit == 1 {
      decode_1d_line(ctx, reader, decoder)
    } else {
      decode_2d_line(ctx, reader, decoder)
    }
    ctx.next_line(reader, decoder)
    if group3_check_eob(ctx, reader) {
      break
    }
  }
}

///|
/// Check for end-of-block, including RTC (T.4 Section 4.1.4).
fn group3_check_eob(ctx : DecoderContext, reader : BitReader) -> Bool {
  let eol_count = reader.read_eol_if_available()

  // T.4 Section 4.1.4: "The end of a document transmission is indicated by
  // sending six consecutive EOLs."
  // PDFBOX-2778 has 7 EOL, although it should only be 6. Let's be lenient
  // and check with >=.
  if ctx.settings.end_of_block && eol_count >= 6 {
    return true
  }
  if ctx.decoded_rows == ctx.settings.rows || reader.at_end() {
    return true
  }
  false
}

///|
fn[D : Decoder] decode_group4(
  ctx : DecoderContext,
  reader : BitReader,
  decoder : D,
) -> Unit raise DecodeError {
  while true {
    if ctx.settings.end_of_block && reader.peak_bits(24) == Some(EOFB) {
      ignore(reader.read_bits(24))
      break
    }
    if ctx.decoded_rows == ctx.settings.rows || reader.at_end() {
      break
    }
    decode_2d_line(ctx, reader, decoder)
    ctx.next_line(reader, decoder)
  }
}

///|
/// Decode a single 1D-coded line (T.4 Section 4.1.1, T.6 Section 2.2.4).
fn[D : Decoder] decode_1d_line(
  ctx : DecoderContext,
  reader : BitReader,
  decoder : D,
) -> Unit raise DecodeError {
  while !ctx.at_eol() {
    let run_length = reader.decode_run(ctx.color)
    ctx.push_pixels(decoder, run_length)
    ctx.color = ctx.color.opposite()
  }
}

///|
/// Decode a single 2D-coded line (T.4 Section 4.2, T.6 Section 2.2).
fn[D : Decoder] decode_2d_line(
  ctx : DecoderContext,
  reader : BitReader,
  decoder : D,
) -> Unit raise DecodeError {
  while !ctx.at_eol() {
    let mode = reader.decode_mode()
    match mode {
      // Pass mode (T.4 Section 4.2.1.3.2a, T.6 Section 2.2.3.1).
      Pass => {
        ctx.push_pixels(decoder, ctx.b2() - ctx.a0().unwrap_or(0))
        ctx.update_b()
        // No color change happens in pass mode.
      }
      // Vertical mode (T.4 Section 4.2.1.3.2b, T.6 Section 2.2.3.2).
      Vertical(i) => {
        let b1 = ctx.b1()
        let a1 = if i >= 0 {
          let a1 = b1 + i.reinterpret_as_uint()
          guard a1 >= b1 else { raise Overflow }
          a1
        } else {
          let d = (-i).reinterpret_as_uint()
          guard b1 >= d else { raise Overflow }
          b1 - d
        }
        let a0 = ctx.a0().unwrap_or(0)
        guard a1 >= a0 else { raise Overflow }
        ctx.push_pixels(decoder, a1 - a0)
        ctx.color = ctx.color.opposite()
        ctx.update_b()
      }
      // Horizontal mode (T.4 Section 4.2.1.3.2c, T.6 Section 2.2.3.3).
      Horizontal => {
        let a0a1 = reader.decode_run(ctx.color)
        ctx.push_pixels(decoder, a0a1)
        ctx.color = ctx.color.opposite()
        let a1a2 = reader.decode_run(ctx.color)
        ctx.push_pixels(decoder, a1a2)
        ctx.color = ctx.color.opposite()
        ctx.update_b()
      }
    }
  }
}

///|
/// A reusable context for decoding CCITT images.
pub struct DecoderContext {
  /// Color changes in the reference line (previous line).
  priv mut ref_changes : Array[ColorChange]
  /// The minimum index we need to start from when searching for b1.
  priv mut ref_pos : UInt
  /// The current index of b1.
  priv mut b1_idx : UInt
  /// Color changes in the coding line (current line being decoded).
  priv mut coding_changes : Array[ColorChange]
  /// Current position in the coding line (number of pixels decoded).
  priv mut pixels_decoded : UInt
  /// The width of a line in pixels (i.e. number of columns).
  priv mut line_width : UInt
  /// The color of the next run to be decoded.
  priv mut color : Color
  /// How many rows have been decoded so far.
  priv mut decoded_rows : UInt
  /// The settings to apply during decoding.
  priv settings : DecodeSettings
  /// Whether to invert black and white.
  priv mut invert_black : Bool
}

///|
/// Creates a new decoder context using the provided decode settings.
pub fn DecoderContext::new(settings : DecodeSettings) -> DecoderContext {
  {
    ref_changes: [],
    ref_pos: 0,
    b1_idx: 0,
    coding_changes: [],
    pixels_decoded: 0,
    line_width: settings.columns,
    // Each run starts with an imaginary white pixel on the left.
    color: White,
    decoded_rows: 0,
    settings,
    invert_black: settings.invert_black,
  }
}

///|
fn DecoderContext::reset(self : DecoderContext) -> Unit {
  self.ref_changes.clear()
  self.ref_pos = 0
  self.b1_idx = 0
  self.coding_changes.clear()
  self.pixels_decoded = 0
  self.line_width = self.settings.columns
  self.color = White
  self.decoded_rows = 0
  self.invert_black = self.settings.invert_black
}

///|
/// `a0` refers to the first changing element on the current line.
fn DecoderContext::a0(self : DecoderContext) -> UInt? {
  if self.pixels_decoded == 0 {
    // If we haven't coded anything yet, a0 conceptually points at the
    // index -1. This is a bit of an edge case, and we therefore require
    // callers of this method to handle the case themselves.
    None
  } else {
    // Otherwise, the index points to the next element to be decoded.
    Some(self.pixels_decoded)
  }
}

///|
/// Element `idx` of `changes` (upstream `get(idx)`).
fn change_at(changes : Array[ColorChange], idx : UInt) -> ColorChange? {
  if idx < changes.length().reinterpret_as_uint() {
    Some(changes[idx.reinterpret_as_int()])
  } else {
    None
  }
}

///|
/// "The first changing element on the reference line to the right of a0 and
/// of opposite color to a0."
fn DecoderContext::b1(self : DecoderContext) -> UInt {
  match change_at(self.ref_changes, self.b1_idx) {
    Some(c) => c.idx
    None => self.line_width
  }
}

///|
/// "The next changing element to the right of b1, on the reference line."
fn DecoderContext::b2(self : DecoderContext) -> UInt {
  match change_at(self.ref_changes, self.b1_idx + 1) {
    Some(c) => c.idx
    None => self.line_width
  }
}

///|
/// Compute the new position of b1 (and implicitly b2).
fn DecoderContext::update_b(self : DecoderContext) -> Unit {
  // b1 refers to an element of the opposite color.
  let target_color = self.color.opposite()
  // b1 must be strictly greater than a0.
  let min_idx = match self.a0() {
    Some(a) => a + 1
    None => 0
  }
  self.b1_idx = self.line_width
  let len = self.ref_changes.length().reinterpret_as_uint()
  let mut i = self.ref_pos
  while i < len {
    let change = self.ref_changes[i.reinterpret_as_int()]
    if change.idx < min_idx {
      self.ref_pos = i + 1
      i += 1
      continue
    }
    if change.color == target_color {
      self.b1_idx = i
      break
    }
    i += 1
  }
}

///|
fn[D : Decoder] DecoderContext::push_pixels(
  self : DecoderContext,
  decoder : D,
  count : UInt,
) -> Unit {
  // Make sure we don't have too many pixels (for invalid files).
  let count = @cmp.minimum(count, self.line_width - self.pixels_decoded)
  let white = self.color.is_white() != self.invert_black
  let mut remaining = count

  // Push individual pixels until we reach an 8-pixel boundary.
  let pixels_to_boundary = (8U - self.pixels_decoded % 8) % 8
  let unaligned_pixels = @cmp.minimum(remaining, pixels_to_boundary)
  for _ in 0U..<unaligned_pixels {
    decoder.push_pixel(white)
    remaining -= 1
  }

  // Push full chunks of 8 pixels.
  let full_chunks = remaining / 8
  if full_chunks > 0 {
    decoder.push_pixel_chunk(white, full_chunks)
    remaining %= 8
  }

  // Push remaining individual pixels.
  for _ in 0U..<remaining {
    decoder.push_pixel(white)
  }

  // Track the color change:
  // - At start of line (no previous changes): only add if color differs from
  //   imaginary white, i.e., only add if black.
  // - Mid-line: only add if color differs from previous.
  if count > 0 {
    let is_change = match self.coding_changes.last() {
      Some(last) => last.color != self.color
      None => !self.color.is_white()
    }
    if is_change {
      self.coding_changes.push({ idx: self.pixels_decoded, color: self.color, })
    }
    self.pixels_decoded += count
  }
}

///|
fn DecoderContext::at_eol(self : DecoderContext) -> Bool {
  self.a0().unwrap_or(0) == self.line_width
}

///|
fn[D : Decoder] DecoderContext::next_line(
  self : DecoderContext,
  reader : BitReader,
  decoder : D,
) -> Unit raise DecodeError {
  if self.pixels_decoded != self.settings.columns {
    raise LineLengthMismatch
  }
  let tmp = self.ref_changes
  self.ref_changes = self.coding_changes
  self.coding_changes = tmp
  self.coding_changes.clear()
  self.pixels_decoded = 0
  self.ref_pos = 0
  self.b1_idx = 0
  self.color = White
  self.decoded_rows += 1
  decoder.next_line()
  if self.settings.rows_are_byte_aligned {
    reader.align()
  }
  self.update_b()
}
