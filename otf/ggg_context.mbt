// Port of `ttf-parser` 0.25.1 `src/ggg/context.rs`.

///|
/// A [Contextual Lookup Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#seqctxt1).
pub(all) enum ContextLookup {
  /// Simple glyph contexts.
  Format1(coverage~ : Coverage, sets~ : SequenceRuleSets)
  /// Class-based glyph contexts.
  Format2(
    coverage~ : Coverage,
    classes~ : ClassDefinition,
    sets~ : SequenceRuleSets
  )
  /// Coverage-based glyph contexts.
  Format3(
    coverage~ : Coverage,
    coverages~ : LazyOffsetArray16[Coverage],
    lookups~ : LazyArray16[SequenceLookupRecord]
  )
}

///|
fn ContextLookup::parse(data : BytesView) -> ContextLookup raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      ContextLookup::Format1(
        coverage~,
        sets=LazyOffsetArray16::new(data, offsets),
      )
    }
    2 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let classes = ClassDefinition::parse_r(s.read_at_offset16(data))
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      ContextLookup::Format2(
        coverage~,
        classes~,
        sets=LazyOffsetArray16::new(data, offsets),
      )
    }
    3 => {
      let input_count = s.read_u16()
      let lookup_count = s.read_u16()
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let coverages = s.read_array16(req(u16_checked_sub(input_count, 1)))
      let lookups = s.read_array16(lookup_count)
      ContextLookup::Format3(
        coverage~,
        coverages=LazyOffsetArray16::new(data, coverages),
        lookups~,
      )
    }
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn ContextLookup::coverage(self : ContextLookup) -> Coverage {
  match self {
    Format1(coverage~, ..) => coverage
    Format2(coverage~, ..) => coverage
    Format3(coverage~, ..) => coverage
  }
}

///|
/// A list of [`SequenceRuleSet`]s.
pub type SequenceRuleSets = LazyOffsetArray16[SequenceRuleSet]

///|
pub impl FromSlice for SequenceRule with fn parse_slice(data) {
  let s = Stream::new(data)
  let input_count = s.read_u16()
  let lookup_count = s.read_u16()
  let input = s.read_array16(req(u16_checked_sub(input_count, 1)))
  let lookups = s.read_array16(lookup_count)
  { input, lookups, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SequenceRule with FromSlice::{parse_slice}

///|
/// A set of [`SequenceRule`]s.
pub type SequenceRuleSet = LazyOffsetArray16[SequenceRule]

///|
/// A sequence rule.
pub(all) struct SequenceRule {
  input : LazyArray16[UInt16]
  lookups : LazyArray16[SequenceLookupRecord]
}

///|
/// A sequence rule record.
pub(all) struct SequenceLookupRecord {
  sequence_index : UInt16
  lookup_list_index : LookupIndex
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SequenceLookupRecord with @debug.Debug::{to_repr}

///|
pub impl FromData for SequenceLookupRecord with fn size() {
  4
}

///|
pub impl FromData for SequenceLookupRecord with fn parse(data) {
  let s = Stream::new(data)
  { sequence_index: s.read(), lookup_list_index: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SequenceLookupRecord with FromData::{size, parse}
