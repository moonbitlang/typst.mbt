// A [Character to Glyph Index Mapping Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap) implementation.
//
// This module provides a low-level alternative to `Face::glyph_index` and
// `Face::glyph_variation_index` methods.

///|
/// A character encoding subtable variant.
pub(all) enum CmapFormat {
  ByteEncodingTable(CmapSubtable0)
  HighByteMappingThroughTable(CmapSubtable2)
  SegmentMappingToDeltaValues(CmapSubtable4)
  TrimmedTableMapping(CmapSubtable6)
  MixedCoverage // unsupported
  TrimmedArray(CmapSubtable10)
  SegmentedCoverage(CmapSubtable12)
  ManyToOneRangeMappings(CmapSubtable13)
  UnicodeVariationSequences(CmapSubtable14)
}

///|
/// A character encoding subtable.
pub(all) struct CmapSubtable {
  /// Subtable platform.
  platform_id : PlatformId
  /// Subtable encoding.
  encoding_id : UInt16
  /// A subtable format.
  format : CmapFormat
}

///|
/// Checks that the current encoding is Unicode compatible.
pub fn CmapSubtable::is_unicode(self : CmapSubtable) -> Bool {
  // https://docs.microsoft.com/en-us/typography/opentype/spec/name#windows-encoding-ids
  let windows_unicode_bmp_encoding_id : UInt16 = 1
  let windows_unicode_full_repertoire_encoding_id : UInt16 = 10
  match self.platform_id {
    Unicode => true
    Windows if self.encoding_id == windows_unicode_bmp_encoding_id => true
    Windows => {
      // "Note: Subtable format 13 has the same structure as format 12; it differs only
      // in the interpretation of the startGlyphID/glyphID fields".
      let is_format_12_compatible = self.format
        is (SegmentedCoverage(_) | ManyToOneRangeMappings(_))

      // "Fonts that support Unicode supplementary-plane characters (U+10000 to U+10FFFF)
      // on the Windows platform must have a format 12 subtable for platform ID 3,
      // encoding ID 10."
      self.encoding_id == windows_unicode_full_repertoire_encoding_id &&
      is_format_12_compatible
    }
    _ => false
  }
}

///|
/// Maps a character to a glyph ID.
///
/// This is a low-level method and unlike `Face::glyph_index` it doesn't
/// check that the current encoding is Unicode.
/// It simply maps a `u32` codepoint number to a glyph ID.
///
/// Returns `None`:
/// - when glyph ID is `0`.
/// - when format is `MixedCoverage`, since it's not supported.
/// - when format is `UnicodeVariationSequences`. Use `glyph_variation_index` instead.
pub fn CmapSubtable::glyph_index(
  self : CmapSubtable,
  code_point : UInt,
) -> GlyphId? {
  match self.format {
    ByteEncodingTable(subtable) => subtable.glyph_index(code_point)
    HighByteMappingThroughTable(subtable) => subtable.glyph_index(code_point)
    SegmentMappingToDeltaValues(subtable) => subtable.glyph_index(code_point)
    TrimmedTableMapping(subtable) => subtable.glyph_index(code_point)
    MixedCoverage => None
    TrimmedArray(subtable) => subtable.glyph_index(code_point)
    SegmentedCoverage(subtable) => subtable.glyph_index(code_point)
    ManyToOneRangeMappings(subtable) => subtable.glyph_index(code_point)
    // This subtable should be accessed via glyph_variation_index().
    UnicodeVariationSequences(_) => None
  }
}

///|
/// Resolves a variation of a glyph ID from two code points.
///
/// Returns `None`:
/// - when glyph ID is `0`.
/// - when format is not `UnicodeVariationSequences`.
pub fn CmapSubtable::glyph_variation_index(
  self : CmapSubtable,
  code_point : UInt,
  variation : UInt,
) -> GlyphVariationResult? {
  match self.format {
    UnicodeVariationSequences(subtable) =>
      subtable.glyph_index(code_point, variation)
    _ => None
  }
}

///|
/// Calls `f` for all codepoints contained in this subtable.
///
/// This is a low-level method and it doesn't check that the current
/// encoding is Unicode. It simply calls the function `f` for all `u32`
/// codepoints that are present in this subtable.
///
/// Note that this may list codepoints for which `glyph_index` still returns
/// `None` because this method finds all codepoints which were _defined_ in
/// this subtable. The subtable may still map them to glyph ID `0`.
///
/// Returns without doing anything:
/// - when format is `MixedCoverage`, since it's not supported.
/// - when format is `UnicodeVariationSequences`, since it's not supported.
pub fn CmapSubtable::codepoints(
  self : CmapSubtable,
  f : (UInt) -> Unit,
) -> Unit {
  match self.format {
    ByteEncodingTable(subtable) => subtable.codepoints(f)
    HighByteMappingThroughTable(subtable) => subtable.codepoints(f)
    SegmentMappingToDeltaValues(subtable) => subtable.codepoints(f)
    TrimmedTableMapping(subtable) => subtable.codepoints(f)
    MixedCoverage => () // unsupported
    TrimmedArray(subtable) => subtable.codepoints(f)
    SegmentedCoverage(subtable) => subtable.codepoints(f)
    ManyToOneRangeMappings(subtable) => subtable.codepoints(f)
    UnicodeVariationSequences(_) => () // unsupported
  }
}

///|
/// Calls `f(start, end)` for each inclusive range of codepoints defined in
/// this table, in the order of [CmapSubtable::codepoints] (not in ttf-parser:
/// formats 4, 12 and 13 report their segments and groups at once instead of
/// every codepoint; the others report single codepoints).
///
/// The segments and groups are read from the raw big-endian fields: font
/// discovery computes the coverage of every face of the system with this,
/// some two million groups, and a parsed value for each is most of its
/// time.
pub fn CmapSubtable::codepoint_ranges(
  self : CmapSubtable,
  f : (UInt, UInt) -> Unit,
) -> Unit {
  match self.format {
    SegmentMappingToDeltaValues(subtable) => {
      let starts = subtable.start_codes.data
      let ends = subtable.end_codes.data
      // (`zip`: as many as the shorter array has.)
      let n = if starts.length() < ends.length() {
        starts.length() / 2
      } else {
        ends.length() / 2
      }
      for i in 0..<n {
        let at = 2 * i
        let start = (starts[at].to_int() << 8) | starts[at + 1].to_int()
        let end = (ends[at].to_int() << 8) | ends[at + 1].to_int()
        // OxFFFF value is special and indicates codes end.
        if start == end && start == 0xFFFF {
          break
        }
        if start <= end {
          f(start.reinterpret_as_uint(), end.reinterpret_as_uint())
        }
      }
    }
    SegmentedCoverage(subtable) => group_ranges(subtable.groups, f)
    ManyToOneRangeMappings(subtable) => group_ranges(subtable.groups, f)
    _ => self.codepoints(c => f(c, c))
  }
}

///|
/// Calls `f(start, end)` for the codepoints of each group of a format 12 or
/// 13 subtable (`start..=end`: nothing if the start is after the end).
fn group_ranges(
  groups : LazyArray32[SequentialMapGroup],
  f : (UInt, UInt) -> Unit,
) -> Unit {
  let data = groups.data
  // Whole groups only, like `LazyArray32::len`.
  let n = data.length() / 12
  for i in 0..<n {
    let at = 12 * i
    let start = be_u32_int(data, at)
    let end = be_u32_int(data, at + 4)
    if start <= end {
      f(start, end)
    }
  }
}

///|
/// `be_u32` with the conversions that are compiled in place.
#inline
fn be_u32_int(data : BytesView, i : Int) -> UInt {
  ((data[i].to_int() << 24) |
  (data[i + 1].to_int() << 16) |
  (data[i + 2].to_int() << 8) |
  data[i + 3].to_int()).reinterpret_as_uint()
}

///|
priv struct EncodingRecord {
  platform_id : PlatformId
  encoding_id : UInt16
  offset : Offset32
}

///|
impl FromData for EncodingRecord with fn size() {
  8
}

///|
impl FromData for EncodingRecord with fn parse(data) {
  let s = Stream::new(data)
  { platform_id: s.read(), encoding_id: s.read(), offset: s.read(), }
}

///|
/// A list of subtables.
struct CmapSubtables {
  data : BytesView
  records : LazyArray16[EncodingRecord]
}

///|
pub impl Default for CmapSubtables with fn default() {
  { data: empty_data, records: LazyArray16::default(), }
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CmapSubtables with Default::{default}

///|
/// Returns a subtable at an index.
pub fn CmapSubtables::get(
  self : CmapSubtables,
  index : UInt16,
) -> CmapSubtable? {
  guard self.records.get(index) is Some(record) else { return None }
  guard slice_from(self.data, record.offset.to_usize()) is Some(data) else {
    return None
  }
  try {
    let format : UInt16 = Stream::read_at(data, 0)
    let format : CmapFormat = match format {
      0 => ByteEncodingTable(req(CmapSubtable0::parse(data)))
      2 => HighByteMappingThroughTable(req(CmapSubtable2::parse(data)))
      4 => SegmentMappingToDeltaValues(req(CmapSubtable4::parse(data)))
      6 => TrimmedTableMapping(req(CmapSubtable6::parse(data)))
      8 => MixedCoverage // unsupported
      10 => TrimmedArray(req(CmapSubtable10::parse(data)))
      12 => SegmentedCoverage(req(CmapSubtable12::parse(data)))
      13 => ManyToOneRangeMappings(req(CmapSubtable13::parse(data)))
      14 => UnicodeVariationSequences(req(CmapSubtable14::parse(data)))
      _ => return None
    }
    Some({
      platform_id: record.platform_id,
      encoding_id: record.encoding_id,
      format,
    })
  } catch {
    _ => None
  }
}

///|
/// The offset in the table of the subtable at an index (not in ttf-parser:
/// several encoding records of a table usually point to one subtable, and
/// whoever walks all subtables, like the coverage of a font, can tell).
pub fn CmapSubtables::offset(self : CmapSubtables, index : UInt16) -> UInt? {
  guard self.records.get(index) is Some(record) else { return None }
  Some(record.offset.0)
}

///|
/// Returns the number of subtables.
pub fn CmapSubtables::len(self : CmapSubtables) -> UInt16 {
  self.records.len()
}

///|
/// Checks if there are any subtables.
pub fn CmapSubtables::is_empty(self : CmapSubtables) -> Bool {
  self.records.is_empty()
}

///|
/// An iterator over subtables (stops at the first unparsable subtable, like
/// upstream).
pub fn CmapSubtables::iter(self : CmapSubtables) -> Iter[CmapSubtable] {
  let len = self.len()
  let mut index : UInt16 = 0
  Iter::new(fn() {
    if index < len {
      index += 1
      self.get(index - 1)
    } else {
      None
    }
  })
}

///|
/// A [Character to Glyph Index Mapping Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap).
pub struct CmapTable {
  /// A list of subtables.
  subtables : CmapSubtables
}

///|
/// Parses a table from raw data.
pub fn CmapTable::parse(data : BytesView) -> CmapTable? {
  let s = Stream::new(data)
  s.advance(2) // version
  try {
    let count = s.read_u16()
    let records = s.read_array16(count)
    Some({ subtables: { data, records, }, })
  } catch {
    _ => None
  }
}

// ---------------------------------------------------------------------------
// Format 0

///|
/// A [format 0](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-0-byte-encoding-table)
/// subtable.
pub struct CmapSubtable0 {
  /// Just a list of 256 8bit glyph IDs.
  glyph_ids : BytesView
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable0::parse(data : BytesView) -> CmapSubtable0? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(2) // length
  s.advance(2) // language
  let glyph_ids = s.read_bytes(256) catch { _ => return None }
  Some({ glyph_ids, })
}

///|
/// Returns a glyph index for a code point.
pub fn CmapSubtable0::glyph_index(
  self : CmapSubtable0,
  code_point : UInt,
) -> GlyphId? {
  if code_point >= self.glyph_ids.length().reinterpret_as_uint() {
    return None
  }
  let glyph_id = self.glyph_ids[code_point.reinterpret_as_int()]
  // Make sure that the glyph is not zero, the array always has 256 ids,
  // but some codepoints may be mapped to zero.
  if glyph_id != 0 {
    Some(GlyphId(u16_from_u8(glyph_id)))
  } else {
    None
  }
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable0::codepoints(
  self : CmapSubtable0,
  f : (UInt) -> Unit,
) -> Unit {
  for i in 0..<self.glyph_ids.length() {
    // In contrast to every other format, here we take a look at the glyph
    // id and check whether it is zero because otherwise this method would
    // always simply call `f` for `0..256` which would be kind of pointless
    // (this array always has length 256 even when the face has fewer glyphs).
    if self.glyph_ids[i] != 0 {
      f(i.reinterpret_as_uint())
    }
  }
}

// ---------------------------------------------------------------------------
// Format 2
//
// This table has a pretty complex parsing algorithm.
// A detailed explanation can be found here:
// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-2-high-byte-mapping-through-table
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6cmap.html
// https://github.com/fonttools/fonttools/blob/a360252709a3d65f899915db0a5bd753007fdbb7/Lib/fontTools/ttLib/tables/_c_m_a_p.py#L360

///|
pub struct SubHeaderRecord {
  first_code : UInt16
  entry_count : UInt16
  id_delta : Int16
  id_range_offset : UInt16
}

///|
pub impl FromData for SubHeaderRecord with fn size() {
  8
}

///|
pub impl FromData for SubHeaderRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    first_code: s.read(),
    entry_count: s.read(),
    id_delta: s.read(),
    id_range_offset: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SubHeaderRecord with FromData::{size, parse}

///|
/// A [format 2](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-2-high-byte-mapping-through-table)
/// subtable.
pub struct CmapSubtable2 {
  sub_header_keys : LazyArray16[UInt16]
  sub_headers_offset : Int
  sub_headers : LazyArray16[SubHeaderRecord]
  // The whole subtable data.
  data : BytesView
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable2::parse(data : BytesView) -> CmapSubtable2? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(2) // length
  s.advance(2) // language
  try {
    let sub_header_keys : LazyArray16[UInt16] = s.read_array16(256)
    // The maximum index in a sub_header_keys is a sub_headers count.
    let mut max : UInt16? = None
    for n in sub_header_keys.iter() {
      let v = n / 8
      max = match max {
        Some(m) if m >= v => Some(m)
        _ => Some(v)
      }
    }
    let sub_headers_count = req(max) + 1

    // Remember sub_headers offset before reading. Will be used later.
    let sub_headers_offset = s.offset()
    let sub_headers = s.read_array16(sub_headers_count)
    Some({ sub_header_keys, sub_headers_offset, sub_headers, data, })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
///
/// Returns `None` when `code_point` is larger than `u16`.
pub fn CmapSubtable2::glyph_index(
  self : CmapSubtable2,
  code_point : UInt,
) -> GlyphId? {
  // This subtable supports code points only in a u16 range.
  guard u16_try_from_u32(code_point) is Some(code_point) else { return None }
  let high_byte = code_point >> 8
  let low_byte = code_point & 0x00FF
  let i : UInt16 = if code_point < 0xff {
    // 'SubHeader 0 is special: it is used for single-byte character codes.'
    0
  } else {
    // 'Array that maps high bytes to subHeaders: value is subHeader index × 8.'
    guard self.sub_header_keys.get(high_byte) is Some(k) else { return None }
    k / 8
  }
  guard self.sub_headers.get(i) is Some(sub_header) else { return None }
  let first_code = sub_header.first_code
  guard u16_checked_add(first_code, sub_header.entry_count) is Some(range_end) else {
    return None
  }
  if low_byte < first_code || low_byte >= range_end {
    return None
  }

  // SubHeaderRecord::id_range_offset points to SubHeaderRecord::first_code
  // in the glyphIndexArray. So we have to advance to our code point.
  guard u16_checked_sub(low_byte, first_code) is Some(index_offset) else {
    return None
  }
  let index_offset = index_offset.to_int() * 2

  // 'The value of the idRangeOffset is the number of bytes
  // past the actual location of the idRangeOffset'.
  let offset = self.sub_headers_offset +
    // Advance to required subheader.
    8 * (i.to_int() + 1) -
    // Move back to idRangeOffset start.
    2 +
    // Use defined offset.
    sub_header.id_range_offset.to_int() +
    // Advance to required index in the glyphIndexArray.
    index_offset
  let glyph : UInt16 = Stream::read_at(self.data, offset) catch {
    _ => return None
  }
  if glyph == 0 {
    return None
  }
  match
    u16_try_from_int((glyph.to_int() + sub_header.id_delta.to_int()) % 65536) {
    Some(g) => Some(GlyphId(g))
    None => None
  }
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable2::codepoints(
  self : CmapSubtable2,
  f : (UInt) -> Unit,
) -> Unit {
  self.codepoints_inner(f) catch {
    _ => ()
  }
}

///|
fn CmapSubtable2::codepoints_inner(
  self : CmapSubtable2,
  f : (UInt) -> Unit,
) -> Unit raise Malformed {
  for first_byte_i in 0..<256 {
    let first_byte = first_byte_i.to_uint16()
    let i = self.sub_header_keys.get_r(first_byte) / 8
    let sub_header = self.sub_headers.get_r(i)
    let first_code = sub_header.first_code
    if i == 0 {
      // This is a single byte code.
      let range_end = req(u16_checked_add(first_code, sub_header.entry_count))
      if first_byte >= first_code && first_byte < range_end {
        f(first_byte.to_uint())
      }
    } else {
      // This is a two byte code.
      let base = req(u16_checked_add(first_code, first_byte << 8))
      for k in 0..<sub_header.entry_count.to_int() {
        let code_point = req(u16_checked_add(base, k.to_uint16()))
        f(code_point.to_uint())
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Format 4

///|
/// A [format 4](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-4-segment-mapping-to-delta-values)
/// subtable.
pub struct CmapSubtable4 {
  start_codes : LazyArray16[UInt16]
  end_codes : LazyArray16[UInt16]
  id_deltas : LazyArray16[Int16]
  id_range_offsets : LazyArray16[UInt16]
  id_range_offset_pos : Int
  // The whole subtable data.
  data : BytesView
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable4::parse(data : BytesView) -> CmapSubtable4? {
  let s = Stream::new(data)
  s.advance(6) // format + length + language
  try {
    let seg_count_x2 = s.read_u16()
    if seg_count_x2 < 2 {
      return None
    }
    let seg_count = seg_count_x2 / 2
    s.advance(6) // searchRange + entrySelector + rangeShift
    let end_codes = s.read_array16(seg_count)
    s.advance(2) // reservedPad
    let start_codes = s.read_array16(seg_count)
    let id_deltas = s.read_array16(seg_count)
    let id_range_offset_pos = s.offset()
    let id_range_offsets = s.read_array16(seg_count)
    Some({
      start_codes,
      end_codes,
      id_deltas,
      id_range_offsets,
      id_range_offset_pos,
      data,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
///
/// Returns `None` when `code_point` is larger than `u16`.
pub fn CmapSubtable4::glyph_index(
  self : CmapSubtable4,
  code_point : UInt,
) -> GlyphId? {
  // This subtable supports code points only in a u16 range.
  guard u16_try_from_u32(code_point) is Some(code_point) else { return None }

  // A custom binary search.
  let mut start : UInt16 = 0
  let mut end = self.start_codes.len()
  while end > start {
    let index = ((start.to_int() + end.to_int()) / 2).to_uint16()
    guard self.end_codes.get(index) is Some(end_value) else { return None }
    if end_value >= code_point {
      guard self.start_codes.get(index) is Some(start_value) else {
        return None
      }
      if start_value > code_point {
        end = index
      } else {
        guard self.id_range_offsets.get(index) is Some(id_range_offset) else {
          return None
        }
        guard self.id_deltas.get(index) is Some(id_delta) else { return None }
        if id_range_offset == 0 {
          return Some(GlyphId(code_point + i16_as_u16(id_delta)))
        } else if id_range_offset == 0xFFFF {
          // Some malformed fonts have 0xFFFF as the last offset,
          // which is invalid and should be ignored.
          return None
        }
        let delta = (code_point.to_int() - start_value.to_int()) * 2
        guard u16_try_from_int(delta) is Some(delta) else { return None }
        let id_range_offset_pos = (self.id_range_offset_pos + index.to_int() * 2).to_uint16()
        let pos = id_range_offset_pos + delta
        let pos = pos + id_range_offset
        let glyph_array_value : UInt16 = Stream::read_at(
          self.data,
          pos.to_int(),
        ) catch {
          _ => return None
        }

        // 0 indicates missing glyph.
        if glyph_array_value == 0 {
          return None
        }
        let glyph_id = u16_as_i16(glyph_array_value) + id_delta
        return match u16_try_from_int(glyph_id.to_int()) {
          Some(g) => Some(GlyphId(g))
          None => None
        }
      }
    } else {
      start = index + 1
    }
  }
  None
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable4::codepoints(
  self : CmapSubtable4,
  f : (UInt) -> Unit,
) -> Unit {
  let n = if self.start_codes.len() < self.end_codes.len() {
    self.start_codes.len()
  } else {
    self.end_codes.len()
  }
  for i in 0..<n.to_int() {
    let start = self.start_codes.get(i.to_uint16()).unwrap()
    let end = self.end_codes.get(i.to_uint16()).unwrap()
    // OxFFFF value is special and indicates codes end.
    if start == end && start == 0xFFFF {
      break
    }
    if start <= end {
      for code_point in start.to_int()..<=end.to_int() {
        f(code_point.reinterpret_as_uint())
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Format 6

///|
/// A [format 6](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-6-trimmed-table-mapping)
/// subtable.
pub struct CmapSubtable6 {
  /// First character code of subrange.
  first_code_point : UInt16
  /// Array of glyph indexes for character codes in the range.
  glyphs : LazyArray16[GlyphId]
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable6::parse(data : BytesView) -> CmapSubtable6? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(2) // length
  s.advance(2) // language
  try {
    let first_code_point = s.read_u16()
    let count = s.read_u16()
    let glyphs = s.read_array16(count)
    Some({ first_code_point, glyphs, })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
///
/// Returns `None` when `code_point` is larger than `u16`.
pub fn CmapSubtable6::glyph_index(
  self : CmapSubtable6,
  code_point : UInt,
) -> GlyphId? {
  // This subtable supports code points only in a u16 range.
  guard u16_try_from_u32(code_point) is Some(code_point) else { return None }
  guard u16_checked_sub(code_point, self.first_code_point) is Some(idx) else {
    return None
  }
  self.glyphs.get(idx)
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable6::codepoints(
  self : CmapSubtable6,
  f : (UInt) -> Unit,
) -> Unit {
  for i in 0..<self.glyphs.len().to_int() {
    if u16_checked_add(self.first_code_point, i.to_uint16()) is Some(code_point) {
      f(code_point.to_uint())
    }
  }
}

// ---------------------------------------------------------------------------
// Format 10

///|
/// A [format 10](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-10-trimmed-array)
/// subtable.
pub struct CmapSubtable10 {
  /// First character code covered.
  first_code_point : UInt
  /// Array of glyph indices for the character codes covered.
  glyphs : LazyArray32[GlyphId]
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable10::parse(data : BytesView) -> CmapSubtable10? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(2) // reserved
  s.advance(4) // length
  s.advance(4) // language
  try {
    let first_code_point = s.read_u32()
    let count = s.read_u32()
    let glyphs = s.read_array32(count)
    Some({ first_code_point, glyphs, })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
pub fn CmapSubtable10::glyph_index(
  self : CmapSubtable10,
  code_point : UInt,
) -> GlyphId? {
  guard u32_checked_sub(code_point, self.first_code_point) is Some(idx) else {
    return None
  }
  self.glyphs.get(idx)
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable10::codepoints(
  self : CmapSubtable10,
  f : (UInt) -> Unit,
) -> Unit {
  let mut i : UInt = 0
  while i < self.glyphs.len() {
    if u32_checked_add(self.first_code_point, i) is Some(code_point) {
      f(code_point)
    }
    i += 1
  }
}

// ---------------------------------------------------------------------------
// Format 12

///|
pub struct SequentialMapGroup {
  start_char_code : UInt
  end_char_code : UInt
  start_glyph_id : UInt
}

///|
pub impl FromData for SequentialMapGroup with fn size() {
  12
}

///|
pub impl FromData for SequentialMapGroup with fn parse(data) {
  let s = Stream::new(data)
  {
    start_char_code: s.read(),
    end_char_code: s.read(),
    start_glyph_id: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SequentialMapGroup with FromData::{size, parse}

///|
/// Calls `f` for each code point of a group (`start..=end`).
fn SequentialMapGroup::each_codepoint(
  self : SequentialMapGroup,
  f : (UInt) -> Unit,
) -> Unit {
  if self.start_char_code > self.end_char_code {
    return
  }
  let mut code_point = self.start_char_code
  while true {
    f(code_point)
    if code_point == self.end_char_code {
      break
    }
    code_point += 1
  }
}

///|
/// A [format 12](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-12-segmented-coverage)
/// subtable.
pub struct CmapSubtable12 {
  groups : LazyArray32[SequentialMapGroup]
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable12::parse(data : BytesView) -> CmapSubtable12? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(2) // reserved
  s.advance(4) // length
  s.advance(4) // language
  try {
    let count = s.read_u32()
    let groups = s.read_array32(count)
    Some({ groups, })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
pub fn CmapSubtable12::glyph_index(
  self : CmapSubtable12,
  code_point : UInt,
) -> GlyphId? {
  // `binary_search_by` specialized to compare the raw big-endian fields
  // instead of parsing a group for every probe (same probe sequence).
  let data = self.groups.data
  let mut size = self.groups.len()
  if size == 0 {
    return None
  }
  let mut base : UInt = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    let at = mid.reinterpret_as_int() * 12
    let cmp = if be_u32(data, at) > code_point {
      1
    } else if be_u32(data, at + 4) < code_point {
      -1
    } else {
      0
    }
    base = if cmp > 0 { base } else { mid }
    size -= half
  }
  let at = base.reinterpret_as_int() * 12
  let start_char_code = be_u32(data, at)
  if start_char_code > code_point || be_u32(data, at + 4) < code_point {
    return None
  }
  let start_glyph_id = be_u32(data, at + 8)
  guard u32_checked_add(start_glyph_id, code_point) is Some(id) else {
    return None
  }
  guard u32_checked_sub(id, start_char_code) is Some(id) else { return None }
  match u16_try_from_u32(id) {
    Some(g) => Some(GlyphId(g))
    None => None
  }
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable12::codepoints(
  self : CmapSubtable12,
  f : (UInt) -> Unit,
) -> Unit {
  for group in self.groups.iter() {
    group.each_codepoint(f)
  }
}

// ---------------------------------------------------------------------------
// Format 13
//
// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-13-many-to-one-range-mappings

///|
/// A [format 13](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-13-segmented-coverage)
/// subtable.
pub struct CmapSubtable13 {
  groups : LazyArray32[SequentialMapGroup]
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable13::parse(data : BytesView) -> CmapSubtable13? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(2) // reserved
  s.advance(4) // length
  s.advance(4) // language
  try {
    let count = s.read_u32()
    let groups = s.read_array32(count)
    Some({ groups, })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
pub fn CmapSubtable13::glyph_index(
  self : CmapSubtable13,
  code_point : UInt,
) -> GlyphId? {
  for group in self.groups.iter() {
    let start_char_code = group.start_char_code
    if code_point >= start_char_code && code_point <= group.end_char_code {
      return match u16_try_from_u32(group.start_glyph_id) {
        Some(g) => Some(GlyphId(g))
        None => None
      }
    }
  }
  None
}

///|
/// Calls `f` for each codepoint defined in this table.
pub fn CmapSubtable13::codepoints(
  self : CmapSubtable13,
  f : (UInt) -> Unit,
) -> Unit {
  for group in self.groups.iter() {
    group.each_codepoint(f)
  }
}

// ---------------------------------------------------------------------------
// Format 14

///|
pub struct VariationSelectorRecord {
  var_selector : UInt
  default_uvs_offset : Offset32?
  non_default_uvs_offset : Offset32?
}

///|
pub impl FromData for VariationSelectorRecord with fn size() {
  11
}

///|
pub impl FromData for VariationSelectorRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    var_selector: (s.read() : U24).0,
    default_uvs_offset: s.read(),
    non_default_uvs_offset: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VariationSelectorRecord with FromData::{size, parse}

///|
pub struct UVSMappingRecord {
  unicode_value : UInt
  glyph_id : GlyphId
}

///|
pub impl FromData for UVSMappingRecord with fn size() {
  5
}

///|
pub impl FromData for UVSMappingRecord with fn parse(data) {
  let s = Stream::new(data)
  { unicode_value: (s.read() : U24).0, glyph_id: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UVSMappingRecord with FromData::{size, parse}

///|
pub struct UnicodeRangeRecord {
  start_unicode_value : UInt
  additional_count : Byte
}

///|
fn UnicodeRangeRecord::contains(self : UnicodeRangeRecord, c : UInt) -> Bool {
  // Never overflows, since `start_unicode_value` is actually u24.
  let end = self.start_unicode_value + self.additional_count.to_uint()
  c >= self.start_unicode_value && c <= end
}

///|
pub impl FromData for UnicodeRangeRecord with fn size() {
  4
}

///|
pub impl FromData for UnicodeRangeRecord with fn parse(data) {
  let s = Stream::new(data)
  { start_unicode_value: (s.read() : U24).0, additional_count: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UnicodeRangeRecord with FromData::{size, parse}

///|
/// A result of a variation glyph mapping.
pub(all) enum GlyphVariationResult {
  /// Glyph was found in the variation encoding table.
  Found(GlyphId)
  /// Glyph should be looked in other, non-variation tables.
  ///
  /// Basically, you should use `Encoding::glyph_index` or `Face::glyph_index`
  /// in this case.
  UseDefault
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphVariationResult with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphVariationResult with @debug.Debug::{to_repr}

///|
/// A [format 14](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#format-14-unicode-variation-sequences)
/// subtable.
pub struct CmapSubtable14 {
  records : LazyArray32[VariationSelectorRecord]
  // The whole subtable data.
  data : BytesView
}

///|
/// Parses a subtable from raw data.
pub fn CmapSubtable14::parse(data : BytesView) -> CmapSubtable14? {
  let s = Stream::new(data)
  s.advance(2) // format
  s.advance(4) // length
  try {
    let count = s.read_u32()
    let records = s.read_array32(count)
    Some({ records, data, })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph index for a code point.
pub fn CmapSubtable14::glyph_index(
  self : CmapSubtable14,
  code_point : UInt,
  variation : UInt,
) -> GlyphVariationResult? {
  guard self.records.binary_search_by(v => v.var_selector.compare(variation))
    is Some((_, record)) else {
    return None
  }
  try {
    if record.default_uvs_offset is Some(offset) {
      let data = slice_from_r(self.data, offset.to_usize())
      let s = Stream::new(data)
      let count = s.read_u32()
      let ranges : LazyArray32[UnicodeRangeRecord] = s.read_array32(count)
      for range in ranges.iter() {
        if range.contains(code_point) {
          return Some(UseDefault)
        }
      }
    }
    if record.non_default_uvs_offset is Some(offset) {
      let data = slice_from_r(self.data, offset.to_usize())
      let s = Stream::new(data)
      let count = s.read_u32()
      let uvs_mappings : LazyArray32[UVSMappingRecord] = s.read_array32(count)
      let (_, mapping) = req(
        uvs_mappings.binary_search_by(v => v.unicode_value.compare(code_point)),
      )
      return Some(Found(mapping.glyph_id))
    }
    None
  } catch {
    _ => None
  }
}
