// Port of `typst-library/src/text/font/mod.rs`: `Font` and `FontInstance`.
//
// A `Font` wraps an OpenType backend behind the [FontFace] trait object and a
// `FontInstance` wraps the instantiated backend behind [FontInstanceFace]. The
// real backend is the `otf` package (a port of `ttf-parser`), see
// [OtfFontFace]/[OtfInstanceFace] below and `Font::from_data`; tests may
// provide fake faces. Everything that reads fonts (shaping, layout, exporters,
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
  /// The font's metadata (upstream `Font::info`).
  fn info(Self) -> FontInfo = _
  /// The underlying `ttf-parser` face, if the backend is `otf`.
  fn ttf(Self) -> @otf.Face? = _
}

///|
impl FontFace with fn info(self) {
  {
    family: self.family(),
    variant: FontVariant::default(),
    flags: FontFlags::empty(),
    axes: [],
    coverage: Coverage::default(),
  }
}

///|
impl FontFace with fn ttf(_) {
  None
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
  /// The instance's metrics (upstream `FontMetrics::from_ttf` of the
  /// instantiated face).
  fn metrics(Self) -> FontMetrics = _
  /// The underlying `ttf-parser` face with the instance's variations, if the
  /// backend is `otf`.
  fn ttf(Self) -> @otf.Face? = _
}

///|
impl FontInstanceFace with fn metrics(self) {
  let zero = Em::zero()
  let line : LineMetrics = { position: zero, thickness: zero, }
  {
    units_per_em: self.units_per_em(),
    ascender: zero,
    cap_height: zero,
    x_height: zero,
    descender: zero,
    strikethrough: line,
    underline: line,
    overline: line,
    subscript: None,
    superscript: None,
    math: Ref(None),
  }
}

///|
impl FontInstanceFace with fn ttf(_) {
  None
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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphRect with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphRect with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GlyphRect with @debug.Debug::{to_repr}

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
/// Parse a font from data and collection index (upstream `Font::new`).
pub fn Font::from_data(data : Bytes, index : UInt) -> Font? {
  let ttf = @otf.Face::parse(data[:], index) catch { _ => return None }
  guard FontInfo::from_ttf(ttf) is Some(info) else { return None }
  let face : OtfFontFace = { data, index, ttf, info, instances: {}, }
  Some(Font::new(data, index, face))
}

///|
/// Parse all fonts in the given data (upstream `Font::iter`).
pub fn Font::iter(data : Bytes) -> Array[Font] {
  let count = @otf.fonts_in_collection(data[:]).unwrap_or(1)
  let out = []
  for index in 0U..<count {
    if Font::from_data(data, index) is Some(font) {
      out.push(font)
    }
  }
  out
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
/// The font's metadata.
pub fn Font::info(self : Font) -> FontInfo {
  self.face.info()
}

///|
/// The underlying `ttf-parser` face (without variations), if any.
pub fn Font::ttf(self : Font) -> @otf.Face? {
  self.face.ttf()
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
/// Instantiates the font with specific text properties. The resulting
/// type allows access to methods that depend on coordinates.
pub fn Font::instantiate(
  self : Font,
  variant : FontVariant,
  size : Abs,
  custom : FontVariations,
) -> FontInstance {
  let axes = self.info().axes
  let automatic = FontVariations::resolve(axes, variant, size)
  let full = automatic.chain(custom).normalized()
  self.instantiate_with(full)
}

///|
/// Instantiates the font with specific variation coordinates. The resulting
/// type allows access to methods that depend on coordinates (upstream
/// `Font::instantiate_impl`).
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
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Font with Eq::{not_equal, equal}

///|
pub impl Hash for Font with fn hash_combine(self, hasher) {
  // Consistent with `Eq`: equal fonts have equal data lengths.
  hasher.combine(self.data.length())
  hasher.combine(self.index)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Font with Hash::{hash, hash_combine}

///|
/// Upstream `Debug for Font`: `Font({family}, {variant:?})`.
pub impl Show for Font with fn output(self, logger) {
  let info = self.info()
  logger.write_string("Font(\{info.family}, \{info.variant})")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Font with Show::{to_string, output}

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
/// The font's metrics.
pub fn FontInstance::metrics(self : FontInstance) -> FontMetrics {
  self.face.metrics()
}

///|
/// The font's math constants.
pub fn FontInstance::math(self : FontInstance) -> MathConstants {
  let metrics = self.metrics()
  match metrics.math.val {
    Some(math) => math
    None => {
      let math = MathConstants::new(self)
      metrics.math.val = Some(math)
      math
    }
  }
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
/// A reference to the underlying `ttf-parser` face (with the instance's
/// variations), if any.
pub fn FontInstance::ttf(self : FontInstance) -> @otf.Face? {
  self.face.ttf()
}

///|
/// Resolve the top and bottom edges of text.
///
/// Upstream returns `(Abs, Abs)`; [TextEdges] is a value type so that
/// measuring text does not allocate per glyph.
pub fn FontInstance::edges(
  self : FontInstance,
  top_edge : TopEdge,
  bottom_edge : BottomEdge,
  font_size : Abs,
  bounds : TextEdgeBounds,
) -> TextEdges {
  match bounds {
    Zero => self.edges_impl(top_edge, bottom_edge, font_size, None, -1)
    Frame(frame) =>
      self.edges_impl(top_edge, bottom_edge, font_size, Some(frame), -1)
    Glyph(gid) =>
      self.edges_impl(top_edge, bottom_edge, font_size, None, gid.to_int())
  }
}

///|
/// [FontInstance::edges] with `TextEdgeBounds::Glyph(gid)`, without
/// allocating the bounds.
pub fn FontInstance::glyph_edges(
  self : FontInstance,
  top_edge : TopEdge,
  bottom_edge : BottomEdge,
  font_size : Abs,
  gid : UInt16,
) -> TextEdges {
  self.edges_impl(top_edge, bottom_edge, font_size, None, gid.to_int())
}

///|
/// The top and bottom edges of text (see [FontInstance::edges]).
#valtype
pub struct TextEdges {
  top : Abs
  bottom : Abs
}

///|
/// [FontInstance::edges] for the bounds `Glyph(gid)` if `gid >= 0`, else
/// `Frame(frame)` if `frame` is set, else `Zero`. The glyph's bounding box is
/// loaded at most once (upstream: a `OnceCell` read by a closure).
fn FontInstance::edges_impl(
  self : FontInstance,
  top_edge : TopEdge,
  bottom_edge : BottomEdge,
  font_size : Abs,
  frame : Frame?,
  gid : Int,
) -> TextEdges {
  let mut rect : GlyphRect? = None
  let mut loaded = false
  let top = match top_edge {
    Metric(metric) =>
      match metric.to_vertical() {
        Some(metric) => self.metrics().vertical(metric).at(font_size)
        None =>
          if gid >= 0 {
            rect = self.glyph_bounding_box(gid.to_uint16())
            loaded = true
            match rect {
              Some(bbox) => self.to_em(bbox.y_max.to_double()).at(font_size)
              None => Abs::zero()
            }
          } else {
            match frame {
              Some(frame) => frame.ascent()
              None => Abs::zero()
            }
          }
      }
    Length(length) => length.at(font_size)
  }
  let bottom = match bottom_edge {
    Metric(metric) =>
      match metric.to_vertical() {
        Some(metric) => -self.metrics().vertical(metric).at(font_size)
        None =>
          if gid >= 0 {
            if !loaded {
              rect = self.glyph_bounding_box(gid.to_uint16())
            }
            -(match rect {
              Some(bbox) => self.to_em(bbox.y_min.to_double()).at(font_size)
              None => Abs::zero()
            })
          } else {
            match frame {
              Some(frame) => frame.descent()
              None => Abs::zero()
            }
          }
      }
    Length(length) => -length.at(font_size)
  }
  { top, bottom, }
}

///|
pub impl Eq for FontInstance with fn equal(self, other) {
  self.font == other.font && self.variations == other.variations
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontInstance with Eq::{not_equal, equal}

///|
pub impl Hash for FontInstance with fn hash_combine(self, hasher) {
  hasher.combine(self.font)
  hasher.combine(self.variations)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontInstance with Hash::{hash, hash_combine}

///|
/// Upstream `Debug for FontInstance` (abridged).
pub impl Show for FontInstance with fn output(self, logger) {
  logger.write_string("FontInstance { font: \{self.font} }")
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FontInstance with Show::{to_string, output}

// ---------------------------------------------------------------------------
// The `otf` backend.

///|
/// A font face backed by the `otf` package (upstream `FontInner`).
priv struct OtfFontFace {
  /// The raw font data.
  data : Bytes
  /// The font's index in the buffer.
  index : UInt
  /// The underlying ttf-parser face.
  ttf : @otf.Face
  /// Metadata about the font.
  info : FontInfo
  /// Memoized instances (upstream `#[comemo::memoize] instantiate_impl`).
  instances : Map[FontVariations, OtfInstanceFace]
}

///|
impl FontFace for OtfFontFace with fn family(self) {
  self.info.family
}

///|
impl FontFace for OtfFontFace with fn post_script_name(self) {
  find_name(self.ttf, @otf.name_id_post_script_name)
}

///|
impl FontFace for OtfFontFace with fn info(self) {
  self.info
}

///|
impl FontFace for OtfFontFace with fn ttf(self) {
  Some(self.ttf)
}

///|
impl FontFace for OtfFontFace with fn instantiate(self, variations) {
  match self.instances.get(variations) {
    Some(instance) => instance
    None => {
      // Upstream parses a fresh `rustybuzz::Face` and sets the variations.
      let ttf = @otf.Face::parse(self.data[:], self.index) catch {
        _ => abort("font data was parsed before")
      }
      for entry in variations.0 {
        let (tag, value) = entry
        ttf.set_variation(@otf.Tag::from_str(tag.0), value.get()) |> ignore
      }
      let instance : OtfInstanceFace = {
        ttf,
        metrics: FontMetrics::from_ttf(ttf),
      }
      self.instances[variations] = instance
      instance
    }
  }
}

///|
/// An instantiated `otf` face (upstream `FontInstanceInner`).
priv struct OtfInstanceFace {
  /// The face with the instance's variation coordinates applied.
  ttf : @otf.Face
  /// The font's metrics.
  metrics : FontMetrics
}

///|
impl FontInstanceFace for OtfInstanceFace with fn units_per_em(self) {
  self.metrics.units_per_em
}

///|
impl FontInstanceFace for OtfInstanceFace with fn glyph_hor_advance(self, glyph) {
  self.ttf.glyph_hor_advance(@otf.GlyphId(glyph)).map(v => v.to_int())
}

///|
impl FontInstanceFace for OtfInstanceFace with fn glyph_ver_advance(self, glyph) {
  self.ttf.glyph_ver_advance(@otf.GlyphId(glyph)).map(v => v.to_int())
}

///|
impl FontInstanceFace for OtfInstanceFace with fn glyph_bounding_box(
  self,
  glyph,
) {
  self.ttf
  .glyph_bounding_box(@otf.GlyphId(glyph))
  .map(r => GlyphRect::{
    x_min: r.x_min.to_int(),
    y_min: r.y_min.to_int(),
    x_max: r.x_max.to_int(),
    y_max: r.y_max.to_int(),
  })
}

///|
impl FontInstanceFace for OtfInstanceFace with fn metrics(self) {
  self.metrics
}

///|
impl FontInstanceFace for OtfInstanceFace with fn ttf(self) {
  Some(self.ttf)
}
