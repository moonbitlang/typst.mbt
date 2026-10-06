// Common data types used by GDEF/GPOS/GSUB tables.
//
// <https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2>
//
// Port of `ttf-parser` 0.25.1 `src/ggg/mod.rs` (the `opentype_layout`
// module).

// A heavily modified port of https://github.com/harfbuzz/rustybuzz implementation
// originally written by https://github.com/laurmaedje

///|
/// A record that describes a range of glyph IDs.
pub(all) struct RangeRecord {
  /// First glyph ID in the range
  start : GlyphId
  /// Last glyph ID in the range
  end : GlyphId
  /// Coverage Index of first glyph ID in range.
  value : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RangeRecord with @debug.Debug::{to_repr}

///|
/// Returns a [`RangeRecord`] for a glyph.
pub fn LazyArray16::range(
  self : LazyArray16[RangeRecord],
  glyph : GlyphId,
) -> RangeRecord? {
  let at = range_record_at(self, glyph)
  if at < 0 {
    return None
  }
  let data = self.data
  Some({
    start: GlyphId(be_u16(data, at)),
    end: GlyphId(be_u16(data, at + 2)),
    value: be_u16(data, at + 4),
  })
}

///|
/// The byte offset of the [`RangeRecord`] containing `glyph` (see
/// [LazyArray16::range]), or `-1`. (Lets hot callers read the record's
/// fields without allocating it.)
fn range_record_at(records : LazyArray16[RangeRecord], glyph : GlyphId) -> Int {
  // `binary_search_by` specialized to compare the raw big-endian fields
  // instead of parsing a record for every probe (same probe sequence).
  let data = records.data
  let mut size = records.len().to_int()
  if size == 0 {
    return -1
  }
  let g = glyph.0.to_int()
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    let at = mid * 6
    let start = (data[at].to_int() << 8) | data[at + 1].to_int()
    let end = (data[at + 2].to_int() << 8) | data[at + 3].to_int()
    let cmp = if g < start { 1 } else if g <= end { 0 } else { -1 }
    base = if cmp > 0 { base } else { mid }
    size -= half
  }
  let at = base * 6
  let start = (data[at].to_int() << 8) | data[at + 1].to_int()
  let end = (data[at + 2].to_int() << 8) | data[at + 3].to_int()
  if g >= start && g <= end {
    at
  } else {
    -1
  }
}

///|
pub impl FromData for RangeRecord with fn size() {
  6
}

///|
pub impl FromData for RangeRecord with fn parse(data) {
  let s = Stream::new(data)
  { start: s.read(), end: s.read(), value: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend RangeRecord with FromData::{size, parse}

///|
/// A [Coverage Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#coverage-table).
pub(all) enum Coverage {
  /// `glyphs`: Array of glyph IDs. Sorted.
  Format1(glyphs~ : LazyArray16[GlyphId])
  /// `records`: Array of glyph ranges. Ordered by `RangeRecord.start`.
  Format2(records~ : LazyArray16[RangeRecord])
}

///|
pub impl FromSlice for Coverage with fn parse_slice(data) {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let count = s.read_u16()
      let glyphs = s.read_array16(count)
      Coverage::Format1(glyphs~)
    }
    2 => {
      let count = s.read_u16()
      let records = s.read_array16(count)
      Coverage::Format2(records~)
    }
    _ => raise Malformed
  }
}

///|
pub extend Coverage with FromSlice::{parse_slice}

///|
/// Parses a coverage table (`FromSlice::parse`).
pub fn Coverage::parse(data : BytesView) -> Coverage? {
  opt(() => Coverage::parse_slice(data))
}

///|
/// Checks that glyph is present.
pub fn Coverage::contains(self : Coverage, glyph : GlyphId) -> Bool {
  self.get(glyph) is Some(_)
}

///|
/// Returns the coverage index of the glyph or `None` if it is not covered.
pub fn Coverage::get(self : Coverage, glyph : GlyphId) -> UInt16? {
  match self {
    Format1(glyphs~) => {
      // `glyphs.binary_search(glyph).map(p => p.0)` specialized to compare
      // the raw big-endian glyph ids (same probe sequence, without the
      // closures and the result pair).
      let data = glyphs.data
      let mut size = glyphs.len().to_int()
      if size == 0 {
        return None
      }
      let g = glyph.0
      let mut base = 0
      while size > 1 {
        let half = size / 2
        let mid = base + half
        base = if be_u16(data, mid * 2) > g { base } else { mid }
        size -= half
      }
      if be_u16(data, base * 2) == g {
        Some(base.to_uint16())
      } else {
        None
      }
    }
    Format2(records~) => {
      let at = range_record_at(records, glyph)
      guard at >= 0 else { return None }
      let offset = glyph.0 - be_u16(records.data, at)
      u16_checked_add(be_u16(records.data, at + 4), offset)
    }
  }
}

///|
/// A value of [Class Definition Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#class-definition-table).
pub type Class = UInt16

///|
/// A [Class Definition Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#class-definition-table).
pub(all) enum ClassDefinition {
  Format1(start~ : GlyphId, classes~ : LazyArray16[Class])
  Format2(records~ : LazyArray16[RangeRecord])
  Empty
}

///|
/// Parses a class definition table.
pub fn ClassDefinition::parse(data : BytesView) -> ClassDefinition? {
  opt(() => ClassDefinition::parse_r(data))
}

///|
fn ClassDefinition::parse_r(
  data : BytesView,
) -> ClassDefinition raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let start : GlyphId = s.read()
      let count = s.read_u16()
      let classes = s.read_array16(count)
      ClassDefinition::Format1(start~, classes~)
    }
    2 => {
      let count = s.read_u16()
      let records = s.read_array16(count)
      ClassDefinition::Format2(records~)
    }
    _ => raise Malformed
  }
}

///|
/// Returns the glyph class of the glyph (zero if it is not defined).
pub fn ClassDefinition::get(self : ClassDefinition, glyph : GlyphId) -> Class {
  let r : Class? = match self {
    Format1(start~, classes~) =>
      match u16_checked_sub(glyph.0, start.0) {
        Some(index) => classes.get(index)
        None => None
      }
    Format2(records~) => {
      // `records.range(glyph).map(record => record.value)` without
      // allocating the record.
      let at = range_record_at(records, glyph)
      if at >= 0 {
        Some(be_u16(records.data, at + 4))
      } else {
        None
      }
    }
    Empty => Some(0)
  }
  r.unwrap_or(0)
}

///|
/// `FromSlice` for nested offset arrays (`SequenceRuleSet`,
/// `ChainedSequenceRuleSet`, `LigatureSet`, ...).
pub impl[T] FromSlice for LazyOffsetArray16[T] with fn parse_slice(data) {
  LazyOffsetArray16::parse(data)
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LazyOffsetArray16 with FromSlice::{parse_slice}
