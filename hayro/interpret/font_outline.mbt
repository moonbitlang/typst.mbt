// Port of `hayro-interpret/src/font/outline.rs`.

///|
/// Font data and metadata for downstream use.
pub(all) struct OutlineFontData {
  /// Raw font bytes (TrueType/OpenType/CFF data).
  data : Bytes
  /// Cache key for font deduplication.
  cache_key : U128
  /// PostScript name (e.g., "TimesNewRomanPS-BoldMT").
  postscript_name : String?
  /// Font weight (100-900, 400=normal, 700=bold).
  weight : UInt?
  /// Whether the font is italic/oblique.
  is_italic : Bool
  /// Whether the font is serif (vs sans-serif).
  is_serif : Bool
  /// Whether the font is monospace.
  is_monospace : Bool
}

///|
priv struct OutlinePath {
  path : @kurbo.BezPath
}

///|
fn OutlinePath::new() -> OutlinePath {
  { path: @kurbo.BezPath::new(), }
}

///|
fn OutlinePath::take(self : OutlinePath) -> @kurbo.BezPath {
  self.path
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn move_to(self, x, y) {
  self.path.move_to(@kurbo.Point::new(x.to_double(), y.to_double()))
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn line_to(self, x, y) {
  if !self.path.elements().is_empty() {
    self.path.line_to(@kurbo.Point::new(x.to_double(), y.to_double()))
  }
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn quad_to(self, cx, cy, x, y) {
  if !self.path.elements().is_empty() {
    self.path.quad_to(
      @kurbo.Point::new(cx.to_double(), cy.to_double()),
      @kurbo.Point::new(x.to_double(), y.to_double()),
    )
  }
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  if !self.path.elements().is_empty() {
    self.path.curve_to(
      @kurbo.Point::new(cx0.to_double(), cy0.to_double()),
      @kurbo.Point::new(cx1.to_double(), cy1.to_double()),
      @kurbo.Point::new(x.to_double(), y.to_double()),
    )
  }
}

///|
impl @read_fonts.OutlinePen for OutlinePath with fn close(self) {
  if !self.path.elements().is_empty() {
    self.path.close_path()
  }
}

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
/// Get raw font bytes and metadata.
///
/// Returns None for Type1 fonts and non-embedded TrueType fonts.
fn OutlineFont::font_data(self : OutlineFont) -> OutlineFontData? {
  match self {
    Type1(_) => None
    TrueType(t) => {
      guard t.font_data() is Some(data) else { return None }
      Some({
        data,
        cache_key: CacheKey::cache_key(t),
        postscript_name: t.postscript_name(),
        weight: t.weight(),
        is_italic: t.is_italic(),
        is_serif: t.is_serif(),
        is_monospace: t.is_monospace(),
      })
    }
    Type0(t) => {
      guard t.font_data() is Some(data) else { return None }
      Some({
        data,
        cache_key: CacheKey::cache_key(t),
        postscript_name: t.postscript_name(),
        weight: t.weight(),
        is_italic: t.is_italic(),
        is_serif: t.is_serif(),
        is_monospace: t.is_monospace(),
      })
    }
  }
}

///|
/// Get raw font bytes and metadata for downstream use.
///
/// Returns `None` for Type1 fonts.
pub fn OutlineGlyph::font_data(self : OutlineGlyph) -> OutlineFontData? {
  self.font.font_data()
}
