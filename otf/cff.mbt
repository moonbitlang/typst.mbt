// Common CFF/CFF2 code.
//
// Port of `ttf-parser` 0.25.1 `src/tables/cff/{mod, argstack, index, dict,
// charset, encoding, charstring}.rs`.

///|
/// A list of errors that can occur during a CFF glyph outlining.
pub(all) suberror CFFError {
  NoGlyph
  ReadOutOfBounds
  ZeroBBox
  InvalidOperator
  UnsupportedOperator
  MissingEndChar
  DataAfterEndChar
  NestingLimitReached
  ArgumentsStackLimitReached
  InvalidArgumentsStackLength
  BboxOverflow
  MissingMoveTo
  InvalidSubroutineIndex
  NoLocalSubroutines
  InvalidSeacCode
  InvalidItemVariationDataIndex
  InvalidNumberOfBlendOperands
  BlendRegionsLimitReached
} derive(Eq, Debug)

///|
priv struct CffBuilder {
  builder : &OutlineBuilder
  bbox : RectF
}

///|
fn CffBuilder::move_to(self : CffBuilder, x : Float, y : Float) -> Unit {
  self.bbox.extend_by(x, y)
  self.builder.move_to(x, y)
}

///|
fn CffBuilder::line_to(self : CffBuilder, x : Float, y : Float) -> Unit {
  self.bbox.extend_by(x, y)
  self.builder.line_to(x, y)
}

///|
fn CffBuilder::curve_to(
  self : CffBuilder,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  x : Float,
  y : Float,
) -> Unit {
  self.bbox.extend_by(x1, y1)
  self.bbox.extend_by(x2, y2)
  self.bbox.extend_by(x, y)
  self.builder.curve_to(x1, y1, x2, y2, x, y)
}

///|
fn CffBuilder::close(self : CffBuilder) -> Unit {
  self.builder.close()
}

///|
/// A type-safe wrapper for string ID.
pub(all) struct StringId(UInt16) derive(Eq, Compare, Debug)

///|
pub impl FromData for StringId with fn size() {
  2
}

///|
pub impl FromData for StringId with fn parse(data) {
  StringId(FromData::parse(data))
}

///|
fn f32_abs(n : Float) -> Float {
  n.abs()
}

///|
fn conv_subroutine_index(index : Float, bias : UInt16) -> UInt raise CFFError {
  match conv_subroutine_index_impl(index, bias) {
    Some(v) => v
    None => raise InvalidSubroutineIndex
  }
}

///|
fn conv_subroutine_index_impl(index : Float, bias : UInt16) -> UInt? {
  guard try_i32_from_f32(index) is Some(index) else { return None }
  let bias = bias.to_int()
  let index = index.to_int64() + bias.to_int64()
  if index > 0x7fffffffL || index < 0L {
    return None
  }
  Some(index.to_int().reinterpret_as_uint())
}

///|
// Adobe Technical Note #5176, Chapter 16 "Local / Global Subrs INDEXes"
fn calc_subroutine_bias(len : UInt) -> UInt16 {
  if len < 1240 {
    107
  } else if len < 33900 {
    1131
  } else {
    32768
  }
}

// ---------------------------------------------------------------------------
// argstack.rs

///|
priv struct ArgumentsStack {
  data : FixedArray[Float]
  mut len : Int
  max_len : Int
}

///|
fn ArgumentsStack::new(max_len : Int) -> ArgumentsStack {
  { data: FixedArray::make(max_len, 0.0), len: 0, max_len, }
}

///|
fn ArgumentsStack::len(self : ArgumentsStack) -> Int {
  self.len
}

///|
fn ArgumentsStack::is_empty(self : ArgumentsStack) -> Bool {
  self.len == 0
}

///|
fn ArgumentsStack::push(
  self : ArgumentsStack,
  n : Float,
) -> Unit raise CFFError {
  if self.len == self.max_len {
    raise ArgumentsStackLimitReached
  } else {
    self.data[self.len] = n
    self.len += 1
  }
}

///|
fn ArgumentsStack::at(self : ArgumentsStack, index : Int) -> Float {
  self.data[index]
}

///|
fn ArgumentsStack::pop(self : ArgumentsStack) -> Float raise CFFError {
  // Upstream only `debug_assert`s here (and would panic on underflow).
  if self.len == 0 {
    raise InvalidArgumentsStackLength
  }
  self.len -= 1
  self.data[self.len]
}

///|
fn ArgumentsStack::reverse(self : ArgumentsStack) -> Unit {
  if self.is_empty() {
    return
  }
  // Reverse only the actual data and not the whole stack.
  let mut i = 0
  let mut j = self.len - 1
  while i < j {
    let t = self.data[i]
    self.data[i] = self.data[j]
    self.data[j] = t
    i += 1
    j -= 1
  }
}

///|
fn ArgumentsStack::clear(self : ArgumentsStack) -> Unit {
  self.len = 0
}

// ---------------------------------------------------------------------------
// index.rs

///|
fn parse_index_u16(s : Stream) -> CffIndex raise Malformed {
  let count = s.read_u16()
  parse_index_impl(count.to_uint(), s)
}

///|
fn parse_index_u32(s : Stream) -> CffIndex raise Malformed {
  let count = s.read_u32()
  parse_index_impl(count, s)
}

///|
fn parse_index_impl(count : UInt, s : Stream) -> CffIndex raise Malformed {
  if count == 0 || count == 0xFFFFFFFF {
    return CffIndex::default()
  }
  let offset_size = OffsetSize::parse(s.read_u8())
  let offsets_len = (count + 1).to_uint64() * offset_size.to_u32().to_uint64()
  if offsets_len > 0xFFFFFFFFUL || offsets_len > 0x7fffffffUL {
    raise Malformed
  }
  let offsets : VarOffsets = {
    data: s.read_bytes(offsets_len.to_int()),
    offset_size,
  }

  // Last offset indicates a Data Index size.
  match offsets.last() {
    Some(last_offset) => {
      let data = s.read_bytes(u32_to_usize(last_offset))
      { data, offsets, }
    }
    None => CffIndex::default()
  }
}

///|
/// `usize::num_from(u32)`; values beyond `Int` saturate so that bounds checks
/// fail.
fn u32_to_usize(v : UInt) -> Int {
  let i = v.reinterpret_as_int()
  if i < 0 {
    0x7fffffff
  } else {
    i
  }
}

///|
fn skip_index_u16(s : Stream) -> Unit raise Malformed {
  let count = s.read_u16()
  skip_index_impl(count.to_uint(), s)
}

///|
fn skip_index_impl(count : UInt, s : Stream) -> Unit raise Malformed {
  if count == 0 || count == 0xFFFFFFFF {
    return
  }
  let offset_size = OffsetSize::parse(s.read_u8())
  let offsets_len = (count + 1).to_uint64() * offset_size.to_u32().to_uint64()
  if offsets_len > 0x7fffffffUL {
    raise Malformed
  }
  let offsets : VarOffsets = {
    data: s.read_bytes(offsets_len.to_int()),
    offset_size,
  }
  if offsets.last() is Some(last_offset) {
    s.advance(u32_to_usize(last_offset))
  }
}

///|
priv struct VarOffsets {
  data : BytesView
  offset_size : OffsetSize
}

///|
fn VarOffsets::get(self : VarOffsets, index : UInt) -> UInt? {
  if index >= self.len() {
    return None
  }
  let start = index.reinterpret_as_int() * self.offset_size.to_usize()
  guard Stream::new_at(self.data, start) is Some(s) else { return None }
  let n : UInt = match self.offset_size {
    Size1 => (s.read_u8() catch { _ => return None }).to_uint()
    Size2 => (s.read_u16() catch { _ => return None }).to_uint()
    Size3 => (s.read() catch { _ => return None } : U24).0
    Size4 => s.read_u32() catch { _ => return None }
  }

  // Offsets are offset by one byte in the font,
  // so we have to shift them back.
  u32_checked_sub(n, 1)
}

///|
fn VarOffsets::last(self : VarOffsets) -> UInt? {
  if !self.is_empty() {
    self.get(self.len() - 1)
  } else {
    None
  }
}

///|
fn VarOffsets::len(self : VarOffsets) -> UInt {
  (self.data.length() / self.offset_size.to_usize()).reinterpret_as_uint()
}

///|
fn VarOffsets::is_empty(self : VarOffsets) -> Bool {
  self.len() == 0
}

///|
struct CffIndex {
  data : BytesView
  offsets : VarOffsets
}

///|
impl Default for CffIndex with fn default() {
  { data: empty_data, offsets: { data: empty_data, offset_size: Size1, }, }
}

///|
fn CffIndex::len(self : CffIndex) -> UInt {
  // Last offset points to the byte after the `Object data`. We should skip it.
  let n = self.offsets.len()
  if n == 0 {
    0
  } else {
    n - 1
  }
}

///|
fn CffIndex::get(self : CffIndex, index : UInt) -> BytesView? {
  guard u32_checked_add(index, 1) is Some(next_index) else { return None } // make sure we do not overflow
  guard self.offsets.get(index) is Some(start) else { return None }
  guard self.offsets.get(next_index) is Some(end) else { return None }
  slice_get(self.data, u32_to_usize(start), u32_to_usize(end))
}

///|
fn CffIndex::iter(self : CffIndex) -> Iter[BytesView] {
  let len = self.len()
  let mut offset_index : UInt = 0
  Iter::new(fn() {
    if offset_index == len {
      return None
    }
    let index = offset_index
    offset_index += 1
    self.get(index)
  })
}

///|
priv enum OffsetSize {
  Size1
  Size2
  Size3
  Size4
} derive(Eq)

///|
fn OffsetSize::to_u32(self : OffsetSize) -> UInt {
  self.to_usize().reinterpret_as_uint()
}

///|
fn OffsetSize::to_usize(self : OffsetSize) -> Int {
  match self {
    Size1 => 1
    Size2 => 2
    Size3 => 3
    Size4 => 4
  }
}

///|
fn OffsetSize::parse(b : Byte) -> OffsetSize raise Malformed {
  match b {
    1 => Size1
    2 => Size2
    3 => Size3
    4 => Size4
    _ => raise Malformed
  }
}

// ---------------------------------------------------------------------------
// dict.rs

///|
// Limits according to the Adobe Technical Note #5176, chapter 4 DICT Data.
let dict_two_byte_operator_mark : Byte = 12

///|
let dict_float_stack_len : Int = 64

///|
let dict_end_of_float_flag : Int = 0xf

///|
priv struct DictionaryParser {
  data : BytesView
  // The current offset.
  mut offset : Int
  // Offset to the last operands start.
  mut operands_offset : Int
  // Actual operands.
  //
  // While CFF can contain only i32 and f32 values, we have to store operands as f64
  // since f32 cannot represent the whole i32 range.
  // Meaning we have a choice of storing operands as f64 or as enum of i32/f32.
  // In both cases the type size would be 8 bytes, so it's easier to simply use f64.
  operands : FixedArray[Double]
  // An amount of operands in the `operands` array.
  mut operands_len : Int
}

///|
fn DictionaryParser::new(
  data : BytesView,
  max_operands : Int,
) -> DictionaryParser {
  {
    data,
    offset: 0,
    operands_offset: 0,
    operands: FixedArray::make(max_operands, 0.0),
    operands_len: 0,
  }
}

///|
fn DictionaryParser::parse_next(self : DictionaryParser) -> UInt16? {
  guard Stream::new_at(self.data, self.offset) is Some(s) else { return None }
  self.operands_offset = self.offset
  while !s.at_end() {
    let b = s.read_u8() catch { _ => return None }
    // 0..=21 bytes are operators.
    if is_dict_one_byte_op(b) {
      let mut operator = u16_from_u8(b)

      // Check that operator is two byte long.
      if b == dict_two_byte_operator_mark {
        // Use a 1200 'prefix' to make two byte operators more readable.
        // 12 3 => 1203
        operator = 1200 + u16_from_u8(s.read_u8() catch { _ => return None })
      }
      self.offset = s.offset()
      return Some(operator)
    } else {
      skip_number(b, s) catch {
        _ => return None
      }
    }
  }
  None
}

///|
/// Parses operands of the current operator.
///
/// In the DICT structure, operands are defined before an operator.
/// So we are trying to find an operator first and the we can actually parse the operands.
///
/// Since this methods is pretty expensive and we do not care about most of the operators,
/// we can speed up parsing by parsing operands only for required operators.
///
/// We still have to "skip" operands during operators search (see `skip_number()`),
/// but it's still faster that a naive method.
fn DictionaryParser::parse_operands(
  self : DictionaryParser,
) -> Unit raise Malformed {
  let s = Stream::new_at_r(self.data, self.operands_offset)
  self.operands_len = 0
  while !s.at_end() {
    let b = s.read_u8()
    // 0..=21 bytes are operators.
    if is_dict_one_byte_op(b) {
      break
    } else {
      let op = parse_dict_number(b, s)
      self.operands[self.operands_len] = op
      self.operands_len += 1
      if self.operands_len >= self.operands.length() {
        break
      }
    }
  }
}

///|
fn DictionaryParser::operands(self : DictionaryParser) -> ArrayView[Double] {
  // FixedArray has no views; copy the (small) operand list.
  Array::makei(self.operands_len, i => self.operands[i])[:]
}

///|
fn DictionaryParser::parse_number(self : DictionaryParser) -> Double? {
  self.parse_operands() catch {
    _ => return None
  }
  if self.operands_len > 0 {
    Some(self.operands[0])
  } else {
    None
  }
}

///|
/// Rust's `f64 as i32` (saturating, NaN -> 0).
fn f64_as_i32(v : Double) -> Int {
  if v.is_nan() {
    0
  } else if v >= 2147483647.0 {
    0x7fffffff
  } else if v <= -2147483648.0 {
    -0x80000000
  } else {
    v.to_int()
  }
}

///|
fn DictionaryParser::parse_offset(self : DictionaryParser) -> Int? {
  self.parse_operands() catch {
    _ => return None
  }
  if self.operands_len == 1 {
    let n = f64_as_i32(self.operands[0])
    if n >= 0 {
      Some(n)
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn DictionaryParser::parse_range(self : DictionaryParser) -> (Int, Int)? {
  self.parse_operands() catch {
    _ => return None
  }
  if self.operands_len == 2 {
    let len = f64_as_i32(self.operands[0])
    let start = f64_as_i32(self.operands[1])
    if len < 0 || start < 0 {
      return None
    }
    guard usize_checked_add(start, len) is Some(end) else { return None }
    Some((start, end))
  } else {
    None
  }
}

///|
// One-byte CFF DICT Operators according to the
// Adobe Technical Note #5176, Appendix H CFF DICT Encoding.
fn is_dict_one_byte_op(b : Byte) -> Bool {
  match b.to_int() {
    0..=27 => true
    28..=30 => false // numbers
    31 => true // Reserved
    32..=254 => false // numbers
    _ => true // Reserved
  }
}

///|
// Adobe Technical Note #5177, Table 3 Operand Encoding
fn parse_dict_number(b0 : Byte, s : Stream) -> Double raise Malformed {
  let b0 = b0.to_int()
  match b0 {
    28 => {
      let n = s.read_i16().to_int()
      Double::from_int(n)
    }
    29 => {
      let n = s.read_i32()
      Double::from_int(n)
    }
    30 => parse_dict_float(s)
    32..=246 => {
      let n = b0 - 139
      Double::from_int(n)
    }
    247..=250 => {
      let b1 = s.read_u8().to_int()
      let n = (b0 - 247) * 256 + b1 + 108
      Double::from_int(n)
    }
    251..=254 => {
      let b1 = s.read_u8().to_int()
      let n = -(b0 - 251) * 256 - b1 - 108
      Double::from_int(n)
    }
    _ => raise Malformed
  }
}

///|
fn parse_dict_float(s : Stream) -> Double raise Malformed {
  let data = StringBuilder::new()
  let mut idx = 0
  while true {
    let b1 = s.read_u8().to_int()
    let nibble1 = b1 >> 4
    let nibble2 = b1 & 15
    if nibble1 == dict_end_of_float_flag {
      break
    }
    idx = parse_float_nibble(nibble1, idx, data)
    if nibble2 == dict_end_of_float_flag {
      break
    }
    idx = parse_float_nibble(nibble2, idx, data)
  }
  rust_parse_f64(data.to_string())
}

///|
// Adobe Technical Note #5176, Table 5 Nibble Definitions
fn parse_float_nibble(
  nibble : Int,
  idx : Int,
  data : StringBuilder,
) -> Int raise Malformed {
  let mut idx = idx
  if idx == dict_float_stack_len {
    raise Malformed
  }
  match nibble {
    0..=9 => data.write_char((48 + nibble).unsafe_to_char())
    10 => data.write_char('.')
    11 => data.write_char('E')
    12 => {
      if idx + 1 == dict_float_stack_len {
        raise Malformed
      }
      data.write_char('E')
      idx += 1
      data.write_char('-')
    }
    13 => raise Malformed
    14 => data.write_char('-')
    _ => raise Malformed
  }
  idx += 1
  idx
}

///|
/// Rust's `str::parse::<f64>` for the strings the CFF float nibbles can
/// produce (digits, `.`, `E`, `-`).
fn rust_parse_f64(s : String) -> Double raise Malformed {
  // Validate Rust's grammar:
  // Sign? (Digit+ | Digit+ '.' Digit* | Digit* '.' Digit+) (('e'|'E') Sign? Digit+)?
  let chars = s.to_array()
  let n = chars.length()
  let mut i = 0
  if i < n && (chars[i] == '-' || chars[i] == '+') {
    i += 1
  }
  let mut int_digits = 0
  while i < n && chars[i] >= '0' && chars[i] <= '9' {
    i += 1
    int_digits += 1
  }
  let mut frac_digits = 0
  if i < n && chars[i] == '.' {
    i += 1
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      i += 1
      frac_digits += 1
    }
  }
  if int_digits == 0 && frac_digits == 0 {
    raise Malformed
  }
  if i < n && (chars[i] == 'e' || chars[i] == 'E') {
    i += 1
    if i < n && (chars[i] == '-' || chars[i] == '+') {
      i += 1
    }
    let mut exp_digits = 0
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      i += 1
      exp_digits += 1
    }
    if exp_digits == 0 {
      raise Malformed
    }
  }
  if i != n {
    raise Malformed
  }
  // Normalize forms like `5.` / `.5` for the MoonBit parser.
  let mut t = s
  if frac_digits == 0 && t.contains(".") {
    t = t.replace(old=".", new=".0")
  }
  if int_digits == 0 {
    t = t.replace(old=".", new="0.")
  }
  @string.parse_double(t) catch {
    _ => raise Malformed
  }
}

///|
// Just like `parse_number`, but doesn't actually parses the data.
fn skip_number(b0 : Byte, s : Stream) -> Unit raise Malformed {
  match b0.to_int() {
    28 => s.advance(2)
    29 => s.advance(4)
    30 =>
      while !s.at_end() {
        let b1 = s.read_u8().to_int()
        let nibble1 = b1 >> 4
        let nibble2 = b1 & 15
        if nibble1 == dict_end_of_float_flag ||
          nibble2 == dict_end_of_float_flag {
          break
        }
      }
    32..=246 => ()
    247..=250 => s.advance(1)
    251..=254 => s.advance(1)
    _ => raise Malformed
  }
}

// ---------------------------------------------------------------------------
// charset.rs

///|
priv struct CharsetFormat1Range {
  first : StringId
  left : Byte
}

///|
impl FromData for CharsetFormat1Range with fn size() {
  3
}

///|
impl FromData for CharsetFormat1Range with fn parse(data) {
  let s = Stream::new(data)
  { first: s.read(), left: s.read(), }
}

///|
priv struct CharsetFormat2Range {
  first : StringId
  left : UInt16
}

///|
impl FromData for CharsetFormat2Range with fn size() {
  4
}

///|
impl FromData for CharsetFormat2Range with fn parse(data) {
  let s = Stream::new(data)
  { first: s.read(), left: s.read(), }
}

///|
priv enum Charset {
  ISOAdobe
  Expert
  ExpertSubset
  Format0(LazyArray16[StringId])
  Format1(LazyArray16[CharsetFormat1Range])
  Format2(LazyArray16[CharsetFormat2Range])
}

///|
fn Charset::sid_to_gid(self : Charset, sid : StringId) -> GlyphId? {
  if sid.0 == 0 {
    return Some(GlyphId(0))
  }
  match self {
    ISOAdobe | Expert | ExpertSubset => None
    Format0(array) => {
      // First glyph is omitted, so we have to add 1.
      let mut i = 0
      for n in array.iter() {
        if n == sid {
          return Some(GlyphId(i.to_uint16() + 1))
        }
        i += 1
      }
      None
    }
    Format1(array) => {
      let mut glyph_id : UInt16 = 1
      for range in array.iter() {
        let last = range.first.0.to_uint() + range.left.to_uint()
        if range.first <= sid && sid.0.to_uint() <= last {
          glyph_id += sid.0 - range.first.0
          return Some(GlyphId(glyph_id))
        }
        glyph_id += u16_from_u8(range.left) + 1
      }
      None
    }
    Format2(array) => {
      // The same as format 1, but Range::left is u16.
      let mut glyph_id : UInt16 = 1
      for range in array.iter() {
        let last = range.first.0.to_uint() + range.left.to_uint()
        if sid >= range.first && sid.0.to_uint() <= last {
          glyph_id += sid.0 - range.first.0
          return Some(GlyphId(glyph_id))
        }
        glyph_id += range.left + 1
      }
      None
    }
  }
}

///|
fn Charset::gid_to_sid(self : Charset, gid : GlyphId) -> StringId? {
  match self {
    ISOAdobe => if gid.0 <= 228 { Some(StringId(gid.0)) } else { None }
    Expert => {
      let i = gid.0.to_int()
      if i < cff_expert_encoding.length() {
        Some(StringId(cff_expert_encoding[i]))
      } else {
        None
      }
    }
    ExpertSubset => {
      let i = gid.0.to_int()
      if i < cff_expert_subset_encoding.length() {
        Some(StringId(cff_expert_subset_encoding[i]))
      } else {
        None
      }
    }
    Format0(array) =>
      if gid.0 == 0 {
        Some(StringId(0))
      } else {
        array.get(gid.0 - 1)
      }
    Format1(array) =>
      if gid.0 == 0 {
        Some(StringId(0))
      } else {
        let mut sid = gid.0 - 1
        for range in array.iter() {
          if sid <= u16_from_u8(range.left) {
            guard u16_checked_add(sid, range.first.0) is Some(sid) else {
              return None
            }
            return Some(StringId(sid))
          }
          guard u16_checked_sub(sid, u16_from_u8(range.left) + 1) is Some(s) else {
            return None
          }
          sid = s
        }
        None
      }
    Format2(array) =>
      if gid.0 == 0 {
        Some(StringId(0))
      } else {
        let mut sid = gid.0 - 1
        for range in array.iter() {
          if sid <= range.left {
            guard u16_checked_add(sid, range.first.0) is Some(sid) else {
              return None
            }
            return Some(StringId(sid))
          }
          guard u16_checked_add(range.left, 1) is Some(l) else { return None }
          guard u16_checked_sub(sid, l) is Some(s) else { return None }
          sid = s
        }
        None
      }
  }
}

///|
fn parse_charset(
  number_of_glyphs : UInt16,
  s : Stream,
) -> Charset raise Malformed {
  // -1 everywhere, since `.notdef` is omitted.
  let format = s.read_u8()
  match format {
    0 => Format0(s.read_array16(number_of_glyphs - 1))
    1 => {
      // The number of ranges is not defined, so we have to
      // read until no glyphs are left.
      let mut count : UInt16 = 0
      {
        let s = s.copy()
        let mut total_left = number_of_glyphs - 1
        while total_left > 0 {
          s.advance(2) // first
          let left = s.read_u8()
          total_left = req(u16_checked_sub(total_left, u16_from_u8(left) + 1))
          count += 1
        }
      }
      Format1(s.read_array16(count))
    }
    2 => {
      // The same as format 1, but Range::left is u16.
      let mut count : UInt16 = 0
      {
        let s = s.copy()
        let mut total_left = number_of_glyphs - 1
        while total_left > 0 {
          s.advance(2) // first
          let left = req(u16_checked_add(s.read_u16(), 1))
          total_left = req(u16_checked_sub(total_left, left))
          count += 1
        }
      }
      Format2(s.read_array16(count))
    }
    _ => raise Malformed
  }
}

// ---------------------------------------------------------------------------
// encoding.rs

///|
priv struct EncodingFormat1Range {
  first : Byte
  left : Byte
}

///|
impl FromData for EncodingFormat1Range with fn size() {
  2
}

///|
impl FromData for EncodingFormat1Range with fn parse(data) {
  let s = Stream::new(data)
  { first: s.read(), left: s.read(), }
}

///|
priv struct Supplement {
  code : Byte
  name : StringId
}

///|
impl FromData for Supplement with fn size() {
  3
}

///|
impl FromData for Supplement with fn parse(data) {
  let s = Stream::new(data)
  { code: s.read(), name: s.read(), }
}

///|
priv struct Encoding {
  kind : EncodingKind
  supplemental : LazyArray16[Supplement]
}

///|
priv enum EncodingKind {
  Standard
  Expert
  Format0(LazyArray16[Byte])
  Format1(LazyArray16[EncodingFormat1Range])
}

///|
fn Encoding::new_standard() -> Encoding {
  { kind: Standard, supplemental: LazyArray16::default(), }
}

///|
fn Encoding::new_expert() -> Encoding {
  { kind: Expert, supplemental: LazyArray16::default(), }
}

///|
fn Encoding::code_to_gid(
  self : Encoding,
  charset : Charset,
  code : Byte,
) -> GlyphId? {
  if !self.supplemental.is_empty() {
    for s in self.supplemental.iter() {
      if s.code == code {
        return charset.sid_to_gid(s.name)
      }
    }
  }
  let index = code.to_int()
  match self.kind {
    // Standard encodings store a StringID/SID and not GlyphID/GID.
    // Therefore we have to get SID first and then convert it to GID via Charset.
    // Custom encodings (FormatN) store GID directly.
    //
    // Indexing for predefined encodings never fails,
    // because `code` is always `u8` and encodings have 256 entries.
    //
    // We treat `Expert` as `Standard` as well, since we allow only 8bit codepoints.
    Standard | Expert => {
      let sid = StringId(u16_from_u8(cff_standard_encoding[index]))
      charset.sid_to_gid(sid)
    }
    Format0(table) => {
      // +1 because .notdef is implicit.
      let mut i = 0
      for c in table.iter() {
        if c == code {
          return Some(GlyphId((i + 1).to_uint16()))
        }
        i += 1
      }
      None
    }
    Format1(table) => {
      // Starts from 1 because .notdef is implicit.
      let mut gid : UInt16 = 1
      for range in table.iter() {
        let end_ = range.first.to_int() + range.left.to_int()
        let end_ = if end_ > 255 { 255 } else { end_ }
        if code >= range.first && code.to_int() <= end_ {
          gid += u16_from_u8(code - range.first)
          return Some(GlyphId(gid))
        } else {
          gid += u16_from_u8(range.left) + 1
        }
      }
      None
    }
  }
}

///|
fn parse_encoding(s : Stream) -> Encoding raise Malformed {
  let format = s.read_u8()
  // The first high-bit in format indicates that a Supplemental encoding is present.
  // Check it and clear.
  let has_supplemental = (format & 0x80) != 0
  let format = format & 0x7f
  let count = u16_from_u8(s.read_u8())
  let kind : EncodingKind = match format {
    // TODO: read_array8?
    0 => Format0(s.read_array16(count))
    1 => Format1(s.read_array16(count))
    _ => raise Malformed
  }
  let supplemental = if has_supplemental {
    let count = u16_from_u8(s.read_u8())
    s.read_array16(count)
  } else {
    LazyArray16::default()
  }
  { kind, supplemental, }
}

// ---------------------------------------------------------------------------
// charstring.rs

///|
priv struct CharStringParser {
  stack : ArgumentsStack
  builder : CffBuilder
  mut x : Float
  mut y : Float
  mut has_move_to : Bool
  mut is_first_move_to : Bool
  width_only : Bool // Exit right after the glyph width is parsed.
}

///|
fn CharStringParser::parse_move_to(
  self : CharStringParser,
  offset : Int,
) -> Unit raise CFFError {
  // dx1 dy1
  if self.stack.len() != offset + 2 {
    raise InvalidArgumentsStackLength
  }
  if self.is_first_move_to {
    self.is_first_move_to = false
  } else {
    self.builder.close()
  }
  self.has_move_to = true
  self.x += self.stack.at(offset + 0)
  self.y += self.stack.at(offset + 1)
  self.builder.move_to(self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_horizontal_move_to(
  self : CharStringParser,
  offset : Int,
) -> Unit raise CFFError {
  // dx1
  if self.stack.len() != offset + 1 {
    raise InvalidArgumentsStackLength
  }
  if self.is_first_move_to {
    self.is_first_move_to = false
  } else {
    self.builder.close()
  }
  self.has_move_to = true
  self.x += self.stack.at(offset)
  self.builder.move_to(self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_vertical_move_to(
  self : CharStringParser,
  offset : Int,
) -> Unit raise CFFError {
  // dy1
  if self.stack.len() != offset + 1 {
    raise InvalidArgumentsStackLength
  }
  if self.is_first_move_to {
    self.is_first_move_to = false
  } else {
    self.builder.close()
  }
  self.has_move_to = true
  self.y += self.stack.at(offset)
  self.builder.move_to(self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_line_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // {dxa dya}+
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if (self.stack.len() & 1) != 0 {
    raise InvalidArgumentsStackLength
  }
  let mut i = 0
  while i < self.stack.len() {
    self.x += self.stack.at(i + 0)
    self.y += self.stack.at(i + 1)
    self.builder.line_to(self.x, self.y)
    i += 2
  }
  self.stack.clear()
}

///|
fn CharStringParser::parse_horizontal_line_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dx1 {dya dxb}*
  //     {dxa dyb}+
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.is_empty() {
    raise InvalidArgumentsStackLength
  }
  let mut i = 0
  while i < self.stack.len() {
    self.x += self.stack.at(i)
    i += 1
    self.builder.line_to(self.x, self.y)
    if i == self.stack.len() {
      break
    }
    self.y += self.stack.at(i)
    i += 1
    self.builder.line_to(self.x, self.y)
  }
  self.stack.clear()
}

///|
fn CharStringParser::parse_vertical_line_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dy1 {dxa dyb}*
  //     {dya dxb}+
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.is_empty() {
    raise InvalidArgumentsStackLength
  }
  let mut i = 0
  while i < self.stack.len() {
    self.y += self.stack.at(i)
    i += 1
    self.builder.line_to(self.x, self.y)
    if i == self.stack.len() {
      break
    }
    self.x += self.stack.at(i)
    i += 1
    self.builder.line_to(self.x, self.y)
  }
  self.stack.clear()
}

///|
fn CharStringParser::parse_curve_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // {dxa dya dxb dyb dxc dyc}+
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() % 6 != 0 {
    raise InvalidArgumentsStackLength
  }
  let mut i = 0
  while i < self.stack.len() {
    let x1 = self.x + self.stack.at(i + 0)
    let y1 = self.y + self.stack.at(i + 1)
    let x2 = x1 + self.stack.at(i + 2)
    let y2 = y1 + self.stack.at(i + 3)
    self.x = x2 + self.stack.at(i + 4)
    self.y = y2 + self.stack.at(i + 5)
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
    i += 6
  }
  self.stack.clear()
}

///|
fn CharStringParser::parse_curve_line(
  self : CharStringParser,
) -> Unit raise CFFError {
  // {dxa dya dxb dyb dxc dyc}+ dxd dyd
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() < 8 {
    raise InvalidArgumentsStackLength
  }
  if (self.stack.len() - 2) % 6 != 0 {
    raise InvalidArgumentsStackLength
  }
  let mut i = 0
  while i < self.stack.len() - 2 {
    let x1 = self.x + self.stack.at(i + 0)
    let y1 = self.y + self.stack.at(i + 1)
    let x2 = x1 + self.stack.at(i + 2)
    let y2 = y1 + self.stack.at(i + 3)
    self.x = x2 + self.stack.at(i + 4)
    self.y = y2 + self.stack.at(i + 5)
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
    i += 6
  }
  self.x += self.stack.at(i + 0)
  self.y += self.stack.at(i + 1)
  self.builder.line_to(self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_line_curve(
  self : CharStringParser,
) -> Unit raise CFFError {
  // {dxa dya}+ dxb dyb dxc dyc dxd dyd
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() < 8 {
    raise InvalidArgumentsStackLength
  }
  if ((self.stack.len() - 6) & 1) != 0 {
    raise InvalidArgumentsStackLength
  }
  let mut i = 0
  while i < self.stack.len() - 6 {
    self.x += self.stack.at(i + 0)
    self.y += self.stack.at(i + 1)
    self.builder.line_to(self.x, self.y)
    i += 2
  }
  let x1 = self.x + self.stack.at(i + 0)
  let y1 = self.y + self.stack.at(i + 1)
  let x2 = x1 + self.stack.at(i + 2)
  let y2 = y1 + self.stack.at(i + 3)
  self.x = x2 + self.stack.at(i + 4)
  self.y = y2 + self.stack.at(i + 5)
  self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_hh_curve_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dy1? {dxa dxb dyb dxc}+
  if !self.has_move_to {
    raise MissingMoveTo
  }
  let mut i = 0

  // The odd argument count indicates an Y position.
  if (self.stack.len() & 1) != 0 {
    self.y += self.stack.at(0)
    i += 1
  }
  if (self.stack.len() - i) % 4 != 0 {
    raise InvalidArgumentsStackLength
  }
  while i < self.stack.len() {
    let x1 = self.x + self.stack.at(i + 0)
    let y1 = self.y
    let x2 = x1 + self.stack.at(i + 1)
    let y2 = y1 + self.stack.at(i + 2)
    self.x = x2 + self.stack.at(i + 3)
    self.y = y2
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
    i += 4
  }
  self.stack.clear()
}

///|
fn CharStringParser::parse_vv_curve_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dx1? {dya dxb dyb dyc}+
  if !self.has_move_to {
    raise MissingMoveTo
  }
  let mut i = 0

  // The odd argument count indicates an X position.
  if (self.stack.len() & 1) != 0 {
    self.x += self.stack.at(0)
    i += 1
  }
  if (self.stack.len() - i) % 4 != 0 {
    raise InvalidArgumentsStackLength
  }
  while i < self.stack.len() {
    let x1 = self.x
    let y1 = self.y + self.stack.at(i + 0)
    let x2 = x1 + self.stack.at(i + 1)
    let y2 = y1 + self.stack.at(i + 2)
    self.x = x2
    self.y = y2 + self.stack.at(i + 3)
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
    i += 4
  }
  self.stack.clear()
}

///|
fn CharStringParser::parse_hv_curve_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dx1 dx2 dy2 dy3 {dya dxb dyb dxc dxd dxe dye dyf}* dxf?
  //                 {dxa dxb dyb dyc dyd dxe dye dxf}+ dyf?
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() < 4 {
    raise InvalidArgumentsStackLength
  }
  self.stack.reverse()
  while !self.stack.is_empty() {
    if self.stack.len() < 4 {
      raise InvalidArgumentsStackLength
    }
    let x1 = self.x + self.stack.pop()
    let y1 = self.y
    let x2 = x1 + self.stack.pop()
    let y2 = y1 + self.stack.pop()
    self.y = y2 + self.stack.pop()
    self.x = x2
    if self.stack.len() == 1 {
      self.x += self.stack.pop()
    }
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
    if self.stack.is_empty() {
      break
    }
    if self.stack.len() < 4 {
      raise InvalidArgumentsStackLength
    }
    let x1 = self.x
    let y1 = self.y + self.stack.pop()
    let x2 = x1 + self.stack.pop()
    let y2 = y1 + self.stack.pop()
    self.x = x2 + self.stack.pop()
    self.y = y2
    if self.stack.len() == 1 {
      self.y += self.stack.pop()
    }
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
  }
}

///|
fn CharStringParser::parse_vh_curve_to(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dy1 dx2 dy2 dx3 {dxa dxb dyb dyc dyd dxe dye dxf}* dyf?
  //                 {dya dxb dyb dxc dxd dxe dye dyf}+ dxf?
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() < 4 {
    raise InvalidArgumentsStackLength
  }
  self.stack.reverse()
  while !self.stack.is_empty() {
    if self.stack.len() < 4 {
      raise InvalidArgumentsStackLength
    }
    let x1 = self.x
    let y1 = self.y + self.stack.pop()
    let x2 = x1 + self.stack.pop()
    let y2 = y1 + self.stack.pop()
    self.x = x2 + self.stack.pop()
    self.y = y2
    if self.stack.len() == 1 {
      self.y += self.stack.pop()
    }
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
    if self.stack.is_empty() {
      break
    }
    if self.stack.len() < 4 {
      raise InvalidArgumentsStackLength
    }
    let x1 = self.x + self.stack.pop()
    let y1 = self.y
    let x2 = x1 + self.stack.pop()
    let y2 = y1 + self.stack.pop()
    self.y = y2 + self.stack.pop()
    self.x = x2
    if self.stack.len() == 1 {
      self.x += self.stack.pop()
    }
    self.builder.curve_to(x1, y1, x2, y2, self.x, self.y)
  }
}

///|
fn CharStringParser::parse_flex(self : CharStringParser) -> Unit raise CFFError {
  // dx1 dy1 dx2 dy2 dx3 dy3 dx4 dy4 dx5 dy5 dx6 dy6 fd
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() != 13 {
    raise InvalidArgumentsStackLength
  }
  let dx1 = self.x + self.stack.at(0)
  let dy1 = self.y + self.stack.at(1)
  let dx2 = dx1 + self.stack.at(2)
  let dy2 = dy1 + self.stack.at(3)
  let dx3 = dx2 + self.stack.at(4)
  let dy3 = dy2 + self.stack.at(5)
  let dx4 = dx3 + self.stack.at(6)
  let dy4 = dy3 + self.stack.at(7)
  let dx5 = dx4 + self.stack.at(8)
  let dy5 = dy4 + self.stack.at(9)
  self.x = dx5 + self.stack.at(10)
  self.y = dy5 + self.stack.at(11)
  self.builder.curve_to(dx1, dy1, dx2, dy2, dx3, dy3)
  self.builder.curve_to(dx4, dy4, dx5, dy5, self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_flex1(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dx1 dy1 dx2 dy2 dx3 dy3 dx4 dy4 dx5 dy5 d6
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() != 11 {
    raise InvalidArgumentsStackLength
  }
  let dx1 = self.x + self.stack.at(0)
  let dy1 = self.y + self.stack.at(1)
  let dx2 = dx1 + self.stack.at(2)
  let dy2 = dy1 + self.stack.at(3)
  let dx3 = dx2 + self.stack.at(4)
  let dy3 = dy2 + self.stack.at(5)
  let dx4 = dx3 + self.stack.at(6)
  let dy4 = dy3 + self.stack.at(7)
  let dx5 = dx4 + self.stack.at(8)
  let dy5 = dy4 + self.stack.at(9)
  if f32_abs(dx5 - self.x) > f32_abs(dy5 - self.y) {
    self.x = dx5 + self.stack.at(10)
  } else {
    self.y = dy5 + self.stack.at(10)
  }
  self.builder.curve_to(dx1, dy1, dx2, dy2, dx3, dy3)
  self.builder.curve_to(dx4, dy4, dx5, dy5, self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_hflex(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dx1 dx2 dy2 dx3 dx4 dx5 dx6
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() != 7 {
    raise InvalidArgumentsStackLength
  }
  let dx1 = self.x + self.stack.at(0)
  let dy1 = self.y
  let dx2 = dx1 + self.stack.at(1)
  let dy2 = dy1 + self.stack.at(2)
  let dx3 = dx2 + self.stack.at(3)
  let dy3 = dy2
  let dx4 = dx3 + self.stack.at(4)
  let dy4 = dy2
  let dx5 = dx4 + self.stack.at(5)
  let dy5 = self.y
  self.x = dx5 + self.stack.at(6)
  self.builder.curve_to(dx1, dy1, dx2, dy2, dx3, dy3)
  self.builder.curve_to(dx4, dy4, dx5, dy5, self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_hflex1(
  self : CharStringParser,
) -> Unit raise CFFError {
  // dx1 dy1 dx2 dy2 dx3 dx4 dx5 dy5 dx6
  if !self.has_move_to {
    raise MissingMoveTo
  }
  if self.stack.len() != 9 {
    raise InvalidArgumentsStackLength
  }
  let dx1 = self.x + self.stack.at(0)
  let dy1 = self.y + self.stack.at(1)
  let dx2 = dx1 + self.stack.at(2)
  let dy2 = dy1 + self.stack.at(3)
  let dx3 = dx2 + self.stack.at(4)
  let dy3 = dy2
  let dx4 = dx3 + self.stack.at(5)
  let dy4 = dy2
  let dx5 = dx4 + self.stack.at(6)
  let dy5 = dy4 + self.stack.at(7)
  self.x = dx5 + self.stack.at(8)
  self.builder.curve_to(dx1, dy1, dx2, dy2, dx3, dy3)
  self.builder.curve_to(dx4, dy4, dx5, dy5, self.x, self.y)
  self.stack.clear()
}

///|
fn CharStringParser::parse_int1(
  self : CharStringParser,
  op : Byte,
) -> Unit raise CFFError {
  let n = op.to_int() - 139
  self.stack.push(Float::from_int(n))
}

///|
fn CharStringParser::parse_int2(
  self : CharStringParser,
  op : Byte,
  s : Stream,
) -> Unit raise CFFError {
  let b1 = s.read_u8() catch { _ => raise ReadOutOfBounds }
  let n = (op.to_int() - 247) * 256 + b1.to_int() + 108
  self.stack.push(Float::from_int(n))
}

///|
fn CharStringParser::parse_int3(
  self : CharStringParser,
  op : Byte,
  s : Stream,
) -> Unit raise CFFError {
  let b1 = s.read_u8() catch { _ => raise ReadOutOfBounds }
  let n = -(op.to_int() - 251) * 256 - b1.to_int() - 108
  self.stack.push(Float::from_int(n))
}

///|
fn CharStringParser::parse_fixed(
  self : CharStringParser,
  s : Stream,
) -> Unit raise CFFError {
  let n : Fixed = s.read() catch { _ => raise ReadOutOfBounds }
  self.stack.push(n.0)
}
