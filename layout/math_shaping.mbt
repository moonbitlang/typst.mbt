// Port of `typst-layout/src/math/shaping.rs`.

///|
/// Shape some text in math.
fn math_shape(
  world : &@library.World,
  styles : @library.StyleChain,
  features : Array[@shape.Feature],
  text : String,
) -> (@library.FontInstance, Array[@library.Glyph])? {
  math_shape_impl(
    world,
    bridge_variant(styles),
    features,
    bridge_language(styles),
    @library.TextElem::fallback_in(styles),
    text,
    math_families(styles),
    @library.TextElem::size_in(styles).resolve(styles),
    @library.TextElem::variations_in(styles),
  )
}

///|
/// Internal shaping implementation.
fn math_shape_impl(
  world : &@library.World,
  variant : @library.FontVariant,
  features : Array[@shape.Feature],
  language : @shape.Language,
  fallback : Bool,
  text : String,
  families : Array[@library.FontFamily],
  size : @library.Abs,
  variations : @library.FontVariations,
) -> (@library.FontInstance, Array[@library.Glyph])? {
  let ctx : MathShapingContext = {
    world,
    used: [],
    variant,
    features,
    language,
    fallback,
    glyphs: [],
    font: None,
    size,
    variations,
  }
  math_shape_text(ctx, text, families.iter())
  match ctx.font {
    Some(font) => Some((font, ctx.glyphs))
    None => None
  }
}

///|
/// Calls `retry` with feature slices that turn `flac`/`ssty` on or off in
/// different combinations until the closure returns `true`.
fn feat_fallback(
  features : Array[@shape.Feature],
  retry : (Array[@shape.Feature]) -> Bool,
) -> Unit {
  let flac_tag = @otf.Tag::from_str("flac")
  let ssty_tag = @otf.Tag::from_str("ssty")

  // (flac, ssty) combinations to try.
  // Whilst there can be more ssty levels above two, only the first two are
  // used, with 0 here representing disabling the ssty feature.
  let options : Array[(Bool, UInt)] = [
    (true, 2),
    (true, 1),
    (true, 0),
    (false, 2),
    (false, 1),
    (false, 0),
  ]
  let mut had_flac = false
  for f in features.rev_iter() {
    if f.tag == flac_tag {
      had_flac = f.value != 0
      break
    }
  }
  let mut prev_ssty : UInt = 0
  for f in features.rev_iter() {
    if f.tag == ssty_tag {
      prev_ssty = f.value
      break
    }
  }
  let base = features.filter(f => f.tag != flac_tag && f.tag != ssty_tag)
  for option in options {
    let (flac, ssty) = option
    // Don't enable a feature the caller didn't pass in.
    if (flac && !had_flac) || ssty > prev_ssty {
      continue
    }
    // Don't retry the original.
    if flac == had_flac && ssty == prev_ssty {
      continue
    }
    let features = base.copy()
    if flac {
      features.push(@shape.Feature::new(flac_tag, 1))
    }
    if ssty > 0 {
      features.push(@shape.Feature::new(ssty_tag, ssty))
    }
    if retry(features) {
      break
    }
  }
}

///|
/// Holds shaping results and metadata for shaping some text (upstream
/// `math::shaping::ShapingContext`).
priv struct MathShapingContext {
  world : &@library.World
  used : Array[@library.FontInstance]
  variant : @library.FontVariant
  features : Array[@shape.Feature]
  variations : @library.FontVariations
  language : @shape.Language
  fallback : Bool
  glyphs : Array[@library.Glyph]
  mut font : @library.FontInstance?
  size : @library.Abs
}

///|
/// `0..text.len().saturating_as()` as a `u16` range end.
fn math_range_end(text : String) -> UInt16 {
  let len = @syntax.utf8_len(text)
  (if len > 65535 { 65535 } else { len }).to_uint16()
}

///|
/// Shape text with font fallback using the `families` iterator.
fn math_shape_text(
  ctx : MathShapingContext,
  text : String,
  families : Iter[@library.FontFamily],
) -> Unit {
  let shape_tofus = (
    ctx : MathShapingContext,
    text : String,
    font : @library.FontInstance,
  ) => {
    for _ in text {
      ctx.glyphs.push({
        id: 0,
        x_advance: font.x_advance(0).unwrap_or(@library.Em::zero()),
        x_offset: @library.Em::zero(),
        y_advance: @library.Em::zero(),
        y_offset: @library.Em::zero(),
        range_start: 0,
        range_end: math_range_end(text),
        span: (@syntax.Span::detached(), 0),
      })
    }
    ctx.font = Some(font)
  }
  guard bridge_get_font_and_covers(ctx, text, families, shape_tofus)
    is Some((font, covers)) else {
    return
  }
  let buffer = @shape.UnicodeBuffer::new()
  buffer.push_str(text)
  buffer.set_language(ctx.language)
  // TODO: Use `rustybuzz::script::MATH` once
  // https://github.com/harfbuzz/rustybuzz/pull/165 is released.
  buffer.set_script(
    @shape.Script::from_iso15924_tag(@otf.Tag::from_str("math")).unwrap(),
  )
  buffer.set_direction(LeftToRight)
  buffer.set_flags(@shape.BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES)
  let plan = bridge_create_shape_plan(
    font,
    buffer.direction(),
    buffer.script(),
    buffer.language(),
    ctx.features,
  )
  let buffer = @shape.shape_with_plan(bridge_rusty(font), plan, buffer)
  // Because we will only ever shape single grapheme clusters, we will
  // (incorrectly) assume that the output from the shaper is a single cluster
  // that spans the entire range of the given text. The only problem this
  // could cause is the ranges for glyphs being incorrect in the final
  // `TextItem`, which could then affect text extraction in PDF export.
  let infos = buffer.glyph_infos()
  let covered = match covers {
    None => true
    Some(cov) => cov.is_match(text)
  }
  if infos.iter().any(i => i.glyph_id == 0) || !covered {
    math_shape_text(ctx, text, families)
  } else {
    let positions = buffer.glyph_positions()
    for i in 0..<buffer.len() {
      let info = infos[i]
      let pos = positions[i]
      ctx.glyphs.push({
        id: info.glyph_id.to_uint16(),
        x_advance: font.to_em(pos.x_advance.to_double()),
        x_offset: font.to_em(pos.x_offset.to_double()),
        y_advance: font.to_em(pos.y_advance.to_double()),
        y_offset: font.to_em(pos.y_offset.to_double()),
        range_start: 0,
        range_end: math_range_end(text),
        span: (@syntax.Span::detached(), 0),
      })
    }
    if !buffer.is_empty() {
      ctx.font = Some(font)
    }
  }
}
