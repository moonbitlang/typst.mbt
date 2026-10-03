// Port of `hayro-jbig2/src/lib.rs` (hayro-jbig2 0.3.0, as hayro uses it with
// the `std` and `simd` features).
//
// A memory-safe, pure-Rust JBIG2 decoder.
//
// `hayro-jbig2` decodes JBIG2 images as specified in ITU-T T.88 (also known as
// ISO/IEC 14492). JBIG2 is a bi-level image compression standard commonly used
// in PDF documents for compressing scanned text documents.
//
// (`lazy.rs` is not ported: the lazily built standard Huffman tables are
// `Option`s in `StandardHuffmanTables`. `integration.rs` belongs to the
// `image` feature, which hayro doesn't enable. `simd.rs` is ported lane by
// lane in `gray_scale.mbt`.)

///|
/// A reusable context for decoding JBIG2 images.
pub struct DecoderContext {
  priv page_state : PageState
  priv scratch_buffers : ScratchBuffers
  priv page_bitmap : Bitmap
}

///|
pub fn DecoderContext::default() -> DecoderContext {
  {
    page_state: PageState::default(),
    scratch_buffers: { contexts: [], },
    page_bitmap: Bitmap::default(),
  }
}

///|
priv struct ScratchBuffers {
  mut contexts : FixedArray[Byte]
}

///|
/// `contexts.clear(); contexts.resize(n, ArithmeticDecoderContext::default())`.
fn ScratchBuffers::reset_contexts(
  self : ScratchBuffers,
  n : Int,
) -> FixedArray[Byte] {
  if self.contexts.length() == n {
    self.contexts.fill(b'\x00')
  } else {
    self.contexts = new_contexts(n)
  }
  self.contexts
}

///|
/// A decoder for JBIG2 images.
pub(open) trait Decoder {
  /// Push a single pixel to the output.
  fn push_pixel(Self, black : Bool) -> Unit
  /// Push multiple chunks of 8 pixels of the same color.
  ///
  /// The `chunk_count` parameter indicates how many 8-pixel chunks to push.
  /// For example, if this method is called with `white = true` and
  /// `chunk_count = 10`, 80 white pixels are pushed (10 × 8 = 80).
  ///
  /// You can assume that this method is only called if the number of already
  /// pushed pixels is a multiple of 8 (i.e. byte-aligned).
  fn push_pixel_chunk(Self, black : Bool, chunk_count : UInt) -> Unit
  /// Called when a row has been completed.
  fn next_line(Self) -> Unit
}

///|
/// A JBIG2 image.
pub struct Image {
  /// The parsed segments.
  priv segments : Array[Segment]
  /// The width of the image in pixels.
  priv width : UInt
  /// The height of the image in pixels.
  priv height : UInt
  /// The height determined from `EndOfStripe` segments, if applicable.
  priv height_from_stripes : UInt?
}

///|
/// Parse a JBIG2 file from the given data.
///
/// The file is expected to use the sequential or random-access organization,
/// as defined in Annex D.1 and D.2.
pub fn Image::new(data : BytesView) -> Image raise DecodeError {
  let file = parse_file(data)
  Image::from_segments(file.segments)
}

///|
/// Parse an embedded JBIG2 image with optional global segments.
///
/// The file is expected to use the embedded organization defined in
/// Annex D.3.
pub fn Image::new_embedded(
  data : BytesView,
  globals : BytesView?,
) -> Image raise DecodeError {
  let segments = []
  if globals is Some(globals_data) {
    let reader = Reader::new(globals_data)
    parse_segments_sequential(reader, segments)
  }
  let reader = Reader::new(data)
  parse_segments_sequential(reader, segments)
  let segments = sort_segments(segments)
  Image::from_segments(segments)
}

///|
fn Image::from_segments(segments : Array[Segment]) -> Image raise DecodeError {
  // Pre-scan for stripe height from EndOfStripe segments.
  let mut height_from_stripes : UInt? = None
  for seg in segments {
    if seg.header.segment_type is EndOfStripe && seg.data.length() == 4 {
      let d = seg.data
      let v = (d[0].to_uint() << 24) |
        (d[1].to_uint() << 16) |
        (d[2].to_uint() << 8) |
        d[3].to_uint()
      // (`checked_add(1)`)
      if v != 0xFFFFFFFF {
        let h = v + 1
        height_from_stripes = match height_from_stripes {
          Some(m) if m >= h => Some(m)
          _ => Some(h)
        }
      }
    }
  }

  // Find and parse page information to extract dimensions.
  let page_info_seg = ok_or(
    segments
    .search_by(s => s.header.segment_type is PageInformation)
    .map(i => segments[i]),
    Format(MissingPageInfo),
  )
  let reader = Reader::new(page_info_seg.data)
  let page_info = parse_page_information(reader)

  // "A page's bitmap height may be declared in its page information segment
  // to be unknown (by specifying a height of 0xFFFFFFFF). In this case, the
  // page must be striped." (7.4.8.2)
  let height = if page_info.height == 0xFFFFFFFF {
    ok_or(height_from_stripes, Format(UnknownPageHeight))
  } else {
    page_info.height
  }
  if page_info.width == 0 || height == 0 {
    raise Format(EmptyPage)
  }
  { segments, width: page_info.width, height, height_from_stripes, }
}

///|
/// The width of the image in pixels.
pub fn Image::width(self : Image) -> UInt {
  self.width
}

///|
/// The height of the image in pixels.
pub fn Image::height(self : Image) -> UInt {
  self.height
}

///|
/// Decode the image data through the given [`Decoder`].
pub fn[D : Decoder] Image::decode(
  self : Image,
  decoder : D,
) -> Unit raise DecodeError {
  let ctx = DecoderContext::default()
  self.decode_with(decoder, ctx)
}

///|
/// Decode the image data through the given [`Decoder`] and [`DecoderContext`].
///
/// This is useful in case you want to convert multiple JBIG2 images,
/// as it allows `hayro-jbig2` to reuse allocations during decoding.
pub fn[D : Decoder] Image::decode_with(
  self : Image,
  decoder : D,
  ctx : DecoderContext,
) -> Unit raise DecodeError {
  decode_segments(self.segments, self.height_from_stripes, ctx)
  emit_bitmap(ctx.page_bitmap, decoder)
}

///|
fn[D : Decoder] emit_bitmap(bitmap : Bitmap, decoder : D) -> Unit {
  let width = bitmap.width
  let bytes_per_row = ((width + 7) / 8).reinterpret_as_int()
  let stride = bitmap.stride.reinterpret_as_int()
  let rows = if stride == 0 { 0 } else { bitmap.data.length() / stride }
  for r in 0..<rows {
    let row_base = r * stride
    let mut x = 0U
    // (`chunk_byte: Option<u8>`; -1 is `None`.)
    let mut chunk_byte = -1
    let mut chunk_count = 0U
    for i in 0..<bytes_per_row {
      let byte = ((bitmap.data[row_base + i / 4] >> ((3 - i % 4) * 8)) & 0xFF).reinterpret_as_int()
      let remaining = width - x
      if remaining >= 8 && (byte == 0x00 || byte == 0xFF) {
        // Continue the previous chunk.
        if chunk_byte == byte {
          chunk_count += 1
          x += 8
          continue
        }

        // Flush previous chunk if any, then start new one.
        if chunk_byte >= 0 {
          decoder.push_pixel_chunk(chunk_byte == 0xFF, chunk_count)
        }
        chunk_byte = byte
        chunk_count = 1
        x += 8
        continue
      }

      // Can't continue/start chunk, flush any existing chunk first.
      if chunk_byte >= 0 {
        decoder.push_pixel_chunk(chunk_byte == 0xFF, chunk_count)
        chunk_byte = -1
        chunk_count = 0
      }

      // Emit individual pixels.
      let count = if remaining < 8 { remaining } else { 8 }
      for k in 0..<count.reinterpret_as_int() {
        decoder.push_pixel(((byte >> (7 - k)) & 1) != 0)
      }
      x += count
    }

    // Flush any remaining chunk at end of row.
    if chunk_byte >= 0 {
      decoder.push_pixel_chunk(chunk_byte == 0xFF, chunk_count)
    }
    decoder.next_line()
  }
}

///|
/// Collect the exported symbols of the referred symbol dictionaries.
fn PageState::referred_symbols(
  self : PageState,
  referred_to_segments : Array[UInt],
) -> Array[Bitmap] {
  let symbols = []
  for num in referred_to_segments {
    if self.get_symbol_dictionary(num) is Some(dict) {
      symbols.append(dict.exported_symbols)
    }
  }
  symbols
}

///|
/// Collect Huffman tables from referred table segments.
fn PageState::referred_tables(
  self : PageState,
  referred_to_segments : Array[UInt],
) -> Array[HuffmanTable] {
  let tables = []
  for num in referred_to_segments {
    if self.get_huffman_table(num) is Some(table) {
      tables.push(table)
    }
  }
  tables
}

///|
fn decode_segments(
  segments : Array[Segment],
  height_from_stripes : UInt?,
  decoder_ctx : DecoderContext,
) -> Unit raise DecodeError {
  // Find and parse page information segment first.
  match segments.search_by(s => s.header.segment_type is PageInformation) {
    Some(i) => {
      let reader = Reader::new(segments[i].data)
      init_page(
        reader,
        height_from_stripes,
        decoder_ctx.page_state,
        decoder_ctx.page_bitmap,
      )
    }
    None => raise Format(MissingPageInfo)
  }
  let page_bitmap = decoder_ctx.page_bitmap
  let page_state = decoder_ctx.page_state
  let scratch_buffers = decoder_ctx.scratch_buffers

  // Process all segments.
  for seg in segments {
    let reader = Reader::new(seg.data)
    match seg.header.segment_type {
      PageInformation => () // Already processed above, skip.
      ImmediateGenericRegion | ImmediateLosslessGenericRegion => {
        let had_unknown_length = seg.header.data_length is None
        let header = generic_parse(reader, had_unknown_length)
        if page_state.can_decode_directly(
            page_bitmap,
            header.region_info,
            false,
          ) {
          generic_decode_into(header, page_bitmap, scratch_buffers)
        } else {
          let region = generic_decode(header, scratch_buffers)
          page_bitmap.combine(
            region.bitmap,
            region.bitmap.x_location.reinterpret_as_int(),
            region.bitmap.y_location.reinterpret_as_int(),
            region.combination_operator,
          )
        }
        page_state.page_pristine = false
      }
      IntermediateGenericRegion => {
        // Intermediate segments cannot have unknown length.
        let header = generic_parse(reader, false)
        let region = generic_decode(header, scratch_buffers)
        page_state.store_region(seg.header.segment_number, region.bitmap)
      }
      PatternDictionary => {
        let header = pattern_parse(reader)
        let dictionary = pattern_decode(header, scratch_buffers)
        page_state.store_pattern_dictionary(
          seg.header.segment_number,
          dictionary,
        )
      }
      SymbolDictionary => {
        // "1) Concatenate all the input symbol dictionaries to form SDINSYMS."
        // (6.5.5, step 1)
        // Collect references to avoid cloning; symbols are only cloned if re-exported.
        let input_symbols = page_state.referred_symbols(
          seg.header.referred_to_segments,
        )

        // Collect Huffman tables from referred table segments.
        let referred_tables = page_state.referred_tables(
          seg.header.referred_to_segments,
        )

        // Get retained contexts from the last referred symbol dictionary (7.4.2.2 step 3).
        let retained_contexts = match seg.header.referred_to_segments.last() {
          Some(num) =>
            match page_state.get_symbol_dictionary(num) {
              Some(dict) => dict.retained_contexts
              None => None
            }
          None => None
        }
        let header = symbol_parse(reader)
        let dictionary = symbol_decode(
          header,
          input_symbols,
          referred_tables,
          page_state.standard_tables,
          retained_contexts,
        )
        page_state.store_symbol_dictionary(
          seg.header.segment_number,
          dictionary,
        )
      }
      ImmediateTextRegion | ImmediateLosslessTextRegion => {
        // Collect symbols from referred symbol dictionaries (SBSYMS).
        let symbols = page_state.referred_symbols(
          seg.header.referred_to_segments,
        )

        // Collect Huffman tables from referred table segments.
        // "These user-supplied Huffman decoding tables may be supplied either
        // as a Tables segment..." (7.4.3.1.6)
        let referred_tables = page_state.referred_tables(
          seg.header.referred_to_segments,
        )
        let header = text_parse(reader, symbols.length().reinterpret_as_uint())
        if page_state.can_decode_directly(
            page_bitmap,
            header.region_info,
            header.flags.default_pixel,
          ) {
          text_decode_into(
            header,
            symbols,
            referred_tables,
            page_state.standard_tables,
            page_bitmap,
            scratch_buffers,
          )
        } else {
          let region = text_decode(
            header,
            symbols,
            referred_tables,
            page_state.standard_tables,
            scratch_buffers,
          )
          page_bitmap.combine(
            region.bitmap,
            region.bitmap.x_location.reinterpret_as_int(),
            region.bitmap.y_location.reinterpret_as_int(),
            region.combination_operator,
          )
        }
        page_state.page_pristine = false
      }
      IntermediateTextRegion => {
        // Collect symbols from referred symbol dictionaries (SBSYMS).
        let symbols = page_state.referred_symbols(
          seg.header.referred_to_segments,
        )

        // Collect Huffman tables from referred table segments.
        let referred_tables = page_state.referred_tables(
          seg.header.referred_to_segments,
        )
        let header = text_parse(reader, symbols.length().reinterpret_as_uint())
        let region = text_decode(
          header,
          symbols,
          referred_tables,
          page_state.standard_tables,
          scratch_buffers,
        )
        page_state.store_region(seg.header.segment_number, region.bitmap)
      }
      ImmediateHalftoneRegion | ImmediateLosslessHalftoneRegion => {
        let pattern_dict = ok_or(
          match seg.header.referred_to_segments {
            [num, ..] => page_state.get_pattern_dictionary(num)
            [] => None
          },
          Segment(MissingPatternDictionary),
        )
        let header = halftone_parse(reader)
        if page_state.can_decode_directly(
            page_bitmap,
            header.region_info,
            header.flags.initial_pixel_color,
          ) {
          halftone_decode_into(
            header, pattern_dict, page_bitmap, scratch_buffers,
          )
        } else {
          let region = halftone_decode(header, pattern_dict, scratch_buffers)
          page_bitmap.combine(
            region.bitmap,
            region.bitmap.x_location.reinterpret_as_int(),
            region.bitmap.y_location.reinterpret_as_int(),
            region.combination_operator,
          )
        }
        page_state.page_pristine = false
      }
      IntermediateHalftoneRegion => {
        let pattern_dict = ok_or(
          match seg.header.referred_to_segments {
            [num, ..] => page_state.get_pattern_dictionary(num)
            [] => None
          },
          Segment(MissingPatternDictionary),
        )
        let header = halftone_parse(reader)
        let region = halftone_decode(header, pattern_dict, scratch_buffers)
        page_state.store_region(seg.header.segment_number, region.bitmap)
      }
      IntermediateGenericRefinementRegion => {
        // Same logic as immediate refinement, but store result instead of combining.
        let reference = match seg.header.referred_to_segments {
          [num, ..] =>
            page_state.get_referred_segment(num).unwrap_or(page_bitmap)
          [] => page_bitmap
        }
        let header = generic_refinement_parse(reader)
        let region = generic_refinement_decode(
          header, reference, scratch_buffers,
        )
        page_state.store_region(seg.header.segment_number, region.bitmap)
      }
      ImmediateGenericRefinementRegion
      | ImmediateLosslessGenericRefinementRegion => {
        // "3) Determine the buffer associated with the region segment that
        // this segment refers to." (7.4.7.5)
        //
        // "2) If there are no referred-to segments, then use the page
        // bitmap as the reference buffer." (7.4.7.5)
        let referred_segment = match seg.header.referred_to_segments {
          [num, ..] => page_state.get_referred_segment(num)
          [] => None
        }
        let header = generic_refinement_parse(reader)
        match referred_segment {
          Some(referred_segment) if page_state.can_decode_directly(
              page_bitmap,
              header.region_info,
              false,
            ) =>
            generic_refinement_decode_into(
              header, referred_segment, page_bitmap, scratch_buffers,
            )
          _ => {
            let reference = referred_segment.unwrap_or(page_bitmap)
            let region = generic_refinement_decode(
              header, reference, scratch_buffers,
            )
            page_bitmap.combine(
              region.bitmap,
              region.bitmap.x_location.reinterpret_as_int(),
              region.bitmap.y_location.reinterpret_as_int(),
              region.combination_operator,
            )
          }
        }
        page_state.page_pristine = false
      }
      Tables => {
        // "Tables – see 7.4.13." (type 53)
        // "This segment contains data which defines one or more user-supplied
        // Huffman coding tables." (7.4.13)
        let table = HuffmanTable::read_custom(reader)
        page_state.store_huffman_table(seg.header.segment_number, table)
      }
      EndOfPage | EndOfFile => break
      // Other segment types not yet implemented.
      EndOfStripe | Profiles | ColourPalette | Extension => ()
    }
  }
}

///|
/// Page-level decoding state for a JBIG2 page.
priv struct PageState {
  /// The parsed page information.
  mut page_info : PageInformation
  /// Whether the page bitmap is still in its initial state (not yet painted to).
  mut page_pristine : Bool
  /// Decoded intermediate regions, stored as (`segment_number`, region) pairs.
  referred_segments : Array[(UInt, Bitmap)]
  /// Decoded pattern dictionaries, stored as (`segment_number`, dictionary) pairs.
  pattern_dictionaries : Array[(UInt, PatternDictionary)]
  /// Decoded symbol dictionaries, stored as (`segment_number`, dictionary) pairs.
  symbol_dictionaries : Array[(UInt, SymbolDictionary)]
  /// Decoded Huffman tables from table segments, stored as (`segment_number`, table) pairs.
  /// "Tables – see 7.4.13." (type 53)
  huffman_tables : Array[(UInt, HuffmanTable)]
  /// Standard Huffman tables (`TABLE_A` through `TABLE_O`).
  standard_tables : StandardHuffmanTables
}

///|
fn PageState::default() -> PageState {
  {
    page_info: PageInformation::default(),
    page_pristine: false,
    referred_segments: [],
    pattern_dictionaries: [],
    symbol_dictionaries: [],
    huffman_tables: [],
    standard_tables: StandardHuffmanTables::new(),
  }
}

///|
fn PageState::reset(self : PageState, page_info : PageInformation) -> Unit {
  self.page_info = page_info
  self.page_pristine = true
  self.referred_segments.clear()
  self.pattern_dictionaries.clear()
  self.symbol_dictionaries.clear()
  self.huffman_tables.clear()
  // Standard tables are lazily built and reused across images.
}

///|
/// Check if an immediate region can be decoded directly into the page bitmap.
fn PageState::can_decode_directly(
  self : PageState,
  page_bitmap : Bitmap,
  region_info : RegionSegmentInfo,
  region_default_pixel : Bool,
) -> Bool {
  if !self.page_pristine {
    return false
  }
  let covers_page = region_info.x_location == 0 &&
    region_info.y_location == 0 &&
    region_info.width == page_bitmap.width &&
    region_info.height == page_bitmap.height
  if !covers_page {
    return false
  }
  let page_default_is_zero = self.page_info.flags.default_pixel == 0
  if region_default_pixel == page_default_is_zero {
    return false
  }
  let op = region_info.combination_operator
  match op {
    Replace => true
    Or | Xor => page_default_is_zero
    And | Xnor => !page_default_is_zero
  }
}

///|
/// `binary_search_by_key(&segment_number, |(num, _)| *num)` as Rust's
/// `slice::binary_search_by` implements it (the index it finds among equal
/// keys is part of the behavior).
fn[T] binary_search_by_key(entries : Array[(UInt, T)], key : UInt) -> T? {
  let mut size = entries.length()
  if size == 0 {
    return None
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    // `cmp == Greater` keeps `base`.
    if !(entries[mid].0 > key) {
      base = mid
    }
    size -= half
  }
  if entries[base].0 == key {
    Some(entries[base].1)
  } else {
    None
  }
}

///|
/// Store a decoded region for later reference.
fn PageState::store_region(
  self : PageState,
  segment_number : UInt,
  region : Bitmap,
) -> Unit {
  self.referred_segments.push((segment_number, region))
}

///|
/// Look up a referred segment by number.
fn PageState::get_referred_segment(
  self : PageState,
  segment_number : UInt,
) -> Bitmap? {
  binary_search_by_key(self.referred_segments, segment_number)
}

///|
/// Store a decoded pattern dictionary for later reference.
fn PageState::store_pattern_dictionary(
  self : PageState,
  segment_number : UInt,
  dictionary : PatternDictionary,
) -> Unit {
  self.pattern_dictionaries.push((segment_number, dictionary))
}

///|
/// Look up a pattern dictionary by segment number.
fn PageState::get_pattern_dictionary(
  self : PageState,
  segment_number : UInt,
) -> PatternDictionary? {
  binary_search_by_key(self.pattern_dictionaries, segment_number)
}

///|
/// Store a decoded symbol dictionary for later reference.
fn PageState::store_symbol_dictionary(
  self : PageState,
  segment_number : UInt,
  dictionary : SymbolDictionary,
) -> Unit {
  self.symbol_dictionaries.push((segment_number, dictionary))
}

///|
/// Look up a symbol dictionary by segment number.
fn PageState::get_symbol_dictionary(
  self : PageState,
  segment_number : UInt,
) -> SymbolDictionary? {
  binary_search_by_key(self.symbol_dictionaries, segment_number)
}

///|
/// Store a decoded Huffman table for later reference.
fn PageState::store_huffman_table(
  self : PageState,
  segment_number : UInt,
  table : HuffmanTable,
) -> Unit {
  self.huffman_tables.push((segment_number, table))
}

///|
/// Look up a Huffman table by segment number.
fn PageState::get_huffman_table(
  self : PageState,
  segment_number : UInt,
) -> HuffmanTable? {
  binary_search_by_key(self.huffman_tables, segment_number)
}

///|
/// Parse page information and initialize the page bitmap.
fn init_page(
  reader : Reader,
  height_from_stripes : UInt?,
  page : PageState,
  bitmap : Bitmap,
) -> Unit raise DecodeError {
  let page_info = parse_page_information(reader)

  // "A page's bitmap height may be declared in its page information segment
  // to be unknown (by specifying a height of 0xFFFFFFFF). In this case, the
  // page must be striped." (7.4.8.2)
  let height = if page_info.height == 0xFFFFFFFF {
    ok_or(height_from_stripes, Format(UnknownPageHeight))
  } else {
    page_info.height
  }

  // "Bit 2: Page default pixel value. This bit contains the initial value
  // for every pixel in the page, before any region segments are decoded
  // or drawn." (7.4.8.5)
  bitmap.reinitialize(
    page_info.width,
    height,
    page_info.flags.default_pixel != 0,
  )
  page.reset(page_info)
}
