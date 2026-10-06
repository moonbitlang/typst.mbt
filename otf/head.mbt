// A [Font Header Table](https://docs.microsoft.com/en-us/typography/opentype/spec/head)
// implementation.

///|
/// An index format used by the [Index to Location Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/loca).
pub(all) enum IndexToLocationFormat {
  Short
  Long
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IndexToLocationFormat with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IndexToLocationFormat with @debug.Debug::{to_repr}

///|
/// A [Font Header Table](https://docs.microsoft.com/en-us/typography/opentype/spec/head).
pub(all) struct HeadTable {
  /// Units per EM.
  ///
  /// Guarantee to be in a 16..=16384 range.
  units_per_em : UInt16
  /// A bounding box that large enough to enclose any glyph from the face.
  global_bbox : Rect
  /// An index format used by the [Index to Location Table](
  /// https://docs.microsoft.com/en-us/typography/opentype/spec/loca).
  index_to_location_format : IndexToLocationFormat
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend HeadTable with @debug.Debug::{to_repr}

///|
/// Parses a table from raw data.
pub fn HeadTable::parse(data : BytesView) -> HeadTable? {
  // Do not check the exact length, because some fonts include
  // padding in table's length in table records, which is incorrect.
  if data.length() < 54 {
    return None
  }
  let s = Stream::new(data)
  s.advance(4) // version
  s.advance(4) // font revision
  s.advance(4) // checksum adjustment
  s.advance(4) // magic number
  s.advance(2) // flags
  let units_per_em = s.read_u16() catch { _ => return None }
  s.advance(8) // created time
  s.advance(8) // modified time
  let (x_min, y_min, x_max, y_max) = (
    s.read_i16(),
    s.read_i16(),
    s.read_i16(),
    s.read_i16(),
  ) catch {
    _ => return None
  }
  s.advance(2) // mac style
  s.advance(2) // lowest PPEM
  s.advance(2) // font direction hint
  let index_to_location_format = s.read_u16() catch { _ => return None }
  if !(units_per_em >= 16 && units_per_em <= 16384) {
    return None
  }
  let index_to_location_format : IndexToLocationFormat = match
    index_to_location_format {
    0 => Short
    1 => Long
    _ => return None
  }
  Some({
    units_per_em,
    global_bbox: { x_min, y_min, x_max, y_max, },
    index_to_location_format,
  })
}

///|
/// A [Horizontal Header Table](https://docs.microsoft.com/en-us/typography/opentype/spec/hhea).
pub(all) struct HheaTable {
  /// Face ascender.
  ascender : Int16
  /// Face descender.
  descender : Int16
  /// Face line gap.
  line_gap : Int16
  /// Number of metrics in the `hmtx` table.
  number_of_metrics : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend HheaTable with @debug.Debug::{to_repr}

///|
/// Parses a table from raw data.
pub fn HheaTable::parse(data : BytesView) -> HheaTable? {
  // Do not check the exact length, because some fonts include
  // padding in table's length in table records, which is incorrect.
  if data.length() < 36 {
    return None
  }
  let s = Stream::new(data)
  s.advance(4) // version
  try {
    let ascender = s.read_i16()
    let descender = s.read_i16()
    let line_gap = s.read_i16()
    s.advance(24)
    let number_of_metrics = s.read_u16()
    Some({ ascender, descender, line_gap, number_of_metrics, })
  } catch {
    _ => None
  }
}

///|
/// A [Vertical Header Table](https://docs.microsoft.com/en-us/typography/opentype/spec/vhea).
pub(all) struct VheaTable {
  /// Face ascender.
  ascender : Int16
  /// Face descender.
  descender : Int16
  /// Face line gap.
  line_gap : Int16
  /// Number of metrics in the `vmtx` table.
  number_of_metrics : UInt16
} derive(Debug, Default)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VheaTable with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend VheaTable with Default::{default}

///|
/// Parses a table from raw data.
pub fn VheaTable::parse(data : BytesView) -> VheaTable? {
  // Do not check the exact length, because some fonts include
  // padding in table's length in table records, which is incorrect.
  if data.length() < 36 {
    return None
  }
  let s = Stream::new(data)
  s.advance(4) // version
  try {
    let ascender = s.read_i16()
    let descender = s.read_i16()
    let line_gap = s.read_i16()
    s.advance(24)
    let number_of_metrics = s.read_u16()
    Some({ ascender, descender, line_gap, number_of_metrics, })
  } catch {
    _ => None
  }
}

///|
/// A [Maximum Profile Table](https://docs.microsoft.com/en-us/typography/opentype/spec/maxp).
pub(all) struct MaxpTable {
  /// The total number of glyphs in the face (never zero).
  number_of_glyphs : UInt16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaxpTable with @debug.Debug::{to_repr}

///|
/// Parses a table from raw data.
pub fn MaxpTable::parse(data : BytesView) -> MaxpTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u32()
    if !(version == 0x00005000 || version == 0x00010000) {
      return None
    }
    let n = s.read_u16()
    if n == 0 {
      return None
    }
    Some({ number_of_glyphs: n, })
  } catch {
    _ => None
  }
}

///|
/// Horizontal/Vertical Metrics.
pub(all) struct HmtxMetrics {
  /// Width/Height advance for `hmtx`/`vmtx`.
  advance : UInt16
  /// Left/Top side bearing for `hmtx`/`vmtx`.
  side_bearing : Int16
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend HmtxMetrics with @debug.Debug::{to_repr}

///|
pub impl FromData for HmtxMetrics with fn size() {
  4
}

///|
pub impl FromData for HmtxMetrics with fn parse(data) {
  // (`Stream::new(data)` + `read_u16`/`read_i16`, without allocating the
  // stream: `data` has `size()` bytes.)
  {
    advance: be_u16(data, 0),
    side_bearing: Int16::reinterpret_from_uint16(be_u16(data, 2)),
  }
}

///|
#deprecated("call as `FromData::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend HmtxMetrics with FromData::{size, parse}

///|
/// A [Horizontal/Vertical Metrics Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/hmtx).
///
/// `hmtx` and `vmtx` tables has the same structure, so we're reusing the same struct for both.
pub(all) struct HmtxTable {
  /// A list of metrics indexed by glyph ID.
  metrics : LazyArray16[HmtxMetrics]
  /// Side bearings for glyph IDs greater than or equal to the number of `metrics` values.
  bearings : LazyArray16[Int16]
  /// Sum of long metrics + bearings.
  number_of_metrics : UInt16
}

///|
/// Parses a table from raw data.
///
/// - `number_of_metrics` is from the `hhea`/`vhea` table.
/// - `number_of_glyphs` is from the `maxp` table.
pub fn HmtxTable::parse(
  number_of_metrics : UInt16,
  number_of_glyphs : UInt16,
  data : BytesView,
) -> HmtxTable? {
  if number_of_metrics == 0 {
    return None
  }
  let s = Stream::new(data)
  let metrics : LazyArray16[HmtxMetrics] = s.read_array16(number_of_metrics) catch {
    _ => return None
  }

  // 'If the number_of_metrics is less than the total number of glyphs,
  // then that array is followed by an array for the left side bearing values
  // of the remaining glyphs.'
  let mut number_of_metrics = number_of_metrics
  let bearings_count = u16_checked_sub(number_of_glyphs, number_of_metrics)
  let bearings = if bearings_count is Some(count) {
    number_of_metrics += count
    // Some malformed fonts can skip "left side bearing values"
    // even when they are expected.
    // Therefore if we weren't able to parser them, simply fallback to an empty array.
    // No need to mark the whole table as malformed.
    s.read_array16(count) catch {
      _ => LazyArray16::default()
    }
  } else {
    LazyArray16::default()
  }
  Some({ metrics, bearings, number_of_metrics, })
}

///|
/// Returns advance for a glyph.
pub fn HmtxTable::advance(self : HmtxTable, glyph_id : GlyphId) -> UInt16? {
  if glyph_id.0 >= self.number_of_metrics {
    return None
  }
  if self.metrics.get(glyph_id.0) is Some(metrics) {
    Some(metrics.advance)
  } else {
    // 'As an optimization, the number of records can be less than the number of glyphs,
    // in which case the advance value of the last record applies
    // to all remaining glyph IDs.'
    self.metrics.last().map(m => m.advance)
  }
}

///|
/// Returns side bearing for a glyph.
pub fn HmtxTable::side_bearing(self : HmtxTable, glyph_id : GlyphId) -> Int16? {
  if self.metrics.get(glyph_id.0) is Some(metrics) {
    Some(metrics.side_bearing)
  } else {
    // 'If the number_of_metrics is less than the total number of glyphs,
    // then that array is followed by an array for the side bearing values
    // of the remaining glyphs.'
    guard u16_checked_sub(glyph_id.0, self.metrics.len()) is Some(i) else {
      return None
    }
    self.bearings.get(i)
  }
}

///|
/// An [Index to Location Table](https://docs.microsoft.com/en-us/typography/opentype/spec/loca).
pub(all) enum LocaTable {
  /// Short offsets.
  Short(LazyArray16[UInt16])
  /// Long offsets.
  Long(LazyArray16[UInt])
}

///|
/// Parses a table from raw data.
///
/// - `number_of_glyphs` is from the `maxp` table.
/// - `format` is from the `head` table.
pub fn LocaTable::parse(
  number_of_glyphs : UInt16,
  format : IndexToLocationFormat,
  data : BytesView,
) -> LocaTable? {
  // The number of ranges is `maxp.numGlyphs + 1`.
  //
  // Check for overflow first.
  let mut total = if number_of_glyphs == 0xFFFF {
    number_of_glyphs
  } else {
    number_of_glyphs + 1
  }

  // By the spec, the number of `loca` offsets is `maxp.numGlyphs + 1`.
  // But some malformed fonts can have less glyphs than that.
  // In which case we try to parse only the available offsets
  // and do not return an error, since the expected data length
  // would go beyond table's length.
  //
  // In case when `loca` has more data than needed we simply ignore the rest.
  let actual_total = match format {
    Short => data.length() / 2
    Long => data.length() / 4
  }
  guard u16_try_from_int(actual_total) is Some(actual_total) else {
    return None
  }
  if actual_total < total {
    total = actual_total
  }
  let s = Stream::new(data)
  try {
    match format {
      Short => Some(Short(s.read_array16(total)))
      Long => Some(Long(s.read_array16(total)))
    }
  } catch {
    _ => None
  }
}

///|
/// Returns the number of offsets.
pub fn LocaTable::len(self : LocaTable) -> UInt16 {
  match self {
    Short(array) => array.len()
    Long(array) => array.len()
  }
}

///|
/// Checks if there are any offsets.
pub fn LocaTable::is_empty(self : LocaTable) -> Bool {
  self.len() == 0
}

///|
/// Returns glyph's range in the `glyf` table.
pub fn LocaTable::glyph_range(
  self : LocaTable,
  glyph_id : GlyphId,
) -> (Int, Int)? {
  let glyph_id = glyph_id.0
  if glyph_id == 0xFFFF {
    return None
  }

  // Glyph ID must be smaller than total number of values in a `loca` array.
  if glyph_id + 1 >= self.len() {
    return None
  }
  let (start, end) = match self {
    Short(array) => {
      // 'The actual local offset divided by 2 is stored.'
      guard array.get(glyph_id) is Some(a) else { return None }
      guard array.get(glyph_id + 1) is Some(b) else { return None }
      (a.to_int() * 2, b.to_int() * 2)
    }
    Long(array) => {
      guard array.get(glyph_id) is Some(a) else { return None }
      guard array.get(glyph_id + 1) is Some(b) else { return None }
      // Offsets beyond `Int` range can't be valid ranges into the data.
      if a.reinterpret_as_int() < 0 || b.reinterpret_as_int() < 0 {
        return None
      }
      (a.reinterpret_as_int(), b.reinterpret_as_int())
    }
  }
  if start >= end {
    // 'The offsets must be in ascending order.'
    // And range cannot be empty.
    None
  } else {
    Some((start, end))
  }
}
