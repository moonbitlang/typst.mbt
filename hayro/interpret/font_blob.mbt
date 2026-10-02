// Port of `hayro-interpret/src/font/blob.rs`.

///|
/// A glyph ID.
pub type GlyphId = @font_types.GlyphId

///|
let glyph_id_notdef : GlyphId = @font_types.GlyphId::notdef()

///|
/// Decode the bytes of a glyph name (upstream `std::str::from_utf8`).
fn glyph_name_from_bytes(bytes : BytesView) -> String? {
  try @utf8.decode(bytes) catch {
    _ => None
  } noraise {
    s => Some(s)
  }
}

///|
/// A font blob for type 1 fonts.
///
/// TODO: not ported yet (needs `read_fonts::ps::type1`); such fonts fail to
/// load.
priv struct Type1FontBlob {
  dummy : Unit
}

///|
fn Type1FontBlob::new(_data : Bytes) -> Type1FontBlob? {
  None
}

///|
fn Type1FontBlob::outline_glyph(
  _self : Type1FontBlob,
  _gid : GlyphId,
) -> @kurbo.BezPath {
  @kurbo.BezPath::new()
}

///|
fn Type1FontBlob::glyph_names(
  _self : Type1FontBlob,
) -> Array[(GlyphId, String)] {
  []
}

///|
fn Type1FontBlob::encoding_map(_self : Type1FontBlob, _code : Byte) -> GlyphId? {
  None
}

///|
fn Type1FontBlob::encoding_glyph_name(
  _self : Type1FontBlob,
  _code : Byte,
) -> String? {
  None
}

///|
fn Type1FontBlob::has_encoding(_self : Type1FontBlob) -> Bool {
  false
}

///|
/// A font blob for CFF-based fonts.
priv struct CffFontBlob {
  data : Bytes
  font : @ps.CffFontRef
  cff : @ps.Cff
  charset : @ps.Charset?
  subfonts : Array[@ps.Subfont]
}

///|
fn CffFontBlob::new(data : Bytes) -> CffFontBlob? {
  let font = @ps.CffFontRef::new(data[:], 0, None) catch { _ => return None }
  let cff = @ps.Cff::read(data[:]) catch { _ => return None }
  let charset = font.charset()
  let subfonts = []
  for index in 0..<font.num_subfonts() {
    let subfont = font.subfont(index, []) catch { _ => return None }
    subfonts.push(subfont)
  }
  Some({ data, font, cff, charset, subfonts, })
}

///|
fn CffFontBlob::font_data(self : CffFontBlob) -> Bytes {
  self.data
}

///|
fn CffFontBlob::subfont(self : CffFontBlob, glyph : GlyphId) -> @ps.Subfont? {
  guard self.font.subfont_index(glyph) is Some(index) else { return None }
  self.subfonts.get(index)
}

///|
fn CffFontBlob::outline_glyph(
  self : CffFontBlob,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  let path = OutlinePath::new()
  guard self.subfont(glyph) is Some(subfont) else {
    return @kurbo.BezPath::new()
  }
  let _ = self.font.draw(subfont, glyph, [], Some(units_per_em), path) catch {
    _ => None
  }
  path.take()
}

///|
fn CffFontBlob::glyph_names(self : CffFontBlob) -> Array[(GlyphId, String)] {
  guard self.charset is Some(charset) else { return [] }
  let result = []
  for item in charset.iter() {
    let (gid, sid) = item
    guard self.cff.string(sid) is Some(bytes) else { continue }
    guard glyph_name_from_bytes(bytes) is Some(name) else { continue }
    result.push((gid, name))
  }
  result
}

///|
fn CffFontBlob::glyph_index_by_name(
  self : CffFontBlob,
  name : String,
) -> GlyphId? {
  guard self.charset is Some(charset) else { return None }
  let name_bytes = @utf8.encode(name)
  for item in charset.iter() {
    let (gid, sid) = item
    guard self.cff.string(sid) is Some(bytes) else { continue }
    if bytes == name_bytes[:] {
      return Some(gid)
    }
  }
  None
}

///|
fn CffFontBlob::glyph_index_by_cid(self : CffFontBlob, cid : Int) -> GlyphId? {
  guard self.charset is Some(charset) else { return None }
  try charset.glyph_id(@ps.Sid::new(cid)) catch {
    _ => None
  } noraise {
    g => Some(g)
  }
}

///|
fn CffFontBlob::glyph_index(self : CffFontBlob, code : Byte) -> GlyphId? {
  match self.font.encoding() {
    Some(encoding) => encoding.map(code)
    None => None
  }
}

///|
fn CffFontBlob::num_glyphs(self : CffFontBlob) -> Int {
  self.font.num_glyphs()
}

///|
fn CffFontBlob::is_cid(self : CffFontBlob) -> Bool {
  self.font.is_cid()
}

///|
/// A font blob for OpenType fonts.
///
/// TODO: not ported yet (needs `skrifa`); such fonts fail to load.
priv struct OpenTypeFontBlob {
  data : Bytes
}

///|
fn OpenTypeFontBlob::new(_data : Bytes, _index : Int) -> OpenTypeFontBlob? {
  None
}

///|
fn OpenTypeFontBlob::font_data(self : OpenTypeFontBlob) -> Bytes {
  self.data
}

///|
fn OpenTypeFontBlob::glyph_names(
  _self : OpenTypeFontBlob,
) -> Map[String, GlyphId] {
  {}
}

///|
fn OpenTypeFontBlob::outline_glyph(
  _self : OpenTypeFontBlob,
  _glyph : GlyphId,
) -> @kurbo.BezPath {
  @kurbo.BezPath::new()
}

///|
fn OpenTypeFontBlob::advance_width(
  _self : OpenTypeFontBlob,
  _glyph : GlyphId,
) -> Float? {
  None
}

///|
/// `font_ref().cmap().ok()?.map_codepoint(code)`.
fn OpenTypeFontBlob::map_codepoint(
  _self : OpenTypeFontBlob,
  _code : UInt,
) -> GlyphId? {
  None
}

///|
/// An encoding record of the `cmap` table.
priv struct CmapRecord {
  platform_id : Int
  encoding_id : Int
  /// `map_codepoint` of the record's subtable (`None` if it fails to parse).
  subtable : ((UInt) -> GlyphId?)?
}

///|
/// The encoding records of the `cmap` table (`None` if there is no valid
/// `cmap` table).
fn OpenTypeFontBlob::cmap_records(
  _self : OpenTypeFontBlob,
) -> Array[CmapRecord]? {
  None
}

///|
/// The blob of the font's `CFF` table, if any.
fn OpenTypeFontBlob::cff_blob(_self : OpenTypeFontBlob) -> CffFontBlob? {
  None
}

///|
/// `font_ref().attributes().weight.value()`.
fn OpenTypeFontBlob::weight(_self : OpenTypeFontBlob) -> Float {
  400.0
}

///|
/// `font_ref().attributes().style == Style::Normal`.
fn OpenTypeFontBlob::style_is_normal(_self : OpenTypeFontBlob) -> Bool {
  true
}

///|
/// `font_ref().metrics(Size::unscaled(), LocationRef::default()).is_monospace`.
fn OpenTypeFontBlob::is_monospace(_self : OpenTypeFontBlob) -> Bool {
  false
}

///|
/// `font_ref().charmap().map(c)`.
fn OpenTypeFontBlob::charmap_map(
  _self : OpenTypeFontBlob,
  _c : Char,
) -> GlyphId? {
  None
}

///|
/// Whether the data is a valid OpenType font (`FontRef::from_index(data, 0).is_ok()`).
fn is_open_type(_data : Bytes) -> Bool {
  false
}
