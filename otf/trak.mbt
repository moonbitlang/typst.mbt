// A [Tracking Table](
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6trak.html) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/trak.rs`.

///|
priv struct TrackTableRecord {
  value : Fixed
  name_id : UInt16
  offset : Offset16 // Offset from start of the table.
}

///|
impl FromData for TrackTableRecord with fn size() {
  8
}

///|
impl FromData for TrackTableRecord with fn parse(data) {
  let s = Stream::new(data)
  { value: s.read(), name_id: s.read(), offset: s.read(), }
}

///|
/// A single track.
pub(all) struct Track {
  /// A track value.
  value : Float
  /// The `name` table index for the track's name.
  name_index : UInt16
  /// A list of tracking values for each size.
  values : LazyArray16[Int16]
}

///|
/// A list of tracks.
struct Tracks {
  data : BytesView // the whole table
  records : LazyArray16[TrackTableRecord]
  sizes_count : UInt16
}

///|
pub impl Default for Tracks with fn default() {
  { data: empty_data, records: LazyArray16::default(), sizes_count: 0, }
}

///|
/// Returns a track at index.
pub fn Tracks::get(self : Tracks, index : UInt16) -> Track? {
  guard self.records.get(index) is Some(record) else { return None }
  guard slice_from(self.data, record.offset.to_usize()) is Some(data) else {
    return None
  }
  let s = Stream::new(data)
  Some({
    value: record.value.0,
    values: s.read_array16(self.sizes_count),
    name_index: record.name_id,
  }) catch {
    _ => None
  }
}

///|
/// Returns the number of tracks.
pub fn Tracks::len(self : Tracks) -> UInt16 {
  self.records.len()
}

///|
/// Checks if there are any tracks.
pub fn Tracks::is_empty(self : Tracks) -> Bool {
  self.records.is_empty()
}

///|
/// Returns an iterator over the tracks.
pub fn Tracks::into_iter(self : Tracks) -> TracksIter {
  { tracks: self, index: 0, }
}

///|
/// Iterates over the tracks.
pub fn Tracks::iter(self : Tracks) -> Iter[Track] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over [`Tracks`].
struct TracksIter {
  tracks : Tracks
  mut index : UInt16
}

///|
/// Returns the next track.
pub fn TracksIter::next(self : TracksIter) -> Track? {
  if self.index < self.tracks.len() {
    self.index += 1
    self.tracks.get(self.index - 1)
  } else {
    None
  }
}

///|
/// A track data.
pub(all) struct TrackData {
  /// A list of tracks.
  tracks : Tracks
  /// A list of sizes.
  sizes : LazyArray16[Fixed]
}

///|
pub impl Default for TrackData with fn default() {
  { tracks: Default::default(), sizes: LazyArray16::default(), }
}

///|
fn TrackData::parse(
  offset : Int,
  data : BytesView,
) -> TrackData raise Malformed {
  let s = Stream::new_at_r(data, offset)
  let tracks_count = s.read_u16()
  let sizes_count = s.read_u16()
  let size_table_offset : Offset32 = s.read() // Offset from start of the table.
  let tracks : Tracks = {
    data,
    records: s.read_array16(tracks_count),
    sizes_count,
  }

  // TODO: Isn't the size table is directly after the tracks table?!
  //       Why we need an offset then?
  let sizes = {
    let s = Stream::new_at_r(data, size_table_offset.to_usize())
    s.read_array16(sizes_count)
  }
  { tracks, sizes, }
}

///|
/// A [Tracking Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6trak.html).
pub(all) struct TrakTable {
  /// Horizontal track data.
  horizontal : TrackData
  /// Vertical track data.
  vertical : TrackData
}

///|
/// Parses a table from raw data.
pub fn TrakTable::parse(data : BytesView) -> TrakTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let format = s.read_u16()
    if format != 0 {
      return None
    }
    let hor_offset : Offset16? = s.read()
    let ver_offset : Offset16? = s.read()
    s.advance(2) // reserved
    let horizontal = match hor_offset {
      Some(offset) => TrackData::parse(offset.to_usize(), data)
      None => Default::default()
    }
    let vertical = match ver_offset {
      Some(offset) => TrackData::parse(offset.to_usize(), data)
      None => Default::default()
    }
    Some({ horizontal, vertical, })
  } catch {
    _ => None
  }
}
