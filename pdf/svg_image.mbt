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
    GIF(d) => {
      guard svg_gif_image(d) is Some(image) else { return None }
      surface.draw_image(image, size)
    }
    WEBP(d) => {
      guard svg_webp_image(d) is Some(image) else { return None }
      surface.draw_image(image, size)
    }
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
/// krilla `Image::from_png(data, false)`: PNGs that allow it are embedded as
/// is (`PngData`), others are decoded with the `EXPAND` transformation.
///
/// TODO: krilla decodes lazily and reports decoding errors (after valid
/// metadata) when writing the PDF ("failed to process image"); such images
/// are skipped here. Deviation: 16-bit images are reduced to 8 bits (krilla
/// keeps 16 bits per component).
fn svg_png_image(data : Bytes) -> @export.Image? {
  // `png_metadata`.
  let info = @codecs.read_png_info(data[:]) catch { _ => return None }
  let width = info.width.reinterpret_as_int()
  let height = info.height.reinterpret_as_int()
  let key = bytes_key(data)
  if PngData::new(data[:]) is Some(png) {
    let colorspace : @export.ImageColorspace = match png.color_type {
      Grayscale => Luma
      _ => Rgb
    }
    return Some({
      key,
      width,
      height,
      colorspace,
      data: Png(png.idat, png.color_type.samples(), png.bit_depth, png.palette),
      icc: info.icc_profile,
      interpolate: false,
      inverted_cmyk: false,
    })
  }
  let (info, pixels) = @codecs.decode_png(data[:]) catch { _ => return None }
  Some(krilla_sampled(key, width, height, info.color, pixels, info.icc))
}

///|
/// krilla `Image::from_gif(data, false)`: the first frame, decoded to RGBA
/// with the `gif` crate. The size comes from the logical screen
/// (`imagesize`), like in krilla.
///
/// TODO: decoding errors are skipped (see `svg_png_image`).
fn svg_gif_image(data : Bytes) -> @export.Image? {
  // `gif_metadata`: `imagesize::blob_size`.
  if data.length() < 10 || data[0:4] != b"GIF8" {
    return None
  }
  let width = data[6].to_int() | (data[7].to_int() << 8)
  let height = data[8].to_int() | (data[9].to_int() << 8)
  // `decode_gif`.
  let first_frame = @codecs.decode_gif_first_frame(data[:]) catch {
    _ => return None
  }
  guard first_frame is Some(frame) else { return None }
  Some(krilla_sampled(bytes_key(data), width, height, Rgba8, frame.rgba, None))
}

///|
/// krilla `Image::from_webp(data, false)`: decoded with `image-webp`.
///
/// TODO: decoding errors are skipped (see `svg_png_image`).
fn svg_webp_image(data : Bytes) -> @export.Image? {
  let (info, pixels) = @codecs.decode_webp_image(data[:]) catch {
    _ => return None
  }
  Some(
    krilla_sampled(
      bytes_key(data),
      info.width.reinterpret_as_int(),
      info.height.reinterpret_as_int(),
      info.color,
      pixels,
      info.icc,
    ),
  )
}

///|
/// Decoded pixels as krilla embeds them (`handle_u8_image`/
/// `handle_u16_image`): the color channels and, for 8-bit images, an alpha
/// channel only if some pixel is not fully opaque.
///
/// Deviation: 16-bit samples are reduced to 8 bits.
fn krilla_sampled(
  key : String,
  width : Int,
  height : Int,
  color : @codecs.ColorType,
  buf : Bytes,
  icc : Bytes?,
) -> @export.Image {
  let channels = color.channel_count()
  let sixteen = color is (L16 | La16 | Rgb16 | Rgba16)
  let has_alpha = color is (La8 | Rgba8 | La16 | Rgba16)
  let color_channels = if channels >= 3 { 3 } else { 1 }
  let bpc = if sixteen { 2 } else { 1 }
  let sample = (i : Int) => {
    if sixteen {
      u16_to_u8(buf[i].to_int() | (buf[i + 1].to_int() << 8))
    } else {
      buf[i]
    }
  }
  // All pixels of the buffer (for GIFs, those of the first frame, whose size
  // may differ from the logical screen's).
  let n = buf.length() / (channels * bpc)
  let color_buf = FixedArray::make(n * color_channels, b'\x00')
  let alpha_buf = FixedArray::make(if has_alpha { n } else { 0 }, b'\x00')
  let mut all_opaque = true
  for p in 0..<n {
    let base = p * channels * bpc
    for c in 0..<color_channels {
      color_buf[p * color_channels + c] = sample(base + c * bpc)
    }
    if has_alpha {
      let a = sample(base + (channels - 1) * bpc)
      alpha_buf[p] = a
      all_opaque = all_opaque && a == b'\xFF'
    }
  }
  let alpha = if has_alpha && (sixteen || !all_opaque) {
    Some(Bytes::from_array(alpha_buf))
  } else {
    None
  }
  {
    key,
    width,
    height,
    colorspace: if channels >= 3 {
      Rgb
    } else {
      Luma
    },
    data: Samples(Bytes::from_array(color_buf), alpha),
    icc: if sixteen {
      None
    } else {
      icc
    },
    interpolate: false,
    inverted_cmyk: false,
  }
}
