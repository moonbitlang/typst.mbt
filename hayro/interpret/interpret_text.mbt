// Port of `hayro-interpret/src/interpret/text.rs`.

///|
fn show_text_string(
  ctx : Context,
  device : &Device,
  resources : @hayro_syntax.Resources,
  text : @hayro_syntax.PdfString,
) -> Unit {
  guard ctx.get().text_state.font is Some(font) else {
    // warn!("tried to show text without active font");
    return
  }
  let bytes = text.as_bytes()

  // In case we have a fallback font (which occurs if either no font was set at all
  // in the content stream, or an invalid one), we only want to show the glyphs
  // using Helvetica if the bytes are actually valid ASCII.
  let show_glyphs = match font {
    Font(_) => true
    Fallback(_) => bytes.iter().all(b => b < b'\x80')
  }
  let f = font.font()
  let mut cur_idx = 0
  while cur_idx < bytes.length() {
    let (code, adv) = f.read_code(bytes, cur_idx)
    cur_idx += adv
    if show_glyphs {
      let (glyph, glyph_transform) = f.get_glyph(
        f.map_code(code),
        code,
        ctx,
        resources,
        f.origin_displacement(code),
      )
      show_glyph(ctx, device, glyph, glyph_transform)
    }
    ctx.get().text_state.apply_code_advance(code, adv)
  }
}

///|
fn next_line(ctx : Context, tx : Double, ty : Double) -> Unit {
  let ts = ctx.get().text_state
  let new_matrix = ts.text_line_matrix * @kurbo.Affine::translate(tx, ty)
  ts.text_line_matrix = new_matrix
  ts.text_matrix = new_matrix
}

///|
fn show_glyph(
  ctx : Context,
  device : &Device,
  glyph : Glyph,
  glyph_transform : @kurbo.Affine,
) -> Unit {
  if !ctx.ocg_state.is_visible() {
    return
  }
  let stroke_props = ctx.stroke_props()
  match ctx.get().text_state.render_mode {
    Fill => {
      let props = ctx.draw_props(false)
      device.draw_glyph(glyph, glyph_transform, props, Fill(NonZero))
    }
    Stroke => {
      let props = ctx.draw_props(true)
      device.draw_glyph(glyph, glyph_transform, props, Stroke(stroke_props))
    }
    FillStroke => {
      let props = ctx.draw_props(false)
      device.draw_glyph(glyph, glyph_transform, props, Fill(NonZero))
      let props = ctx.draw_props(true)
      device.draw_glyph(glyph, glyph_transform, props, Stroke(stroke_props))
    }
    Invisible => {
      // Still call draw_glyph for invisible text, so that it can
      // for example be used for text extraction.
      let props = ctx.draw_props(false)
      device.draw_glyph(glyph, glyph_transform, props, Invisible)
    }
    Clip => clip_glyph(ctx, glyph, glyph_transform)
    FillAndClip => {
      clip_glyph(ctx, glyph, glyph_transform)
      let props = ctx.draw_props(false)
      device.draw_glyph(glyph, glyph_transform, props, Fill(NonZero))
    }
    StrokeAndClip => {
      clip_glyph(ctx, glyph, glyph_transform)
      let props = ctx.draw_props(true)
      device.draw_glyph(glyph, glyph_transform, props, Stroke(stroke_props))
    }
    FillAndStrokeAndClip => {
      clip_glyph(ctx, glyph, glyph_transform)
      let props = ctx.draw_props(false)
      device.draw_glyph(glyph, glyph_transform, props, Fill(NonZero))
      let props = ctx.draw_props(true)
      device.draw_glyph(glyph, glyph_transform, props, Stroke(stroke_props))
    }
  }
}

///|
fn clip_glyph(
  context : Context,
  glyph : Glyph,
  transform : @kurbo.Affine,
) -> Unit {
  match glyph {
    Outline(o) => {
      let outline = o.outline().transform(transform)
      let has_outline = outline.segments().length() > 0
      if has_outline {
        context.get().text_state.clip_paths.extend_path(outline)
      }
    }
    Type3(_) =>
      // warn!("text rendering mode clip not implemented for shape glyphs");
      ()
  }
}

///|
priv enum TextRenderingMode {
  Fill
  Stroke
  FillStroke
  Invisible
  FillAndClip
  StrokeAndClip
  FillAndStrokeAndClip
  Clip
}
