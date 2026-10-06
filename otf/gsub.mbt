// A [Glyph Substitution Table](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub)
// implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/gsub.rs`.

// A heavily modified port of https://github.com/harfbuzz/rustybuzz implementation
// originally written by https://github.com/laurmaedje

///|
/// A [Single Substitution Subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#SS).
pub(all) enum SingleSubstitution {
  Format1(coverage~ : Coverage, delta~ : Int16)
  Format2(coverage~ : Coverage, substitutes~ : LazyArray16[GlyphId])
}

///|
fn SingleSubstitution::parse(
  data : BytesView,
) -> SingleSubstitution raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let delta = s.read_i16()
      SingleSubstitution::Format1(coverage~, delta~)
    }
    2 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let substitutes = s.read_array16(count)
      SingleSubstitution::Format2(coverage~, substitutes~)
    }
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn SingleSubstitution::coverage(self : SingleSubstitution) -> Coverage {
  match self {
    Format1(coverage~, ..) => coverage
    Format2(coverage~, ..) => coverage
  }
}

///|
/// A sequence of glyphs for
/// [Multiple Substitution Subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#MS).
pub(all) struct Sequence {
  /// A list of substitute glyphs.
  substitutes : LazyArray16[GlyphId]
}

///|
pub impl FromSlice for Sequence with fn parse_slice(data) {
  let s = Stream::new(data)
  let count = s.read_u16()
  let substitutes = s.read_array16(count)
  { substitutes, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Sequence with FromSlice::{parse_slice}

///|
/// A list of [`Sequence`] tables.
pub type SequenceList = LazyOffsetArray16[Sequence]

///|
/// A [Multiple Substitution Subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#MS).
pub(all) struct MultipleSubstitution {
  coverage : Coverage
  sequences : SequenceList
}

///|
fn MultipleSubstitution::parse(
  data : BytesView,
) -> MultipleSubstitution raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      { coverage, sequences: LazyOffsetArray16::new(data, offsets), }
    }
    _ => raise Malformed
  }
}

///|
/// A list of glyphs for
/// [Alternate Substitution Subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#AS).
pub(all) struct AlternateSet {
  /// Array of alternate glyph IDs, in arbitrary order.
  alternates : LazyArray16[GlyphId]
}

///|
pub impl FromSlice for AlternateSet with fn parse_slice(data) {
  let s = Stream::new(data)
  let count = s.read_u16()
  let alternates = s.read_array16(count)
  { alternates, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AlternateSet with FromSlice::{parse_slice}

///|
/// A set of [`AlternateSet`].
pub type AlternateSets = LazyOffsetArray16[AlternateSet]

///|
/// A [Alternate Substitution Subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#AS).
pub(all) struct AlternateSubstitution {
  coverage : Coverage
  alternate_sets : AlternateSets
}

///|
fn AlternateSubstitution::parse(
  data : BytesView,
) -> AlternateSubstitution raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      { coverage, alternate_sets: LazyOffsetArray16::new(data, offsets), }
    }
    _ => raise Malformed
  }
}

///|
/// Glyph components for one ligature.
pub(all) struct Ligature {
  /// Ligature to substitute.
  glyph : GlyphId
  /// Glyph components for one ligature.
  components : LazyArray16[GlyphId]
}

///|
pub impl FromSlice for Ligature with fn parse_slice(data) {
  let s = Stream::new(data)
  let glyph : GlyphId = s.read()
  let count = s.read_u16()
  let components = s.read_array16(req(u16_checked_sub(count, 1)))
  { glyph, components, }
}

///|
#deprecated("call as `FromSlice::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Ligature with FromSlice::{parse_slice}

///|
/// A [`Ligature`] set.
pub type LigatureSet = LazyOffsetArray16[Ligature]

///|
/// A list of [`Ligature`] sets.
pub type LigatureSets = LazyOffsetArray16[LigatureSet]

///|
/// A [Ligature Substitution Subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#LS).
pub(all) struct LigatureSubstitution {
  coverage : Coverage
  ligature_sets : LigatureSets
}

///|
fn LigatureSubstitution::parse(
  data : BytesView,
) -> LigatureSubstitution raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      { coverage, ligature_sets: LazyOffsetArray16::new(data, offsets), }
    }
    _ => raise Malformed
  }
}

///|
/// A [Reverse Chaining Contextual Single Substitution Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#RCCS).
pub(all) struct ReverseChainSingleSubstitution {
  coverage : Coverage
  backtrack_coverages : LazyOffsetArray16[Coverage]
  lookahead_coverages : LazyOffsetArray16[Coverage]
  substitutes : LazyArray16[GlyphId]
}

///|
fn ReverseChainSingleSubstitution::parse(
  data : BytesView,
) -> ReverseChainSingleSubstitution raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let backtrack_count = s.read_u16()
      let backtrack_coverages = s.read_array16(backtrack_count)
      let lookahead_count = s.read_u16()
      let lookahead_coverages = s.read_array16(lookahead_count)
      let substitute_count = s.read_u16()
      let substitutes = s.read_array16(substitute_count)
      {
        coverage,
        backtrack_coverages: LazyOffsetArray16::new(data, backtrack_coverages),
        lookahead_coverages: LazyOffsetArray16::new(data, lookahead_coverages),
        substitutes,
      }
    }
    _ => raise Malformed
  }
}

///|
/// A glyph substitution
/// [lookup subtable](https://docs.microsoft.com/en-us/typography/opentype/spec/gsub#table-organization)
/// enumeration.
pub(all) enum SubstitutionSubtable {
  Single(SingleSubstitution)
  Multiple(MultipleSubstitution)
  Alternate(AlternateSubstitution)
  Ligature(LigatureSubstitution)
  Context(ContextLookup)
  ChainContext(ChainedContextLookup)
  ReverseChainSingle(ReverseChainSingleSubstitution)
}

///|
pub impl LookupSubtable for SubstitutionSubtable with fn parse(data, kind) {
  substitution_subtable_parse(data, kind)
}

///|
#deprecated("call as `LookupSubtable::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SubstitutionSubtable with LookupSubtable::{parse}

///|
fn substitution_subtable_parse(
  data : BytesView,
  kind : UInt16,
) -> SubstitutionSubtable raise Malformed {
  match kind {
    1 => Single(SingleSubstitution::parse(data))
    2 => Multiple(MultipleSubstitution::parse(data))
    3 => Alternate(AlternateSubstitution::parse(data))
    4 => SubstitutionSubtable::Ligature(LigatureSubstitution::parse(data))
    5 => SubstitutionSubtable::Context(ContextLookup::parse(data))
    6 => SubstitutionSubtable::ChainContext(ChainedContextLookup::parse(data))
    7 => parse_extension_lookup(data, substitution_subtable_parse)
    8 => ReverseChainSingle(ReverseChainSingleSubstitution::parse(data))
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn SubstitutionSubtable::coverage(self : SubstitutionSubtable) -> Coverage {
  match self {
    Single(t) => t.coverage()
    Multiple(t) => t.coverage
    Alternate(t) => t.coverage
    Ligature(t) => t.coverage
    Context(t) => t.coverage()
    ChainContext(t) => t.coverage()
    ReverseChainSingle(t) => t.coverage
  }
}

///|
/// Checks that the current subtable is *Reverse Chaining Contextual Single*.
pub fn SubstitutionSubtable::is_reverse(self : SubstitutionSubtable) -> Bool {
  self is ReverseChainSingle(_)
}
