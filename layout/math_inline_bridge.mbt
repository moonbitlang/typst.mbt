// TEMPORARY bridge between math layout (unit I) and inline layout (unit F).
//
// Upstream math layout uses a few items of `typst-layout/src/inline` and of
// `typst-library/src/text/mod.rs` that belong to the inline layout port:
// `inline::{SharedShapingContext, get_font_and_covers, create_shape_plan,
// layout_box}`, `FontInstance::rusty` and `text::{features, language,
// variant}`. Until that port lands, faithful copies live here under
// `bridge_` names. Delete this file and switch the callers in `math_*.mbt`
// to the real items when inline layout is merged.

///|
/// Cache of shaping faces per font instance (upstream stores the rustybuzz
/// face inside `FontInstance`).
let bridge_rusty_cache : Map[@library.FontInstance, @shape.Face] = Map([])

///|
/// The underlying rustybuzz face (upstream `FontInstance::rusty`).
fn bridge_rusty(font : @library.FontInstance) -> @shape.Face {
  match bridge_rusty_cache.get(font) {
    Some(face) => face
    None => {
      let face = @shape.Face::from_face(font.ttf().unwrap())
      bridge_rusty_cache[font] = face
      face
    }
  }
}

///|
/// Memoized shape plans (upstream `#[comemo::memoize] create_shape_plan`).
let bridge_shape_plan_cache : Map[
  (
    @library.FontInstance,
    @shape.Direction,
    @shape.Script,
    @shape.Language?,
    Array[@shape.Feature],
  ),
  @shape.ShapePlan,
] = Map([])

///|
/// Create a shape plan (upstream `inline::create_shape_plan`).
fn bridge_create_shape_plan(
  font : @library.FontInstance,
  direction : @shape.Direction,
  script : @shape.Script,
  language : @shape.Language?,
  features : Array[@shape.Feature],
) -> @shape.ShapePlan {
  let key = (font, direction, script, language, features)
  match bridge_shape_plan_cache.get(key) {
    Some(plan) => plan
    None => {
      let plan = @shape.ShapePlan::new(
        bridge_rusty(font),
        direction,
        Some(script),
        language,
        features,
      )
      bridge_shape_plan_cache[key] = plan
      plan
    }
  }
}

///|
/// The regex of a family's coverage (upstream `FontFamily::covers`).
fn bridge_family_covers(family : @library.FontFamily) -> @library.Regex? {
  match family.covers {
    None => None
    Some(LatinInCjk) => Some(bridge_latin_in_cjk.get())
    Some(Regex(regex)) => Some(regex)
  }
}

///|
/// The `latin-in-cjk` coverage regex (upstream `Covers::as_regex`).
let bridge_latin_in_cjk : Lazy[@library.Regex] = Lazy::new(() => {
  @library.Regex::new(
    "[^\u{00B7}\u{2013}\u{2014}\u{2018}\u{2019}\u{201C}\u{201D}\u{2025}-\u{2027}\u{2E3A}]",
  ) catch {
    _ => abort("invalid regex")
  }
})

///|
/// A lazily computed value.
priv struct Lazy[T] {
  init : () -> T
  mut value : T?
}

///|
fn[T] Lazy::new(init : () -> T) -> Lazy[T] {
  { init, value: None, }
}

///|
fn[T] Lazy::get(self : Lazy[T]) -> T {
  match self.value {
    Some(v) => v
    None => {
      let v = (self.init)()
      self.value = Some(v)
      v
    }
  }
}

///|
/// Select the next font of `families` (upstream
/// `inline::get_font_and_covers`, specialized to the math shaping context).
fn bridge_get_font_and_covers(
  ctx : MathShapingContext,
  text : String,
  families : Iter[@library.FontFamily],
  shape_tofus : (MathShapingContext, String, @library.FontInstance) -> Unit,
) -> (@library.FontInstance, @library.Regex?)? {
  // Find the next available family.
  let world = ctx.world
  let book = world.book()
  let mut selection : @library.FontInstance? = None
  let mut covers = None
  while families.next() is Some(family) {
    selection = match book.select(family.as_str(), ctx.variant) {
      Some(id) =>
        match world.font(id) {
          Some(font) => {
            let font = font.instantiate(ctx.variant, ctx.size, ctx.variations)
            if ctx.used.contains(font) {
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
      covers = bridge_family_covers(family)
      break
    }
  }

  // Do font fallback if the families are exhausted and fallback is enabled.
  if selection is None && ctx.fallback {
    let first = ctx.used.get(0).map(font => font.font().info())
    selection = match book.select_fallback(first, ctx.variant, text) {
      Some(id) =>
        match world.font(id) {
          Some(font) => {
            let font = font.instantiate(ctx.variant, ctx.size, ctx.variations)
            if ctx.used.contains(font) {
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
    if ctx.used.get(0) is Some(font) {
      shape_tofus(ctx, text, font)
    }
    return None
  }

  // This font has been exhausted and will not be used again.
  if covers is None {
    ctx.used.push(font)
  }
  Some((font, covers))
}

///|
/// Collect the features from styles (upstream `text::features`).
fn bridge_features(styles : @library.StyleChain) -> Array[@shape.Feature] {
  let tags = []
  let feat = (tag : String, value : UInt) => {
    tags.push(@shape.Feature::new(@otf.Tag::from_str(tag), value))
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
    v => feat("salt", v.to_int().reinterpret_as_uint())
  }
  for set in @library.TextElem::stylistic_set_in(styles).sets() {
    let storage = "ss" + (set / 10).to_string() + (set % 10).to_string()
    feat(storage, 1)
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
  for entry in @library.TextElem::features_in(styles).0 {
    let (tag, value) = entry
    tags.push(
      @shape.Feature::new(
        @otf.Tag::from_str(tag.0),
        value.to_int().reinterpret_as_uint(),
      ),
    )
  }
  tags
}

///|
/// Process the language and region of a style chain into a
/// rustybuzz-compatible BCP 47 language (upstream `text::language`).
fn bridge_language(styles : @library.StyleChain) -> @shape.Language {
  let mut bcp = @library.TextElem::lang_in(styles).as_str()
  if @library.TextElem::region_in(styles) is Some(region) {
    bcp = bcp + "-" + region.as_str()
  }
  @shape.Language::from_str(bcp).unwrap()
}

///|
/// Resolve the font variant (upstream `text::variant`).
fn bridge_variant(styles : @library.StyleChain) -> @library.FontVariant {
  let variant = @library.FontVariant::new(
    @library.TextElem::style_in(styles),
    @library.TextElem::weight_in(styles),
    @library.TextElem::stretch_in(styles),
  )
  let delta = @library.TextElem::delta_in(styles).0
  let delta = if delta < -32768L {
    -32768
  } else if delta > 32767L {
    32767
  } else {
    delta.to_int()
  }
  let variant = { ..variant, weight: variant.weight.thicken(delta), }
  if @library.TextElem::emph_in(styles).0 {
    {
      ..variant,
      style: match variant.style {
        Normal => Italic
        Italic => Normal
        Oblique => Normal
      },
    }
  } else {
    variant
  }
}

///|
/// Lay out a box as part of inline layout (upstream `inline::layout_box`).
fn bridge_layout_box(
  elem : @library.BoxElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
) -> @library.Frame raise @library.SourceError {
  // Fetch sizing properties.
  let width = elem.width(styles)
  let height = elem.height(styles)
  let inset = sides_rel_or_zero(resolve_sides_rel(elem.inset(styles), styles))

  // Build the pod region.
  let pod = unbreakable_pod(
    width,
    sizing_from_smart(height),
    inset,
    styles,
    region,
  )

  // Layout the body.
  let frame = match elem.body(styles) {
    // If we have no body, just create an empty frame. If necessary,
    // its size will be adjusted below.
    None => @library.Frame::hard(@library.Axes::zero_size())

    // If we have a child, layout it into the body. Boxes are boundaries
    // for gradient relativeness, so we set the `FrameKind` to `Hard`.
    Some(body) =>
      layout_frame(engine, body, locator, styles, pod).with_kind(Hard)
  }

  // Enforce a correct frame size on the expanded axes. Do this before
  // applying the inset, since the pod shrunk.
  frame.set_size(pod.expand.select(pod.size, frame.size()))

  // Apply the inset.
  if !inset.is_zero() {
    grow(frame, inset)
  }

  // Prepare fill and stroke.
  let fill = elem.fill(styles)
  let stroke = sides_fixed_stroke(
    resolve_sides_stroke(elem.stroke(styles), styles),
  )

  // Only fetch these if necessary (for clipping or filling/stroking).
  let outset = () => {
    sides_rel_or_zero(resolve_sides_rel(elem.outset(styles), styles))
  }
  let radius = () => {
    corners_rel_or_zero(resolve_corners_rel(elem.radius(styles), styles))
  }

  // Clip the contents, if requested.
  if elem.clip(styles) {
    frame.clip(clip_rect(frame.size(), radius(), stroke, outset()))
  }

  // Add fill and/or stroke.
  if fill is Some(_) || any_stroke(stroke) {
    fill_and_stroke(frame, fill, stroke, outset(), radius(), elem.pack().span())
  }

  // Assign label to the frame.
  if elem.pack().label() is Some(label) {
    frame.label(label)
  }

  // Apply baseline shift. Do this after setting the size and applying the
  // inset, so that a relative shift is resolved relative to the final
  // height.
  let baseline = elem.baseline(styles)
  if baseline.at() is Custom(align) {
    frame.set_baseline(align.position(frame.height()))
  }
  let shift = baseline.shift().resolve(styles).relative_to(frame.height())
  if !shift.is_zero() {
    frame.set_baseline(frame.baseline() - shift)
  }
  frame
}
