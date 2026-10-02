// A [Vertical Origin Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/vorg) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/vorg.rs`.

///|
/// Vertical origin metrics for the
/// [Vertical Origin Table](https://docs.microsoft.com/en-us/typography/opentype/spec/vorg).
pub(all) struct VerticalOriginMetrics {
  /// Glyph ID.
  glyph_id : GlyphId
  /// Y coordinate, in the font's design coordinate system, of the vertical origin.
  y : Int16
} derive(Debug)

///|
pub impl FromData for VerticalOriginMetrics with fn size() {
  4
}

///|
pub impl FromData for VerticalOriginMetrics with fn parse(data) {
  let s = Stream::new(data)
  { glyph_id: s.read(), y: s.read(), }
}

///|
/// A [Vertical Origin Table](https://docs.microsoft.com/en-us/typography/opentype/spec/vorg).
pub(all) struct VorgTable {
  /// Default origin.
  default_y : Int16
  /// A list of metrics for each glyph.
  ///
  /// Ordered by `glyph_id`.
  metrics : LazyArray16[VerticalOriginMetrics]
}

///|
/// Parses a table from raw data.
pub fn VorgTable::parse(data : BytesView) -> VorgTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u32()
    if version != 0x00010000 {
      return None
    }
    let default_y = s.read_i16()
    let count = s.read_u16()
    let metrics = s.read_array16(count)
    Some({ default_y, metrics, })
  } catch {
    _ => None
  }
}

///|
/// Returns glyph's Y origin.
pub fn VorgTable::glyph_y_origin(self : VorgTable, glyph_id : GlyphId) -> Int16 {
  self.metrics
  .binary_search_by(m => Compare::compare(m.glyph_id, glyph_id))
  .map(x => x.1.y)
  .unwrap_or(self.default_y)
}
