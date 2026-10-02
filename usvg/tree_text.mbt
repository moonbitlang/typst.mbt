// Port of `usvg` 0.47.0 `src/tree/text.rs`: text tree types.

///|
/// A font stretch property.
pub(all) enum FontStretch {
  UltraCondensed
  ExtraCondensed
  Condensed
  SemiCondensed
  Normal
  SemiExpanded
  Expanded
  ExtraExpanded
  UltraExpanded
} derive(Eq, Compare, Hash)

///|
pub impl Default for FontStretch with fn default() {
  Normal
}

///|
/// The numeric value of a stretch (`fontdb::Stretch::to_number`).
pub fn FontStretch::to_number(self : FontStretch) -> Int {
  match self {
    UltraCondensed => 1
    ExtraCondensed => 2
    Condensed => 3
    SemiCondensed => 4
    Normal => 5
    SemiExpanded => 6
    Expanded => 7
    ExtraExpanded => 8
    UltraExpanded => 9
  }
}

///|
/// A font variation axis setting.
///
/// Used for variable fonts to specify axis values like weight, width, etc.
pub(all) struct FontVariation {
  /// The 4-byte axis tag (e.g., b"wght" for weight).
  tag : FixedArray[Byte]
  /// The axis value.
  value : Float
}

///|
/// Creates a new font variation.
pub fn FontVariation::new(
  tag : FixedArray[Byte],
  value : Float,
) -> FontVariation {
  { tag, value, }
}

///|
pub impl Eq for FontVariation with fn equal(self, other) {
  self.tag == other.tag &&
  self.value.reinterpret_as_uint() == other.value.reinterpret_as_uint()
}

///|
pub impl Hash for FontVariation with fn hash_combine(self, hasher) {
  for b in self.tag {
    hasher.combine_byte(b)
  }
  hasher.combine_uint(self.value.reinterpret_as_uint())
}

///|
/// A font style property.
pub(all) enum FontStyle {
  /// A face that is neither italic not obliqued.
  Normal
  /// A form that is generally cursive in nature.
  Italic
  /// A typically-sloped version of the regular face.
  Oblique
} derive(Eq, Hash)

///|
pub impl Default for FontStyle with fn default() {
  Normal
}

///|
/// Text font properties.
pub struct Font {
  priv families : Array[@svgtypes.FontFamily]
  priv style : FontStyle
  priv stretch : FontStretch
  priv weight : Int
  priv variations : Array[FontVariation]
} derive(Eq)

///|
/// A list of family names.
///
/// Never empty. Uses `usvg::Options::font_family` as fallback.
pub fn Font::families(self : Font) -> Array[@svgtypes.FontFamily] {
  self.families
}

///|
/// A font style.
pub fn Font::style(self : Font) -> FontStyle {
  self.style
}

///|
/// A font stretch.
pub fn Font::stretch(self : Font) -> FontStretch {
  self.stretch
}

///|
/// A font weight.
pub fn Font::weight(self : Font) -> Int {
  self.weight
}

///|
/// Font variation settings for variable fonts.
pub fn Font::variations(self : Font) -> Array[FontVariation] {
  self.variations
}

///|
/// A dominant baseline property.
pub(all) enum DominantBaseline {
  Auto
  UseScript
  NoChange
  ResetSize
  Ideographic
  Alphabetic
  Hanging
  Mathematical
  Central
  Middle
  TextAfterEdge
  TextBeforeEdge
} derive(Eq)

///|
pub impl Default for DominantBaseline with fn default() {
  Auto
}

///|
/// An alignment baseline property.
pub(all) enum AlignmentBaseline {
  Auto
  Baseline
  BeforeEdge
  TextBeforeEdge
  Middle
  Central
  AfterEdge
  TextAfterEdge
  Ideographic
  Alphabetic
  Hanging
  Mathematical
} derive(Eq)

///|
pub impl Default for AlignmentBaseline with fn default() {
  Auto
}

///|
/// A baseline shift property.
pub(all) enum BaselineShift {
  Baseline
  Subscript
  Superscript
  Number(Float)
} derive(Eq)

///|
pub impl Default for BaselineShift with fn default() {
  Baseline
}

///|
/// A length adjust property.
pub(all) enum LengthAdjust {
  Spacing
  SpacingAndGlyphs
} derive(Eq)

///|
pub impl Default for LengthAdjust with fn default() {
  Spacing
}

///|
/// A font optical sizing property.
///
/// Controls automatic adjustment of the `opsz` axis in variable fonts
/// based on font size. Matches CSS `font-optical-sizing`.
pub(all) enum FontOpticalSizing {
  /// Automatically set `opsz` to match font size (browser default).
  OpticalAuto
  /// Do not automatically adjust `opsz`.
  OpticalNone
} derive(Eq)

///|
pub impl Default for FontOpticalSizing with fn default() {
  OpticalAuto
}

///|
/// A text span decoration style.
///
/// In SVG, text decoration and text it's applied to can have different styles.
/// So you can have black text and green underline.
///
/// Also, in SVG you can specify text decoration stroking.
pub struct TextDecorationStyle {
  priv fill : Fill?
  priv stroke : Stroke?
}

///|
/// A fill style.
pub fn TextDecorationStyle::fill(self : TextDecorationStyle) -> Fill? {
  self.fill
}

///|
/// A stroke style.
pub fn TextDecorationStyle::stroke(self : TextDecorationStyle) -> Stroke? {
  self.stroke
}

///|
/// A text span decoration.
pub struct TextDecoration {
  priv mut underline : TextDecorationStyle?
  priv mut overline : TextDecorationStyle?
  priv mut line_through : TextDecorationStyle?
}

///|
fn TextDecoration::clone(self : TextDecoration) -> TextDecoration {
  { ..self, }
}

///|
/// An optional underline and its style.
pub fn TextDecoration::underline(self : TextDecoration) -> TextDecorationStyle? {
  self.underline
}

///|
/// An optional overline and its style.
pub fn TextDecoration::overline(self : TextDecoration) -> TextDecorationStyle? {
  self.overline
}

///|
/// An optional line-through and its style.
pub fn TextDecoration::line_through(
  self : TextDecoration,
) -> TextDecorationStyle? {
  self.line_through
}

///|
/// A text style span.
///
/// Spans do not overlap inside a text chunk.
pub struct TextSpan {
  priv start : Int
  priv mut end : Int
  priv mut fill : Fill?
  priv mut stroke : Stroke?
  priv paint_order : PaintOrder
  priv font : Font
  priv font_size : NonZeroPositiveF32
  priv small_caps : Bool
  priv apply_kerning : Bool
  priv font_optical_sizing : FontOpticalSizing
  priv decoration : TextDecoration
  priv dominant_baseline : DominantBaseline
  priv alignment_baseline : AlignmentBaseline
  priv baseline_shift : Array[BaselineShift]
  priv visible : Bool
  priv letter_spacing : Float
  priv word_spacing : Float
  priv text_length : Float?
  priv length_adjust : LengthAdjust
}

///|
fn TextSpan::clone(self : TextSpan) -> TextSpan {
  { ..self, decoration: self.decoration.clone(), }
}

///|
/// A span start in bytes.
///
/// Offset is relative to the parent text chunk and not the parent text element.
pub fn TextSpan::start(self : TextSpan) -> Int {
  self.start
}

///|
/// A span end in bytes.
pub fn TextSpan::end(self : TextSpan) -> Int {
  self.end
}

///|
/// A fill style.
pub fn TextSpan::fill(self : TextSpan) -> Fill? {
  self.fill
}

///|
/// A stroke style.
pub fn TextSpan::stroke(self : TextSpan) -> Stroke? {
  self.stroke
}

///|
/// A paint order style.
pub fn TextSpan::paint_order(self : TextSpan) -> PaintOrder {
  self.paint_order
}

///|
/// A font.
pub fn TextSpan::font(self : TextSpan) -> Font {
  self.font
}

///|
/// A font size.
pub fn TextSpan::font_size(self : TextSpan) -> NonZeroPositiveF32 {
  self.font_size
}

///|
/// Indicates that small caps should be used.
pub fn TextSpan::small_caps(self : TextSpan) -> Bool {
  self.small_caps
}

///|
/// Indicates that a kerning should be applied.
pub fn TextSpan::apply_kerning(self : TextSpan) -> Bool {
  self.apply_kerning
}

///|
/// Font optical sizing mode.
pub fn TextSpan::font_optical_sizing(self : TextSpan) -> FontOpticalSizing {
  self.font_optical_sizing
}

///|
/// A span decorations.
pub fn TextSpan::decoration(self : TextSpan) -> TextDecoration {
  self.decoration
}

///|
/// A span dominant baseline.
pub fn TextSpan::dominant_baseline(self : TextSpan) -> DominantBaseline {
  self.dominant_baseline
}

///|
/// A span alignment baseline.
pub fn TextSpan::alignment_baseline(self : TextSpan) -> AlignmentBaseline {
  self.alignment_baseline
}

///|
/// A list of all baseline shift that should be applied to this span.
///
/// Ordered from `text` element down to the actual `span` element.
pub fn TextSpan::baseline_shift(self : TextSpan) -> Array[BaselineShift] {
  self.baseline_shift
}

///|
/// A visibility property.
pub fn TextSpan::is_visible(self : TextSpan) -> Bool {
  self.visible
}

///|
/// A letter spacing property.
pub fn TextSpan::letter_spacing(self : TextSpan) -> Float {
  self.letter_spacing
}

///|
/// A word spacing property.
pub fn TextSpan::word_spacing(self : TextSpan) -> Float {
  self.word_spacing
}

///|
/// A text length property.
pub fn TextSpan::text_length(self : TextSpan) -> Float? {
  self.text_length
}

///|
/// A length adjust property.
pub fn TextSpan::length_adjust(self : TextSpan) -> LengthAdjust {
  self.length_adjust
}

///|
/// A text chunk anchor property.
pub(all) enum TextAnchor {
  Start
  Middle
  End
} derive(Eq)

///|
pub impl Default for TextAnchor with fn default() {
  Start
}

///|
/// A path used by text-on-path.
pub struct TextPath {
  priv id : NonEmptyString
  priv start_offset : Float
  priv path : TinyPath
}

///|
/// Element's ID.
pub fn TextPath::id(self : TextPath) -> String {
  self.id.get()
}

///|
/// A text offset in SVG coordinates.
///
/// Percentage values already resolved.
pub fn TextPath::start_offset(self : TextPath) -> Float {
  self.start_offset
}

///|
/// A path.
pub fn TextPath::path(self : TextPath) -> TinyPath {
  self.path
}

///|
/// A text chunk flow property.
pub(all) enum TextFlow {
  /// A linear layout.
  ///
  /// Includes left-to-right, right-to-left and top-to-bottom.
  Linear
  /// A text-on-path layout.
  Path(TextPath)
}

///|
/// A text chunk.
///
/// Text alignment and BIDI reordering can only be done inside a text chunk.
pub struct TextChunk {
  priv x : Float?
  priv y : Float?
  priv anchor : TextAnchor
  priv spans : Array[TextSpan]
  priv text_flow : TextFlow
  priv mut text : String
}

///|
fn TextChunk::clone(self : TextChunk) -> TextChunk {
  { ..self, spans: self.spans.map(TextSpan::clone), }
}

///|
/// An absolute X axis offset.
pub fn TextChunk::x(self : TextChunk) -> Float? {
  self.x
}

///|
/// An absolute Y axis offset.
pub fn TextChunk::y(self : TextChunk) -> Float? {
  self.y
}

///|
/// A text anchor.
pub fn TextChunk::anchor(self : TextChunk) -> TextAnchor {
  self.anchor
}

///|
/// A list of text chunk style spans.
pub fn TextChunk::spans(self : TextChunk) -> Array[TextSpan] {
  self.spans
}

///|
/// A text chunk flow.
pub fn TextChunk::text_flow(self : TextChunk) -> TextFlow {
  self.text_flow
}

///|
/// A text chunk actual text.
pub fn TextChunk::text(self : TextChunk) -> String {
  self.text
}

///|
/// A writing mode.
pub(all) enum WritingMode {
  LeftToRight
  TopToBottom
} derive(Eq)

///|
/// A text element.
///
/// `text` element in SVG.
pub struct Text {
  priv mut id : String
  priv rendering_mode : TextRendering
  priv dx : Array[Float]
  priv dy : Array[Float]
  priv rotate : Array[Float]
  priv writing_mode : WritingMode
  priv chunks : Array[TextChunk]
  priv abs_transform : Transform
  priv mut bounding_box : Rect
  priv mut abs_bounding_box : Rect
  priv mut stroke_bounding_box : Rect
  priv mut abs_stroke_bounding_box : Rect
  priv mut flattened : Group
  priv mut layouted : Array[LayoutSpan]
}

///|
fn Text::clone(self : Text) -> Text {
  {
    ..self,
    chunks: self.chunks.map(TextChunk::clone),
    flattened: self.flattened.clone(),
    layouted: self.layouted.map(LayoutSpan::clone),
  }
}

///|
/// Element's ID.
pub fn Text::id(self : Text) -> String {
  self.id
}

///|
/// Rendering mode.
pub fn Text::rendering_mode(self : Text) -> TextRendering {
  self.rendering_mode
}

///|
/// A relative X axis offsets.
///
/// One offset for each Unicode codepoint. Aka `char` in Rust.
pub fn Text::dx(self : Text) -> Array[Float] {
  self.dx
}

///|
/// A relative Y axis offsets.
pub fn Text::dy(self : Text) -> Array[Float] {
  self.dy
}

///|
/// A list of rotation angles.
pub fn Text::rotate(self : Text) -> Array[Float] {
  self.rotate
}

///|
/// A writing mode.
pub fn Text::writing_mode(self : Text) -> WritingMode {
  self.writing_mode
}

///|
/// A list of text chunks.
pub fn Text::chunks(self : Text) -> Array[TextChunk] {
  self.chunks
}

///|
/// Element's absolute transform.
pub fn Text::abs_transform(self : Text) -> Transform {
  self.abs_transform
}

///|
/// Element's text bounding box.
pub fn Text::bounding_box(self : Text) -> Rect {
  self.bounding_box
}

///|
/// Element's text bounding box in canvas coordinates.
pub fn Text::abs_bounding_box(self : Text) -> Rect {
  self.abs_bounding_box
}

///|
/// Element's object bounding box including stroke.
pub fn Text::stroke_bounding_box(self : Text) -> Rect {
  self.stroke_bounding_box
}

///|
/// Element's bounding box including stroke in canvas coordinates.
pub fn Text::abs_stroke_bounding_box(self : Text) -> Rect {
  self.abs_stroke_bounding_box
}

///|
/// Text converted into paths, ready to render.
pub fn Text::flattened(self : Text) -> Group {
  self.flattened
}

///|
/// The positioned glyphs and decoration spans of the text.
pub fn Text::layouted(self : Text) -> Array[LayoutSpan] {
  self.layouted
}

///|
fn Text::subroots(self : Text, f : (Group) -> Unit) -> Unit {
  f(self.flattened)
}
