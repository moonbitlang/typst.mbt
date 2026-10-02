// Port of `typst-layout/src/inline/shaping.rs`, plus the rustybuzz-facing
// text helpers of `typst-library/src/text/mod.rs` (`features`, `language`)
// and `FontInstance::rusty` (a cached shaping face per font instance).

///|
let shy_char : Char = '\u{ad}'

///|
let hyphen_char : Char = '-'

// ---------------------------------------------------------------------------
// Shaping faces and plans.

///|
/// The cached rustybuzz faces of all font instances (upstream stores the
/// face in the `FontInstance`).
let rusty_faces : Map[@library.FontInstance, @shape.Face] = {}

///|
/// A reference to the underlying `rustybuzz` face of a font instance
/// (upstream `FontInstance::rusty`).
pub fn rusty(font : @library.FontInstance) -> @shape.Face {
  match rusty_faces.get(font) {
    Some(face) => face
    None => {
      let base = font.font()
      let face = @shape.Face::from_slice(base.data()[:], base.index()).unwrap()
      for entry in font.variations().0 {
        let (tag, value) = entry
        face.set_variation(@otf.Tag::from_str(tag.0), value.get())
      }
      rusty_faces[font] = face
      face
    }
  }
}

///|
priv struct PlanKey {
  font : @library.FontInstance
  direction : @shape.Direction
  script : @shape.Script
  language : @shape.Language?
  features : Array[@shape.Feature]
} derive(Eq, Hash)

///|
let shape_plans : Map[PlanKey, @shape.ShapePlan] = {}

///|
/// Create a shape plan (memoized like upstream's `#[comemo::memoize]`).
pub fn create_shape_plan(
  font : @library.FontInstance,
  direction : @shape.Direction,
  script : @shape.Script,
  language : @shape.Language?,
  features : ArrayView[@shape.Feature],
) -> @shape.ShapePlan {
  let key = {
    font,
    direction,
    script,
    language,
    features: features.to_array(),
  }
  match shape_plans.get(key) {
    Some(plan) => plan
    None => {
      let plan = @shape.ShapePlan::new(
        rusty(font),
        direction,
        Some(script),
        language,
        key.features,
      )
      shape_plans[key] = plan
      plan
    }
  }
}

///|
fn ot_tag(s : String) -> @otf.Tag {
  @otf.Tag::from_str(s)
}

///|
/// Collect the OpenType features to apply.
pub fn features(styles : @library.StyleChain) -> Array[@shape.Feature] {
  let tags = []
  let feat = (tag : String, value : UInt) => {
    tags.push(@shape.Feature::new(ot_tag(tag), value))
  }

  // Features that are on by default in Harfbuzz are only added if disabled.
  if !@library.TextElem::kerning_in(styles) {
    feat("kern", 0)
  }

  // Features that are off by default in Harfbuzz are only added if enabled.
  if @library.TextElem::smallcaps_in(styles) is Some(sc) {
    feat("smcp", 1)
    if sc == All {
      feat("c2sc", 1)
    }
  }
  match @library.TextElem::alternates_in(styles).0 {
    0L => ()
    v => feat("salt", v.reinterpret_as_uint64().to_uint())
  }
  for set in @library.TextElem::stylistic_set_in(styles).sets() {
    let tens = (set / 10 + '0'.to_int()).unsafe_to_char()
    let ones = (set % 10 + '0'.to_int()).unsafe_to_char()
    feat("ss\{tens}\{ones}", 1)
  }
  if !@library.TextElem::ligatures_in(styles) {
    feat("liga", 0)
    feat("clig", 0)
  }
  if @library.TextElem::discretionary_ligatures_in(styles) {
    feat("dlig", 1)
  }
  if @library.TextElem::historical_ligatures_in(styles) {
    feat("hlig", 1)
  }
  match @library.TextElem::number_type_in(styles) {
    Auto => ()
    Custom(Lining) => feat("lnum", 1)
    Custom(OldStyle) => feat("onum", 1)
  }
  match @library.TextElem::number_width_in(styles) {
    Auto => ()
    Custom(Proportional) => feat("pnum", 1)
    Custom(Tabular) => feat("tnum", 1)
  }
  if @library.TextElem::slashed_zero_in(styles) {
    feat("zero", 1)
  }
  if @library.TextElem::fractions_in(styles) {
    feat("frac", 1)
  }
  match @library.EquationElem::size_in(styles) {
    Script => feat("ssty", 1)
    ScriptScript => feat("ssty", 2)
    _ => ()
  }
  for pair in @library.TextElem::features_in(styles).0 {
    let (tag, value) = pair
    tags.push(
      @shape.Feature::new(
        ot_tag(tag.0),
        value.reinterpret_as_uint64().to_uint(),
      ),
    )
  }
  tags
}

///|
/// Process the language and region of a style chain into a
/// rustybuzz-compatible BCP 47 language.
pub fn language(styles : @library.StyleChain) -> @shape.Language {
  let mut bcp = @library.TextElem::lang_in(styles).as_str()
  if @library.TextElem::region_in(styles) is Some(region) {
    bcp = bcp + "-" + region.as_str()
  }
  @shape.Language::from_str(bcp).unwrap()
}

// ---------------------------------------------------------------------------
// Shaped text.

///|
/// The result of shaping text.
///
/// This type contains owned or borrowed shaped text runs, which can be
/// measured, used to reshape substrings more quickly and converted into a
/// frame.
priv struct ShapedText {
  /// The start of the text in the full text.
  base : Int
  /// The text that was shaped.
  text : Utf8Slice
  /// The text direction.
  dir : @library.Dir
  /// The text language.
  lang : @library.Lang
  /// The text region.
  region : @library.Region?
  /// The text's style properties.
  styles : @library.StyleChain
  /// The font variant.
  variant : @library.FontVariant
  /// The shaped glyphs.
  glyphs : Glyphs
}

///|
/// Clone the shaped text. The glyphs are shared copy-on-write.
fn ShapedText::clone(self : ShapedText) -> ShapedText {
  { ..self, glyphs: self.glyphs.clone(), }
}

///|
/// A copy-on-write collection of glyphs.
///
/// At the edges of the collection, there can be _trimmed_ glyphs for
/// end-of-line whitespace that should not affect layout, but should be
/// emitted into the PDF to keep things accessible.
///
/// These glyphs are not visible through `kept()` as they should be ignored
/// in almost all circumstances. They are only visible when explicitly
/// accessing [`all`](Self::all) glyphs.
priv struct Glyphs {
  /// All glyphs, including the trimmed ones.
  mut inner : ArrayView[ShapedGlyph]
  /// Whether `inner` is owned (may be mutated in place).
  mut owned : Bool
  /// The range of untrimmed glyphs.
  mut kept_start : Int
  mut kept_end : Int
}

///|
/// Create a borrowed glyph collection from an existing slice.
///
/// This happens after reshaping.
fn Glyphs::from_slice(glyphs : ArrayView[ShapedGlyph]) -> Glyphs {
  { inner: glyphs, owned: false, kept_start: 0, kept_end: glyphs.length(), }
}

///|
/// Create an owned glyph collection from an vector.
///
/// This happens after initial shaping.
fn Glyphs::from_vec(glyphs : Array[ShapedGlyph]) -> Glyphs {
  { inner: glyphs[:], owned: true, kept_start: 0, kept_end: glyphs.length(), }
}

///|
/// Share the glyphs copy-on-write (upstream `Cow::clone`).
fn Glyphs::clone(self : Glyphs) -> Glyphs {
  {
    inner: self.inner,
    owned: false,
    kept_start: self.kept_start,
    kept_end: self.kept_end,
  }
}

///|
/// Clone the internal glyph data to make it modifiable.
fn Glyphs::to_mut(self : Glyphs) -> ArrayView[ShapedGlyph] {
  if !self.owned {
    self.inner = self.inner.map(g => g.copy())[:]
    self.owned = true
  }
  self.inner[self.kept_start:self.kept_end]
}

///|
/// Trims glyphs that satisfy the given condition from the start and end.
///
/// Those glyphs will not be visible during normal operation anymore, only
/// through [`all`](Self::all).
fn Glyphs::trim(self : Glyphs, f : (ShapedGlyph) -> Bool) -> Unit {
  let (start, end) = split_prefix_suffix(self.inner, f)
  self.kept_start = start
  self.kept_end = end
}

///|
/// Accesses all glyphs, not just the untrimmed ones.
fn Glyphs::all(self : Glyphs) -> ArrayView[ShapedGlyph] {
  self.inner
}

///|
/// Returns only the kept (untrimmed) glyphs (upstream `Deref`).
fn Glyphs::kept(self : Glyphs) -> ArrayView[ShapedGlyph] {
  self.inner[self.kept_start:self.kept_end]
}

///|
/// Whether this contains neither kept nor trimmed glyphs.
fn Glyphs::is_fully_empty(self : Glyphs) -> Bool {
  self.inner.length() == 0
}

///|
/// A single glyph resulting from shaping.
priv struct ShapedGlyph {
  /// The font the glyph is contained in.
  font : @library.FontInstance
  /// The glyph's index in the font.
  glyph_id : Int
  /// The advance width of the glyph.
  mut x_advance : @library.Em
  /// The horizontal offset of the glyph.
  mut x_offset : @library.Em
  /// The vertical offset of the glyph.
  y_offset : @library.Em
  /// The font size for the glyph.
  size : @library.Abs
  /// The adjustability of the glyph.
  mut adjustability : Adjustability
  /// The byte range of this glyph's cluster in the full inline layout. A
  /// cluster is a sequence of one or multiple glyphs that cannot be
  /// separated and must always be treated as a union.
  range_start : Int
  range_end : Int
  /// Whether splitting the shaping result before this glyph would yield the
  /// same results as shaping the parts to both sides of `text_index`
  /// separately.
  safe_to_break : Bool
  /// The first char in this glyph's cluster.
  c : Char
  /// Whether this glyph is justifiable for CJK scripts.
  mut is_justifiable : Bool
  /// The script of the glyph.
  script : String
}

///|
fn ShapedGlyph::copy(self : ShapedGlyph) -> ShapedGlyph {
  { ..self, adjustability: self.adjustability, }
}

///|
priv struct Adjustability {
  /// The left and right stretchability
  stretchability : (@library.Em, @library.Em)
  /// The left and right shrinkability
  shrinkability : (@library.Em, @library.Em)
} derive(Eq)

///|
fn Adjustability::default() -> Adjustability {
  {
    stretchability: (@library.Em::zero(), @library.Em::zero()),
    shrinkability: (@library.Em::zero(), @library.Em::zero()),
  }
}

///|
/// Whether the glyph is a space.
fn ShapedGlyph::is_space(self : ShapedGlyph) -> Bool {
  is_space(self.c)
}

///|
/// Whether the glyph is justifiable.
fn ShapedGlyph::is_justifiable(self : ShapedGlyph) -> Bool {
  // GB style is not relevant here.
  self.is_justifiable
}

///|
/// Whether the glyph is part of Chinese or Japanese script (i.e. CJ, not
/// CJK).
fn ShapedGlyph::is_cj_script(self : ShapedGlyph) -> Bool {
  is_cj_script(self.c, self.script)
}

///|
fn ShapedGlyph::is_cjk_punctuation(self : ShapedGlyph) -> Bool {
  self.is_cjk_left_aligned_punctuation(Gb) ||
  self.is_cjk_right_aligned_punctuation() ||
  self.is_cjk_center_aligned_punctuation(Gb)
}

///|
/// See <https://www.w3.org/TR/clreq/#punctuation_width_adjustment>
fn ShapedGlyph::is_cjk_left_aligned_punctuation(
  self : ShapedGlyph,
  style : CjkPunctStyle,
) -> Bool {
  is_cjk_left_aligned_punctuation(
    self.c,
    self.x_advance,
    self.stretchability(),
    style,
  )
}

///|
/// See <https://www.w3.org/TR/clreq/#punctuation_width_adjustment>
fn ShapedGlyph::is_cjk_right_aligned_punctuation(self : ShapedGlyph) -> Bool {
  is_cjk_right_aligned_punctuation(
    self.c,
    self.x_advance,
    self.stretchability(),
  )
}

///|
/// See <https://www.w3.org/TR/clreq/#punctuation_width_adjustment>
fn ShapedGlyph::is_cjk_center_aligned_punctuation(
  self : ShapedGlyph,
  style : CjkPunctStyle,
) -> Bool {
  is_cjk_center_aligned_punctuation(self.c, style)
}

///|
/// Whether the glyph is a western letter or number.
fn ShapedGlyph::is_letter_or_number(self : ShapedGlyph) -> Bool {
  @unicode.script(self.c) is ("Latin" | "Greek" | "Cyrillic") ||
  self.c is ('#' | '$' | '%' | '&') ||
  self.c is ('0'..='9')
}

///|
/// The amount by which the glyph's advance width is allowed to be shrunk or
/// stretched to improve justification.
fn ShapedGlyph::base_adjustability(
  self : ShapedGlyph,
  style : CjkPunctStyle,
  limits : @library.JustificationLimits,
  font_size : @library.Abs,
  stretchable : Bool,
) -> Adjustability {
  let width = self.x_advance

  // Do not ever shrink away more than three quarters of the glyph. As the
  // width approaches zero, justification gets increasingly expensive and
  // if negative it may not terminate.
  let limited = (v : @library.Em) => em_min(v, width.times(0.75))
  let zero = @library.Em::zero()
  if self.is_space() {
    // To a space, both the spacing and tracking limits apply, just like
    // `text.tracking` and `text.spacing` both apply to spaces.
    let spacing = limits.spacing_limits()
    let tracking = limits.tracking_limits()
    let max = spacing.max + @library.Rel::from_abs(tracking.max)
    let min = spacing.min + @library.Rel::from_abs(tracking.min)
    {
      stretchability: (
        zero,
        em_max(
          (max - @library.Rel::one())
          .map(length => @library.Em::from_length(length, font_size))
          .relative_to(width),
          zero,
        ),
      ),
      shrinkability: (
        zero,
        limited(
          (@library.Rel::one() - min)
          .map(length => @library.Em::from_length(length, font_size))
          .relative_to(width),
        ),
      ),
    }
  } else if self.is_cjk_left_aligned_punctuation(style) {
    { stretchability: (zero, zero), shrinkability: (zero, width.div_by(2.0)), }
  } else if self.is_cjk_right_aligned_punctuation() {
    { stretchability: (zero, zero), shrinkability: (width.div_by(2.0), zero), }
  } else if self.is_cjk_center_aligned_punctuation(style) {
    {
      stretchability: (zero, zero),
      shrinkability: (width.div_by(4.0), width.div_by(4.0)),
    }
  } else if stretchable {
    let tracking = limits.tracking_limits()
    {
      stretchability: (
        zero,
        em_max(@library.Em::from_length(tracking.max, font_size), zero),
      ),
      shrinkability: (
        zero,
        limited(@library.Em::from_length(-tracking.min, font_size)),
      ),
    }
  } else {
    Adjustability::default()
  }
}

///|
/// The stretchability of the character.
fn ShapedGlyph::stretchability(
  self : ShapedGlyph,
) -> (@library.Em, @library.Em) {
  self.adjustability.stretchability
}

///|
/// The shrinkability of the character.
fn ShapedGlyph::shrinkability(self : ShapedGlyph) -> (@library.Em, @library.Em) {
  self.adjustability.shrinkability
}

///|
/// Shrink the width of glyph on the left side.
fn ShapedGlyph::shrink_left(self : ShapedGlyph, amount : @library.Em) -> Unit {
  self.x_offset = self.x_offset - amount
  self.x_advance = self.x_advance - amount
  let (l, r) = self.adjustability.shrinkability
  self.adjustability = { ..self.adjustability, shrinkability: (l - amount, r), }
}

///|
/// Shrink the width of glyph on the right side.
fn ShapedGlyph::shrink_right(self : ShapedGlyph, amount : @library.Em) -> Unit {
  self.x_advance = self.x_advance - amount
  let (l, r) = self.adjustability.shrinkability
  self.adjustability = { ..self.adjustability, shrinkability: (l, r - amount), }
}

///|
/// `Em::min` (Rust's `Ord::min` returns the first value on ties).
fn em_min(a : @library.Em, b : @library.Em) -> @library.Em {
  if b < a {
    b
  } else {
    a
  }
}

///|
/// `Em::max` (Rust's `Ord::max` returns the second value on ties).
fn em_max(a : @library.Em, b : @library.Em) -> @library.Em {
  if b >= a {
    b
  } else {
    a
  }
}

///|
/// Build the shaped text's frame.
///
/// The `justification` defines how much extra advance width each
/// [justifiable glyph](ShapedGlyph::is_justifiable) will get.
fn ShapedText::build(
  self : ShapedText,
  engine : @library.Engine,
  spans : SpanMapper,
  justification_ratio : Double,
  extra_justification : @library.Abs,
) -> @library.Frame {
  let (top, bottom) = self.measure(engine)
  let size = @library.Axes::new(self.width(), top + bottom)
  let mut offset = @library.Abs::zero()
  let frame = @library.Frame::soft(size)
  frame.set_baseline(top)
  let size = @library.TextElem::size_in(self.styles).resolve(self.styles)
  let shift = @library.TextElem::baseline_in(self.styles).resolve(self.styles)
  let decos = @library.TextElem::deco_in(self.styles)
  let fill = @library.TextElem::fill_in(self.styles)
  let stroke = @library.TextElem::stroke_in(self.styles).map(s => {
    s.resolve(self.styles).unwrap_or_default()
  })
  let span_offset = @library.TextElem::span_offset_in(self.styles).0
  let mut i = 0
  let all = self.glyphs.all()
  let mut gstart = 0
  while gstart < all.length() {
    // Group by font, y offset and size.
    let first = all[gstart]
    let mut gend = gstart + 1
    while gend < all.length() &&
          all[gend].font == first.font &&
          all[gend].y_offset == first.y_offset &&
          all[gend].size == first.size {
      gend += 1
    }
    let group = all[gstart:gend]
    let font = first.font
    let y_offset = first.y_offset
    let glyph_size = first.size
    let mut range_start = first.range_start
    let mut range_end = first.range_end
    for glyph in group {
      range_start = @cmp.minimum(range_start, glyph.range_start)
      range_end = @cmp.maximum(range_end, glyph.range_end)
    }
    let pos = @library.Point::new(offset, top + shift - y_offset.at(size))
    let glyphs : Array[@library.Glyph] = []
    for shaped in group {
      // Whether the glyph is _not_ trimmed end-of-line whitespace.
      // Trimmed whitespace has its advance width and offset zeroed out and
      // is not taken into account for justification.
      let kept = i >= self.glyphs.kept_start && i < self.glyphs.kept_end
      let (x_advance, x_offset) = if kept {
        let adjustability_left = if justification_ratio < 0.0 {
          shaped.shrinkability().0
        } else {
          shaped.stretchability().0
        }
        let adjustability_right = if justification_ratio < 0.0 {
          shaped.shrinkability().1
        } else {
          shaped.stretchability().1
        }
        let justification_left = adjustability_left.times(justification_ratio)
        let mut justification_right = adjustability_right.times(
          justification_ratio,
        )
        if shaped.is_justifiable() {
          justification_right = justification_right +
            @library.Em::from_abs(extra_justification, glyph_size)
        }
        let fsize = frame.size()
        frame.set_size({
          ..fsize,
          x: fsize.x +
          (
            justification_left.at(glyph_size) +
            justification_right.at(glyph_size)
          ),
        })
        (
          shaped.x_advance + justification_left + justification_right,
          shaped.x_offset + justification_left,
        )
      } else {
        (@library.Em::zero(), @library.Em::zero())
      }
      i += 1

      // We may not be able to reach the offset completely if it exceeds
      // u16, but better to have a roughly correct span offset than nothing.
      let (span, sub) = spans.span_at(shaped.range_start)
      let sub = saturating_u16(
        sub.to_uint64() + span_offset.reinterpret_as_uint64(),
      )
      glyphs.push({
        id: shaped.glyph_id.to_uint16(),
        x_advance,
        x_offset,
        y_advance: @library.Em::zero(),
        y_offset: @library.Em::zero(),
        range_start: saturating_u16(
          (shaped.range_start - range_start).to_uint64(),
        ),
        range_end: saturating_u16((shaped.range_end - range_start).to_uint64()),
        span: (span, sub),
      })
    }
    let item : @library.TextItem = {
      font,
      size: glyph_size,
      lang: self.lang,
      region: self.region,
      fill,
      stroke,
      text: self.text
      .slice(range_start - self.base, range_end - self.base)
      .to_string(),
      glyphs,
    }
    let width = item.width()
    if decos.is_empty() {
      frame.push(pos, Text(item))
    } else {
      // Apply line decorations.
      frame.push(pos, Text(item))
      for deco in decos {
        decorate(frame, deco, item, width, shift, pos)
      }
    }
    offset = offset + width
    gstart = gend
  }
  modify_text(frame, self.styles)
  frame
}

///|
fn saturating_u16(v : UInt64) -> UInt16 {
  if v > 65535UL {
    65535
  } else {
    v.to_int().to_uint16()
  }
}

///|
/// Computes the width of a run of glyphs relative to the font size,
/// accounting for their individual scaling factors and other font metrics.
fn ShapedText::width(self : ShapedText) -> @library.Abs {
  let mut sum = abs_sum_start()
  for g in self.glyphs.kept() {
    sum = sum + g.x_advance.at(g.size)
  }
  sum
}

///|
/// The starting value of Rust's float `Sum` (`-0.0`).
fn abs_sum_start() -> @library.Abs {
  @library.Abs::raw(-0.0)
}

///|
/// Measure the top and bottom extent of this text.
fn ShapedText::measure(
  self : ShapedText,
  engine : @library.Engine,
) -> (@library.Abs, @library.Abs) {
  let mut top = @library.Abs::zero()
  let mut bottom = @library.Abs::zero()
  let size = @library.TextElem::size_in(self.styles).resolve(self.styles)
  let top_edge = @library.TextElem::top_edge_in(self.styles)
  let bottom_edge = @library.TextElem::bottom_edge_in(self.styles)

  // Expand top and bottom by reading the font's vertical metrics.
  let expand = (font : @library.FontInstance, bounds : @library.TextEdgeBounds) => {
    let (t, b) = font.edges(top_edge, bottom_edge, size, bounds)
    top = top.max(t)
    bottom = bottom.max(b)
  }
  if self.glyphs.is_fully_empty() {
    // When there are no glyphs, we just use the vertical metrics of the
    // first available font.
    let world = engine.world
    let variations = @library.TextElem::variations_in(self.styles)
    for family in @library.families(self.styles) {
      if world.book().select(family.as_str(), self.variant) is Some(id) &&
        world.font(id) is Some(font) {
        expand(font.instantiate(self.variant, size, variations), Zero)
        break
      }
    }
  } else {
    for g in self.glyphs.kept() {
      expand(g.font, Glyph(g.glyph_id.to_uint16()))
    }
  }
  (top, bottom)
}

///|
/// How many glyphs are in the text where we can insert additional space
/// when encountering underfull lines.
fn ShapedText::justifiables(self : ShapedText) -> Int {
  let mut count = 0
  for g in self.glyphs.kept() {
    if g.is_justifiable() {
      count += 1
    }
  }
  count
}

///|
/// Whether the last glyph is a CJK character which should not be justified
/// on line end.
fn ShapedText::cjk_justifiable_at_last(self : ShapedText) -> Bool {
  let kept = self.glyphs.kept()
  match kept.last() {
    Some(g) => g.is_cj_script() || g.is_cjk_punctuation()
    None => false
  }
}

///|
/// The stretchability of the text.
fn ShapedText::stretchability(self : ShapedText) -> @library.Abs {
  let mut sum = abs_sum_start()
  for g in self.glyphs.kept() {
    let (l, r) = g.stretchability()
    sum = sum + (l + r).at(g.size)
  }
  sum
}

///|
/// The shrinkability of the text
fn ShapedText::shrinkability(self : ShapedText) -> @library.Abs {
  let mut sum = abs_sum_start()
  for g in self.glyphs.kept() {
    let (l, r) = g.shrinkability()
    sum = sum + (l + r).at(g.size)
  }
  sum
}

///|
/// Reshape a range of the shaped text, reusing information from this
/// shaping process if possible.
///
/// The text `range` is relative to the whole inline layout.
fn ShapedText::reshape(
  self : ShapedText,
  engine : @library.Engine,
  start : Int,
  end : Int,
) -> ShapedText {
  let text = self.text.slice(start - self.base, end - self.base)
  match self.slice_safe_to_break(start, end) {
    Some(glyphs) =>
      {
        base: start,
        text,
        dir: self.dir,
        lang: self.lang,
        region: self.region,
        styles: self.styles,
        variant: self.variant,
        glyphs: Glyphs::from_slice(glyphs),
      }
    None =>
      shape(engine, start, text, self.styles, self.dir, self.lang, self.region)
  }
}

///|
/// Derive an empty text run with the same properties as this one.
fn ShapedText::empty(self : ShapedText) -> ShapedText {
  { ..self, text: empty_slice, glyphs: Glyphs::from_slice([][:]), }
}

///|
let hyphen_slice : Utf8Slice = Utf8Slice::from_string("-")

///|
let shy_slice : Utf8Slice = Utf8Slice::from_string("\u{ad}")

///|
/// Creates shaped text containing a hyphen.
///
/// If `soft` is true, the item will map to plain text as a soft hyphen.
/// Otherwise, it will map to a normal hyphen.
fn ShapedText::hyphen(
  engine : @library.Engine,
  fallback : Bool,
  base : ShapedText,
  pos : Int,
  soft : Bool,
) -> ShapedText? {
  let world = engine.world
  let book = world.book()
  let chain : Array[Int] = []
  for family in @library.families(base.styles) {
    let covered = match family.covers() {
      None => true
      Some(c) => c.is_match("-")
    }
    if covered && book.select(family.as_str(), base.variant) is Some(id) {
      chain.push(id)
    }
  }
  // The fallback is only consulted lazily upstream (`chain` + `find_map`),
  // but selecting is pure, so collecting it eagerly is equivalent.
  if fallback && book.select_fallback(None, base.variant, "-") is Some(id) {
    chain.push(id)
  }
  for id in chain {
    let size = @library.TextElem::size_in(base.styles).resolve(base.styles)
    let variations = @library.TextElem::variations_in(base.styles)
    guard world.font(id) is Some(font) else { continue }
    let font = font.instantiate(base.variant, size, variations)
    guard font.ttf() is Some(ttf) else { continue }
    guard ttf.glyph_index('-') is Some(glyph_id) else { continue }
    guard ttf.glyph_hor_advance(glyph_id) is Some(advance) else { continue }
    let x_advance = font.to_em(advance.to_int().to_double())
    let (c, text) = if soft {
      (shy_char, shy_slice)
    } else {
      (hyphen_char, hyphen_slice)
    }
    return Some({
      base: pos,
      text,
      dir: base.dir,
      lang: base.lang,
      region: base.region,
      styles: base.styles,
      variant: base.variant,
      glyphs: Glyphs::from_vec([
        {
          font,
          glyph_id: glyph_id.0.to_int(),
          x_advance,
          x_offset: @library.Em::zero(),
          y_offset: @library.Em::zero(),
          size,
          adjustability: Adjustability::default(),
          range_start: pos,
          range_end: pos + text.len(),
          safe_to_break: true,
          c,
          is_justifiable: false,
          script: "Common",
        },
      ]),
    })
  }
  None
}

///|
/// Find the subslice of glyphs that represent the given text range if both
/// sides are safe to break.
fn ShapedText::slice_safe_to_break(
  self : ShapedText,
  start : Int,
  end : Int,
) -> ArrayView[ShapedGlyph]? {
  let (start, end) = if !self.dir.is_positive() {
    (end, start)
  } else {
    (start, end)
  }
  guard self.find_safe_to_break(start) is Some(left) else { return None }
  guard self.find_safe_to_break(end) is Some(right) else { return None }
  Some(self.glyphs.kept()[left:right])
}

///|
/// Find the glyph offset matching the text index that is most towards the
/// start of the text and safe-to-break.
fn ShapedText::find_safe_to_break(self : ShapedText, text_index : Int) -> Int? {
  let ltr = self.dir.is_positive()
  let glyphs = self.glyphs.kept()

  // Handle edge cases.
  let len = glyphs.length()
  if text_index == self.base {
    return Some(if ltr { 0 } else { len })
  } else if text_index == self.base + self.text.len() {
    return Some(if ltr { len } else { 0 })
  }

  // Find any glyph with the text index.
  let mut lo = 0
  let mut hi = len
  let mut found = -1
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let s = glyphs[mid].range_start
    let ordering = if ltr {
      s.compare(text_index)
    } else {
      text_index.compare(s)
    }
    if ordering < 0 {
      lo = mid + 1
    } else if ordering > 0 {
      hi = mid
    } else {
      found = mid
      break
    }
  }
  let mut idx = if found >= 0 {
    found
  } else {
    let idx = lo
    // Handle the special case where we break before a '\n'
    //
    // For example: (assume `a` is a CJK character with three bytes)
    // text:  " a     \n b  "
    // index:   0 1 2 3  4 5
    // text_index:    ^
    // glyphs:  0     .  1
    //
    // We will get found = Err(1), because '\n' does not have a glyph. But
    // it's safe to break here. Thus the following condition:
    // - glyphs[0].end == text_index == 3
    // - text[3] == '\n'
    return if idx > 0 &&
      glyphs[idx - 1].range_end == text_index &&
      self.text.char_at(text_index - self.base) == '\n'.to_int() {
      Some(idx)
    } else {
      None
    }
  }

  // Search for the start-most glyph with the text index. This means we take
  // empty range glyphs at the start and leave those at the end for the next
  // line.
  while true {
    let next = if ltr { idx - 1 } else { idx + 1 }
    if next < 0 {
      break
    }
    if next >= len || glyphs[next].range_start != text_index {
      break
    }
    idx = next
  }

  // RTL needs offset one because the left side of the range should be
  // exclusive and the right side inclusive, contrary to the normal
  // behaviour of ranges.
  if glyphs[idx].safe_to_break {
    Some(idx + (if ltr { 0 } else { 1 }))
  } else {
    None
  }
}

///|
/// Group a range of text by BiDi level and script, shape the runs and
/// generate items for them.
fn shape_range(
  items : Array[(Int, Int, InlineItem)],
  engine : @library.Engine,
  text : Utf8Slice,
  bidi : @bidi.BidiInfo,
  start : Int,
  end : Int,
  styles : @library.StyleChain,
) -> Unit {
  let script = @library.TextElem::script_in(styles)
  let lang = @library.TextElem::lang_in(styles)
  let region = @library.TextElem::region_in(styles)
  let process = (a : Int, b : Int, level : @bidi.Level) => {
    let dir : @library.Dir = if level.is_ltr() { LTR } else { RTL }
    let shaped = shape(engine, a, text.slice(a, b), styles, dir, lang, region)
    items.push((a, b, Text(shaped)))
  }
  let mut prev_level = @bidi.Level::ltr()
  let mut prev_script = "Unknown"
  let mut cursor = start

  // Group by embedding level and script. If the text's script is explicitly
  // set (rather than inferred from the glyphs), we keep the script at an
  // unchanging `Script::Unknown` so that only level changes cause breaks.
  for i in start..<end {
    let c = text.char_at(i)
    if c < 0 {
      continue
    }
    let level = bidi.levels[i]
    let curr_script = match script {
      Auto => @unicode.script(char_of(c))
      Custom(_) => "Unknown"
    }
    if level != prev_level || !is_compatible(curr_script, prev_script) {
      if cursor < i {
        process(cursor, i, prev_level)
      }
      cursor = i
      prev_level = level
      prev_script = curr_script
    } else if is_generic_script(prev_script) {
      prev_script = curr_script
    }
  }
  process(cursor, end, prev_level)
}

///|
/// Whether this is not a specific script.
fn is_generic_script(script : String) -> Bool {
  script is ("Unknown" | "Common" | "Inherited")
}

///|
/// Whether these script can be part of the same shape run.
fn is_compatible(a : String, b : String) -> Bool {
  is_generic_script(a) || is_generic_script(b) || a == b
}

///|
/// Shape text into [`ShapedText`].
fn shape(
  engine : @library.Engine,
  base : Int,
  text : Utf8Slice,
  styles : @library.StyleChain,
  dir : @library.Dir,
  lang : @library.Lang,
  region : @library.Region?,
) -> ShapedText {
  let size = @library.TextElem::size_in(styles).resolve(styles)
  let shift_settings = @library.TextElem::shift_settings_in(styles)
  let ctx : ShapingContext = {
    world: engine.world,
    size,
    glyphs: [],
    used: [],
    styles,
    variant: @library.variant(styles),
    features: features(styles),
    variations: @library.TextElem::variations_in(styles),
    fallback: @library.TextElem::fallback_in(styles),
    dir,
    shift_settings,
  }
  if !text.is_empty() {
    shape_segment(ctx, base, text, FamilyIter::new(@library.families(styles)))
  }
  track_and_space(ctx)
  calculate_adjustability(ctx, lang, region)
  {
    base,
    text,
    dir,
    lang,
    region,
    styles,
    variant: ctx.variant,
    glyphs: Glyphs::from_vec(ctx.glyphs),
  }
}

///|
/// An iterator over font families that can be cloned and advanced by
/// reference (upstream `impl Iterator<Item = &FontFamily> + Clone`).
pub struct FamilyIter {
  priv list : Array[@library.FontFamily]
  priv mut pos : Int
}

///|
pub fn FamilyIter::new(list : Array[@library.FontFamily]) -> FamilyIter {
  { list, pos: 0, }
}

///|
pub fn FamilyIter::next(self : FamilyIter) -> @library.FontFamily? {
  if self.pos < self.list.length() {
    let family = self.list[self.pos]
    self.pos += 1
    Some(family)
  } else {
    None
  }
}

///|
pub fn FamilyIter::clone(self : FamilyIter) -> FamilyIter {
  { list: self.list, pos: self.pos, }
}

///|
/// Holds shaping results and metadata common to all shaped segments.
priv struct ShapingContext {
  world : &@library.World
  glyphs : Array[ShapedGlyph]
  used : Array[@library.FontInstance]
  styles : @library.StyleChain
  size : @library.Abs
  variant : @library.FontVariant
  features : Array[@shape.Feature]
  variations : @library.FontVariations
  fallback : Bool
  dir : @library.Dir
  shift_settings : @library.ShiftSettings?
}

///|
/// Shared state of text and math shaping contexts (upstream
/// `SharedShapingContext`).
pub(open) trait SharedShapingContext {
  fn world(Self) -> &@library.World
  /// Font families that have been used with unlimited coverage.
  ///
  /// These font families are considered exhausted and will not be used
  /// again, even if they are declared again (e.g., during fallback after
  /// normal selection).
  fn used(Self) -> Array[@library.FontInstance]
  fn first(Self) -> @library.FontInstance?
  fn variant(Self) -> @library.FontVariant
  fn fallback(Self) -> Bool
  /// The text size (for optical size axis in variable fonts).
  fn size(Self) -> @library.Abs
  /// Custom font variations from the style chain.
  fn variations(Self) -> @library.FontVariations
}

///|
impl SharedShapingContext for ShapingContext with fn world(self) {
  self.world
}

///|
impl SharedShapingContext for ShapingContext with fn used(self) {
  self.used
}

///|
impl SharedShapingContext for ShapingContext with fn first(self) {
  self.used.get(0)
}

///|
impl SharedShapingContext for ShapingContext with fn variant(self) {
  self.variant
}

///|
impl SharedShapingContext for ShapingContext with fn fallback(self) {
  self.fallback
}

///|
impl SharedShapingContext for ShapingContext with fn size(self) {
  self.size
}

///|
impl SharedShapingContext for ShapingContext with fn variations(self) {
  self.variations
}

///|
/// Select the next font for shaping `text` from `families` (advancing it),
/// falling back to the font book if enabled. Shapes tofus with
/// `shape_tofus` if no font is found.
pub fn[C : SharedShapingContext] get_font_and_covers(
  ctx : C,
  text : String,
  families : FamilyIter,
  shape_tofus : (C, String, @library.FontInstance) -> Unit,
) -> (@library.FontInstance, @library.Regex?)? {
  // Find the next available family.
  let world = ctx.world()
  let book = world.book()
  let mut selection : @library.FontInstance? = None
  let mut covers : @library.Regex? = None
  while families.next() is Some(family) {
    selection = match book.select(family.as_str(), ctx.variant()) {
      Some(id) =>
        match world.font(id) {
          Some(font) => {
            let font = font.instantiate(
              ctx.variant(),
              ctx.size(),
              ctx.variations(),
            )
            if ctx.used().contains(font) {
              None
            } else {
              Some(font)
            }
          }
          None => None
        }
      None => None
    }
    if selection is Some(_) {
      covers = family.covers()
      break
    }
  }

  // Do font fallback if the families are exhausted and fallback is enabled.
  if selection is None && ctx.fallback() {
    let first = ctx.first().map(font => font.font().info())
    selection = match book.select_fallback(first, ctx.variant(), text) {
      Some(id) =>
        match world.font(id) {
          Some(font) => {
            let font = font.instantiate(
              ctx.variant(),
              ctx.size(),
              ctx.variations(),
            )
            if ctx.used().contains(font) {
              None
            } else {
              Some(font)
            }
          }
          None => None
        }
      None => None
    }
  }

  // Extract the font id or shape notdef glyphs if we couldn't find any font.
  guard selection is Some(font) else {
    if ctx.used().get(0) is Some(font) {
      shape_tofus(ctx, text, font)
    }
    return None
  }

  // This font has been exhausted and will not be used again.
  if covers is None {
    ctx.used().push(font)
  }
  Some((font, covers))
}

///|
/// Shape text with font fallback using the `families` iterator.
fn shape_segment(
  ctx : ShapingContext,
  base : Int,
  text : Utf8Slice,
  families : FamilyIter,
) -> Unit {
  // Don't try shaping newlines, tabs, or default ignorables.
  let mut all_ignorable = true
  for pair in text.char_indices() {
    let c = pair.1
    if !(c == '\n' || c == '\t' || @unicode.is_default_ignorable(char_of(c))) {
      all_ignorable = false
      break
    }
  }
  if all_ignorable {
    return
  }
  let text_str = text.to_string()
  guard get_font_and_covers(ctx, text_str, families, (ctx, _, font) => {
      shape_tofus(ctx, base, text, font)
    })
    is Some((font, covers)) else {
    return
  }

  // Fill the buffer with our text.
  let buffer = @shape.UnicodeBuffer::new()
  buffer.push_str(text_str)
  buffer.set_language(language(ctx.styles))
  if @library.TextElem::script_in(ctx.styles) is Custom(script) &&
    @shape.Script::from_iso15924_tag(ot_tag(script.as_str())) is Some(script) {
    buffer.set_script(script)
  }
  buffer.set_direction(
    match ctx.dir {
      LTR => LeftToRight
      RTL => RightToLeft
      _ => abort("vertical text layout")
    },
  )
  buffer.guess_segment_properties()

  // By default, Harfbuzz will create zero-width space glyphs for default
  // ignorables. This is probably useful for GUI apps that want noticeable
  // effects on the cursor for those, but for us it's not useful and hurts
  // text extraction.
  buffer.set_flags(@shape.BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES)
  let (script_shift, script_compensation, scale, shift_feature) = match
    ctx.shift_settings {
    None => (@library.Em::zero(), @library.Em::zero(), @library.Em::one(), None)
    Some(settings) => determine_shift(text, font, settings)
  }
  let has_shift_feature = shift_feature is Some(_)
  if shift_feature is Some(feat) {
    // Temporarily push the feature.
    ctx.features.push(feat)
  }

  // Prepare the shape plan. This plan depends on direction, script,
  // language, and features, but is independent from the text and can thus
  // be memoized.
  let plan = create_shape_plan(
    font,
    buffer.direction(),
    buffer.script(),
    buffer.language(),
    ctx.features,
  )
  if has_shift_feature {
    ctx.features.pop() |> ignore
  }

  // Shape!
  let buffer = @shape.shape_with_plan(rusty(font), plan, buffer)
  let infos = buffer.glyph_infos()
  let pos = buffer.glyph_positions()
  let ltr = ctx.dir.is_positive()

  // Whether the character at the given offset is covered by the coverage.
  let is_covered = (offset : Int) => {
    match covers {
      None => true
      Some(cov) => {
        let c = text.char_at(offset)
        let end = offset + utf8_char_len(c)
        cov.is_match(text.slice(offset, end).to_string())
      }
    }
  }

  // Collect the shaped glyphs, doing fallback and shaping parts again with
  // the next font if necessary.
  let mut i = 0
  while i < infos.length() {
    let info = infos[i]
    let cluster = info.cluster.reinterpret_as_int()

    // Add the glyph to the shaped output.
    if info.glyph_id != 0 && is_covered(cluster) {
      // Each glyph in the same cluster should be assigned the full text
      // range. This is necessary because only this way krilla can properly
      // assign `ActualText` attributes in complex shaping scenarios.

      // The start of the glyph's text range.
      let start = base + cluster

      // Determine the end of the glyph's text range.
      let mut k = i
      let step = if ltr { 1 } else { -1 }
      let mut end = 0
      while true {
        // If we've reached the end of the glyphs, the `end` of the range
        // should be the end of the full text.
        let next = k + step
        if next < 0 || next >= infos.length() {
          end = base + text.len()
          break
        }
        let next_info = infos[next]

        // If the cluster doesn't match anymore, we've reached the end.
        if next_info.cluster != info.cluster {
          end = base + next_info.cluster.reinterpret_as_int()
          break
        }
        k = next
      }
      let c = char_of(text.char_at(cluster))
      let script = @unicode.script(c)
      let x_advance = font.to_em(pos[i].x_advance.to_double())
      ctx.glyphs.push({
        font,
        glyph_id: info.glyph_id.reinterpret_as_int(),
        // TODO: Don't ignore y_advance.
        x_advance,
        x_offset: font.to_em(pos[i].x_offset.to_double()) + script_compensation,
        y_offset: font.to_em(pos[i].y_offset.to_double()) + script_shift,
        size: scale.at(ctx.size),
        adjustability: Adjustability::default(),
        range_start: start,
        range_end: end,
        safe_to_break: !info.unsafe_to_break(),
        c,
        is_justifiable: is_justifiable(
          c,
          script,
          x_advance,
          Adjustability::default().stretchability,
        ),
        script,
      })
    } else {
      // First, search for the end of the tofu sequence.
      let k = i
      while i + 1 < infos.length() &&
            (
              infos[i + 1].glyph_id == 0 ||
              !is_covered(infos[i + 1].cluster.reinterpret_as_int())
            ) {
        i += 1
      }

      // Then, determine the start and end text index for the tofu
      // sequence.
      //
      // Examples:
      // Everything is shown in visual order. Tofus are written as "_".
      // We want to find out that the tofus span the text `2..6`.
      // Note that the clusters are longer than 1 char.
      //
      // Left-to-right:
      // Text:     h a l i h a l l o
      // Glyphs:   A   _   _   C   E
      // Clusters: 0   2   4   6   8
      //              k=1 i=2
      //
      // Right-to-left:
      // Text:     O L L A H I L A H
      // Glyphs:   E   C   _   _   A
      // Clusters: 8   6   4   2   0
      //                  k=2 i=3
      let start = infos[if ltr { k } else { i }].cluster.reinterpret_as_int()
      let last = if ltr { i + 1 } else { k - 1 }
      let end = if last >= 0 && last < infos.length() {
        infos[last].cluster.reinterpret_as_int()
      } else {
        text.len()
      }

      // Trim half-baked cluster.
      let remove_start = base + start
      let remove_end = base + end
      while ctx.glyphs.last() is Some(g) &&
            g.range_start >= remove_start &&
            g.range_start < remove_end {
        ctx.glyphs.pop() |> ignore
      }

      // Recursively shape the tofu sequence with the next family.
      shape_segment(ctx, base + start, text.slice(start, end), families.clone())
    }
    i += 1
  }
  ctx.used.pop() |> ignore
}

///|
/// Returns a `(script_shift, script_compensation, scale, feature)`
/// quadruplet describing how to produce scripts.
///
/// Those values determine how the rendered text should be transformed to
/// display sub-/super-scripts. If the OpenType feature can be used, the
/// rendered text should not be transformed in any way, and so those values
/// are neutral (`(0, 0, 1, None)`). If scripts should be synthesized, those
/// values determine how to transform the rendered text to display scripts
/// as expected.
fn determine_shift(
  text : Utf8Slice,
  font : @library.FontInstance,
  settings : @library.ShiftSettings,
) -> (@library.Em, @library.Em, @library.Em, @shape.Feature?) {
  if settings.typographic && typographic_shift_supported(text, font, settings) {
    // If we can use the OpenType feature, we can keep the text as is.
    return (
      @library.Em::zero(),
      @library.Em::zero(),
      @library.Em::one(),
      Some(@shape.Feature::new(ot_tag(settings.kind.feature()), 1)),
    )
  }
  // Reunite the cases where `typographic` is `false` or where using the
  // OpenType feature would not work.
  let script_metrics = settings.kind.read_metrics(font.metrics())
  (
    match settings.shift {
      Custom(v) => v
      Auto => script_metrics.vertical_offset
    },
    script_metrics.horizontal_offset,
    match settings.size {
      Custom(v) => v
      Auto => script_metrics.height
    },
    None,
  )
}

///|
/// If typographic scripts are enabled (i.e., we want to use the OpenType
/// feature instead of synthesizing if possible), we add "subs"/"sups" to
/// the feature list if supported by the font.
fn typographic_shift_supported(
  text : Utf8Slice,
  font : @library.FontInstance,
  settings : @library.ShiftSettings,
) -> Bool {
  guard font.ttf() is Some(ttf) else { return false }
  guard ttf.tables().gsub is Some(gsub) else { return false }
  guard gsub.features.find(ot_tag(settings.kind.feature())) is Some(feature) else {
    return false
  }
  let lookups = feature.lookup_indices
  for pair in text.char_indices() {
    let c = char_of(pair.1)
    guard rusty(font).ttf().glyph_index(c) is Some(gid) else { return false }
    let mut any = false
    for li in 0..<lookups.len().to_int() {
      guard lookups.get(li.to_uint16()) is Some(index) else { continue }
      guard gsub.lookups.get(index) is Some(lookup) else { continue }
      let iter : @otf.LookupSubtablesIter[@otf.SubstitutionSubtable] = lookup.subtables.into_iter()
      while iter.next() is Some(subtable) {
        if subtable.coverage().contains(gid) {
          any = true
          break
        }
      }
      if any {
        break
      }
    }
    if !any {
      return false
    }
  }
  true
}

///|
/// Shape the text with tofus from the given font.
fn shape_tofus(
  ctx : ShapingContext,
  base : Int,
  text : Utf8Slice,
  font : @library.FontInstance,
) -> Unit {
  let x_advance = font.x_advance(0).unwrap_or(@library.Em::zero())
  let add_glyph = (cluster : Int, c : Int) => {
    let start = base + cluster
    let end = start + utf8_char_len(c)
    let c = char_of(c)
    let script = @unicode.script(c)
    ctx.glyphs.push({
      font,
      glyph_id: 0,
      x_advance,
      x_offset: @library.Em::zero(),
      y_offset: @library.Em::zero(),
      size: ctx.size,
      adjustability: Adjustability::default(),
      range_start: start,
      range_end: end,
      safe_to_break: true,
      c,
      is_justifiable: is_justifiable(
        c,
        script,
        x_advance,
        Adjustability::default().stretchability,
      ),
      script,
    })
  }
  let chars = text.char_indices()
  if ctx.dir.is_positive() {
    for pair in chars {
      add_glyph(pair.0, pair.1)
    }
  } else {
    for i = chars.length() - 1; i >= 0; i = i - 1 {
      add_glyph(chars[i].0, chars[i].1)
    }
  }
}

///|
/// Apply tracking and spacing to the shaped glyphs.
fn track_and_space(ctx : ShapingContext) -> Unit {
  let tracking = @library.Em::from_abs(
    @library.TextElem::tracking_in(ctx.styles).resolve(ctx.styles),
    ctx.size,
  )
  let spacing = @library.TextElem::spacing_in(ctx.styles)
    .resolve(ctx.styles)
    .map(abs => @library.Em::from_abs(abs, ctx.size))
  let glyphs = ctx.glyphs
  for i, glyph in glyphs {
    // Make non-breaking space same width as normal space.
    if glyph.c == '\u{00A0}' {
      glyph.x_advance = glyph.x_advance -
        nbsp_delta(glyph.font).unwrap_or(@library.Em::zero())
    }
    if glyph.is_space() {
      glyph.x_advance = spacing.relative_to(glyph.x_advance)
    }
    if i + 1 < glyphs.length() && glyph.range_start != glyphs[i + 1].range_start {
      glyph.x_advance = glyph.x_advance + tracking
    }
  }
}

///|
/// Calculate stretchability and shrinkability of each glyph, and CJK
/// punctuation adjustments according to Chinese Layout Requirements.
fn calculate_adjustability(
  ctx : ShapingContext,
  lang : @library.Lang,
  region : @library.Region?,
) -> Unit {
  let style = cjk_punct_style(lang, region)
  let limits = @library.ParElem::justification_limits_in(ctx.styles)
  let font_size = ctx.size
  let glyphs = ctx.glyphs
  for i, glyph in glyphs {
    // Do not apply adjustability to a glyph if there is another one in the
    // same cluster.
    let stretchable = i + 1 >= glyphs.length() ||
      glyph.range_start != glyphs[i + 1].range_start
    glyph.adjustability = glyph.base_adjustability(
      style, limits, font_size, stretchable,
    )
  }
  for i, glyph in glyphs {
    // CNS style needs not further adjustment.
    if glyph.is_cjk_punctuation() && style == Cns {
      continue
    }

    // Now we apply consecutive punctuation adjustment, specified in Chinese
    // Layout Requirements, section 3.1.6.1 Punctuation Adjustment Space, and
    // Japanese Layout Requirements, section 3.1 Line Composition Rules for
    // Punctuation Marks
    guard glyphs.get(i + 1) is Some(next) else { continue }
    let width = glyph.x_advance
    let delta = width.div_by(2.0)
    if glyph.is_cjk_punctuation() &&
      next.is_cjk_punctuation() &&
      glyph.shrinkability().1 + next.shrinkability().0 >= delta {
      let left_delta = em_min(glyph.shrinkability().1, delta)
      glyph.shrink_right(left_delta)
      next.shrink_left(delta - left_delta)
    }
  }
}

///|
/// Difference between non-breaking and normal space.
fn nbsp_delta(font : @library.FontInstance) -> @library.Em? {
  guard font.ttf() is Some(ttf) else { return None }
  guard ttf.glyph_index(' ') is Some(space) else { return None }
  guard ttf.glyph_index('\u{00A0}') is Some(nbsp) else { return None }
  guard font.x_advance(nbsp.0) is Some(a) else { return None }
  guard font.x_advance(space.0) is Some(b) else { return None }
  Some(a - b)
}

///|
/// The CJK punctuation that can appear at the beginning or end of a line.
let begin_punct_pat : Array[Char] = [
  '“', '‘', '《', '〈', '（', '『', '「', '【', '〖', '〔', '［', '｛',
  '｟', '〘', '〝',
]

///|
let end_punct_pat : Array[Char] = [
  '”', '’', '，', '．', '。', '、', '：', '；', '》', '〉', '）', '』',
  '」', '】', '〗', '〕', '］', '｝', '｠', '〙', '〟', '？', '！',
]

///|
priv enum CjkPunctStyle {
  /// Standard GB/T 15834-2011, used mostly in mainland China.
  Gb
  /// Standard by Taiwan Ministry of Education, used in Taiwan and Hong Kong.
  Cns
  /// Standard JIS X 4051, used in Japan.
  Jis
} derive(Eq)

///|
fn cjk_punct_style(
  lang : @library.Lang,
  region : @library.Region?,
) -> CjkPunctStyle {
  match (lang.as_str(), region.map(r => r.as_str())) {
    ("zh", Some("TW" | "HK")) => Cns
    ("ja", _) => Jis
    // zh-CN, zh-SG, zh-MY use GB-style punctuation,
    _ => Gb
  }
}

///|
/// Whether the glyph is a space.
fn is_space(c : Char) -> Bool {
  c is (' ' | '\u{00A0}' | '　')
}

///|
/// Whether the glyph is part of Chinese or Japanese script (i.e. CJ, not
/// CJK).
fn is_of_cj_script(c : Char) -> Bool {
  is_cj_script(c, @unicode.script(c))
}

///|
/// Whether the glyph is part of Chinese or Japanese script (i.e. CJ, not
/// CJK). The function is dedicated to typesetting Chinese or Japanese,
/// which do not have spaces between words, so K is not checked here.
fn is_cj_script(c : Char, script : String) -> Bool {
  // U+30FC: Katakana-Hiragana Prolonged Sound Mark
  script is ("Hiragana" | "Katakana" | "Han") || c == '\u{30FC}'
}

///|
/// See <https://www.w3.org/TR/clreq/#punctuation_width_adjustment>
fn is_cjk_left_aligned_punctuation(
  c : Char,
  x_advance : @library.Em,
  stretchability : (@library.Em, @library.Em),
  style : CjkPunctStyle,
) -> Bool {
  // CJK quotation marks shares codepoints with latin quotation marks.
  // But only the CJK ones have full width.
  if c is ('”' | '’') && x_advance + stretchability.1 == @library.Em::one() {
    return true
  }
  if style is (Gb | Jis) && c is ('，' | '。' | '．' | '、' | '：' | '；') {
    return true
  }
  if style is Gb && c is ('？' | '！') {
    // In GB style, exclamations and question marks are also left aligned
    // and can be adjusted. Note that they are not adjustable in other
    // styles.
    return true
  }

  // See CLReq appendix A.3 https://www.w3.org/TR/clreq/#table_of_bracket_indication_punctuation_marks
  // and JLReq appendix A.2 https://www.w3.org/TR/jlreq/?lang=ja#cl-02
  c
  is ('》'
  | '）'
  | '』'
  | '」'
  | '】'
  | '〗'
  | '〕'
  | '〉'
  | '］'
  | '｝'
  | '｠'
  | '〙'
  | '〟')
}

///|
/// See <https://www.w3.org/TR/clreq/#punctuation_width_adjustment>
fn is_cjk_right_aligned_punctuation(
  c : Char,
  x_advance : @library.Em,
  stretchability : (@library.Em, @library.Em),
) -> Bool {
  // CJK quotation marks shares codepoints with latin quotation marks.
  // But only the CJK ones have full width.
  if c is ('“' | '‘') && x_advance + stretchability.0 == @library.Em::one() {
    return true
  }
  // See CLReq appendix A.3 https://www.w3.org/TR/clreq/#table_of_bracket_indication_punctuation_marks
  // and JLReq appendix A.1 https://www.w3.org/TR/jlreq/?lang=ja#cl-01
  c
  is ('《'
  | '（'
  | '『'
  | '「'
  | '【'
  | '〖'
  | '〔'
  | '〈'
  | '［'
  | '｛'
  | '｟'
  | '〘'
  | '〝')
}

///|
/// See <https://www.w3.org/TR/clreq/#punctuation_width_adjustment>
fn is_cjk_center_aligned_punctuation(c : Char, style : CjkPunctStyle) -> Bool {
  if style is Cns && c is ('，' | '。' | '．' | '、' | '：' | '；') {
    return true
  }

  // U+30FB: Katakana Middle Dot
  // U+00B7: Middle Dot
  c is ('\u{30FB}' | '\u{00B7}')
}

///|
/// Whether the glyph is justifiable.
///
/// Quotations in latin script and CJK are unfortunately the same codepoint
/// (U+2018, U+2019, U+201C, U+201D), but quotations in Chinese must be
/// fullwidth. This heuristics can therefore fail for monospace latin fonts.
/// However, since monospace fonts are usually not justified this edge case
/// should be rare enough.
fn is_justifiable(
  c : Char,
  script : String,
  x_advance : @library.Em,
  stretchability : (@library.Em, @library.Em),
) -> Bool {
  // punctuation style is not relevant here.
  let style = Gb
  is_space(c) ||
  is_cj_script(c, script) ||
  is_cjk_left_aligned_punctuation(c, x_advance, stretchability, style) ||
  is_cjk_right_aligned_punctuation(c, x_advance, stretchability) ||
  is_cjk_center_aligned_punctuation(c, style)
}
