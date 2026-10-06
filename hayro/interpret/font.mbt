// Port of `hayro-interpret/src/font/mod.rs`: interacting with the different
// kinds of PDF fonts.

///|
let units_per_em : Float = 1000.0

///|
fn stretch_glyph(
  path : @kurbo.BezPath,
  expected_width : Float,
  actual_width : Float,
) -> @kurbo.BezPath {
  if actual_width != 0.0 && actual_width != expected_width {
    let stretch_factor = expected_width / actual_width
    path.transform(
      @kurbo.Affine::scale_non_uniform(stretch_factor.to_double(), 1.0),
    )
  } else {
    path
  }
}

///|
/// Strip the 6-character subset prefix from a PostScript font name.
///
/// PDF subset fonts use names like "ABCDEF+TimesNewRoman". This function
/// returns `TimesNewRoman` from such a name, or the original name if no
/// valid prefix is found.
fn strip_subset_prefix(name : String) -> String {
  match name.find("+") {
    Some(i) if i == 6 && name.length() >= 7 =>
      name.view(start_offset=7).to_owned()
    _ => name
  }
}

///|
/// A glyph that can be drawn.
pub enum Glyph {
  /// A glyph defined by an outline.
  Outline(OutlineGlyph)
  /// A type3 glyph, defined by PDF drawing instructions.
  Type3(Type3Glyph)
}

///|
/// Returns the Unicode code point for this glyph, if available.
///
/// For outline fonts (Type1, TrueType, CFF): the `ToUnicode` cmap, the glyph
/// name (via the Adobe Glyph List) and Unicode naming conventions (e.g.
/// "uni0041", "u0041"). For CID and Type3 fonts: the `ToUnicode` cmap.
pub fn Glyph::as_unicode(self : Glyph) -> @cmap.BfString? {
  match self {
    Outline(g) => g.as_unicode()
    Type3(g) => g.as_unicode()
  }
}

///|
/// An identifier that uniquely identifies a glyph, for caching purposes.
pub struct GlyphIdentifier {
  priv id : GlyphId
  priv font : OutlineFont
}

///|
pub impl CacheKey for GlyphIdentifier with fn cache_key(self) {
  let font_key = CacheKey::cache_key(self.font)
  hash128(h => {
    h.write_u32(self.id.to_u32())
    h.write_u128(font_key)
  })
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphIdentifier with CacheKey::{cache_key}

///|
/// A glyph defined by an outline.
pub struct OutlineGlyph {
  priv id : GlyphId
  priv font : OutlineFont
  priv char_code : UInt
}

///|
/// Return the outline of the glyph, assuming an upem value of 1000.
pub fn OutlineGlyph::outline(self : OutlineGlyph) -> @kurbo.BezPath {
  self.font.outline_glyph(self.id, self.char_code)
}

///|
/// Return the identifier of the glyph. You can use this to calculate the
/// cache key for the glyph.
///
/// Note that the `glyph_transform` attribute is not considered in the cache
/// key of the identifier, only the glyph ID and the font.
pub fn OutlineGlyph::identifier(self : OutlineGlyph) -> GlyphIdentifier {
  { id: self.id, font: self.font, }
}

///|
/// Returns the Unicode code point for this glyph, if available.
pub fn OutlineGlyph::as_unicode(self : OutlineGlyph) -> @cmap.BfString? {
  self.font.char_code_to_unicode(self.char_code)
}

///|
/// Get the glyph ID within the font.
pub fn OutlineGlyph::glyph_id(self : OutlineGlyph) -> GlyphId {
  self.id
}

///|
/// Get the advance width for this glyph.
pub fn OutlineGlyph::advance_width(self : OutlineGlyph) -> Float? {
  self.font.glyph_advance_width(self.char_code)
}

///|
/// Get the cache key for this glyph's font.
pub fn OutlineGlyph::font_cache_key(self : OutlineGlyph) -> U128 {
  CacheKey::cache_key(self.font)
}

///|
/// A glyph defined by PDF drawing instructions.
pub struct Type3Glyph {
  priv font : Type3
  priv glyph_id : GlyphId
  priv state : State
  priv parent_resources : @hayro_syntax.Resources
  priv cache : InterpreterCache
  priv xref : @hayro_syntax.XRef
  priv settings : InterpreterSettings
  priv nesting_depth : Int
  priv char_code : UInt
}

///|
/// Draw the type3 glyph to the given device.
pub fn Type3Glyph::interpret(
  self : Type3Glyph,
  device : &Device,
  transform : @kurbo.Affine,
  glyph_transform : @kurbo.Affine,
  paint : Paint,
) -> Unit {
  let _ = self.font.render_glyph(
    self, transform, glyph_transform, paint, device,
  )
}

///|
/// Returns the Unicode code point for this glyph, if available.
///
/// Note: Type3 fonts can only provide Unicode via `ToUnicode` cmap.
pub fn Type3Glyph::as_unicode(self : Type3Glyph) -> @cmap.BfString? {
  self.font.char_code_to_unicode(self.char_code)
}

///|
pub impl CacheKey for Type3Glyph with fn cache_key(self) {
  let font_key = CacheKey::cache_key(self.font)
  hash128(h => {
    h.write_u128(font_key)
    h.write_u32(self.glyph_id.to_u32())
  })
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Type3Glyph with CacheKey::{cache_key}

///|
priv struct Font {
  cache_key : U128
  font_type : FontType
}

///|
fn Font::new(
  dict : @hayro_syntax.Dict,
  font_resolver : FontResolverFn,
  cmap_resolver : CMapResolverFn,
) -> Font? {
  guard (dict.get("Subtype") : @hayro_syntax.Name?) is Some(subtype) else {
    return None
  }
  let f_type = match subtype.as_str() {
    "Type1" | "MMType1" =>
      match Type1Font::new(dict, font_resolver, cmap_resolver) {
        Some(f) => FontType::Type1(f)
        None => return None
      }
    // PDFBOX-5463: PDF viewers seem to accept OpenType as well.
    "TrueType" | "OpenType" =>
      match TrueTypeFont::new(dict, font_resolver, cmap_resolver) {
        Some(f) => FontType::TrueType(f)
        None => return None
      }
    "Type0" =>
      match Type0Font::new(dict, font_resolver, cmap_resolver) {
        Some(f) => FontType::Type0(f)
        None => return None
      }
    "Type3" =>
      match Type3::new(dict, cmap_resolver) {
        Some(f) => FontType::Type3(f)
        None => return None
      }
    _ =>
      // warn!("unimplemented font type {:?}", ...);
      return None
  }
  let cache_key = CacheKey::cache_key(dict)
  Some({ cache_key, font_type: f_type, })
}

///|
fn Font::new_standard(
  standard_font : StandardFont,
  font_resolver : FontResolverFn,
) -> Font? {
  guard Type1Font::new_standard(standard_font, font_resolver) is Some(font) else {
    return None
  }
  Some({ cache_key: U128::default(), font_type: Type1(font), })
}

///|
fn Font::map_code(self : Font, code : UInt) -> GlyphId {
  match self.font_type {
    Type1(f) => f.map_code(code.to_byte())
    TrueType(t) => t.map_code(code.to_byte())
    Type0(t) => t.map_code(code)
    Type3(t) => t.map_code(code.to_byte())
  }
}

///|
fn Font::get_glyph(
  self : Font,
  glyph : GlyphId,
  char_code : UInt,
  ctx : Context,
  resources : @hayro_syntax.Resources,
  origin_displacement : @kurbo.Vec2,
) -> (Glyph, @kurbo.Affine) {
  let glyph_transform = ctx.get().text_state.full_transform() *
    @kurbo.Affine::scale(1.0 / units_per_em.to_double()) *
    @kurbo.Affine::translate_vec(origin_displacement)
  let glyph = match self.font_type {
    Type1(t) =>
      Glyph::Outline({ id: glyph, font: OutlineFont::Type1(t), char_code, })
    TrueType(t) =>
      Glyph::Outline({ id: glyph, font: OutlineFont::TrueType(t), char_code, })
    Type0(t) =>
      Glyph::Outline({ id: glyph, font: OutlineFont::Type0(t), char_code, })
    Type3(t) => {
      let nesting_depth = ctx.nesting_depth() + 1
      Glyph::Type3({
        font: t,
        glyph_id: glyph,
        state: ctx.get().clone(),
        parent_resources: resources,
        cache: ctx.interpreter_cache,
        xref: ctx.xref,
        settings: ctx.settings,
        nesting_depth,
        char_code,
      })
    }
  }
  (glyph, glyph_transform)
}

///|
fn Font::code_advance(self : Font, code : UInt) -> @kurbo.Vec2 {
  match self.font_type {
    Type1(t) =>
      @kurbo.Vec2::new(
        t.glyph_width(code.to_byte()).unwrap_or(0.0).to_double(),
        0.0,
      )
    TrueType(t) =>
      @kurbo.Vec2::new(t.glyph_width(code.to_byte()).to_double(), 0.0)
    Type0(t) => t.code_advance(code)
    Type3(t) => @kurbo.Vec2::new(t.glyph_width(code.to_byte()).to_double(), 0.0)
  }
}

///|
fn Font::origin_displacement(self : Font, code : UInt) -> @kurbo.Vec2 {
  match self.font_type {
    Type1(_) => @kurbo.vec2_zero
    TrueType(_) => @kurbo.vec2_zero
    Type0(t) => t.origin_displacement(code)
    Type3(_) => @kurbo.vec2_zero
  }
}

///|
fn Font::read_code(self : Font, bytes : Bytes, offset : Int) -> (UInt, Int) {
  match self.font_type {
    Type1(_) => (bytes[offset].to_uint(), 1)
    TrueType(_) => (bytes[offset].to_uint(), 1)
    Type0(t) => t.read_code(bytes, offset)
    Type3(_) => (bytes[offset].to_uint(), 1)
  }
}

///|
fn Font::is_horizontal(self : Font) -> Bool {
  match self.font_type {
    Type1(_) => true
    TrueType(_) => true
    Type0(t) => t.is_horizontal()
    Type3(_) => true
  }
}

///|
// Upstream has this impl (hayro-interpret/src/font/mod.rs:400) and never
// calls it either.
#warnings("-unused_value")
impl CacheKey for Font with fn cache_key(self) {
  self.cache_key
}

///|
priv enum FontType {
  Type1(Type1Font)
  TrueType(TrueTypeFont)
  Type0(Type0Font)
  Type3(Type3)
}

///|
priv enum Encoding {
  Standard
  MacRoman
  WinAnsi
  MacExpert
  BuiltIn
}

///|
fn Encoding::map_code(self : Encoding, code : Byte) -> String? {
  if code == 0 {
    return Some(".notdef")
  }
  match self {
    Standard => standard_get(code)
    MacRoman =>
      match mac_roman_get(code) {
        Some(n) => Some(n)
        None => mac_os_roman_get(code)
      }
    WinAnsi => win_ansi_get(code)
    MacExpert => mac_expert_get(code)
    BuiltIn => None
  }
}

///|
/// The font stretch.
pub(all) enum FontStretch {
  /// Normal.
  Normal
  /// Ultra condensed.
  UltraCondensed
  /// Extra condensed.
  ExtraCondensed
  /// Condensed.
  Condensed
  /// Semi condensed.
  SemiCondensed
  /// Semi expanded.
  SemiExpanded
  /// Expanded.
  Expanded
  /// Extra expanded.
  ExtraExpanded
  /// Ultra expanded.
  UltraExpanded
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontStretch with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontStretch with @debug.Debug::{to_repr}

///|
fn FontStretch::from_string(s : String) -> FontStretch {
  match s {
    "UltraCondensed" => UltraCondensed
    "ExtraCondensed" => ExtraCondensed
    "Condensed" => Condensed
    "SemiCondensed" => SemiCondensed
    "SemiExpanded" => SemiExpanded
    "Expanded" => Expanded
    "ExtraExpanded" => ExtraExpanded
    "UltraExpanded" => UltraExpanded
    _ => Normal
  }
}

// Bitflags describing various characteristics of fonts.

///|
const FONT_FLAG_FIXED_PITCH : UInt = 0x1

///|
const FONT_FLAG_SERIF : UInt = 0x2

///|
const FONT_FLAG_SYMBOLIC : UInt = 0x4

///|
const FONT_FLAG_SCRIPT : UInt = 0x8

///|
const FONT_FLAG_NON_SYMBOLIC : UInt = 0x20

///|
const FONT_FLAG_ITALIC : UInt = 0x40

///|
const FONT_FLAG_ALL_CAP : UInt = 0x10000

///|
const FONT_FLAG_SMALL_CAP : UInt = 0x20000

///|
const FONT_FLAG_FORCE_BOLD : UInt = 0x40000

///|
const FONT_FLAGS_ALL : UInt = FONT_FLAG_FIXED_PITCH |
  FONT_FLAG_SERIF |
  FONT_FLAG_SYMBOLIC |
  FONT_FLAG_SCRIPT |
  FONT_FLAG_NON_SYMBOLIC |
  FONT_FLAG_ITALIC |
  FONT_FLAG_ALL_CAP |
  FONT_FLAG_SMALL_CAP |
  FONT_FLAG_FORCE_BOLD

///|
/// `FontFlags::from_bits`: `None` if unknown bits are set.
fn font_flags_from_bits(bits : UInt) -> UInt? {
  if (bits & FONT_FLAGS_ALL.lnot()) != 0 {
    None
  } else {
    Some(bits)
  }
}

///|
/// A query for a font.
pub(all) enum FontQuery {
  /// A query for one of the 14 PDF standard fonts.
  Standard(StandardFont)
  /// A query for a font that is not embedded in the PDF file.
  ///
  /// Note that this type of query is currently not supported,
  /// but will be implemented in the future.
  Fallback(FallbackFontQuery)
}

///|
/// A query for a font with specific properties.
pub(all) struct FallbackFontQuery {
  /// The postscript name of the font.
  mut post_script_name : String?
  /// The name of the font.
  mut font_name : String?
  /// The family of the font.
  mut font_family : String?
  /// The stretch of the font.
  mut font_stretch : FontStretch
  /// The weight of the font.
  mut font_weight : UInt
  /// Whether the font is monospaced.
  mut is_fixed_pitch : Bool
  /// Whether the font is serif.
  mut is_serif : Bool
  /// Whether the font is italic.
  mut is_italic : Bool
  /// Whether the font is bold.
  mut is_bold : Bool
  /// Whether the font is small cap.
  mut is_small_cap : Bool
  /// The character collection (registry/ordering) if this is a CID font.
  mut character_collection : @cmap.CharacterCollection?
}

///|
fn FallbackFontQuery::new(dict : @hayro_syntax.Dict) -> FallbackFontQuery {
  let post_script_name = match (dict.get("BaseFont") : @hayro_syntax.Name?) {
    Some(n) => Some(strip_subset_prefix(n.as_str()))
    None => None
  }
  let data = { ..FallbackFontQuery::default(), post_script_name, }
  if (dict.get("FontDescriptor") : @hayro_syntax.Dict?) is Some(descriptor) {
    data.font_name = match (dict.get("FontName") : @hayro_syntax.Name?) {
      Some(n) => Some(strip_subset_prefix(n.as_str()))
      None => None
    }
    data.font_family = match
      (descriptor.get("FontFamily") : @hayro_syntax.Name?) {
      Some(n) => Some(n.as_str())
      None => None
    }
    data.font_stretch = match
      (descriptor.get("FontStretch") : @hayro_syntax.Name?) {
      Some(n) => FontStretch::from_string(n.as_str())
      None => Normal
    }
    data.font_weight = (descriptor.get("FontWeight") : UInt?).unwrap_or(400)
    if (descriptor.get("Flags") : UInt?) is Some(bits) {
      // `from_bits_truncate`
      let flags = bits & FONT_FLAGS_ALL
      data.is_serif = (flags & FONT_FLAG_SERIF) != 0
      data.is_italic = (flags & FONT_FLAG_ITALIC) != 0
      data.is_small_cap = (flags & FONT_FLAG_SMALL_CAP) != 0
    }
  }
  data.is_italic = data.is_italic ||
    (data.post_script_name is Some(s) && s.contains("Italic"))
  data.is_bold = data.is_bold ||
    (data.post_script_name is Some(s) && s.contains("Bold"))
  data
}

///|
/// Do a best-effort fallback to the 14 standard fonts based on the query.
pub fn FallbackFontQuery::pick_standard_font(
  self : FallbackFontQuery,
) -> StandardFont {
  if self.is_fixed_pitch {
    match (self.is_bold, self.is_italic) {
      (true, true) => CourierBoldOblique
      (true, false) => CourierBold
      (false, true) => CourierOblique
      (false, false) => Courier
    }
  } else if !self.is_serif {
    match (self.is_bold, self.is_italic) {
      (true, true) => HelveticaBoldOblique
      (true, false) => HelveticaBold
      (false, true) => HelveticaOblique
      (false, false) => Helvetica
    }
  } else {
    match (self.is_bold, self.is_italic) {
      (true, true) => TimesBoldItalic
      (true, false) => TimesBold
      (false, true) => TimesItalic
      (false, false) => TimesRoman
    }
  }
}

///|
fn FallbackFontQuery::default() -> FallbackFontQuery {
  {
    post_script_name: None,
    font_name: None,
    font_family: None,
    font_stretch: Normal,
    font_weight: 400,
    is_fixed_pitch: false,
    is_serif: false,
    is_italic: false,
    is_bold: false,
    is_small_cap: false,
    character_collection: None,
  }
}

///|
/// Convert a glyph name to a Unicode character, if possible.
/// An incomplete implementation of the Adobe Glyph List Specification
/// <https://github.com/adobe-type-tools/agl-specification>
fn glyph_name_to_unicode(name : String) -> Char? {
  if glyph_names_get(name) is Some(unicode_str) {
    return unicode_str.iter().next()
  }
  // warn!("failed to map glyph name {} to unicode", name) on failure.
  unicode_from_name(name)
}

///|
fn unicode_from_name(name : String) -> Char? {
  let convert = (input : StringView) => {
    let v = parse_hex_u32(input)
    match v {
      Some(v) => char_from_u32(v)
      None => None
    }
  }
  if name.has_prefix("uni") {
    convert(name.view(start_offset=3))
  } else if name.has_prefix("u") {
    convert(name.view(start_offset=1))
  } else {
    None
  }
}

///|
/// Rust's `u32::from_str_radix(input, 16)`.
fn parse_hex_u32(input : StringView) -> UInt? {
  let mut s = input
  if s.has_prefix("+") {
    s = s.view(start_offset=1)
  }
  if s.is_empty() {
    return None
  }
  let mut v : UInt64 = 0
  for c in s {
    let d = match c {
      '0'..='9' => c.to_int() - '0'.to_int()
      'a'..='f' => c.to_int() - 'a'.to_int() + 10
      'A'..='F' => c.to_int() - 'A'.to_int() + 10
      _ => return None
    }
    v = v * 16 + d.to_uint64()
    if v > 0xFFFF_FFFFUL {
      return None
    }
  }
  Some(v.to_uint())
}

///|
/// Rust's `char::from_u32`.
fn char_from_u32(v : UInt) -> Char? {
  if v > 0x10FFFF || (v >= 0xD800 && v <= 0xDFFF) {
    None
  } else {
    Some(Int::unsafe_to_char(v.reinterpret_as_int()))
  }
}

///|
fn read_to_unicode(
  dict : @hayro_syntax.Dict,
  cmap_resolver : CMapResolverFn,
) -> @cmap.CMap? {
  let data : Bytes? = match (dict.get("ToUnicode") : @hayro_syntax.Stream?) {
    Some(s) =>
      match s.decoded() {
        Ok(d) => Some(d.to_owned())
        Err(_) => None
      }
    None => None
  }
  let data = match data {
    Some(d) => Some(d)
    // See PDFJS-11915, where `Identity-H` is used for `ToUnicode`. I don't
    // believe it's valid, but at least mupdf seems to be able to deal with it.
    None =>
      match (dict.get("ToUnicode") : @hayro_syntax.Name?) {
        Some(name) => cmap_resolver(@cmap.CMapName::from_bytes(name.as_bytes()))
        None => None
      }
  }
  match data {
    Some(data) => @cmap.CMap::parse(data, name => cmap_resolver(name))
    None => None
  }
}

///|
// When mapping to glyphs, some fonts might only have a glyph for the "normalized"
// name.
fn normalized_glyph_name(name : String) -> String {
  if name == "nbspace" {
    return "space"
  }
  if name == "sfthyphen" {
    return "hyphen"
  }
  name
}
