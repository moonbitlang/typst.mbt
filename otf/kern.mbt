// A [Kerning Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/kern) implementation.
//
// Supports both
// [OpenType](https://docs.microsoft.com/en-us/typography/opentype/spec/kern)
// and
// [Apple Advanced Typography](https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6kern.html)
// variants.
//
// Since there is no single correct way to process a kerning data,
// we have to provide an access to kerning subtables, so a caller can implement
// a kerning algorithm manually.
// But we still try to keep the API as high-level as possible.

///|
/// A kerning pair.
pub(all) struct KerningPair {
  /// Glyphs pair.
  ///
  /// In the kern table spec, a kerning pair is stored as two u16,
  /// but we are using one u32, so we can binary search it directly.
  pair : UInt
  /// Kerning value.
  value : Int16
} derive(Debug)

///|
/// Returns left glyph ID.
pub fn KerningPair::left(self : KerningPair) -> GlyphId {
  GlyphId((self.pair >> 16).reinterpret_as_int().to_uint16())
}

///|
/// Returns right glyph ID.
pub fn KerningPair::right(self : KerningPair) -> GlyphId {
  GlyphId(self.pair.reinterpret_as_int().to_uint16())
}

///|
pub impl FromData for KerningPair with fn size() {
  6
}

///|
pub impl FromData for KerningPair with fn parse(data) {
  let s = Stream::new(data)
  { pair: s.read(), value: s.read(), }
}

///|
/// A kerning subtable format.
pub(all) enum KernFormat {
  Format0(KernSubtable0)
  Format1(AatStateTable)
  Format2(KernSubtable2)
  Format3(KernSubtable3)
}

///|
/// A kerning subtable.
pub(all) struct KernSubtable {
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
  /// Subtable format.
  format : KernFormat
}

///|
/// Returns kerning for a pair of glyphs.
///
/// Returns `None` in case of state machine based subtable.
pub fn KernSubtable::glyphs_kerning(
  self : KernSubtable,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  match self.format {
    Format0(subtable) => subtable.glyphs_kerning(left, right)
    Format2(subtable) => subtable.glyphs_kerning(left, right)
    Format3(subtable) => subtable.glyphs_kerning(left, right)
    _ => None
  }
}

///|
/// A list of subtables.
///
/// The internal data layout is not designed for random access,
/// therefore we're not providing the `get()` method and only an iterator.
struct KernSubtables {
  /// Indicates an Apple Advanced Typography format.
  is_aat : Bool
  /// The total number of tables.
  count : UInt
  /// Actual data. Starts right after the `kern` header.
  data : BytesView
}

///|
/// Returns the number of subtables.
pub fn KernSubtables::len(self : KernSubtables) -> UInt {
  self.count
}

///|
/// Checks if there are any subtables.
pub fn KernSubtables::is_empty(self : KernSubtables) -> Bool {
  self.count == 0
}

///|
/// Returns an iterator over the subtables.
pub fn KernSubtables::into_iter(self : KernSubtables) -> KernSubtablesIter {
  {
    is_aat: self.is_aat,
    table_index: 0,
    number_of_tables: self.count,
    stream: Stream::new(self.data),
  }
}

///|
/// Iterates over the subtables.
pub fn KernSubtables::iter(self : KernSubtables) -> Iter[KernSubtable] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over kerning subtables.
struct KernSubtablesIter {
  /// Indicates an Apple Advanced Typography format.
  is_aat : Bool
  /// The current table index,
  table_index : UInt
  /// The total number of tables.
  number_of_tables : UInt
  /// Actual data. Starts right after `kern` header.
  stream : Stream
}

///|
/// Returns the next subtable.
pub fn KernSubtablesIter::next(self : KernSubtablesIter) -> KernSubtable? {
  if self.table_index == self.number_of_tables {
    return None
  }
  if self.stream.at_end() {
    return None
  }
  try {
    if self.is_aat {
      let header_size = 8
      let table_len = self.stream.read_u32()
      let coverage = self.stream.read_u8()
      let format_id = self.stream.read_u8()
      self.stream.advance(2) // variation tuple index
      if format_id > 3 {
        // Unknown format.
        return None
      }

      // Subtract the header size.
      let table_len = table_len.reinterpret_as_int()
      if table_len < 0 {
        return None
      }
      let data_len = req(usize_checked_sub(table_len, header_size))
      let data = self.stream.read_bytes(data_len)
      let format : KernFormat = match format_id {
        0 => Format0(req(KernSubtable0::parse(data)))
        1 => Format1(req(AatStateTable::parse(data)))
        2 => Format2(req(KernSubtable2::parse(header_size.to_byte(), data)))
        3 => Format3(req(KernSubtable3::parse(data)))
        _ => return None
      }
      Some({
        // AATCoverage
        horizontal: (coverage & (1 << 7)) == 0,
        variable: (coverage & (1 << 5)) != 0,
        has_cross_stream: (coverage & (1 << 6)) != 0,
        has_state_machine: format_id == 1,
        format,
      })
    } else {
      let header_size = 6
      self.stream.advance(2) // version
      let table_len = self.stream.read_u16()
      // In the OpenType variant, `format` comes first.
      let format_id = self.stream.read_u8()
      let coverage = self.stream.read_u8()
      if format_id != 0 && format_id != 2 {
        // Unknown format.
        return None
      }
      let data_len = if self.number_of_tables == 1 {
        // An OpenType `kern` table with just one subtable is a special case.
        // The `table_len` property is mainly required to jump to the next subtable,
        // but if there is only one subtable, this property can be ignored.
        // This is abused by some fonts, to get around the `u16` size limit.
        self.stream.tail_r().length()
      } else {
        // Subtract the header size.
        req(usize_checked_sub(table_len.to_int(), header_size))
      }
      let data = self.stream.read_bytes(data_len)
      let format : KernFormat = match format_id {
        0 => Format0(req(KernSubtable0::parse(data)))
        2 => Format2(req(KernSubtable2::parse(header_size.to_byte(), data)))
        _ => return None
      }
      Some({
        // OTCoverage
        horizontal: (coverage & (1 << 0)) != 0,
        variable: false, // Only AAT supports it.
        has_cross_stream: (coverage & (1 << 2)) != 0,
        has_state_machine: format_id == 1,
        format,
      })
    }
  } catch {
    _ => None
  }
}

///|
/// A format 0 subtable.
///
/// Ordered List of Kerning Pairs.
pub(all) struct KernSubtable0 {
  /// A list of kerning pairs.
  pairs : LazyArray16[KerningPair]
}

///|
/// Parses a subtable from raw data.
pub fn KernSubtable0::parse(data : BytesView) -> KernSubtable0? {
  let s = Stream::new(data)
  try {
    let number_of_pairs = s.read_u16()
    s.advance(6) // search_range (u16) + entry_selector (u16) + range_shift (u16)
    let pairs = s.read_array16(number_of_pairs)
    Some({ pairs, })
  } catch {
    _ => None
  }
}

///|
/// Returns kerning for a pair of glyphs.
pub fn KernSubtable0::glyphs_kerning(
  self : KernSubtable0,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  let needle = (left.0.to_uint() << 16) | right.0.to_uint()
  self.pairs.binary_search_by(v => v.pair.compare(needle)).map(x => x.1.value)
}

///|
/// A format 2 subtable.
///
/// Simple n x m Array of Kerning Values.
struct KernSubtable2 {
  // TODO: parse actual structure
  data : BytesView
  header_len : Byte
}

///|
/// Parses a subtable from raw data.
pub fn KernSubtable2::parse(
  header_len : Byte,
  data : BytesView,
) -> KernSubtable2? {
  Some({ header_len, data, })
}

///|
/// Returns kerning for a pair of glyphs.
pub fn KernSubtable2::glyphs_kerning(
  self : KernSubtable2,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  let s = Stream::new(self.data)
  s.advance(2) // row_width
  try {
    // Offsets are from beginning of the subtable and not from the `data` start,
    // so we have to subtract the header.
    let header_len = self.header_len.to_int()
    let left_hand_table_offset = req(
      usize_checked_sub((s.read() : Offset16).to_usize(), header_len),
    )
    let right_hand_table_offset = req(
      usize_checked_sub((s.read() : Offset16).to_usize(), header_len),
    )
    let array_offset = req(
      usize_checked_sub((s.read() : Offset16).to_usize(), header_len),
    )

    // 'The array can be indexed by completing the left-hand and right-hand class mappings,
    // adding the class values to the address of the subtable,
    // and fetching the kerning value to which the new address points.'
    let left_class = get_format2_class(
      left.0,
      left_hand_table_offset,
      self.data,
    ).unwrap_or(0)
    let right_class = get_format2_class(
      right.0,
      right_hand_table_offset,
      self.data,
    ).unwrap_or(0)

    // 'Values within the left-hand offset table should not be less than the kerning array offset.'
    if left_class.to_int() < array_offset {
      return None
    }

    // Classes are already premultiplied, so we only need to sum them.
    let index = left_class.to_int() + right_class.to_int()
    let value_offset = req(usize_checked_sub(index, header_len))
    Some(Stream::read_at(self.data, value_offset))
  } catch {
    _ => None
  }
}

///|
fn get_format2_class(
  glyph_id : UInt16,
  offset : Int,
  data : BytesView,
) -> UInt16? {
  try {
    let s = Stream::new_at_r(data, offset)
    let first_glyph = s.read_u16()
    let index = req(u16_checked_sub(glyph_id, first_glyph))
    let number_of_classes = s.read_u16()
    let classes : LazyArray16[UInt16] = s.read_array16(number_of_classes)
    classes.get(index)
  } catch {
    _ => None
  }
}

///|
/// A format 3 subtable.
///
/// Simple n x m Array of Kerning Indices.
struct KernSubtable3 {
  // TODO: parse actual structure
  data : BytesView
}

///|
/// Parses a subtable from raw data.
pub fn KernSubtable3::parse(data : BytesView) -> KernSubtable3? {
  Some({ data, })
}

///|
/// Returns kerning for a pair of glyphs.
pub fn KernSubtable3::glyphs_kerning(
  self : KernSubtable3,
  left : GlyphId,
  right : GlyphId,
) -> Int16? {
  let s = Stream::new(self.data)
  try {
    let glyph_count = s.read_u16()
    let kerning_values_count = s.read_u8()
    let left_hand_classes_count = s.read_u8()
    let right_hand_classes_count = s.read_u8()
    s.advance(1) // reserved
    let indices_count = u16_from_u8(left_hand_classes_count) *
      u16_from_u8(right_hand_classes_count)
    let kerning_values : LazyArray16[Int16] = s.read_array16(
      u16_from_u8(kerning_values_count),
    )
    let left_hand_classes : LazyArray16[Byte] = s.read_array16(glyph_count)
    let right_hand_classes : LazyArray16[Byte] = s.read_array16(glyph_count)
    let indices : LazyArray16[Byte] = s.read_array16(indices_count)
    let left_class = req(left_hand_classes.get(left.0))
    let right_class = req(right_hand_classes.get(right.0))
    if left_class > left_hand_classes_count ||
      right_class > right_hand_classes_count {
      return None
    }
    let index = u16_from_u8(left_class) * u16_from_u8(right_hand_classes_count) +
      u16_from_u8(right_class)
    let index = req(indices.get(index))
    kerning_values.get(u16_from_u8(index))
  } catch {
    _ => None
  }
}

///|
/// A [Kerning Table](https://docs.microsoft.com/en-us/typography/opentype/spec/kern).
pub(all) struct KernTable {
  /// A list of subtables.
  subtables : KernSubtables
}

///|
/// Parses a table from raw data.
pub fn KernTable::parse(data : BytesView) -> KernTable? {
  // The `kern` table has two variants: OpenType and Apple.
  // And they both have different headers.
  // There are no robust way to distinguish them, so we have to guess.
  //
  // The OpenType one has the first two bytes (UInt16) as a version set to 0.
  // While Apple one has the first four bytes (Fixed) set to 1.0
  // So the first two bytes in case of an OpenType format will be 0x0000
  // and 0x0001 in case of an Apple format.
  let s = Stream::new(data)
  try {
    let version = s.read_u16()
    let subtables : KernSubtables = if version == 0 {
      let count = s.read_u16()
      { is_aat: false, count: count.to_uint(), data: s.tail_r(), }
    } else {
      s.advance(2) // Skip the second part of u32 version.
      // Note that AAT stores the number of tables as u32 and not as u16.
      let count = s.read_u32()
      { is_aat: true, count, data: s.tail_r(), }
    }
    Some({ subtables, })
  } catch {
    _ => None
  }
}
