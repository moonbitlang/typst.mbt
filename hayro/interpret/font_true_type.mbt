// Port of `hayro-interpret/src/font/true_type.rs`.

///|
priv enum Width {
  Value(Float)
  Missing
}

///|
fn read_widths(
  dict : @hayro_syntax.Dict,
  descriptor : @hayro_syntax.Dict,
) -> (Array[Width], Float)? {
  let widths = []
  let first_char = (dict.get("FirstChar") : UInt?)
  let last_char = (dict.get("LastChar") : UInt?)
  let widths_arr = (dict.get("Widths") : @hayro_syntax.PdfArray?)
  let missing_width = (descriptor.get("MissingWidth") : Float?).unwrap_or(0.0)
  if (first_char, last_char, widths_arr) is (Some(fc), Some(lc), Some(w)) {
    guard lc >= fc else { return None }
    let take = (lc - fc).to_uint64() + 1
    for _ in 0U..<fc {
      widths.push(Missing)
    }
    let mut taken = 0UL
    for w in (w.iter() : Iter[Float]) {
      if taken >= take {
        break
      }
      widths.push(Value(w))
      taken += 1
    }
    while widths.length() <= 255 + 1 {
      widths.push(Missing)
    }
  }
  Some((widths, missing_width))
}

///|
fn glyph_num_string(s : String) -> UInt? {
  if !s.has_prefix("g") || s.length() < 2 {
    return None
  }
  // `s[1..].parse::<u32>()`
  let rest = s.view(start_offset=1)
  let mut v : UInt64 = 0
  let mut first = true
  for c in rest {
    if first && c == '+' {
      first = false
      continue
    }
    first = false
    guard c >= '0' && c <= '9' else { return None }
    v = v * 10 + (c.to_int() - '0'.to_int()).to_uint64()
    if v > 0xFFFF_FFFFUL {
      return None
    }
  }
  if rest == "+" {
    return None
  }
  Some(v.to_uint())
}

///|
fn read_encoding(dict : @hayro_syntax.Dict) -> (Encoding, Map[Int, String]) {
  fn get_encoding_base(dict : @hayro_syntax.Dict, name : String) -> Encoding {
    match (dict.get(name) : @hayro_syntax.Name?) {
      Some(n) =>
        match n.as_str() {
          "WinAnsiEncoding" => WinAnsi
          "MacRomanEncoding" => MacRoman
          "MacExpertEncoding" => MacExpert
          "StandardEncoding" => Standard
          _ =>
            // warn!("Unknown font encoding {}", name.as_str());
            BuiltIn
        }
      None => BuiltIn
    }
  }

  let map = {}
  if (dict.get("Encoding") : @hayro_syntax.Dict?) is Some(encoding_dict) {
    if (encoding_dict.get("Differences") : @hayro_syntax.PdfArray?)
      is Some(differences) {
      let mut code = 0L
      for obj in (differences.iter() : Iter[@hayro_syntax.Object]) {
        match obj {
          Number(num) => code = num.as_i64()
          Name(name) => {
            if code >= 0L && code <= 255L {
              map[code.to_int()] = name.as_str()
            }
            code += 1L
          }
          _ => ()
        }
      }
    }
    (get_encoding_base(encoding_dict, "BaseEncoding"), map)
  } else {
    (get_encoding_base(dict, "Encoding"), {})
  }
}

///|
priv struct TrueTypeFont {
  cache_key : U128
  kind : TrueTypeKind
  to_unicode : @cmap.CMap?
}

///|
priv enum TrueTypeKind {
  Embedded(EmbeddedKind)
  Standard(StandardKind)
}

///|
fn TrueTypeFont::new(
  dict : @hayro_syntax.Dict,
  font_resolver : FontResolverFn,
  cmap_resolver : CMapResolverFn,
) -> TrueTypeFont? {
  let cache_key = CacheKey::cache_key(dict)
  let to_unicode = read_to_unicode(dict, cmap_resolver)
  if EmbeddedKind::new(dict) is Some(embedded) {
    return Some(TrueTypeFont::{
      cache_key,
      kind: Embedded(embedded),
      to_unicode,
    })
  }
  let fallback = () => {
    let fallback_query = FallbackFontQuery::new(dict)
    let standard_font = fallback_query.pick_standard_font()
    // warn!("unable to load TrueType font {}, falling back to {}", ...);
    match
      StandardKind::new_with_standard(dict, standard_font, true, font_resolver) {
      Some(s) =>
        Some(TrueTypeFont::{
          cache_key,
          kind: TrueTypeKind::Standard(s),
          to_unicode,
        })
      None => None
    }
  }
  match StandardKind::new(dict, font_resolver) {
    Some(standard) =>
      Some(TrueTypeFont::{
        cache_key,
        kind: TrueTypeKind::Standard(standard),
        to_unicode,
      })
    None => fallback()
  }
}

///|
fn TrueTypeFont::outline_glyph(
  self : TrueTypeFont,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  match self.kind {
    Embedded(e) => e.outline_glyph(glyph)
    Standard(s) => s.outline_glyph(glyph)
  }
}

///|
fn TrueTypeFont::font_data(self : TrueTypeFont) -> Bytes? {
  match self.kind {
    Embedded(e) => Some(e.base_font.font_data())
    Standard(_) => None
  }
}

///|
fn TrueTypeFont::postscript_name(self : TrueTypeFont) -> String? {
  match self.kind {
    Embedded(e) => e.postscript_name
    Standard(_) => None
  }
}

///|
fn TrueTypeFont::weight(self : TrueTypeFont) -> UInt? {
  match self.kind {
    Embedded(e) => {
      let weight = f32_as_u32(rust_round_f32(e.base_font.weight())).reinterpret_as_uint()
      if weight > 0 {
        Some(weight)
      } else {
        None
      }
    }
    Standard(s) => Some(if s.is_bold() { 700 } else { 400 })
  }
}

///|
fn TrueTypeFont::is_italic(self : TrueTypeFont) -> Bool {
  match self.kind {
    Embedded(e) => {
      // Check PDF font flags first
      if e.font_flags is Some(flags) && (flags & FONT_FLAG_ITALIC) != 0 {
        return true
      }
      // Check skrifa font attributes
      !e.base_font.style_is_normal()
    }
    Standard(s) => s.is_italic()
  }
}

///|
fn TrueTypeFont::is_serif(self : TrueTypeFont) -> Bool {
  match self.kind {
    Embedded(e) => e.font_flags is Some(f) && (f & FONT_FLAG_SERIF) != 0
    Standard(s) => s.is_serif()
  }
}

///|
fn TrueTypeFont::is_monospace(self : TrueTypeFont) -> Bool {
  match self.kind {
    Embedded(e) => {
      // Check PDF font flags first
      if e.font_flags is Some(flags) && (flags & FONT_FLAG_FIXED_PITCH) != 0 {
        return true
      }
      // Check skrifa font metrics
      e.base_font.is_monospace()
    }
    Standard(s) => s.is_monospace()
  }
}

///|
fn TrueTypeFont::map_code(self : TrueTypeFont, code : Byte) -> GlyphId {
  match self.kind {
    Embedded(e) => e.map_code(code)
    Standard(s) => s.map_code(code)
  }
}

///|
fn TrueTypeFont::glyph_width(self : TrueTypeFont, code : Byte) -> Float {
  match self.kind {
    Embedded(e) => e.glyph_width(code)
    Standard(s) => s.glyph_width(code).unwrap_or(0.0)
  }
}

///|
fn TrueTypeFont::char_code_to_unicode(
  self : TrueTypeFont,
  code : UInt,
) -> @cmap.BfString? {
  if self.to_unicode is Some(to_unicode) &&
    to_unicode.lookup_bf_string(code) is Some(c) {
    return Some(c)
  }
  let c = match self.kind {
    Embedded(e) =>
      match e.code_to_name(code.to_byte()) {
        Some(name) => glyph_name_to_unicode(name)
        None => None
      }
    Standard(s) => s.char_code_to_unicode(code.to_byte())
  }
  // TODO: The test PDFs below fail (but mutool can render them correctly).
  // There is likely some other strategy that requires processing the font tables
  // hayro-tests/pdfs/custom/font_truetype_7.pdf
  // hayro-tests/pdfs/custom/font_truetype_6.pdf
  match c {
    Some(c) => Some(Char(c))
    None => None
  }
}

///|
impl CacheKey for TrueTypeFont with fn cache_key(self) {
  self.cache_key
}

///|
priv struct EmbeddedKind {
  base_font : OpenTypeFontBlob
  widths : Array[Width]
  missing_width : Float
  font_flags : UInt?
  glyph_names : Map[String, GlyphId]
  encoding : Encoding
  // Only used for PDFs that mistakenly embed a
  // CFF font.
  cff_blob : CffFontBlob?
  differences : Map[Int, String]
  cached_mappings : Map[Int, GlyphId]
  /// PostScript name from the PDF.
  postscript_name : String?
}

///|
fn EmbeddedKind::new(dict : @hayro_syntax.Dict) -> EmbeddedKind? {
  let descriptor = (dict.get("FontDescriptor") : @hayro_syntax.Dict?).unwrap_or(
    @hayro_syntax.Dict::empty(),
  )
  let font_flags = match (descriptor.get("Flags") : UInt?) {
    Some(bits) => font_flags_from_bits(bits)
    None => None
  }
  guard read_widths(dict, descriptor) is Some((widths, missing_width)) else {
    return None
  }
  let (encoding, differences) = read_encoding(dict)
  guard (descriptor.get("FontFile2") : @hayro_syntax.Stream?) is Some(s) &&
    s.decoded() is Ok(d) &&
    OpenTypeFontBlob::new(d.to_bytes(), 0) is Some(base_font) else {
    return None
  }
  let glyph_names = base_font.glyph_names()
  let cff_font_blob = base_font.cff_blob()
  let postscript_name = match (dict.get("BaseFont") : @hayro_syntax.Name?) {
    Some(n) => Some(strip_subset_prefix(n.as_str()))
    None => None
  }
  Some({
    base_font,
    differences,
    cff_blob: cff_font_blob,
    widths,
    missing_width,
    glyph_names,
    font_flags,
    encoding,
    cached_mappings: {},
    postscript_name,
  })
}

///|
fn EmbeddedKind::is_non_symbolic(self : EmbeddedKind) -> Bool {
  match self.font_flags {
    Some(f) => (f & FONT_FLAG_NON_SYMBOLIC) != 0
    None => false
  }
}

///|
fn EmbeddedKind::code_to_name(self : EmbeddedKind, code : Byte) -> String? {
  match self.differences.get(code.to_int()) {
    Some(s) => Some(s)
    None =>
      match self.encoding.map_code(code) {
        Some(s) => Some(s)
        // See PDFJS-6410 - PDF has no base encoding, so let's fallback to
        // standard here.
        None => standard_get(code)
      }
  }
}

///|
fn EmbeddedKind::outline_glyph(
  self : EmbeddedKind,
  glyph : GlyphId,
) -> @kurbo.BezPath {
  self.base_font.outline_glyph(glyph)
}

///|
fn not_notdef(g : GlyphId?) -> GlyphId? {
  match g {
    Some(g) if g != glyph_id_notdef => Some(g)
    _ => None
  }
}

///|
fn EmbeddedKind::map_code(self : EmbeddedKind, code : Byte) -> GlyphId {
  if self.cached_mappings.get(code.to_int()) is Some(glyph) {
    return glyph
  }
  if self.cff_blob is Some(blob) {
    return match self.code_to_name(code) {
      Some(name) => blob.glyph_index_by_name(name).unwrap_or(glyph_id_notdef)
      None => glyph_id_notdef
    }
  }
  let mut glyph : GlyphId? = None
  if self.is_non_symbolic() {
    guard self.code_to_name(code) is Some(lookup) else {
      return glyph_id_notdef
    }
    if self.base_font.cmap_records() is Some(records) {
      for record in records {
        if record.platform_id == 3 &&
          record.encoding_id == 1 &&
          record.subtable is Some(subtable) &&
          glyph is None {
          let c = match glyph_names_get(lookup) {
            Some(n) => n.iter().next()
            None => unicode_from_name(lookup)
          }
          glyph = match c {
            Some(c) => not_notdef(subtable(c.to_uint()))
            None => None
          }
        }
      }
      for record in records {
        if record.platform_id == 1 &&
          record.encoding_id == 0 &&
          record.subtable is Some(subtable) &&
          glyph is None {
          let c = match mac_os_roman_get_inverse(lookup) {
            Some(c) => Some(c)
            None => mac_roman_get_inverse(lookup)
          }
          glyph = match c {
            Some(c) => not_notdef(subtable(c.to_uint()))
            None => None
          }
        }
      }
    }
    if glyph is None {
      if self.glyph_names.get(lookup) is Some(gid) {
        glyph = Some(gid)
      } else if glyph_num_string(lookup) is Some(gid) {
        glyph = Some(GlyphId::new(gid))
      }
    }
  } else if self.base_font.cmap_records() is Some(records) {
    for record in records {
      if record.platform_id == 3 &&
        (record.encoding_id == 0 || record.encoding_id == 1) {
        if record.subtable is Some(subtable) {
          for offset in [0x0000U, 0xF000, 0xF100, 0xF200] {
            glyph = match glyph {
              Some(g) => not_notdef(Some(g))
              None => not_notdef(subtable(code.to_uint() + offset))
            }
          }
        }
      } else if (record.platform_id == 1 || record.platform_id == 0) &&
        record.encoding_id == 0 &&
        record.subtable is Some(subtable) {
        glyph = match glyph {
          Some(g) => not_notdef(Some(g))
          None => not_notdef(subtable(code.to_uint()))
        }
      }
    }
  }
  let glyph = glyph.unwrap_or(glyph_id_notdef)
  self.cached_mappings[code.to_int()] = glyph
  glyph
}

///|
fn EmbeddedKind::glyph_width(self : EmbeddedKind, code : Byte) -> Float {
  match self.widths.get(code.to_int()) {
    Some(Value(w)) => w
    Some(Missing) => self.missing_width
    _ =>
      // warn_none: "failed to find advance width for code {code}"
      self.base_font.advance_width(self.map_code(code)).unwrap_or(0.0)
  }
}

///|
/// Rust's `f32::round` (half away from zero).
fn rust_round_f32(x : Float) -> Float {
  if x.is_nan() || x.is_inf() {
    return x
  }
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    t + (if x < 0.0 { -1.0 } else { 1.0 })
  } else {
    t
  }
}
