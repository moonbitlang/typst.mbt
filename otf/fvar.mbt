// [Font Variations](https://docs.microsoft.com/en-us/typography/opentype/spec/fvar),
// [Axis Variations](https://docs.microsoft.com/en-us/typography/opentype/spec/avar),
// [HVAR/VVAR](https://docs.microsoft.com/en-us/typography/opentype/spec/hvar) and
// [MVAR](https://docs.microsoft.com/en-us/typography/opentype/spec/mvar) tables.
//
// Port of `ttf-parser` 0.25.1 `src/tables/{fvar, avar, hvar, vvar, mvar}.rs`.

///|
/// A [variation axis](https://docs.microsoft.com/en-us/typography/opentype/spec/fvar#variationaxisrecord).
pub(all) struct VariationAxis {
  tag : Tag
  min_value : Float
  def_value : Float
  max_value : Float
  /// An axis name in the `name` table.
  name_id : UInt16
  hidden : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VariationAxis with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VariationAxis with @debug.Debug::{to_repr}

///|
pub impl FromData for VariationAxis with fn size() {
  20
}

///|
pub impl FromData for VariationAxis with fn parse(data) {
  let s = Stream::new(data)
  let tag : Tag = s.read()
  let min_value : Fixed = s.read()
  let def_value : Fixed = s.read()
  let max_value : Fixed = s.read()
  let flags = s.read_u16()
  let name_id = s.read_u16()
  {
    tag,
    min_value: f32_min_of(def_value.0, min_value.0),
    def_value: def_value.0,
    max_value: f32_max_of(def_value.0, max_value.0),
    name_id,
    hidden: ((flags >> 3) & 1) == 1,
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VariationAxis with FromData::{size, parse}

///|
/// Returns a normalized variation coordinate for this axis.
pub fn VariationAxis::normalized_value(
  self : VariationAxis,
  v : Float,
) -> NormalizedCoordinate {
  // Based on
  // https://docs.microsoft.com/en-us/typography/opentype/spec/avar#overview
  let mut v = f32_bound(self.min_value, v, self.max_value)
  if v == self.def_value {
    v = 0.0
  } else if v < self.def_value {
    v = (v - self.def_value) / (self.def_value - self.min_value)
  } else {
    v = (v - self.def_value) / (self.max_value - self.def_value)
  }
  NormalizedCoordinate::from_f32(v)
}

///|
/// A [Font Variations Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/fvar).
pub(all) struct FvarTable {
  /// A list of variation axes.
  axes : LazyArray16[VariationAxis]
}

///|
/// Parses a table from raw data.
pub fn FvarTable::parse(data : BytesView) -> FvarTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let axes_array_offset : Offset16 = s.read()
    s.advance(2) // reserved
    let axis_count = s.read_u16()

    // 'If axisCount is zero, then the font is not functional as a variable font,
    // and must be treated as a non-variable font;
    // any variation-specific tables or data is ignored.'
    if axis_count == 0 {
      return None
    }
    let s = Stream::new_at_r(data, axes_array_offset.to_usize())
    let axes = s.read_array16(axis_count)
    Some({ axes, })
  } catch {
    _ => None
  }
}

// ---------------------------------------------------------------------------
// avar

///|
/// An axis value map.
pub(all) struct AxisValueMap {
  /// A normalized coordinate value obtained using default normalization.
  from_coordinate : Int16
  /// The modified, normalized coordinate value.
  to_coordinate : Int16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AxisValueMap with @debug.Debug::{to_repr}

///|
pub impl FromData for AxisValueMap with fn size() {
  4
}

///|
pub impl FromData for AxisValueMap with fn parse(data) {
  let s = Stream::new(data)
  { from_coordinate: s.read(), to_coordinate: s.read(), }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AxisValueMap with FromData::{size, parse}

///|
/// A list of segment maps.
///
/// Can be empty.
///
/// The internal data layout is not designed for random access,
/// therefore we're not providing the `get()` method and only an iterator.
struct SegmentMaps {
  count : UInt16
  data : BytesView
}

///|
/// Returns the number of segments.
pub fn SegmentMaps::len(self : SegmentMaps) -> UInt16 {
  self.count
}

///|
/// Checks if there are any segments.
pub fn SegmentMaps::is_empty(self : SegmentMaps) -> Bool {
  self.count == 0
}

///|
/// An iterator over maps.
pub fn SegmentMaps::iter(self : SegmentMaps) -> Iter[LazyArray16[AxisValueMap]] {
  let stream = Stream::new(self.data)
  Iter::new(fn() {
    try {
      let count = stream.read_u16()
      Some(stream.read_array16(count))
    } catch {
      _ => None
    }
  })
}

///|
/// An [Axis Variations Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/avar).
pub(all) struct AvarTable {
  /// The segment maps array — one segment map for each axis
  /// in the order of axes specified in the `fvar` table.
  segment_maps : SegmentMaps
}

///|
/// Parses a table from raw data.
pub fn AvarTable::parse(data : BytesView) -> AvarTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    s.advance(2) // reserved
    // TODO: check that `axisCount` is the same as in `fvar`?
    let count = s.read_u16()
    Some({ segment_maps: { count, data: s.tail_r(), }, })
  } catch {
    _ => None
  }
}

///|
/// Maps a single coordinate
pub fn AvarTable::map_coordinate(
  self : AvarTable,
  coordinates : Array[NormalizedCoordinate],
  coordinate_index : Int,
) -> Unit? {
  if self.segment_maps.count.to_int() != coordinates.length() {
    return None
  }
  // `zip(...).nth(coordinate_index)`
  let mut i = 0
  for map in self.segment_maps.iter() {
    if i >= coordinates.length() {
      break
    }
    if i == coordinate_index {
      guard avar_map_value(map, coordinates[i].0) is Some(v) else {
        return None
      }
      coordinates[i] = NormalizedCoordinate::from_i16(v)
      break
    }
    i += 1
  }
  Some(())
}

///|
fn avar_map_value(map : LazyArray16[AxisValueMap], value : Int16) -> Int16? {
  // This code is based on harfbuzz implementation.
  if map.is_empty() {
    return Some(value)
  } else if map.len() == 1 {
    guard map.get(0) is Some(record) else { return None }
    return Some(value - record.from_coordinate + record.to_coordinate)
  }
  guard map.get(0) is Some(record_0) else { return None }
  if value <= record_0.from_coordinate {
    return Some(value - record_0.from_coordinate + record_0.to_coordinate)
  }
  let mut i : UInt16 = 1
  while i < map.len() {
    guard map.get(i) is Some(r) else { return None }
    if !(value > r.from_coordinate) {
      break
    }
    i += 1
  }
  if i == map.len() {
    i -= 1
  }
  guard map.get(i) is Some(record_curr) else { return None }
  let curr_from = record_curr.from_coordinate
  let curr_to = record_curr.to_coordinate
  if value >= curr_from {
    return Some(value - curr_from + curr_to)
  }
  guard map.get(i - 1) is Some(record_prev) else { return None }
  let prev_from = record_prev.from_coordinate
  let prev_to = record_prev.to_coordinate
  if prev_from == curr_from {
    return Some(prev_to)
  }
  let curr_from = curr_from.to_int()
  let curr_to = curr_to.to_int()
  let prev_from = prev_from.to_int()
  let prev_to = prev_to.to_int()
  let denom = curr_from - prev_from
  let k = (curr_to - prev_to) * (value.to_int() - prev_from) + denom / 2
  let value = prev_to + k / denom
  i16_try_from_int(value)
}

// ---------------------------------------------------------------------------
// HVAR

///|
/// A [Horizontal Metrics Variations Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/hvar).
struct HvarTable {
  data : BytesView
  variation_store : ItemVariationStore
  advance_width_mapping_offset : Offset32?
  lsb_mapping_offset : Offset32?
  rsb_mapping_offset : Offset32?
}

///|
/// Parses a table from raw data.
pub fn HvarTable::parse(data : BytesView) -> HvarTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let variation_store_offset : Offset32 = s.read()
    let var_store_s = Stream::new_at_r(data, variation_store_offset.to_usize())
    let variation_store = req(ItemVariationStore::parse(var_store_s))
    Some({
      data,
      variation_store,
      advance_width_mapping_offset: s.read(),
      lsb_mapping_offset: s.read(),
      rsb_mapping_offset: s.read(),
    })
  } catch {
    _ => None
  }
}

///|
/// Returns the advance width offset for a glyph.
pub fn HvarTable::advance_offset(
  self : HvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  let (outer_idx, inner_idx) = if self.advance_width_mapping_offset
    is Some(offset) {
    guard slice_from(self.data, offset.to_usize()) is Some(d) else {
      return None
    }
    guard DeltaSetIndexMap::new(d).map(glyph_id.0.to_uint()) is Some(m) else {
      return None
    }
    m
  } else {
    // 'If there is no delta-set index mapping table for advance widths,
    // then glyph IDs implicitly provide the indices:
    // for a given glyph ID, the delta-set outer-level index is zero,
    // and the glyph ID is the delta-set inner-level index.'
    (0, glyph_id.0)
  }
  self.variation_store.parse_delta(outer_idx, inner_idx, coordinates)
}

///|
/// Returns the left side bearing offset for a glyph.
pub fn HvarTable::left_side_bearing_offset(
  self : HvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  guard self.lsb_mapping_offset is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(set_data) else {
    return None
  }
  var_side_bearing_offset(self.variation_store, glyph_id, coordinates, set_data)
}

///|
/// Returns the right side bearing offset for a glyph.
pub fn HvarTable::right_side_bearing_offset(
  self : HvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  guard self.rsb_mapping_offset is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(set_data) else {
    return None
  }
  var_side_bearing_offset(self.variation_store, glyph_id, coordinates, set_data)
}

///|
fn var_side_bearing_offset(
  variation_store : ItemVariationStore,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
  set_data : BytesView,
) -> Float? {
  guard DeltaSetIndexMap::new(set_data).map(glyph_id.0.to_uint())
    is Some((outer_idx, inner_idx)) else {
    return None
  }
  variation_store.parse_delta(outer_idx, inner_idx, coordinates)
}

// ---------------------------------------------------------------------------
// VVAR

///|
/// A [Vertical Metrics Variations Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/hvar).
struct VvarTable {
  data : BytesView
  variation_store : ItemVariationStore
  advance_height_mapping_offset : Offset32?
  tsb_mapping_offset : Offset32?
  bsb_mapping_offset : Offset32?
  vorg_mapping_offset : Offset32?
}

///|
/// Parses a table from raw data.
pub fn VvarTable::parse(data : BytesView) -> VvarTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let variation_store_offset : Offset32 = s.read()
    let var_store_s = Stream::new_at_r(data, variation_store_offset.to_usize())
    let variation_store = req(ItemVariationStore::parse(var_store_s))
    Some({
      data,
      variation_store,
      advance_height_mapping_offset: s.read(),
      tsb_mapping_offset: s.read(),
      bsb_mapping_offset: s.read(),
      vorg_mapping_offset: s.read(),
    })
  } catch {
    _ => None
  }
}

///|
/// Returns the advance height offset for a glyph.
pub fn VvarTable::advance_offset(
  self : VvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  let (outer_idx, inner_idx) = if self.advance_height_mapping_offset
    is Some(offset) {
    guard slice_from(self.data, offset.to_usize()) is Some(d) else {
      return None
    }
    guard DeltaSetIndexMap::new(d).map(glyph_id.0.to_uint()) is Some(m) else {
      return None
    }
    m
  } else {
    // 'If there is no delta-set index mapping table for advance widths,
    // then glyph IDs implicitly provide the indices:
    // for a given glyph ID, the delta-set outer-level index is zero,
    // and the glyph ID is the delta-set inner-level index.'
    (0, glyph_id.0)
  }
  self.variation_store.parse_delta(outer_idx, inner_idx, coordinates)
}

///|
/// Returns the top side bearing offset for a glyph.
pub fn VvarTable::top_side_bearing_offset(
  self : VvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  guard self.tsb_mapping_offset is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(set_data) else {
    return None
  }
  var_side_bearing_offset(self.variation_store, glyph_id, coordinates, set_data)
}

///|
/// Returns the bottom side bearing offset for a glyph.
pub fn VvarTable::bottom_side_bearing_offset(
  self : VvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  guard self.bsb_mapping_offset is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(set_data) else {
    return None
  }
  var_side_bearing_offset(self.variation_store, glyph_id, coordinates, set_data)
}

///|
/// Returns the vertical origin offset for a glyph.
pub fn VvarTable::vertical_origin_offset(
  self : VvarTable,
  glyph_id : GlyphId,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  guard self.vorg_mapping_offset is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(set_data) else {
    return None
  }
  var_side_bearing_offset(self.variation_store, glyph_id, coordinates, set_data)
}

// ---------------------------------------------------------------------------
// MVAR

///|
priv struct MvarValueRecord {
  value_tag : Tag
  delta_set_outer_index : UInt16
  delta_set_inner_index : UInt16
}

///|
impl FromData for MvarValueRecord with fn size() {
  8
}

///|
impl FromData for MvarValueRecord with fn parse(data) {
  let s = Stream::new(data)
  {
    value_tag: s.read(),
    delta_set_outer_index: s.read(),
    delta_set_inner_index: s.read(),
  }
}

///|
/// A [Metrics Variations Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/mvar).
struct MvarTable {
  variation_store : ItemVariationStore
  records : LazyArray16[MvarValueRecord]
}

///|
/// Parses a table from raw data.
pub fn MvarTable::parse(data : BytesView) -> MvarTable? {
  try {
    let s = Stream::new(data)
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    s.advance(2) // reserved
    let value_record_size = s.read_u16()
    if value_record_size.to_int() != 8 {
      return None
    }
    let count = s.read_u16()
    if count == 0 {
      return None
    }
    let var_store_offset = (req(s.read()) : Offset16).to_usize()
    let records = s.read_array16(count)
    let variation_store = req(
      ItemVariationStore::parse(Stream::new_at_r(data, var_store_offset)),
    )
    Some({ variation_store, records, })
  } catch {
    _ => None
  }
}

///|
/// Returns a metric offset by tag.
pub fn MvarTable::metric_offset(
  self : MvarTable,
  tag : Tag,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  guard self.records.binary_search_by(r => r.value_tag.compare(tag))
    is Some((_, record)) else {
    return None
  }
  self.variation_store.parse_delta(
    record.delta_set_outer_index,
    record.delta_set_inner_index,
    coordinates,
  )
}
