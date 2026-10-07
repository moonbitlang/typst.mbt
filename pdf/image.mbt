// Port of `typst-pdf/src/image.rs`.
//
// SVG images are drawn with the port of `krilla-svg` (`svg*.mbt`); PDF
// images are embedded as form XObjects extracted with the port of
// `hayro-write` (`hayro/write`), like krilla's `draw_pdf_page`.

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
        Err(err) => {
          surface.pop()
          raise @library.SourceError([
            @library.SourceDiagnostic::error_at(
              span,
              "failed to process image (\{err})",
            ),
          ])
        }
      }
      surface.pop()
    }
    Svg(svg) =>
      if to_export_size(size) is Some(size) {
        draw_svg(
          surface,
          svg.tree(),
          size,
          { ..SvgSettings::default(), embed_text: true, },
          gc.svg_fonts,
        )
        |> ignore
      }
    Pdf(pdf) =>
      if to_export_size(size) is Some(size) {
        draw_pdf_page(gc, surface, pdf, size, span)
      }
  }
  if started {
    surface.end_tagged()
  }
  surface.pop()
  surface.reset_location()
}

///|
/// Draw a page of a PDF (krilla's `Surface::draw_pdf_page`; the page is
/// extracted with the port of `hayro-write`).
fn draw_pdf_page(
  gc : GlobalContext,
  surface : @export.Surface,
  image : @library.PdfImage,
  size : @export.Size,
  span : @syntax.Span,
) -> Unit raise @library.SourceError {
  let document = image.document()
  let pdf = document.pdf()
  let page_idx = image.page_index()
  let doc_key = bytes_key(document.data())

  // krilla checks the version when serializing the embedded document.
  let pdf_version = convert_hayro_pdf_version(pdf.version())
  if gc.options.version() < pdf_version {
    let embedded = pdf_version.as_str()
    let target = gc.options.version().as_str()
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        span, "the version of the PDF is too high",
      ).with_hints([
        "the current export target is \{target}, while the PDF has version \{embedded}",
        "raise the export target to \{embedded} or higher",
        "or preprocess the PDF to convert it to a lower version",
      ]),
    ])
  }

  // If the user provided an invalid page index, we will detect this later on anyway, so
  // just use dummy dimensions here.
  let (page_width, page_height) = match pdf.pages().get(page_idx) {
    Some(p) => p.render_dimensions()
    None => (Float::from_int(1), Float::from_int(1))
  }
  let page_width = page_width.to_double()
  let page_height = page_height.to_double()
  let transform = @export.Transform::from_scale(
    size.width / page_width,
    size.height / page_height,
  )
  // We applied a transform to invert the y-axis initially, but since the embedded PDF also uses
  // a y-up coordinate system, we need to "invert" this.
  surface.push_transform(transform)
  surface.push_transform(
    @export.Transform::from_row(1.0, 0.0, 0.0, -1.0, 0.0, page_height),
  )
  surface.draw_external_xobject({
    key: "\{doc_key}:\{page_idx}",
    bbox: @export.Rect::from_xywh(0.0, 0.0, page_width, page_height).unwrap(),
    write: (root, new_ref, put) => {
      // All pages of a document share one extraction context, so that
      // shared objects are written once (like krilla, which extracts all
      // queries of a document together).
      let ctx = match gc.pdf_extractions.get(doc_key) {
        Some(ctx) => ctx
        None => {
          let ctx = @hayro_write.ExtractionContext::new(
            pdf,
            new_ref,
            put,
            page_tree_parent_ref=surface.page_tree_ref(),
          )
          gc.pdf_extractions[doc_key] = ctx
          ctx
        }
      }
      ctx.extract_query_into(
        @hayro_write.ExtractionQuery::new_xobject(page_idx),
        root,
      )
      |> ignore
      ctx.write_dependencies()
    },
  })
  surface.pop()
  surface.pop()
}

///|
fn convert_hayro_pdf_version(
  version : @hayro_syntax.PdfVersion,
) -> @export.PdfVersion {
  match version {
    // Those are obviously not right, but we don't support versions lower than 1.4 in krilla.
    // Since we only need this conversion to detect version mismatches (in which case the
    // version of the embedded PDF has to be higher than 1.4), this hack is sufficient for our
    // purposes.
    Pdf10 | Pdf11 | Pdf12 | Pdf13 | Pdf14 => Pdf14
    Pdf15 => Pdf15
    Pdf16 => Pdf16
    Pdf17 => Pdf17
    Pdf20 => Pdf20
  }
}

///|
/// A key identifying image data.
fn bytes_key(data : Bytes) -> String {
  // FNV-1a over the data.
  let mut h = 0xcbf29ce484222325UL
  for b in data {
    h = (h ^ b.to_uint64()) * 0x100000001b3UL
  }
  "\{data.length()}:\{h}"
}

///|
/// The converted raster images (upstream `#[comemo::memoize]` on
/// `convert_raster`), see [convert_raster].
let raster_cache : @library.ContentCache[Result[@export.Image, String]] = @library.ContentCache::new()

///|
/// Convert a raster image.
///
/// Upstream's function is `#[comemo::memoize]`d: the lookup is here, the
/// function is [convert_raster_impl]. The key is what upstream hashes, the
/// two arguments: the image (`Hash for RasterImage`: its data, format and
/// ICC profile, [@library.RasterImage::hash128]) and `interpolate`. Like
/// comemo it keeps the `Result`. The converted image is immutable and
/// shared by its occurrences, like krilla's (`Arc<ImageRepr>`); what
/// belongs to an occurrence (the transform, the tag, the location, the
/// span of an error) stays in [handle_image].
///
/// Kept beyond the export (`library/memo_content.mbt`): an image that is on
/// many pages, or in the next export of `typst watch`, is converted once.
/// The exporter still writes it once per document and compresses it for
/// each (krilla keeps the compressed stream in its image).
fn convert_raster(
  raster : @library.RasterImage,
  interpolate : Bool,
) -> Result[@export.Image, String] {
  if !@library.content_memo_enabled() {
    return convert_raster_impl(raster, interpolate)
  }
  let state = @library.SipHasher128::new()
  state.write_u128(raster.hash128())
  state.write_bool(interpolate)
  let key = state.finish128()
  match raster_cache.get(key) {
    Some(result) => result
    None => {
      let result = convert_raster_impl(raster, interpolate)
      raster_cache.insert(key, result)
      result
    }
  }
}

///|
/// Upstream `convert_raster`.
///
/// The exporter embeds images with one key once, as krilla embeds images
/// with one hash once (`ImageRepr.sip`). The key is krilla's: for a JPEG,
/// which is embedded as it is, the data alone (`from_jpeg_with_icc`: the
/// same file inside an SVG is the same image); for the others the image
/// (`from_custom`: the hash of the `PdfRasterImage`, which is the raster
/// image's: the same data in another pixel format or with another profile
/// is another image).
fn convert_raster_impl(
  raster : @library.RasterImage,
  interpolate : Bool,
) -> Result[@export.Image, String] {
  let width = raster.width().reinterpret_as_int()
  let height = raster.height().reinterpret_as_int()
  if raster.format() == Exchange(Jpg) {
    return Ok(
      convert_jpeg(
        bytes_key(raster.data()),
        raster.data(),
        width,
        height,
        raster.icc(),
        interpolate,
      ),
    )
  }
  let key = "\{raster.hash128()}"
  let dynamic = raster.dynamic()
  // The ICC profile is only kept for 8-bit images that are used as is.
  convert_samples(
    key,
    width,
    height,
    dynamic.color,
    dynamic.buf,
    raster.icc(),
    interpolate,
  )
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

///|
/// Convert decoded pixels into an image (upstream `PdfRasterImage`: the
/// color channels as 8-bit luma or RGB, the alpha channel if the image has
/// one, and the ICC profile for 8-bit images).
fn convert_samples(
  key : String,
  width : Int,
  height : Int,
  color : @codecs.ColorType,
  buf : Bytes,
  icc : Bytes?,
  interpolate : Bool,
) -> Result[@export.Image, String] {
  let channels = color.channel_count()
  let sixteen = color is (L16 | La16 | Rgb16 | Rgba16)
  let has_alpha = color is (La8 | Rgba8 | La16 | Rgba16)
  let has_color = channels >= 3
  let bpc = if sixteen { 2 } else { 1 }
  let n = width * height
  if buf.length() < n * channels * bpc {
    return Err("image data is truncated")
  }
  let color_channels = if has_color { 3 } else { 1 }
  // Every read below is of `buf[i]` with `i < n * channels * bpc`, which is
  // at most `buf.length()`; every write is inside its buffer of
  // `n * color_channels` or `n` bytes.
  let color_data = if color is (L8 | Rgb8) && buf.length() == n * channels {
    // Pure luma8 or rgb8 image, can use it directly.
    buf
  } else {
    let out = FixedArray::make(n * color_channels, b'\x00')
    if sixteen {
      // Little-endian 16-bit samples are converted like `to_rgb8`.
      let stride = channels * 2
      for p in 0..<n {
        let base = p * stride
        for c in 0..<color_channels {
          let i = base + c * 2
          out.unsafe_set(
            p * color_channels + c,
            u16_to_u8(
              buf.unsafe_get(i).to_int() | (buf.unsafe_get(i + 1).to_int() << 8),
            ),
          )
        }
      }
    } else {
      for p in 0..<n {
        let base = p * channels
        for c in 0..<color_channels {
          out.unsafe_set(p * color_channels + c, buf.unsafe_get(base + c))
        }
      }
    }
    out.unsafe_reinterpret_as_bytes()
  }
  let alpha_data = if has_alpha {
    let out = FixedArray::make(n, b'\x00')
    if sixteen {
      let stride = channels * 2
      for p in 0..<n {
        let i = p * stride + (channels - 1) * 2
        out.unsafe_set(
          p,
          u16_to_u8(
            buf.unsafe_get(i).to_int() | (buf.unsafe_get(i + 1).to_int() << 8),
          ),
        )
      }
    } else {
      for p in 0..<n {
        out.unsafe_set(p, buf.unsafe_get(p * channels + channels - 1))
      }
    }
    Some(out.unsafe_reinterpret_as_bytes())
  } else {
    None
  }
  let icc = if sixteen { None } else { icc }
  Ok({
    key,
    width,
    height,
    colorspace: if has_color {
      Rgb
    } else {
      Luma
    },
    data: Samples(color_data, alpha_data),
    icc,
    interpolate,
    inverted_cmyk: false,
  })
}

///|
/// Embed a JPEG image as is.
fn convert_jpeg(
  key : String,
  data : Bytes,
  width : Int,
  height : Int,
  icc : Bytes?,
  interpolate : Bool,
) -> @export.Image {
  let (components, adobe, dims) = jpeg_components(data)
  // The image is embedded as is, so use the dimensions of the frame (the
  // raster's dimensions have the EXIF orientation applied).
  let (width, height) = dims.unwrap_or((width, height))
  let colorspace : @export.ImageColorspace = match components {
    1 => Luma
    4 => Cmyk
    _ => Rgb
  }
  {
    key,
    width,
    height,
    colorspace,
    data: Jpeg(data),
    icc,
    interpolate,
    inverted_cmyk: adobe,
  }
}

///|
/// Converts a 16-bit sample to 8 bits (upstream `image`'s
/// `FromPrimitive<u16> for u8`: `round(c * 255 / 65535)`).
fn u16_to_u8(c : Int) -> Byte {
  ((c + 128) / 257).to_byte()
}
