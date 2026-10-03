// Port of `hayro-jbig2/src/decode/symbol.rs`: symbol dictionary segment
// parsing and decoding (7.4.2, 6.5).

///|
const MAX_SYMBOLS : UInt = 0xFFFF

///|
/// `u32::checked_add_signed`.
fn checked_add_signed_u32(a : UInt, b : Int) -> UInt? {
  let r = a.to_int64() + b.to_int64()
  if r < 0L || r > 0xFFFFFFFFL {
    None
  } else {
    Some(r.to_int().reinterpret_as_uint())
  }
}

///|
/// `u32::checked_add`.
fn checked_add_u32(a : UInt, b : UInt) -> UInt? {
  let r = a + b
  if r < a {
    None
  } else {
    Some(r)
  }
}

///|
/// Decode a symbol dictionary segment (7.4.2, 6.5).
fn symbol_decode(
  header : SymbolDictionaryHeader,
  input_symbols : Array[Bitmap],
  referred_tables : Array[HuffmanTable],
  standard_tables : StandardHuffmanTables,
  input_contexts : RetainedContexts?,
) -> SymbolDictionary raise DecodeError {
  let num_new_symbols = header.num_new_symbols
  let ctx : SymbolDecodeContext = {
    a_ctx: ArithmeticContext::new(header.data, header, input_contexts),
    h_ctx: HuffmanContext::new(
      header.data,
      header,
      referred_tables,
      standard_tables,
    ),
    symbols: Symbols::new(input_symbols),
    symbol_widths: [],
    height_class_first_symbol: 0,
    symbols_decoded_count: 0,
    total_width: 0,
    height_class_height: 0,
    header,
    standard_tables,
  }
  fn read_height_class_delta(
    ctx : SymbolDecodeContext,
  ) -> Int? raise DecodeError {
    if ctx.header.flags.use_huffman {
      ctx.h_ctx.height_class_delta_table.decode(ctx.h_ctx.reader)
    } else {
      ctx.a_ctx.height_class_delta_decoder.decode(ctx.a_ctx.decoder)
    }
  }

  fn read_symbol_width_delta(
    ctx : SymbolDecodeContext,
  ) -> Int? raise DecodeError {
    if ctx.header.flags.use_huffman {
      ctx.h_ctx.symbol_width_delta_table.decode(ctx.h_ctx.reader)
    } else {
      ctx.a_ctx.symbol_width_delta_decoder.decode(ctx.a_ctx.decoder)
    }
  }

  while ctx.symbols_decoded_count < num_new_symbols {
    let height_class_delta = ok_or(
      read_height_class_delta(ctx),
      Symbol(UnexpectedOob),
    )
    ctx.height_class_height = ok_or(
      checked_add_signed_u32(ctx.height_class_height, height_class_delta),
      Overflow(BitmapDimension),
    )
    let mut symbol_width : UInt = 0
    ctx.total_width = 0
    ctx.height_class_first_symbol = ctx.symbols_decoded_count

    // "If the result of this decoding is OOB then all the symbols
    // in this height class have been decoded."
    while read_symbol_width_delta(ctx) is Some(width_delta) {
      // Prevent infinite loop for invalid files.
      if ctx.symbols_decoded_count >= num_new_symbols {
        raise Symbol(TooManySymbols)
      }
      symbol_width = ok_or(
        checked_add_signed_u32(symbol_width, width_delta),
        Overflow(BitmapDimension),
      )
      ctx.total_width = ok_or(
        checked_add_u32(ctx.total_width, symbol_width),
        Overflow(BitmapDimension),
      )
      match (ctx.header.flags.use_huffman, ctx.header.flags.use_refagg) {
        (false, false) => {
          // Decode a single symbol using a simple generic decoding procedure,
          // described in 6.5.8.1.
          let region = Bitmap::new(symbol_width, ctx.height_class_height)
          decode_bitmap_arithmetic_coding(
            region,
            ctx.a_ctx.decoder,
            ctx.a_ctx.generic_region_contexts,
            ctx.header.flags.template,
            false,
            ctx.header.adaptive_template_pixels,
          )
          ctx.symbols.new.push(region)
        }
        (true, false) =>
          // Decode a single symbol width. We don't actually decode the symbols
          // yet, those will be decoded later on from the collective bitmap.
          ctx.symbol_widths.push(symbol_width)
        (_, true) => {
          // Also decode a single symbol, but using refinement-aggregation.
          // In this case, we can have both, huffman and arithmetic coding.
          let symbol = decode_refinement_aggregation_bitmap(ctx, symbol_width)
          ctx.symbols.new.push(symbol)
        }
      }
      ctx.symbols_decoded_count += 1
    }
    if ctx.header.flags.use_huffman && !ctx.header.flags.use_refagg {
      // In case we have huffman coding and no refinement-aggregation, we use
      // the previously decoded symbol widths to decode the collective bitmap
      // and extract the individual symbols from that bitmap.
      decode_height_class_collective_bitmap(ctx)
    }
  }
  let exported = export_symbols(ctx)
  let retained_contexts = if ctx.header.flags.bitmap_context_retained {
    Some({
      generic_region: ctx.a_ctx.generic_region_contexts,
      refinement_region: ctx.a_ctx.refinement_region_contexts,
    })
  } else {
    None
  }
  { exported_symbols: exported, retained_contexts, }
}

///|
priv struct RetainedContexts {
  generic_region : FixedArray[Byte]
  refinement_region : FixedArray[Byte]
}

///|
/// A decoded symbol dictionary segment.
priv struct SymbolDictionary {
  exported_symbols : Array[Bitmap]
  retained_contexts : RetainedContexts?
}

///|
/// `32 - (n - 1).leading_zeros()` (with `u32` wrapping).
fn symbol_code_length_of(n : UInt) -> UInt {
  32U - (n - 1).clz().reinterpret_as_uint()
}

///|
/// Decode a symbol bitmap using refinement/aggregate coding (6.5.8.2).
fn decode_refinement_aggregation_bitmap(
  ctx : SymbolDecodeContext,
  symbol_width : UInt,
) -> Bitmap raise DecodeError {
  // 6.5.8.2.1 Number of symbol instances in the aggregation.
  let aggregation_instance_count = ok_or(
    if ctx.header.flags.use_huffman {
      ctx.h_ctx.aggregation_instance_count_table.decode(ctx.h_ctx.reader)
    } else {
      ctx.a_ctx.aggregation_instance_count_decoder.decode(ctx.a_ctx.decoder)
    },
    Symbol(UnexpectedOob),
  )
  if aggregation_instance_count == 1 {
    decode_refinement_bitmap(ctx, symbol_width)
  } else if aggregation_instance_count > 1 {
    decode_aggregation_bitmap(
      ctx,
      symbol_width,
      aggregation_instance_count.reinterpret_as_uint(),
    )
  } else {
    raise Symbol(Invalid)
  }
}

///|
/// Decode a refinement bitmap symbol with a single aggregate (6.5.8.2).
fn decode_refinement_bitmap(
  ctx : SymbolDecodeContext,
  symbol_width : UInt,
) -> Bitmap raise DecodeError {
  let use_huffman = ctx.header.flags.use_huffman
  let mut symbol_code_length = symbol_code_length_of(ctx.total_symbols())
  let (symbol_id, refinement_x_offset, refinement_y_offset) = if use_huffman {
    // See 6.5.8.2.3, the value should be at least 1 if we use huffman coding.
    if symbol_code_length < 1 {
      symbol_code_length = 1
    }
    let symbol_id = ok_or(
      ctx.h_ctx.reader.read_bits(symbol_code_length.reinterpret_as_int()),
      eof,
    ).reinterpret_as_int()
    let refinement_x_offset = ok_or(
      ctx.standard_tables.table_o().decode(ctx.h_ctx.reader),
      Huffman(UnexpectedOob),
    )
    let refinement_y_offset = ok_or(
      ctx.standard_tables.table_o().decode(ctx.h_ctx.reader),
      Huffman(UnexpectedOob),
    )
    (symbol_id, refinement_x_offset, refinement_y_offset)
  } else {
    // Note that the contexts should be reused across multiple
    // bitmaps in the same symbol dictionary.
    let contexts = ctx.a_ctx.text_region_contexts(symbol_code_length)
    let symbol_id = contexts.iaid.decode(ctx.a_ctx.decoder).reinterpret_as_int()
    let refinement_x_offset = ok_or(
      contexts.iardx.decode(ctx.a_ctx.decoder),
      Symbol(UnexpectedOob),
    )
    let refinement_y_offset = ok_or(
      contexts.iardy.decode(ctx.a_ctx.decoder),
      Symbol(UnexpectedOob),
    )
    (symbol_id, refinement_x_offset, refinement_y_offset)
  }
  let reference_region = ok_or(ctx.symbols.get(symbol_id), Symbol(OutOfRange))
  let region = Bitmap::new(symbol_width, ctx.height_class_height)
  if use_huffman {
    let bitmap_size = ok_or(
      ctx.standard_tables.table_a().decode(ctx.h_ctx.reader),
      Huffman(UnexpectedOob),
    )
    ctx.h_ctx.reader.align()
    // (`bitmap_size as usize`: a negative `i32` is out of range.)
    let bitmap_data = ok_or(
      ctx.h_ctx.reader.read_bytes(bitmap_size.to_int64()),
      eof,
    )
    let bitmap_decoder = ArithmeticDecoder::new(bitmap_data)
    generic_refinement_decode_bitmap(
      bitmap_decoder,
      ctx.a_ctx.refinement_region_contexts,
      region,
      reference_region,
      refinement_x_offset,
      refinement_y_offset,
      ctx.header.flags.refinement_template,
      ctx.header.refinement_at_pixels,
      false,
    )
  } else {
    generic_refinement_decode_bitmap(
      ctx.a_ctx.decoder,
      ctx.a_ctx.refinement_region_contexts,
      region,
      reference_region,
      refinement_x_offset,
      refinement_y_offset,
      ctx.header.flags.refinement_template,
      ctx.header.refinement_at_pixels,
      false,
    )
  }
  region
}

///|
/// Decode an aggregation bitmap with more than one aggregate (6.5.8.2).
fn decode_aggregation_bitmap(
  ctx : SymbolDecodeContext,
  symbol_width : UInt,
  aggregation_instance_count : UInt,
) -> Bitmap raise DecodeError {
  let use_huffman = ctx.header.flags.use_huffman

  // Concatenate input and new symbols.
  let all_symbols : Array[Bitmap] = []
  all_symbols.append(ctx.symbols.input)
  all_symbols.append(ctx.symbols.new)

  // Set all parameters according to Table 17.

  let symbol_code_length = symbol_code_length_of(ctx.total_symbols())
  let symbol_id_table = if use_huffman {
    Some(HuffmanTable::build_uniform(ctx.total_symbols(), symbol_code_length))
  } else {
    None
  }
  let huffman_flags : TextRegionHuffmanFlags? = if use_huffman {
    Some({
      first_s_table: 0,
      delta_s_table: 0,
      delta_t_table: 0,
      refinement_width_table: 1,
      refinement_height_table: 1,
      refinement_y_table: 1,
      refinement_x_table: 1,
      refinement_size_table: 0,
    })
  } else {
    None
  }
  let header : TextRegionHeader = {
    region_info: {
      width: symbol_width,
      height: ctx.height_class_height,
      x_location: 0,
      y_location: 0,
      combination_operator: Or,
      _colour_extension: false,
    },
    flags: {
      use_huffman,
      use_refinement: true,
      log_strip_size: 0,
      reference_corner: TopLeft,
      transposed: false,
      combination_operator: Or,
      default_pixel: false,
      delta_s_offset: 0,
      refinement_template: ctx.header.flags.refinement_template,
    },
    huffman_flags,
    refinement_at_pixels: ctx.header.refinement_at_pixels.copy(),
    num_instances: aggregation_instance_count,
    symbol_id_table,
    segment_data_len: ctx.header.data.length(),
    data: b""[:], // Data comes from parent decoder context, not the header.
  }
  let decode_ctx = if use_huffman {
    DecodeContext::new_huffman(
      ctx.h_ctx.reader,
      header,
      [],
      ctx.standard_tables,
    )
  } else {
    let contexts = ctx.a_ctx.text_region_contexts(symbol_code_length)
    DecodeContext::new_arithmetic(
      ctx.a_ctx.decoder,
      contexts,
      ctx.a_ctx.refinement_region_contexts,
    )
  }
  let bitmap = Bitmap::new_with(
    header.region_info.width,
    header.region_info.height,
    header.region_info.x_location,
    header.region_info.y_location,
    header.flags.default_pixel,
  )
  text_decode_with(decode_ctx, all_symbols, header, bitmap)
  bitmap
}

///|
priv struct Symbols {
  input : Array[Bitmap]
  new : Array[Bitmap]
}

///|
fn Symbols::new(input : Array[Bitmap]) -> Symbols {
  { input, new: [], }
}

///|
fn Symbols::input_count(self : Symbols) -> UInt {
  self.input.length().reinterpret_as_uint()
}

///|
/// (A negative `index` stands for an out-of-range `usize`.)
fn Symbols::get(self : Symbols, index : Int) -> Bitmap? {
  if index < 0 {
    None
  } else if index < self.input.length() {
    Some(self.input[index])
  } else {
    let i = index - self.input.length()
    if i < self.new.length() {
      Some(self.new[i])
    } else {
      None
    }
  }
}

///|
priv struct SymbolDecodeContext {
  header : SymbolDictionaryHeader
  a_ctx : ArithmeticContext
  h_ctx : HuffmanContext
  symbols : Symbols
  standard_tables : StandardHuffmanTables
  symbol_widths : Array[UInt]
  mut height_class_first_symbol : UInt
  mut symbols_decoded_count : UInt
  mut total_width : UInt
  mut height_class_height : UInt
}

///|
fn SymbolDecodeContext::total_symbols(self : SymbolDecodeContext) -> UInt {
  self.symbols.input_count() + self.header.num_new_symbols
}

///|
priv struct ArithmeticContext {
  decoder : ArithmeticDecoder
  /// `IADH`
  height_class_delta_decoder : IntegerDecoder
  /// `IADW`
  symbol_width_delta_decoder : IntegerDecoder
  /// `IAEX`
  export_run_length_decoder : IntegerDecoder
  /// `IAAI`
  aggregation_instance_count_decoder : IntegerDecoder
  generic_region_contexts : FixedArray[Byte]
  refinement_region_contexts : FixedArray[Byte]
  mut text_region_contexts_ : TextRegionContexts?
}

///|
/// `self.text_region_contexts.get_or_insert_with(|| TextRegionContexts::new(code_len))`.
fn ArithmeticContext::text_region_contexts(
  self : ArithmeticContext,
  symbol_code_length : UInt,
) -> TextRegionContexts {
  match self.text_region_contexts_ {
    Some(c) => c
    None => {
      let c = TextRegionContexts::new(symbol_code_length)
      self.text_region_contexts_ = Some(c)
      c
    }
  }
}

///|
fn ArithmeticContext::new(
  data : BytesView,
  header : SymbolDictionaryHeader,
  input_contexts : RetainedContexts?,
) -> ArithmeticContext raise DecodeError {
  let decoder = ArithmeticDecoder::new(data)
  let height_class_delta_decoder = IntegerDecoder::new()
  let symbol_width_delta_decoder = IntegerDecoder::new()
  let export_run_length_decoder = IntegerDecoder::new()
  let aggregation_instance_count_decoder = IntegerDecoder::new()
  let (generic_region_contexts, refinement_region_contexts) = if header.flags.bitmap_context_used {
    let ctx = ok_or(input_contexts, Symbol(Invalid))
    (ctx.generic_region.copy(), ctx.refinement_region.copy())
  } else {
    let template = header.flags.template
    let num_contexts = 1 << template.context_bits()
    let refinement_template = header.flags.refinement_template
    let num_refinement_contexts = 1 << refinement_template.context_bits()
    (new_contexts(num_contexts), new_contexts(num_refinement_contexts))
  }
  {
    decoder,
    height_class_delta_decoder,
    symbol_width_delta_decoder,
    export_run_length_decoder,
    aggregation_instance_count_decoder,
    generic_region_contexts,
    refinement_region_contexts,
    text_region_contexts_: None,
  }
}

///|
priv struct HuffmanContext {
  /// `SDHUFFDH`
  height_class_delta_table : HuffmanTable
  /// `SDHUFFDW`
  symbol_width_delta_table : HuffmanTable
  /// `SDHUFFBMSIZE`
  collective_bitmap_size_table : HuffmanTable
  /// `SDHUFFAGGINST`
  aggregation_instance_count_table : HuffmanTable
  export_run_length_table : HuffmanTable
  reader : Reader
}

///|
fn HuffmanContext::new(
  data : BytesView,
  header : SymbolDictionaryHeader,
  referred_tables : Array[HuffmanTable],
  standard_tables : StandardHuffmanTables,
) -> HuffmanContext raise DecodeError {
  let reader = Reader::new(data)
  let mut custom_count = 0
  for
    x in [
      header.flags.delta_height_table == UserSupplied,
      header.flags.delta_width_table == UserSupplied,
      header.flags.collective_bitmap_size_table == UserSupplied,
      header.flags.aggregate_instance_table == UserSupplied,
    ] {
    if x {
      custom_count += 1
    }
  }
  if referred_tables.length() < custom_count {
    raise Huffman(MissingTables)
  }
  let mut custom_table_idx = 0
  fn get_custom() -> HuffmanTable {
    let table = referred_tables[custom_table_idx]
    custom_table_idx += 1
    table
  }

  // Select Huffman tables based on flags (7.4.2.1.6).
  fn get_table(selection : HuffmanTableSelection) -> HuffmanTable {
    match selection {
      TableB1 => standard_tables.table_a()
      TableB2 => standard_tables.table_b()
      TableB3 => standard_tables.table_c()
      TableB4 => standard_tables.table_d()
      TableB5 => standard_tables.table_e()
      UserSupplied => get_custom()
    }
  }

  let height_class_delta_table = get_table(header.flags.delta_height_table)
  let symbol_width_delta_table = get_table(header.flags.delta_width_table)
  let collective_bitmap_size_table = get_table(
    header.flags.collective_bitmap_size_table,
  )
  let aggregation_instance_count_table = get_table(
    header.flags.aggregate_instance_table,
  )
  let export_run_length_table = get_table(TableB1)
  {
    reader,
    height_class_delta_table,
    symbol_width_delta_table,
    collective_bitmap_size_table,
    aggregation_instance_count_table,
    export_run_length_table,
  }
}

///|
/// Decode a height class collective bitmap (6.5.9).
fn decode_height_class_collective_bitmap(
  ctx : SymbolDecodeContext,
) -> Unit raise DecodeError {
  let bitmap_size = ok_or(
    ctx.h_ctx.collective_bitmap_size_table.decode(ctx.h_ctx.reader),
    Huffman(UnexpectedOob),
  )
  if bitmap_size < 0 {
    raise Overflow(BitmapDimension)
  }
  let bitmap_size = bitmap_size.reinterpret_as_uint()
  ctx.h_ctx.reader.align()
  let collective_bitmap = if bitmap_size == 0 {
    // Bitmap is stored uncompressed, so we basically just copy-paste
    // each byte. Rows are padded to the byte boundary.
    let row_bytes = (ctx.total_width.to_uint64() + 7) / 8
    let bitmap = Bitmap::new(ctx.total_width, ctx.height_class_height)
    for y in 0U..<ctx.height_class_height {
      for byte_x in 0UL..<row_bytes {
        let byte = ok_or(ctx.h_ctx.reader.read_byte(), eof).to_int()
        for bit in 0..<8 {
          let x = byte_x.to_uint() * 8 + bit.reinterpret_as_uint()
          if x < ctx.total_width {
            let pixel = (byte >> (7 - bit)) & 1
            bitmap.set_pixel(x, y, pixel)
          }
        }
      }
    }
    bitmap
  } else {
    // Otherwise, we need to use MMR decoding.
    let bitmap_data = ok_or(
      ctx.h_ctx.reader.read_bytes(bitmap_size.to_int64()),
      eof,
    )
    let bitmap = Bitmap::new(ctx.total_width, ctx.height_class_height)
    let _ = decode_bitmap_mmr(bitmap, bitmap_data)
    bitmap
  }

  // Finally, we simply chop up the collective bitmap into its constituent
  // symbols.
  let mut x_offset : UInt = 0
  for symbol_idx in ctx.height_class_first_symbol..<ctx.symbols_decoded_count {
    let symbol_width = ctx.symbol_widths[symbol_idx.reinterpret_as_int()]
    let symbol = Bitmap::new(symbol_width, ctx.height_class_height)
    for y in 0U..<ctx.height_class_height {
      let src_bit_offset = x_offset % WORD_BITS
      let src_word_start = x_offset / WORD_BITS
      let dest_row = (y * symbol.stride).reinterpret_as_int()
      for w in 0U..<symbol.stride {
        let sw = src_word_start + w
        let src1 = collective_bitmap.get_word(y, sw)
        let word = if src_bit_offset == 0 {
          src1
        } else {
          let src2 = collective_bitmap.get_word(y, sw + 1)
          (src1 << src_bit_offset.reinterpret_as_int()) |
          (src2 >> (WORD_BITS - src_bit_offset).reinterpret_as_int())
        }
        symbol.data[dest_row + w.reinterpret_as_int()] = word
      }

      // Clear trailing bits in the last word beyond `symbol_width`.
      let trailing = symbol_width % WORD_BITS
      if trailing != 0 && symbol.stride > 0 {
        let last = dest_row + (symbol.stride - 1).reinterpret_as_int()
        symbol.data[last] = symbol.data[last] &
          (0xFFFFFFFFU << (WORD_BITS - trailing).reinterpret_as_int())
      }
    }
    ctx.symbols.new.push(symbol)
    x_offset = ok_or(checked_add_u32(x_offset, symbol_width), Overflow(Index))
  }
}

///|
/// Exported symbols (6.5.10).
fn export_symbols(ctx : SymbolDecodeContext) -> Array[Bitmap] raise DecodeError {
  let total_symbols = ctx.total_symbols()
  fn read_run_length() -> UInt raise DecodeError {
    let value = ok_or(
      if ctx.header.flags.use_huffman {
        ctx.h_ctx.export_run_length_table.decode(ctx.h_ctx.reader)
      } else {
        ctx.a_ctx.export_run_length_decoder.decode(ctx.a_ctx.decoder)
      },
      Huffman(UnexpectedOob),
    )
    if value < 0 {
      raise Huffman(InvalidCode)
    }
    value.reinterpret_as_uint()
  }

  let exported = []
  let mut index : UInt = 0
  let mut should_export = false
  while index < total_symbols {
    let run_length = read_run_length()
    let end_index = ok_or(checked_add_u32(index, run_length), Overflow(Index))
    if end_index > total_symbols {
      raise Symbol(OutOfRange)
    }
    if should_export {
      for symbol_idx in index..<end_index {
        let symbol = ok_or(
          ctx.symbols.get(symbol_idx.reinterpret_as_int()),
          Symbol(OutOfRange),
        )
        exported.push(symbol)
      }
    }
    index = end_index
    should_export = !should_export
  }
  if exported.length().reinterpret_as_uint() != ctx.header.num_exported_symbols {
    raise Symbol(NoSymbols)
  }
  exported
}

///|
priv enum HuffmanTableSelection {
  TableB1
  TableB2
  TableB3
  TableB4
  TableB5
  UserSupplied
} derive(Eq)

///|
/// Parsed symbol dictionary segment flags (7.4.2.1.1).
priv struct SymbolDictionaryFlags {
  use_huffman : Bool
  use_refagg : Bool
  delta_height_table : HuffmanTableSelection
  delta_width_table : HuffmanTableSelection
  collective_bitmap_size_table : HuffmanTableSelection
  aggregate_instance_table : HuffmanTableSelection
  bitmap_context_used : Bool
  bitmap_context_retained : Bool
  template : Template
  refinement_template : RefinementTemplate
}

///|
/// Parsed symbol dictionary segment header (7.4.2.1).
priv struct SymbolDictionaryHeader {
  flags : SymbolDictionaryFlags
  adaptive_template_pixels : FixedArray[AdaptiveTemplatePixel]
  refinement_at_pixels : Array[AdaptiveTemplatePixel]
  num_exported_symbols : UInt
  num_new_symbols : UInt
  data : BytesView
}

///|
/// Parse a symbol dictionary segment header (7.4.2.1).
fn symbol_parse(reader : Reader) -> SymbolDictionaryHeader raise DecodeError {
  let flags_word = ok_or(reader.read_u16(), eof).reinterpret_as_int()
  let use_huffman = (flags_word & 0x0001) != 0
  let use_refagg = (flags_word & 0x0002) != 0
  let delta_height_table = match (flags_word >> 2) & 0x03 {
    0 => TableB4
    1 => TableB5
    3 => UserSupplied
    _ => raise Huffman(InvalidSelection)
  }
  let delta_width_table = match (flags_word >> 4) & 0x03 {
    0 => TableB2
    1 => TableB3
    3 => UserSupplied
    _ => raise Huffman(InvalidSelection)
  }
  let collective_bitmap_size_table = if (flags_word & 0x0040) != 0 {
    UserSupplied
  } else {
    TableB1
  }
  let aggregate_instance_table = if (flags_word & 0x0080) != 0 {
    UserSupplied
  } else {
    TableB1
  }
  let bitmap_context_used = (flags_word & 0x0100) != 0
  let bitmap_context_retained = (flags_word & 0x0200) != 0
  let template = Template::from_byte((flags_word >> 10) & 0xFF)
  let refinement_template = RefinementTemplate::from_byte(
    (flags_word >> 12) & 0xFF,
  )
  let flags : SymbolDictionaryFlags = {
    use_huffman,
    use_refagg,
    delta_height_table,
    delta_width_table,
    collective_bitmap_size_table,
    aggregate_instance_table,
    bitmap_context_used,
    bitmap_context_retained,
    template,
    refinement_template,
  }
  let at_pixels = if !use_huffman {
    parse_adaptive_template_pixels(reader, template, false)
  } else {
    // Unused.
    FixedArray::make(4, AdaptiveTemplatePixel::default())
  }
  let refinement_at_pixels = if use_refagg && refinement_template == RTemplate0 {
    parse_refinement_at_pixels(reader)
  } else {
    []
  }
  let num_exported_symbols = ok_or(reader.read_u32(), eof)
  let num_new_symbols = ok_or(reader.read_u32(), eof)
  let sum = num_exported_symbols.to_uint64() + num_new_symbols.to_uint64()
  // (`saturating_add`)
  if sum > MAX_SYMBOLS.to_uint64() {
    raise Overflow(SymbolCount)
  }
  let data = ok_or(reader.tail(), eof)
  {
    flags,
    adaptive_template_pixels: at_pixels,
    refinement_at_pixels,
    num_exported_symbols,
    num_new_symbols,
    data,
  }
}
