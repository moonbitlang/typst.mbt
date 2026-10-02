// Port of `hayro-svg/src/image.rs`.

///|
/// A decoded 8-bit image (the subset of `image::DynamicImage` hayro-svg uses).
priv struct DynamicImage {
  color : @codecs.PngColorType
  width : Int
  height : Int
  data : Bytes
}

///|
fn SvgRenderer::draw_rgba_image(
  self : SvgRenderer,
  image_data : @interpret.ImageData,
  transform : @kurbo.Affine,
  alpha : @interpret.LumaData?,
) -> Unit {
  let (rgb_data, width, height, interpolate) = match image_data {
    Rgb(rgb) => (rgb.data, rgb.width, rgb.height, rgb.interpolate)
    // TODO: Store as gray-scale.
    Luma(luma) => {
      let rgb = FixedArray::make(luma.data.length() * 3, b'\x00')
      for i, g in luma.data {
        rgb[i * 3] = g
        rgb[i * 3 + 1] = g
        rgb[i * 3 + 2] = g
      }
      (Bytes::from_array(rgb), luma.width, luma.height, luma.interpolate)
    }
  }
  if alpha is Some(alpha) {
    if alpha.interpolate == interpolate &&
      alpha.width == width &&
      alpha.height == height {
      let n = @cmp.minimum(rgb_data.length() / 3, alpha.data.length())
      let interleaved = FixedArray::make(n * 4, b'\x00')
      for p in 0..<n {
        interleaved[p * 4] = rgb_data[p * 3]
        interleaved[p * 4 + 1] = rgb_data[p * 3 + 1]
        interleaved[p * 4 + 2] = rgb_data[p * 3 + 2]
        interleaved[p * 4 + 3] = alpha.data[p]
      }
      let image = image_from_raw(
        Rgba,
        width,
        height,
        Bytes::from_array(interleaved),
      )
      self.write_image(image, interpolate, None, transform)
    } else {
      let image = image_from_raw(Rgb, width, height, rgb_data)
      let alpha = {
        let image = image_from_raw(
          Grayscale,
          alpha.width,
          alpha.height,
          alpha.data,
        )
        let transform = transform *
          @kurbo.Affine::scale_non_uniform(
            width.to_double() / alpha.width.to_double(),
            height.to_double() / alpha.height.to_double(),
          )
        { image, transform, interpolate: alpha.interpolate, }
      }
      self.push_transparency_group_inner(
        1.0,
        Some(MaskKind::Image(alpha)),
        Normal,
      )
      self.write_image(image, interpolate, None, transform)
      self.pop_transparency_group_impl()
    }
  } else {
    let image = image_from_raw(Rgb, width, height, rgb_data)
    self.write_image(image, interpolate, None, transform)
  }
}

///|
/// `ImageBuffer::from_raw(...).unwrap()`: the buffer must be large enough.
fn image_from_raw(
  color : @codecs.PngColorType,
  width : Int,
  height : Int,
  data : Bytes,
) -> DynamicImage {
  let channels = match color {
    Grayscale => 1
    GrayscaleAlpha => 2
    Rgb => 3
    Rgba => 4
    _ => abort("unsupported color type")
  }
  let len = width * height * channels
  guard data.length() >= len else {
    abort("called `Option::unwrap()` on a `None` value")
  }
  // `from_raw` keeps the whole buffer, but only the first `len` bytes are
  // part of the image.
  { color, width, height, data: data[0:len].to_bytes(), }
}

///|
fn SvgRenderer::draw_stencil_image(
  self : SvgRenderer,
  stencil : @interpret.LumaData,
  transform : @kurbo.Affine,
  paint : @interpret.Paint,
) -> Unit {
  let interpolate = stencil.interpolate
  match paint {
    Color(c) => {
      let color = c.to_rgba().to_rgba8()
      let image = FixedArray::make(stencil.data.length() * 4, b'\x00')
      for i, d in stencil.data {
        if d == 255 {
          image[i * 4] = color[0]
          image[i * 4 + 1] = color[1]
          image[i * 4 + 2] = color[2]
          image[i * 4 + 3] = color[3]
        }
      }
      let image = image_from_raw(
        Rgba,
        stencil.width,
        stencil.height,
        Bytes::from_array(image),
      )
      self.write_image(image, interpolate, None, transform)
    }
    Pattern(_) => {
      let mask = {
        let image = image_from_raw(
          Grayscale,
          stencil.width,
          stencil.height,
          stencil.data,
        )
        { image, transform, interpolate, }
      }
      self.push_transparency_group_inner(
        1.0,
        Some(MaskKind::Image(mask)),
        Normal,
      )
      self.draw_path_impl(
        @kurbo.Rect::new(
          0.0,
          0.0,
          stencil.width.to_double(),
          stencil.height.to_double(),
        ).to_path(0.1),
        { transform, paint, soft_mask: None, blend_mode: Normal, },
        Fill(NonZero),
      )
      self.pop_transparency_group_impl()
    }
  }
}

///|
fn SvgRenderer::write_image(
  self : SvgRenderer,
  image : DynamicImage,
  interpolate : Bool,
  id : Id?,
  transform : @kurbo.Affine,
) -> Unit {
  let scaling = if interpolate { "smooth" } else { "pixelated" }
  let base64 = to_base64(image)
  self.xml.start_element("image")
  if id is Some(id) {
    self.xml.write_attribute("id", id.to_string())
  }
  self.write_transform(transform)
  self.xml.write_attribute("xlink:href", base64)
  self.xml.write_attribute("width", image.width.to_string())
  self.xml.write_attribute("height", image.height.to_string())
  self.xml.write_attribute("preserveAspectRatio", "none")
  self.xml.write_attribute("style", "image-rendering: \{scaling}")
  self.xml.end_element()
}

///|
fn to_base64(image : DynamicImage) -> String {
  let png = @codecs.encode_png(
    image.data[:],
    image.width,
    image.height,
    image.color,
  )
  "data:image/png;base64," + @base64.encode(png[:])
}
