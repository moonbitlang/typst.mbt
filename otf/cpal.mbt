// A [Color Palette Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/cpal) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/cpal.rs`.

///|
/// A [Color Palette Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cpal).
struct CpalTable {
  color_indices : LazyArray16[UInt16]
  colors : LazyArray16[BgraColor]
}

///|
/// Parses a table from raw data.
pub fn CpalTable::parse(data : BytesView) -> CpalTable? {
  let s = Stream::new(data)
  try {
    let version = s.read_u16()
    if version > 1 {
      return None
    }
    s.advance(2) // number of palette entries
    let num_palettes = s.read_u16()
    if num_palettes == 0 {
      return None // zero palettes is an error
    }
    let num_colors = s.read_u16()
    let color_records_offset : Offset32 = s.read()
    let color_indices = s.read_array16(num_palettes)
    let colors = Stream::new_at_r(data, color_records_offset.to_usize()).read_array16(
      num_colors,
    )
    Some({ color_indices, colors, })
  } catch {
    _ => None
  }
}

///|
/// Returns the number of palettes.
///
/// Always non-zero (checked during parsing).
pub fn CpalTable::palettes(self : CpalTable) -> UInt16 {
  self.color_indices.len()
}

///|
/// Returns the color at the given index into the given palette.
pub fn CpalTable::get(
  self : CpalTable,
  palette_index : UInt16,
  palette_entry : UInt16,
) -> RgbaColor? {
  guard self.color_indices.get(palette_index) is Some(start) else {
    return None
  }
  guard u16_checked_add(start, palette_entry) is Some(index) else {
    return None
  }
  self.colors.get(index).map(c => c.to_rgba())
}

///|
priv struct BgraColor {
  blue : Byte
  green : Byte
  red : Byte
  alpha : Byte
}

///|
fn BgraColor::to_rgba(self : BgraColor) -> RgbaColor {
  RgbaColor::new(self.red, self.green, self.blue, self.alpha)
}

///|
impl FromData for BgraColor with fn size() {
  4
}

///|
impl FromData for BgraColor with fn parse(data) {
  let s = Stream::new(data)
  { blue: s.read(), green: s.read(), red: s.read(), alpha: s.read(), }
}
