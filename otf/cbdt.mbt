// A [Color Bitmap Data Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/cbdt) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/cbdt.rs`.

///|
/// A [Color Bitmap Data Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cbdt).
///
/// EBDT and bdat also share the same structure, so this is re-used for them.
struct CbdtTable {
  locations : CblcTable
  data : BytesView
}

///|
/// Parses a table from raw data.
pub fn CbdtTable::parse(locations : CblcTable, data : BytesView) -> CbdtTable? {
  Some({ locations, data, })
}

///|
/// Returns a raster image for the glyph.
pub fn CbdtTable::get(
  self : CbdtTable,
  glyph_id : GlyphId,
  pixels_per_em : UInt16,
) -> RasterGlyphImage? {
  guard self.locations.get(glyph_id, pixels_per_em) is Some(location) else {
    return None
  }
  try {
    let s = Stream::new_at_r(self.data, location.offset)
    let metrics : CblcMetrics = match location.format.metrics {
      Small => {
        let height = s.read_u8()
        let width = s.read_u8()
        let bearing_x = s.read_i8()
        let bearing_y = s.read_i8()
        s.advance(1) // advance
        { x: bearing_x, y: bearing_y, width, height, }
      }
      Big => {
        let height = s.read_u8()
        let width = s.read_u8()
        let hor_bearing_x = s.read_i8()
        let hor_bearing_y = s.read_i8()
        s.advance(1) // hor_advance
        s.advance(1) // ver_bearing_x
        s.advance(1) // ver_bearing_y
        s.advance(1) // ver_advance
        { x: hor_bearing_x, y: hor_bearing_y, width, height, }
      }
      Shared => location.metrics
    }
    let x = Int16::from_int(metrics.x)
    // `y` in CBDT is a bottom bound, not top one.
    let y = Int16::from_int(metrics.y - metrics.height.to_int())
    let width = u16_from_u8(metrics.width)
    let height = u16_from_u8(metrics.height)
    match location.format.data {
      ByteAligned(bit_depth~) => {
        let row_len = (metrics.width.to_uint() * bit_depth.to_uint() + 7) / 8
        let data_len = row_len * metrics.height.to_uint()
        let data = s.read_bytes(data_len.reinterpret_as_int())
        Some({
          x,
          y,
          width,
          height,
          pixels_per_em: location.ppem,
          format: match bit_depth {
            1 => BitmapMono
            2 => BitmapGray2
            4 => BitmapGray4
            8 => BitmapGray8
            32 => BitmapPremulBgra32
            _ => return None
          },
          data,
        })
      }
      BitAligned(bit_depth~) => {
        let data_len = {
          let w = metrics.width.to_uint()
          let h = metrics.height.to_uint()
          let d = bit_depth.to_uint()
          (w * h * d + 7) / 8
        }
        let data = s.read_bytes(data_len.reinterpret_as_int())
        Some({
          x,
          y,
          width,
          height,
          pixels_per_em: location.ppem,
          format: match bit_depth {
            1 => BitmapMonoPacked
            2 => BitmapGray2Packed
            4 => BitmapGray4Packed
            8 => BitmapGray8
            32 => BitmapPremulBgra32
            _ => return None
          },
          data,
        })
      }
      PNG => {
        let data_len = s.read_u32()
        let data = s.read_bytes(data_len.reinterpret_as_int())
        Some({
          x,
          y,
          width,
          height,
          pixels_per_em: location.ppem,
          format: PNG,
          data,
        })
      }
    }
  } catch {
    _ => None
  }
}
