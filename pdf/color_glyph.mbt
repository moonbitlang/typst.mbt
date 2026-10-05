// Drawing color glyphs into Type 3 fonts (port of krilla's `text::glyph`
// modules `colr`, `bitmap` and `outline`, on top of the `otf` port of
// ttf-parser).
//
// SVG glyphs are drawn with krilla-svg's `render_svg_glyph` (`svg.mbt`);
// glyphs fall back to the glyph outline like krilla does when drawing fails.

///|
/// The color glyph hook of a font (krilla `should_outline` and
/// `draw_color_glyph`).
fn color_glyph_hook(font : @library.FontInstance) -> @export.ColorGlyphs? {
  guard font.ttf() is Some(ttf) else { return None }
  color_glyph_hook_face(ttf)
}

///|
/// The color glyph hook of a parsed font face.
fn color_glyph_hook_face(ttf : @otf.Face) -> @export.ColorGlyphs? {
  let tables = ttf.tables()
  let can_be_cid = tables.glyf is Some(_) ||
    tables.cff is Some(_) ||
    tables.cff2 is Some(_)
  // krilla treats every glyph of a font with an `SVG ` table as an SVG
  // glyph.
  let has_svg = tables.svg is Some(_)
  let has_bitmap = (g : @otf.GlyphId) => {
    ttf.glyph_raster_image(g, 0xFFFF) is Some(img) && img.format == PNG
  }
  Some({
    is_color: g => {
      let gid = @otf.GlyphId(g.to_uint16())
      !can_be_cid || has_svg || ttf.is_color_glyph(gid) || has_bitmap(gid)
    },
    draw: (g, context_color, surface) => {
      let gid = @otf.GlyphId(g.to_uint16())
      let drawn = draw_colr_glyph(ttf, gid, context_color, surface) ||
        draw_svg_glyph(ttf, gid, context_color, surface) ||
        draw_bitmap_glyph(ttf, gid, surface)
      if !drawn {
        // Fall back to the outline (filled with black).
        if glyph_outline(ttf, gid) is Some(path) {
          surface.set_fill(Some(@export.Fill::default()))
          surface.set_stroke(None)
          surface.draw_path(path)
          return true
        }
      }
      drawn
    },
  })
}

///|
/// A path builder receiving glyph outlines.
priv struct OutlineSink {
  builder : @export.PathBuilder
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn move_to(self, x, y) {
  self.builder.move_to(x.to_double(), y.to_double())
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn line_to(self, x, y) {
  self.builder.line_to(x.to_double(), y.to_double())
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn quad_to(self, x1, y1, x, y) {
  self.builder.quad_to(
    x1.to_double(),
    y1.to_double(),
    x.to_double(),
    y.to_double(),
  )
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.builder.cubic_to(
    x1.to_double(),
    y1.to_double(),
    x2.to_double(),
    y2.to_double(),
    x.to_double(),
    y.to_double(),
  )
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn close(self) {
  self.builder.close()
}

///|
/// The outline of a glyph in font units (y-up).
fn glyph_outline(ttf : @otf.Face, gid : @otf.GlyphId) -> @export.Path? {
  let sink : OutlineSink = { builder: @export.PathBuilder::new(), }
  guard ttf.outline_glyph(gid, sink) is Some(_) else { return None }
  sink.builder.finish()
}

///|
fn otf_transform(t : @otf.Transform) -> @export.Transform {
  @export.Transform::from_row(
    t.a.to_double(),
    t.b.to_double(),
    t.c.to_double(),
    t.d.to_double(),
    t.e.to_double(),
    t.f.to_double(),
  )
}

///|
/// A COLR painter drawing onto a surface (in font units, y-up).
priv struct ColrSurfacePainter {
  face : @otf.Face
  surface : @export.Surface
  mut path : @export.Path?
  mut transform : @otf.Transform
  transforms : Array[@otf.Transform]
  context_color : Int
}

///|
fn rgba_color(c : @otf.RgbaColor) -> (@export.Color, Double) {
  (
    @export.Color::rgb(c.red.to_int(), c.green.to_int(), c.blue.to_int()),
    c.alpha.to_int().to_double() / 255.0,
  )
}

///|
fn ColrSurfacePainter::stops(
  self : ColrSurfacePainter,
  iter : @otf.GradientStopsIter,
) -> Array[@export.Stop] {
  let out = []
  for stop in iter.iter() {
    let (color, opacity) = rgba_color(stop.color)
    out.push(
      ({ offset: stop.stop_offset.to_double(), color, opacity, } : @export.Stop),
    )
  }
  if out.is_empty() {
    out.push({ offset: 0.0, color: @export.Color::black(), opacity: 1.0, })
  }
  out
}

///|
fn spread(extend_ : @otf.GradientExtend) -> @export.SpreadMethod {
  match extend_ {
    Pad => Pad
    Repeat => Repeat
    Reflect => Reflect
  }
}

///|
fn ColrSurfacePainter::fill(
  self : ColrSurfacePainter,
  paint : @export.Paint,
  opacity : Double,
) -> Unit {
  guard self.path is Some(path) else { return }
  self.surface.set_fill(Some({ paint, opacity, rule: NonZero, }))
  self.surface.set_stroke(None)
  self.surface.draw_path(path)
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn outline_glyph(
  self,
  glyph_id,
) {
  self.path = match glyph_outline(self.face, glyph_id) {
    Some(path) => Some(path.transform(otf_transform(self.transform)))
    None => None
  }
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn paint(self, paint) {
  let ts = otf_transform(self.transform)
  let palette : UInt16 = 0
  let coords = self.face.variation_coordinates()
  match paint {
    Solid(c) => {
      let (color, opacity) = rgba_color(c)
      self.fill(Color(color), opacity)
    }
    LinearGradient(lg) =>
      self.fill(
        LinearGradient({
          x1: lg.x0.to_double(),
          y1: lg.y0.to_double(),
          x2: lg.x1.to_double(),
          y2: lg.y1.to_double(),
          transform: ts,
          spread_method: spread(lg.extend_),
          stops: self.stops(lg.stops(palette, coords)),
          anti_alias: true,
        }),
        1.0,
      )
    RadialGradient(rg) =>
      self.fill(
        RadialGradient({
          fx: rg.x0.to_double(),
          fy: rg.y0.to_double(),
          fr: rg.r0.to_double(),
          cx: rg.x1.to_double(),
          cy: rg.y1.to_double(),
          cr: rg.r1.to_double(),
          transform: ts,
          spread_method: spread(rg.extend_),
          stops: self.stops(rg.stops(palette, coords)),
          anti_alias: true,
        }),
        1.0,
      )
    SweepGradient(sg) =>
      self.fill(
        SweepGradient({
          cx: sg.center_x.to_double(),
          cy: sg.center_y.to_double(),
          start_angle: sg.start_angle.to_double(),
          end_angle: sg.end_angle.to_double(),
          transform: ts,
          spread_method: spread(sg.extend_),
          stops: self.stops(sg.stops(palette, coords)),
          anti_alias: true,
        }),
        1.0,
      )
  }
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn push_clip(self) {
  match self.path {
    Some(path) => self.surface.push_clip_path(path, NonZero)
    None => {
      // Clip everything away.
      let b = @export.PathBuilder::new()
      b.push_rect({ left: 0.0, top: 0.0, right: 0.0, bottom: 0.0, })
      match b.finish() {
        Some(p) => self.surface.push_clip_path(p, NonZero)
        None => self.surface.push_isolated()
      }
    }
  }
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn push_clip_box(self, b) {
  let builder = @export.PathBuilder::new()
  builder.move_to(b.x_min.to_double(), b.y_min.to_double())
  builder.line_to(b.x_max.to_double(), b.y_min.to_double())
  builder.line_to(b.x_max.to_double(), b.y_max.to_double())
  builder.line_to(b.x_min.to_double(), b.y_max.to_double())
  builder.close()
  match builder.finish() {
    Some(path) =>
      self.surface.push_clip_path(
        path.transform(otf_transform(self.transform)),
        NonZero,
      )
    None => self.surface.push_isolated()
  }
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn pop_clip(self) {
  self.surface.pop()
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn push_layer(self, _mode) {
  self.surface.push_isolated()
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn pop_layer(self) {
  self.surface.pop()
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn push_transform(self, ts) {
  self.transforms.push(self.transform)
  self.transform = @otf.Transform::combine(self.transform, ts)
}

///|
impl @otf.ColrPainter for ColrSurfacePainter with fn pop_transform(self) {
  if self.transforms.pop() is Some(ts) {
    self.transform = ts
  }
}

///|
/// Draw a COLR glyph.
fn draw_colr_glyph(
  ttf : @otf.Face,
  gid : @otf.GlyphId,
  context_color : Int,
  surface : @export.Surface,
) -> Bool {
  if !ttf.is_color_glyph(gid) {
    return false
  }
  let painter : ColrSurfacePainter = {
    face: ttf,
    surface,
    path: None,
    transform: @otf.Transform::default(),
    transforms: [],
    context_color,
  }
  let foreground = @otf.RgbaColor::new(
    ((context_color >> 16) & 0xFF).to_byte(),
    ((context_color >> 8) & 0xFF).to_byte(),
    (context_color & 0xFF).to_byte(),
    b'\xFF',
  )
  ttf.paint_color_glyph(gid, 0, foreground, painter) is Some(_)
}

///|
/// Draw a bitmap (PNG) glyph.
fn draw_bitmap_glyph(
  ttf : @otf.Face,
  gid : @otf.GlyphId,
  surface : @export.Surface,
) -> Bool {
  guard ttf.glyph_raster_image(gid, 0xFFFF) is Some(img) && img.format == PNG else {
    return false
  }
  let data = img.data.to_bytes()
  guard decode_png_image(data) is Some(image) else { return false }
  let upem = ttf.units_per_em().to_int().to_double()
  let s = upem / img.pixels_per_em.to_int().to_double()
  let w = image.width.to_double() * s
  let h = image.height.to_double() * s
  let x = img.x.to_int().to_double() * s
  let y = img.y.to_int().to_double() * s
  guard @export.Size::from_wh(w, h) is Some(size) else { return false }
  // Images are drawn y-down: flip, then place the top-left corner.
  surface.push_transform(@export.Transform::from_scale(1.0, -1.0))
  surface.push_transform(@export.Transform::from_translate(x, -(y + h)))
  surface.draw_image(image, size)
  surface.pop()
  surface.pop()
  true
}

///|
/// Decode a PNG into an exporter image.
fn decode_png_image(data : Bytes) -> @export.Image? {
  let raster = @library.RasterImage::plain(data, Exchange(Png)) catch {
    _ => return None
  }
  convert_raster(raster, false).to_option()
}
