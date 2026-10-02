// A [Compact Font Format Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/cff) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/cff/cff1.rs`.

// Useful links:
// http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/font/pdfs/5176.CFF.pdf
// http://wwwimages.adobe.com/content/dam/Adobe/en/devnet/font/pdfs/5177.Type2.pdf
// https://github.com/opentypejs/opentype.js/blob/master/src/tables/cff.js

///|
// Limits according to the Adobe Technical Note #5176, chapter 4 DICT Data.
let cff1_max_operands_len : Int = 48

///|
// Limits according to the Adobe Technical Note #5177 Appendix B.
let cff1_stack_limit : Int = 10

///|
let cff1_max_arguments_stack_len : Int = 48

///|
priv enum FontKind {
  SID(SIDMetadata)
  CID(CIDMetadata)
}

///|
priv struct SIDMetadata {
  mut local_subrs : CffIndex
  /// Can be zero.
  mut default_width : Float
  /// Can be zero.
  mut nominal_width : Float
  encoding : Encoding
}

///|
priv struct CIDMetadata {
  fd_array : CffIndex
  fd_select : FDSelect
}

///|
/// An affine transformation matrix.
pub(all) struct Matrix {
  sx : Float
  ky : Float
  kx : Float
  sy : Float
  tx : Float
  ty : Float
} derive(Eq, Debug)

///|
pub impl Default for Matrix with fn default() {
  { sx: 0.001, ky: 0.0, kx: 0.0, sy: 0.001, tx: 0.0, ty: 0.0, }
}

///|
priv struct TopDict {
  mut charset_offset : Int?
  mut encoding_offset : Int?
  mut char_strings_offset : Int
  mut private_dict_range : (Int, Int)?
  mut matrix : Matrix
  mut has_ros : Bool
  mut fd_array_offset : Int?
  mut fd_select_offset : Int?
}

///|
fn parse_top_dict(s : Stream) -> TopDict raise Malformed {
  let top_dict : TopDict = {
    charset_offset: None,
    encoding_offset: None,
    char_strings_offset: 0,
    private_dict_range: None,
    matrix: Matrix::default(),
    has_ros: false,
    fd_array_offset: None,
    fd_select_offset: None,
  }
  let index = parse_index_u16(s)

  // The Top DICT INDEX should have only one dictionary.
  let data = req(index.get(0))
  let dict_parser = DictionaryParser::new(data, cff1_max_operands_len)
  while dict_parser.parse_next() is Some(operator) {
    match operator {
      15 => // CHARSET_OFFSET
        top_dict.charset_offset = dict_parser.parse_offset()
      16 => // ENCODING_OFFSET
        top_dict.encoding_offset = dict_parser.parse_offset()
      17 => // CHAR_STRINGS_OFFSET
        top_dict.char_strings_offset = req(dict_parser.parse_offset())
      18 => // PRIVATE_DICT_SIZE_AND_OFFSET
        top_dict.private_dict_range = dict_parser.parse_range()
      1207 => {
        // FONT_MATRIX
        dict_parser.parse_operands()
        let operands = dict_parser.operands()
        if operands.length() == 6 {
          top_dict.matrix = {
            sx: Float::from_double(operands[0]),
            ky: Float::from_double(operands[1]),
            kx: Float::from_double(operands[2]),
            sy: Float::from_double(operands[3]),
            tx: Float::from_double(operands[4]),
            ty: Float::from_double(operands[5]),
          }
        }
      }
      1230 => // ROS
        top_dict.has_ros = true
      1236 => // FD_ARRAY
        top_dict.fd_array_offset = dict_parser.parse_offset()
      1237 => // FD_SELECT
        top_dict.fd_select_offset = dict_parser.parse_offset()
      _ => ()
    }
  }
  top_dict
}

///|
priv struct PrivateDict {
  mut local_subroutines_offset : Int?
  mut default_width : Float?
  mut nominal_width : Float?
}

///|
fn parse_private_dict(data : BytesView) -> PrivateDict {
  let dict : PrivateDict = {
    local_subroutines_offset: None,
    default_width: None,
    nominal_width: None,
  }
  let dict_parser = DictionaryParser::new(data, cff1_max_operands_len)
  while dict_parser.parse_next() is Some(operator) {
    if operator == 19 {
      // LOCAL_SUBROUTINES_OFFSET
      dict.local_subroutines_offset = dict_parser.parse_offset()
    } else if operator == 20 {
      // DEFAULT_WIDTH
      dict.default_width = dict_parser.parse_number().map(Float::from_double)
    } else if operator == 21 {
      // NOMINAL_WIDTH
      dict.nominal_width = dict_parser.parse_number().map(Float::from_double)
    }
  }
  dict
}

///|
fn parse_font_dict(data : BytesView) -> (Int, Int)? {
  let dict_parser = DictionaryParser::new(data, cff1_max_operands_len)
  while dict_parser.parse_next() is Some(operator) {
    if operator == 18 {
      // PRIVATE_DICT_SIZE_AND_OFFSET
      return dict_parser.parse_range()
    }
  }
  None
}

///|
/// In CID fonts, to get local subroutines we have to:
///   1. Find Font DICT index via FDSelect by GID.
///   2. Get Font DICT data from FDArray using this index.
///   3. Get a Private DICT offset from a Font DICT.
///   4. Get a local subroutine offset from Private DICT.
///   5. Parse a local subroutine at offset.
fn parse_cid_local_subrs(
  data : BytesView,
  glyph_id : GlyphId,
  cid : CIDMetadata,
) -> CffIndex? {
  try {
    let font_dict_index = req(cid.fd_select.font_dict_index(glyph_id))
    let font_dict_data = req(cid.fd_array.get(font_dict_index.to_uint()))
    let private_dict_range = req(parse_font_dict(font_dict_data))
    let private_dict_data = slice_r(
      data,
      private_dict_range.0,
      private_dict_range.1,
    )
    let private_dict = parse_private_dict(private_dict_data)
    let subroutines_offset = req(private_dict.local_subroutines_offset)

    // 'The local subroutines offset is relative to the beginning
    // of the Private DICT data.'
    let start = req(usize_checked_add(private_dict_range.0, subroutines_offset))
    let subrs_data = slice_from_r(data, start)
    let s = Stream::new(subrs_data)
    Some(parse_index_u16(s))
  } catch {
    _ => None
  }
}

///|
priv struct Cff1Context {
  metadata : CffTable
  mut width : Float?
  mut stems_len : UInt
  mut has_endchar : Bool
  mut has_seac : Bool
  glyph_id : GlyphId // Required to parse local subroutine in CID fonts.
  mut local_subrs : CffIndex?
}

///|
fn cff1_parse_char_string(
  data : BytesView,
  metadata : CffTable,
  glyph_id : GlyphId,
  width_only : Bool,
  builder : &OutlineBuilder,
) -> (Rect, Float?) raise CFFError {
  let local_subrs = match metadata.kind {
    SID(sid) => Some(sid.local_subrs)
    CID(_) => None // Will be resolved on request.
  }
  let ctx : Cff1Context = {
    metadata,
    width: None,
    stems_len: 0,
    has_endchar: false,
    has_seac: false,
    glyph_id,
    local_subrs,
  }
  let inner_builder : CffBuilder = { builder, bbox: RectF::new(), }
  let stack = ArgumentsStack::new(cff1_max_arguments_stack_len)
  let parser : CharStringParser = {
    stack,
    builder: inner_builder,
    x: 0.0,
    y: 0.0,
    has_move_to: false,
    is_first_move_to: true,
    width_only,
  }
  cff1_parse_char_string_impl(ctx, data, 0, parser)
  if width_only {
    return (Rect::zero(), ctx.width)
  }
  if !ctx.has_endchar {
    raise MissingEndChar
  }
  let bbox = parser.builder.bbox

  // Check that bbox was changed.
  if bbox.is_default() {
    raise ZeroBBox
  }
  guard bbox.to_rect() is Some(rect) else { raise BboxOverflow }
  (rect, ctx.width)
}

///|
fn cff1_parse_char_string_impl(
  ctx : Cff1Context,
  char_string : BytesView,
  depth : Int,
  p : CharStringParser,
) -> Unit raise CFFError {
  let s = Stream::new(char_string)
  while !s.at_end() {
    let op = s.read_u8() catch { _ => raise ReadOutOfBounds }
    match op.to_int() {
      0 | 2 | 9 | 13 | 15 | 16 | 17 =>
        // Reserved.
        raise InvalidOperator
      1 | 3 | 18 | 23 => {
        // HORIZONTAL_STEM | VERTICAL_STEM | HORIZONTAL_STEM_HINT_MASK | VERTICAL_STEM_HINT_MASK
        // y dy {dya dyb}* hstem
        // x dx {dxa dxb}* vstem
        // y dy {dya dyb}* hstemhm
        // x dx {dxa dxb}* vstemhm

        // If the stack length is uneven, than the first value is a `width`.
        let len = if (p.stack.len() & 1) != 0 && ctx.width is None {
          ctx.width = Some(p.stack.at(0))
          p.stack.len() - 1
        } else {
          p.stack.len()
        }
        ctx.stems_len += len.reinterpret_as_uint() >> 1

        // We are ignoring the hint operators.
        p.stack.clear()
      }
      4 => {
        // VERTICAL_MOVE_TO
        let mut i = 0
        if p.stack.len() == 2 {
          i += 1
          if ctx.width is None {
            ctx.width = Some(p.stack.at(0))
          }
        }
        p.parse_vertical_move_to(i)
      }
      5 => p.parse_line_to()
      6 => p.parse_horizontal_line_to()
      7 => p.parse_vertical_line_to()
      8 => p.parse_curve_to()
      10 => {
        // CALL_LOCAL_SUBROUTINE
        if p.stack.is_empty() {
          raise InvalidArgumentsStackLength
        }
        if depth == cff1_stack_limit {
          raise NestingLimitReached
        }

        // Parse and remember the local subroutine for the current glyph.
        // Since it's a pretty complex task, we're doing it only when
        // a local subroutine is actually requested by the glyphs charstring.
        if ctx.local_subrs is None {
          if ctx.metadata.kind is CID(cid) {
            ctx.local_subrs = parse_cid_local_subrs(
              ctx.metadata.table_data,
              ctx.glyph_id,
              cid,
            )
          }
        }
        if ctx.local_subrs is Some(local_subrs) {
          let subroutine_bias = calc_subroutine_bias(local_subrs.len())
          let index = conv_subroutine_index(p.stack.pop(), subroutine_bias)
          guard local_subrs.get(index) is Some(char_string) else {
            raise InvalidSubroutineIndex
          }
          cff1_parse_char_string_impl(ctx, char_string, depth + 1, p)
        } else {
          raise NoLocalSubroutines
        }
        if ctx.has_endchar && !ctx.has_seac {
          if !s.at_end() {
            raise DataAfterEndChar
          }
          break
        }
      }
      11 => // RETURN
        break
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
      14 => {
        // ENDCHAR
        if p.stack.len() == 4 || (ctx.width is None && p.stack.len() == 5) {
          // Process 'seac'.
          guard seac_code_to_glyph_id(ctx.metadata.charset, p.stack.pop())
            is Some(accent_char) else {
            raise InvalidSeacCode
          }
          guard seac_code_to_glyph_id(ctx.metadata.charset, p.stack.pop())
            is Some(base_char) else {
            raise InvalidSeacCode
          }
          let dy = p.stack.pop()
          let dx = p.stack.pop()
          if ctx.width is None && !p.stack.is_empty() {
            ctx.width = Some(p.stack.pop())
          }
          ctx.has_seac = true
          if depth == cff1_stack_limit {
            raise NestingLimitReached
          }
          guard ctx.metadata.char_strings.get(base_char.0.to_uint())
            is Some(base_char_string) else {
            raise InvalidSeacCode
          }
          cff1_parse_char_string_impl(ctx, base_char_string, depth + 1, p)
          p.x = dx
          p.y = dy
          guard ctx.metadata.char_strings.get(accent_char.0.to_uint())
            is Some(accent_char_string) else {
            raise InvalidSeacCode
          }
          cff1_parse_char_string_impl(ctx, accent_char_string, depth + 1, p)
        } else if p.stack.len() == 1 && ctx.width is None {
          ctx.width = Some(p.stack.pop())
        }
        if !p.is_first_move_to {
          p.is_first_move_to = true
          p.builder.close()
        }
        if !s.at_end() {
          raise DataAfterEndChar
        }
        ctx.has_endchar = true
        break
      }
      19 | 20 => {
        // HINT_MASK | COUNTER_MASK
        let mut len = p.stack.len()

        // We are ignoring the hint operators.
        p.stack.clear()

        // If the stack length is uneven, than the first value is a `width`.
        if (len & 1) != 0 {
          len -= 1
          if ctx.width is None {
            ctx.width = Some(p.stack.at(0))
          }
        }
        ctx.stems_len += len.reinterpret_as_uint() >> 1
        s.advance(u32_to_usize((ctx.stems_len + 7) >> 3))
      }
      21 => {
        // MOVE_TO
        let mut i = 0
        if p.stack.len() == 3 {
          i += 1
          if ctx.width is None {
            ctx.width = Some(p.stack.at(0))
          }
        }
        p.parse_move_to(i)
      }
      22 => {
        // HORIZONTAL_MOVE_TO
        let mut i = 0
        if p.stack.len() == 2 {
          i += 1
          if ctx.width is None {
            ctx.width = Some(p.stack.at(0))
          }
        }
        p.parse_horizontal_move_to(i)
      }
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
        if depth == cff1_stack_limit {
          raise NestingLimitReached
        }
        let subroutine_bias = calc_subroutine_bias(
          ctx.metadata.global_subrs.len(),
        )
        let index = conv_subroutine_index(p.stack.pop(), subroutine_bias)
        guard ctx.metadata.global_subrs.get(index) is Some(char_string) else {
          raise InvalidSubroutineIndex
        }
        cff1_parse_char_string_impl(ctx, char_string, depth + 1, p)
        if ctx.has_endchar && !ctx.has_seac {
          if !s.at_end() {
            raise DataAfterEndChar
          }
          break
        }
      }
      30 => p.parse_vh_curve_to()
      31 => p.parse_hv_curve_to()
      32..=246 => p.parse_int1(op)
      247..=250 => p.parse_int2(op, s)
      251..=254 => p.parse_int3(op, s)
      _ => // FIXED_16_16
        p.parse_fixed(s)
    }
    if p.width_only && ctx.width is Some(_) {
      break
    }
  }
  // TODO: 'A charstring subroutine must end with either an endchar or a return operator.'
}

///|
fn seac_code_to_glyph_id(charset : Charset, n : Float) -> GlyphId? {
  guard try_u8_from_f32(n) is Some(code) else { return None }
  let sid = cff_standard_encoding[code.to_int()]
  let sid = StringId(u16_from_u8(sid))
  match charset {
    ISOAdobe =>
      // ISO Adobe charset only defines string ids up to 228 (zcaron)
      if code <= 228 {
        Some(GlyphId(sid.0))
      } else {
        None
      }
    Expert | ExpertSubset => None
    _ => charset.sid_to_gid(sid)
  }
}

///|
priv enum FDSelect {
  Format0(LazyArray16[Byte])
  Format3(BytesView) // It's easier to parse it in-place.
}

///|
fn FDSelect::font_dict_index(self : FDSelect, glyph_id : GlyphId) -> Byte? {
  match self {
    Format0(array) => array.get(glyph_id.0)
    Format3(data) =>
      try {
        let s = Stream::new(data)
        let number_of_ranges = s.read_u16()
        if number_of_ranges == 0 {
          return None
        }

        // 'A sentinel GID follows the last range element and serves
        // to delimit the last range in the array.'
        // So we can simply increase the number of ranges by one.
        let number_of_ranges = req(u16_checked_add(number_of_ranges, 1))

        // Range is: GlyphId + u8
        let mut prev_first_glyph : GlyphId = s.read()
        let mut prev_index = s.read_u8()
        for _ in 1..<number_of_ranges.to_int() {
          let curr_first_glyph : GlyphId = s.read()
          if glyph_id >= prev_first_glyph && glyph_id < curr_first_glyph {
            return Some(prev_index)
          } else {
            prev_index = s.read_u8()
          }
          prev_first_glyph = curr_first_glyph
        }
        None
      } catch {
        _ => None
      }
  }
}

///|
fn parse_fd_select(
  number_of_glyphs : UInt16,
  s : Stream,
) -> FDSelect raise Malformed {
  let format = s.read_u8()
  match format {
    0 => Format0(s.read_array16(number_of_glyphs))
    3 => Format3(s.tail_r())
    _ => raise Malformed
  }
}

///|
fn parse_sid_metadata(
  data : BytesView,
  top_dict : TopDict,
  encoding : Encoding,
) -> FontKind raise Malformed {
  let metadata : SIDMetadata = {
    local_subrs: CffIndex::default(),
    default_width: 0.0,
    nominal_width: 0.0,
    encoding,
  }
  let private_dict = match top_dict.private_dict_range {
    Some((start, end)) => parse_private_dict(slice_r(data, start, end))
    None => return SID(metadata)
  }
  metadata.default_width = private_dict.default_width.unwrap_or(0.0)
  metadata.nominal_width = private_dict.nominal_width.unwrap_or(0.0)
  if (top_dict.private_dict_range, private_dict.local_subroutines_offset)
    is (Some(private_dict_range), Some(subroutines_offset)) {
    // 'The local subroutines offset is relative to the beginning
    // of the Private DICT data.'
    if usize_checked_add(private_dict_range.0, subroutines_offset)
      is Some(start) {
      let data = slice_r(data, start, data.length())
      let s = Stream::new(data)
      metadata.local_subrs = parse_index_u16(s)
    }
  }
  SID(metadata)
}

///|
fn parse_cid_metadata(
  data : BytesView,
  top_dict : TopDict,
  number_of_glyphs : UInt16,
) -> FontKind raise Malformed {
  let (charset_offset, fd_array_offset, fd_select_offset) = match
    (
      top_dict.charset_offset,
      top_dict.fd_array_offset,
      top_dict.fd_select_offset,
    ) {
    (Some(a), Some(b), Some(c)) => (a, b, c)
    _ => raise Malformed // charset, FDArray and FDSelect must be set.
  }
  if charset_offset <= 2 {
    // 'There are no predefined charsets for CID fonts.'
    // Adobe Technical Note #5176, chapter 18 CID-keyed Fonts
    raise Malformed
  }
  let fd_array = {
    let s = Stream::new_at_r(data, fd_array_offset)
    parse_index_u16(s)
  }
  let fd_select = {
    let s = Stream::new_at_r(data, fd_select_offset)
    parse_fd_select(number_of_glyphs, s)
  }
  CID({ fd_array, fd_select, })
}

///|
/// A [Compact Font Format Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cff).
struct CffTable {
  // The whole CFF table.
  // Used to resolve a local subroutine in a CID font.
  table_data : BytesView
  strings : CffIndex
  global_subrs : CffIndex
  charset : Charset
  number_of_glyphs : UInt16
  matrix : Matrix
  char_strings : CffIndex
  kind : FontKind
}

///|
/// Parses a table from raw data.
pub fn CffTable::parse(data : BytesView) -> CffTable? {
  try {
    let s = Stream::new(data)

    // Parse Header.
    let major = s.read_u8()
    s.advance(1) // minor
    let header_size = s.read_u8()
    s.advance(1) // Absolute offset
    if major != 1 {
      return None
    }

    // Jump to Name INDEX. It's not necessarily right after the header.
    if header_size > 4 {
      s.advance(header_size.to_int() - 4)
    }

    // Skip Name INDEX.
    skip_index_u16(s)
    let top_dict = parse_top_dict(s)

    // Must be set, otherwise there are nothing to parse.
    if top_dict.char_strings_offset == 0 {
      return None
    }

    // String INDEX.
    let strings = parse_index_u16(s)

    // Parse Global Subroutines INDEX.
    let global_subrs = parse_index_u16(s)
    let char_strings = {
      let s = Stream::new_at_r(data, top_dict.char_strings_offset)
      parse_index_u16(s)
    }

    // 'The number of glyphs is the value of the count field in the CharStrings INDEX.'
    let number_of_glyphs = req(u16_try_from_u32(char_strings.len()))
    if number_of_glyphs == 0 {
      return None
    }
    let charset : Charset = match top_dict.charset_offset {
      Some(0) => ISOAdobe
      Some(1) => Expert
      Some(2) => ExpertSubset
      Some(offset) => {
        let s = Stream::new_at_r(data, offset)
        parse_charset(number_of_glyphs, s)
      }
      None => ISOAdobe // default
    }
    let matrix = top_dict.matrix
    let kind = if top_dict.has_ros {
      parse_cid_metadata(data, top_dict, number_of_glyphs)
    } else {
      // Only SID fonts are allowed to have an Encoding.
      let encoding = match top_dict.encoding_offset {
        Some(0) => Encoding::new_standard()
        Some(1) => Encoding::new_expert()
        Some(offset) => parse_encoding(Stream::new_at_r(data, offset))
        None => Encoding::new_standard() // default
      }
      parse_sid_metadata(data, top_dict, encoding)
    }
    Some({
      table_data: data,
      strings,
      global_subrs,
      charset,
      number_of_glyphs,
      matrix,
      char_strings,
      kind,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a total number of glyphs in the font.
///
/// Never zero.
pub fn CffTable::number_of_glyphs(self : CffTable) -> UInt16 {
  self.number_of_glyphs
}

///|
/// Returns a font transformation matrix.
pub fn CffTable::matrix(self : CffTable) -> Matrix {
  self.matrix
}

///|
/// Outlines a glyph.
pub fn CffTable::outline(
  self : CffTable,
  glyph_id : GlyphId,
  builder : &OutlineBuilder,
) -> Result[Rect, CFFError] {
  guard self.char_strings.get(glyph_id.0.to_uint()) is Some(data) else {
    return Err(NoGlyph)
  }
  try {
    let (rect, _) = cff1_parse_char_string(data, self, glyph_id, false, builder)
    Ok(rect)
  } catch {
    e => Err(e)
  }
}

///|
/// Resolves a Glyph ID for a code point.
///
/// Similar to `Face::glyph_index` but 8bit
/// and uses CFF encoding and charset tables instead of TrueType `cmap`.
pub fn CffTable::glyph_index(self : CffTable, code_point : Byte) -> GlyphId? {
  match self.kind {
    SID(sid_meta) =>
      match sid_meta.encoding.code_to_gid(self.charset, code_point) {
        Some(id) => Some(id)
        None =>
          // Try using the Standard encoding otherwise.
          // Custom Encodings does not guarantee to include all glyphs.
          Encoding::new_standard().code_to_gid(self.charset, code_point)
      }
    CID(_) => None
  }
}

///|
/// Returns a glyph width.
///
/// This value is different from outline bbox width and is stored separately.
///
/// Technically similar to `Face::glyph_hor_advance`.
pub fn CffTable::glyph_width(self : CffTable, glyph_id : GlyphId) -> UInt16? {
  match self.kind {
    SID(sid) => {
      guard self.char_strings.get(glyph_id.0.to_uint()) is Some(data) else {
        return None
      }
      let (_, width) = cff1_parse_char_string(data, self, glyph_id, true, DummyOutline::{
      }) catch {
        _ => return None
      }
      let width = match width {
        Some(w) => sid.nominal_width + w
        None => sid.default_width
      }
      u16_try_from_int(f32_as_i32(width))
    }
    CID(_) => None
  }
}

///|
/// Returns a glyph ID by a name.
pub fn CffTable::glyph_index_by_name(
  self : CffTable,
  name : String,
) -> GlyphId? {
  match self.kind {
    SID(_) => {
      let sid = match cff_standard_names.search(name) {
        Some(index) => StringId(index.to_uint16())
        None => {
          let mut index = 0
          let mut found = false
          for n in self.strings.iter() {
            if bytes_eq_str(n, name) {
              found = true
              break
            }
            index += 1
          }
          if !found {
            return None
          }
          StringId((cff_standard_names.length() + index).to_uint16())
        }
      }
      self.charset.sid_to_gid(sid)
    }
    CID(_) => None
  }
}

///|
/// Compares raw bytes with the UTF-8 encoding of a string.
fn bytes_eq_str(bytes : BytesView, s : String) -> Bool {
  let encoded = @utf8.encode(s)
  if encoded.length() != bytes.length() {
    return false
  }
  for i in 0..<bytes.length() {
    if encoded[i] != bytes[i] {
      return false
    }
  }
  true
}

///|
/// Returns a glyph name.
pub fn CffTable::glyph_name(self : CffTable, glyph_id : GlyphId) -> String? {
  match self.kind {
    SID(_) => {
      guard self.charset.gid_to_sid(glyph_id) is Some(sid) else { return None }
      let sid = sid.0.to_int()
      if sid < cff_standard_names.length() {
        Some(cff_standard_names[sid])
      } else {
        let idx = (sid - cff_standard_names.length()).reinterpret_as_uint()
        guard self.strings.get(idx) is Some(name) else { return None }
        utf8_to_string(name)
      }
    }
    CID(_) => None
  }
}

///|
/// Returns the CID corresponding to a glyph ID.
///
/// Returns `None` if this is not a CIDFont.
pub fn CffTable::glyph_cid(self : CffTable, glyph_id : GlyphId) -> UInt16? {
  match self.kind {
    SID(_) => None
    CID(_) => self.charset.gid_to_sid(glyph_id).map(id => id.0)
  }
}
