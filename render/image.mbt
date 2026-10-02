// Port of `typst-render/src/image.rs`.

///|
/// Render a raster or SVG image into the canvas.
fn render_image(
  canvas : @skia.Pixmap,
  state : State,
  image : @library.Image,
  size : @library.Axes[@library.Abs],
) -> Unit raise RenderPanic {
  let ts = state.transform
  let view_width = to_f32(size.x)
  let view_height = to_f32(size.y)

  // For better-looking output, resize `image` to its final size before
  // painting it to `canvas`. For the math, see:
  // https://github.com/typst/typst/issues/1404#issuecomment-1598374652
  let theta = musl_atan2f(-ts.kx, ts.sx)

  // To avoid division by 0, choose the one of { sin, cos } that is
  // further from 0.
  let prefer_sin = @path.fabs(musl_sinf(theta)) >
    (0.70710678118654752440 : Float)
  let scale_x = @path.fabs(
    if prefer_sin {
      ts.kx / musl_sinf(theta)
    } else {
      ts.sx / musl_cosf(theta)
    },
  )
  let aspect = image.width().to_float() / image.height().to_float()
  let w = @path.f32_to_u32(
    @path.ceilf(scale_x * @path.fmax(view_width, aspect * view_height)),
  )
  let h = @path.f32_to_u32(@path.ceilf(Float::from_uint(w) / aspect))
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
fn build_texture(
  image : @library.Image,
  w : UInt,
  h : UInt,
) -> @skia.Pixmap? raise RenderPanic {
  match image.kind() {
    Raster(raster) => {
      guard @skia.Pixmap::new(w, h) is Some(texture) else { return None }
      // TODO: the pixels of JPEG, GIF and WebP images are not decoded yet.
      guard raster.dynamic() is Some(dynamic) else { return None }
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
      match svg_image_renderer.val {
        Some(f) => f(svg, texture, w, h)
        None => ()
      }
      Some(texture)
    }
    Pdf(_) =>
      // TODO: PDF images need `hayro`.
      None
  }
}
