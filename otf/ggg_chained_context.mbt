// Port of `ttf-parser` 0.25.1 `src/ggg/chained_context.rs`.

///|
/// A [Chained Contextual Lookup Subtable](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#chseqctxt1).
pub(all) enum ChainedContextLookup {
  /// Simple glyph contexts.
  Format1(coverage~ : Coverage, sets~ : ChainedSequenceRuleSets)
  /// Class-based glyph contexts.
  Format2(
    coverage~ : Coverage,
    backtrack_classes~ : ClassDefinition,
    input_classes~ : ClassDefinition,
    lookahead_classes~ : ClassDefinition,
    sets~ : ChainedSequenceRuleSets
  )
  /// Coverage-based glyph contexts.
  Format3(
    coverage~ : Coverage,
    backtrack_coverages~ : LazyOffsetArray16[Coverage],
    input_coverages~ : LazyOffsetArray16[Coverage],
    lookahead_coverages~ : LazyOffsetArray16[Coverage],
    lookups~ : LazyArray16[SequenceLookupRecord]
  )
}

///|
fn ChainedContextLookup::parse(
  data : BytesView,
) -> ChainedContextLookup raise Malformed {
  let s = Stream::new(data)
  match s.read_u16() {
    1 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      ChainedContextLookup::Format1(
        coverage~,
        sets=LazyOffsetArray16::new(data, offsets),
      )
    }
    2 => {
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let parse_func = () => {
        let offset : Offset16? = s.read()
        match offset {
          Some(offset) =>
            ClassDefinition::parse_r(slice_from_r(data, offset.to_usize()))
          None => ClassDefinition::Empty
        }
      }
      let backtrack_classes = parse_func()
      let input_classes = parse_func()
      let lookahead_classes = parse_func()
      let count = s.read_u16()
      let offsets = s.read_array16(count)
      ChainedContextLookup::Format2(
        coverage~,
        backtrack_classes~,
        input_classes~,
        lookahead_classes~,
        sets=LazyOffsetArray16::new(data, offsets),
      )
    }
    3 => {
      let backtrack_count = s.read_u16()
      let backtrack_coverages = s.read_array16(backtrack_count)
      let input_count = s.read_u16()
      let coverage = Coverage::parse_slice(s.read_at_offset16(data))
      let input_coverages = s.read_array16(req(u16_checked_sub(input_count, 1)))
      let lookahead_count = s.read_u16()
      let lookahead_coverages = s.read_array16(lookahead_count)
      let lookup_count = s.read_u16()
      let lookups = s.read_array16(lookup_count)
      ChainedContextLookup::Format3(
        coverage~,
        backtrack_coverages=LazyOffsetArray16::new(data, backtrack_coverages),
        input_coverages=LazyOffsetArray16::new(data, input_coverages),
        lookahead_coverages=LazyOffsetArray16::new(data, lookahead_coverages),
        lookups~,
      )
    }
    _ => raise Malformed
  }
}

///|
/// Returns the subtable coverage.
pub fn ChainedContextLookup::coverage(self : ChainedContextLookup) -> Coverage {
  match self {
    Format1(coverage~, ..) => coverage
    Format2(coverage~, ..) => coverage
    Format3(coverage~, ..) => coverage
  }
}

///|
/// A list of [`ChainedSequenceRule`] sets.
pub type ChainedSequenceRuleSets = LazyOffsetArray16[ChainedSequenceRuleSet]

///|
/// A set of [`ChainedSequenceRule`].
pub type ChainedSequenceRuleSet = LazyOffsetArray16[ChainedSequenceRule]

///|
/// A [Chained Sequence Rule](https://docs.microsoft.com/en-us/typography/opentype/spec/chapter2#chained-sequence-context-format-1-simple-glyph-contexts).
pub(all) struct ChainedSequenceRule {
  /// Contains either glyph IDs or glyph Classes.
  backtrack : LazyArray16[UInt16]
  input : LazyArray16[UInt16]
  /// Contains either glyph IDs or glyph Classes.
  lookahead : LazyArray16[UInt16]
  lookups : LazyArray16[SequenceLookupRecord]
}

///|
pub impl FromSlice for ChainedSequenceRule with fn parse_slice(data) {
  let s = Stream::new(data)
  let backtrack_count = s.read_u16()
  let backtrack = s.read_array16(backtrack_count)
  let input_count = s.read_u16()
  let input = s.read_array16(req(u16_checked_sub(input_count, 1)))
  let lookahead_count = s.read_u16()
  let lookahead = s.read_array16(lookahead_count)
  let lookup_count = s.read_u16()
  let lookups = s.read_array16(lookup_count)
  { backtrack, input, lookahead, lookups, }
}
