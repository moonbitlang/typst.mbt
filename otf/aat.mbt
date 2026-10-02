// A collection of [Apple Advanced Typography](
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6AATIntro.html)
// related types.
//
// Port of `ttf-parser` 0.25.1 `src/aat.rs` (`apple_layout` module).

///|
/// Predefined states.
pub let aat_state_start_of_text : UInt16 = 0

///|
/// Predefined classes.
///
/// Search for _Class Code_ in [Apple Advanced Typography Font Tables](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6Tables.html).
pub let aat_class_end_of_text : Byte = 0

///|
pub let aat_class_out_of_bounds : Byte = 1

///|
pub let aat_class_deleted_glyph : Byte = 2

///|
/// A State Table entry.
///
/// Used by legacy and extended tables.
pub(all) struct GenericStateEntry[T] {
  /// A new state.
  new_state : UInt16
  /// Entry flags.
  flags : UInt16
  /// Additional data.
  ///
  /// Use `()` if no data expected.
  extra : T
}

///|
pub impl[T : FromData] FromData for GenericStateEntry[T] with fn size() {
  4 + T::size()
}

///|
pub impl[T : FromData] FromData for GenericStateEntry[T] with fn parse(data) {
  let s = Stream::new(data)
  { new_state: s.read(), flags: s.read(), extra: s.read(), }
}

///|
/// Checks that entry has an offset.
pub fn[T] GenericStateEntry::has_offset(self : GenericStateEntry[T]) -> Bool {
  (self.flags & 0x3FFF) != 0
}

///|
/// Returns a value offset.
///
/// Used by kern::format1 subtable.
pub fn[T] GenericStateEntry::value_offset(
  self : GenericStateEntry[T],
) -> ValueOffset {
  ValueOffset(self.flags & 0x3FFF)
}

///|
/// If set, reset the kerning data (clear the stack).
pub fn[T] GenericStateEntry::has_reset(self : GenericStateEntry[T]) -> Bool {
  (self.flags & 0x2000) != 0
}

///|
/// If set, advance to the next glyph before going to the new state.
pub fn[T] GenericStateEntry::has_advance(self : GenericStateEntry[T]) -> Bool {
  (self.flags & 0x4000) == 0
}

///|
/// If set, push this glyph on the kerning stack.
pub fn[T] GenericStateEntry::has_push(self : GenericStateEntry[T]) -> Bool {
  (self.flags & 0x8000) != 0
}

///|
/// If set, remember this glyph as the marked glyph.
///
/// Used by kerx::format4 subtable.
///
/// Yes, the same as `has_push`.
pub fn[T] GenericStateEntry::has_mark(self : GenericStateEntry[T]) -> Bool {
  (self.flags & 0x8000) != 0
}

///|
/// A legacy state entry used by `StateTable`.
pub type StateEntry = GenericStateEntry[Unit]

///|
/// A type-safe wrapper for a kerning value offset.
pub(all) struct ValueOffset(UInt16) derive(Debug)

///|
/// Returns the next offset.
///
/// After reaching u16::MAX will start from 0.
pub fn ValueOffset::next(self : ValueOffset) -> ValueOffset {
  ValueOffset(self.0 + 2)
}

///|
/// A [State Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6Tables.html).
///
/// Also called `STHeader`.
///
/// Currently used by `kern` table.
struct AatStateTable {
  number_of_classes : UInt16
  first_glyph : GlyphId
  class_table : BytesView
  state_array_offset : UInt16
  state_array : BytesView
  entry_table : BytesView
  actions : BytesView
}

///|
fn AatStateTable::parse(data : BytesView) -> AatStateTable? {
  try {
    let s = Stream::new(data)
    let number_of_classes : UInt16 = s.read()
    // Note that in format1 subtable, offsets are not from the subtable start,
    // but from subtable start + `header_size`.
    // So there is not need to subtract the `header_size`.
    let class_table_offset = (s.read() : Offset16).to_usize()
    let state_array_offset = (s.read() : Offset16).to_usize()
    let entry_table_offset = (s.read() : Offset16).to_usize()
    // Ignore `values_offset` since we don't use it.

    // Parse class subtable.
    let s = Stream::new_at_r(data, class_table_offset)
    let first_glyph : GlyphId = s.read()
    let number_of_glyphs : UInt16 = s.read()
    // The class table contains u8, so it's easier to use just a slice
    // instead of a LazyArray.
    let class_table = s.read_bytes(number_of_glyphs.to_int())
    Some({
      number_of_classes,
      first_glyph,
      class_table,
      state_array_offset: state_array_offset.to_uint16(),
      // We don't know the actual data size and it's kinda expensive to calculate.
      // So we are simply storing all the data past the offset.
      // Despite the fact that they may overlap.
      state_array: slice_from_r(data, state_array_offset),
      entry_table: slice_from_r(data, entry_table_offset),
      // `ValueOffset` defines an offset from the start of the subtable data.
      // We do not check that the provided offset is actually after `values_offset`.
      actions: data,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph class.
pub fn AatStateTable::class(self : AatStateTable, glyph_id : GlyphId) -> Byte? {
  if glyph_id.0 == 0xFFFF {
    return Some(aat_class_deleted_glyph)
  }
  guard u16_checked_sub(glyph_id.0, self.first_glyph.0) is Some(idx) else {
    return None
  }
  let idx = idx.to_int()
  if idx < self.class_table.length() {
    Some(self.class_table[idx])
  } else {
    None
  }
}

///|
/// Returns a class entry.
pub fn AatStateTable::entry(
  self : AatStateTable,
  state : UInt16,
  class : Byte,
) -> StateEntry? {
  let class = if class.to_int() >= self.number_of_classes.to_int() {
    aat_class_out_of_bounds
  } else {
    class
  }
  let idx = state.to_int() * self.number_of_classes.to_int() + class.to_int()
  if idx >= self.state_array.length() {
    return None
  }
  let entry_idx = self.state_array[idx]
  try Stream::read_at(self.entry_table, entry_idx.to_int() * 4) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns kerning at offset.
pub fn AatStateTable::kerning(
  self : AatStateTable,
  offset : ValueOffset,
) -> Int16? {
  try Stream::read_at(self.actions, offset.0.to_int()) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Produces a new state.
pub fn AatStateTable::new_state(self : AatStateTable, state : UInt16) -> UInt16 {
  if self.number_of_classes == 0 {
    // Rust would panic on division by zero here.
    return 0
  }
  let n = (state.to_int() - self.state_array_offset.to_int()) /
    self.number_of_classes.to_int()
  u16_try_from_int(n).unwrap_or(0)
}

///|
/// An [Extended State Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6Tables.html).
///
/// Also called `STXHeader`.
///
/// Currently used by `kerx` and `morx` tables.
struct ExtendedStateTable[T] {
  number_of_classes : UInt
  lookup : AatLookup
  state_array : BytesView
  entry_table : BytesView
}

///|
/// Parses an Extended State Table from a stream.
///
/// `number_of_glyphs` is from the `maxp` table.
pub fn[T] ExtendedStateTable::parse(
  number_of_glyphs : UInt16,
  s : Stream,
) -> ExtendedStateTable[T]? {
  try {
    let data = s.tail_r()
    let number_of_classes = s.read_u32()
    // Note that offsets are not from the subtable start,
    // but from subtable start + `header_size`.
    // So there is not need to subtract the `header_size`.
    let lookup_table_offset = (s.read() : Offset32).to_usize()
    let state_array_offset = (s.read() : Offset32).to_usize()
    let entry_table_offset = (s.read() : Offset32).to_usize()
    Some({
      number_of_classes,
      lookup: req(
        AatLookup::parse(
          number_of_glyphs,
          slice_from_r(data, lookup_table_offset),
        ),
      ),
      // We don't know the actual data size and it's kinda expensive to calculate.
      // So we are simply storing all the data past the offset.
      // Despite the fact that they may overlap.
      state_array: slice_from_r(data, state_array_offset),
      entry_table: slice_from_r(data, entry_table_offset),
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a glyph class.
pub fn[T] ExtendedStateTable::class(
  self : ExtendedStateTable[T],
  glyph_id : GlyphId,
) -> UInt16? {
  if glyph_id.0 == 0xFFFF {
    return Some(u16_from_u8(aat_class_deleted_glyph))
  }
  self.lookup.value(glyph_id)
}

///|
/// Returns a class entry.
pub fn[T : FromData] ExtendedStateTable::entry(
  self : ExtendedStateTable[T],
  state : UInt16,
  class : UInt16,
) -> GenericStateEntry[T]? {
  let class = if class.to_uint() >= self.number_of_classes {
    u16_from_u8(aat_class_out_of_bounds)
  } else {
    class
  }
  let state_idx = state.to_int() * self.number_of_classes.reinterpret_as_int() +
    class.to_int()
  try {
    let entry_idx : UInt16 = Stream::read_at(self.state_array, state_idx * 2)
    Some(
      Stream::read_at(self.entry_table, entry_idx.to_int() * (4 + T::size())),
    )
  } catch {
    _ => None
  }
}

///|
/// A [lookup table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6Tables.html).
///
/// u32 values in Format10 tables will be truncated to u16.
/// u64 values in Format10 tables are not supported.
struct AatLookup {
  data : LookupInner
}

///|
/// Parses a lookup table from raw data.
///
/// `number_of_glyphs` is from the `maxp` table.
pub fn AatLookup::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> AatLookup? {
  LookupInner::parse(number_of_glyphs, data).map(data => { data, })
}

///|
/// Returns a value associated with the specified glyph.
pub fn AatLookup::value(self : AatLookup, glyph_id : GlyphId) -> UInt16? {
  self.data.value(glyph_id)
}

///|
priv enum LookupInner {
  Format1(LazyArray16[UInt16])
  Format2(BinarySearchTable[LookupSegment])
  Format4(BinarySearchTable[LookupSegment], BytesView)
  Format6(BinarySearchTable[LookupSingle])
  Format8(first_glyph~ : UInt16, values~ : LazyArray16[UInt16])
  Format10(
    value_size~ : UInt16,
    first_glyph~ : UInt16,
    glyph_count~ : UInt16,
    data~ : BytesView
  )
}

///|
fn LookupInner::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> LookupInner? {
  try {
    let s = Stream::new(data)
    let format = s.read_u16()
    match format {
      0 => {
        let values = s.read_array16(number_of_glyphs)
        Some(Format1(values))
      }
      2 => {
        let bsearch = req(BinarySearchTable::parse(s.tail_r()))
        Some(Format2(bsearch))
      }
      4 => {
        let bsearch = req(BinarySearchTable::parse(s.tail_r()))
        Some(Format4(bsearch, data))
      }
      6 => {
        let bsearch = req(BinarySearchTable::parse(s.tail_r()))
        Some(Format6(bsearch))
      }
      8 => {
        let first_glyph = s.read_u16()
        let glyph_count = s.read_u16()
        let values = s.read_array16(glyph_count)
        Some(Format8(first_glyph~, values~))
      }
      10 => {
        let value_size = s.read_u16()
        let first_glyph = s.read_u16()
        let glyph_count = s.read_u16()
        Some(Format10(value_size~, first_glyph~, glyph_count~, data=s.tail_r()))
      }
      _ => None
    }
  } catch {
    _ => None
  }
}

///|
fn LookupInner::value(self : LookupInner, glyph_id : GlyphId) -> UInt16? {
  match self {
    Format1(values) => values.get(glyph_id.0)
    Format2(bsearch) => bsearch.get(glyph_id).map(v => v.value)
    Format4(bsearch, data) => {
      // In format 4, LookupSegment contains an offset to a list of u16 values.
      // One value for each glyph in the LookupSegment range.
      guard bsearch.get(glyph_id) is Some(segment) else { return None }
      guard u16_checked_sub(glyph_id.0, segment.first_glyph) is Some(index) else {
        return None
      }
      let offset = segment.value.to_int() + 2 * index.to_int()
      try Stream::read_at(data, offset) catch {
        _ => None
      } noraise {
        v => Some(v)
      }
    }
    Format6(bsearch) => bsearch.get(glyph_id).map(v => v.value)
    Format8(first_glyph~, values~) => {
      guard u16_checked_sub(glyph_id.0, first_glyph) is Some(idx) else {
        return None
      }
      values.get(idx)
    }
    Format10(value_size~, first_glyph~, glyph_count~, data~) => {
      guard u16_checked_sub(glyph_id.0, first_glyph) is Some(idx) else {
        return None
      }
      let s = Stream::new(data)
      try {
        match value_size {
          1 =>
            (s.read_array16(glyph_count) : LazyArray16[Byte])
            .get(idx)
            .map(u16_from_u8)
          2 => (s.read_array16(glyph_count) : LazyArray16[UInt16]).get(idx)
          // TODO: we should return u32 here, but this is not supported yet
          4 =>
            (s.read_array16(glyph_count) : LazyArray16[UInt])
            .get(idx)
            .map(n => n.reinterpret_as_int().to_uint16())
          _ => None // 8 is also supported
        }
      } catch {
        _ => None
      }
    }
  }
}

///|
/// A binary searching table as defined at
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6Tables.html
priv struct BinarySearchTable[T] {
  values : LazyArray16[T]
  len : UInt16 // values length excluding termination segment
}

///|
fn[T : BinarySearchValue] BinarySearchTable::parse(
  data : BytesView,
) -> BinarySearchTable[T]? {
  try {
    let s = Stream::new(data)
    let segment_size = s.read_u16()
    let number_of_segments = s.read_u16()
    s.advance(6) // search_range + entry_selector + range_shift
    if segment_size.to_int() != T::size() {
      return None
    }
    if number_of_segments == 0 {
      return None
    }
    let values : LazyArray16[T] = s.read_array16(number_of_segments)

    // 'The number of termination values that need to be included is table-specific.
    // The value that indicates binary search termination is 0xFFFF.'
    let mut len = number_of_segments
    if req(values.last()).is_termination() {
      len = req(u16_checked_sub(len, 1))
    }
    if len == 0 {
      return None
    }
    Some({ len, values, })
  } catch {
    _ => None
  }
}

///|
fn[T : BinarySearchValue] BinarySearchTable::get(
  self : BinarySearchTable[T],
  key : GlyphId,
) -> T? {
  let mut min = 0
  let mut max = self.len.to_int() - 1
  while min <= max {
    let mid = (min + max) / 2
    guard self.values.get(mid.to_uint16()) is Some(v) else { return None }
    let c = v.contains(key)
    if c < 0 {
      max = mid - 1
    } else if c > 0 {
      min = mid + 1
    } else {
      return Some(v)
    }
  }
  None
}

///|
priv trait BinarySearchValue: FromData {
  fn is_termination(Self) -> Bool
  fn contains(Self, GlyphId) -> Int
}

///|
priv struct LookupSegment {
  last_glyph : UInt16
  first_glyph : UInt16
  value : UInt16
}

///|
impl FromData for LookupSegment with fn size() {
  6
}

///|
impl FromData for LookupSegment with fn parse(data) {
  let s = Stream::new(data)
  { last_glyph: s.read(), first_glyph: s.read(), value: s.read(), }
}

///|
impl BinarySearchValue for LookupSegment with fn is_termination(self) {
  self.last_glyph == 0xFFFF && self.first_glyph == 0xFFFF
}

///|
impl BinarySearchValue for LookupSegment with fn contains(self, id) {
  if id.0 < self.first_glyph {
    -1
  } else if id.0 <= self.last_glyph {
    0
  } else {
    1
  }
}

///|
priv struct LookupSingle {
  glyph : UInt16
  value : UInt16
}

///|
impl FromData for LookupSingle with fn size() {
  4
}

///|
impl FromData for LookupSingle with fn parse(data) {
  let s = Stream::new(data)
  { glyph: s.read(), value: s.read(), }
}

///|
impl BinarySearchValue for LookupSingle with fn is_termination(self) {
  self.glyph == 0xFFFF
}

///|
impl BinarySearchValue for LookupSingle with fn contains(self, id) {
  id.0.compare(self.glyph)
}
