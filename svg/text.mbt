// Port of `typst-svg/src/text.rs`: rendering of text items.

///|
/// Represents a glyph to be rendered.
priv enum RenderedGlyph {
  /// A frame that contains an image glpyh.
  Frame(@library.GlyphFrame)
  /// A path is a sequence of drawing commands.
  ///
  /// It is in the format of `M x y L x y C x1 y1 x2 y2 x y Z`.
  Path(String)
}

///|
/// The rendered outlines of glyphs, by the key of `render_glyph`.
let glyph_paths : Map[@library.U128, RenderedGlyph?] = {}

///|
/// The bounding boxes of glyphs (by font and glyph).
let glyph_bboxes : Map[@library.U128, @otf.Rect?] = {}

///|
/// `text.font.ttf().glyph_bounding_box(id)`, memoized (not upstream: it
/// outlines CFF glyphs again for every use; performance).
fn glyph_bounding_box(
  font : @library.FontInstance,
  glyph_id : UInt16,
) -> @otf.Rect? {
  let key = {
    let h = @library.SipHasher128::new()
    hash_font(h, font)
    hash_u16(h, glyph_id.to_uint())
    h.finish128()
  }
  match glyph_bboxes.get(key) {
    Some(bbox) => bbox
    None => {
      let bbox = match font.ttf() {
        Some(ttf) => ttf.glyph_bounding_box(@otf.GlyphId(glyph_id))
        None => None
      }
      glyph_bboxes[key] = bbox
      bbox
    }
  }
}

///|
/// Render a text item. The text is rendered as a group of glyphs. We will try
/// to render the text as SVG first, then bitmap, then outline. If none of
/// them works, we will skip the text.
fn SVGRenderer::render_text(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  text : @library.TextItem,
) -> Unit {
  let svg = svg.elem("g")

  // Flip the transform since fonts use a Y-Up coordinate system.
  let state = state.pre_concat(
    @library.Transform::scale(@library.Ratio::one(), -@library.Ratio::one()),
  )
  svg.attr("transform", SvgTransform(state.transform)) |> ignore
  let mut x = @library.Abs::pt(0.0)
  let mut y = @library.Abs::pt(0.0)
  for glyph in text.glyphs {
    let x_offset = x + glyph.x_offset.at(text.size)
    let y_offset = y + glyph.y_offset.at(text.size)
    self.render_glyph(svg, state, text, glyph.id, x_offset, y_offset)
    x = x + glyph.x_advance.at(text.size)
    y = y + glyph.y_advance.at(text.size)
  }
  svg.end()
}

///|
fn SVGRenderer::render_glyph(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  text : @library.TextItem,
  glyph_id : UInt16,
  x_offset : @library.Abs,
  y_offset : @library.Abs,
) -> Unit {
  if @library.should_outline(text.font, glyph_id) {
    // Pre-scale outlined glyphs, so strokes and fill patterns don't need to
    // consider text size glyph scaling.
    let scale = @library.Ratio::new(
      text.size.to_pt() / text.font.units_per_em(),
    )
    let key = {
      let h = @library.SipHasher128::new()
      hash_font(h, text.font)
      hash_u16(h, glyph_id.to_uint())
      hash_ratio(h, scale)
      h.finish128()
    }
    let (id, path) = self.glyphs.insert_with_val(key, () => {
      // The outlines are shared by all pages (not upstream: each page's
      // SVG outlines its glyphs again; performance).
      match glyph_paths.get(key) {
        Some(path) => return path
        None => ()
      }
      let path = {
        let builder = SvgPathBuilder::with_scale(scale)
        guard text.font.ttf() is Some(ttf) else { return None }
        guard ttf.outline_glyph(@otf.GlyphId(glyph_id), OutlineSink(builder))
          is Some(_) else {
          return None
        }
        Some(RenderedGlyph::Path(builder.finsish()))
      }
      glyph_paths[key] = path
      path
    })
    if path is Some(_) {
      self.render_path_glyph(svg, state, text, glyph_id, x_offset, y_offset, id)
    }
  } else {
    // Image glyphs apply a `scale` at use site, since colr, svg-, and bitmap
    // glyph images are usually quite large, and having one glyph per text
    // size is a bit of a waste.
    let key = {
      let h = @library.SipHasher128::new()
      hash_font(h, text.font)
      hash_u16(h, glyph_id.to_uint())
      h.finish128()
    }
    let (id, frame) = self.glyphs.insert_with_val(key, () => {
      match @library.glyph_frame(text.font, glyph_id) {
        Some(frame) => Some(RenderedGlyph::Frame(frame))
        None => None
      }
    })
    if frame is Some(_) {
      self.render_image_glyph(svg, x_offset, y_offset, text, id)
    }
  }
}

///|
/// Write a reference to an image glyph that is stored in font units.
fn SVGRenderer::render_image_glyph(
  _self : SVGRenderer,
  svg : SvgElem,
  x_offset : @library.Abs,
  y_offset : @library.Abs,
  text : @library.TextItem,
  id : DedupId,
) -> Unit {
  let scale = @library.Ratio::new(text.size.to_pt() / text.font.units_per_em())
  // Flip the transform again, since images are drawn Y-Down.
  let ts = @library.Transform::translate(x_offset, y_offset).pre_concat(
    @library.Transform::scale(scale, -scale),
  )
  svg
  .elem("use")
  .attr("xlink:href", SvgIdRef(id))
  .attr("transform", SvgTransform(ts))
  .end()
}

///|
/// Render a pre-scaled path glyph defined by an outline.
fn SVGRenderer::render_path_glyph(
  self : SVGRenderer,
  svg : SvgElem,
  state : State,
  text : @library.TextItem,
  glyph_id : UInt16,
  x_offset : @library.Abs,
  y_offset : @library.Abs,
  id : DedupId,
) -> Unit {
  // Apply the transform here, because the state transform is used to draw
  // strokes and fills with gradients and tilings.
  let state = state.pre_concat(
    @library.Transform::translate(x_offset, y_offset),
  )
  let glyph_size = glyph_bounding_box(text.font, glyph_id)
  guard glyph_size is Some(glyph_size) else {
    // This shouldn't happen, because the glyph has been successfully
    // outlined to create the path.
    return
  }
  let aspect_ratio = (
    {
      x: @library.Abs::pt(glyph_size.width().to_int().to_double()),
      y: @library.Abs::pt(glyph_size.height().to_int().to_double()),
    } : @library.Axes[@library.Abs]).aspect_ratio()
  let use_ = svg.elem("use")
  use_
  .attr("xlink:href", SvgIdRef(id))
  .attr("x", x_offset.to_pt())
  .attr("y", y_offset.to_pt())
  |> ignore
  self.write_fill(
    use_,
    text.fill,
    @library.FillRule::NonZero,
    aspect_ratio,
    self.text_paint_transform(state, text.fill),
  )
  if text.stroke is Some(stroke) {
    self.write_stroke(
      use_,
      stroke,
      aspect_ratio,
      self.text_paint_transform(state, stroke.paint),
    )
  }
  use_.end()
}

///|
fn SVGRenderer::text_paint_transform(
  _self : SVGRenderer,
  state : State,
  paint : @library.Paint,
) -> @library.Transform {
  match paint {
    Solid(_) => @library.Transform::identity()
    Gradient(gradient) =>
      match gradient.unwrap_relative(true) {
        Self_ => @library.Transform::identity()
        Parent =>
          @library.Transform::scale(
            @library.Ratio::new(state.size.x.to_pt()),
            @library.Ratio::new(state.size.y.to_pt()),
          ).post_concat(state.transform.invert().unwrap())
      }
    Tiling(tiling) =>
      match tiling.unwrap_relative(true) {
        Self_ => @library.Transform::identity()
        Parent => state.transform.invert().unwrap()
      }
  }
}

///|
/// Build the glyph definitions.
fn SVGRenderer::write_glyph_defs(self : SVGRenderer, svg : SvgElem) -> Unit {
  if self.glyphs.iter().iter().all(e => e.1 is None) {
    return
  }
  let defs = svg.elem("defs")
  let glyphs = self.glyphs
  // Upstream takes the glyphs with `std::mem::take`, leaving a default
  // deduplicator whose kind is `'\0'`. Glyphs referenced while writing
  // tilings later on are thus written as `#\0<hash>` (sic).
  self.glyphs = Deduplicator::new('\u{0}')
  for entry in glyphs.iter() {
    let (id, glyph) = entry
    guard glyph is Some(glyph) else { continue }
    let symbol = defs.elem("symbol")
    symbol.attr("id", id) |> ignore
    symbol.attr("overflow", "visible") |> ignore
    match glyph {
      Frame(frame) => {
        let state = State::new(frame.size()).pre_translate(frame.item.pos())
        match frame.item {
          Tofu(_, shape) => self.render_shape(symbol, state, shape)
          Image(_, image, size) => self.render_image(symbol, state, image, size)
        }
      }
      Path(path) => symbol.elem("path").attr("d", path).end()
    }
    symbol.end()
  }
  defs.end()

  // The glyphs have been taken above, there shouldn't be any new glyphs
  // produced from writing the glyph definitions.
  guard self.glyphs.is_empty() else { abort("new glyphs were produced") }
}
