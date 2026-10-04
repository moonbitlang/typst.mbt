// Port of `typst-render/src/text.rs`.

///|
/// Render a text run into the canvas.
fn render_text(
  canvas : @skia.Pixmap,
  state : State,
  text : @library.TextItem,
) -> Unit raise RenderPanic {
  let mut x = @library.Abs::zero()
  let mut y = @library.Abs::zero()
  for glyph in text.glyphs {
    let id = glyph.id
    let x_offset = x + glyph.x_offset.at(text.size)
    let y_offset = y + glyph.y_offset.at(text.size)
    if @library.should_outline(text.font, id) {
      let state = state.pre_translate({ x: x_offset, y: -y_offset, })
      render_outline_glyph(canvas, state, text, id)
    } else {
      let upem = text.font.units_per_em()
      let text_scale = text.size.div_by(upem)
      let state = state
        .pre_translate({ x: x_offset, y: -y_offset, })
        .pre_scale({ x: text_scale, y: text_scale, })
      if @library.glyph_frame(text.font, id) is Some(frame) {
        render_frame(canvas, state, frame.to_frame())
      }
    }
    x = x + glyph.x_advance.at(text.size)
    y = y + glyph.y_advance.at(text.size)
  }
}

///|
/// Allows to build tiny-skia paths from glyph outlines.
priv struct WrappedPathBuilder(@path.PathBuilder)

///|
impl @otf.OutlineBuilder for WrappedPathBuilder with fn move_to(self, x, y) {
  self.0.move_to(x, y)
}

///|
impl @otf.OutlineBuilder for WrappedPathBuilder with fn line_to(self, x, y) {
  self.0.line_to(x, y)
}

///|
impl @otf.OutlineBuilder for WrappedPathBuilder with fn quad_to(
  self,
  x1,
  y1,
  x,
  y,
) {
  self.0.quad_to(x1, y1, x, y)
}

///|
impl @otf.OutlineBuilder for WrappedPathBuilder with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.0.cubic_to(x1, y1, x2, y2, x, y)
}

///|
impl @otf.OutlineBuilder for WrappedPathBuilder with fn close(self) {
  self.0.close()
}

///|
/// The loaded `pixglyph` glyphs (see [load_pixglyph]).
let pixglyphs : Map[(@library.FontInstance, UInt16), @pixglyph.Glyph?] = {}

///|
/// `@pixglyph.Glyph::load(text.font.ttf(), id)`, memoized (not upstream:
/// loading outlines the glyph; loaded glyphs are immutable; performance).
fn load_pixglyph(font : @library.FontInstance, id : UInt16) -> @pixglyph.Glyph? {
  let key = (font, id)
  match pixglyphs.get(key) {
    Some(glyph) => glyph
    None => {
      let glyph = match font.ttf() {
        Some(ttf) => @pixglyph.Glyph::load(ttf, @otf.GlyphId(id))
        None => None
      }
      pixglyphs[key] = glyph
      glyph
    }
  }
}

///|
/// Render an outline glyph into the canvas. This is the "normal" case.
fn render_outline_glyph(
  canvas : @skia.Pixmap,
  state : State,
  text : @library.TextItem,
  id : UInt16,
) -> Unit raise RenderPanic {
  let ts = state.transform
  let ppem = to_f32(text.size) * ts.sy

  // Render a glyph directly as a path. This only happens when the fast glyph
  // rasterization can't be used due to very large text size or weird
  // scale/skewing transforms.
  if ppem > 100.0 ||
    ppem < 0.0 ||
    ts.kx != 0.0 ||
    ts.ky != 0.0 ||
    ts.sx != ts.sy ||
    text.stroke is Some(_) {
    guard text.font.ttf() is Some(ttf) else { return }
    let builder = WrappedPathBuilder(@path.PathBuilder::new())
    guard ttf.outline_glyph(@otf.GlyphId(id), builder) is Some(_) else {
      return
    }
    guard builder.0.finish() is Some(path) else { return }
    let scale = to_f32(text.size) / text.font.units_per_em().to_float()
    let rule : @skia.FillRule = Winding

    // Flip vertically because font design coordinate
    // system is Y-up.
    let ts = ts.pre_scale(scale, -scale)
    let state_ts = state.pre_concat(@path.Transform::from_scale(scale, -scale))
    let paint = to_sk_paint(text.fill, state_ts, true, None, false)
    canvas.fill_path(path, paint, rule, ts, state.mask)
    if text.stroke is Some(stroke) && to_f32(stroke.thickness) > 0.0 {
      let dash = stroke.dash.bind(to_sk_dash_pattern)
      let paint = to_sk_paint(stroke.paint, state_ts, true, None, false)
      let sk_stroke : @path.Stroke = {
        width: to_f32(stroke.thickness) / scale, // When we scale the path, we need to scale the stroke width, too.
        line_cap: to_sk_line_cap(stroke.cap),
        line_join: to_sk_line_join(stroke.join),
        dash,
        miter_limit: stroke.miter_limit.get().to_float(),
      }
      canvas.stroke_path(path, paint, sk_stroke, ts, state.mask)
    }
    return
  }

  // Rasterize the glyph with `pixglyph`.
  guard load_pixglyph(text.font, id) is Some(glyph) else { return }
  let bitmap = glyph.rasterize(ts.tx, ts.ty, ppem)
  match text.fill {
    Gradient(gradient) => {
      let sampler = gradient_sampler(
        gradient,
        state,
        @library.Axes::splat(@library.Abs::zero()),
        true,
      )
      write_bitmap(canvas, bitmap, state, sampler)
    }
    Solid(color) =>
      write_bitmap(
        canvas,
        bitmap,
        state,
        PaintSampler::solid(to_sk_color_u8(color.to_process()).premultiply()),
      )
    Tiling(tiling) => {
      let pixmap = render_tiling_frame(state, tiling)
      let sampler = tiling_sampler(tiling, pixmap, state, true)
      write_bitmap(canvas, bitmap, state, sampler)
    }
  }
}

///|
fn write_bitmap(
  canvas : @skia.Pixmap,
  bitmap : @pixglyph.Bitmap,
  state : State,
  sampler : PaintSampler,
) -> Unit raise RenderPanic {
  // If we have a clip mask we first render to a pixmap that we then blend
  // with our canvas
  if state.mask is Some(_) {
    let cw = canvas.width()
    let ch = canvas.height()
    let mw = bitmap.width
    let mh = bitmap.height
    let left = bitmap.left
    let top = bitmap.top

    // Pad the pixmap with 1 pixel in each dimension so that we do
    // not get any problem with floating point errors along their border
    guard @skia.Pixmap::new(mw + 2, mh + 2) is Some(pixmap) else { return }
    let pixels = pixmap.pixels()
    let mw = mw.reinterpret_as_int()
    let mh = mh.reinterpret_as_int()
    for x in 0..<mw {
      for y in 0..<mh {
        let alpha = bitmap.coverage[y * mw + x].to_uint()

        // To sample at the correct position, we need to convert each
        // pixel's position in the bitmap (x and y) to its final
        // expected position in the canvas. Due to padding, this
        // pixel's position in the pixmap will be (x + 1, y + 1).
        // Then, when drawing the pixmap to the canvas, we place its
        // top-left corner at position (left - 1, top - 1). Therefore,
        // the final position of this pixel in the canvas is given by
        // (left - 1 + x + 1, top - 1 + y + 1) = (left + x, top + y).
        let sx = clamp(left + x, 0, cw).reinterpret_as_uint()
        let sy = clamp(top + y, 0, ch).reinterpret_as_uint()
        let color = sampler.sample(sx, sy)
        let applied = alpha_mul(color, alpha)
        pixels[(y + 1) * (mw + 2) + (x + 1)] = applied
      }
    }
    canvas.draw_pixmap(
      left - 1,
      top - 1,
      pixmap,
      @skia.PixmapPaint::default(),
      @path.Transform::identity(),
      state.mask,
    )
  } else {
    let cw = canvas.width()
    let ch = canvas.height()
    let mw = bitmap.width.reinterpret_as_int()
    let mh = bitmap.height.reinterpret_as_int()

    // Determine the pixel bounding box that we actually need to draw.
    let left = bitmap.left
    let right = left + mw
    let top = bitmap.top
    let bottom = top + mh

    // Blend the glyph bitmap with the existing pixels on the canvas.
    let pixels = canvas.pixels()
    for x in clamp(left, 0, cw)..<clamp(right, 0, cw) {
      for y in clamp(top, 0, ch)..<clamp(bottom, 0, ch) {
        let ai = (y - top) * mw + (x - left)
        let cov = bitmap.coverage[ai].to_uint()
        if cov == 0 {
          continue
        }
        let color = sampler.sample(
          x.reinterpret_as_uint(),
          y.reinterpret_as_uint(),
        )
        let pi = y * cw + x
        // Fast path if color is opaque.
        if cov == 255 && (color & 0xFF) == 0xFF {
          pixels[pi] = color
          continue
        }
        let applied = alpha_mul(color, cov)
        pixels[pi] = blend_src_over(applied, pixels[pi])
      }
    }
  }
}

///|
fn clamp(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

// Alpha multiplication and blending are ported from:
// https://skia.googlesource.com/skia/+/refs/heads/main/include/core/SkColorPriv.h

///|
/// Blends two premulitplied, packed 32-bit RGBA colors. Alpha channel must be
/// in the 8 high bits.
fn blend_src_over(src : UInt, dst : UInt) -> UInt {
  src + alpha_mul(dst, 256 - (src >> 24))
}

///|
/// Alpha multiply a color.
fn alpha_mul(color : UInt, scale : UInt) -> UInt {
  let mask = 0xff00ffU
  let rb = ((color & mask) * scale) >> 8
  let ag = ((color >> 8) & mask) * scale
  (rb & mask) | (ag & mask.lnot())
}
