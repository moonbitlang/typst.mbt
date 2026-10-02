// A [Standard Bitmap Graphics Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/sbix) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/sbix.rs`.

///|
/// A strike of glyphs (`sbix::Strike`).
pub struct SbixStrike {
  /// The pixels per EM size for which this strike was designed.
  pixels_per_em : UInt16
  /// The device pixel density (in PPI) for which this strike was designed.
  ppi : UInt16
  offsets : LazyArray16[Offset32]
  /// Data from the beginning of the `Strikes` table.
  data : BytesView
}

///|
fn SbixStrike::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> SbixStrike raise Malformed {
  let s = Stream::new(data)
  let pixels_per_em = s.read_u16()
  let ppi = s.read_u16()
  let offsets = s.read_array16(number_of_glyphs)
  { pixels_per_em, ppi, offsets, data, }
}

///|
/// Returns a glyph data.
pub fn SbixStrike::get(
  self : SbixStrike,
  glyph_id : GlyphId,
) -> RasterGlyphImage? {
  self.get_inner(glyph_id, 0)
}

///|
fn SbixStrike::get_inner(
  self : SbixStrike,
  glyph_id : GlyphId,
  depth : Int,
) -> RasterGlyphImage? {
  // Recursive `dupe`. Bail.
  if depth == 10 {
    return None
  }
  try {
    let start = req(self.offsets.get(glyph_id.0)).to_usize()
    let end = req(self.offsets.get(req(u16_checked_add(glyph_id.0, 1)))).to_usize()
    if start == end {
      return None
    }
    let data_len = req(usize_checked_sub(req(usize_checked_sub(end, start)), 8)) // 8 is a Glyph data header size.
    let s = Stream::new_at_r(self.data, start)
    let x = s.read_i16()
    let y = s.read_i16()
    let image_type : Tag = s.read()
    let image_data = s.read_bytes(data_len)

    // We do ignore `pdf` and `mask` intentionally, because Apple docs state that:
    // 'Support for the 'pdf ' and 'mask' data types and sbixDrawOutlines flag
    // are planned for future releases of iOS and OS X.'
    let format : RasterImageFormat = if image_type == Tag::from_str("png ") {
      PNG
    } else if image_type == Tag::from_str("dupe") {
      // 'The special graphicType of 'dupe' indicates that
      // the data field contains a glyph ID. The bitmap data for
      // the indicated glyph should be used for the current glyph.'
      if image_data.length() != 2 {
        return None
      }
      let glyph_id : GlyphId = FromData::parse(image_data)
      // TODO: The spec isn't clear about which x/y values should we use.
      //       The current glyph or the referenced one.
      return self.get_inner(glyph_id, depth + 1)
    } else {
      // TODO: support JPEG and TIFF
      return None
    }
    let (width, height) = req(png_size(image_data))
    Some({
      x,
      y,
      width,
      height,
      pixels_per_em: self.pixels_per_em,
      format,
      data: image_data,
    })
  } catch {
    _ => None
  }
}

///|
/// Returns the number of glyphs in this strike.
pub fn SbixStrike::len(self : SbixStrike) -> UInt16 {
  // The last offset simply indicates the glyph data end. We don't need it.
  self.offsets.len() - 1
}

///|
/// Checks if there are any glyphs.
pub fn SbixStrike::is_empty(self : SbixStrike) -> Bool {
  self.len() == 0
}

///|
/// A list of [`SbixStrike`]s.
struct SbixStrikes {
  /// `sbix` table data.
  data : BytesView
  // Offsets from the beginning of the `sbix` table.
  offsets : LazyArray32[Offset32]
  // The total number of glyphs in the face + 1. From the `maxp` table.
  number_of_glyphs : UInt16
}

///|
/// Returns a strike at the index.
pub fn SbixStrikes::get(self : SbixStrikes, index : UInt) -> SbixStrike? {
  guard self.offsets.get(index) is Some(offset) else { return None }
  guard slice_from(self.data, offset.to_usize()) is Some(data) else {
    return None
  }
  try SbixStrike::parse(self.number_of_glyphs, data) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns the number of strikes.
pub fn SbixStrikes::len(self : SbixStrikes) -> UInt {
  self.offsets.len()
}

///|
/// Checks if there are any strikes.
pub fn SbixStrikes::is_empty(self : SbixStrikes) -> Bool {
  self.offsets.is_empty()
}

///|
/// Returns an iterator over the strikes.
pub fn SbixStrikes::into_iter(self : SbixStrikes) -> SbixStrikesIter {
  { strikes: self, index: 0, }
}

///|
/// Iterates over the strikes.
pub fn SbixStrikes::iter(self : SbixStrikes) -> Iter[SbixStrike] {
  let it = self.into_iter()
  Iter::new(() => it.next())
}

///|
/// An iterator over [`SbixStrikes`].
struct SbixStrikesIter {
  strikes : SbixStrikes
  mut index : UInt
}

///|
/// Returns the next strike.
pub fn SbixStrikesIter::next(self : SbixStrikesIter) -> SbixStrike? {
  if self.index < self.strikes.len() {
    self.index += 1
    self.strikes.get(self.index - 1)
  } else {
    None
  }
}

///|
/// A [Standard Bitmap Graphics Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/sbix).
pub(all) struct SbixTable {
  /// A list of [`SbixStrike`]s.
  strikes : SbixStrikes
}

///|
/// Parses a table from raw data.
///
/// - `number_of_glyphs` is from the `maxp` table (non-zero).
pub fn SbixTable::parse(
  number_of_glyphs : UInt16,
  data : BytesView,
) -> SbixTable? {
  guard u16_checked_add(number_of_glyphs, 1) is Some(number_of_glyphs) else {
    return None
  }
  let s = Stream::new(data)
  try {
    let version = s.read_u16()
    if version != 1 {
      return None
    }
    s.advance(2) // flags
    let strikes_count = s.read_u32()
    if strikes_count == 0 {
      return None
    }
    let offsets = s.read_array32(strikes_count)
    Some({ strikes: { data, offsets, number_of_glyphs, }, })
  } catch {
    _ => None
  }
}

///|
/// Selects the best matching [`SbixStrike`] based on `pixels_per_em`.
pub fn SbixTable::best_strike(
  self : SbixTable,
  pixels_per_em : UInt16,
) -> SbixStrike? {
  let mut idx : UInt = 0
  let mut max_ppem : UInt16 = 0
  let it = self.strikes.into_iter()
  let mut i : UInt = 0
  while it.next() is Some(strike) {
    if (
        pixels_per_em <= strike.pixels_per_em && strike.pixels_per_em < max_ppem
      ) ||
      (pixels_per_em > max_ppem && strike.pixels_per_em > max_ppem) {
      idx = i
      max_ppem = strike.pixels_per_em
    }
    i += 1
  }
  self.strikes.get(idx)
}

///|
// The `sbix` table doesn't store the image size, so we have to parse it manually.
// Which is quite simple in case of PNG, but way more complex for JPEG.
// Therefore we are omitting it for now.
fn png_size(data : BytesView) -> (UInt16, UInt16)? {
  try {
    // PNG stores its size as u32 BE at a fixed offset.
    let s = Stream::new_at_r(data, 16)
    let width = s.read_u32()
    let height = s.read_u32()

    // PNG size larger than u16::MAX is an error.
    Some((req(u16_try_from_u32(width)), req(u16_try_from_u32(height))))
  } catch {
    _ => None
  }
}
