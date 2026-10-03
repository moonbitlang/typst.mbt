// Port of `hayro-jbig2/src/decode/text.rs`: text region segment parsing and
// decoding (7.4.3, 6.4).

///|
/// `i32::checked_add`.
fn checked_add_i32(a : Int, b : Int) -> Int? {
  let r = a.to_int64() + b.to_int64()
  if r < -0x80000000L || r > 0x7FFFFFFFL {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// `i32::checked_mul`.
fn checked_mul_i32(a : Int, b : Int) -> Int? {
  let r = a.to_int64() * b.to_int64()
  if r < -0x80000000L || r > 0x7FFFFFFFL {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// Decode a text region segment (6.4).
fn text_decode(
  header : TextRegionHeader,
  symbols : Array[Bitmap],
  referred_tables : Array[HuffmanTable],
  standard_tables : StandardHuffmanTables,
  scratch : ScratchBuffers,
) -> RegionBitmap raise DecodeError {
  let bitmap = Bitmap::new_with(
    header.region_info.width,
    header.region_info.height,
    header.region_info.x_location,
    header.region_info.y_location,
    header.flags.default_pixel,
  )
  text_decode_into(
    header, symbols, referred_tables, standard_tables, bitmap, scratch,
  )
  { bitmap, combination_operator: header.region_info.combination_operator, }
}

///|
fn text_decode_into(
  header : TextRegionHeader,
  symbols : Array[Bitmap],
  referred_tables : Array[HuffmanTable],
  standard_tables : StandardHuffmanTables,
  bitmap : Bitmap,
  scratch : ScratchBuffers,
) -> Unit raise DecodeError {
  if header.flags.use_huffman {
    let reader = Reader::new(header.data)
    let ctx = DecodeContext::new_huffman(
      reader, header, referred_tables, standard_tables,
    )
    text_decode_with(ctx, symbols, header, bitmap)
  } else {
    let decoder = ArithmeticDecoder::new(header.data)
    let num_symbols = symbols.length().reinterpret_as_uint()
    let symbol_code_length = 32U -
      (if num_symbols == 0 { 0U } else { num_symbols - 1 })
      .clz()
      .reinterpret_as_uint()
    let contexts = TextRegionContexts::new(symbol_code_length)
    let num_gr_contexts = 1 << header.flags.refinement_template.context_bits()
    let gr_contexts = scratch.reset_contexts(num_gr_contexts)
    let ctx = DecodeContext::new_arithmetic(decoder, contexts, gr_contexts)
    text_decode_with(ctx, symbols, header, bitmap)
  }
}

///|
/// Decode a text region segment with a decode context (6.4).
fn text_decode_with(
  ctx : DecodeContext,
  symbols : Array[Bitmap],
  header : TextRegionHeader,
  region : Bitmap,
) -> Unit raise DecodeError {
  let strip_size = header.strip_size()

  // Inspired by Chromium's limit:
  // https://pdfium.googlesource.com/pdfium/%2B/refs/heads/main/core/fxcodec/jbig2/jbig2_context.cpp#666
  let max_instances = header.segment_data_len.to_int64() * 32
  if header.num_instances.to_int64() > max_instances {
    raise Symbol(TooManyInstances)
  }
  let first_delta_t = ctx.read_strip_delta_t(strip_size)
  if first_delta_t == -0x80000000 {
    raise Overflow(PlacementCoordinate)
  }
  let mut strip_t = -first_delta_t
  let mut first_s : Int = 0
  let mut instance_count = 0U
  while instance_count < header.num_instances {
    let delta_t = ctx.read_strip_delta_t(strip_size)
    strip_t = ok_or(
      checked_add_i32(strip_t, delta_t),
      Overflow(PlacementCoordinate),
    )
    let mut first_symbol_in_strip = true
    let mut current_s = 0
    while true {
      // Prevent infinite loop for invalid files.
      if instance_count > header.num_instances {
        raise Symbol(TooManySymbols)
      }
      if first_symbol_in_strip {
        let delta_first_s = ctx.read_first_s()
        first_s = ok_or(
          checked_add_i32(first_s, delta_first_s),
          Overflow(PlacementCoordinate),
        )
        current_s = first_s
        first_symbol_in_strip = false
      } else {
        guard ctx.read_delta_s() is Some(delta_s) else {
          // OOB - end of strip.
          break
        }
        current_s = ok_or(
          checked_add_i32(current_s, delta_s).bind(v => {
            checked_add_i32(v, header.flags.delta_s_offset)
          }),
          Overflow(PlacementCoordinate),
        )
      }
      let current_t = ctx.read_symbol_t(strip_size, header.flags.log_strip_size)
      let symbol_t = ok_or(
        checked_add_i32(strip_t, current_t),
        Overflow(PlacementCoordinate),
      )
      let symbol_id = ctx.read_symbol_id()
      let symbol_bitmap = decode_symbol_instance_bitmap(
        ctx, symbols, header, symbol_id,
      )
      let symbol_bitmap_ref : Bitmap = match symbol_bitmap {
        Reference(idx) => ok_or(get_symbol(symbols, idx), Symbol(OutOfRange))
        Owned(bitmap) => bitmap
      }
      let symbol_width = symbol_bitmap_ref.width.reinterpret_as_int()
      let symbol_height = symbol_bitmap_ref.height.reinterpret_as_int()
      let corner = header.flags.reference_corner
      let transposed = header.flags.transposed
      if !transposed && (corner == TopRight || corner == BottomRight) {
        current_s = ok_or(
          checked_add_i32(current_s, symbol_width - 1),
          Overflow(PlacementCoordinate),
        )
      } else if transposed && (corner == BottomLeft || corner == BottomRight) {
        current_s = ok_or(
          checked_add_i32(current_s, symbol_height - 1),
          Overflow(PlacementCoordinate),
        )
      }
      let symbol_s = current_s
      let (x, y) = if !transposed {
        match corner {
          TopLeft => (symbol_s, symbol_t)
          TopRight => (symbol_s - symbol_width + 1, symbol_t)
          BottomLeft => (symbol_s, symbol_t - symbol_height + 1)
          BottomRight =>
            (symbol_s - symbol_width + 1, symbol_t - symbol_height + 1)
        }
      } else {
        match corner {
          TopLeft => (symbol_t, symbol_s)
          TopRight => (symbol_t - symbol_width + 1, symbol_s)
          BottomLeft => (symbol_t, symbol_s - symbol_height + 1)
          BottomRight =>
            (symbol_t - symbol_width + 1, symbol_s - symbol_height + 1)
        }
      }
      region.combine(symbol_bitmap_ref, x, y, header.flags.combination_operator)
      if !transposed && (corner == TopLeft || corner == BottomLeft) {
        current_s = ok_or(
          checked_add_i32(current_s, symbol_width - 1),
          Overflow(PlacementCoordinate),
        )
      } else if transposed && (corner == TopLeft || corner == TopRight) {
        current_s = ok_or(
          checked_add_i32(current_s, symbol_height - 1),
          Overflow(PlacementCoordinate),
        )
      }
      instance_count += 1
    }
  }
}

///|
/// `symbols.get(idx)`, where a negative `idx` stands for a `usize` that is
/// out of range anyway.
fn get_symbol(symbols : Array[Bitmap], idx : Int) -> Bitmap? {
  if idx >= 0 && idx < symbols.length() {
    Some(symbols[idx])
  } else {
    None
  }
}

///|
/// Shared integer decoder contexts for text region decoding.
priv struct TextRegionContexts {
  /// IADT: Strip delta T decoder (6.4.6)
  iadt : IntegerDecoder
  /// IAFS: First symbol S coordinate decoder (6.4.7)
  iafs : IntegerDecoder
  /// IADS: Subsequent symbol S coordinate decoder (6.4.8)
  iads : IntegerDecoder
  /// IAIT: Symbol instance T coordinate decoder (6.4.9)
  iait : IntegerDecoder
  /// IAID: Symbol ID decoder (6.4.10)
  iaid : SymbolIdDecoder
  /// IARI: Refinement image indicator decoder (6.4.11)
  iari : IntegerDecoder
  /// IARDW: Refinement delta width decoder (6.4.11.1)
  iardw : IntegerDecoder
  /// IARDH: Refinement delta height decoder (6.4.11.2)
  iardh : IntegerDecoder
  /// IARDX: Refinement X offset decoder (6.4.11.3)
  iardx : IntegerDecoder
  /// IARDY: Refinement Y offset decoder (6.4.11.4)
  iardy : IntegerDecoder
}

///|
/// Create new text region contexts with the given symbol code length.
fn TextRegionContexts::new(symbol_code_length : UInt) -> TextRegionContexts {
  {
    iadt: IntegerDecoder::new(),
    iafs: IntegerDecoder::new(),
    iads: IntegerDecoder::new(),
    iait: IntegerDecoder::new(),
    iaid: SymbolIdDecoder::new(symbol_code_length),
    iari: IntegerDecoder::new(),
    iardw: IntegerDecoder::new(),
    iardh: IntegerDecoder::new(),
    iardx: IntegerDecoder::new(),
    iardy: IntegerDecoder::new(),
  }
}

///|
/// (Upstream's variants are `Huffman` and `Arithmetic`; renamed to not clash
/// with `DecodeError::Huffman`.)
priv enum DecodeContext {
  HuffmanCoding(
    reader~ : Reader,
    tables~ : TextRegionHuffmanTables,
    symbol_codes~ : HuffmanTable
  )
  ArithmeticCoding(
    decoder~ : ArithmeticDecoder,
    contexts~ : TextRegionContexts,
    gr_contexts~ : FixedArray[Byte]
  )
}

///|
fn DecodeContext::new_huffman(
  reader : Reader,
  header : TextRegionHeader,
  referred_tables : Array[HuffmanTable],
  standard_tables : StandardHuffmanTables,
) -> DecodeContext raise DecodeError {
  let huffman_flags = ok_or(header.huffman_flags, Huffman(InvalidSelection))
  let tables = select_huffman_tables(
    huffman_flags, referred_tables, standard_tables,
  )
  let symbol_codes = ok_or(header.symbol_id_table, Huffman(MissingTables))
  HuffmanCoding(reader~, tables~, symbol_codes~)
}

///|
fn DecodeContext::new_arithmetic(
  decoder : ArithmeticDecoder,
  contexts : TextRegionContexts,
  gr_contexts : FixedArray[Byte],
) -> DecodeContext {
  ArithmeticCoding(decoder~, contexts~, gr_contexts~)
}

///|
fn DecodeContext::read_strip_delta_t(
  self : DecodeContext,
  strip_size : UInt,
) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) => {
      let value = tables.delta_t.decode_no_oob(reader)
      ok_or(
        checked_mul_i32(value, strip_size.reinterpret_as_int()),
        Symbol(InvalidStripDelta),
      )
    }
    ArithmeticCoding(decoder~, contexts~, ..) => {
      let value = ok_or(contexts.iadt.decode(decoder), Symbol(UnexpectedOob))
      ok_or(
        checked_mul_i32(value, strip_size.reinterpret_as_int()),
        Symbol(InvalidStripDelta),
      )
    }
  }
}

///|
/// Decode first symbol instance S coordinate (6.4.7).
fn DecodeContext::read_first_s(self : DecodeContext) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) => tables.first_s.decode_no_oob(reader)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iafs.decode(decoder), Symbol(UnexpectedOob))
  }
}

///|
/// Decode subsequent symbol instance S coordinate (6.4.8).
fn DecodeContext::read_delta_s(self : DecodeContext) -> Int? raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) => tables.delta_s.decode(reader)
    ArithmeticCoding(decoder~, contexts~, ..) => contexts.iads.decode(decoder)
  }
}

///|
/// Decode symbol instance T coordinate (6.4.9).
fn DecodeContext::read_symbol_t(
  self : DecodeContext,
  strip_size : UInt,
  log_strip_size : Int,
) -> Int raise DecodeError {
  if strip_size == 1 {
    return 0
  }
  match self {
    HuffmanCoding(reader~, ..) =>
      ok_or(reader.read_bits(log_strip_size), Huffman(InvalidCode)).reinterpret_as_int()
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iait.decode(decoder), Symbol(UnexpectedOob))
  }
}

///|
/// Decode symbol instance symbol ID (6.4.10).
///
/// (Upstream's `usize`; a negative result stands for an out-of-range one.)
fn DecodeContext::read_symbol_id(self : DecodeContext) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, symbol_codes~, ..) =>
      symbol_codes.decode_no_oob(reader)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      contexts.iaid.decode(decoder).reinterpret_as_int()
  }
}

///|
fn DecodeContext::read_refinement_flag(
  self : DecodeContext,
) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, ..) => ok_or(reader.read_bit(), eof)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iari.decode(decoder), Symbol(UnexpectedOob)) & 0xFF
  }
}

///|
/// Decode symbol instance refinement delta width (6.4.11.1).
fn DecodeContext::read_refinement_delta_width(
  self : DecodeContext,
) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) =>
      tables.refinement_width.decode_no_oob(reader)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iardw.decode(decoder), Symbol(UnexpectedOob))
  }
}

///|
/// Decode symbol instance refinement delta height (6.4.11.2).
fn DecodeContext::read_refinement_delta_height(
  self : DecodeContext,
) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) =>
      tables.refinement_height.decode_no_oob(reader)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iardh.decode(decoder), Symbol(UnexpectedOob))
  }
}

///|
/// Decode symbol instance refinement x offset (6.4.11.3).
fn DecodeContext::read_refinement_x_offset(
  self : DecodeContext,
) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) =>
      tables.refinement_x.decode_no_oob(reader)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iardx.decode(decoder), Symbol(UnexpectedOob))
  }
}

///|
/// Decode symbol instance refinement y offset (6.4.11.4).
fn DecodeContext::read_refinement_y_offset(
  self : DecodeContext,
) -> Int raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) =>
      tables.refinement_y.decode_no_oob(reader)
    ArithmeticCoding(decoder~, contexts~, ..) =>
      ok_or(contexts.iardy.decode(decoder), Symbol(UnexpectedOob))
  }
}

///|
/// Decode the refinement bitmap, steps 5) to 7) of 6.4.11.
fn DecodeContext::decode_refinement_bitmap(
  self : DecodeContext,
  refined : Bitmap,
  reference_bitmap : Bitmap,
  reference_x_offset : Int,
  reference_y_offset : Int,
  refinement_template : RefinementTemplate,
  refinement_at_pixels : Array[AdaptiveTemplatePixel],
) -> Unit raise DecodeError {
  match self {
    HuffmanCoding(reader~, tables~, ..) => {
      let refinement_data_size = tables.refinement_size
        .decode_no_oob(reader)
        .reinterpret_as_uint()
      reader.align()
      let refinement_data = ok_or(
        reader.read_bytes(refinement_data_size.to_int64()),
        eof,
      )
      let decoder = ArithmeticDecoder::new(refinement_data)
      let num_context_bits = refinement_template.context_bits()
      let contexts = new_contexts(1 << num_context_bits)
      generic_refinement_decode_bitmap(
        decoder, contexts, refined, reference_bitmap, reference_x_offset, reference_y_offset,
        refinement_template, refinement_at_pixels, false,
      )
    }
    ArithmeticCoding(decoder~, gr_contexts~, ..) =>
      generic_refinement_decode_bitmap(
        decoder, gr_contexts, refined, reference_bitmap, reference_x_offset, reference_y_offset,
        refinement_template, refinement_at_pixels, false,
      )
  }
}

///|
/// Result of determining a symbol instance bitmap.
priv enum SymbolBitmap {
  /// Use the symbol at this index directly (`R_I` = 0).
  Reference(Int)
  /// Use this refined bitmap (`R_I` = 1).
  Owned(Bitmap)
}

///|
/// Decode the symbol instance bitmap (6.4.11).
fn decode_symbol_instance_bitmap(
  ctx : DecodeContext,
  symbols : Array[Bitmap],
  header : TextRegionHeader,
  symbol_id : Int,
) -> SymbolBitmap raise DecodeError {
  if !header.flags.use_refinement || ctx.read_refinement_flag() == 0 {
    return Reference(symbol_id)
  }

  // Otherwise, the refinement flag was 1.

  let reference_bitmap = ok_or(
    get_symbol(symbols, symbol_id),
    Symbol(OutOfRange),
  )
  let rdw = ctx.read_refinement_delta_width()
  let rdh = ctx.read_refinement_delta_height()
  let rdx = ctx.read_refinement_x_offset()
  let rdy = ctx.read_refinement_y_offset()
  let refined_width = match
    checked_add_i32(reference_bitmap.width.reinterpret_as_int(), rdw) {
    Some(v) if v >= 0 => v.reinterpret_as_uint()
    _ => raise Overflow(BitmapDimension)
  }
  let refined_height = match
    checked_add_i32(reference_bitmap.height.reinterpret_as_int(), rdh) {
    Some(v) if v >= 0 => v.reinterpret_as_uint()
    _ => raise Overflow(BitmapDimension)
  }
  // (`div_euclid(2)` is an arithmetic shift.)
  let reference_x_offset = ok_or(
    checked_add_i32(rdw >> 1, rdx),
    Overflow(ReferenceOffset),
  )
  let reference_y_offset = ok_or(
    checked_add_i32(rdh >> 1, rdy),
    Overflow(ReferenceOffset),
  )
  let refined_bitmap = Bitmap::new(refined_width, refined_height)
  ctx.decode_refinement_bitmap(
    refined_bitmap,
    reference_bitmap,
    reference_x_offset,
    reference_y_offset,
    header.flags.refinement_template,
    header.refinement_at_pixels,
  )
  Owned(refined_bitmap)
}

///|
/// Select Huffman tables based on flags (7.4.3.1.6).
fn select_huffman_tables(
  flags : TextRegionHuffmanFlags,
  custom_tables : Array[HuffmanTable],
  standard_tables : StandardHuffmanTables,
) -> TextRegionHuffmanTables raise DecodeError {
  let mut custom_table_idx = 0
  fn get_custom() -> HuffmanTable raise DecodeError {
    guard custom_table_idx < custom_tables.length() else {
      raise Huffman(MissingTables)
    }
    let table = custom_tables[custom_table_idx]
    custom_table_idx += 1
    table
  }

  // "1) SBHUFFFS"
  let first_s = match flags.first_s_table {
    0 => standard_tables.table_f()
    1 => standard_tables.table_g()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "2) SBHUFFDS"
  let delta_s = match flags.delta_s_table {
    0 => standard_tables.table_h()
    1 => standard_tables.table_i()
    2 => standard_tables.table_j()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "3) SBHUFFDT"
  let delta_t = match flags.delta_t_table {
    0 => standard_tables.table_k()
    1 => standard_tables.table_l()
    2 => standard_tables.table_m()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "4) SBHUFFRDW"
  let refinement_width = match flags.refinement_width_table {
    0 => standard_tables.table_n()
    1 => standard_tables.table_o()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "5) SBHUFFRDH"
  let refinement_height = match flags.refinement_height_table {
    0 => standard_tables.table_n()
    1 => standard_tables.table_o()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "6) SBHUFFRDY"
  let refinement_y = match flags.refinement_y_table {
    0 => standard_tables.table_n()
    1 => standard_tables.table_o()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "7) SBHUFFRDX"
  let refinement_x = match flags.refinement_x_table {
    0 => standard_tables.table_n()
    1 => standard_tables.table_o()
    3 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }

  // "8) SBHUFFRSIZE"
  let refinement_size = match flags.refinement_size_table {
    0 => standard_tables.table_a()
    1 => get_custom()
    _ => raise Huffman(InvalidSelection)
  }
  {
    first_s,
    delta_s,
    delta_t,
    refinement_width,
    refinement_height,
    refinement_y,
    refinement_x,
    refinement_size,
  }
}

///|
/// Decode the symbol ID Huffman table (7.4.3.1.7).
fn decode_symbol_id_huffman_table(
  reader : Reader,
  num_symbols : UInt,
) -> HuffmanTable raise DecodeError {
  let runcode_lines = []
  for runcode_idx in 0..<35 {
    let prefix_length = ok_or(reader.read_bits(4), Huffman(InvalidCode)).reinterpret_as_int()
    runcode_lines.push(TableLine::new(runcode_idx, prefix_length, 0))
  }
  let runcode_table = HuffmanTable::build(runcode_lines)
  let num_symbols = num_symbols.to_uint64()
  let symbol_code_lengths : Array[Int] = []
  while symbol_code_lengths.length().to_uint64() < num_symbols {
    let runcode = runcode_table.decode_no_oob(reader)
    match runcode {
      0..=31 => symbol_code_lengths.push(runcode)
      32 => {
        // Copy previous 3-6 times.
        let extra_bits = ok_or(reader.read_bits(2), Huffman(InvalidCode)).reinterpret_as_int()
        let repeat = extra_bits + 3
        let previous_length = ok_or(
          symbol_code_lengths.last(),
          Huffman(InvalidCode),
        )
        for _ in 0..<repeat {
          symbol_code_lengths.push(previous_length)
        }
      }
      33 => {
        // Repeat 0 length 3-10 times.
        let extra_bits = ok_or(reader.read_bits(3), Huffman(InvalidCode)).reinterpret_as_int()
        let repeat = extra_bits + 3
        for _ in 0..<repeat {
          symbol_code_lengths.push(0)
        }
      }
      34 => {
        // Repeat 0 length 11-138 times.
        let extra_bits = ok_or(reader.read_bits(7), Huffman(InvalidCode)).reinterpret_as_int()
        let repeat = extra_bits + 11
        for _ in 0..<repeat {
          symbol_code_lengths.push(0)
        }
      }
      _ => raise Huffman(InvalidCode)
    }
  }
  if symbol_code_lengths.length().to_uint64() != num_symbols {
    raise Huffman(InvalidCode)
  }
  reader.align()
  let symbol_lines = symbol_code_lengths.mapi((symbol_idx, prefix_length) => {
    TableLine::new(symbol_idx, prefix_length, 0)
  })
  HuffmanTable::build(symbol_lines)
}

///|
priv struct TextRegionHuffmanTables {
  first_s : HuffmanTable
  delta_s : HuffmanTable
  delta_t : HuffmanTable
  refinement_width : HuffmanTable
  refinement_height : HuffmanTable
  refinement_y : HuffmanTable
  refinement_x : HuffmanTable
  refinement_size : HuffmanTable
}

///|
/// Reference corner for symbol placement.
priv enum ReferenceCorner {
  BottomLeft
  TopLeft
  BottomRight
  TopRight
} derive(Eq)

///|
fn ReferenceCorner::from_byte(value : Int) -> ReferenceCorner {
  match value {
    0 => BottomLeft
    1 => TopLeft
    2 => BottomRight
    _ => TopRight
  }
}

///|
/// Parsed text region segment flags (7.4.3.1.1).
priv struct TextRegionFlags {
  use_huffman : Bool
  use_refinement : Bool
  log_strip_size : Int
  reference_corner : ReferenceCorner
  transposed : Bool
  combination_operator : CombinationOperator
  default_pixel : Bool
  /// (Upstream's `i8`.)
  delta_s_offset : Int
  refinement_template : RefinementTemplate
}

///|
/// Text region segment Huffman flags (7.4.3.1.2).
priv struct TextRegionHuffmanFlags {
  first_s_table : Int
  delta_s_table : Int
  delta_t_table : Int
  refinement_width_table : Int
  refinement_height_table : Int
  refinement_y_table : Int
  refinement_x_table : Int
  refinement_size_table : Int
}

///|
/// Parsed text region segment header (7.4.3.1).
priv struct TextRegionHeader {
  region_info : RegionSegmentInfo
  flags : TextRegionFlags
  huffman_flags : TextRegionHuffmanFlags?
  refinement_at_pixels : Array[AdaptiveTemplatePixel]
  num_instances : UInt
  symbol_id_table : HuffmanTable?
  segment_data_len : Int
  data : BytesView
}

///|
fn TextRegionHeader::strip_size(self : TextRegionHeader) -> UInt {
  1U << self.flags.log_strip_size
}

///|
/// Parse text region segment flags (7.4.3.1.1).
fn parse_text_region_flags(
  reader : Reader,
) -> TextRegionFlags raise DecodeError {
  let flags_word = ok_or(reader.read_u16(), eof).reinterpret_as_int()
  let use_huffman = (flags_word & 0x0001) != 0
  let use_refinement = (flags_word & 0x0002) != 0
  let log_strip_size = (flags_word >> 2) & 0x03
  let reference_corner = ReferenceCorner::from_byte((flags_word >> 4) & 0x03)
  let transposed = (flags_word & 0x0040) != 0
  let combination_operator = CombinationOperator::from_value(
    (flags_word >> 7) & 0x03,
  )
  let default_pixel = (flags_word & 0x0200) != 0
  let delta_s_offset_raw = (flags_word >> 10) & 0x1F
  let delta_s_offset = if (delta_s_offset_raw & 0x10) != 0 {
    i8_of((delta_s_offset_raw | 0xE0).to_byte())
  } else {
    delta_s_offset_raw
  }
  let refinement_template = RefinementTemplate::from_byte(flags_word >> 15)
  {
    use_huffman,
    use_refinement,
    log_strip_size,
    reference_corner,
    transposed,
    combination_operator,
    default_pixel,
    delta_s_offset,
    refinement_template,
  }
}

///|
/// Parse text region Huffman flags (7.4.3.1.2).
fn parse_text_region_huffman_flags(
  reader : Reader,
) -> TextRegionHuffmanFlags raise DecodeError {
  let flags_word = ok_or(reader.read_u16(), eof).reinterpret_as_int()
  let first_s_table = flags_word & 0x03
  let delta_s_table = (flags_word >> 2) & 0x03
  let delta_t_table = (flags_word >> 4) & 0x03
  let refinement_width_table = (flags_word >> 6) & 0x03
  let refinement_height_table = (flags_word >> 8) & 0x03
  let refinement_y_table = (flags_word >> 10) & 0x03
  let refinement_x_table = (flags_word >> 12) & 0x03
  let refinement_size_table = (flags_word >> 14) & 0x01
  {
    first_s_table,
    delta_s_table,
    delta_t_table,
    refinement_width_table,
    refinement_height_table,
    refinement_y_table,
    refinement_x_table,
    refinement_size_table,
  }
}

///|
/// Parse a text region segment header (7.4.3.1).
fn text_parse(
  reader : Reader,
  num_symbols : UInt,
) -> TextRegionHeader raise DecodeError {
  let segment_data_len = ok_or(reader.tail(), eof).length()
  let region_info = parse_region_segment_info(reader)
  let flags = parse_text_region_flags(reader)
  let huffman_flags = if flags.use_huffman {
    Some(parse_text_region_huffman_flags(reader))
  } else {
    None
  }
  let refinement_at_pixels = if flags.use_refinement &&
    flags.refinement_template == RTemplate0 {
    parse_refinement_at_pixels(reader)
  } else {
    []
  }
  let num_instances = ok_or(reader.read_u32(), eof)
  let symbol_id_table = if flags.use_huffman {
    Some(decode_symbol_id_huffman_table(reader, num_symbols))
  } else {
    None
  }
  let data = ok_or(reader.tail(), eof)
  {
    region_info,
    flags,
    huffman_flags,
    refinement_at_pixels,
    num_instances,
    symbol_id_table,
    segment_data_len,
    data,
  }
}
