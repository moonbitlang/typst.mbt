// Port of `typst-pdf/src/text.rs`.

///|
fn handle_text(
  fc : FrameContext,
  t : @library.TextItem,
  surface : @export.Surface,
  gc : GlobalContext,
) -> Unit raise @library.SourceError {
  let started = tags_text(gc, fc, surface, t)
  let font = convert_font(gc, t.font)
  let fill = convert_fill(gc, t.fill, NonZero, true, surface, fc.state(), None)
  let stroke = match t.stroke {
    Some(stroke) =>
      Some(convert_stroke(gc, stroke, true, surface, fc.state(), None))
    None => None
  }
  let size = t.size
  let glyphs = convert_glyphs(t)
  surface.push_transform(to_export_transform(fc.state().transform))
  surface.set_fill(Some(fill))
  surface.set_stroke(stroke)
  surface.draw_glyphs(
    @export.Point::from_xy(0.0, 0.0),
    glyphs[:],
    font,
    t.text,
    to_f32(size),
  )
  surface.pop()
  if started {
    surface.end_tagged()
  }
}

///|
/// Convert the glyphs of a text item; text ranges are converted from UTF-8
/// byte offsets to UTF-16 offsets into the text.
fn convert_glyphs(t : @library.TextItem) -> Array[@export.Glyph] {
  // Map UTF-8 byte offsets to UTF-16 offsets.
  let offsets = []
  let mut u16 = 0
  for c in t.text {
    let cp = c.to_int()
    let n = if cp < 0x80 {
      1
    } else if cp < 0x800 {
      2
    } else if cp < 0x10000 {
      3
    } else {
      4
    }
    for _ in 0..<n {
      offsets.push(u16)
    }
    u16 += if cp >= 0x10000 { 2 } else { 1 }
  }
  offsets.push(u16)
  let map = (b : Int) => {
    if b >= 0 && b < offsets.length() {
      offsets[b]
    } else {
      u16
    }
  }
  t.glyphs.map(g => {
    let (start, end) = g.range()
    {
      glyph_id: g.id.to_int(),
      text_start: map(start),
      text_end: map(end),
      x_advance: g.x_advance.get(),
      x_offset: g.x_offset.get(),
      y_advance: g.y_advance.get(),
      y_offset: g.y_offset.get(),
      location: Some(g.span.0.0),
    }
  })
}

///|
fn convert_font(
  gc : GlobalContext,
  typst_font : @library.FontInstance,
) -> @export.Font raise @library.SourceError {
  match gc.fonts_forward.get(typst_font) {
    Some(font) => font
    None => {
      let font = build_font(typst_font)
      gc.fonts_forward[typst_font] = font
      gc.fonts_backward.push((font, typst_font))
      font
    }
  }
}

///|
fn build_font(
  typst_font : @library.FontInstance,
) -> @export.Font raise @library.SourceError {
  let font = typst_font.font()
  match @export.Font::new(font.data(), font.index().reinterpret_as_int()) {
    Some(f) => f
    None =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "failed to process \{display_font(Some(typst_font))}",
        ),
      ])
  }
}
