// Port of read-fonts 0.39.2 `src/tables/cmap.rs` and `generated_cmap.rs`
// (subtable parsing for all formats, codepoint mapping for formats 0, 4, 6,
// 10, 12 and 13 like upstream).

///|
/// Platform identifiers.
pub(all) enum PlatformId {
  Unicode
  Macintosh
  ISO
  Windows
  Custom
  Unknown
} derive(Eq, Debug)

///|
pub fn PlatformId::new(raw : Int) -> PlatformId {
  match raw {
    0 => Unicode
    1 => Macintosh
    2 => ISO
    3 => Windows
    4 => Custom
    _ => Unknown
  }
}

///|
/// The [cmap](https://docs.microsoft.com/en-us/typography/opentype/spec/cmap) table.
pub struct Cmap {
  data : FontData
}

///|
pub fn FontRef::cmap(self : FontRef) -> Cmap raise ReadError {
  let data = self.expect_data_for_tag("cmap")
  if data.len() < 4 {
    raise OutOfBounds
  }
  { data, }
}

///|
pub fn Cmap::offset_data(self : Cmap) -> FontData {
  self.data
}

///|
/// An encoding record.
pub(all) struct EncodingRecord {
  platform : Int
  encoding : Int
  subtable_offset : UInt
} derive(Debug)

///|
pub fn EncodingRecord::platform_id(self : EncodingRecord) -> PlatformId {
  PlatformId::new(self.platform)
}

///|
pub fn EncodingRecord::encoding_id(self : EncodingRecord) -> Int {
  self.encoding
}

///|
/// The subtable for this encoding.
pub fn EncodingRecord::subtable(
  self : EncodingRecord,
  data : FontData,
) -> CmapSubtable raise ReadError {
  if self.subtable_offset == 0U {
    raise NullOffset
  }
  if self.subtable_offset > data.len().reinterpret_as_uint() {
    raise OutOfBounds
  }
  CmapSubtable::read(
    data.split_off(self.subtable_offset.reinterpret_as_int()).unwrap(),
  )
}

///|
pub fn EncodingRecord::is_symbol(self : EncodingRecord) -> Bool {
  self.platform_id() == Windows && self.encoding == 0
}

///|
pub fn EncodingRecord::is_mac_roman(self : EncodingRecord) -> Bool {
  self.platform_id() == Macintosh && self.encoding == 0
}

///|
pub fn Cmap::encoding_records(self : Cmap) -> Array[EncodingRecord] {
  let num_tables = u16_at(self.data, 2)
  let recs = self.data.read_array(4, num_tables, 8) catch {
    _ => FontData::empty()
  }
  [
    for i in 0..<(recs.len() / 8) => {
      EncodingRecord::{
        platform: u16_at(recs, i * 8),
        encoding: u16_at(recs, i * 8 + 2),
        subtable_offset: u32_at(recs, i * 8 + 4),
      }
    }
  ]
}

///|
/// Map a codepoint to a nominal glyph identifier.
///
/// This uses the first available subtable that provides a valid mapping.
pub fn Cmap::map_codepoint(self : Cmap, codepoint : UInt) -> GlyphId? {
  for record in self.encoding_records() {
    let subtable = record.subtable(self.data) catch { _ => continue }
    if subtable.map_codepoint(codepoint) is Some(gid) {
      return Some(gid)
    }
  }
  None
}

///|
/// Returns the subtable at the given index.
pub fn Cmap::subtable(self : Cmap, index : Int) -> CmapSubtable raise ReadError {
  let records = self.encoding_records()
  if index < 0 || index >= records.length() {
    raise OutOfBounds
  }
  records[index].subtable(self.data)
}

///|
/// A cmap subtable. The payload is the subtable data.
pub enum CmapSubtable {
  Format0(FontData)
  Format2(FontData)
  Format4(FontData)
  Format6(FontData)
  Format8(FontData)
  Format10(FontData)
  Format12(FontData)
  Format13(FontData)
  Format14(FontData)
}

///|
fn CmapSubtable::read(data : FontData) -> CmapSubtable raise ReadError {
  let format = data.read_u16(0)
  let check = fn(min : Int) raise ReadError {
    if data.len() < min {
      raise OutOfBounds
    }
  }
  match format {
    0 => {
      check(262)
      Format0(data)
    }
    2 => {
      check(518)
      Format2(data)
    }
    4 => {
      check(16)
      Format4(data)
    }
    6 => {
      check(10)
      Format6(data)
    }
    8 => {
      check(8208)
      Format8(data)
    }
    10 => {
      check(20)
      Format10(data)
    }
    12 => {
      check(16)
      Format12(data)
    }
    13 => {
      check(16)
      Format13(data)
    }
    14 => {
      check(10)
      Format14(data)
    }
    other => raise InvalidFormat(other.to_int64())
  }
}

///|
pub fn CmapSubtable::format(self : CmapSubtable) -> Int {
  match self {
    Format0(d)
    | Format2(d)
    | Format4(d)
    | Format6(d)
    | Format8(d)
    | Format10(d)
    | Format12(d)
    | Format13(d)
    | Format14(d) => u16_at(d, 0)
  }
}

///|
/// Attempts to map the given codepoint to a nominal glyph identifier using
/// the underlying subtable.
pub fn CmapSubtable::map_codepoint(
  self : CmapSubtable,
  codepoint : UInt,
) -> GlyphId? {
  match self {
    Format0(d) =>
      if codepoint < 256U {
        Some(
          GlyphId::new(
            d.as_bytes()[6 + codepoint.reinterpret_as_int()].to_uint(),
          ),
        )
      } else {
        None
      }
    Format4(d) => cmap4_map_codepoint(d, codepoint)
    Format6(d) => {
      let first = u16_at(d, 6).reinterpret_as_uint()
      if codepoint < first {
        return None
      }
      let idx = codepoint - first
      let entry_count = u16_at(d, 8)
      let arr = d.read_array(10, entry_count, 2) catch {
        _ => FontData::empty()
      }
      if idx < (arr.len() / 2).reinterpret_as_uint() {
        Some(GlyphId::from_int(u16_at(arr, idx.reinterpret_as_int() * 2)))
      } else {
        None
      }
    }
    Format10(d) => {
      let start = u32_at(d, 12)
      if codepoint < start {
        return None
      }
      let idx = codepoint - start
      let num_chars = u32_at(d, 16)
      let arr = if num_chars > 0x3FFFFFFFU {
        FontData::empty()
      } else {
        d.read_array(20, num_chars.reinterpret_as_int(), 2) catch {
          _ => FontData::empty()
        }
      }
      if idx < (arr.len() / 2).reinterpret_as_uint() {
        Some(GlyphId::from_int(u16_at(arr, idx.reinterpret_as_int() * 2)))
      } else {
        None
      }
    }
    Format12(d) => cmap1213_map_codepoint(d, codepoint, false)
    Format13(d) => cmap1213_map_codepoint(d, codepoint, true)
    _ => None
  }
}

///|
/// The cmap4 arrays: (seg_count_x2, end_code, start_code, id_delta,
/// id_range_offsets, glyph_id_array).
fn cmap4_arrays(
  d : FontData,
) -> (Int, FontData, FontData, FontData, FontData, FontData) {
  let seg_count_x2 = u16_at(d, 6)
  let n = seg_count_x2 / 2
  let arr = fn(start : Int) {
    d.read_array(start, n, 2) catch {
      _ => FontData::empty()
    }
  }
  let end_code = arr(14)
  let start_code = arr(14 + n * 2 + 2)
  let id_delta = arr(14 + n * 4 + 2)
  let id_range_offsets = arr(14 + n * 6 + 2)
  let ga_start = 14 + n * 8 + 2
  let ga_len = d.len() - ga_start
  let ga_len = if ga_len < 0 { 0 } else { ga_len / 2 }
  let glyph_id_array = d.read_array(ga_start, ga_len, 2) catch {
    _ => FontData::empty()
  }
  (
    seg_count_x2, end_code, start_code, id_delta, id_range_offsets, glyph_id_array,
  )
}

///|
fn cmap4_map_codepoint(d : FontData, codepoint : UInt) -> GlyphId? {
  if codepoint > 0xFFFFU {
    return None
  }
  let codepoint = codepoint.reinterpret_as_int()
  let (seg_count_x2, end_codes, start_codes, deltas, range_offsets, glyph_ids) = cmap4_arrays(
    d,
  )
  let mut lo = 0
  let mut hi = seg_count_x2 / 2
  while lo < hi {
    let i = (lo + hi) / 2
    if i >= start_codes.len() / 2 {
      return None
    }
    let start_code = u16_at(start_codes, i * 2)
    if codepoint < start_code {
      hi = i
    } else {
      if i >= end_codes.len() / 2 {
        return None
      }
      if codepoint > u16_at(end_codes, i * 2) {
        lo = i + 1
      } else {
        // lookup_glyph_id
        if i >= deltas.len() / 2 {
          return None
        }
        let delta = i16_at(deltas, i * 2)
        let num_range_offsets = range_offsets.len() / 2
        if i >= num_range_offsets {
          return None
        }
        let range_offset = u16_at(range_offsets, i * 2)
        if range_offset == 0 {
          return Some(GlyphId::from_int((codepoint + delta) & 0xFFFF))
        }
        let mut offset = range_offset / 2 + (codepoint - start_code)
        let sub = num_range_offsets - i
        offset = if offset > sub { offset - sub } else { 0 }
        if offset >= glyph_ids.len() / 2 {
          return None
        }
        let gid = u16_at(glyph_ids, offset * 2)
        return if gid != 0 {
          Some(GlyphId::from_int((gid + delta) & 0xFFFF))
        } else {
          None
        }
      }
    }
  }
  None
}

///|
fn cmap1213_map_codepoint(
  d : FontData,
  codepoint : UInt,
  is_constant : Bool,
) -> GlyphId? {
  let num_groups = u32_at(d, 12)
  let groups = if num_groups > 0x0AAAAAAAU {
    FontData::empty()
  } else {
    d.read_array(16, num_groups.reinterpret_as_int(), 12) catch {
      _ => FontData::empty()
    }
  }
  let mut lo = 0
  let mut hi = groups.len() / 12
  while lo < hi {
    let i = (lo + hi) / 2
    let start = u32_at(groups, i * 12)
    let end = u32_at(groups, i * 12 + 4)
    let ref_glyph = u32_at(groups, i * 12 + 8)
    if codepoint < start {
      hi = i
    } else if codepoint > end {
      lo = i + 1
    } else if is_constant {
      return Some(GlyphId::new(ref_glyph))
    } else {
      return Some(GlyphId::new(ref_glyph + (codepoint - start)))
    }
  }
  None
}
