// A [Color Bitmap Location Table](
// https://docs.microsoft.com/en-us/typography/opentype/spec/cblc) implementation.
//
// Port of `ttf-parser` 0.25.1 `src/tables/cblc.rs`. The crate-private types
// get a `Cblc` prefix.

///|
priv struct CblcBitmapFormat {
  metrics : CblcMetricsFormat
  data : CblcBitmapDataFormat
} derive(Eq, Debug)

///|
priv enum CblcMetricsFormat {
  Small
  Big
  Shared
} derive(Eq, Debug)

///|
priv enum CblcBitmapDataFormat {
  ByteAligned(bit_depth~ : Byte)
  BitAligned(bit_depth~ : Byte)
  PNG
} derive(Eq, Debug)

///|
priv struct CblcMetrics {
  mut x : Int // i8
  mut y : Int // i8
  mut width : Byte
  mut height : Byte
} derive(Debug)

///|
fn CblcMetrics::default() -> CblcMetrics {
  { x: 0, y: 0, width: 0, height: 0, }
}

///|
priv struct CblcLocation {
  format : CblcBitmapFormat
  offset : Int
  metrics : CblcMetrics
  ppem : UInt16
} derive(Debug)

///|
priv struct BitmapSizeTable {
  subtable_array_offset : Offset32
  number_of_subtables : UInt
  ppem : UInt16
  bit_depth : Byte
  // Many fields are omitted.
}

///|
fn select_bitmap_size_table(
  glyph_id : GlyphId,
  pixels_per_em : UInt16,
  s : Stream,
) -> BitmapSizeTable raise Malformed {
  let s = s.copy()
  let subtable_count = s.read_u32()
  let orig_s = s.copy()
  let mut idx : Int? = None
  let mut max_ppem : UInt16 = 0
  let mut bit_depth_for_max_ppem : Byte = 0
  let mut i : UInt = 0
  while i < subtable_count {
    let cur = i
    i += 1
    // Check that the current subtable contains a provided glyph id.
    s.advance(40) // Jump to `start_glyph_index`.
    let start_glyph_id : GlyphId = s.read()
    let end_glyph_id : GlyphId = s.read()
    let ppem_x = u16_from_u8(s.read_u8())
    s.advance(1) // ppem_y
    let bit_depth = s.read_u8()
    s.advance(1) // flags
    if !(start_glyph_id <= glyph_id && glyph_id <= end_glyph_id) {
      continue
    }

    // Select a best matching subtable based on `pixels_per_em`.
    if (pixels_per_em <= ppem_x && ppem_x < max_ppem) ||
      (pixels_per_em > max_ppem && ppem_x > max_ppem) {
      idx = Some(cur.reinterpret_as_int())
      max_ppem = ppem_x
      bit_depth_for_max_ppem = bit_depth
    }
  }
  let s = orig_s
  s.advance(req(idx) * 48) // 48 is BitmapSize Table size
  let subtable_array_offset : Offset32 = s.read()
  s.advance(4) // index_tables_size
  let number_of_subtables = s.read_u32()
  {
    subtable_array_offset,
    number_of_subtables,
    ppem: max_ppem,
    bit_depth: bit_depth_for_max_ppem,
  }
}

///|
priv struct IndexSubtableInfo {
  start_glyph_id : GlyphId
  offset : Int // absolute offset
}

///|
fn select_index_subtable(
  data : BytesView,
  size_table : BitmapSizeTable,
  glyph_id : GlyphId,
) -> IndexSubtableInfo raise Malformed {
  let s = Stream::new_at_r(data, size_table.subtable_array_offset.to_usize())
  let mut i : UInt = 0
  while i < size_table.number_of_subtables {
    i += 1
    let start_glyph_id : GlyphId = s.read()
    let end_glyph_id : GlyphId = s.read()
    let offset : Offset32 = s.read()
    if start_glyph_id <= glyph_id && glyph_id <= end_glyph_id {
      let offset = cblc_usize_add(
        size_table.subtable_array_offset.to_usize(),
        offset.to_usize(),
      )
      return { start_glyph_id, offset, }
    }
  }
  raise Malformed
}

///|
/// `usize` addition of two non-negative offsets. Results that do not fit
/// into an `Int` saturate to `Int::max_value`, which is out of bounds of any
/// data anyway (upstream uses a 64-bit `usize`).
fn cblc_usize_add(a : Int, b : Int) -> Int {
  let r = a.to_int64() + b.to_int64()
  if r > 0x7fffffffL {
    0x7fffffff
  } else {
    r.to_int()
  }
}

///|
/// `usize` multiplication of two non-negative numbers, saturating like
/// `cblc_usize_add`.
fn cblc_usize_mul(a : Int, b : Int) -> Int {
  let r = a.to_int64() * b.to_int64()
  if r > 0x7fffffffL {
    0x7fffffff
  } else {
    r.to_int()
  }
}

///|
/// `usize::num_from(u32)`, saturating like `cblc_usize_add`.
fn cblc_usize_from_u32(v : UInt) -> Int {
  let i = v.reinterpret_as_int()
  if i < 0 {
    0x7fffffff
  } else {
    i
  }
}

///|
priv struct GlyphIdOffsetPair {
  glyph_id : GlyphId
  offset : Offset16
}

///|
impl FromData for GlyphIdOffsetPair with fn size() {
  4
}

///|
impl FromData for GlyphIdOffsetPair with fn parse(data) {
  let s = Stream::new(data)
  { glyph_id: s.read(), offset: s.read(), }
}

// TODO: rewrite

///|
/// A [Color Bitmap Location Table](
/// https://docs.microsoft.com/en-us/typography/opentype/spec/cblc).
///
/// EBLC and bloc also share the same structure, so this is re-used for them.
struct CblcTable {
  data : BytesView
}

///|
/// Parses a table from raw data.
pub fn CblcTable::parse(data : BytesView) -> CblcTable? {
  Some({ data, })
}

///|
fn CblcTable::get(
  self : CblcTable,
  glyph_id : GlyphId,
  pixels_per_em : UInt16,
) -> CblcLocation? {
  try {
    let s = Stream::new(self.data)

    // The CBLC table version is a bit tricky, so we are ignoring it for now.
    // The CBLC table is based on EBLC table, which was based on the `bloc` table.
    // And before the CBLC table specification was finished, some fonts,
    // notably Noto Emoji, have used version 2.0, but the final spec allows only 3.0.
    // So there are perfectly valid fonts in the wild, which have an invalid version.
    s.advance(4) // version
    let size_table = select_bitmap_size_table(glyph_id, pixels_per_em, s)
    let info = select_index_subtable(self.data, size_table, glyph_id)
    let s = Stream::new_at_r(self.data, info.offset)
    let index_format = s.read_u16()
    let image_format = s.read_u16()
    let mut image_offset = (s.read() : Offset32).to_usize()
    let bit_depth = size_table.bit_depth
    let image_format : CblcBitmapFormat = match image_format {
      1 => { metrics: Small, data: ByteAligned(bit_depth~), }
      2 => { metrics: Small, data: BitAligned(bit_depth~), }
      5 => { metrics: Shared, data: BitAligned(bit_depth~), }
      6 => { metrics: Big, data: ByteAligned(bit_depth~), }
      7 => { metrics: Big, data: BitAligned(bit_depth~), }
      17 => { metrics: Small, data: PNG, }
      18 => { metrics: Big, data: PNG, }
      19 => { metrics: Shared, data: PNG, }
      _ => return None // Invalid format.
    }

    // TODO: I wasn't able to find fonts with index 4 and 5, so they are untested.

    let glyph_diff = req(u16_checked_sub(glyph_id.0, info.start_glyph_id.0))
    let metrics = CblcMetrics::default()
    match index_format {
      1 => {
        s.advance(glyph_diff.to_int() * 4)
        let offset : Offset32 = s.read()
        image_offset = cblc_usize_add(image_offset, offset.to_usize())
      }
      2 => {
        let image_size = s.read_u32()
        image_offset = cblc_usize_add(
          image_offset,
          cblc_usize_mul(glyph_diff.to_int(), cblc_usize_from_u32(image_size)),
        )
        metrics.height = s.read_u8()
        metrics.width = s.read_u8()
        metrics.x = s.read_i8()
        metrics.y = s.read_i8()
      }
      3 => {
        s.advance(glyph_diff.to_int() * 2)
        let offset : Offset16 = s.read()
        image_offset = cblc_usize_add(image_offset, offset.to_usize())
      }
      4 => {
        let num_glyphs = s.read_u32()
        let num_glyphs = req(u32_checked_add(num_glyphs, 1))
        let pairs : LazyArray32[GlyphIdOffsetPair] = s.read_array32(num_glyphs)
        let pair = req(
          pairs.iter().find_first(pair => pair.glyph_id == glyph_id),
        )
        image_offset = cblc_usize_add(image_offset, pair.offset.to_usize())
      }
      5 => {
        let image_size = s.read_u32()
        metrics.height = s.read_u8()
        metrics.width = s.read_u8()
        metrics.x = s.read_i8()
        metrics.y = s.read_i8()
        s.advance(1) // hor_advance
        s.advance(1) // ver_bearing_x
        s.advance(1) // ver_bearing_y
        s.advance(1) // ver_advance
        let num_glyphs = s.read_u32()
        let glyphs : LazyArray32[GlyphId] = s.read_array32(num_glyphs)
        let (index, _) = req(glyphs.binary_search(glyph_id))
        image_offset = cblc_usize_add(
          image_offset,
          cblc_usize_mul(
            cblc_usize_from_u32(index),
            cblc_usize_from_u32(image_size),
          ),
        )
      }
      _ => return None // Invalid format.
    }
    Some({
      format: image_format,
      offset: image_offset,
      metrics,
      ppem: size_table.ppem,
    })
  } catch {
    _ => None
  }
}
