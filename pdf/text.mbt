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
  let glyphs = gc.glyphs
  convert_glyphs(t, glyphs)
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
///
/// (Upstream hands krilla the glyphs as they are, behind its `Glyph`
/// trait. Here every glyph of a document is converted, so what is made per
/// glyph is the glyph alone: text that is ASCII, which most is, needs no
/// table of offsets, the glyphs of a word share their location, and the
/// array is the caller's, which uses the one of the text item before: the
/// exporter reads the glyphs while it draws them and keeps none. `out` is
/// emptied first.)
fn convert_glyphs(t : @library.TextItem, out : Array[@export.Glyph]) -> Unit {
  let text = t.text
  let u16 = text.length()
  let mut ascii = true
  for i in 0..<u16 {
    if text.unsafe_get(i).to_int() >= 0x80 {
      ascii = false
      break
    }
  }
  // Map UTF-8 byte offsets to UTF-16 offsets: the two are the same in
  // ASCII text.
  let offsets = if ascii { no_offsets } else { utf16_offsets(text) }
  let glyphs = t.glyphs
  out.clear()
  // The location of the glyph before, to share it with the next glyph of
  // the same span.
  let mut span = 0UL
  let mut location : UInt64? = None
  for g in glyphs {
    // (`let (start, end) = g.range()`, without the tuple.)
    let start = g.range_start.to_int()
    let end = g.range_end.to_int()
    if location is None || g.span.0 != span {
      span = g.span.0
      location = Some(span)
    }
    out.push({
      glyph_id: g.id.to_int(),
      text_start: if ascii {
        if start <= u16 {
          start
        } else {
          u16
        }
      } else if start < offsets.length() {
        offsets[start]
      } else {
        u16
      },
      text_end: if ascii {
        if end <= u16 {
          end
        } else {
          u16
        }
      } else if end < offsets.length() {
        offsets[end]
      } else {
        u16
      },
      x_advance: g.x_advance.get(),
      x_offset: g.x_offset.get(),
      y_advance: g.y_advance.get(),
      y_offset: g.y_offset.get(),
      location,
    })
  }
}

///|
/// The table of offsets that ASCII text does not need (never written to).
let no_offsets : Array[Int32] = []

///|
/// The UTF-16 offset of every UTF-8 byte offset into the text, and of its
/// end.
fn utf16_offsets(text : String) -> Array[Int32] {
  let offsets = []
  let mut u16 = 0
  for c in text {
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
  offsets
}

///|
fn convert_font(
  gc : GlobalContext,
  typst_font : @library.FontInstance,
) -> @export.Font raise @library.SourceError {
  // (Not upstream: the font of the text item before, by its identity.)
  if gc.last_font is Some((last, font)) && physical_equal(last, typst_font) {
    return font
  }
  let font = convert_font_lookup(gc, typst_font)
  gc.last_font = Some((typst_font, font))
  font
}

///|
/// [convert_font] without what it keeps of the call before.
fn convert_font_lookup(
  gc : GlobalContext,
  typst_font : @library.FontInstance,
) -> @export.Font raise @library.SourceError {
  match gc.fonts_forward.get(typst_font) {
    Some(font) => font
    None => {
      // Fonts without variations are shared with SVG images (krilla
      // deduplicates fonts by their font info).
      let font = if typst_font.variations().0.is_empty() {
        let data = typst_font.font().data()
        let index = typst_font.font().index().reinterpret_as_int()
        match gc.svg_fonts.find(data, index) {
          Some(Some(font)) => font
          Some(None) => build_font(typst_font)
          None => {
            let font = build_font(typst_font)
            gc.svg_fonts.insert(data, index, Some(font))
            font
          }
        }
      } else {
        build_font(typst_font)
      }
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
  let variations = []
  for v in typst_font.variations().0 {
    if @subsetter.Tag::from_str(v.0.0) is Some(tag) {
      variations.push((tag, v.1.get()))
    }
  }
  match
    @export.Font::new_variable(
      font.data(),
      font.index().reinterpret_as_int(),
      variations,
    ) {
    Some(f) => {
      if color_glyph_hook(typst_font) is Some(hook) {
        f.set_color_glyphs(hook)
      }
      f
    }
    None =>
      raise @library.SourceError([
        @library.SourceDiagnostic::error_at(
          @syntax.Span::detached(),
          "failed to process \{display_font(Some(typst_font))}",
        ),
      ])
  }
}
