// Port of `typst-library/src/text/font/mod.rs`: `Font` and `FontInstance`.
//
// Contract between the runtime types (P4 work unit A) and the OpenType
// parser (unit B): font parsing is not ported yet, so a `Font` wraps an
// OpenType backend behind the [FontFace] trait object and a `FontInstance`
// wraps the instantiated backend behind [FontInstanceFace]. The backend
// provides exactly the queries upstream answers with `ttf-parser`/
// `rustybuzz`; unit B implements the traits for its face type and may add
// `info()` (`FontInfo`) and `metrics()` (`FontMetrics`) accessors here once
// those are ported. Everything that reads fonts (shaping, layout, exporters,
// the frame dump) must go through these types.

///|
/// The OpenType backend of a [Font] (upstream: the `ttf_parser::Face` and
/// the `FontInfo` derived from it).
pub(open) trait FontFace {
  /// The typographic font family this font is part of (upstream
  /// `FontInfo::family`).
  fn family(Self) -> String
  /// The font's PostScript name (upstream `Font::post_script_name`).
  fn post_script_name(Self) -> String?
  /// Instantiate the face with fully resolved, normalized variation
  /// coordinates (upstream `Font::instantiate_impl`, which sets the
  /// variations on a `rustybuzz::Face`).
  fn instantiate(Self, FontVariations) -> &FontInstanceFace
}

///|
/// The OpenType backend of a [FontInstance] (upstream: the
/// `rustybuzz::Face` with variation coordinates applied).
pub(open) trait FontInstanceFace {
  /// The number of font units per one em.
  fn units_per_em(Self) -> Double
  /// The horizontal advance of a glyph in font units (upstream
  /// `glyph_hor_advance`).
  fn glyph_hor_advance(Self, UInt16) -> Int?
  /// The vertical advance of a glyph in font units (upstream
  /// `glyph_ver_advance`).
  fn glyph_ver_advance(Self, UInt16) -> Int?
  /// The bounding box of a glyph's outline in font units (upstream
  /// `glyph_bounding_box`).
  fn glyph_bounding_box(Self, UInt16) -> GlyphRect?
}

///|
/// A rectangle in font units (upstream `ttf_parser::Rect`).
pub(all) struct GlyphRect {
  x_min : Int
  y_min : Int
  x_max : Int
  y_max : Int
} derive(Eq, Hash, Debug)

///|
/// An OpenType font.
///
/// Values of this type are cheap to clone and immutable.
pub struct Font {
  /// The raw font data, possibly shared with other fonts from the same
  /// collection.
  priv data : Bytes
  /// The font's index in the buffer.
  priv index : UInt
  /// The parsed face.
  priv face : &FontFace
}

///|
/// Create a font from its data, collection index and parsed face.
pub fn Font::new(data : Bytes, index : UInt, face : &FontFace) -> Font {
  { data, index, face, }
}

///|
/// The underlying buffer.
pub fn Font::data(self : Font) -> Bytes {
  self.data
}

///|
/// The font's index in the buffer.
pub fn Font::index(self : Font) -> UInt {
  self.index
}

///|
/// The parsed face.
pub fn Font::face(self : Font) -> &FontFace {
  self.face
}

///|
/// The typographic font family this font is part of (upstream
/// `font.info().family`).
pub fn Font::family(self : Font) -> String {
  self.face.family()
}

///|
/// Determine the font's PostScript name.
pub fn Font::post_script_name(self : Font) -> String? {
  self.face.post_script_name()
}

///|
/// Instantiates the font with specific variation coordinates. The resulting
/// type allows access to methods that depend on coordinates (upstream
/// `Font::instantiate_impl`; `instantiate`, which resolves the automatic
/// variations, needs `FontInfo::axes`).
pub fn Font::instantiate_with(
  self : Font,
  variations : FontVariations,
) -> FontInstance {
  { font: self, variations, face: self.face.instantiate(variations), }
}

///|
pub impl Eq for Font with fn equal(self, other) {
  self.index == other.index &&
  (physical_equal(self.data, other.data) || self.data == other.data)
}

///|
pub impl Hash for Font with fn hash_combine(self, hasher) {
  // Consistent with `Eq`: equal fonts have equal data lengths.
  hasher.combine(self.data.length())
  hasher.combine(self.index)
}

///|
/// Upstream `Debug for Font` (without the variant).
pub impl Show for Font with fn output(self, logger) {
  logger.write_string("Font(\{self.family()})")
}

///|
/// An OpenType font with fixed variation coordinates.
///
/// Values of this type are cheap to clone and immutable.
pub struct FontInstance {
  /// The underlying font.
  priv font : Font
  /// The instance's variation coordinates.
  priv variations : FontVariations
  /// The instantiated face.
  priv face : &FontInstanceFace
}

///|
/// The instance's underlying font.
pub fn FontInstance::font(self : FontInstance) -> Font {
  self.font
}

///|
/// The instance's variation coordinates.
pub fn FontInstance::variations(self : FontInstance) -> FontVariations {
  self.variations
}

///|
/// The instantiated face.
pub fn FontInstance::face(self : FontInstance) -> &FontInstanceFace {
  self.face
}

///|
/// The number of font units per one em.
pub fn FontInstance::units_per_em(self : FontInstance) -> Double {
  self.face.units_per_em()
}

///|
/// Convert from font units to an em length.
pub fn FontInstance::to_em(self : FontInstance, units : Double) -> Em {
  Em::from_units(units, self.units_per_em())
}

///|
/// Look up the horizontal advance width of a glyph.
pub fn FontInstance::x_advance(self : FontInstance, glyph : UInt16) -> Em? {
  self.face.glyph_hor_advance(glyph).map(units => self.to_em(units.to_double()))
}

///|
/// Look up the vertical advance width of a glyph.
pub fn FontInstance::y_advance(self : FontInstance, glyph : UInt16) -> Em? {
  self.face.glyph_ver_advance(glyph).map(units => self.to_em(units.to_double()))
}

///|
/// The bounding box of a glyph's outline in font units.
pub fn FontInstance::glyph_bounding_box(
  self : FontInstance,
  glyph : UInt16,
) -> GlyphRect? {
  self.face.glyph_bounding_box(glyph)
}

///|
pub impl Eq for FontInstance with fn equal(self, other) {
  self.font == other.font && self.variations == other.variations
}

///|
pub impl Hash for FontInstance with fn hash_combine(self, hasher) {
  hasher.combine(self.font)
  hasher.combine(self.variations)
}

///|
/// Upstream `Debug for FontInstance` (abridged).
pub impl Show for FontInstance with fn output(self, logger) {
  logger.write_string("FontInstance { font: \{self.font} }")
}
