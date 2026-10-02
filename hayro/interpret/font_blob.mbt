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
priv struct Type1FontBlob {
  table : @ps.Type1Font
}

///|
fn Type1FontBlob::new(data : Bytes) -> Type1FontBlob? {
  let table = @ps.Type1Font::new(data[:]) catch { _ => return None }
  Some({ table, })
}

///|
fn Type1FontBlob::outline_glyph(
  self : Type1FontBlob,
  gid : GlyphId,
) -> @kurbo.BezPath {
  let path = OutlinePath::new()
  let _ = self.table.draw(gid, Some(units_per_em), path) catch { _ => None }
  path.take()
}

///|
fn Type1FontBlob::glyph_names(self : Type1FontBlob) -> Array[(GlyphId, String)] {
  self.table.glyph_names()
}

///|
/// `table().encoding().and_then(|e| e.map(code))`.
fn Type1FontBlob::encoding_map(self : Type1FontBlob, code : Byte) -> GlyphId? {
  match self.table.encoding() {
    Some(e) => e.map(code)
    None => None
  }
}

///|
/// `table().encoding().and_then(|e| e.glyph_name(code))`.
fn Type1FontBlob::encoding_glyph_name(
  self : Type1FontBlob,
  code : Byte,
) -> String? {
  match self.table.encoding() {
    Some(e) => e.glyph_name(code)
    None => None
  }
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
priv struct OpenTypeFontBlob {
  data : Bytes
  font_ref : @read_fonts.FontRef
  outline_glyphs : @skrifa.OutlineGlyphCollection
  hinting_instance : @skrifa.HintingInstance?
  glyph_metrics : @skrifa.GlyphMetrics
  cff_blob : CffFontBlob?
}

///|
fn OpenTypeFontBlob::new(data : Bytes, index : Int) -> OpenTypeFontBlob? {
  // Check first whether the font is valid.
  let f = @read_fonts.FontRef::from_index(data[:], index) catch {
    _ => return None
  }
  // Reject fonts with invalid post table version, fixes pdf.js issue 9462. Not sure if there
  // is a better fix, for some reason skrifa accepts the font which is completely invalid.
  let invalid = match (try? f.post()) {
    Ok(p) =>
      !(p.version().to_major_minor() is ((1, 0) | (2, 0) | (2, 5) | (3, 0)))
    Err(_) => false
  }
  if invalid {
    return None
  }

  // We store this separately because we want to be able to cache the subfonts
  // of a CFF OpenType font, which is not possible using the current skrifa API.
  // Hopefully there will be some way in the future.
  let cff_blob = match (try? f.cff()) {
    Ok(cff) => CffFontBlob::new(cff.offset_data().to_bytes())
    Err(_) => None
  }
  let outline_glyphs = @skrifa.outline_glyphs(f)
  let hinting_instance = if outline_glyphs.require_interpreter() {
    try
      @skrifa.HintingInstance::new(
        outline_glyphs,
        @skrifa.Size::new(units_per_em),
        @skrifa.LocationRef::default(),
        { engine: Interpreter, target: Mono, },
      )
    catch {
      _ => None
    } noraise {
      h => Some(h)
    }
  } else {
    None
  }
  let glyph_metrics = @skrifa.glyph_metrics(
    f,
    @skrifa.Size::new(units_per_em),
    @skrifa.LocationRef::default(),
  )
  Some({
    data,
    font_ref: f,
    outline_glyphs,
    hinting_instance,
    glyph_metrics,
    cff_blob,
  })
}

///|
fn OpenTypeFontBlob::font_data(self : OpenTypeFontBlob) -> Bytes {
  self.data
}

///|
fn OpenTypeFontBlob::glyph_names(
  self : OpenTypeFontBlob,
) -> Map[String, GlyphId] {
  // Note: We don't call the `glyph_name` method provided by read-fonts because
  // calling it repeatedly is very slow.
  let glyph_names = {}
  guard (try? self.font_ref.post()) is Ok(post) else { return glyph_names }
  match post.version().to_major_minor() {
    (1, 0) =>
      for gid, name in @read_fonts.default_glyph_names {
        glyph_names[name] = GlyphId::new(gid.reinterpret_as_uint())
      }
    (2, 0) => {
      guard post.glyph_name_index() is Some(name_indices) else {
        return glyph_names
      }
      guard post.string_data() is Some(string_data) else { return glyph_names }
      let custom_names : Array[String?] = string_data.map(entry => {
        match entry {
          Ok(name) => Some(name)
          Err(_) => None
        }
      })
      let defaults = @read_fonts.default_glyph_names
      for gid, idx in name_indices {
        let name = if idx < defaults.length() {
          Some(defaults[idx])
        } else {
          match custom_names.get(idx - defaults.length()) {
            Some(n) => n
            None => None
          }
        }
        if name is Some(name) {
          glyph_names[name] = GlyphId::new(gid.reinterpret_as_uint())
        }
      }
    }
    _ => ()
  }
  glyph_names
}

///|
fn OpenTypeFontBlob::outline_glyph(
  self : OpenTypeFontBlob,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  if self.cff_blob is Some(cff_blob) {
    return cff_blob.outline_glyph(glyph)
  }
  let path = OutlinePath::new()
  let draw_settings = match self.hinting_instance {
    // Note: We always hint at the font size `UNITS_PER_EM`, which obviously isn't very useful. We don't do this
    // for better text quality (right now), but instead because there are some PDFs with obscure fonts that
    // actually render wrongly if hinting is disabled!
    Some(instance) => @skrifa.DrawSettings::hinted(instance, false)
    None =>
      @skrifa.DrawSettings::unhinted(
        @skrifa.Size::new(units_per_em),
        @skrifa.LocationRef::default(),
      )
  }
  guard self.outline_glyphs.get(glyph) is Some(outline) else {
    return @kurbo.BezPath::new()
  }
  let _ = try? outline.draw(draw_settings, path)
  path.take()
}

///|
fn OpenTypeFontBlob::advance_width(
  self : OpenTypeFontBlob,
  glyph : GlyphId,
) -> Float? {
  self.glyph_metrics.advance_width(glyph)
}

///|
/// `font_ref().cmap().ok()?.map_codepoint(code)`.
fn OpenTypeFontBlob::map_codepoint(
  self : OpenTypeFontBlob,
  code : UInt,
) -> GlyphId? {
  match (try? self.font_ref.cmap()) {
    Ok(c) => c.map_codepoint(code)
    Err(_) => None
  }
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
  self : OpenTypeFontBlob,
) -> Array[CmapRecord]? {
  guard (try? self.font_ref.cmap()) is Ok(cmap) else { return None }
  Some(
    cmap
    .encoding_records()
    .map(record => {
      let platform_id = match record.platform_id() {
        Unicode => 0
        Macintosh => 1
        ISO => 2
        Windows => 3
        Custom => 4
        Unknown => 5
      }
      let subtable : ((UInt) -> GlyphId?)? = match
        (try? record.subtable(cmap.offset_data())) {
        Ok(st) => Some(c => st.map_codepoint(c))
        Err(_) => None
      }
      { platform_id, encoding_id: record.encoding_id(), subtable, }
    }),
  )
}

///|
/// The blob of the font's `CFF` table, if any.
fn OpenTypeFontBlob::cff_blob(self : OpenTypeFontBlob) -> CffFontBlob? {
  match (try? self.font_ref.cff()) {
    Ok(cff) => CffFontBlob::new(cff.offset_data().to_bytes())
    Err(_) => None
  }
}

///|
/// `font_ref().attributes().weight.value()`.
fn OpenTypeFontBlob::weight(self : OpenTypeFontBlob) -> Float {
  @skrifa.attributes(self.font_ref).weight.value()
}

///|
/// `font_ref().attributes().style == Style::Normal`.
fn OpenTypeFontBlob::style_is_normal(self : OpenTypeFontBlob) -> Bool {
  @skrifa.attributes(self.font_ref).style == Normal
}

///|
/// `font_ref().metrics(Size::unscaled(), LocationRef::default()).is_monospace`.
fn OpenTypeFontBlob::is_monospace(self : OpenTypeFontBlob) -> Bool {
  @skrifa.metrics(
    self.font_ref,
    @skrifa.Size::unscaled(),
    @skrifa.LocationRef::default(),
  ).is_monospace
}

///|
/// `font_ref().charmap().map(c)`.
fn OpenTypeFontBlob::charmap_map(self : OpenTypeFontBlob, c : Char) -> GlyphId? {
  @skrifa.charmap(self.font_ref).map_char(c)
}

///|
/// Whether the data is a valid OpenType font (`FontRef::from_index(data, 0).is_ok()`).
fn is_open_type(data : Bytes) -> Bool {
  (try? @read_fonts.FontRef::from_index(data[:], 0)) is Ok(_)
}
