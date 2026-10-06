// Port of `hayro-svg/src/paint.rs`.

///|
priv struct CachedTilingPattern {
  transform : @kurbo.Affine
  tiling_pattern : @interpret.TilingPattern
}

///|
priv struct CachedShadingPattern {
  transform : @kurbo.Affine
  paint : CachedShadingPaint
  clip_path : Id?
  bbox : @kurbo.Rect
}

///|
priv enum CachedShadingPaint {
  Raster(shading~ : Id)
  NativeGradient(gradient~ : Id)
}

///|
priv struct CachedNativeGradient {
  gradient : @interpret.SvgGradient
}

///|
priv struct CachedShading {
  pattern : @interpret.ShadingPattern
  bbox : @kurbo.Rect
}

///|
fn SvgRenderer::write_paint(
  self : SvgRenderer,
  paint : @interpret.Paint,
  path_bbox : () -> @kurbo.Rect,
  path_transform : @kurbo.Affine,
  stroke_props : @interpret.StrokeProps?,
) -> Unit {
  let (paint_str, alpha) = self.svg_paint(
    paint, path_bbox, path_transform, stroke_props,
  )
  if stroke_props is Some(_) {
    self.xml.write_attribute("fill", "none")
    self.xml.write_attribute("stroke", paint_str)
    if alpha != 1.0 {
      self.xml.write_attribute("stroke-opacity", f32_str(alpha))
    }
  } else {
    self.xml.write_attribute("fill", paint_str)
    if alpha != 1.0 {
      self.xml.write_attribute("fill-opacity", f32_str(alpha))
    }
  }
}

///|
fn SvgRenderer::write_fill_and_stroke_paint(
  self : SvgRenderer,
  paint : @interpret.Paint,
  path_bbox : () -> @kurbo.Rect,
  path_transform : @kurbo.Affine,
  stroke_props : @interpret.StrokeProps,
) -> Unit {
  let (fill_str, fill_alpha) = self.svg_paint(
    paint,
    path_bbox,
    path_transform,
    None,
  )
  let (stroke_str, stroke_alpha) = self.svg_paint(
    paint,
    path_bbox,
    path_transform,
    Some(stroke_props),
  )
  self.xml.write_attribute("fill", fill_str)
  self.xml.write_attribute("stroke", stroke_str)
  if fill_alpha != 1.0 {
    self.xml.write_attribute("fill-opacity", f32_str(fill_alpha))
  }
  if stroke_alpha != 1.0 {
    self.xml.write_attribute("stroke-opacity", f32_str(stroke_alpha))
  }
}

///|
fn hex2(b : Byte) -> String {
  let digits = "0123456789abcdef"
  let v = b.to_int()
  [digits[v >> 4].unsafe_to_char(), digits[v & 15].unsafe_to_char()]
  |> String::from_array
}

///|
fn SvgRenderer::svg_paint(
  self : SvgRenderer,
  paint : @interpret.Paint,
  path_bbox : () -> @kurbo.Rect,
  path_transform : @kurbo.Affine,
  stroke_props : @interpret.StrokeProps?,
) -> (String, Float) {
  match paint {
    Color(c) => {
      let rgba8 = c.to_rgba().to_rgba8()
      let color = "#\{hex2(rgba8[0])}\{hex2(rgba8[1])}\{hex2(rgba8[2])}"
      let alpha = Float::from_byte(rgba8[3]) / 255.0
      (color, alpha)
    }
    Pattern(p) => {
      let id = match p {
        Shading(s) => {
          let native_gradient_tolerance : Float = 0.01
          let mut basic_bbox = path_bbox()
          if stroke_props is Some(props) {
            let stroke_width = props.line_width.to_double()
            basic_bbox = basic_bbox.inflate(stroke_width, stroke_width)
          }
          let bbox = basic_bbox
            .to_path(0.0)
            .transform(path_transform)
            .bounding_box()
          let shading_key = @interpret.hash128(h => {
            h.write_u128(@interpret.CacheKey::cache_key(s))
            h.write_f64(bbox.x0)
            h.write_f64(bbox.x1)
            h.write_f64(bbox.y0)
            h.write_f64(bbox.y1)
          })
          let encoded = s.encode()
          let native = match encoded.shading_type {
            RadialAxial(gradient) =>
              gradient.as_svg_gradient(encoded, bbox, native_gradient_tolerance)
            _ => None
          }
          let shading_paint = if native is Some(native) {
            let gradient_key = gradient_key(shading_key, native)
            let gradient_id = self.gradients.insert_with(gradient_key, () => {
              gradient: native,
            })
            CachedShadingPaint::NativeGradient(gradient=gradient_id)
          } else {
            let shading_id = self.shadings.insert_with(shading_key, () => {
              pattern: s,
              bbox,
            })
            CachedShadingPaint::Raster(shading=shading_id)
          }
          let clip_path = match s.shading.clip_path {
            Some(path) =>
              Some(
                self.clip_paths.insert(
                  CachedClipPath::Path(path~, fill_rule=NonZero, parent=None),
                ),
              )
            None => None
          }
          let inverse_transform = path_transform.inverse()
          let pattern_key = @interpret.pair_cache_key(
            shading_key, inverse_transform,
          )
          self.shading_patterns.insert_with(pattern_key, () => {
            transform: inverse_transform,
            bbox,
            clip_path,
            paint: shading_paint,
          })
        }
        Tiling(t) => {
          let inverse_transform = path_transform.inverse()
          let pattern = t
          let cache_key = @interpret.hash128_keys([
            @interpret.CacheKey::cache_key(pattern),
            @interpret.CacheKey::cache_key(inverse_transform),
          ])
          if !self.tiling_patterns.contains(cache_key) {
            self.with_dummy(r => {
              let _ = t.interpret(
                r,
                @kurbo.Affine::translate(-pattern.bbox.x0, -pattern.bbox.y0),
                false,
              )
            })
          }
          self.tiling_patterns.insert_with(cache_key, () => {
            transform: inverse_transform,
            tiling_pattern: pattern,
          })
        }
      }
      ("url(#\{id})", 1.0)
    }
  }
}

///|
fn SvgRenderer::write_shading_pattern_defs(self : SvgRenderer) -> Unit {
  if self.shading_patterns.is_empty() {
    return
  }
  self.xml.start_element("defs")
  self.xml.write_attribute("id", "shading-pattern")
  for item in self.shading_patterns.iter() {
    let (id, shading) = item
    self.xml.start_element("pattern")
    self.xml.write_attribute("id", id.to_string())
    self.xml.write_attribute("patternUnits", "userSpaceOnUse")
    self.xml.write_attribute("width", f64_str(shading.bbox.x1))
    self.xml.write_attribute("height", f64_str(shading.bbox.y1))
    self.xml.write_attribute(
      "patternTransform",
      "matrix(\{convert_transform(shading.transform)})",
    )
    match shading.paint {
      Raster(shading=shading_id) => {
        self.xml.start_element("use")
        if shading.clip_path is Some(clip) {
          self.xml.write_attribute("clip-path", "url(#\{clip})")
        }
        self.xml.write_attribute("xlink:href", "#\{shading_id}")
        self.xml.end_element()
      }
      NativeGradient(gradient~) => {
        self.xml.start_element("rect")
        self.xml.write_attribute("x", f64_str(shading.bbox.x0))
        self.xml.write_attribute("y", f64_str(shading.bbox.y0))
        self.xml.write_attribute("width", f64_str(shading.bbox.width()))
        self.xml.write_attribute("height", f64_str(shading.bbox.height()))
        if shading.clip_path is Some(clip) {
          self.xml.write_attribute("clip-path", "url(#\{clip})")
        }
        self.xml.write_attribute("fill", "url(#\{gradient})")
        self.xml.end_element()
      }
    }
    self.xml.end_element()
  }
  self.xml.end_element()
}

///|
fn SvgRenderer::write_native_gradient_defs(self : SvgRenderer) -> Unit {
  if self.gradients.is_empty() {
    return
  }
  self.xml.start_element("defs")
  self.xml.write_attribute("id", "gradient")
  for item in self.gradients.iter() {
    let (id, gradient) = item
    write_gradient(self.xml, id.to_string(), gradient.gradient)
  }
  self.xml.end_element()
}

///|
fn SvgRenderer::write_tiling_pattern_defs(self : SvgRenderer) -> Unit {
  if self.tiling_patterns.is_empty() {
    return
  }
  self.xml.start_element("defs")
  self.xml.write_attribute("id", "tiling-pattern")
  let patterns = self.tiling_patterns.iter()
  for item in patterns {
    let (id, pattern) = item
    let bbox_origin = @kurbo.Affine::translate(
      pattern.tiling_pattern.bbox.x0,
      pattern.tiling_pattern.bbox.y0,
    )
    let transform = pattern.transform *
      pattern.tiling_pattern.matrix *
      bbox_origin
    self.xml.start_element("pattern")
    self.xml.write_attribute("id", id.to_string())
    self.xml.write_attribute("patternUnits", "userSpaceOnUse")
    self.xml.write_attribute(
      "width",
      f32_str(pattern.tiling_pattern.x_step.abs()),
    )
    self.xml.write_attribute(
      "height",
      f32_str(pattern.tiling_pattern.y_step.abs()),
    )
    self.xml.write_attribute(
      "patternTransform",
      "matrix(\{convert_transform(transform)})",
    )
    let _ = pattern.tiling_pattern.interpret(
      self,
      @kurbo.Affine::translate(
        -pattern.tiling_pattern.bbox.x0,
        -pattern.tiling_pattern.bbox.y0,
      ),
      false,
    )
    self.xml.end_element()
  }
  self.xml.end_element()
}

///|
fn SvgRenderer::write_shading_defs(self : SvgRenderer) -> Unit {
  if self.shadings.is_empty() {
    return
  }
  // `std::mem::take(&mut self.shadings)`.
  let shadings = self.shadings.iter()
  self.shadings.vec.clear()
  self.shadings.present.clear()
  self.xml.start_element("defs")
  self.xml.write_attribute("id", "shading")
  for item in shadings {
    let (id, shading) = item
    let encoded = shading.pattern.encode()
    let (image, transform) = render_shading_texture(shading.bbox, encoded)
    self.write_image(image, true, Some(id), transform)
  }
  self.xml.end_element()
}

///|
fn rgba_to_hex(color : FixedArray[Float]) -> String {
  let r = @interpret.f32_as_u8(
    @interpret.f32_clamp(color[0], 0.0, 1.0) * 255.0 + 0.5,
  )
  let g = @interpret.f32_as_u8(
    @interpret.f32_clamp(color[1], 0.0, 1.0) * 255.0 + 0.5,
  )
  let b = @interpret.f32_as_u8(
    @interpret.f32_clamp(color[2], 0.0, 1.0) * 255.0 + 0.5,
  )
  "#\{hex2(r)}\{hex2(g)}\{hex2(b)}"
}

///|
fn gradient_key(
  shading_key : @interpret.U128,
  gradient : @interpret.SvgGradient,
) -> @interpret.U128 {
  @interpret.hash128(h => {
    h.write_u128(shading_key)
    // kind: `(u8, u64, u64, u32, u64, u64, u32, u32)` of float bits.
    match gradient.kind {
      Linear(start~, end~) => {
        h.write_u8(0)
        h.write_f64(start.x)
        h.write_f64(start.y)
        h.write_u32(0)
        h.write_f64(end.x)
        h.write_f64(end.y)
        h.write_u32(0)
        h.write_u32(0)
      }
      Radial(start_center~, start_radius~, end_center~, end_radius~) => {
        h.write_u8(1)
        h.write_f64(start_center.x)
        h.write_f64(start_center.y)
        h.write_f32(start_radius)
        h.write_f64(end_center.x)
        h.write_f64(end_center.y)
        h.write_f32(end_radius)
        h.write_u32(0)
      }
    }
    // transform: `[u64; 6]` (hashed like a slice, with a length prefix).
    let transform = gradient.transform.as_coeffs()
    h.write_usize(transform.length())
    for coeff in transform {
      h.write_f64(coeff)
    }
    // stops: `Vec<(u32, [u32; 4])>`.
    h.write_usize(gradient.stops.length())
    for stop in gradient.stops {
      h.write_f32(stop.offset)
      h.write_usize(4)
      for i in 0..<4 {
        h.write_f32(stop.color[i])
      }
    }
  })
}

///|
fn write_gradient(
  xml : @xmlwriter.XmlWriter,
  id : String,
  gradient : @interpret.SvgGradient,
) -> Unit {
  let gradient_transform = convert_transform(
    @kurbo.Affine::translate(-0.5, -0.5) * gradient.transform,
  )
  match gradient.kind {
    Linear(start~, end~) => {
      xml.start_element("linearGradient")
      xml.write_attribute("id", id)
      xml.write_attribute("gradientUnits", "userSpaceOnUse")
      xml.write_attribute("gradientTransform", "matrix(\{gradient_transform})")
      xml.write_attribute("x1", f64_str(start.x))
      xml.write_attribute("y1", f64_str(start.y))
      xml.write_attribute("x2", f64_str(end.x))
      xml.write_attribute("y2", f64_str(end.y))
    }
    Radial(start_center~, start_radius~, end_center~, end_radius~) => {
      xml.start_element("radialGradient")
      xml.write_attribute("id", id)
      xml.write_attribute("gradientUnits", "userSpaceOnUse")
      xml.write_attribute("gradientTransform", "matrix(\{gradient_transform})")
      xml.write_attribute("fx", f64_str(start_center.x))
      xml.write_attribute("fy", f64_str(start_center.y))
      xml.write_attribute("fr", f32_str(start_radius))
      xml.write_attribute("cx", f64_str(end_center.x))
      xml.write_attribute("cy", f64_str(end_center.y))
      xml.write_attribute("r", f32_str(end_radius))
    }
  }
  xml.write_attribute("spreadMethod", "pad")
  for stop in gradient.stops {
    xml.start_element("stop")
    xml.write_attribute("offset", f32_str(stop.offset))
    xml.write_attribute("stop-color", rgba_to_hex(stop.color))
    if stop.color[3] < 1.0 {
      xml.write_attribute("stop-opacity", f32_str(stop.color[3]))
    }
    xml.end_element()
  }
  xml.end_element()
}

///|
fn render_shading_texture(
  bbox : @kurbo.Rect,
  shading_pattern : @interpret.EncodedShadingPattern,
) -> (DynamicImage, @kurbo.Affine) {
  let scale : Float = 1.0
  let inv_scale : Float = 1.0 / scale
  let base_width = @interpret.f32_max(Float::from_double(bbox.width()), 1.0)
  let base_height = @interpret.f32_max(Float::from_double(bbox.height()), 1.0)
  let width = @interpret.f32_as_u32((base_width * scale).ceil())
  let height = @interpret.f32_as_u32((base_height * scale).ceil())
  let (x_advance, y_advance) = x_y_advances(
    @kurbo.Affine::scale(inv_scale.to_double()) * shading_pattern.base_transform,
  )
  let buf = FixedArray::make(width * height * 4, b'\x00')
  let mut start_point = (shading_pattern.base_transform *
  @kurbo.Affine::translate(0.5, 0.5)).apply(@kurbo.Point::new(bbox.x0, bbox.y0))
  for row in 0..<height {
    let mut point = start_point
    for col in 0..<width {
      let sample = shading_pattern.sample(point)
      let offset = (row * width + col) * 4
      for i in 0..<4 {
        buf[offset + i] = @interpret.f32_as_u8(sample[i] * 255.0 + 0.5)
      }
      point = point.add_vec(x_advance)
    }
    start_point = start_point.add_vec(y_advance)
  }
  let image = image_from_raw(Rgba, width, height, Bytes::from_array(buf))
  (
    image,
    @kurbo.Affine::translate(bbox.x0, bbox.y0) *
    @kurbo.Affine::scale(inv_scale.to_double()),
  )
}

///|
fn x_y_advances(transform : @kurbo.Affine) -> (@kurbo.Vec2, @kurbo.Vec2) {
  let scale_skew_transform = {
    let c = transform.as_coeffs()
    @kurbo.Affine::new([c[0], c[1], c[2], c[3], 0.0, 0.0])
  }
  let x_advance = scale_skew_transform.apply(@kurbo.Point::new(1.0, 0.0))
  let y_advance = scale_skew_transform.apply(@kurbo.Point::new(0.0, 1.0))
  (
    @kurbo.Vec2::new(x_advance.x, x_advance.y),
    @kurbo.Vec2::new(y_advance.x, y_advance.y),
  )
}
