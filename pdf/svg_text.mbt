// Port of `krilla-svg/src/text.rs`.

///|
/// Render a text into a surface.
fn svg_text_render(
  text : @usvg.Text,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit {
  for span in text.layouted() {
    if !span.visible {
      continue
    }
    if span.overline is Some(overline) {
      svg_path_render(overline, surface, process_context)
    }
    if span.underline is Some(underline) {
      svg_path_render(underline, surface, process_context)
    }
    for glyph in span.positioned_glyphs {
      // Ignore glyph if font can't be fetched.
      guard process_context.fonts.retrieve(span, glyph.font) is Some(loaded) else {
        continue
      }
      let font = loaded.font
      let upem = Float::from_double(font.units_per_em)
      let font_size = span.font_size.get()

      // The text transform contains the scale transform `font_size / upem`,
      // we need to invert that so we only get the raw transform to account
      // for the glyph position, and the font size is being taken care of by
      // the exporter.
      let transform = glyph
        .transform()
        .pre_concat(
          @tiny_skia_path.Transform::from_scale(
            upem / font_size,
            upem / font_size,
          ),
        )
      guard transform.invert() is Some(inverted) else { continue }

      // We need to apply the inverse transform to fill/stroke because we
      // don't want the paint to be affected by the transform applied to the
      // glyph. See docs of `svg_convert_paint`.
      let fill = span
        .fill()
        .map(f => svg_convert_fill(f, surface, process_context, inverted))
      let stroke = span
        .stroke()
        .map(s => svg_convert_stroke(s, surface, process_context, inverted))
      let draw_op = (
        s : @export.Surface,
        fill : @export.Fill?,
        stroke : @export.Stroke?,
        embed_text : Bool,
      ) => {
        s.set_fill(fill)
        s.set_stroke(stroke)
        if embed_text {
          let glyphs : Array[@export.Glyph] = [
            {
              glyph_id: glyph.id,
              // Don't care about those, since we render only one glyph.
              x_advance: 0.0,
              x_offset: 0.0,
              y_offset: 0.0,
              y_advance: 0.0,
              text_start: 0,
              text_end: glyph.text.length(),
              location: None,
            },
          ]
          s.draw_glyphs(
            @export.Point::from_xy(0.0, 0.0),
            glyphs[:],
            font,
            glyph.text,
            font_size.to_double(),
          )
        } else {
          svg_outline_glyph(s, loaded, glyph.id, font_size.to_double())
        }
      }
      surface.push_transform(svg_transform_to_export(transform))
      if fill is None && stroke is None {
        // Emulate invisible glyph by drawing it with an opacity of zero.
        draw_op(
          surface,
          Some({
            paint: Color(Regular(Rgb(0, 0, 0))),
            opacity: 0.0,
            rule: NonZero,
          }),
          None,
          process_context.svg_settings.embed_text,
        )
      } else if span.paint_order is FillAndStroke ||
        fill is None ||
        stroke is None {
        draw_op(surface, fill, stroke, process_context.svg_settings.embed_text)
      } else {
        // Paint order stroke and fill, and we have BOTH, a fill and
        // stroke.

        // We always draw the text outlined in this case, so that
        // text won't be embedded twice.
        draw_op(surface, None, stroke, false)
        draw_op(surface, fill, None, process_context.svg_settings.embed_text)
      }
      surface.pop()
    }
    if span.line_through is Some(line_through) {
      svg_path_render(line_through, surface, process_context)
    }
  }
}

///|
/// Draw a glyph as an outline (krilla `Surface::draw_glyphs` with
/// `outlined: true`, i.e. `outline_glyphs` for a single glyph at the
/// origin without offsets).
///
/// Deviation: krilla first tries to draw the glyph as a color glyph; here
/// only the outline is drawn.
fn svg_outline_glyph(
  surface : @export.Surface,
  loaded : SvgLoadedFont,
  glyph : Int,
  font_size : Double,
) -> Unit {
  guard loaded.face is Some(ttf) else { return }
  let scale = Float::from_double(font_size) /
    Float::from_double(loaded.font.units_per_em)
  let base_transform = @tiny_skia_path.Transform::from_translate(0.0, 0.0).pre_concat(
    @tiny_skia_path.Transform::from_scale(scale, -scale),
  )
  guard glyph_outline(ttf, @otf.GlyphId(glyph.to_uint16())) is Some(path) else {
    return
  }
  surface.draw_path(path.transform(svg_transform_to_export(base_transform)))
}

///|
/// A font loaded for an SVG.
priv struct SvgLoadedFont {
  font : @export.Font
  /// The parsed face, for outlined glyphs.
  face : @otf.Face?
}

///|
/// Manages the exporter fonts used by an SVG (krilla-svg `Fonts`).
priv struct SvgFonts {
  db : @usvg.FontDatabase
  fonts : Map[(@usvg.FontId, Array[@usvg.FontVariation]), SvgLoadedFont?]
  supported_axes : Map[@usvg.FontId, Array[FixedArray[Byte]]]
  /// The exporter fonts shared with the rest of the document (krilla
  /// deduplicates fonts by their font info, so a font used both by Typst
  /// text and an SVG is only embedded once).
  cache : SvgFontCache
}

///|
fn SvgFonts::new(db : @usvg.FontDatabase, cache : SvgFontCache) -> SvgFonts {
  { db, fonts: {}, supported_axes: {}, cache, }
}

///|
/// Retrieves the font identified by `id` from the cache or loads it.
///
/// Deviation: the exporter cannot instantiate variable fonts, so the
/// default instance is used whatever the variations are.
fn SvgFonts::retrieve(
  self : SvgFonts,
  span : @usvg.LayoutSpan,
  id : @usvg.FontId,
) -> SvgLoadedFont? {
  let variations = self.resolve_variations(span, id)
  let key = (id, variations)
  match self.fonts.get(key) {
    Some(font) => font
    None => {
      let font = match self.db.face(id) {
        Some(info) =>
          self.cache
          .get_or_load(info.source, info.index.reinterpret_as_int())
          .map(font => {
            font,
            face: Some(@otf.Face::parse(info.source[:], info.index)) catch {
              _ => None
            },
          })
        None => None
      }
      self.fonts[key] = font
      font
    }
  }
}

///|
/// Resolves which variations are applicable for the given font (filtering
/// out undefined axis values and taking into account optical sizing).
fn SvgFonts::resolve_variations(
  self : SvgFonts,
  span : @usvg.LayoutSpan,
  id : @usvg.FontId,
) -> Array[@usvg.FontVariation] {
  let supported_axes = match self.supported_axes.get(id) {
    Some(axes) => axes
    None => {
      let axes = self.db
        .with_face_data(id, (data, index) => {
          let axes : Array[FixedArray[Byte]] = []
          let face = Some(@otf.Face::parse(data[:], index)) catch { _ => None }
          if face is Some(font) {
            for axis in font.variation_axes().iter() {
              axes.push(FixedArray::from_iter(axis.tag.to_bytes().iter()))
            }
          }
          axes
        })
        .unwrap_or([])
      self.supported_axes[id] = axes
      axes
    }
  }
  let is_supported = (tag : FixedArray[Byte]) => supported_axes.contains(tag)
  let variations = span.variations.filter(v => is_supported(v.tag))

  // Set the font size for optical sizing if desired, supported, and not
  // manually set.
  let opsz : FixedArray[Byte] = [b'o', b'p', b's', b'z']
  if span.font_optical_sizing == OpticalAuto &&
    is_supported(opsz) &&
    !variations.iter().any(v => v.tag == opsz) {
    variations.push(@usvg.FontVariation::new(opsz, span.font_size.get()))
  }
  variations
}

///|
/// The exporter fonts of the document by font data (compared by identity)
/// and face index, for fonts without variations.
///
/// What the SVG images of a document share is here; besides the fonts, the
/// error of the first image inside an SVG that cannot be decoded (krilla
/// decodes an image when the document is written and fails with
/// `KrillaError::Image`: see `svg_png_image`), until the caller that drew
/// the SVG takes it.
priv struct SvgFontCache {
  entries : Array[(Bytes, Int, @export.Font?)]
  mut image_error : String?
}

///|
fn SvgFontCache::new() -> SvgFontCache {
  { entries: [], image_error: None, }
}

///|
fn SvgFontCache::find(
  self : SvgFontCache,
  data : Bytes,
  index : Int,
) -> @export.Font?? {
  for entry in self.entries {
    if physical_equal(entry.0, data) && entry.1 == index {
      return Some(entry.2)
    }
  }
  None
}

///|
fn SvgFontCache::insert(
  self : SvgFontCache,
  data : Bytes,
  index : Int,
  font : @export.Font?,
) -> Unit {
  self.entries.push((data, index, font))
}

///|
/// Retrieves the exporter font for some font data or loads it (krilla
/// `Font::new`).
fn SvgFontCache::get_or_load(
  self : SvgFontCache,
  data : Bytes,
  index : Int,
) -> @export.Font? {
  match self.find(data, index) {
    Some(font) => font
    None => {
      let font = @export.Font::new(data, index)
      if font is Some(f) {
        let face = Some(@otf.Face::parse(data[:], index.reinterpret_as_uint())) catch {
          _ => None
        }
        if face is Some(ttf) && color_glyph_hook_face(ttf) is Some(hook) {
          f.set_color_glyphs(hook)
        }
      }
      self.insert(data, index, font)
      font
    }
  }
}
