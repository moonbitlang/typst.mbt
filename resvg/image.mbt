// Port of `resvg/src/image.rs` (with the `raster-images` feature, as enabled
// by Typst).

///|
/// Upstream `image::render`.
fn render_image(
  image : @usvg.Image,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  if !image.is_visible() {
    return
  }
  render_image_inner(image.kind(), transform, image.rendering_mode(), pixmap)
}

///|
fn render_image_inner(
  image_kind : @usvg.ImageKind,
  transform : @path.Transform,
  rendering_mode : @usvg.ImageRendering,
  pixmap : @skia.Pixmap,
) -> Unit {
  match image_kind {
    SVG(tree) => render_vector(tree, transform, pixmap)
    _ => render_raster(image_kind, transform, rendering_mode, pixmap) |> ignore
  }
}

///|
fn render_vector(
  tree : @usvg.Tree,
  transform : @path.Transform,
  pixmap : @skia.Pixmap,
) -> Unit {
  let sub_pixmap = @skia.Pixmap::new(
    pixmap.width().reinterpret_as_uint(),
    pixmap.height().reinterpret_as_uint(),
  ).unwrap()
  render(tree, transform, sub_pixmap)
  pixmap.draw_pixmap(
    0,
    0,
    sub_pixmap,
    @skia.PixmapPaint::default(),
    @path.Transform::default(),
    None,
  )
}

///|
fn decode_raster(image : @usvg.ImageKind) -> @skia.Pixmap? {
  match image {
    SVG(_) => None
    // Failed to decode a JPEG image.
    JPEG(data) => decode_jpeg(data)
    // Failed to decode a PNG image.
    PNG(data) => decode_png(data)
    // Failed to decode a GIF image.
    GIF(data) => decode_gif(data)
    // Failed to decode a WebP image.
    WEBP(data) => decode_webp(data)
  }
}

///|
fn decode_png(data : Bytes) -> @skia.Pixmap? {
  Some(@skia.Pixmap::decode_png(data)) catch {
    _ => None
  }
}

///|
/// Upstream decodes with `zune-jpeg` into RGBA. The `codecs` port of
/// `zune-jpeg` produces RGB or luma samples, which are expanded to RGBA
/// with an opaque alpha (what zune-jpeg's RGBA output contains).
fn decode_jpeg(data : Bytes) -> @skia.Pixmap? {
  let (info, buf) = @codecs.decode_jpeg(data) catch { _ => return None }
  guard @path.IntSize::from_wh(info.width, info.height) is Some(size) else {
    return None
  }
  let rgba = @codecs.to_rgba8(info.width, info.height, info.color, buf)
  let n = rgba.length() / 4
  let pixels = FixedArray::make(n, 0U)
  for i in 0..<n {
    pixels[i] = rgba[i * 4].to_uint() |
      (rgba[i * 4 + 1].to_uint() << 8) |
      (rgba[i * 4 + 2].to_uint() << 16) |
      (rgba[i * 4 + 3].to_uint() << 24)
  }
  @skia.Pixmap::from_vec(pixels, size)
}

///|
fn decode_gif(data : Bytes) -> @skia.Pixmap? {
  let first_frame = @codecs.decode_gif_first_frame(data) catch {
    _ => return None
  }
  guard first_frame is Some(first_frame) else { return None }
  guard @path.IntSize::from_wh(
      first_frame.width.reinterpret_as_uint(),
      first_frame.height.reinterpret_as_uint(),
    )
    is Some(size) else {
    return None
  }
  let (w, h) = size.dimensions()
  guard @skia.Pixmap::new(w, h) is Some(pixmap) else { return None }
  rgba_to_pixmap(first_frame.rgba, pixmap)
  Some(pixmap)
}

///|
fn rgba_to_pixmap(data : Bytes, pixmap : @skia.Pixmap) -> Unit {
  let dst = pixmap.pixels()
  let n = @cmp.minimum(data.length() / 4, dst.length())
  for i in 0..<n {
    let a = data[i * 4 + 3].to_int()
    let af = a.to_double() / 255.0
    let r = f64_to_u8(data[i * 4].to_int().to_double() * af + 0.5)
    let g = f64_to_u8(data[i * 4 + 1].to_int().to_double() * af + 0.5)
    let b = f64_to_u8(data[i * 4 + 2].to_int().to_double() * af + 0.5)
    dst[i] = r.reinterpret_as_uint() |
      (g.reinterpret_as_uint() << 8) |
      (b.reinterpret_as_uint() << 16) |
      (a.reinterpret_as_uint() << 24)
  }
}

///|
fn rgb_to_pixmap(data : Bytes, pixmap : @skia.Pixmap) -> Unit {
  let dst = pixmap.pixels()
  let n = @cmp.minimum(data.length() / 3, dst.length())
  for i in 0..<n {
    dst[i] = data[i * 3].to_uint() |
      (data[i * 3 + 1].to_uint() << 8) |
      (data[i * 3 + 2].to_uint() << 16) |
      (255U << 24)
  }
}

///|
fn decode_webp(data : Bytes) -> @skia.Pixmap? {
  let image = @codecs.decode_webp(data) catch { _ => return None }
  guard @skia.Pixmap::new(
      image.width.reinterpret_as_uint(),
      image.height.reinterpret_as_uint(),
    )
    is Some(pixmap) else {
    return None
  }
  if image.has_alpha {
    rgba_to_pixmap(image.data, pixmap)
  } else {
    rgb_to_pixmap(image.data, pixmap)
  }
  Some(pixmap)
}

///|
fn render_raster(
  image : @usvg.ImageKind,
  transform : @path.Transform,
  rendering_mode : @usvg.ImageRendering,
  pixmap : @skia.Pixmap,
) -> Unit? {
  guard decode_raster(image) is Some(raster) else { return None }
  guard @path.Size::from_wh(
      i32_to_f32(raster.width()),
      i32_to_f32(raster.height()),
    )
    is Some(size) else {
    return None
  }
  guard size.to_rect(0.0, 0.0) is Some(rect) else { return None }
  let quality : @skia.FilterQuality = match rendering_mode {
    OptimizeQuality => Bicubic
    OptimizeSpeed => Nearest
    Smooth => Bilinear
    HighQuality => Bicubic
    CrispEdges => Nearest
    Pixelated => Nearest
  }
  let pattern = @skia.Pattern::new(
    raster,
    Pad,
    quality,
    1.0,
    @path.Transform::default(),
  )
  let paint = @skia.Paint::default()
  paint.shader = pattern
  pixmap.fill_rect(rect, paint, transform, None)
  Some(())
}
