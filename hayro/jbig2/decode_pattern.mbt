// Port of `hayro-jbig2/src/decode/pattern.rs`: pattern dictionary segment
// parsing and decoding (7.4.4, 6.7).

///|
/// Decode a pattern dictionary segment (7.4.4.2, 6.7).
fn pattern_decode(
  header : PatternDictionaryHeader,
  scratch : ScratchBuffers,
) -> PatternDictionary raise DecodeError {
  let pattern_width = header.pattern_width
  let pattern_height = header.pattern_height
  let num_patterns = ok_or(
    checked_add_u32(header.num_patterns, 1),
    Overflow(BitmapDimension),
  )

  // "1) Create a bitmap B_HDC. The height of this bitmap is HDPH. The width
  // of the bitmap is (GRAYMAX + 1) × HDPW. This bitmap contains all the
  // patterns concatenated left to right." (6.7.5)
  let collective_width = num_patterns.to_uint64() * pattern_width.to_uint64()
  if collective_width > 0xFFFFFFFFUL {
    raise Overflow(BitmapDimension)
  }
  let collective_width = collective_width.to_uint()
  let collective_bitmap = Bitmap::new(collective_width, pattern_height)

  // "2) Decode the collective bitmap using a generic region decoding procedure
  // as described in 6.2." (6.7.5)
  if header.mmr {
    let _ = decode_bitmap_mmr(collective_bitmap, header.data)
  } else {
    // (`-(pattern_width as i8)`)
    let at_x = -i8_of(pattern_width.to_byte())
    let at_x = if at_x == 128 { -128 } else { at_x }
    let at_pixels : FixedArray[AdaptiveTemplatePixel] = match header.template {
      Template0 =>
        [
          { x: at_x, y: 0, },
          { x: -3, y: -1, },
          { x: 2, y: -2, },
          { x: -2, y: -2, },
        ]
      Template1 | Template2 | Template3 =>
        [
          { x: at_x, y: 0, },
          // Unused.
          AdaptiveTemplatePixel::default(),
          AdaptiveTemplatePixel::default(),
          AdaptiveTemplatePixel::default(),
        ]
    }
    let decoder = ArithmeticDecoder::new(header.data)
    let contexts = scratch.reset_contexts(1 << header.template.context_bits())
    decode_bitmap_arithmetic_coding(
      collective_bitmap,
      decoder,
      contexts,
      header.template,
      false,
      at_pixels,
    )
  }

  // "3) Set: GRAY = 0" (6.7.5)
  // "4) While GRAY ≤ GRAYMAX:" (6.7.5)
  let patterns = []
  let src_stride = collective_bitmap.stride
  for gray in 0U..<num_patterns {
    // "a) Let the subimage of B_HDC consisting of HPH rows and columns
    // HDPW × GRAY through HDPW × (GRAY + 1) − 1 be denoted B_P. Set:
    // HDPATS[GRAY] = B_P" (6.7.5)"
    let start_x = gray * pattern_width
    let pattern = Bitmap::new(pattern_width, pattern_height)
    let src_word_idx = start_x / WORD_BITS
    let src_bit_offset = start_x % WORD_BITS
    let dst_stride = pattern.stride
    let src_data = collective_bitmap.data
    for y in 0U..<pattern_height {
      let src_row = (y * src_stride + src_word_idx).reinterpret_as_int()
      let dst_row = (y * dst_stride).reinterpret_as_int()
      for w in 0..<dst_stride.reinterpret_as_int() {
        let s1 = src_data[src_row + w]
        let s2 = if src_row + w + 1 < src_data.length() {
          src_data[src_row + w + 1]
        } else {
          0
        }
        let word = if src_bit_offset == 0 {
          s1
        } else {
          (s1 << src_bit_offset.reinterpret_as_int()) |
          (s2 >> (WORD_BITS - src_bit_offset).reinterpret_as_int())
        }
        pattern.data[dst_row + w] = word
      }

      // Clear trailing bits in the last word beyond `pattern_width`.
      let trailing = pattern_width % WORD_BITS
      if trailing != 0 {
        let last = dst_row + (dst_stride - 1).reinterpret_as_int()
        pattern.data[last] = pattern.data[last] &
          (0xFFFFFFFFU << (WORD_BITS - trailing).reinterpret_as_int())
      }
    }
    patterns.push(pattern)
  }

  // It turns out that when rendering patterns, the `Bitmap::combine` operation
  // can often be a huge bottleneck. This is because we need to do a lot of
  // fiddling to compose the patterns in the right position. And since
  // if a page uses such patterns, there's going to be a lot of them,
  // this takes up a lot of time.
  //
  // The key insight for our optimization is that patterns are usually
  // very small. Therefore, we precompute a new version of each pattern
  // for all possible 32-bit alignments, which later on allows us to
  // very easily blit it into the backdrop, significantly speeding up
  // the whole process.
  let shifted_patterns : Array[UInt] = if pattern_width <= WORD_BITS &&
    pattern_height <= WORD_BITS {
    let h = pattern_height.reinterpret_as_int()
    let data = Array(capacity=patterns.length() * 32 * h * 2)
    for pattern in patterns {
      for k in 0..<32 {
        for y in 0..<h {
          let word = pattern.data[y]
          if k == 0 {
            data.push(word)
            data.push(0)
          } else {
            data.push(word >> k)
            data.push(word << (32 - k))
          }
        }
      }
    }
    data
  } else {
    []
  }
  { patterns, pattern_width, pattern_height, shifted_patterns, }
}

///|
/// A decoded pattern dictionary.
priv struct PatternDictionary {
  patterns : Array[Bitmap]
  pattern_width : UInt
  pattern_height : UInt
  shifted_patterns : Array[UInt]
}

///|
/// Returns the start of the `pattern_height * 2` shifted words (upstream
/// returns the slice).
#inline
fn PatternDictionary::shifted_pattern(
  self : PatternDictionary,
  pattern_idx : Int,
  bit_offset : UInt,
) -> Int? {
  let h = self.pattern_height.reinterpret_as_int()
  let len = h * 2
  let start = (pattern_idx * 32 + bit_offset.reinterpret_as_int()) * len
  if start + len <= self.shifted_patterns.length() {
    Some(start)
  } else {
    None
  }
}

///|
/// Parsed pattern dictionary segment header (7.4.4.1).
priv struct PatternDictionaryHeader {
  mmr : Bool
  template : Template
  /// `HDPW`
  pattern_width : UInt
  /// `HDPH`
  pattern_height : UInt
  /// `GRAYMAX`
  num_patterns : UInt
  data : BytesView
}

///|
/// Parse a pattern dictionary segment header (7.4.4.1).
fn pattern_parse(reader : Reader) -> PatternDictionaryHeader raise DecodeError {
  let flags_byte = ok_or(reader.read_byte(), eof).to_int()
  let mmr = (flags_byte & 0x01) != 0
  let template = Template::from_byte(flags_byte >> 1)
  let pattern_width = ok_or(reader.read_nonzero_byte(), eof).to_uint()
  let pattern_height = ok_or(reader.read_nonzero_byte(), eof).to_uint()
  let num_patterns = ok_or(reader.read_u32(), eof)
  let data = ok_or(reader.tail(), eof)
  { mmr, template, pattern_width, pattern_height, num_patterns, data, }
}
