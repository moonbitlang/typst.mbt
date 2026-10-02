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
/// A TrueType font.
///
/// TODO: not ported yet (needs `skrifa`); such fonts fail to load.
priv struct TrueTypeFont {
  cache_key : U128
}

///|
fn TrueTypeFont::new(
  _dict : @hayro_syntax.Dict,
  _font_resolver : FontResolverFn,
  _cmap_resolver : CMapResolverFn,
) -> TrueTypeFont? {
  None
}

///|
fn TrueTypeFont::outline_glyph(
  _self : TrueTypeFont,
  _glyph : GlyphId,
) -> @kurbo.BezPath {
  @kurbo.BezPath::new()
}

///|
fn TrueTypeFont::map_code(_self : TrueTypeFont, _code : Byte) -> GlyphId {
  glyph_id_notdef
}

///|
fn TrueTypeFont::glyph_width(_self : TrueTypeFont, _code : Byte) -> Float {
  0.0
}

///|
fn TrueTypeFont::char_code_to_unicode(
  _self : TrueTypeFont,
  _code : UInt,
) -> @cmap.BfString? {
  None
}

///|
impl CacheKey for TrueTypeFont with fn cache_key(self) {
  self.cache_key
}

///|
/// A Type1 font. TODO: not ported yet (needs `skrifa`).
priv struct Type1Font {
  cache_key : U128
}

///|
fn Type1Font::new(
  _dict : @hayro_syntax.Dict,
  _font_resolver : FontResolverFn,
  _cmap_resolver : CMapResolverFn,
) -> Type1Font? {
  None
}

///|
fn Type1Font::new_standard(
  _font : StandardFont,
  _resolver : FontResolverFn,
) -> Type1Font? {
  None
}

///|
fn Type1Font::map_code(_self : Type1Font, _code : Byte) -> GlyphId {
  glyph_id_notdef
}

///|
fn Type1Font::outline_glyph(
  _self : Type1Font,
  _glyph : GlyphId,
) -> @kurbo.BezPath {
  @kurbo.BezPath::new()
}

///|
fn Type1Font::glyph_width(_self : Type1Font, _code : Byte) -> Float? {
  None
}

///|
fn Type1Font::char_code_to_unicode(
  _self : Type1Font,
  _code : UInt,
) -> @cmap.BfString? {
  None
}

///|
impl CacheKey for Type1Font with fn cache_key(self) {
  self.cache_key
}

///|
/// A Type0 (CID) font. TODO: not ported yet (needs `skrifa`).
priv struct Type0Font {
  cache_key : U128
}

///|
fn Type0Font::new(
  _dict : @hayro_syntax.Dict,
  _font_resolver : FontResolverFn,
  _cmap_resolver : CMapResolverFn,
) -> Type0Font? {
  None
}

///|
fn Type0Font::map_code(_self : Type0Font, _code : UInt) -> GlyphId {
  glyph_id_notdef
}

///|
fn Type0Font::outline_glyph(
  _self : Type0Font,
  _glyph : GlyphId,
  _code : UInt,
) -> @kurbo.BezPath {
  @kurbo.BezPath::new()
}

///|
fn Type0Font::code_advance(_self : Type0Font, _code : UInt) -> @kurbo.Vec2 {
  @kurbo.vec2_zero
}

///|
fn Type0Font::origin_displacement(
  _self : Type0Font,
  _code : UInt,
) -> @kurbo.Vec2 {
  @kurbo.vec2_zero
}

///|
fn Type0Font::read_code(
  _self : Type0Font,
  _bytes : Bytes,
  _offset : Int,
) -> (UInt, Int) {
  (0, 1)
}

///|
fn Type0Font::is_horizontal(_self : Type0Font) -> Bool {
  true
}

///|
fn Type0Font::char_code_to_unicode(
  _self : Type0Font,
  _code : UInt,
) -> @cmap.BfString? {
  None
}

///|
impl CacheKey for Type0Font with fn cache_key(self) {
  self.cache_key
}

///|
/// A glyph ID (TEMPORARY until `font_types` is merged).
pub(all) struct GlyphId(UInt) derive(Eq, Hash, Debug)

///|
pub fn GlyphId::new(v : UInt) -> GlyphId {
  GlyphId(v)
}

///|
pub fn GlyphId::to_u32(self : GlyphId) -> UInt {
  self.0
}

///|
let glyph_id_notdef : GlyphId = GlyphId(0)

///|
priv enum OutlineFont {
  Type1(Type1Font)
  TrueType(TrueTypeFont)
  Type0(Type0Font)
}

///|
impl CacheKey for OutlineFont with fn cache_key(self) {
  match self {
    Type1(f) => CacheKey::cache_key(f)
    TrueType(t) => CacheKey::cache_key(t)
    Type0(t0) => CacheKey::cache_key(t0)
  }
}

///|
fn OutlineFont::outline_glyph(
  self : OutlineFont,
  glyph : GlyphId,
  code : UInt,
) -> @kurbo.BezPath {
  match self {
    Type1(t) => t.outline_glyph(glyph)
    TrueType(t) => t.outline_glyph(glyph)
    Type0(t) => t.outline_glyph(glyph, code)
  }
}

///|
fn OutlineFont::char_code_to_unicode(
  self : OutlineFont,
  char_code : UInt,
) -> @cmap.BfString? {
  match self {
    Type1(t) => t.char_code_to_unicode(char_code)
    TrueType(t) => t.char_code_to_unicode(char_code)
    Type0(t) => t.char_code_to_unicode(char_code)
  }
}

///|
/// Get the advance width for a glyph by character code.
fn OutlineFont::glyph_advance_width(
  self : OutlineFont,
  char_code : UInt,
) -> Float? {
  match self {
    Type1(t) => t.glyph_width(char_code.to_byte())
    TrueType(t) => Some(t.glyph_width(char_code.to_byte()))
    Type0(t) => Some(t.code_advance(char_code).x.to_float())
  }
}

///|
/// The 14 standard fonts of PDF.
pub(all) enum StandardFont {
  /// Helvetica.
  Helvetica
  /// Helvetica Bold.
  HelveticaBold
  /// Helvetica Oblique.
  HelveticaOblique
  /// Helvetica Bold Oblique.
  HelveticaBoldOblique
  /// Courier.
  Courier
  /// Courier Bold.
  CourierBold
  /// Courier Oblique.
  CourierOblique
  /// Courier Bold Oblique.
  CourierBoldOblique
  /// Times Roman.
  TimesRoman
  /// Times Bold.
  TimesBold
  /// Times Italic.
  TimesItalic
  /// Times Bold Italic.
  TimesBoldItalic
  /// Zapf Dingbats - a decorative symbol font.
  ZapfDingBats
  /// Symbol - a mathematical symbol font.
  Symbol
} derive(Eq, Debug)
