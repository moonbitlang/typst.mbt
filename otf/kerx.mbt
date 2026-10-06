// An [Extended Kerning Table](
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6kerx.html) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/kerx.rs`. Public types get a `Kerx`
// prefix (`kerx::Subtable0` -> `KerxSubtable0`, ...).

// TODO: find a way to test this table
// This table is basically untested because it uses Apple's State Tables
// and I have no idea how to generate them.

///|
let kerx_header_size : Int = 12

///|
/// A format 0 subtable.
///
/// Ordered List of Kerning Pairs.
///
/// The same as in `kern`, but uses `LazyArray32` instead of `LazyArray16`.
pub(all) struct KerxSubtable0 {
  /// A list of kerning pairs.
  pairs : LazyArray32[KerningPair]
}

///|
/// Parses a subtable from raw data.
fn KerxSubtable0::parse(data : BytesView) -> KerxSubtable0 raise Malformed {
  let s = Stream::new(data)
  let number_of_pairs = s.read_u32()
  s.advance(12) // search_range (u32) + entry_selector (u32) + range_shift (u32)
  let pairs = s.read_array32(number_of_pairs)
  { pairs, }
}

///|
/// Returns kerning for a pair of glyphs.
pub fn KerxSubtable0::glyphs_kerning(
  self : KerxSubtable0,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  let needle = (left.0.to_uint() << 16) | right.0.to_uint()
  self.pairs.binary_search_by(v => v.pair.compare(needle)).map(x => x.1.value)
}

///|
/// A state machine entry.
pub(all) struct KerxEntryData {
  /// An action index.
  action_index : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend KerxEntryData with @debug.Debug::{to_repr}

///|
pub impl FromData for KerxEntryData with fn size() {
  2
}

///|
pub impl FromData for KerxEntryData with fn parse(data) {
  let s = Stream::new(data)
  { action_index: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend KerxEntryData with FromData::{size, parse}

///|
/// A format 1 subtable.
///
/// State Table for Contextual Kerning.
pub struct KerxSubtable1 {
  /// A state table.
  state_table : ExtendedStateTable[KerxEntryData]
  actions_data : BytesView
}

///|
fn KerxSubtable1::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> KerxSubtable1 raise Malformed {
  let s = Stream::new(data)
  let state_table = req(ExtendedStateTable::parse(number_of_glyphs, s))

  // Actions offset is right after the state table.
  let actions_offset : Offset32 = s.read()
  // Actions offset is from the start of the state table and not from the start of subtable.
  // And since we don't know the length of the actions data,
  // simply store all the data after the offset.
  let actions_data = slice_from_r(data, actions_offset.to_usize())
  { state_table, actions_data, }
}

///|
/// Returns kerning at action index.
pub fn KerxSubtable1::glyphs_kerning(
  self : KerxSubtable1,
  action_index : UInt16,
) -> Int16? {
  try Stream::read_at(self.actions_data, action_index.to_int() * 2) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns a glyph class (`Deref` to the state table).
pub fn KerxSubtable1::class(
  self : KerxSubtable1,
  glyph_id : GlyphId,
) -> UInt16? {
  self.state_table.class(glyph_id)
}

///|
/// Returns a class entry (`Deref` to the state table).
pub fn KerxSubtable1::entry(
  self : KerxSubtable1,
  state : UInt16,
  class : UInt16,
) -> GenericStateEntry[KerxEntryData]? {
  self.state_table.entry(state, class)
}

///|
/// A format 2 subtable.
///
/// Simple n x m Array of Kerning Values.
///
/// The same as in `kern`, but uses 32bit offsets instead of 16bit one.
pub(all) struct KerxSubtable2(BytesView) // TODO: parse actual structure

///|
/// Returns kerning for a pair of glyphs.
pub fn KerxSubtable2::glyphs_kerning(
  self : KerxSubtable2,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  let s = Stream::new(self.0)
  s.advance(4) // row_width
  try {
    // Offsets are from beginning of the subtable and not from the `data` start,
    // so we have to subtract the header.
    let left_hand_table_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )
    let right_hand_table_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )
    let array_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )

    // 'The array can be indexed by completing the left-hand and right-hand class mappings,
    // adding the class values to the address of the subtable,
    // and fetching the kerning value to which the new address points.'

    let left_class = get_format2_class(left.0, left_hand_table_offset, self.0).unwrap_or(
      0,
    )
    let right_class = get_format2_class(
      right.0,
      right_hand_table_offset,
      self.0,
    ).unwrap_or(0)

    // 'Values within the left-hand offset table should not be less than the kerning array offset.'
    if left_class.to_int() < array_offset {
      return None
    }

    // Classes are already premultiplied, so we only need to sum them.
    let index = left_class.to_int() + right_class.to_int()
    let value_offset = req(usize_checked_sub(index, kerx_header_size))
    Some(Stream::read_at(self.0, value_offset))
  } catch {
    _ => None
  }
}

///|
/// A container of Anchor Points used by [`KerxSubtable4`].
pub(all) struct KerxAnchorPoints(BytesView)

///|
/// Returns a mark and current anchor points at action index.
pub fn KerxAnchorPoints::get(
  self : KerxAnchorPoints,
  action_index : UInt16,
) -> (UInt16, UInt16)? {
  // Each action contains two 16-bit fields, so we must
  // double the action_index to get the correct offset here.
  let offset = action_index.to_int() * 2 * 2
  try {
    let s = Stream::new_at_r(self.0, offset)
    let a = s.read_u16()
    let b = s.read_u16()
    Some((a, b))
  } catch {
    _ => None
  }
}

///|
/// A format 4 subtable.
///
/// State Table for Control Point/Anchor Point Positioning.
///
/// Note: I wasn't able to find any fonts that actually use
/// `ControlPointActions` and/or `ControlPointCoordinateActions`,
/// therefore only `AnchorPointActions` is supported.
pub struct KerxSubtable4 {
  /// A state table.
  state_table : ExtendedStateTable[KerxEntryData]
  /// Anchor points.
  anchor_points : KerxAnchorPoints
}

///|
fn KerxSubtable4::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> KerxSubtable4 raise Malformed {
  let s = Stream::new(data)
  let state_table = req(ExtendedStateTable::parse(number_of_glyphs, s))
  let flags = s.read_u32()
  let action_type = (flags & 0xC0000000) >> 30
  let points_offset = (flags & 0x00FFFFFF).reinterpret_as_int()

  // We support only Anchor Point Actions.
  if action_type != 1 {
    raise Malformed
  }
  {
    state_table,
    anchor_points: KerxAnchorPoints(slice_from_r(data, points_offset)),
  }
}

///|
/// Returns a glyph class (`Deref` to the state table).
pub fn KerxSubtable4::class(
  self : KerxSubtable4,
  glyph_id : GlyphId,
) -> UInt16? {
  self.state_table.class(glyph_id)
}

///|
/// Returns a class entry (`Deref` to the state table).
pub fn KerxSubtable4::entry(
  self : KerxSubtable4,
  state : UInt16,
  class : UInt16,
) -> GenericStateEntry[KerxEntryData]? {
  self.state_table.entry(state, class)
}

///|
/// A format 6 subtable.
///
/// Simple Index-based n x m Array of Kerning Values.
struct KerxSubtable6 {
  data : BytesView
  number_of_glyphs : UInt16
}

///|
// TODO: parse actual structure
fn KerxSubtable6::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> KerxSubtable6 {
  { number_of_glyphs, data, }
}

///|
/// Returns kerning for a pair of glyphs.
pub fn KerxSubtable6::glyphs_kerning(
  self : KerxSubtable6,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  let s = Stream::new(self.data)
  try {
    let flags = s.read_u32()
    s.advance(2) // row_count
    s.advance(2) // col_count
    // All offsets are from the start of the subtable.
    let row_index_table_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )
    let column_index_table_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )
    let kerning_array_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )
    let kerning_vector_offset = req(
      usize_checked_sub((s.read() : Offset32).to_usize(), kerx_header_size),
    )
    let row_index_table_data = slice_from_r(self.data, row_index_table_offset)
    let column_index_table_data = slice_from_r(
      self.data,
      column_index_table_offset,
    )
    let kerning_array_data = slice_from_r(self.data, kerning_array_offset)
    let kerning_vector_data = slice_from_r(self.data, kerning_vector_offset)
    let has_long_values = (flags & 0x00000001) != 0
    if has_long_values {
      let l = req(AatLookup::parse(self.number_of_glyphs, row_index_table_data))
        .value(left)
        .unwrap_or(0)
        .to_int()
      let r = req(
          AatLookup::parse(self.number_of_glyphs, column_index_table_data),
        )
        .value(right)
        .unwrap_or(0)
        .to_int()
      let array_offset = (l + r) * 4
      let vector_offset : UInt = Stream::read_at(
        kerning_array_data, array_offset,
      )
      Some(
        Stream::read_at(kerning_vector_data, cblc_usize_from_u32(vector_offset)),
      )
    } else {
      let l = req(AatLookup::parse(self.number_of_glyphs, row_index_table_data))
        .value(left)
        .unwrap_or(0)
      let r = req(
          AatLookup::parse(self.number_of_glyphs, column_index_table_data),
        )
        .value(right)
        .unwrap_or(0)
      let array_offset = (l + r).to_int() * 2
      let vector_offset : UInt16 = Stream::read_at(
        kerning_array_data, array_offset,
      )
      Some(Stream::read_at(kerning_vector_data, vector_offset.to_int()))
    }
  } catch {
    _ => None
  }
}

///|
/// An extended kerning subtable format.
pub(all) enum KerxFormat {
  Format0(KerxSubtable0)
  Format1(KerxSubtable1)
  Format2(KerxSubtable2)
  Format4(KerxSubtable4)
  Format6(KerxSubtable6)
}

///|
/// A kerning subtable.
pub(all) struct KerxSubtable {
  /// Indicates that subtable is for horizontal text.
  horizontal : Bool
  /// Indicates that subtable is variable.
  variable : Bool
  /// Indicates that subtable has a cross-stream values.
  has_cross_stream : Bool
  /// Indicates that subtable uses a state machine.
  ///
  /// In this case `glyphs_kerning()` will return `None`.
  has_state_machine : Bool
  /// The tuple count.
  ///
  /// This value is only used with variation fonts and should be 0 for all other fonts.
  tuple_count : UInt
  /// Subtable format.
  format : KerxFormat
}

///|
/// Returns kerning for a pair of glyphs.
///
/// Returns `None` in case of state machine based subtable.
pub fn KerxSubtable::glyphs_kerning(
  self : KerxSubtable,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  match self.format {
    Format0(subtable) => subtable.glyphs_kerning(left, right)
    Format1(_) => None
    Format2(subtable) => subtable.glyphs_kerning(left, right)
    Format4(_) => None
    Format6(subtable) => subtable.glyphs_kerning(left, right)
  }
}

///|
priv struct KerxCoverage(Byte)

///|
// TODO: use hex
fn KerxCoverage::is_horizontal(self : KerxCoverage) -> Bool {
  (self.0 & (1 << 7)) == 0
}

///|
fn KerxCoverage::has_cross_stream(self : KerxCoverage) -> Bool {
  (self.0 & (1 << 6)) != 0
}

///|
fn KerxCoverage::is_variable(self : KerxCoverage) -> Bool {
  (self.0 & (1 << 5)) != 0
}

///|
/// A list of extended kerning subtables.
///
/// The internal data layout is not designed for random access,
/// therefore we're not providing the `get()` method and only an iterator.
struct KerxSubtables {
  /// The number of glyphs from the `maxp` table.
  number_of_glyphs : UInt16
  /// The total number of tables.
  number_of_tables : UInt
  /// Actual data. Starts right after the `kerx` header.
  data : BytesView
}

///|
/// Returns an iterator over the subtables.
pub fn KerxSubtables::into_iter(self : KerxSubtables) -> KerxSubtablesIter {
  {
    number_of_glyphs: self.number_of_glyphs,
    table_index: 0,
    number_of_tables: self.number_of_tables,
    stream: Stream::new(self.data),
  }
}

///|
/// Iterates over the subtables.
pub fn KerxSubtables::iter(self : KerxSubtables) -> Iter[KerxSubtable] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over extended kerning subtables.
struct KerxSubtablesIter {
  /// The number of glyphs from the `maxp` table.
  number_of_glyphs : UInt16
  /// The current table index.
  mut table_index : UInt
  /// The total number of tables.
  number_of_tables : UInt
  /// Actual data. Starts right after the `kerx` header.
  stream : Stream
}

///|
/// Copies the iterator (Rust's `Clone`).
pub fn KerxSubtablesIter::copy(self : KerxSubtablesIter) -> KerxSubtablesIter {
  { ..self, stream: self.stream.copy(), }
}

///|
/// Returns the next subtable.
pub fn KerxSubtablesIter::next(self : KerxSubtablesIter) -> KerxSubtable? {
  if self.table_index == self.number_of_tables {
    return None
  }
  if self.stream.at_end() {
    return None
  }
  let s = self.stream
  try {
    let table_len = s.read_u32()
    let coverage = KerxCoverage(s.read_u8())
    s.advance(2) // unused
    let raw_format = s.read_u8()
    let tuple_count = s.read_u32()

    // Subtract the header size.
    let data_len = req(
      usize_checked_sub(cblc_usize_from_u32(table_len), kerx_header_size),
    )
    let data = s.read_bytes(data_len)
    let format : KerxFormat = match raw_format {
      0 => Format0(KerxSubtable0::parse(data))
      1 => Format1(KerxSubtable1::parse(self.number_of_glyphs, data))
      2 => Format2(KerxSubtable2(data))
      4 => Format4(KerxSubtable4::parse(self.number_of_glyphs, data))
      6 => Format6(KerxSubtable6::parse(self.number_of_glyphs, data))
      _ =>
        // Unknown format.
        return None
    }
    self.table_index += 1
    Some({
      horizontal: coverage.is_horizontal(),
      variable: coverage.is_variable(),
      has_cross_stream: coverage.has_cross_stream(),
      has_state_machine: raw_format == 1 || raw_format == 4,
      tuple_count,
      format,
    })
  } catch {
    _ => None
  }
}

///|
/// An [Extended Kerning Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6kerx.html).
pub(all) struct KerxTable {
  /// A list of subtables.
  subtables : KerxSubtables
}

///|
/// Parses a table from raw data.
///
/// `number_of_glyphs` is from the `maxp` table (non-zero).
pub fn KerxTable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> KerxTable? {
  let s = Stream::new(data)
  s.advance(2) // version
  s.advance(2) // padding
  try {
    let number_of_tables = s.read_u32()
    let subtables : KerxSubtables = {
      number_of_glyphs,
      number_of_tables,
      data: s.tail_r(),
    }
    Some({ subtables, })
  } catch {
    _ => None
  }
}
