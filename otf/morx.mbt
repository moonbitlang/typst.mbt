// An [Extended Glyph Metamorphosis Table](
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6morx.html) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/morx.rs`. Public types get a `Morx`
// prefix (`morx::Chain` -> `MorxChain`, ...).

// Note: We do not have tests for this table because it has a very complicated structure.
// Specifically, the State Machine Tables. I have no idea how to generate them.
// And all fonts that use this table are mainly Apple one, so we cannot use them for legal reasons.
//
// On the other hand, this table is tested indirectly by https://github.com/harfbuzz/rustybuzz
// And it has like 170 tests. Which is pretty good.
// Therefore after applying any changes to this table,
// you have to check that all rustybuzz tests are still passing.

///|
/// The feature table is used to compute the sub-feature flags
/// for a list of requested features and settings.
pub(all) struct MorxFeature {
  /// The type of feature.
  kind : UInt16
  /// The feature's setting (aka selector).
  setting : UInt16
  /// Flags for the settings that this feature and setting enables.
  enable_flags : UInt
  /// Complement of flags for the settings that this feature and setting disable.
  disable_flags : UInt
} derive(Debug)

///|
pub impl FromData for MorxFeature with fn size() {
  12
}

///|
pub impl FromData for MorxFeature with fn parse(data) {
  let s = Stream::new(data)
  {
    kind: s.read(),
    setting: s.read(),
    enable_flags: s.read(),
    disable_flags: s.read(),
  }
}

///|
/// A contextual subtable state table trailing data.
pub(all) struct MorxContextualEntryData {
  /// A mark index.
  mark_index : UInt16
  /// A current index.
  current_index : UInt16
} derive(Debug)

///|
pub impl FromData for MorxContextualEntryData with fn size() {
  4
}

///|
pub impl FromData for MorxContextualEntryData with fn parse(data) {
  let s = Stream::new(data)
  { mark_index: s.read(), current_index: s.read(), }
}

///|
/// A contextual subtable.
pub struct MorxContextualSubtable {
  /// The contextual glyph substitution state table.
  state : ExtendedStateTable[MorxContextualEntryData]
  offsets_data : BytesView
  offsets : LazyArray32[Offset32]
  number_of_glyphs : UInt16
}

///|
fn MorxContextualSubtable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> MorxContextualSubtable raise Malformed {
  let s = Stream::new(data)
  let state = req(ExtendedStateTable::parse(number_of_glyphs, s))

  // While the spec clearly states that this is an
  // 'offset from the beginning of the state subtable',
  // it's actually not. Subtable header should not be included.
  let offset = (s.read() : Offset32).to_usize()

  // The offsets list is unsized.
  let offsets_data = slice_from_r(data, offset)
  let offsets = LazyArray32::new(offsets_data)
  { state, offsets_data, offsets, number_of_glyphs, }
}

///|
/// Returns a [Lookup](AatLookup) at index.
pub fn MorxContextualSubtable::lookup(
  self : MorxContextualSubtable,
  index : UInt,
) -> AatLookup? {
  guard self.offsets.get(index) is Some(offset) else { return None }
  guard slice_from(self.offsets_data, offset.to_usize()) is Some(lookup_data) else {
    return None
  }
  AatLookup::parse(self.number_of_glyphs, lookup_data)
}

///|
/// A ligature subtable.
pub struct MorxLigatureSubtable {
  /// A state table.
  state : ExtendedStateTable[UInt16]
  /// Ligature actions.
  ligature_actions : LazyArray32[UInt]
  /// Ligature components.
  components : LazyArray32[UInt16]
  /// Ligatures.
  ligatures : LazyArray32[GlyphId]
}

///|
fn MorxLigatureSubtable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> MorxLigatureSubtable raise Malformed {
  let s = Stream::new(data)
  let state = req(ExtendedStateTable::parse(number_of_glyphs, s))

  // Offset are from `ExtendedStateTable`/`data`, not from subtable start.
  let ligature_action_offset = (s.read() : Offset32).to_usize()
  let component_offset = (s.read() : Offset32).to_usize()
  let ligature_offset = (s.read() : Offset32).to_usize()

  // All three arrays are unsized, so we're simply reading/mapping all the data past offset.
  let ligature_actions = LazyArray32::new(
    slice_from_r(data, ligature_action_offset),
  )
  let components = LazyArray32::new(slice_from_r(data, component_offset))
  let ligatures = LazyArray32::new(slice_from_r(data, ligature_offset))
  { state, ligature_actions, components, ligatures, }
}

///|
/// A contextual subtable state table trailing data.
pub(all) struct MorxInsertionEntryData {
  /// A current insert index.
  current_insert_index : UInt16
  /// A marked insert index.
  marked_insert_index : UInt16
} derive(Debug)

///|
pub impl FromData for MorxInsertionEntryData with fn size() {
  4
}

///|
pub impl FromData for MorxInsertionEntryData with fn parse(data) {
  let s = Stream::new(data)
  { current_insert_index: s.read(), marked_insert_index: s.read(), }
}

///|
/// An insertion subtable.
pub struct MorxInsertionSubtable {
  /// A state table.
  state : ExtendedStateTable[MorxInsertionEntryData]
  /// Insertion glyphs.
  glyphs : LazyArray32[GlyphId]
}

///|
fn MorxInsertionSubtable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> MorxInsertionSubtable raise Malformed {
  let s = Stream::new(data)
  let state = req(ExtendedStateTable::parse(number_of_glyphs, s))
  let offset = (s.read() : Offset32).to_usize()

  // TODO: unsized array?
  // The list is unsized.
  let glyphs = LazyArray32::new(slice_from_r(data, offset))
  { state, glyphs, }
}

///|
/// A subtable kind.
pub(all) enum MorxSubtableKind {
  Rearrangement(ExtendedStateTable[Unit])
  Contextual(MorxContextualSubtable)
  Ligature(MorxLigatureSubtable)
  NonContextual(AatLookup)
  Insertion(MorxInsertionSubtable)
}

///|
/// A subtable coverage.
pub(all) struct MorxCoverage(Byte) derive(Debug)

///|
/// If true, this subtable will process glyphs in logical order
/// (or reverse logical order if [`is_vertical`](Self::is_vertical) is also true).
pub fn MorxCoverage::is_logical(self : MorxCoverage) -> Bool {
  (self.0 & 0x10) != 0
}

///|
/// If true, this subtable will be applied to both horizontal and vertical text
/// ([`is_vertical`](Self::is_vertical) should be ignored).
pub fn MorxCoverage::is_all_directions(self : MorxCoverage) -> Bool {
  (self.0 & 0x20) != 0
}

///|
/// If true, this subtable will process glyphs in descending order.
pub fn MorxCoverage::is_backwards(self : MorxCoverage) -> Bool {
  (self.0 & 0x40) != 0
}

///|
/// If true, this subtable will only be applied to vertical text.
pub fn MorxCoverage::is_vertical(self : MorxCoverage) -> Bool {
  (self.0 & 0x80) != 0
}

///|
/// A subtable in a metamorphosis chain.
pub(all) struct MorxSubtable {
  /// A subtable kind.
  kind : MorxSubtableKind
  /// A subtable coverage.
  coverage : MorxCoverage
  /// Subtable feature flags.
  feature_flags : UInt
}

///|
/// A list of subtables in a metamorphosis chain.
///
/// The internal data layout is not designed for random access,
/// therefore we're not providing the `get()` method and only an iterator.
struct MorxSubtables {
  count : UInt
  data : BytesView
  number_of_glyphs : UInt16
}

///|
/// Returns an iterator over the subtables.
pub fn MorxSubtables::into_iter(self : MorxSubtables) -> MorxSubtablesIter {
  {
    index: 0,
    count: self.count,
    stream: Stream::new(self.data),
    number_of_glyphs: self.number_of_glyphs,
  }
}

///|
/// Iterates over the subtables.
pub fn MorxSubtables::iter(self : MorxSubtables) -> Iter[MorxSubtable] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over a metamorphosis chain subtables.
struct MorxSubtablesIter {
  index : UInt
  count : UInt
  stream : Stream
  number_of_glyphs : UInt16
}

///|
/// Copies the iterator (Rust's `Clone`).
pub fn MorxSubtablesIter::copy(self : MorxSubtablesIter) -> MorxSubtablesIter {
  { ..self, stream: self.stream.copy(), }
}

///|
/// Returns the next subtable.
pub fn MorxSubtablesIter::next(self : MorxSubtablesIter) -> MorxSubtable? {
  // NOTE: like upstream, `index` is never incremented, so iteration stops at
  // the end of the data.
  if self.index == self.count {
    return None
  }
  let s = self.stream
  if s.at_end() {
    return None
  }
  try {
    let len = s.read_u32()
    let coverage = MorxCoverage(s.read_u8())
    s.advance(2) // reserved
    let kind = s.read_u8()
    let feature_flags = s.read_u32()
    let header_len = 12
    let len = req(usize_checked_sub(cblc_usize_from_u32(len), header_len))
    let subtables_data = s.read_bytes(len)
    let kind : MorxSubtableKind = match kind {
      0 => {
        let s = Stream::new(subtables_data)
        let table = req(ExtendedStateTable::parse(self.number_of_glyphs, s))
        Rearrangement(table)
      }
      1 => {
        let table = MorxContextualSubtable::parse(
          self.number_of_glyphs,
          subtables_data,
        )
        Contextual(table)
      }
      2 => {
        let table = MorxLigatureSubtable::parse(
          self.number_of_glyphs,
          subtables_data,
        )
        Ligature(table)
      }
      // 3 - reserved
      4 =>
        NonContextual(
          req(AatLookup::parse(self.number_of_glyphs, subtables_data)),
        )
      5 => {
        let table = MorxInsertionSubtable::parse(
          self.number_of_glyphs,
          subtables_data,
        )
        Insertion(table)
      }
      _ => return None
    }
    Some({ kind, coverage, feature_flags, })
  } catch {
    _ => None
  }
}

///|
/// A metamorphosis chain.
pub(all) struct MorxChain {
  /// Default chain features.
  default_flags : UInt
  /// A list of chain features.
  features : LazyArray32[MorxFeature]
  /// A list of chain subtables.
  subtables : MorxSubtables
}

///|
/// A list of metamorphosis chains.
///
/// The internal data layout is not designed for random access,
/// therefore we're not providing the `get()` method and only an iterator.
struct MorxChains {
  data : BytesView
  count : UInt
  number_of_glyphs : UInt16
}

///|
fn MorxChains::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> MorxChains raise Malformed {
  let s = Stream::new(data)
  s.advance(2) // version
  s.advance(2) // reserved
  let count = s.read_u32()
  { count, data: s.tail_r(), number_of_glyphs, }
}

///|
/// Returns an iterator over the chains.
pub fn MorxChains::into_iter(self : MorxChains) -> MorxChainsIter {
  {
    index: 0,
    count: self.count,
    stream: Stream::new(self.data),
    number_of_glyphs: self.number_of_glyphs,
  }
}

///|
/// Iterates over the chains.
pub fn MorxChains::iter(self : MorxChains) -> Iter[MorxChain] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over metamorphosis chains.
struct MorxChainsIter {
  index : UInt
  count : UInt
  stream : Stream
  number_of_glyphs : UInt16
}

///|
/// Copies the iterator (Rust's `Clone`).
pub fn MorxChainsIter::copy(self : MorxChainsIter) -> MorxChainsIter {
  { ..self, stream: self.stream.copy(), }
}

///|
/// Returns the next chain.
pub fn MorxChainsIter::next(self : MorxChainsIter) -> MorxChain? {
  // NOTE: like upstream, `index` is never incremented, so iteration stops at
  // the end of the data.
  if self.index == self.count {
    return None
  }
  if self.stream.at_end() {
    return None
  }
  try {
    let default_flags = self.stream.read_u32()
    let len = self.stream.read_u32()
    let features_count = self.stream.read_u32()
    let subtables_count = self.stream.read_u32()
    let features = self.stream.read_array32(features_count)
    let header_len = 16
    let len = req(usize_checked_sub(cblc_usize_from_u32(len), header_len))
    let features_len = 12L * features_count.to_uint64().reinterpret_as_int64()
    if features_len > len.to_int64() {
      return None
    }
    let len = len - features_len.to_int()
    let subtables_data = self.stream.read_bytes(len)
    let subtables : MorxSubtables = {
      data: subtables_data,
      count: subtables_count,
      number_of_glyphs: self.number_of_glyphs,
    }
    Some({ default_flags, features, subtables, })
  } catch {
    _ => None
  }
}

///|
/// An [Extended Glyph Metamorphosis Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6morx.html).
///
/// Subtable Glyph Coverage used by morx v3 is not supported.
pub(all) struct MorxTable {
  /// A list of metamorphosis chains.
  chains : MorxChains
}

///|
/// Parses a table from raw data.
///
/// `number_of_glyphs` is from the `maxp` table (non-zero).
pub fn MorxTable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> MorxTable? {
  try MorxChains::parse(number_of_glyphs, data) catch {
    _ => None
  } noraise {
    chains => Some({ chains, })
  }
}
