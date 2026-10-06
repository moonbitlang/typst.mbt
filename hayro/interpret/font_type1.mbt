// Port of `hayro-interpret/src/font/type1.rs`.

///|
priv struct Type1Font {
  cache_key : U128
  kind : Type1Kind
  to_unicode : @cmap.CMap?
}

///|
fn Type1Font::new(
  dict : @hayro_syntax.Dict,
  resolver : FontResolverFn,
  cmap_resolver : CMapResolverFn,
) -> Type1Font? {
  let cache_key = CacheKey::cache_key(dict)
  let to_unicode = read_to_unicode(dict, cmap_resolver)
  let fallback = () => {
    // TODO: Actually use fallback fonts
    let fallback_query = FallbackFontQuery::new(dict)
    let standard_font = fallback_query.pick_standard_font()
    // warn!("unable to load font {}, falling back to {}", ...);
    match StandardKind::new_with_standard(dict, standard_font, true, resolver) {
      Some(s) =>
        Some(Type1Font::{ cache_key, kind: Type1Kind::Standard(s), to_unicode, })
      None => None
    }
  }
  let inner = if is_cff(dict) {
    match CffKind::new(dict) {
      Some(cff) =>
        Type1Font::{ cache_key, kind: Type1Kind::Cff(cff), to_unicode, }
      None => return fallback()
    }
  } else if is_type1(dict) {
    match Type1BlobKind::new(dict) {
      Some(f) =>
        Type1Font::{ cache_key, kind: Type1Kind::Type1(f), to_unicode, }
      None => return fallback()
    }
  } else {
    match StandardKind::new(dict, resolver) {
      Some(standard) =>
        Type1Font::{
          cache_key,
          kind: Type1Kind::Standard(standard),
          to_unicode,
        }
      None => return fallback()
    }
  }
  Some(inner)
}

///|
fn Type1Font::new_standard(
  font : StandardFont,
  resolver : FontResolverFn,
) -> Type1Font? {
  let dict = @hayro_syntax.Dict::empty()
  match StandardKind::new_with_standard(dict, font, true, resolver) {
    Some(standard) =>
      Some(Type1Font::{
        cache_key: U128::default(),
        kind: Type1Kind::Standard(standard),
        to_unicode: None,
      })
    None => None
  }
}

///|
fn Type1Font::map_code(self : Type1Font, code : Byte) -> GlyphId {
  match self.kind {
    Standard(s) => s.map_code(code)
    Type1(s) => s.map_code(code)
    Cff(c) => c.map_code(code)
  }
}

///|
fn Type1Font::outline_glyph(
  self : Type1Font,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  match self.kind {
    Standard(s) => s.outline_glyph(glyph)
    Cff(c) => c.outline_glyph(glyph)
    Type1(t) => t.outline_glyph(glyph)
  }
}

///|
fn Type1Font::glyph_width(self : Type1Font, code : Byte) -> Float? {
  match self.kind {
    Standard(s) => s.glyph_width(code)
    Cff(c) => c.glyph_width(code)
    Type1(t) => t.glyph_width(code)
  }
}

///|
fn Type1Font::char_code_to_unicode(
  self : Type1Font,
  char_code : UInt,
) -> @cmap.BfString? {
  if self.to_unicode is Some(to_unicode) &&
    to_unicode.lookup_bf_string(char_code) is Some(c) {
    // Skip null character mappings and fall back to glyph name
    // lookup. Some PDFs have incorrect ToUnicode mappings that map
    // to U+0000.
    if c != Char('\u{0}') {
      return Some(c)
    }
  }
  let code = char_code.to_byte()
  let c = match self.kind {
    Standard(s) => s.char_code_to_unicode(code)
    Cff(c) => c.char_code_to_unicode(code)
    Type1(t) => t.char_code_to_unicode(code)
  }
  match c {
    Some(c) => Some(Char(c))
    None => None
  }
}

///|
impl CacheKey for Type1Font with fn cache_key(self) {
  self.cache_key
}

///|
priv enum Type1Kind {
  Standard(StandardKind)
  Cff(CffKind)
  Type1(Type1BlobKind)
}

///|
fn is_cff(dict : @hayro_syntax.Dict) -> Bool {
  match (dict.get("FontDescriptor") : @hayro_syntax.Dict?) {
    Some(d) => d.contains_key("FontFile3")
    None => false
  }
}

///|
fn is_type1(dict : @hayro_syntax.Dict) -> Bool {
  match (dict.get("FontDescriptor") : @hayro_syntax.Dict?) {
    Some(d) => d.contains_key("FontFile")
    None => false
  }
}

///|
/// Upstream `Type1Kind` (an embedded Type1 font program).
priv struct Type1BlobKind {
  font : Type1FontBlob
  encoding : Encoding
  widths : Array[Width]
  missing_width : Float
  encodings : Map[Int, String]
  name_to_gid : Map[String, GlyphId]
  standard_font : StandardFont?
}

///|
fn Type1BlobKind::new(dict : @hayro_syntax.Dict) -> Type1BlobKind? {
  guard (dict.get("FontDescriptor") : @hayro_syntax.Dict?) is Some(descriptor) else {
    return None
  }
  guard (descriptor.get("FontFile") : @hayro_syntax.Stream?) is Some(data) else {
    return None
  }
  guard data.decoded() is Ok(decoded) else { return None }
  guard Type1FontBlob::new(decoded.to_bytes()) is Some(font) else {
    return None
  }
  let (encoding, encodings) = read_encoding(dict)
  guard read_widths(dict, descriptor) is Some((widths, missing_width)) else {
    return None
  }
  let standard_font = match select_standard_font(dict, descriptor) {
    Some((f, _)) => Some(f)
    None => None
  }
  let name_to_gid = Map([])
  for item in font.glyph_names() {
    let (gid, name) = item
    name_to_gid[name] = gid
  }
  Some({
    font,
    encoding,
    widths,
    missing_width,
    encodings,
    name_to_gid,
    standard_font,
  })
}

///|
fn Type1BlobKind::name_to_glyph(
  self : Type1BlobKind,
  name : String,
) -> GlyphId? {
  self.name_to_gid.get(name)
}

///|
fn Type1BlobKind::map_code(self : Type1BlobKind, code : Byte) -> GlyphId {
  let g = match self.encodings.get(code.to_int()) {
    Some(entry) => self.name_to_glyph(entry)
    None =>
      match self.encoding {
        BuiltIn => self.font.encoding_map(code)
        _ =>
          match self.encoding.map_code(code) {
            Some(name) => self.name_to_glyph(name)
            None => None
          }
      }
  }
  g.unwrap_or(glyph_id_notdef)
}

///|
fn Type1BlobKind::outline_glyph(
  self : Type1BlobKind,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  self.font.outline_glyph(glyph)
}

///|
fn Type1BlobKind::code_to_ps_name(self : Type1BlobKind, code : Byte) -> String? {
  match self.encodings.get(code.to_int()) {
    Some(s) => Some(s)
    None =>
      match self.encoding {
        BuiltIn => self.font.encoding_glyph_name(code)
        _ => self.encoding.map_code(code)
      }
  }
}

///|
fn Type1BlobKind::glyph_width(self : Type1BlobKind, code : Byte) -> Float? {
  match self.widths.get(code.to_int()) {
    Some(Value(w)) => Some(w)
    Some(Missing) => Some(self.missing_width)
    None => {
      // If font looks like a standard font, get the width from there.
      guard self.standard_font is Some(sf) else { return None }
      match self.code_to_ps_name(code) {
        Some(name) => sf.get_width(name)
        None => None
      }
    }
  }
}

///|
fn Type1BlobKind::char_code_to_unicode(
  self : Type1BlobKind,
  code : Byte,
) -> Char? {
  match self.code_to_ps_name(code) {
    Some(name) => glyph_name_to_unicode(name)
    None => None
  }
}

///|
priv struct CffKind {
  font : CffFontBlob
  encoding : Encoding
  widths : Array[Width]
  missing_width : Float
  encodings : Map[Int, String]
  name_to_gid : Map[String, GlyphId]
  gid_to_name : Array[String?]
  standard_font : StandardFont?
}

///|
fn CffKind::new(dict : @hayro_syntax.Dict) -> CffKind? {
  guard (dict.get("FontDescriptor") : @hayro_syntax.Dict?) is Some(descriptor) else {
    return None
  }
  guard (descriptor.get("FontFile3") : @hayro_syntax.Stream?) is Some(data) else {
    return None
  }
  guard data.decoded() is Ok(decoded) else { return None }
  guard CffFontBlob::new(decoded.to_bytes()) is Some(font) else { return None }
  let (encoding, encodings) = read_encoding(dict)
  guard read_widths(dict, descriptor) is Some((widths, missing_width)) else {
    return None
  }
  let standard_font = match select_standard_font(dict, descriptor) {
    Some((f, _)) => Some(f)
    None => None
  }
  let gid_to_name : Array[String?] = Array::make(font.num_glyphs(), None)
  let name_to_gid = Map([])
  for item in font.glyph_names() {
    let (gid, name) = item
    // Upstream indexes `gid_to_name` directly (panicking if out of bounds).
    gid_to_name[gid.to_int()] = Some(name)
    name_to_gid[name] = gid
  }
  Some({
    font,
    encoding,
    widths,
    missing_width,
    encodings,
    name_to_gid,
    gid_to_name,
    standard_font,
  })
}

///|
fn CffKind::map_code(self : CffKind, code : Byte) -> GlyphId {
  let get_glyph = (entry : String) => {
    match self.name_to_gid.get(entry) {
      Some(g) => Some(g)
      None => self.name_to_gid.get(normalized_glyph_name(entry))
    }
  }
  let g = match self.encodings.get(code.to_int()) {
    Some(entry) => get_glyph(entry)
    None =>
      match self.encoding {
        BuiltIn => self.font.glyph_index(code)
        _ =>
          match self.encoding.map_code(code) {
            Some(name) => get_glyph(name)
            None => None
          }
      }
  }
  g.unwrap_or(glyph_id_notdef)
}

///|
fn CffKind::outline_glyph(self : CffKind, glyph : GlyphId) -> @kurbo.BezPath {
  self.font.outline_glyph(glyph)
}

///|
fn CffKind::code_to_ps_name(self : CffKind, code : Byte) -> String? {
  match self.encodings.get(code.to_int()) {
    Some(entry) => Some(entry)
    None =>
      match self.encoding {
        BuiltIn =>
          match self.font.glyph_index(code) {
            Some(gid) =>
              match self.gid_to_name.get(gid.to_int()) {
                Some(name) => name
                None => None
              }
            None => None
          }
        _ => self.encoding.map_code(code)
      }
  }
}

///|
fn CffKind::glyph_width(self : CffKind, code : Byte) -> Float? {
  match self.widths.get(code.to_int()) {
    Some(Value(w)) => Some(w)
    Some(Missing) => Some(self.missing_width)
    None => {
      // If font looks like a standard font, get the width from there.
      guard self.standard_font is Some(sf) else { return None }
      match self.code_to_ps_name(code) {
        Some(name) => sf.get_width(name)
        None => None
      }
    }
  }
}

///|
fn CffKind::char_code_to_unicode(self : CffKind, code : Byte) -> Char? {
  match self.code_to_ps_name(code) {
    Some(name) => glyph_name_to_unicode(name)
    None => None
  }
}
