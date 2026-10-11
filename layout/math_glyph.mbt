// Port of `typst-layout/src/math/fragment/glyph.rs`.

///|
/// Maximum number of times extenders can be repeated.
const MAX_REPEATS : Int = 1024

///|
priv struct GlyphFragment {
  // Text stuff.
  mut item : @library.TextItem
  // Math stuff.
  mut size : @library.Axes[@library.Abs]
  mut baseline : @library.Abs?
  mut italics_correction : @library.Abs
  mut accent_attach : (@library.Abs, @library.Abs)
  math_size : @library.MathSize
  mut class : @unicode.MathClass
  mut extended_shape : Bool
  stretchable_axes : @library.Axes[Bool]
  // External frame stuff.
  modifiers : FrameModifiers
  shift : @library.Abs
  mut align : @library.Abs
}

///|
/// Creates a synthetic glyph fragment from the given character.
fn GlyphFragment::synthetic(
  engine : @library.Engine,
  styles : @library.StyleChain,
  c : Char,
  span : @syntax.Span,
) -> GlyphFragment? {
  let class = @unicode.default_math_class(c).unwrap_or(Normal)
  let math_size = @library.EquationElem::size_in(styles)
  GlyphFragment::base(
    engine.world,
    styles,
    features(styles),
    c.to_string(),
    class,
    math_size,
  ).map(glyph => glyph.with_span(span))
}

///|
/// Creates a glyph fragment from the given text, stretching it if needed.
fn GlyphFragment::new(
  engine : @library.Engine,
  text : String,
  stretch : @library.Stretch,
  styles : @library.StyleChain,
  props : @library.MathProperties,
  class : @unicode.MathClass,
) -> GlyphFragment? {
  guard GlyphFragment::planned(
      engine.world,
      styles,
      text,
      class,
      props.size,
      stretch,
    )
    is Some(planned) else {
    return None
  }
  let { glyph, action, } = planned.with_span(props.span)
  match action {
    Stretch(axis~, target~, short_fall~) => {
      glyph.stretch(engine, target, short_fall, axis)
      if axis == Y {
        glyph.center_on_axis()
      }
    }
    WarnBothAxes =>
      // As far as we know, there aren't any glyphs that have both
      // vertical and horizontal constructions. So for the time
      // being, we will assume that a glyph cannot have both.
      engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          props.span,
          "glyph has both vertical and horizontal constructions",
        ).with_hints([
          "this is probably a font bug", "please file an issue at https://github.com/typst/typst/issues",
        ]),
      )
    Keep | Fallback => ()
  }
  Some(glyph)
}

///|
fn GlyphFragment::planned(
  world : @library.TrackedWorld,
  styles : @library.StyleChain,
  text : String,
  class : @unicode.MathClass,
  math_size : @library.MathSize,
  stretch : @library.Stretch,
) -> PlannedGlyph? {
  let features = features(styles)
  let shape = (feats : Array[@shape.Feature]) => {
    GlyphFragment::base(world, styles, feats, text, class, math_size)
  }
  guard shape(features) is Some(first) else { return None }
  let mut glyph = first
  let mut action = decide(glyph, stretch)

  // If the initial glyph isn't sufficient, keep retrying shaping, by
  // removing `ssty` and `flac` features, until one satisfies the stretch
  // requirements (or until we exhaust them all, in which case we keep
  // the original glyph, unstretched)
  if action is Fallback {
    feat_fallback(features, feats => {
      guard shape(feats) is Some(new) else { return false }
      match decide(new, stretch) {
        Fallback => false
        other => {
          glyph = new
          action = other
          true
        }
      }
    })
  }
  Some({ glyph, action, })
}

///|
fn GlyphFragment::base(
  world : @library.TrackedWorld,
  styles : @library.StyleChain,
  features : Array[@shape.Feature],
  text : String,
  class : @unicode.MathClass,
  math_size : @library.MathSize,
) -> GlyphFragment? {
  guard math_shape(world, styles, features, text) is Some(shaped) else {
    return None
  }
  Some(GlyphFragment::from_shaped(styles, text, class, math_size, shaped))
}

///|
/// Construct a glyph fragment from the shaped text.
fn GlyphFragment::from_shaped(
  styles : @library.StyleChain,
  text : String,
  class : @unicode.MathClass,
  math_size : @library.MathSize,
  shaped : (@library.FontInstance, Array[@library.Glyph]),
) -> GlyphFragment {
  let (font, glyphs) = shaped
  let stretchable_axes = stretch_axes(font, glyphs[0].id)
  let item : @library.TextItem = {
    text,
    font,
    size: @library.TextElem::size_in(styles).resolve(styles),
    fill: @library.TextElem::fill_in(styles).as_decoration(),
    stroke: @library.TextElem::stroke_in(styles).map(s => {
      s.resolve(styles).unwrap_or_default()
    }),
    lang: @library.TextElem::lang_in(styles),
    region: @library.TextElem::region_in(styles),
    glyphs,
  }
  let fragment : GlyphFragment = {
    item,
    // Math
    math_size,
    class,
    stretchable_axes,
    // Math in need of updating.
    extended_shape: false,
    italics_correction: @library.Abs::zero(),
    accent_attach: (@library.Abs::zero(), @library.Abs::zero()),
    size: @library.Axes::zero_size(),
    baseline: None,
    // Misc
    align: @library.Abs::zero(),
    shift: @library.TextElem::baseline_in(styles).resolve(styles),
    modifiers: FrameModifiers::get_in(styles),
  }
  fragment.update_glyph()
  fragment
}

///|
fn GlyphFragment::with_span(
  self : GlyphFragment,
  span : @syntax.Span,
) -> GlyphFragment {
  self.item = {
    ..self.item,
    glyphs: self.item.glyphs.map(glyph => { ..glyph, span, span_offset: 0, }),
  }
  self
}

///|
/// Sets element id and boxes in appropriate way without changing other
/// styles. This is used to replace the glyph with a stretch variant.
fn GlyphFragment::update_glyph(self : GlyphFragment) -> Unit {
  let id = self.item.glyphs[0].id
  let font = self.item.font
  let extended_shape = is_extended_shape(font, id)
  let italics = italics_correction(font, id).unwrap_or(@library.Em::zero())
  let width = self.item.width()
  if !extended_shape {
    let glyphs = self.item.glyphs.copy()
    glyphs[0] = { ..glyphs[0], x_advance: glyphs[0].x_advance + italics, }
    self.item = { ..self.item, glyphs, }
  }
  let italics = italics.at(self.item.size)
  let (ascent, descent) = ascent_descent(font, id).unwrap_or(
    (@library.Em::zero(), @library.Em::zero()),
  )

  // The fallback for accents is half the width plus or minus the italics
  // correction. This is similar to how top and bottom attachments are
  // shifted. For bottom accents we do not use the accent attach of the
  // base as it is meant for top acccents.
  let top_accent_attach = match accent_attach(font, id) {
    Some(x) => x.at(self.item.size)
    None => (width + italics).div_by(2.0)
  }
  let bottom_accent_attach = (width - italics).div_by(2.0)
  self.baseline = Some(ascent.at(self.item.size))
  self.size = @library.Axes::new(
    self.item.width(),
    ascent.at(self.item.size) + descent.at(self.item.size),
  )
  self.italics_correction = italics
  self.accent_attach = (top_accent_attach, bottom_accent_attach)
  self.extended_shape = extended_shape
}

///|
fn GlyphFragment::baseline_(self : GlyphFragment) -> @library.Abs {
  self.ascent()
}

///|
/// The distance from the baseline to the top of the frame.
fn GlyphFragment::ascent(self : GlyphFragment) -> @library.Abs {
  self.baseline.unwrap_or(self.size.y)
}

///|
/// The distance from the baseline to the bottom of the frame.
fn GlyphFragment::descent(self : GlyphFragment) -> @library.Abs {
  self.size.y - self.ascent()
}

///|
fn GlyphFragment::into_frame(self : GlyphFragment) -> @library.Frame {
  let frame = @library.Frame::soft(self.size)
  frame.set_baseline(self.baseline_())
  frame.push(
    @library.Point::with_y(self.ascent() + self.shift + self.align),
    Text(self.item),
  )
  FrameModify::modify(frame, self.modifiers)
  frame
}

///|
/// Try to stretch a glyph to a desired width or height.
///
/// The resulting frame may not have the exact desired width or height.
fn GlyphFragment::stretch(
  self : GlyphFragment,
  engine : @library.Engine,
  target : @library.Abs,
  short_fall : @library.Abs,
  axis : @library.Axis,
) -> Unit {
  // If the base glyph is good enough, use it.
  let advance = self.stretch_advance(axis)
  let short_target = target - short_fall
  if short_target <= advance {
    return
  }
  let id = self.item.glyphs[0].id
  let font = self.item.font
  guard glyph_construction(font, id, axis) is Some(construction) else { return }

  // Search for a pre-made variant with a good advance.
  let mut best_id = id
  let mut best_advance = advance
  for variant in construction.variants.iter() {
    best_id = variant.variant_glyph.0
    best_advance = font
      .to_em(variant.advance_measurement.to_int().to_double())
      .at(self.item.size)
    if short_target <= best_advance {
      break
    }
  }

  // This is either good or the best we've got.
  if short_target <= best_advance || construction.assembly is None {
    let first = self.item.glyphs[0]
    self.item = {
      ..self.item,
      glyphs: [
        {
          id: best_id,
          x_advance: font.x_advance(best_id).unwrap_or(@library.Em::zero()),
          x_offset: @library.Em::zero(),
          y_advance: font.y_advance(best_id).unwrap_or(@library.Em::zero()),
          y_offset: @library.Em::zero(),
          range_start: first.range_start,
          range_end: first.range_end,
          span: first.span,
          span_offset: first.span_offset,
        },
      ],
    }
    self.update_glyph()
    return
  }

  // Assemble from parts.
  let assembly = construction.assembly.unwrap()
  let min_overlap = min_connector_overlap(font)
    .unwrap_or(@library.Em::zero())
    .at(self.item.size)
  assemble(engine, self, assembly, min_overlap, target, axis)
}

///|
/// Advance of the glyph along the given axis used during stretching.
fn GlyphFragment::stretch_advance(
  self : GlyphFragment,
  axis : @library.Axis,
) -> @library.Abs {
  let mut advance = self.size.get(axis)
  if axis == X && !self.extended_shape {
    // For consistency, we subtract the italics correction from the
    // glyph's width if it was added in `update_glyph`.
    advance = advance - self.italics_correction
  }
  advance
}

///|
/// Vertically adjust the fragment's frame so that it is centered
/// on the axis.
fn GlyphFragment::center_on_axis(self : GlyphFragment) -> Unit {
  self.align_on_axis(Horizon)
}

///|
/// Vertically adjust the fragment's frame so that it is aligned
/// to the given alignment on the axis.
fn GlyphFragment::align_on_axis(
  self : GlyphFragment,
  align : @library.VAlignment,
) -> Unit {
  let h = self.size.y
  let axis = self.item.font.math().axis_height.at(self.item.size)
  self.align = self.align + self.baseline_()
  self.baseline = Some(align.inv().position(h + axis.times(2.0)))
  self.align = self.align - self.baseline_()
}

///|
priv struct PlannedGlyph {
  glyph : GlyphFragment
  action : Action
}

///|
fn PlannedGlyph::with_span(
  self : PlannedGlyph,
  span : @syntax.Span,
) -> PlannedGlyph {
  { ..self, glyph: self.glyph.with_span(span), }
}

///|
/// How to proceed with the freshly-shaped glyph fragment.
priv enum Action {
  /// Use this glyph as-is (no stretching is needed).
  Keep
  /// Use this glyph and stretch it with the given information.
  Stretch(
    axis~ : @library.Axis,
    target~ : @library.Abs,
    short_fall~ : @library.Abs
  )
  /// Use this glyph, but warn that it claims stretchability on both axes.
  WarnBothAxes
  /// The glyph isn't stretchable on the axes we need and isn't wide enough
  /// to skip stretching (try falling back without some features).
  Fallback
}

///|
/// The glyph's status for the stretch request on a single axis.
priv enum AxisStatus {
  /// No stretching needed (none requested, or the glyph is already wide
  /// enough).
  Sufficient
  /// The glyph is stretchable on this axis.
  Stretchable(target~ : @library.Abs, short_fall~ : @library.Abs)
  /// Stretching is needed but the glyph isn't stretchable and isn't wide
  /// enough (fallback and retry).
  Fallback
}

///|
/// Decide how to proceed with the freshly-shaped glyph fragment based on the
/// stretch required.
fn decide(glyph : GlyphFragment, stretch : @library.Stretch) -> Action {
  let font = glyph.item.font
  let id = glyph.item.glyphs[0].id
  let axes = glyph.stretchable_axes
  let assess = (axis : @library.Axis) => {
    guard resolve_stretch(glyph, stretch, axis) is Some((target, short_fall)) else {
      return AxisStatus::Sufficient
    }
    if axes.get(axis) {
      return AxisStatus::Stretchable(target~, short_fall~)
    }
    // Glyph isn't stretchable on this axis, but might be wide enough.

    let mut advance = glyph.stretch_advance(axis)

    // Combining marks (e.g. accent glyphs) typically have zero advance in
    // `hmtx`, so the advance above is no good. We explicitly compute the
    // bounding box, just in case.
    if font.glyph_bounding_box(id) is Some(bbox) {
      let extents = @library.Axes::new(
        font.to_em((bbox.x_max - bbox.x_min).to_double()),
        font.to_em((bbox.y_max - bbox.y_min).to_double()),
      )
      advance = advance.max(extents.get(axis).at(glyph.item.size))
    }
    if target - short_fall <= advance {
      AxisStatus::Sufficient
    } else {
      AxisStatus::Fallback
    }
  }
  match (assess(X), assess(Y)) {
    (Stretchable(_), Stretchable(_)) => WarnBothAxes
    (Stretchable(target~, short_fall~), _) =>
      Stretch(axis=X, target~, short_fall~)
    (_, Stretchable(target~, short_fall~)) =>
      Stretch(axis=Y, target~, short_fall~)
    (Sufficient, Sufficient) => Keep
    _ => Fallback
  }
}

///|
/// Returns the absolute target and short fall of the stretch along the given
/// axis, if it exists.
fn resolve_stretch(
  glyph : GlyphFragment,
  stretch : @library.Stretch,
  axis : @library.Axis,
) -> (@library.Abs, @library.Abs)? {
  guard stretch.resolve(axis) is Some(stretch) else { return None }
  let relative_to_size = match stretch.relative_to {
    Some(size) => size
    None =>
      if axis == Y &&
        glyph.class == Large &&
        glyph.math_size == @library.MathSize::Display {
        glyph.item.font.math().display_operator_min_height.at(glyph.item.size)
      } else {
        glyph.size.get(axis)
      }
  }
  let target = stretch.target.relative_to(relative_to_size)
  let short_fall = stretch.short_fall.at(
    stretch.font_size.unwrap_or(glyph.item.size),
  )
  Some((target, short_fall))
}

///|
fn ascent_descent(
  font : @library.FontInstance,
  id : UInt16,
) -> (@library.Em, @library.Em)? {
  guard font.glyph_bounding_box(id) is Some(bbox) else { return None }
  Some(
    (font.to_em(bbox.y_max.to_double()), -font.to_em(bbox.y_min.to_double())),
  )
}

///|
/// The MATH glyph info table of a font.
fn math_glyph_info(font : @library.FontInstance) -> @otf.MathGlyphInfo? {
  guard font.ttf() is Some(ttf) else { return None }
  guard ttf.tables().math is Some(math) else { return None }
  math.glyph_info
}

///|
/// The MATH variants table of a font.
fn math_variants(font : @library.FontInstance) -> @otf.MathVariants? {
  guard font.ttf() is Some(ttf) else { return None }
  guard ttf.tables().math is Some(math) else { return None }
  math.variants
}

///|
/// Look up the italics correction for a glyph.
fn italics_correction(
  font : @library.FontInstance,
  id : UInt16,
) -> @library.Em? {
  guard math_glyph_info(font) is Some(info) else { return None }
  guard info.italic_corrections is Some(values) else { return None }
  values
  .get(@otf.GlyphId(id))
  .map(value => font.to_em(value.value.to_int().to_double()))
}

///|
/// Loop up the top accent attachment position for a glyph.
fn accent_attach(font : @library.FontInstance, id : UInt16) -> @library.Em? {
  guard math_glyph_info(font) is Some(info) else { return None }
  guard info.top_accent_attachments is Some(values) else { return None }
  values
  .get(@otf.GlyphId(id))
  .map(value => font.to_em(value.value.to_int().to_double()))
}

///|
/// Look up whether a glyph is an extended shape.
fn is_extended_shape(font : @library.FontInstance, id : UInt16) -> Bool {
  guard math_glyph_info(font) is Some(info) else { return false }
  guard info.extended_shapes is Some(coverage) else { return false }
  coverage.get(@otf.GlyphId(id)) is Some(_)
}

///|
/// Look up a kerning value at a specific corner and height.
fn kern_at_height(
  font : @library.FontInstance,
  id : UInt16,
  corner : @library.Corner,
  height : @library.Em,
) -> @library.Em? {
  guard math_glyph_info(font) is Some(info) else { return None }
  guard info.kern_infos is Some(infos) else { return None }
  guard infos.get(@otf.GlyphId(id)) is Some(kerns) else { return None }
  let kern = match corner {
    TopLeft => kerns.top_left
    TopRight => kerns.top_right
    BottomRight => kerns.bottom_right
    BottomLeft => kerns.bottom_left
  }
  guard kern is Some(kern) else { return None }
  let mut i : UInt16 = 0
  while i < kern.count() {
    guard kern.height(i) is Some(h) else { return None }
    if !(height >= font.to_em(h.value.to_int().to_double())) {
      break
    }
    i = i + 1
  }
  kern.kern(i).map(k => font.to_em(k.value.to_int().to_double()))
}

///|
fn stretch_axes(
  font : @library.FontInstance,
  id : UInt16,
) -> @library.Axes[Bool] {
  let id = @otf.GlyphId(id)
  let horizontal = match math_variants(font) {
    Some(variants) => variants.horizontal_constructions.get(id) is Some(_)
    None => false
  }
  let vertical = match math_variants(font) {
    Some(variants) => variants.vertical_constructions.get(id) is Some(_)
    None => false
  }
  @library.Axes::new(horizontal, vertical)
}

///|
fn min_connector_overlap(font : @library.FontInstance) -> @library.Em? {
  math_variants(font).map(variants => {
    font.to_em(variants.min_connector_overlap.to_int().to_double())
  })
}

///|
fn glyph_construction(
  font : @library.FontInstance,
  id : UInt16,
  axis : @library.Axis,
) -> @otf.GlyphConstruction? {
  guard math_variants(font) is Some(variants) else { return None }
  let constructions = match axis {
    X => variants.horizontal_constructions
    Y => variants.vertical_constructions
  }
  constructions.get(@otf.GlyphId(id))
}

///|
/// Assemble a glyph from parts.
fn assemble(
  engine : @library.Engine,
  base : GlyphFragment,
  assembly : @otf.GlyphAssembly,
  min_overlap : @library.Abs,
  target : @library.Abs,
  axis : @library.Axis,
) -> Unit {
  let font = base.item.font
  let size = base.item.size
  let to_abs = (units : UInt16) => {
    font.to_em(units.to_int().to_double()).at(size)
  }

  // Determine the number of times the extenders need to be repeated as well
  // as a ratio specifying how much to spread the parts apart
  // (0 = maximal overlap, 1 = minimal overlap).
  let mut full = @library.Abs::zero()
  let mut ratio = 0.0
  let mut repeat = 0
  while true {
    full = @library.Abs::zero()
    ratio = 0.0
    let parts = assembly_parts(assembly, repeat)
    let mut growable = @library.Abs::zero()
    for i, part in parts {
      let mut advance = to_abs(part.full_advance)
      if parts.get(i + 1) is Some(next) {
        let max_overlap = to_abs(
          if part.end_connector_length < next.start_connector_length {
            part.end_connector_length
          } else {
            next.start_connector_length
          },
        )
        if max_overlap < min_overlap {
          // This condition happening is indicative of a bug in the
          // font.
          engine.sink.warn(
            @library.SourceDiagnostic::warning_at(
              base.item.glyphs[0].span,
              "glyph has assembly parts with overlap less than minConnectorOverlap",
            ).with_hints([
              "its rendering may appear broken - this is probably a font bug", "please file an issue at https://github.com/typst/typst/issues",
            ]),
          )
        }
        advance = advance - max_overlap
        // In case we have that max_overlap < min_overlap, ensure we
        // don't decrease the value of growable.
        growable = growable +
          (max_overlap - min_overlap).max(@library.Abs::zero())
      }
      full = full + advance
    }
    if full < target {
      let delta = target - full
      ratio = f64_min(delta.ratio_to(growable), 1.0)
      full = full + growable.times(ratio)
    }
    if target <= full || repeat >= MAX_REPEATS {
      break
    }
    repeat += 1
  }
  let glyphs : Array[@library.Glyph] = []
  let parts = assembly_parts(assembly, repeat)
  let first = base.item.glyphs[0]
  for i, part in parts {
    let mut advance = to_abs(part.full_advance)
    if parts.get(i + 1) is Some(next) {
      let max_overlap = to_abs(
        if part.end_connector_length < next.start_connector_length {
          part.end_connector_length
        } else {
          next.start_connector_length
        },
      )
      advance = advance - max_overlap
      advance = advance + (max_overlap - min_overlap).times(ratio)
    }
    let (x_advance, y_advance, y_offset) = match axis {
      X =>
        (
          @library.Em::from_abs(advance, size),
          @library.Em::zero(),
          @library.Em::zero(),
        )
      Y =>
        (
          @library.Em::zero(),
          @library.Em::from_abs(advance, size),
          // Glyph parts used in vertical assemblies are typically aligned
          // at the vertical origin. This way, they combine properly when
          // drawn consecutively, as required by the MATH table spec.
          //
          // However, in some fonts, they aren't. To still have them align
          // properly, we are vertically offsetting such glyphs by their
          // bounding-box computed descent. (Positive descent means that
          // a glyph extends below the baseline and then we must move it
          // up for it to align properly. `y_advance` is Y-up, so that
          // matches up.)
          match ascent_descent(font, part.glyph_id.0) {
            Some(x) => x.1
            None => @library.Em::zero()
          },
        )
    }
    glyphs.push({
      id: part.glyph_id.0,
      x_advance,
      x_offset: @library.Em::zero(),
      y_advance,
      y_offset,
      range_start: first.range_start,
      range_end: first.range_end,
      span: first.span,
      span_offset: first.span_offset,
    })
  }
  match axis {
    X => {
      let mut acc : (@library.Em, @library.Em)? = None
      for glyph in glyphs {
        if ascent_descent(font, glyph.id) is Some((a, d)) {
          acc = match acc {
            None => Some((a, d))
            Some((ma, md)) => Some((math_em_max(ma, a), math_em_max(md, d)))
          }
        }
      }
      let (ascent, descent) = acc.unwrap_or(
        (@library.Em::zero(), @library.Em::zero()),
      )
      base.size = { ..base.size, x: full, }
      base.baseline = Some(ascent.at(size))
      base.size = { ..base.size, y: (ascent + descent).at(size), }
    }
    Y => {
      base.baseline = None
      base.size = { ..base.size, y: full, }
      let mut max : @library.Em? = None
      for glyph in glyphs {
        let adv = font.x_advance(glyph.id).unwrap_or(@library.Em::zero())
        max = match max {
          None => Some(adv)
          Some(m) => Some(math_em_max(m, adv))
        }
      }
      base.size = {
        ..base.size,
        x: max.unwrap_or(@library.Em::zero()).at(size),
      }
    }
  }
  base.item = { ..base.item, glyphs, }
  base.italics_correction = font
    .to_em(assembly.italics_correction.value.to_int().to_double())
    .at(size)
  if axis == X {
    base.accent_attach = (full.div_by(2.0), full.div_by(2.0))
  }
  base.extended_shape = true
}

///|
/// Return the assembly's parts with extenders repeated the specified number
/// of times.
fn assembly_parts(
  assembly : @otf.GlyphAssembly,
  repeat : Int,
) -> Array[@otf.GlyphPart] {
  let out = []
  for part in assembly.parts.iter() {
    let count = if part.part_flags.extender() { repeat } else { 1 }
    for _ in 0..<count {
      out.push(part)
    }
  }
  out
}

///|
/// Rust's `Ord::max` for `Em` (ties return the second value).
fn math_em_max(a : @library.Em, b : @library.Em) -> @library.Em {
  if a > b {
    a
  } else {
    b
  }
}
