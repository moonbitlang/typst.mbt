// An [Anchor Point Table](
// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6ankr.html) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/ankr.rs`.

///|
/// An anchor point (`ankr::Point`).
pub(all) struct AnkrPoint {
  x : Int16
  y : Int16
} derive(Eq, Default, Debug)

///|
pub impl FromData for AnkrPoint with fn size() {
  4
}

///|
pub impl FromData for AnkrPoint with fn parse(data) {
  let s = Stream::new(data)
  { x: s.read(), y: s.read(), }
}

///|
/// An [Anchor Point Table](
/// https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6ankr.html).
struct AnkrTable {
  lookup : AatLookup
  // Ideally, Glyphs Data can be represented as an array,
  // but Apple's spec doesn't specify that Glyphs Data members have padding or not.
  // Meaning we cannot simply iterate over them.
  glyphs_data : BytesView
}

///|
/// Parses a table from raw data.
///
/// `number_of_glyphs` is from the `maxp` table (non-zero).
pub fn AnkrTable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> AnkrTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u16()
    if version != 0 {
      return None
    }
    s.advance(2) // reserved

    // TODO: we should probably check that offset is larger than the header size (8)
    let lookup_table = ankr_read_at_offset32(s, data)
    let glyphs_data = ankr_read_at_offset32(s, data)
    Some({
      lookup: req(AatLookup::parse(number_of_glyphs, lookup_table)),
      glyphs_data,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns a list of anchor points for the specified glyph.
pub fn AnkrTable::points(
  self : AnkrTable,
  glyph_id : GlyphId,
) -> LazyArray32[AnkrPoint]? {
  guard self.lookup.value(glyph_id) is Some(offset) else { return None }
  try {
    let s = Stream::new_at_r(self.glyphs_data, offset.to_int())
    let number_of_points = s.read_u32()
    Some(s.read_array32(number_of_points))
  } catch {
    _ => None
  }
}

///|
/// `StreamExt::read_at_offset32`: reads an `Offset32` and returns the data
/// at it.
fn ankr_read_at_offset32(
  s : Stream,
  data : BytesView,
) -> BytesView raise Malformed {
  let offset = (s.read() : Offset32).to_usize()
  slice_from_r(data, offset)
}
