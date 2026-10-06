// Port of `typst-render/src/image.rs`.

///|
/// Render a raster or SVG image into the canvas.
fn render_image(
  canvas : @skia.Pixmap,
  state : State,
  image : @library.Image,
  size : @library.Axes[@library.Abs],
) -> Unit {
  let ts = state.transform
  let view_width = to_f32(size.x)
  let view_height = to_f32(size.y)

  // For better-looking output, resize `image` to its final size before
  // painting it to `canvas`. For the math, see:
  // https://github.com/typst/typst/issues/1404#issuecomment-1598374652
  let theta = musl_atan2f(-ts.kx, ts.sx)

  // To avoid division by 0, choose the one of { sin, cos } that is
  // further from 0.
  let prefer_sin = @skia.fabs(musl_sinf(theta)) >
    (0.70710678118654752440 : Float)
  let scale_x = @skia.fabs(
    if prefer_sin {
      ts.kx / musl_sinf(theta)
    } else {
      ts.sx / musl_cosf(theta)
    },
  )
  let aspect = image.width().to_float() / image.height().to_float()
  let w = @skia.f32_to_u32(
    @skia.ceilf(scale_x * @skia.fmax(view_width, aspect * view_height)),
  )
  let h = @skia.f32_to_u32(@skia.ceilf(Float::from_uint(w) / aspect))
  guard build_texture(image, w, h) is Some(pixmap) else { return }
  let paint_scale_x = view_width / Float::from_int(pixmap.width())
  let paint_scale_y = view_height / Float::from_int(pixmap.height())
  let paint = @skia.Paint::default()
  paint.shader = @skia.Pattern::new(
    pixmap,
    Pad,
    Nearest,
    1.0,
    @path.Transform::from_scale(paint_scale_x, paint_scale_y),
  )
  guard @path.Rect::from_xywh(0.0, 0.0, view_width, view_height) is Some(rect) else {
    return
  }
  canvas.fill_rect(rect, paint, ts, state.mask)
}

///|
/// Prepare a texture for an image at a scaled size.
fn build_texture(image : @library.Image, w : UInt, h : UInt) -> @skia.Pixmap? {
  match image.kind() {
    Raster(raster) => {
      guard @skia.Pixmap::new(w, h) is Some(texture) else { return None }
      let dynamic = raster.dynamic()
      let rgba = if w == dynamic.width && h == dynamic.height {
        // Small optimization to not allocate in case image is not resized.
        @codecs.to_rgba8(
          dynamic.width,
          dynamic.height,
          dynamic.color,
          dynamic.buf,
        )
      } else {
        let upscale = w > dynamic.width
        let filter : @codecs.FilterType = match image.scaling() {
          Custom(Pixelated) => Nearest
          _ if upscale => CatmullRom
          _ => Lanczos3 // downscale
        }
        let buf = @codecs.resize_exact(
          dynamic.width,
          dynamic.height,
          dynamic.color,
          dynamic.buf,
          w,
          h,
          filter,
        )
        @codecs.to_rgba8(w, h, dynamic.color, buf)
      }
      let pixels = texture.pixels()
      for i in 0..<pixels.length() {
        let c = @skia.ColorU8::from_rgba(
          rgba[i * 4].to_int(),
          rgba[i * 4 + 1].to_int(),
          rgba[i * 4 + 2].to_int(),
          rgba[i * 4 + 3].to_int(),
        )
        pixels[i] = c.premultiply().0
      }
      Some(texture)
    }
    Svg(svg) => {
      guard @skia.Pixmap::new(w, h) is Some(texture) else { return None }
      let tree = svg.tree()
      let ts = @path.Transform::from_scale(
        @skia.u32_to_f32(w) / tree.size().width(),
        @skia.u32_to_f32(h) / tree.size().height(),
      )
      @resvg.render(tree, ts, texture)
      Some(texture)
    }
    Pdf(pdf) => build_pdf_texture(pdf, w, h)
  }
}

///|
/// Select the substitute for one of the 14 PDF standard fonts
/// (`typst_assets::pdf`).
fn select_standard_font(font : @hayro_interpret.StandardFont) -> (Bytes, Int)? {
  let bytes = match font {
    Helvetica => @pdf_fonts.sans()
    HelveticaBold => @pdf_fonts.sans_bold()
    HelveticaOblique => @pdf_fonts.sans_italic()
    HelveticaBoldOblique => @pdf_fonts.sans_bold_italic()
    Courier => @pdf_fonts.fixed()
    CourierBold => @pdf_fonts.fixed_bold()
    CourierOblique => @pdf_fonts.fixed_italic()
    CourierBoldOblique => @pdf_fonts.fixed_bold_italic()
    TimesRoman => @pdf_fonts.serif()
    TimesBold => @pdf_fonts.serif_bold()
    TimesItalic => @pdf_fonts.serif_italic()
    TimesBoldItalic => @pdf_fonts.serif_bold_italic()
    ZapfDingBats => @pdf_fonts.ding_bats()
    Symbol => @pdf_fonts.symbol()
  }
  Some((bytes, 0))
}

///|
// Keep this in sync with `typst-svg`!
fn build_pdf_texture(
  pdf : @library.PdfImage,
  w : UInt,
  h : UInt,
) -> @skia.Pixmap? {
  let interpreter_settings : @hayro_interpret.InterpreterSettings = {
    font_resolver: query => {
      match query {
        Standard(s) => select_standard_font(s)
        Fallback(f) => select_standard_font(f.pick_standard_font())
      }
    },
    // Fairly niche and enabling hayro's embedded cmap would add a
    // considerable amount of data.
    cmap_resolver: _ => None,
    warning_sink: _ => (),
    // We want to render like it prints, so no annotations.
    render_annotations: false,
  }
  // `w as u16` / `h as u16`.
  let w16 = (w & 0xFFFF).reinterpret_as_int()
  let h16 = (h & 0xFFFF).reinterpret_as_int()
  let render_settings : @hayro_render.RenderSettings = {
    x_scale: @skia.u32_to_f32(w) / pdf.width(),
    y_scale: @skia.u32_to_f32(h) / pdf.height(),
    width: Some(w16),
    height: Some(h16),
    bg_color: @vello_cpu.transparent,
  }
  let cache = @hayro_render.RenderCache::new()
  let hayro_pix = @hayro_render.render(
    pdf.page(),
    cache,
    interpreter_settings,
    render_settings,
  )
  let bytes = hayro_pix.data()
  guard w16.reinterpret_as_uint() == w && h16.reinterpret_as_uint() == h else {
    return None
  }
  @skia.Pixmap::from_bytes(Bytes::from_array(bytes)[:], w, h)
}
