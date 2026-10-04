// Port of `hayro/src/renderer.rs`: the `Device` drawing PDF content with
// vello_cpu.

///|
priv struct Renderer {
  ctx : @vello_cpu.RenderContext
  inside_pattern : Bool
  soft_mask_cache : Map[@interpret.U128, @vello_cpu.Mask]
  outline_cache : Map[@interpret.U128, @kurbo.BezPath]
  mut in_type3_glyph : Bool
}

///|
priv enum ImagePixelFormat {
  Luma
  Rgb
  Rgba
}

///|
priv struct SolidColorImage {
  color : FixedArray[Byte]
  width : Int
  height : Int
  interpolate : Bool
}

///|
priv enum RenderImageData {
  Rgb(@interpret.RgbData)
  Luma(@interpret.LumaData)
  Solid(SolidColorImage)
}

///|
fn RenderImageData::from_image_data(
  value : @interpret.ImageData,
) -> RenderImageData {
  match value {
    Rgb(rgb) => Rgb(rgb)
    Luma(luma) => Luma(luma)
  }
}

///|
fn RenderImageData::width(self : RenderImageData) -> Int {
  match self {
    Rgb(d) => d.width
    Luma(d) => d.width
    Solid(d) => d.width
  }
}

///|
fn RenderImageData::height(self : RenderImageData) -> Int {
  match self {
    Rgb(d) => d.height
    Luma(d) => d.height
    Solid(d) => d.height
  }
}

///|
fn RenderImageData::interpolate(self : RenderImageData) -> Bool {
  match self {
    Rgb(d) => d.interpolate
    Luma(d) => d.interpolate
    Solid(d) => d.interpolate
  }
}

///|
fn Renderer::new(
  width : Int,
  height : Int,
  outline_cache : Map[@interpret.U128, @kurbo.BezPath],
) -> Renderer {
  {
    ctx: @vello_cpu.RenderContext::new(width, height),
    inside_pattern: false,
    soft_mask_cache: {},
    outline_cache,
    in_type3_glyph: false,
  }
}

///|
/// Rust's `f32::max`.
fn fmaxnm(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_int() < 0 {
    b
  } else {
    a
  }
}

///|
/// Rust's `f32::min`.
fn fminnm(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_int() < 0 {
    a
  } else {
    b
  }
}

///|
fn Renderer::set_stroke_properties(
  self : Renderer,
  stroke_props : @interpret.StrokeProps,
  is_text : Bool,
) -> Unit {
  let threshold : Float = if is_text { 0.25 } else { 1.0 }
  // Best-effort attempt to ensure a line width of at least 1.0, as required
  // by the PDF specification. If we are stroking text, we reduce the
  // threshold as it will otherwise lead to very bold-looking text at low
  // resolutions.
  let min_factor = max_factor(self.ctx.transform())
  let mut line_width = fmaxnm(stroke_props.line_width, 0.01)
  let transformed_width = line_width * min_factor
  // Only enforce line width if not inside of pattern or type 3 glyph.
  if transformed_width < threshold &&
    !self.inside_pattern &&
    !self.in_type3_glyph {
    line_width = line_width / transformed_width
    line_width = line_width * threshold
  }
  let stroke : @kurbo.Stroke = {
    width: line_width.to_double(),
    join: stroke_props.line_join,
    miter_limit: stroke_props.miter_limit.to_double(),
    start_cap: stroke_props.line_cap,
    end_cap: stroke_props.line_cap,
    dash_pattern: stroke_props.dash_array.map(n => n.to_double()),
    dash_offset: stroke_props.dash_offset.to_double(),
  }
  self.ctx.set_stroke(stroke)
}

///|
fn Renderer::draw_image_with_alpha_mask(
  self : Renderer,
  image_data : RenderImageData,
  alpha_data : @interpret.LumaData,
) -> Unit {
  let mask = {
    let transform = self.ctx.transform() *
      @kurbo.Affine::scale_non_uniform(
        image_data.width().to_double() / alpha_data.width.to_double(),
        image_data.height().to_double() / alpha_data.height.to_double(),
      )
    let renderer = Renderer::new(
      self.ctx.width(),
      self.ctx.height(),
      self.outline_cache,
    )
    let mask_pix = @vello_cpu.Pixmap::new(self.ctx.width(), self.ctx.height())
    let rgb_data = @interpret.ImageData::Rgb({
      data: Bytes::make(alpha_data.width * alpha_data.height * 3, b'\x00'),
      width: alpha_data.width,
      height: alpha_data.height,
      interpolate: alpha_data.interpolate,
      scale_factors: alpha_data.scale_factors,
    })
    renderer.ctx.set_transform(transform)
    // Note that there is a circle between `draw_image` and
    // `draw_image_with_alpha_mask`, but `draw_image_with_alpha_mask` is only
    // called if the dimensions or interpolate values between alpha_data and
    // rgb_data don't match, which they do here.
    renderer.draw_image_impl(
      RenderImageData::from_image_data(rgb_data),
      Some(alpha_data),
    )
    renderer.ctx.flush()
    renderer.ctx.render(mask_pix)
    @vello_cpu.Mask::new_alpha(mask_pix)
  }
  self.ctx.push_mask_layer(mask)
  self.draw_image_impl(image_data, None)
  self.ctx.pop_layer()
}

///|
fn resize_image_data(
  data : Bytes,
  src_width : Int,
  src_height : Int,
  new_width : Int,
  new_height : Int,
  pixel_format : ImagePixelFormat,
) -> Bytes {
  match pixel_format {
    Luma =>
      @pic_scale.resize_planar_u8(
        data, src_width, src_height, new_width, new_height,
      )
    Rgb =>
      @pic_scale.resize_rgb_u8(
        data, src_width, src_height, new_width, new_height,
      )
    Rgba =>
      @pic_scale.resize_rgba_u8_premultiplied(
        data, src_width, src_height, new_width, new_height,
      )
  }
}

///|
/// `AlphaColor::from_rgba8(r, g, b, a).premultiply().to_rgba8()`, cached for
/// every `(component, alpha)` pair (built on first use: computing it at
/// startup took more than half of the CLI's initialization).
let premul_table_cell : Ref[FixedArray[Byte]?] = { val: None, }

///|
fn premul_table() -> FixedArray[Byte] {
  if premul_table_cell.val is Some(table) {
    return table
  }
  let table = FixedArray::make(256 * 256, b'\x00')
  for a in 0..<256 {
    for v in 0..<256 {
      let c = @vello_cpu.AlphaColor::from_rgba8(v, v, v, a)
      let p = @vello_cpu.components_to_rgba8(c.premultiply())
      table[a * 256 + v] = p[0].to_byte()
    }
  }
  premul_table_cell.val = Some(table)
  table
}

///|
/// The alpha channel of `AlphaColor::from_rgba8(..).premultiply().to_rgba8()`
/// (built on first use).
let premul_alpha_table_cell : Ref[FixedArray[Byte]?] = { val: None, }

///|
fn premul_alpha_table() -> FixedArray[Byte] {
  if premul_alpha_table_cell.val is Some(table) {
    return table
  }
  let table = FixedArray::make(256, b'\x00')
  for a in 0..<256 {
    let c = @vello_cpu.AlphaColor::from_rgba8(0, 0, 0, a)
    table[a] = @vello_cpu.components_to_rgba8(c.premultiply())[3].to_byte()
  }
  premul_alpha_table_cell.val = Some(table)
  table
}

///|
fn Renderer::draw_image_impl(
  self : Renderer,
  image_data : RenderImageData,
  alpha_data : @interpret.LumaData?,
) -> Unit {
  let cur_transform = self.ctx.transform()
  let mut additional_transform = @kurbo.Affine::identity()
  let (x_scale, y_scale) = {
    let (x, y) = x_y_advances(cur_transform)
    (Float::from_double(x.hypot()), Float::from_double(y.hypot()))
  }
  let mut img_width = image_data.width()
  let mut img_height = image_data.height()
  let interpolate = image_data.interpolate()
  if alpha_data is Some(a) &&
    (
      a.width != img_width ||
      a.height != img_height ||
      a.interpolate != interpolate
    ) {
    return self.draw_image_with_alpha_mask(image_data, a)
  }
  let mut quality : @vello_cpu.ImageQuality = if interpolate {
    Medium
  } else {
    Low
  }
  let has_alpha = alpha_data is Some(_)
  let mut may_have_transparency = has_alpha
  let needs_resize = x_scale < 1.0 || y_scale < 1.0
  let (new_width, new_height) = if needs_resize {
    let w = f32_as_u32(
      fminnm(
        fmaxnm((Float::from_int(img_width) * x_scale).ceil(), 1.0),
        Float::from_int(65535 / 2),
      ),
    )
    let h = f32_as_u32(
      fminnm(
        fmaxnm((Float::from_int(img_height) * y_scale).ceil(), 1.0),
        Float::from_int(65535 / 2),
      ),
    )
    if self.in_type3_glyph {
      quality = High
    }
    (w, h)
  } else {
    (img_width, img_height)
  }
  let resize_transform = () => {
    @kurbo.Affine::scale_non_uniform(
      img_width.to_double() / new_width.to_double(),
      img_height.to_double() / new_height.to_double(),
    )
  }
  // For luma images without alpha, we can resize as single-channel and
  // expand to RGBA afterwards, which is ~4x faster.
  let mut rgba_data : FixedArray[Byte] = match (image_data, alpha_data) {
    (Solid(solid), Some(alpha)) => {
      let alpha_bytes = if !needs_resize {
        alpha.data
      } else {
        let resized_alpha = resize_image_data(
          alpha.data,
          img_width,
          img_height,
          new_width,
          new_height,
          Luma,
        )
        additional_transform = resize_transform()
        img_width = new_width
        img_height = new_height
        resized_alpha
      }
      let n = img_width * img_height
      let out = FixedArray::make(n * 4, b'\x00')
      for i in 0..<n {
        out[i * 4] = solid.color[0]
        out[i * 4 + 1] = solid.color[1]
        out[i * 4 + 2] = solid.color[2]
        out[i * 4 + 3] = alpha_bytes[i]
      }
      out
    }
    (Luma(luma), None) => {
      let luma_data = if !needs_resize {
        luma.data
      } else {
        let resized = resize_image_data(
          luma.data,
          img_width,
          img_height,
          new_width,
          new_height,
          Luma,
        )
        additional_transform = resize_transform()
        img_width = new_width
        img_height = new_height
        resized
      }
      let n = luma_data.length()
      let out = FixedArray::make(n * 4, b'\x00')
      for i in 0..<n {
        let g = luma_data[i]
        out[i * 4] = g
        out[i * 4 + 1] = g
        out[i * 4 + 2] = g
        out[i * 4 + 3] = b'\xFF'
      }
      out
    }
    (Luma(luma), Some(alpha)) => {
      let (luma_bytes, alpha_bytes) = if !needs_resize {
        (luma.data, alpha.data)
      } else {
        let resized_luma = resize_image_data(
          luma.data,
          img_width,
          img_height,
          new_width,
          new_height,
          Luma,
        )
        let resized_alpha = resize_image_data(
          alpha.data,
          img_width,
          img_height,
          new_width,
          new_height,
          Luma,
        )
        additional_transform = resize_transform()
        img_width = new_width
        img_height = new_height
        (resized_luma, resized_alpha)
      }
      let n = @cmp.minimum(luma_bytes.length(), alpha_bytes.length())
      let out = FixedArray::make(n * 4, b'\x00')
      for i in 0..<n {
        let g = luma_bytes[i]
        out[i * 4] = g
        out[i * 4 + 1] = g
        out[i * 4 + 2] = g
        out[i * 4 + 3] = alpha_bytes[i]
      }
      out
    }
    (Rgb(rgb), None) if needs_resize => {
      let resized = resize_image_data(
        rgb.data,
        img_width,
        img_height,
        new_width,
        new_height,
        Rgb,
      )
      additional_transform = resize_transform()
      img_width = new_width
      img_height = new_height
      let n = resized.length() / 3
      let out = FixedArray::make(n * 4, b'\x00')
      for i in 0..<n {
        out[i * 4] = resized[i * 3]
        out[i * 4 + 1] = resized[i * 3 + 1]
        out[i * 4 + 2] = resized[i * 3 + 2]
        out[i * 4 + 3] = b'\xFF'
      }
      out
    }
    (image_data, alpha_data) => {
      let rgb_data = match image_data {
        Rgb(rgb) => rgb.data
        Luma(luma) => {
          let rgb = FixedArray::make(luma.data.length() * 3, b'\x00')
          for i, g in luma.data {
            rgb[i * 3] = g
            rgb[i * 3 + 1] = g
            rgb[i * 3 + 2] = g
          }
          Bytes::from_array(rgb)
        }
        Solid(solid) => {
          let n = solid.width * solid.height
          let rgb = FixedArray::make(n * 3, b'\x00')
          for i in 0..<n {
            rgb[i * 3] = solid.color[0]
            rgb[i * 3 + 1] = solid.color[1]
            rgb[i * 3 + 2] = solid.color[2]
          }
          Bytes::from_array(rgb)
        }
      }
      let rgba_data = match alpha_data {
        None => {
          let n = rgb_data.length() / 3
          let out = FixedArray::make(n * 4, b'\x00')
          for i in 0..<n {
            out[i * 4] = rgb_data[i * 3]
            out[i * 4 + 1] = rgb_data[i * 3 + 1]
            out[i * 4 + 2] = rgb_data[i * 3 + 2]
            out[i * 4 + 3] = b'\xFF'
          }
          out
        }
        Some(alpha) => {
          let n = @cmp.minimum(rgb_data.length() / 3, alpha.data.length())
          let out = FixedArray::make(n * 4, b'\x00')
          for i in 0..<n {
            out[i * 4] = rgb_data[i * 3]
            out[i * 4 + 1] = rgb_data[i * 3 + 1]
            out[i * 4 + 2] = rgb_data[i * 3 + 2]
            out[i * 4 + 3] = alpha.data[i]
          }
          out
        }
      }
      if !needs_resize {
        rgba_data
      } else {
        let resized = resize_image_data(
          Bytes::from_array(rgba_data),
          img_width,
          img_height,
          new_width,
          new_height,
          Rgba,
        )
        additional_transform = resize_transform()
        img_width = new_width
        img_height = new_height
        let out = FixedArray::make(resized.length(), b'\x00')
        for i, b in resized {
          out[i] = b
        }
        out
      }
    }
  }
  if has_alpha {
    let n = rgba_data.length() / 4
    let premul_table = premul_table()
    let premul_alpha_table = premul_alpha_table()
    for i in 0..<n {
      let a = rgba_data[i * 4 + 3].to_int()
      let row = a * 256
      rgba_data[i * 4] = premul_table[row + rgba_data[i * 4].to_int()]
      rgba_data[i * 4 + 1] = premul_table[row + rgba_data[i * 4 + 1].to_int()]
      rgba_data[i * 4 + 2] = premul_table[row + rgba_data[i * 4 + 2].to_int()]
      rgba_data[i * 4 + 3] = premul_alpha_table[a]
    }
  }
  // The problem is that by default, when applying a bilinear or bicubic
  // scaling, we will sample pixels using an extend (pad/reflect/repeat). For
  // glyphs, this is undesirable as the glyphs will look very bold. Therefore,
  // for glyphs it is more desirable to sample a transparent pixel when
  // reaching the border. Thus, we wrap glyphs in a transparent frame of
  // pixel width 2.
  if self.in_type3_glyph {
    let new_w = img_width + 4
    let new_h = img_height + 4
    let padded_image = FixedArray::make(new_w * new_h * 4, b'\x00')
    for y in 0..<img_height {
      for x in 0..<(img_width * 4) {
        padded_image[((y + 2) * new_w + 2) * 4 + x] = rgba_data[y *
          img_width *
          4 +
          x]
      }
    }
    img_width = new_w
    img_height = new_h
    additional_transform = additional_transform *
      @kurbo.Affine::translate(-2.0, -2.0)
    may_have_transparency = true
    rgba_data = padded_image
  }
  let pixmap = @vello_cpu.Pixmap::from_parts_with_opacity(
    rgba_data,
    img_width & 0xFFFF,
    img_height & 0xFFFF,
    may_have_transparency,
  )
  self.draw_pixmap(pixmap, quality, cur_transform * additional_transform)
}

///|
/// `f32 as u32` (saturating).
fn f32_as_u32(x : Float) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
fn Renderer::push_clip_path_inner(
  self : Renderer,
  clip_path : @kurbo.BezPath,
  fill : @interpret.FillRule,
) -> Unit {
  let old_transform = self.ctx.transform()
  self.ctx.set_fill_rule(convert_fill_rule(fill))
  self.ctx.set_transform(@kurbo.Affine::identity())
  self.ctx.push_clip_path(clip_path)
  self.ctx.set_transform(old_transform)
}

///|
fn Renderer::draw_pixmap(
  self : Renderer,
  pixmap : @vello_cpu.Pixmap,
  quality : @vello_cpu.ImageQuality,
  transform : @kurbo.Affine,
) -> Unit {
  let width = pixmap.width()
  let height = pixmap.height()
  let image : @vello_cpu.Image = {
    image: Pixmap(pixmap),
    sampler: { x_extend: Pad, y_extend: Pad, quality, alpha: 1.0, },
  }
  self.ctx.set_transform(transform)
  self.ctx.set_paint(Image(image))
  self.ctx.fill_rect(
    @kurbo.Rect::new(0.0, 0.0, width.to_double(), height.to_double()),
  )
}

///|
fn Renderer::apply_soft_mask(
  self : Renderer,
  mask : @interpret.SoftMask?,
) -> Unit {
  match mask {
    Some(m) => {
      let mask = self.cached_soft_mask(m)
      self.ctx.set_mask(mask)
    }
    None => self.ctx.reset_mask()
  }
}

///|
fn Renderer::cached_soft_mask(
  self : Renderer,
  m : @interpret.SoftMask,
) -> @vello_cpu.Mask {
  let key = @interpret.CacheKey::cache_key(m)
  match self.soft_mask_cache.get(key) {
    Some(mask) => mask
    None => {
      let mask = draw_soft_mask(m, self.ctx.width(), self.ctx.height())
      self.soft_mask_cache[key] = mask
      mask
    }
  }
}

///|
fn Renderer::apply_draw_props(
  self : Renderer,
  props : @interpret.DrawProps,
) -> Unit {
  self.ctx.set_transform(props.transform)
  self.apply_soft_mask(props.soft_mask)
  self.ctx.set_blend_mode(convert_blend_mode(props.blend_mode))
}

///|
fn Renderer::apply_image_props(
  self : Renderer,
  props : @interpret.ImageDrawProps,
) -> Unit {
  self.ctx.set_transform(props.transform)
  self.apply_soft_mask(props.soft_mask)
  self.ctx.set_blend_mode(convert_blend_mode(props.blend_mode))
}

///|
const NATIVE_GRADIENT_TOLERANCE : Float = 0.01

///|
const MAX_PIXMAP_SIZE : Float = 3000.0

///|
const MIN_PIXMAP_SIZE : Float = 1.0

///|
/// Rust's `f32::round` (half away from zero).
fn roundf(x : Float) -> Float {
  let t = x.trunc()
  if (x - t).abs() >= 0.5 {
    t + (if x < 0.0 { -1.0 } else { 1.0 })
  } else {
    t
  }
}

///|
fn Renderer::set_paint(
  self : Renderer,
  paint : @interpret.Paint,
  path_bbox : () -> @kurbo.Rect,
  is_stroke : Bool,
) -> @kurbo.BezPath? {
  let mut paint_transform = @kurbo.Affine::identity()
  let mut clip_path = None
  let paint : @vello_cpu.PaintType = match paint {
    Color(c) => {
      let c = c.to_rgba().to_rgba8()
      Solid(
        @vello_cpu.AlphaColor::from_rgba8(
          c[0].to_int(),
          c[1].to_int(),
          c[2].to_int(),
          c[3].to_int(),
        ),
      )
    }
    Pattern(p) => {
      let path_transform = self.ctx.transform()
      match p {
        Shading(s) => {
          clip_path = s.shading.clip_path
          let encoded = s.encode()
          let mut bbox = path_bbox()
            .to_path(0.0)
            .transform(path_transform)
            .bounding_box()
          if is_stroke {
            // Try to account for stroke in bbox.
            let (a1, a2) = x_y_advances(path_transform)
            let factor = @kurbo.f64_max(a1.hypot(), a2.hypot()) *
              self.ctx.stroke().width
            bbox = bbox.inflate(factor, factor)
          }
          bbox = bbox.intersect(
            @kurbo.Rect::new(
              0.0,
              0.0,
              self.ctx.width().to_double(),
              self.ctx.height().to_double(),
            ),
          )
          let native = match encoded.shading_type {
            RadialAxial(gradient) =>
              gradient.as_svg_gradient(encoded, bbox, NATIVE_GRADIENT_TOLERANCE)
            _ => None
          }
          match native {
            Some(native) => {
              paint_transform = path_transform.inverse() *
                @kurbo.Affine::translate(-0.5, -0.5) *
                native.transform
              let stops = native.stops.map(stop => @vello_cpu.ColorStop::{
                offset: stop.offset,
                color: @vello_cpu.AlphaColor::new(stop.color),
              })
              let gradient = match native.kind {
                Linear(start~, end~) =>
                  @vello_cpu.Gradient::new_linear(start, end)
                Radial(start_center~, start_radius~, end_center~, end_radius~) =>
                  @vello_cpu.Gradient::new_two_point_radial(
                    start_center, start_radius, end_center, end_radius,
                  )
              }
              Gradient(gradient.with_extend(Pad).with_stops(stops))
            }
            None => {
              let (image, width, height, transform, may_have_transparency) = render_shading_texture(
                bbox, encoded,
              )
              paint_transform = path_transform.inverse() * transform
              let pixmap = @vello_cpu.Pixmap::from_parts_with_opacity(
                image,
                width & 0xFFFF,
                height & 0xFFFF,
                may_have_transparency,
              )
              Image({
                image: Pixmap(pixmap),
                sampler: {
                  x_extend: Repeat,
                  y_extend: Repeat,
                  quality: Medium,
                  alpha: 1.0,
                },
              })
            }
          }
        }
        Tiling(t) => {
          let bbox = t.bbox
          let max_x_scale = MAX_PIXMAP_SIZE / Float::from_double(bbox.width())
          let min_x_scale = MIN_PIXMAP_SIZE / Float::from_double(bbox.width())
          let max_y_scale = MAX_PIXMAP_SIZE / Float::from_double(bbox.height())
          let min_y_scale = MIN_PIXMAP_SIZE / Float::from_double(bbox.height())
          let (xs, ys) = {
            let (x, y) = x_y_advances(t.matrix)
            (Float::from_double(x.hypot()), Float::from_double(y.hypot()))
          }
          let xs = fminnm(fmaxnm(xs, min_x_scale), max_x_scale)
          let ys = fminnm(fmaxnm(ys, min_y_scale), max_y_scale)
          let x_step = xs * t.x_step
          let y_step = ys * t.y_step
          let scaled_width = Float::from_double(bbox.width()) * xs
          let scaled_height = Float::from_double(bbox.height()) * ys
          let pix_width = f32_as_u16(roundf(x_step.abs()))
          let pix_height = f32_as_u16(roundf(y_step.abs()))
          let renderer = {
            ctx: @vello_cpu.RenderContext::new(pix_width, pix_height),
            inside_pattern: true,
            soft_mask_cache: {},
            outline_cache: self.outline_cache,
            in_type3_glyph: false,
          }
          let mut initial_transform = @kurbo.Affine::scale_non_uniform(
              xs.to_double(),
              ys.to_double(),
            ) *
            @kurbo.Affine::translate(-bbox.x0, -bbox.y0)
          let _ = t.interpret(renderer, initial_transform, is_stroke)
          let pix = @vello_cpu.Pixmap::new(pix_width, pix_height)
          renderer.ctx.flush()
          renderer.ctx.render(pix)
          // TODO: Fix these
          if x_step < 0.0 {
            initial_transform = initial_transform *
              @kurbo.Affine::new([
                -1.0,
                0.0,
                0.0,
                1.0,
                scaled_width.to_double(),
                0.0,
              ])
          }
          if y_step < 0.0 {
            initial_transform = initial_transform *
              @kurbo.Affine::new([
                1.0,
                0.0,
                0.0,
                -1.0,
                0.0,
                scaled_height.to_double(),
              ])
          }
          paint_transform = path_transform.inverse() *
            t.matrix *
            initial_transform.inverse()
          Image({
            image: Pixmap(pix),
            sampler: {
              x_extend: Repeat,
              y_extend: Repeat,
              quality: Medium,
              alpha: 1.0,
            },
          })
        }
      }
    }
  }
  self.ctx.set_paint_transform(paint_transform)
  self.ctx.set_paint(paint)
  clip_path
}

///|
/// `f32 as u16` (saturating).
fn f32_as_u16(x : Float) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 65535.0 {
    65535
  } else {
    x.to_int()
  }
}

///|
fn Renderer::stroke_path(
  self : Renderer,
  path : @kurbo.BezPath,
  props : @interpret.DrawProps,
  stroke_props : @interpret.StrokeProps,
  is_text : Bool,
) -> Unit {
  self.apply_draw_props(props)
  self.set_stroke_properties(stroke_props, is_text)
  let clip_path = self.set_paint(props.paint, () => path.bounding_box(), true)
  if clip_path is Some(clip_path) {
    self.push_clip_path_inner(clip_path, NonZero)
  }
  self.ctx.stroke_path(path)
  if clip_path is Some(_) {
    self.ctx.pop_clip_path()
  }
}

///|
fn Renderer::fill_path(
  self : Renderer,
  path : @kurbo.BezPath,
  props : @interpret.DrawProps,
  fill_rule : @interpret.FillRule,
) -> Unit {
  self.ctx.set_fill_rule(convert_fill_rule(fill_rule))
  self.apply_draw_props(props)
  let clip_path = self.set_paint(props.paint, () => path.bounding_box(), false)
  if clip_path is Some(clip_path) {
    self.push_clip_path_inner(clip_path, fill_rule)
  }
  self.ctx.fill_path(path)
  if clip_path is Some(_) {
    self.ctx.pop_clip_path()
  }
}

///|
fn Renderer::fill_glyph(
  self : Renderer,
  glyph : @interpret.Glyph,
  props : @interpret.DrawProps,
  glyph_transform : @kurbo.Affine,
) -> Unit {
  match glyph {
    Outline(o) => {
      let base_outline = self.cached_outline(o)
      let props = { ..props, transform: props.transform * glyph_transform, }
      self.fill_path(base_outline, props, NonZero)
    }
    Type3(s) => {
      self.in_type3_glyph = true
      s.interpret(self, props.transform, glyph_transform, props.paint)
      self.in_type3_glyph = false
    }
  }
}

///|
fn Renderer::stroke_glyph(
  self : Renderer,
  glyph : @interpret.Glyph,
  props : @interpret.DrawProps,
  glyph_transform : @kurbo.Affine,
  stroke_props : @interpret.StrokeProps,
) -> Unit {
  match glyph {
    Outline(o) => {
      let base_outline = self.cached_outline(o)
      self.stroke_path(
        base_outline.transform(glyph_transform),
        props,
        stroke_props,
        true,
      )
    }
    Type3(s) => s.interpret(self, props.transform, glyph_transform, props.paint)
  }
}

///|
fn Renderer::cached_outline(
  self : Renderer,
  glyph : @interpret.OutlineGlyph,
) -> @kurbo.BezPath {
  let id = @interpret.CacheKey::cache_key(glyph.identifier())
  match self.outline_cache.get(id) {
    Some(path) => path
    None => {
      let path = glyph.outline()
      self.outline_cache[id] = path
      path
    }
  }
}

///|
impl @interpret.Device for Renderer with fn draw_image(self, image, props) {
  self.apply_image_props(props)
  let mut transform = props.transform
  self.ctx.set_paint_transform(@kurbo.Affine::identity())
  self.ctx.set_aliasing_threshold(Some(1))
  let target_width = f64_as_u32(
    transform
    .apply(@kurbo.Point::new(image.width().to_double(), 0.0))
    .to_vec2()
    .hypot()
    .ceil(),
  )
  let target_height = f64_as_u32(
    transform
    .apply(@kurbo.Point::new(0.0, image.height().to_double()))
    .to_vec2()
    .hypot()
    .ceil(),
  )
  match image {
    Stencil(s) =>
      s.with_stencil(
        (stencil, paint) => {
          transform = transform *
            @kurbo.Affine::scale_non_uniform(
              stencil.scale_factors.0.to_double(),
              stencil.scale_factors.1.to_double(),
            )
          match paint {
            Color(c) => {
              let color = c.to_rgba().to_rgba8()
              let alpha = color[3]
              let blend_mode = self.ctx.blend_mode()
              let push_layer = alpha != b'\xFF' ||
                blend_mode != @vello_cpu.BlendMode::default()
              self.ctx.set_transform(transform)
              if push_layer {
                self.ctx.push_layer(
                  Some(blend_mode),
                  Some(Float::from_int(alpha.to_int()) / 255.0),
                  None,
                )
              }
              let old_rule = self.ctx.fill_rule()
              self.ctx.set_fill_rule(NonZero)
              self.draw_image_impl(
                Solid({
                  color: [color[0], color[1], color[2]],
                  width: stencil.width,
                  height: stencil.height,
                  interpolate: stencil.interpolate,
                }),
                Some(stencil),
              )
              if push_layer {
                self.ctx.pop_layer()
              }
              self.ctx.set_fill_rule(old_rule)
            }
            Pattern(_) => {
              let width = self.ctx.width()
              let height = self.ctx.height()
              let stencil_rect = @kurbo.Rect::new(
                0.0,
                0.0,
                stencil.width.to_double(),
                stencil.height.to_double(),
              )
              let mask_pix = {
                let rgb_bytes = @interpret.ImageData::Rgb({
                  data: Bytes::make(stencil.width * stencil.height * 3, b'\xFF'),
                  width: stencil.width,
                  height: stencil.height,
                  interpolate: stencil.interpolate,
                  scale_factors: stencil.scale_factors,
                })
                let sub_renderer = Renderer::new(
                  width,
                  height,
                  self.outline_cache,
                )
                let sub_pix = @vello_cpu.Pixmap::new(width, height)
                sub_renderer.ctx.set_transform(transform)
                sub_renderer.draw_image_impl(
                  RenderImageData::from_image_data(rgb_bytes),
                  Some(stencil),
                )
                sub_renderer.ctx.flush()
                sub_renderer.ctx.render(sub_pix)
                sub_pix
              }
              self.ctx.push_layer(
                Some(self.ctx.blend_mode()),
                None,
                Some(@vello_cpu.Mask::new_luminance(mask_pix)),
              )
              self.ctx.set_transform(transform)
              let clip_path = self.set_paint(paint, () => stencil_rect, false)
              if clip_path is Some(clip_path) {
                self.push_clip_path_inner(clip_path, NonZero)
              }
              self.ctx.fill_rect(stencil_rect)
              if clip_path is Some(_) {
                self.ctx.pop_clip_path()
              }
              self.ctx.pop_layer()
            }
          }
        },
        Some((target_width, target_height)),
      )
    Raster(r) =>
      r.with_rgba(
        (image, alpha) => {
          let (sx, sy) = image.scale_factors()
          transform = transform *
            @kurbo.Affine::scale_non_uniform(sx.to_double(), sy.to_double())
          self.ctx.set_transform(transform)
          self.draw_image_impl(RenderImageData::from_image_data(image), alpha)
        },
        Some((target_width, target_height)),
      )
  }
  self.ctx.set_aliasing_threshold(None)
}

///|
/// `f64 as u32` (saturating, as `Int`).
fn f64_as_u32(x : Double) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
impl @interpret.Device for Renderer with fn push_clip_path(self, clip_path) {
  self.push_clip_path_inner(clip_path.path, clip_path.fill)
}

///|
impl @interpret.Device for Renderer with fn push_clip_rect(self, rect) {
  self.push_clip_path_inner(rect.to_path(0.1), NonZero)
}

///|
impl @interpret.Device for Renderer with fn push_transparency_group(
  self,
  opacity,
  mask,
  blend_mode,
) {
  let mask = match mask {
    Some(m) => Some(self.cached_soft_mask(m))
    None => None
  }
  self.ctx.push_layer(Some(convert_blend_mode(blend_mode)), Some(opacity), mask)
}

///|
impl @interpret.Device for Renderer with fn pop_clip(self) {
  self.ctx.pop_clip_path()
}

///|
impl @interpret.Device for Renderer with fn pop_transparency_group(self) {
  self.ctx.pop_layer()
}

///|
impl @interpret.Device for Renderer with fn draw_path(
  self,
  path,
  props,
  draw_mode,
) {
  match draw_mode {
    Fill(f) => self.fill_path(path, props, f)
    Stroke(s) => self.stroke_path(path, props, s, false)
    FillAndStroke(f, s) => {
      self.fill_path(path, props, f)
      self.stroke_path(path, props, s, false)
    }
    Invisible => ()
  }
}

///|
impl @interpret.Device for Renderer with fn draw_rect(
  self,
  rect,
  props,
  draw_mode,
) {
  match draw_mode {
    Fill(fill_rule) => {
      self.ctx.set_fill_rule(convert_fill_rule(fill_rule))
      self.apply_draw_props(props)
      let clip_path = self.set_paint(props.paint, () => rect, false)
      if clip_path is Some(clip_path) {
        self.push_clip_path_inner(clip_path, fill_rule)
      }
      self.ctx.fill_rect(rect)
      if clip_path is Some(_) {
        self.ctx.pop_clip_path()
      }
    }
    Stroke(s) => {
      let path = rect.to_path(0.1)
      self.stroke_path(path, props, s, false)
    }
    FillAndStroke(fill_rule, stroke_props) => {
      @interpret.Device::draw_rect(self, rect, props, Fill(fill_rule))
      let path = rect.to_path(0.1)
      self.stroke_path(path, props, stroke_props, false)
    }
    Invisible => ()
  }
}

///|
impl @interpret.Device for Renderer with fn draw_glyph(
  self,
  glyph,
  glyph_transform,
  props,
  draw_mode,
) {
  match draw_mode {
    Fill(_) => self.fill_glyph(glyph, props, glyph_transform)
    Stroke(s) => self.stroke_glyph(glyph, props, glyph_transform, s)
    FillAndStroke(_, s) => {
      self.fill_glyph(glyph, props, glyph_transform)
      self.stroke_glyph(glyph, props, glyph_transform, s)
    }
    Invisible => ()
  }
}

///|
/// Render a shading into a texture covering `path_bbox`.
fn render_shading_texture(
  path_bbox : @kurbo.Rect,
  shading_pattern : @interpret.EncodedShadingPattern,
) -> (FixedArray[Byte], Int, Int, @kurbo.Affine, Bool) {
  let base_width = fmaxnm(Float::from_double(path_bbox.width()), 1.0)
  let base_height = fmaxnm(Float::from_double(path_bbox.height()), 1.0)
  let width = f32_as_u32(base_width.ceil())
  let height = f32_as_u32(base_height.ceil())
  let (x_advance, y_advance) = x_y_advances(shading_pattern.base_transform)
  let buf = FixedArray::make(width * height * 4, b'\x00')
  let mut start_point = (shading_pattern.base_transform *
  @kurbo.Affine::translate(0.5, 0.5)).apply(
    @kurbo.Point::new(path_bbox.x0, path_bbox.y0),
  )
  let mut may_have_transparency = false
  for row in 0..<height {
    let mut point = start_point
    for col in 0..<width {
      let sample = shading_pattern.sample(point)
      let c = @vello_cpu.components_to_rgba8(
        @vello_cpu.AlphaColor::new(sample).premultiply(),
      )
      let o = (row * width + col) * 4
      buf[o] = c[0].to_byte()
      buf[o + 1] = c[1].to_byte()
      buf[o + 2] = c[2].to_byte()
      buf[o + 3] = c[3].to_byte()
      may_have_transparency = may_have_transparency || c[3] != 255
      point = point.add_vec(x_advance)
    }
    start_point = start_point.add_vec(y_advance)
  }
  (
    buf,
    width,
    height,
    @kurbo.Affine::translate(path_bbox.x0, path_bbox.y0),
    may_have_transparency,
  )
}

///|
fn draw_soft_mask(
  mask : @interpret.SoftMask,
  width : Int,
  height : Int,
) -> @vello_cpu.Mask {
  let renderer = Renderer::new(width, height, {})
  let bg_color = mask.background_color().to_rgba()
  let bg8 = bg_color.to_rgba8()
  let black8 = @interpret.alpha_color_black.to_rgba8()
  let apply_bg = bg8[0] != black8[0] ||
    bg8[1] != black8[1] ||
    bg8[2] != black8[2] ||
    bg8[3] != black8[3]
  if apply_bg {
    renderer.ctx.set_paint(
      Solid(@vello_cpu.AlphaColor::new(bg_color.components())),
    )
    renderer.ctx.fill_rect(
      @kurbo.Rect::new(0.0, 0.0, width.to_double(), height.to_double()),
    )
    renderer.ctx.push_layer(None, None, None)
  }
  mask.interpret(renderer)
  if apply_bg {
    renderer.ctx.pop_layer()
  }
  let pix = @vello_cpu.Pixmap::new(width, height)
  renderer.ctx.flush()
  renderer.ctx.render(pix)
  let rendered_mask = match mask.mask_type() {
    Luminosity => @vello_cpu.Mask::new_luminance(pix)
    Alpha => @vello_cpu.Mask::new_alpha(pix)
  }
  match mask.transfer_function() {
    Some(transfer_function) => {
      let mw = rendered_mask.width()
      let mh = rendered_mask.height()
      let map = FixedArray::make(mw * mh, b'\x00')
      for y in 0..<mh {
        for x in 0..<mw {
          let v = transfer_function.apply(
              Float::from_int(rendered_mask.sample(x, y)) / 255.0,
            ) *
            255.0 +
            0.5
          map[y * mw + x] = f32_as_u8(v).to_byte()
        }
      }
      @vello_cpu.Mask::from_parts(map, mw, mh)
    }
    None => rendered_mask
  }
}

///|
/// `f32 as u8` (saturating).
fn f32_as_u8(x : Float) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 255.0 {
    255
  } else {
    x.to_int()
  }
}

///|
fn max_factor(transform : @kurbo.Affine) -> Float {
  let (x_advance, y_advance) = x_y_advances(transform)
  Float::from_double(@kurbo.f64_max(x_advance.hypot(), y_advance.hypot()))
}

///|
fn x_y_advances(transform : @kurbo.Affine) -> (@kurbo.Vec2, @kurbo.Vec2) {
  let c = transform.as_coeffs()
  let scale_skew_transform = @kurbo.Affine::new([
    c[0],
    c[1],
    c[2],
    c[3],
    0.0,
    0.0,
  ])
  let x_advance = scale_skew_transform.apply(@kurbo.Point::new(1.0, 0.0))
  let y_advance = scale_skew_transform.apply(@kurbo.Point::new(0.0, 1.0))
  (x_advance.to_vec2(), y_advance.to_vec2())
}

///|
fn convert_fill_rule(fill_rule : @interpret.FillRule) -> @vello_cpu.Fill {
  match fill_rule {
    NonZero => NonZero
    EvenOdd => EvenOdd
  }
}

///|
fn convert_blend_mode(
  blend_mode : @interpret.BlendMode,
) -> @vello_cpu.BlendMode {
  let mix : @vello_cpu.Mix = match blend_mode {
    Normal => Normal
    Multiply => Multiply
    Screen => Screen
    Overlay => Overlay
    Darken => Darken
    Lighten => Lighten
    ColorDodge => ColorDodge
    ColorBurn => ColorBurn
    HardLight => HardLight
    SoftLight => SoftLight
    Difference => Difference
    Exclusion => Exclusion
    Hue => Hue
    Saturation => Saturation
    Color => Color
    Luminosity => Luminosity
  }
  @vello_cpu.BlendMode::new(mix, SrcOver)
}
