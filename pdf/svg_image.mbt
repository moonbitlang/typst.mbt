// Port of `krilla-svg/src/image.rs`.

///|
/// Render an image into a surface.
///
/// Returns `None` if the image could not be rendered.
fn svg_image_render(
  image : @usvg.Image,
  surface : @export.Surface,
  process_context : SvgProcessContext,
) -> Unit? {
  if !image.is_visible() {
    return Some(())
  }
  let size = @export.Size::from_wh(
    image.size().width().to_double(),
    image.size().height().to_double(),
  ).unwrap()
  match image.kind() {
    JPEG(d) => {
      guard svg_jpeg_image(d) is Some(image) else { return None }
      surface.draw_image(image, size)
    }
    PNG(d) => {
      guard svg_png_image(d) is Some(image) else { return None }
      surface.draw_image(image, size)
    }
    // TODO: GIF and WebP images (krilla `Image::from_gif`/`from_webp`) are
    // skipped: there is no GIF/WebP decoder yet.
    GIF(_) | WEBP(_) => return None
    SVG(t) => {
      guard @export.Rect::from_xywh(
          0.0,
          0.0,
          t.size().width().to_double(),
          t.size().height().to_double(),
        )
        is Some(rect) else {
        return None
      }
      let clip_path = svg_rect_to_clip_path(rect)
      surface.push_clip_path(clip_path, NonZero)
      svg_group_render(t.root(), surface, process_context)
      surface.pop()
    }
  }
  Some(())
}

///|
/// krilla `Image::from_jpeg(data, false)`.
fn svg_jpeg_image(data : Bytes) -> @export.Image? {
  let info = @codecs.jpeg_image_info(data[:]) catch { _ => return None }
  Some(
    convert_jpeg(
      bytes_key(data),
      data,
      info.width.reinterpret_as_int(),
      info.height.reinterpret_as_int(),
      info.icc,
      false,
    ),
  )
}

///|
/// krilla `Image::from_png(data, false)`.
///
/// Deviation: 16-bit images are reduced to 8 bits (krilla keeps 16 bits per
/// component).
fn svg_png_image(data : Bytes) -> @export.Image? {
  let (info, pixels) = @codecs.decode_png(data[:]) catch { _ => return None }
  convert_samples(
    bytes_key(data),
    info.width.reinterpret_as_int(),
    info.height.reinterpret_as_int(),
    info.color,
    pixels,
    info.icc,
    false,
  ).to_option()
}
