// Port of `typst-pdf/src/image.rs`.
//
// TODO: SVG images (upstream draws them with `krilla-svg`) and PDF images
// (embedded pages) are not ported yet; they are skipped. GIF and WebP
// images are not decoded by the library yet and are skipped as well.

///|
fn handle_image(
  gc : GlobalContext,
  fc : FrameContext,
  image : @library.Image,
  size : @library.Axes[@library.Abs],
  surface : @export.Surface,
  span : @syntax.Span,
) -> Unit raise @library.SourceError {
  surface.push_transform(to_export_transform(fc.state().transform))
  surface.set_location(span.0)
  let interpolate = image.scaling() == Custom(Smooth)
  gc.image_spans[span] = ()
  let started = tags_image(gc, fc, surface, image, size)
  match image.kind() {
    Raster(raster) => {
      let (exif_transform, new_size) = exif_transform(raster, size)
      surface.push_transform(to_export_transform(exif_transform))
      match convert_raster(raster, interpolate) {
        Ok(image) => {
          if !gc.image_to_spans.contains(image.key) {
            gc.image_to_spans[image.key] = span
          }
          if to_export_size(new_size) is Some(size) {
            surface.draw_image(image, size)
          }
        }
        Err(Some(err)) => {
          surface.pop()
          raise @library.SourceError([
            @library.SourceDiagnostic::error_at(
              span,
              "failed to process image (\{err})",
            ),
          ])
        }
        Err(None) => ()
      }
      surface.pop()
    }
    Svg(_) | Pdf(_) => ()
  }
  if started {
    surface.end_tagged()
  }
  surface.pop()
  surface.reset_location()
}

///|
/// A key identifying the raster data of an image.
fn raster_key(raster : @library.RasterImage) -> String {
  let data = raster.data()
  // FNV-1a over the data.
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = (h ^ b.to_uint64()) * 0x100000001b3UL
  }
  "\{data.length()}:\{h}"
}

///|
/// Convert a raster image. `Err(None)` means the format cannot be embedded
/// yet.
fn convert_raster(
  raster : @library.RasterImage,
  interpolate : Bool,
) -> Result[@export.Image, String?] {
  let key = raster_key(raster)
  let width = raster.width().reinterpret_as_int()
  let height = raster.height().reinterpret_as_int()
  if raster.format() == Exchange(Jpg) {
    let (components, adobe, dims) = jpeg_components(raster.data())
    // The image is embedded as is, so use the dimensions of the frame (the
    // raster's dimensions have the EXIF orientation applied).
    let (width, height) = dims.unwrap_or((width, height))
    let colorspace : @export.ImageColorspace = match components {
      1 => Luma
      4 => Cmyk
      _ => Rgb
    }
    return Ok({
      key,
      width,
      height,
      colorspace,
      data: Jpeg(raster.data()),
      icc: raster.icc(),
      interpolate,
      inverted_cmyk: adobe,
    })
  }
  // The decoded pixels (decoding PNGs here if the image was not decoded).
  let (color, buf) : (@codecs.ColorType, Bytes) = match raster.dynamic() {
    Some(dynamic) => (dynamic.color, dynamic.buf)
    None =>
      if raster.format() == Exchange(Png) {
        let (info, pixels) = @codecs.decode_png(raster.data()[:]) catch {
          _ => return Err(Some("failed to decode PNG"))
        }
        (info.color, pixels)
      } else {
        return Err(None)
      }
  }
  let channels = color.channel_count()
  let sixteen = color is (L16 | La16 | Rgb16 | Rgba16)
  let has_alpha = color is (La8 | Rgba8 | La16 | Rgba16)
  let has_color = channels >= 3
  let bpc = if sixteen { 2 } else { 1 }
  let n = width * height
  if buf.length() < n * channels * bpc {
    return Err(Some("image data is truncated"))
  }
  let color_buf = Array::make(n * (if has_color { 3 } else { 1 }), b'\x00')
  let alpha_buf = Array::make(if has_alpha { n } else { 0 }, b'\x00')
  let color_channels = if has_color { 3 } else { 1 }
  for p in 0..<n {
    let base = p * channels * bpc
    for c in 0..<color_channels {
      // 16-bit samples are big-endian; keep the high byte.
      color_buf[p * color_channels + c] = buf[base + c * bpc]
    }
    if has_alpha {
      alpha_buf[p] = buf[base + (channels - 1) * bpc]
    }
  }
  // The ICC profile is only kept for 8-bit images that are used as is.
  let icc = if sixteen { None } else { raster.icc() }
  Ok({
    key,
    width,
    height,
    colorspace: if has_color {
      Rgb
    } else {
      Luma
    },
    data: Samples(
      Bytes::from_array(color_buf),
      if has_alpha {
        Some(Bytes::from_array(alpha_buf))
      } else {
        None
      },
    ),
    icc,
    interpolate,
    inverted_cmyk: false,
  })
}

///|
fn exif_transform(
  image : @library.RasterImage,
  size : @library.Axes[@library.Abs],
) -> (@library.Transform, @library.Axes[@library.Abs]) {
  // For JPEGs, we want to apply the EXIF orientation as a transformation
  // because we don't recode them. For other formats, the transform is
  // already baked into the dynamic image data.
  if image.format() != Exchange(Jpg) {
    return (@library.Transform::identity(), size)
  }
  let one = @library.Ratio::one()
  let neg = @library.Ratio::new(-1.0)
  let base = (
    hp : Bool,
    vp : Bool,
    base_ts : @library.Transform,
    size : @library.Axes[@library.Abs],
  ) => {
    let mut base_ts = base_ts
    if hp {
      // Flip horizontally in-place.
      base_ts = base_ts.pre_concat(
        @library.Transform::scale(neg, one).pre_concat(
          @library.Transform::translate(size.x.neg(), @library.Abs::zero()),
        ),
      )
    }
    if vp {
      // Flip vertically in-place.
      base_ts = base_ts.pre_concat(
        @library.Transform::scale(one, neg).pre_concat(
          @library.Transform::translate(@library.Abs::zero(), size.y.neg()),
        ),
      )
    }
    base_ts
  }
  let no_flipping = (hp : Bool, vp : Bool) => {
    (base(hp, vp, @library.Transform::identity(), size), size)
  }
  let with_flipping = (hp : Bool, vp : Bool) => {
    let base_ts = @library.Transform::rotate_at(
      @library.Angle::deg(90.0),
      @library.Abs::zero(),
      @library.Abs::zero(),
    ).pre_concat(@library.Transform::scale(one, neg))
    let inv_size = @library.Axes::new(size.y, size.x)
    (base(hp, vp, base_ts, inv_size), inv_size)
  }
  match image.exif_rotation() {
    Some(2) => no_flipping(true, false)
    Some(3) => no_flipping(true, true)
    Some(4) => no_flipping(false, true)
    Some(5) => with_flipping(false, false)
    Some(6) => with_flipping(false, true)
    Some(7) => with_flipping(true, true)
    Some(8) => with_flipping(true, false)
    _ => no_flipping(false, false)
  }
}

///|
/// The number of components of a JPEG image (from its frame header),
/// whether it has an Adobe `APP14` marker and the frame's width and height.
fn jpeg_components(data : Bytes) -> (Int, Bool, (Int, Int)?) {
  let mut i = 2
  let mut adobe = false
  while i + 4 <= data.length() {
    if data[i] != b'\xFF' {
      i += 1
      continue
    }
    let marker = data[i + 1].to_int()
    if marker == 0xFF {
      i += 1
      continue
    }
    if marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01 {
      i += 2
      continue
    }
    let len = (data[i + 2].to_int() << 8) | data[i + 3].to_int()
    if marker == 0xEE &&
      i + 9 <= data.length() &&
      data[i + 4] == b'A' &&
      data[i + 5] == b'd' &&
      data[i + 6] == b'o' &&
      data[i + 7] == b'b' &&
      data[i + 8] == b'e' {
      adobe = true
    }
    // SOF markers (except DHT, JPG and DAC).
    if marker >= 0xC0 &&
      marker <= 0xCF &&
      marker != 0xC4 &&
      marker != 0xC8 &&
      marker != 0xCC {
      if i + 9 < data.length() {
        let height = (data[i + 5].to_int() << 8) | data[i + 6].to_int()
        let width = (data[i + 7].to_int() << 8) | data[i + 8].to_int()
        return (data[i + 9].to_int(), adobe, Some((width, height)))
      }
      return (3, adobe, None)
    }
    if marker == 0xDA {
      break
    }
    i += 2 + len
  }
  (3, adobe, None)
}
