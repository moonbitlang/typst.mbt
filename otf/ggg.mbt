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
/// Returns a [`RangeRecord`] for a glyph.
pub fn LazyArray16::range(
  self : LazyArray16[RangeRecord],
  glyph : GlyphId,
) -> RangeRecord? {
  self
  .binary_search_by(record => {
    if glyph < record.start {
      1
    } else if glyph <= record.end {
      0
    } else {
      -1
    }
  })
  .map(p => p.1)
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
    Format1(glyphs~) => glyphs.binary_search(glyph).map(p => p.0)
    Format2(records~) => {
      guard records.range(glyph) is Some(record) else { return None }
      let offset = glyph.0 - record.start.0
      u16_checked_add(record.value, offset)
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
    Format2(records~) => records.range(glyph).map(record => record.value)
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
extend Coverage with FromSlice::{parse_slice}
