// A [Compact Font Format 2 Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/cff2) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/cff/cff2.rs`.

// https://docs.microsoft.com/en-us/typography/opentype/spec/cff2charstr

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/cff2#7-top-dict-data
// 'Operators in DICT may be preceded by up to a maximum of 513 operands.'
let cff2_max_operands_len : Int = 513

///|
// https://docs.microsoft.com/en-us/typography/opentype/spec/cff2charstr#appendix-b-cff2-charstring-implementation-limits
let cff2_stack_limit : Int = 10

///|
let cff2_max_arguments_stack_len : Int = 513

///|
priv struct TopDictData {
  mut char_strings_offset : Int
  mut font_dict_index_offset : Int?
  mut variation_store_offset : Int?
}

///|
fn cff2_parse_top_dict(data : BytesView) -> TopDictData raise Malformed {
  let dict_data : TopDictData = {
    char_strings_offset: 0,
    font_dict_index_offset: None,
    variation_store_offset: None,
  }
  let dict_parser = DictionaryParser::new(data, cff2_max_operands_len)
  while dict_parser.parse_next() is Some(operator) {
    if operator == 17 {
      // CHAR_STRINGS_OFFSET
      dict_data.char_strings_offset = req(dict_parser.parse_offset())
    } else if operator == 1236 {
      // FONT_DICT_INDEX_OFFSET
      dict_data.font_dict_index_offset = dict_parser.parse_offset()
    } else if operator == 24 {
      // VARIATION_STORE_OFFSET
      dict_data.variation_store_offset = dict_parser.parse_offset()
    }
  }

  // Must be set, otherwise there are nothing to parse.
  if dict_data.char_strings_offset == 0 {
    raise Malformed
  }
  dict_data
}

///|
fn cff2_parse_font_dict(data : BytesView) -> (Int, Int)? {
  let mut private_dict_range = None
  let dict_parser = DictionaryParser::new(data, cff2_max_operands_len)
  while dict_parser.parse_next() is Some(operator) {
    if operator == 18 {
      // PRIVATE_DICT_SIZE_AND_OFFSET
      dict_parser.parse_operands() catch {
        _ => return None
      }
      let operands = dict_parser.operands()
      if operands.length() == 2 {
        let len = f64_as_i32(operands[0])
        let start = f64_as_i32(operands[1])
        if len < 0 || start < 0 {
          return None
        }
        guard usize_checked_add(start, len) is Some(end) else { return None }
        private_dict_range = Some((start, end))
      }
      break
    }
  }
  private_dict_range
}

///|
fn cff2_parse_private_dict(data : BytesView) -> Int? {
  let mut subroutines_offset = None
  let dict_parser = DictionaryParser::new(data, cff2_max_operands_len)
  while dict_parser.parse_next() is Some(operator) {
    if operator == 19 {
      // LOCAL_SUBROUTINES_OFFSET
      dict_parser.parse_operands() catch {
        _ => return None
      }
      let operands = dict_parser.operands()
      if operands.length() == 1 {
        let n = f64_as_i32(operands[0])
        subroutines_offset = if n >= 0 { Some(n) } else { None }
      }
      break
    }
  }
  subroutines_offset
}

///|
/// CFF2 allows up to 65535 scalars, but an average font will have 3-5.
/// So 64 is more than enough.
let scalars_max : Int = 64

///|
priv struct Scalars {
  d : FixedArray[Float] // 256B
  mut len : Int
}

///|
fn Scalars::new() -> Scalars {
  { d: FixedArray::make(scalars_max, 0.0), len: 0, }
}

///|
fn Scalars::len(self : Scalars) -> Int {
  self.len
}

///|
fn Scalars::clear(self : Scalars) -> Unit {
  self.len = 0
}

///|
fn Scalars::at(self : Scalars, i : Int) -> Float {
  if i < self.len {
    self.d[i]
  } else {
    0.0
  }
}

///|
fn Scalars::push(self : Scalars, n : Float) -> Bool {
  if self.len < scalars_max {
    self.d[self.len] = n
    self.len += 1
    true
  } else {
    false
  }
}

///|
priv struct Cff2Context {
  metadata : Cff2Table
  coordinates : ArrayView[NormalizedCoordinate]
  scalars : Scalars
  mut had_vsindex : Bool
  mut had_blend : Bool
  mut stems_len : UInt
}

///|
fn Cff2Context::update_scalars(
  self : Cff2Context,
  index : UInt16,
) -> Unit raise CFFError {
  self.scalars.clear()
  guard self.metadata.item_variation_store.region_indices(index)
    is Some(indices) else {
    raise InvalidItemVariationDataIndex
  }
  for index in indices.iter() {
    let scalar = self.metadata.item_variation_store.regions.evaluate_region(
      index,
      self.coordinates,
    )
    if !self.scalars.push(scalar) {
      raise BlendRegionsLimitReached
    }
  }
}

///|
fn cff2_parse_char_string(
  data : BytesView,
  metadata : Cff2Table,
  coordinates : ArrayView[NormalizedCoordinate],
  builder : &OutlineBuilder,
) -> Rect raise CFFError {
  let ctx : Cff2Context = {
    metadata,
    coordinates,
    scalars: Scalars::new(),
    had_vsindex: false,
    had_blend: false,
    stems_len: 0,
  }

  // Load scalars at default index.
  ctx.update_scalars(0)
  let inner_builder : CffBuilder = { builder, bbox: RectF::new(), }
  let stack = ArgumentsStack::new(cff2_max_arguments_stack_len)
  let parser : CharStringParser = {
    stack,
    builder: inner_builder,
    x: 0.0,
    y: 0.0,
    has_move_to: false,
    is_first_move_to: true,
    width_only: false,
  }
  cff2_parse_char_string_impl(ctx, data, 0, parser)
  let bbox = parser.builder.bbox

  // Check that bbox was changed.
  if bbox.is_default() {
    raise ZeroBBox
  }
  guard bbox.to_rect() is Some(rect) else { raise BboxOverflow }
  rect
}

///|
fn cff2_parse_char_string_impl(
  ctx : Cff2Context,
  char_string : BytesView,
  depth : Int,
  p : CharStringParser,
) -> Unit raise CFFError {
  let s = Stream::new(char_string)
  while !s.at_end() {
    let op = s.read_u8() catch { _ => raise ReadOutOfBounds }
    match op.to_int() {
      0 | 2 | 9 | 11 | 13 | 14 | 17 =>
        // Reserved.
        raise InvalidOperator
      1 | 3 | 18 | 23 => {
        // HORIZONTAL_STEM | VERTICAL_STEM | HORIZONTAL_STEM_HINT_MASK | VERTICAL_STEM_HINT_MASK
        // y dy {dya dyb}* hstem
        // x dx {dxa dxb}* vstem
        // y dy {dya dyb}* hstemhm
        // x dx {dxa dxb}* vstemhm
        ctx.stems_len += p.stack.len().reinterpret_as_uint() >> 1

        // We are ignoring the hint operators.
        p.stack.clear()
      }
      4 => p.parse_vertical_move_to(0)
      5 => p.parse_line_to()
      6 => p.parse_horizontal_line_to()
      7 => p.parse_vertical_line_to()
      8 => p.parse_curve_to()
      10 => {
        // CALL_LOCAL_SUBROUTINE
        if p.stack.is_empty() {
          raise InvalidArgumentsStackLength
        }
        if depth == cff2_stack_limit {
          raise NestingLimitReached
        }
        let subroutine_bias = calc_subroutine_bias(
          ctx.metadata.local_subrs.len(),
        )
        let index = conv_subroutine_index(p.stack.pop(), subroutine_bias)
        guard ctx.metadata.local_subrs.get(index) is Some(char_string) else {
          raise InvalidSubroutineIndex
        }
        cff2_parse_char_string_impl(ctx, char_string, depth + 1, p)
      }
      12 => {
        // TWO_BYTE_OPERATOR_MARK
        // flex
        let op2 = s.read_u8() catch { _ => raise ReadOutOfBounds }
        match op2.to_int() {
          34 => p.parse_hflex()
          35 => p.parse_flex()
          36 => p.parse_hflex1()
          37 => p.parse_flex1()
          _ => raise UnsupportedOperator
        }
      }
      15 => {
        // VS_INDEX
        // |- ivs vsindex (15) |-

        // `vsindex` must precede the first `blend` operator, and may occur only once.
        if ctx.had_blend || ctx.had_vsindex {
          // TODO: maybe add a custom error
          raise InvalidOperator
        }
        if p.stack.len() != 1 {
          raise InvalidArgumentsStackLength
        }
        guard try_u16_from_f32(p.stack.pop()) is Some(index) else {
          raise InvalidItemVariationDataIndex
        }
        ctx.update_scalars(index)
        ctx.had_vsindex = true
        p.stack.clear()
      }
      16 => {
        // BLEND
        // num(0)..num(n-1), delta(0,0)..delta(k-1,0),
        // delta(0,1)..delta(k-1,1) .. delta(0,n-1)..delta(k-1,n-1)
        // n blend (16) val(0)..val(n-1)
        ctx.had_blend = true
        guard try_u16_from_f32(p.stack.pop()) is Some(n) else {
          raise InvalidNumberOfBlendOperands
        }
        let n = n.to_int()
        let k = ctx.scalars.len()
        let len = n * (k + 1)
        if p.stack.len() < len {
          raise InvalidArgumentsStackLength
        }
        let start = p.stack.len() - len
        for i = n - 1; i >= 0; i = i - 1 {
          for j in 0..<k {
            let delta = p.stack.pop()
            p.stack.data[start + i] = p.stack.data[start + i] +
              delta * ctx.scalars.at(k - j - 1)
          }
        }
      }
      19 | 20 => {
        // HINT_MASK | COUNTER_MASK
        ctx.stems_len += p.stack.len().reinterpret_as_uint() >> 1
        s.advance(u32_to_usize((ctx.stems_len + 7) >> 3))

        // We are ignoring the hint operators.
        p.stack.clear()
      }
      21 => p.parse_move_to(0)
      22 => p.parse_horizontal_move_to(0)
      24 => p.parse_curve_line()
      25 => p.parse_line_curve()
      26 => p.parse_vv_curve_to()
      27 => p.parse_hh_curve_to()
      28 => {
        // SHORT_INT
        let n = s.read_i16() catch { _ => raise ReadOutOfBounds }
        p.stack.push(Float::from_int(n.to_int()))
      }
      29 => {
        // CALL_GLOBAL_SUBROUTINE
        if p.stack.is_empty() {
          raise InvalidArgumentsStackLength
        }
        if depth == cff2_stack_limit {
          raise NestingLimitReached
        }
        let subroutine_bias = calc_subroutine_bias(
          ctx.metadata.global_subrs.len(),
        )
        let index = conv_subroutine_index(p.stack.pop(), subroutine_bias)
        guard ctx.metadata.global_subrs.get(index) is Some(char_string) else {
          raise InvalidSubroutineIndex
        }
        cff2_parse_char_string_impl(ctx, char_string, depth + 1, p)
      }
      30 => p.parse_vh_curve_to()
      31 => p.parse_hv_curve_to()
      32..<=246 => p.parse_int1(op)
      247..<=250 => p.parse_int2(op, s)
      251..<=254 => p.parse_int3(op, s)
      _ => // FIXED_16_16
        p.parse_fixed(s)
    }
  }
}

///|
/// A [Compact Font Format 2 Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cff2).
struct Cff2Table {
  mut global_subrs : CffIndex
  mut local_subrs : CffIndex
  mut char_strings : CffIndex
  mut item_variation_store : ItemVariationStore
}

///|
/// Parses a table from raw data.
pub fn Cff2Table::parse(data : BytesView) -> Cff2Table? {
  try {
    let s = Stream::new(data)

    // Parse Header.
    let major = s.read_u8()
    s.advance(1) // minor
    let header_size = s.read_u8()
    let top_dict_length = s.read_u16()
    if major != 2 {
      return None
    }

    // Jump to Top DICT. It's not necessarily right after the header.
    if header_size > 5 {
      s.advance(header_size.to_int() - 5)
    }
    let top_dict_data = s.read_bytes(top_dict_length.to_int())
    let top_dict = cff2_parse_top_dict(top_dict_data)
    let metadata : Cff2Table = {
      global_subrs: CffIndex::default(),
      local_subrs: CffIndex::default(),
      char_strings: CffIndex::default(),
      item_variation_store: ItemVariationStore::default(),
    }

    // Parse Global Subroutines INDEX.
    metadata.global_subrs = parse_index_u32(s)
    metadata.char_strings = {
      let s = Stream::new_at_r(data, top_dict.char_strings_offset)
      parse_index_u32(s)
    }
    if top_dict.variation_store_offset is Some(offset) {
      let s = Stream::new_at_r(data, offset)
      s.advance(2) // length
      metadata.item_variation_store = req(ItemVariationStore::parse(s))
    }

    // TODO: simplify
    if top_dict.font_dict_index_offset is Some(offset) {
      let s = Stream::new_at_r(data, offset)
      for font_dict_data in parse_index_u32(s).iter() {
        if cff2_parse_font_dict(font_dict_data) is Some(private_dict_range) {
          // 'Private DICT size and offset, from start of the CFF2 table.'
          let private_dict_data = slice_r(
            data,
            private_dict_range.0,
            private_dict_range.1,
          )
          if cff2_parse_private_dict(private_dict_data)
            is Some(subroutines_offset) {
            // 'The local subroutines offset is relative to the beginning
            // of the Private DICT data.'
            if usize_checked_add(private_dict_range.0, subroutines_offset)
              is Some(start) {
              let data = slice_r(data, start, data.length())
              let s = Stream::new(data)
              metadata.local_subrs = parse_index_u32(s)
              break
            }
          }
        }
      }
    }
    Some(metadata)
  } catch {
    _ => None
  }
}

///|
/// Outlines a glyph.
pub fn Cff2Table::outline(
  self : Cff2Table,
  coordinates : ArrayView[NormalizedCoordinate],
  glyph_id : GlyphId,
  builder : &OutlineBuilder,
) -> Result[Rect, CFFError] {
  guard self.char_strings.get(glyph_id.0.to_uint()) is Some(data) else {
    return Err(NoGlyph)
  }
  Ok(cff2_parse_char_string(data, self, coordinates, builder)) catch {
    e => Err(e)
  }
}
