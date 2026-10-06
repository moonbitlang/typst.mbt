// A [Style Attributes Table](https://docs.microsoft.com/en-us/typography/opentype/spec/stat) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/stat.rs`. Public types get a `Stat`
// prefix (`stat::AxisValue` -> `StatAxisValue`, ...).

///|
/// Axis-value pairing for [`StatAxisValueSubtableFormat4`].
pub(all) struct StatAxisValue {
  /// Zero-based index into [`StatTable::axes`].
  axis_index : UInt16
  /// Numeric value for this axis.
  value : Fixed
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValue with @debug.Debug::{to_repr}

///|
pub impl FromData for StatAxisValue with fn size() {
  6
}

///|
pub impl FromData for StatAxisValue with fn parse(data) {
  let s = Stream::new(data)
  let axis_index = s.read_u16()
  let value : Fixed = s.read()
  { axis_index, value, }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValue with FromData::{size, parse}

///|
/// Iterator over axis value subtables.
struct StatAxisValueSubtables {
  data : Stream
  start : Offset32
  offsets : LazyArray16[Offset16]
  mut index : UInt16
  version : UInt
}

///|
/// Copies the iterator (Rust's `Clone`).
pub fn StatAxisValueSubtables::copy(
  self : StatAxisValueSubtables,
) -> StatAxisValueSubtables {
  { ..self, data: self.data.copy(), }
}

///|
/// Returns the next subtable.
pub fn StatAxisValueSubtables::next(
  self : StatAxisValueSubtables,
) -> StatAxisValueSubtable? {
  if self.index >= self.offsets.len() {
    return None
  }
  try {
    let s = Stream::new_at_r(
      self.data.tail_r(),
      req(self.offsets.get(self.index)).to_usize() + self.start.to_usize(),
    )
    self.index += 1
    let format_variant = s.read_u16()
    let value : StatAxisValueSubtable = match format_variant {
      1 => {
        let value : StatAxisValueSubtableFormat1 = s.read()
        Format1(value)
      }
      2 => {
        let value : StatAxisValueSubtableFormat2 = s.read()
        Format2(value)
      }
      3 => {
        let value : StatAxisValueSubtableFormat3 = s.read()
        Format3(value)
      }
      4 => {
        // Format 4 tables didn't exist until v1.2.
        if self.version < 0x00010002 {
          return None
        }
        let value = StatAxisValueSubtableFormat4::parse(s.tail_r())
        Format4(value)
      }
      _ => return None
    }
    Some(value)
  } catch {
    _ => None
  }
}

///|
/// Iterates over the remaining subtables.
pub fn StatAxisValueSubtables::iter(
  self : StatAxisValueSubtables,
) -> Iter[StatAxisValueSubtable] {
  Iter::new(() => self.next())
}

///|
/// The [axis record](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#axis-records) struct provides information about a single design axis.
pub(all) struct StatAxisRecord {
  /// Axis tag.
  tag : Tag
  /// The name ID for entries in the 'name' table that provide a display string for this axis.
  name_id : UInt16
  /// Sort order for e.g. composing font family or face names.
  ordering : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisRecord with @debug.Debug::{to_repr}

///|
pub impl FromData for StatAxisRecord with fn size() {
  8
}

///|
pub impl FromData for StatAxisRecord with fn parse(data) {
  let s = Stream::new(data)
  { tag: s.read(), name_id: s.read(), ordering: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisRecord with FromData::{size, parse}

///|
/// [Flags](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#flags) for [`StatAxisValueSubtable`].
pub(all) struct StatAxisValueFlags(UInt16)

///|
/// If set, this value also applies to older versions of this font.
pub fn StatAxisValueFlags::older_sibling_attribute(
  self : StatAxisValueFlags,
) -> Bool {
  (self.0 & (1 << 0)) != 0
}

///|
/// If set, this value is the normal (a.k.a. "regular") value for the font family.
pub fn StatAxisValueFlags::elidable(self : StatAxisValueFlags) -> Bool {
  (self.0 & (1 << 1)) != 0
}

///|
pub impl Debug for StatAxisValueFlags with fn to_repr(self) {
  let entries = []
  if self.older_sibling_attribute() {
    entries.push(Repr::string("OLDER_SIBLING_FONT_ATTRIBUTE"))
  }
  if self.elidable() {
    entries.push(Repr::string("ELIDABLE_AXIS_VALUE_NAME"))
  }
  Repr::array(entries)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueFlags with @debug.Debug::{to_repr}

///|
/// Axis value subtable [format 1](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#axis-value-table-format-1).
pub(all) struct StatAxisValueSubtableFormat1 {
  /// Zero-based index into [`StatTable::axes`].
  axis_index : UInt16
  /// Flags for [`StatAxisValueSubtable`].
  flags : StatAxisValueFlags
  /// The name ID of the display string.
  value_name_id : UInt16
  /// Numeric value for this record.
  value : Fixed
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueSubtableFormat1 with @debug.Debug::{to_repr}

///|
pub impl FromData for StatAxisValueSubtableFormat1 with fn size() {
  10
}

///|
pub impl FromData for StatAxisValueSubtableFormat1 with fn parse(data) {
  let s = Stream::new(data)
  {
    axis_index: s.read(),
    flags: StatAxisValueFlags(s.read()),
    value_name_id: s.read(),
    value: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueSubtableFormat1 with FromData::{size, parse}

///|
/// Axis value subtable [format 2](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#axis-value-table-format-2).
pub(all) struct StatAxisValueSubtableFormat2 {
  /// Zero-based index into [`StatTable::axes`].
  axis_index : UInt16
  /// Flags for [`StatAxisValueSubtable`].
  flags : StatAxisValueFlags
  /// The name ID of the display string.
  value_name_id : UInt16
  /// Nominal numeric value for this record.
  nominal_value : Fixed
  /// The minimum value for this record.
  range_min_value : Fixed
  /// The maximum value for this record.
  range_max_value : Fixed
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueSubtableFormat2 with @debug.Debug::{to_repr}

///|
pub impl FromData for StatAxisValueSubtableFormat2 with fn size() {
  18
}

///|
pub impl FromData for StatAxisValueSubtableFormat2 with fn parse(data) {
  let s = Stream::new(data)
  {
    axis_index: s.read(),
    flags: StatAxisValueFlags(s.read()),
    value_name_id: s.read(),
    nominal_value: s.read(),
    range_min_value: s.read(),
    range_max_value: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueSubtableFormat2 with FromData::{size, parse}

///|
/// Axis value subtable [format 3](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#axis-value-table-format-3).
pub(all) struct StatAxisValueSubtableFormat3 {
  /// Zero-based index into [`StatTable::axes`].
  axis_index : UInt16
  /// Flags for [`StatAxisValueSubtable`].
  flags : StatAxisValueFlags
  /// The name ID of the display string.
  value_name_id : UInt16
  /// Numeric value for this record.
  value : Fixed
  /// Numeric value for a style-linked mapping.
  linked_value : Fixed
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueSubtableFormat3 with @debug.Debug::{to_repr}

///|
pub impl FromData for StatAxisValueSubtableFormat3 with fn size() {
  14
}

///|
pub impl FromData for StatAxisValueSubtableFormat3 with fn parse(data) {
  let s = Stream::new(data)
  {
    axis_index: s.read(),
    flags: StatAxisValueFlags(s.read()),
    value_name_id: s.read(),
    value: s.read(),
    linked_value: s.read(),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StatAxisValueSubtableFormat3 with FromData::{size, parse}

///|
/// Axis value subtable [format 4](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#axis-value-table-format-4).
pub(all) struct StatAxisValueSubtableFormat4 {
  /// Flags for [`StatAxisValueSubtable`].
  flags : StatAxisValueFlags
  /// The name ID of the display string.
  value_name_id : UInt16
  /// List of axis-value pairings.
  values : LazyArray16[StatAxisValue]
}

///|
fn StatAxisValueSubtableFormat4::parse(
  data : BytesView,
) -> StatAxisValueSubtableFormat4 raise Malformed {
  let s = Stream::new(data)
  let axis_count = s.read_u16()
  let flags = StatAxisValueFlags(s.read_u16())
  let value_name_id = s.read_u16()
  let values = s.read_array16(axis_count)
  { flags, value_name_id, values, }
}

///|
/// An [axis value subtable](https://learn.microsoft.com/en-us/typography/opentype/spec/stat#axis-value-tables).
pub(all) enum StatAxisValueSubtable {
  Format1(StatAxisValueSubtableFormat1)
  Format2(StatAxisValueSubtableFormat2)
  Format3(StatAxisValueSubtableFormat3)
  Format4(StatAxisValueSubtableFormat4)
}

///|
/// Returns the value from an axis value subtable.
///
/// For formats 1 and 3 the value is returned, for formats 2 and 4 `None` is returned as there
/// is no single value associated with those formats.
pub fn StatAxisValueSubtable::value(self : StatAxisValueSubtable) -> Fixed? {
  match self {
    Format1({ value, .. }) => Some(value)
    Format3({ value, .. }) => Some(value)
    _ => None
  }
}

///|
/// Returns `true` if the axis subtable either is the value or is a range that contains the
/// value passed in as an argument.
///
/// Note: this will always return false for format 4 subtables as they may contain multiple
/// axes.
pub fn StatAxisValueSubtable::contains(
  self : StatAxisValueSubtable,
  value : Fixed,
) -> Bool {
  if self.value() is Some(subtable_value) {
    if subtable_value.0 == value.0 {
      return true
    }
  }
  if self is Format2({ range_min_value, range_max_value, .. }) {
    if value.0 >= range_min_value.0 && value.0 < range_max_value.0 {
      return true
    }
  }
  false
}

///|
/// Returns the associated name ID.
pub fn StatAxisValueSubtable::name_id(self : StatAxisValueSubtable) -> UInt16 {
  match self {
    Format1({ value_name_id, .. }) => value_name_id
    Format2({ value_name_id, .. }) => value_name_id
    Format3({ value_name_id, .. }) => value_name_id
    Format4({ value_name_id, .. }) => value_name_id
  }
}

///|
fn StatAxisValueSubtable::flags(
  self : StatAxisValueSubtable,
) -> StatAxisValueFlags {
  match self {
    Format1({ flags, .. }) => flags
    Format2({ flags, .. }) => flags
    Format3({ flags, .. }) => flags
    Format4({ flags, .. }) => flags
  }
}

///|
/// Returns `true` if the axis subtable has the `ELIDABLE_AXIS_VALUE_NAME` flag set.
pub fn StatAxisValueSubtable::is_elidable(self : StatAxisValueSubtable) -> Bool {
  self.flags().elidable()
}

///|
/// Returns `true` if the axis subtable has the `OLDER_SIBLING_FONT_ATTRIBUTE` flag set.
pub fn StatAxisValueSubtable::is_older_sibling(
  self : StatAxisValueSubtable,
) -> Bool {
  self.flags().older_sibling_attribute()
}

///|
/// A [Style Attributes Table](https://docs.microsoft.com/en-us/typography/opentype/spec/stat).
pub struct StatTable {
  /// List of axes
  axes : LazyArray16[StatAxisRecord]
  /// Fallback name when everything can be elided.
  fallback_name_id : UInt16?
  version : UInt
  data : BytesView
  value_lookup_start : Offset32
  value_offsets : LazyArray16[Offset16]
}

///|
/// Parses a table from raw data.
pub fn StatTable::parse(data : BytesView) -> StatTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u32()

    // Supported versions are:
    // - 1.0
    // - 1.1 adds elidedFallbackNameId
    // - 1.2 adds format 4 axis value table
    if !(version == 0x00010000 || version == 0x00010001 || version == 0x00010002) {
      return None
    }
    let _axis_size = s.read_u16()
    let axis_count = s.read_u16()
    let axis_offset = (s.read() : Offset32).to_usize()
    let value_count = s.read_u16()
    let value_lookup_start : Offset32 = s.read()
    let fallback_name_id = if version >= 0x00010001 {
      // If version >= 1.1 the field is required
      Some(s.read_u16())
    } else {
      None
    }
    let s = Stream::new_at_r(data, axis_offset)
    let axes = s.read_array16(axis_count)
    let s = Stream::new_at_r(data, value_lookup_start.to_usize())
    let value_offsets = s.read_array16(value_count)
    Some({
      axes,
      data,
      value_lookup_start,
      value_offsets,
      fallback_name_id,
      version,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns an iterator over the collection of axis value tables.
pub fn StatTable::subtables(self : StatTable) -> StatAxisValueSubtables {
  {
    data: Stream::new(self.data),
    start: self.value_lookup_start,
    offsets: self.value_offsets,
    index: 0,
    version: self.version,
  }
}

///|
/// Returns the first matching subtable for a given axis.
///
/// If no match value is given the first subtable for the axis is returned. If a match value is
/// given, the first subtable for the axis where the value matches is returned. A value matches
/// if it is equal to the subtable's value or contained within the range defined by the
/// subtable. If no matches are found `None` is returned. Typically a match value is not
/// specified for non-variable fonts as multiple subtables for a given axis ought not exist. For
/// variable fonts a non-`None` match value should be specified as multiple records for each of
/// the variation axes exist.
///
/// Note: Format 4 subtables are explicitly ignored in this function.
pub fn StatTable::subtable_for_axis(
  self : StatTable,
  axis : Tag,
  match_value : Fixed?,
) -> StatAxisValueSubtable? {
  let it = self.subtables()
  while it.next() is Some(subtable) {
    let (axis_index, value) = match subtable {
      Format1({ axis_index, value, .. }) => (axis_index, value)
      Format3({ axis_index, value, .. }) => (axis_index, value)
      Format2({ axis_index, range_min_value, range_max_value, .. }) => {
        guard self.axes.get(axis_index) is Some(rec) else { return None }
        // NOTE: upstream compares with `==` here (sic).
        if rec.tag == axis {
          continue
        }
        match match_value {
          Some(match_value) =>
            if match_value.0 >= range_min_value.0 &&
              match_value.0 < range_max_value.0 {
              return Some(subtable)
            }
          None => return Some(subtable)
        }
        continue
      }
      Format4(_) =>
        // A query that's intended to search format 4 subtables can be performed
        // across multiple axes. A separate function that takes a collection of
        // axis-value pairs is more suitable than this.
        continue
    }
    // Formats 1 and 3.
    guard self.axes.get(axis_index) is Some(rec) else { return None }
    if rec.tag != axis {
      continue
    }
    match match_value {
      Some(match_value) => if match_value.0 == value.0 { return Some(subtable) }
      None => return Some(subtable)
    }
  }
  None
}
