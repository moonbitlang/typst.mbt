// Port of rustybuzz 0.20.1 `src/hb/face.rs` (`hb_font_t`).

// https://docs.microsoft.com/en-us/typography/opentype/spec/cmap#windows-platform-platform-id--3

///|
const WINDOWS_SYMBOL_ENCODING : Int = 0

///|
const WINDOWS_UNICODE_BMP_ENCODING : Int = 1

///|
const WINDOWS_UNICODE_FULL_ENCODING : Int = 10

// https://docs.microsoft.com/en-us/typography/opentype/spec/name#platform-specific-encoding-and-language-ids-unicode-platform-platform-id--0

///|
const UNICODE_1_0_ENCODING : Int = 0

///|
const UNICODE_1_1_ENCODING : Int = 1

///|
const UNICODE_ISO_ENCODING : Int = 2

///|
const UNICODE_2_0_BMP_ENCODING : Int = 3

///|
const UNICODE_2_0_FULL_ENCODING : Int = 4

///|
const UNICODE_FULL_ENCODING : Int = 6

///|
/// A font face handle (`hb_font_t`).
struct Face {
  ttfp_face : @otf.Face
  units_per_em : Int
  mut pixels_per_em : (Int, Int)?
  mut points_per_em : Float?
  prefered_cmap_encoding_subtable : Int?
  gsub : SubstitutionTable?
  gpos : PositioningTable?
}

///|
/// Creates a new `Face` from data (`face_index` selects a face of a
/// collection).
pub fn Face::from_slice(data : BytesView, face_index : UInt) -> Face? {
  let face = @otf.Face::parse(data, face_index) catch { _ => return None }
  Some(Face::from_face(face))
}

///|
/// Creates a new `Face` from an `@otf.Face`. The face is used as is (its
/// variation coordinates are shared).
pub fn Face::from_face(face : @otf.Face) -> Face {
  {
    units_per_em: face.units_per_em().to_int(),
    pixels_per_em: None,
    points_per_em: None,
    prefered_cmap_encoding_subtable: find_best_cmap_subtable(face),
    gsub: face.tables().gsub.map(SubstitutionTable::new),
    gpos: face.tables().gpos.map(PositioningTable::new),
    ttfp_face: face,
  }
}

///|
/// The underlying `@otf.Face`.
pub fn Face::ttf(self : Face) -> @otf.Face {
  self.ttfp_face
}

///|
/// Returns face’s units per EM.
pub fn Face::units_per_em(self : Face) -> Int {
  self.units_per_em
}

///|
/// Sets pixels per EM. Used during raster glyphs processing and hinting.
/// `None` by default.
pub fn Face::set_pixels_per_em(self : Face, ppem : (Int, Int)?) -> Unit {
  self.pixels_per_em = ppem
}

///|
/// Sets point size per EM. Used for optical-sizing in Apple fonts.
/// `None` by default.
pub fn Face::set_points_per_em(self : Face, ptem : Float?) -> Unit {
  self.points_per_em = ptem
}

///|
/// Sets a font variation.
pub fn Face::set_variation(self : Face, tag : @otf.Tag, value : Float) -> Unit {
  self.ttfp_face.set_variation(tag, value) |> ignore
}

///|
/// Sets font variations.
pub fn Face::set_variations(self : Face, variations : Array[Variation]) -> Unit {
  for variation in variations {
    self.set_variation(variation.tag, variation.value)
  }
}

///|
fn Face::tables(self : Face) -> @otf.FaceTables {
  self.ttfp_face.tables()
}

///|
fn Face::variation_coordinates(
  self : Face,
) -> ArrayView[@otf.NormalizedCoordinate] {
  self.ttfp_face.variation_coordinates()
}

///|
fn Face::has_glyph(self : Face, c : Int) -> Bool {
  self.get_nominal_glyph(c) is Some(_)
}

///|
fn Face::get_nominal_glyph(self : Face, c : Int) -> @otf.GlyphId? {
  let mut c = c
  guard self.prefered_cmap_encoding_subtable is Some(subtable_idx) else {
    return None
  }
  guard self.tables().cmap is Some(cmap) else { return None }
  guard cmap.subtables.get(subtable_idx.to_uint16()) is Some(subtable) else {
    return None
  }
  if subtable.platform_id == Macintosh && c > 0x7F {
    c = unicode_to_macroman(c)
  }
  match subtable.glyph_index(c.reinterpret_as_uint()) {
    Some(gid) => Some(gid)
    None => {
      // Special case for Windows Symbol fonts.
      // TODO: add tests
      if subtable.platform_id == Windows &&
        subtable.encoding_id.to_int() == WINDOWS_SYMBOL_ENCODING {
        if c <= 0x00FF {
          // For symbol-encoded OpenType fonts, we duplicate the
          // U+F000..F0FF range at U+0000..U+00FF.  That's what
          // Windows seems to do, and that's hinted about at:
          // https://docs.microsoft.com/en-us/typography/opentype/spec/recom
          // under "Non-Standard (Symbol) Fonts".
          return self.get_nominal_glyph(0xF000 + c)
        }
      }
      None
    }
  }
}

///|
fn Face::glyph_h_advance(self : Face, glyph : @otf.GlyphId) -> Int {
  self.glyph_advance(glyph, false).reinterpret_as_int()
}

///|
fn Face::glyph_v_advance(self : Face, glyph : @otf.GlyphId) -> Int {
  -self.glyph_advance(glyph, true).reinterpret_as_int()
}

///|
fn Face::glyph_advance(
  self : Face,
  glyph : @otf.GlyphId,
  is_vertical : Bool,
) -> UInt {
  let face = self.ttfp_face
  if face.is_variable() &&
    face.has_non_default_variation_coordinates() &&
    face.tables().hvar is None &&
    face.tables().vvar is None &&
    face.glyph_phantom_points(glyph) is None {
    return match face.glyph_bounding_box(glyph) {
      Some(bbox) =>
        // (i16 + i16) as u32
        (if is_vertical {
          (bbox.y_max + bbox.y_min).to_int()
        } else {
          (bbox.x_max + bbox.x_min).to_int()
        }).reinterpret_as_uint()
      None => 0
    }
  }
  if is_vertical {
    if face.tables().vmtx is Some(_) {
      face
      .glyph_ver_advance(glyph)
      .map(v => v.to_int())
      .unwrap_or(0)
      .reinterpret_as_uint()
    } else {
      // TODO: Original code calls `h_extents_with_fallback`
      (face.ascender() - face.descender()).to_int().reinterpret_as_uint()
    }
  } else if !is_vertical && face.tables().hmtx is Some(_) {
    face
    .glyph_hor_advance(glyph)
    .map(v => v.to_int())
    .unwrap_or(0)
    .reinterpret_as_uint()
  } else {
    face.units_per_em().to_int().reinterpret_as_uint()
  }
}

///|
fn Face::glyph_h_origin(self : Face, glyph : @otf.GlyphId) -> Int {
  self.glyph_h_advance(glyph) / 2
}

///|
fn Face::glyph_v_origin(self : Face, glyph : @otf.GlyphId) -> Int {
  match self.ttfp_face.glyph_y_origin(glyph) {
    Some(y) => y.to_int()
    None => {
      let extents = GlyphExtents::new()
      if self.glyph_extents(glyph, extents) {
        if self.ttfp_face.tables().vmtx is Some(_) {
          extents.y_bearing + self.glyph_side_bearing(glyph, true)
        } else {
          let advance = (self.ttfp_face.ascender() - self.ttfp_face.descender()).to_int()
          let diff = advance - -extents.height
          extents.y_bearing + (diff >> 1)
        }
      } else {
        // TODO: Original code calls `h_extents_with_fallback`
        self.ttfp_face.ascender().to_int()
      }
    }
  }
}

///|
fn Face::glyph_side_bearing(
  self : Face,
  glyph : @otf.GlyphId,
  is_vertical : Bool,
) -> Int {
  let face = self.ttfp_face
  if face.is_variable() &&
    face.tables().hvar is None &&
    face.tables().vvar is None {
    return match face.glyph_bounding_box(glyph) {
      Some(bbox) =>
        if is_vertical {
          bbox.x_min.to_int()
        } else {
          bbox.y_min.to_int()
        }
      None => 0
    }
  }
  if is_vertical {
    face.glyph_ver_side_bearing(glyph).map(v => v.to_int()).unwrap_or(0)
  } else {
    face.glyph_hor_side_bearing(glyph).map(v => v.to_int()).unwrap_or(0)
  }
}

///|
/// Rust's `f32::round` (half away from zero) then `as i32` (saturating).
fn round_f32_to_i32(v : Float) -> Int {
  let d = v.to_double()
  if d.is_nan() {
    return 0
  }
  let r = if d < 0.0 { -(-d + 0.5).floor() } else { (d + 0.5).floor() }
  // `f32::round` is exact for |v| >= 2^23; `(d + 0.5).floor()` is exact in
  // f64 for all f32 values.
  if r >= 2147483647.0 {
    2147483647
  } else if r <= -2147483648.0 {
    -2147483648
  } else {
    r.to_int()
  }
}

///|
/// Rust's `f32 as i32` (truncating, saturating).
fn f32_as_i32(v : Float) -> Int {
  let d = v.to_double()
  if d.is_nan() {
    0
  } else if d >= 2147483647.0 {
    2147483647
  } else if d <= -2147483648.0 {
    -2147483648
  } else {
    d.to_int()
  }
}

///|
fn Face::glyph_extents(
  self : Face,
  glyph : @otf.GlyphId,
  glyph_extents : GlyphExtents,
) -> Bool {
  let pixels_per_em = match self.pixels_per_em {
    Some(ppem) => ppem.0
    None => 0xFFFF
  }
  if self.ttfp_face.glyph_raster_image(glyph, pixels_per_em.to_uint16())
    is Some(img) {
    // HarfBuzz also supports only PNG.
    if img.format == PNG {
      let scale = Float::from_int(self.units_per_em) /
        Float::from_int(img.pixels_per_em.to_int())
      glyph_extents.x_bearing = round_f32_to_i32(
        Float::from_int(img.x.to_int()) * scale,
      )
      glyph_extents.y_bearing = round_f32_to_i32(
        (Float::from_int(img.y.to_int()) + Float::from_int(img.height.to_int())) *
        scale,
      )
      glyph_extents.width = round_f32_to_i32(
        Float::from_int(img.width.to_int()) * scale,
      )
      glyph_extents.height = round_f32_to_i32(
        -Float::from_int(img.height.to_int()) * scale,
      )
      return true
    }
    // TODO: Add tests for this. We should use all glyphs from
    // https://github.com/googlefonts/color-fonts/blob/main/fonts/test_glyphs-glyf_colr_1_no_cliplist.ttf
    // and test their output against harfbuzz.
  } else if self.ttfp_face.tables().colr is Some(colr) {
    if colr.is_simple() {
      return false
    }
    if colr.clip_box(glyph, self.variation_coordinates()) is Some(clip_box) {
      // Floor
      glyph_extents.x_bearing = round_f32_to_i32(clip_box.x_min)
      glyph_extents.y_bearing = round_f32_to_i32(clip_box.y_max)
      glyph_extents.width = round_f32_to_i32(clip_box.x_max - clip_box.x_min)
      glyph_extents.height = round_f32_to_i32(clip_box.y_min - clip_box.y_max)
      return true
    }
    let extents_data = PaintExtentsContext::new(self.ttfp_face)
    let ret = colr.paint(
        glyph,
        0,
        extents_data,
        self.variation_coordinates(),
        @otf.RgbaColor::new(b'\x00', b'\x00', b'\x00', b'\x00'),
      )
      is Some(_)
    let e = extents_data.get_extents()
    if e.is_void() {
      glyph_extents.x_bearing = 0
      glyph_extents.y_bearing = 0
      glyph_extents.width = 0
      glyph_extents.height = 0
    } else {
      glyph_extents.x_bearing = f32_as_i32(e.x_min)
      glyph_extents.y_bearing = f32_as_i32(e.y_max)
      glyph_extents.width = f32_as_i32(e.x_max - e.x_min)
      glyph_extents.height = f32_as_i32(e.y_min - e.y_max)
    }
    return ret
  }
  let mut bbox = None
  if self.ttfp_face.tables().glyf is Some(glyf) {
    bbox = glyf.bbox(glyph)
  }

  // See https://github.com/harfbuzz/rustybuzz/pull/98#issuecomment-1948430785
  if self.ttfp_face.tables().glyf is Some(_) && bbox is None {
    // Empty glyph; zero extents.
    return true
  }
  guard bbox is Some(bbox) else { return false }
  glyph_extents.x_bearing = bbox.x_min.to_int()
  glyph_extents.y_bearing = bbox.y_max.to_int()
  glyph_extents.width = bbox.width().to_int()
  glyph_extents.height = (bbox.y_min - bbox.y_max).to_int()
  true
}

///|
fn Face::glyph_name(self : Face, glyph : @otf.GlyphId) -> String? {
  self.ttfp_face.glyph_name(glyph)
}

///|
fn Face::glyph_props(self : Face, glyph : @otf.GlyphId) -> Int {
  guard self.tables().gdef is Some(table) else { return 0 }
  match table.glyph_class(glyph) {
    Some(Base) => GLYPH_PROPS_BASE_GLYPH
    Some(Ligature) => GLYPH_PROPS_LIGATURE
    Some(Mark) => {
      let class = table.glyph_mark_attachment_class(glyph).to_int()
      (class << 8) | GLYPH_PROPS_MARK
    }
    _ => 0
  }
}

///|
fn Face::layout_table(
  self : Face,
  table_index : TableIndex,
) -> @otf.LayoutTable? {
  match table_index {
    GSUB => self.gsub.map(table => table.inner)
    GPOS => self.gpos.map(table => table.inner)
  }
}

///|
/// The present layout tables, GSUB first.
fn Face::layout_tables(self : Face) -> Array[(TableIndex, @otf.LayoutTable)] {
  let out = []
  for idx in [TableIndex::GSUB, TableIndex::GPOS] {
    if self.layout_table(idx) is Some(table) {
      out.push((idx, table))
    }
  }
  out
}

///|
priv struct GlyphExtents {
  mut x_bearing : Int
  mut y_bearing : Int
  mut width : Int
  mut height : Int
}

///|
fn GlyphExtents::new() -> GlyphExtents {
  { x_bearing: 0, y_bearing: 0, width: 0, height: 0, }
}

///|
fn find_best_cmap_subtable(face : @otf.Face) -> Int? {
  // Symbol subtable.
  // Prefer symbol if available.
  // https://github.com/harfbuzz/harfbuzz/issues/1918
  let candidates = [
    (@otf.PlatformId::Windows, WINDOWS_SYMBOL_ENCODING),
    // 32-bit subtables:
    (Windows, WINDOWS_UNICODE_FULL_ENCODING),
    (Unicode, UNICODE_FULL_ENCODING),
    (Unicode, UNICODE_2_0_FULL_ENCODING),
    // 16-bit subtables:
    (Windows, WINDOWS_UNICODE_BMP_ENCODING),
    (Unicode, UNICODE_2_0_BMP_ENCODING),
    (Unicode, UNICODE_ISO_ENCODING),
    (Unicode, UNICODE_1_1_ENCODING),
    (Unicode, UNICODE_1_0_ENCODING),
    // MacRoman subtable:
    (Macintosh, 0),
  ]
  for c in candidates {
    if find_cmap_subtable(face, c.0, c.1) is Some(i) {
      return Some(i)
    }
  }
  None
}

///|
fn find_cmap_subtable(
  face : @otf.Face,
  platform_id : @otf.PlatformId,
  encoding_id : Int,
) -> Int? {
  guard face.tables().cmap is Some(cmap) else { return None }
  for i, subtable in cmap.subtables.iter().to_array() {
    if subtable.platform_id == platform_id &&
      subtable.encoding_id.to_int() == encoding_id {
      return Some(i)
    }
  }
  None
}

///|
let unicode_to_macroman_table : FixedArray[Int] = [
  0x00C4, 0x00C5, 0x00C7, 0x00C9, 0x00D1, 0x00D6, 0x00DC, 0x00E1, 0x00E0, 0x00E2,
  0x00E4, 0x00E3, 0x00E5, 0x00E7, 0x00E9, 0x00E8, 0x00EA, 0x00EB, 0x00ED, 0x00EC,
  0x00EE, 0x00EF, 0x00F1, 0x00F3, 0x00F2, 0x00F4, 0x00F6, 0x00F5, 0x00FA, 0x00F9,
  0x00FB, 0x00FC, 0x2020, 0x00B0, 0x00A2, 0x00A3, 0x00A7, 0x2022, 0x00B6, 0x00DF,
  0x00AE, 0x00A9, 0x2122, 0x00B4, 0x00A8, 0x2260, 0x00C6, 0x00D8, 0x221E, 0x00B1,
  0x2264, 0x2265, 0x00A5, 0x00B5, 0x2202, 0x2211, 0x220F, 0x03C0, 0x222B, 0x00AA,
  0x00BA, 0x03A9, 0x00E6, 0x00F8, 0x00BF, 0x00A1, 0x00AC, 0x221A, 0x0192, 0x2248,
  0x2206, 0x00AB, 0x00BB, 0x2026, 0x00A0, 0x00C0, 0x00C3, 0x00D5, 0x0152, 0x0153,
  0x2013, 0x2014, 0x201C, 0x201D, 0x2018, 0x2019, 0x00F7, 0x25CA, 0x00FF, 0x0178,
  0x2044, 0x20AC, 0x2039, 0x203A, 0xFB01, 0xFB02, 0x2021, 0x00B7, 0x201A, 0x201E,
  0x2030, 0x00C2, 0x00CA, 0x00C1, 0x00CB, 0x00C8, 0x00CD, 0x00CE, 0x00CF, 0x00CC,
  0x00D3, 0x00D4, 0xF8FF, 0x00D2, 0x00DA, 0x00DB, 0x00D9, 0x0131, 0x02C6, 0x02DC,
  0x00AF, 0x02D8, 0x02D9, 0x02DA, 0x00B8, 0x02DD, 0x02DB, 0x02C7,
]

///|
fn unicode_to_macroman(c : Int) -> Int {
  let u = c & 0xFFFF
  for i, m in unicode_to_macroman_table {
    if m == u {
      return 0x80 + i
    }
  }
  0
}
