// Implementation of Item Variation Store
//
// <https://docs.microsoft.com/en-us/typography/opentype/spec/otvarcommonformats#item-variation-store>
//
// Port of `ttf-parser` 0.25.1 `src/var_store.rs` and `src/delta_set.rs`.

///|
struct ItemVariationStore {
  data : BytesView
  data_offsets : LazyArray16[UInt]
  regions : VariationRegionList
}

///|
pub impl Default for ItemVariationStore with fn default() {
  {
    data: empty_data,
    data_offsets: LazyArray16::default(),
    regions: { axis_count: 0, regions: LazyArray16::default(), },
  }
}

///|
/// Parses an item variation store starting at the stream's position.
pub fn ItemVariationStore::parse(s : Stream) -> ItemVariationStore? {
  let s = s.copy()
  try {
    let data = s.tail_r()
    let regions_s = s.copy()
    let format = s.read_u16()
    if format != 1 {
      return None
    }
    let region_list_offset = s.read_u32()
    let count = s.read_u16()
    let offsets = s.read_array16(count)
    let regions : VariationRegionList = {
      regions_s.advance(region_list_offset.reinterpret_as_int())
      // TODO: should be the same as in `fvar`
      let axis_count = regions_s.read_u16()
      let count = regions_s.read_u16()
      let total = req(u16_checked_mul(count, axis_count))
      { axis_count, regions: regions_s.read_array16(total), }
    }
    Some({ data, data_offsets: offsets, regions, })
  } catch {
    _ => None
  }
}

///|
/// Returns the region indices of an item variation data subtable.
pub fn ItemVariationStore::region_indices(
  self : ItemVariationStore,
  index : UInt16,
) -> LazyArray16[UInt16]? {
  try {
    // Offsets in bytes from the start of the item variation store
    // to each item variation data subtable.
    let offset = req(self.data_offsets.get(index))
    let s = Stream::new_at_r(self.data, offset.reinterpret_as_int())
    s.advance(2) // item_count
    s.advance(2) // short_delta_count
    let count = s.read_u16()
    Some(s.read_array16(count))
  } catch {
    _ => None
  }
}

///|
/// Computes a delta for the given coordinates.
pub fn ItemVariationStore::parse_delta(
  self : ItemVariationStore,
  outer_index : UInt16,
  inner_index : UInt16,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float? {
  try {
    let offset = req(self.data_offsets.get(outer_index))
    let s = Stream::new_at_r(self.data, offset.reinterpret_as_int())
    let item_count = s.read_u16()
    let word_delta_count = s.read_u16()
    let region_index_count = s.read_u16()
    let region_indices : LazyArray16[UInt16] = s.read_array16(
      region_index_count,
    )
    if inner_index >= item_count {
      return None
    }
    let has_long_words = (word_delta_count & 0x8000) != 0
    let word_delta_count = word_delta_count & 0x7FFF

    // From the spec: The length of the data for each row, in bytes, is
    // regionIndexCount + (wordDeltaCount & WORD_DELTA_COUNT_MASK)
    // if the LONG_WORDS flag is not set, or 2 x that amount if the flag is set.
    let mut delta_set_len = word_delta_count + region_index_count
    if has_long_words {
      delta_set_len *= 2
    }
    s.advance(inner_index.to_int() * delta_set_len.to_int())
    let mut delta : Float = 0.0
    let mut i : UInt16 = 0
    while i < word_delta_count {
      let idx = req(region_indices.get(i))
      let num = if has_long_words {
        // TODO: use f64?
        Float::from_int(s.read_i32())
      } else {
        Float::from_int(s.read_i16().to_int())
      }
      delta += num * self.regions.evaluate_region(idx, coordinates)
      i += 1
    }
    while i < region_index_count {
      let idx = req(region_indices.get(i))
      let num = if has_long_words {
        Float::from_int(s.read_i16().to_int())
      } else {
        Float::from_int(s.read_i8())
      }
      delta += num * self.regions.evaluate_region(idx, coordinates)
      i += 1
    }
    Some(delta)
  } catch {
    _ => None
  }
}

///|
struct VariationRegionList {
  axis_count : UInt16
  regions : LazyArray16[RegionAxisCoordinatesRecord]
}

///|
/// Evaluates a region's scalar for the given coordinates.
pub fn VariationRegionList::evaluate_region(
  self : VariationRegionList,
  index : UInt16,
  coordinates : ArrayView[NormalizedCoordinate],
) -> Float {
  let mut v : Float = 1.0
  for i, coord in coordinates {
    let region = match
      self.regions.get(index * self.axis_count + i.to_uint16()) {
      Some(r) => r
      None => return 0.0
    }
    let factor = region.evaluate_axis(coord.get())
    if factor == 0.0 {
      return 0.0
    }
    v *= factor
  }
  v
}

///|
priv struct RegionAxisCoordinatesRecord {
  start_coord : Int16
  peak_coord : Int16
  end_coord : Int16
}

///|
fn RegionAxisCoordinatesRecord::evaluate_axis(
  self : RegionAxisCoordinatesRecord,
  coord : Int16,
) -> Float {
  let start = self.start_coord
  let peak = self.peak_coord
  let end = self.end_coord
  if start > peak || peak > end {
    return 1.0
  }
  if start < 0 && end > 0 && peak != 0 {
    return 1.0
  }
  if peak == 0 || coord == peak {
    return 1.0
  }
  if coord <= start || end <= coord {
    return 0.0
  }
  if coord < peak {
    Float::from_int((coord - start).to_int()) /
    Float::from_int((peak - start).to_int())
  } else {
    Float::from_int((end - coord).to_int()) /
    Float::from_int((end - peak).to_int())
  }
}

///|
impl FromData for RegionAxisCoordinatesRecord with fn size() {
  6
}

///|
impl FromData for RegionAxisCoordinatesRecord with fn parse(data) {
  let s = Stream::new(data)
  { start_coord: s.read(), peak_coord: s.read(), end_coord: s.read(), }
}

///|
struct DeltaSetIndexMap {
  data : BytesView
}

///|
/// Creates a new delta-set index map.
pub fn DeltaSetIndexMap::new(data : BytesView) -> DeltaSetIndexMap {
  { data, }
}

///|
/// Maps an index to an `(outer, inner)` index pair.
pub fn DeltaSetIndexMap::map(
  self : DeltaSetIndexMap,
  index : UInt,
) -> (UInt16, UInt16)? {
  let s = Stream::new(self.data)
  try {
    let format = s.read_u8()
    let entry_format = s.read_u8()
    let map_count = if format == 0 {
      s.read_u16().to_uint()
    } else {
      s.read_u32()
    }
    if map_count == 0 {
      return None
    }

    // 'If a given glyph ID is greater than mapCount-1, then the last entry is used.'
    let index = if index >= map_count { map_count - 1 } else { index }
    let entry_size = ((entry_format.to_int() >> 4) & 3) + 1
    let inner_index_bit_count = (entry_format.to_int() & 0xF) + 1
    let index = index.reinterpret_as_int()
    if index < 0 {
      return None
    }
    s.advance(entry_size * index)
    let mut n : UInt = 0
    let bytes = s.read_bytes(entry_size)
    for b in bytes {
      n = (n << 8) + b.to_uint()
    }
    let outer_index = n >> inner_index_bit_count
    let inner_index = n & ((1U << inner_index_bit_count) - 1)
    Some(
      (req(u16_try_from_u32(outer_index)), req(u16_try_from_u32(inner_index))),
    )
  } catch {
    _ => None
  }
}
