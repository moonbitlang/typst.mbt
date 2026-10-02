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
  dummy : Unit
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
  _path_bbox : () -> @kurbo.Rect,
  path_transform : @kurbo.Affine,
  _stroke_props : @interpret.StrokeProps?,
) -> (String, Float) {
  match paint {
    Color(c) => {
      let rgba8 = c.to_rgba().to_rgba8()
      let color = "#\{hex2(rgba8[0])}\{hex2(rgba8[1])}\{hex2(rgba8[2])}"
      let alpha = rgba8[3].to_float() / 255.0
      (color, alpha)
    }
    Pattern(p) => {
      let id = match p {
        Shading(_) =>
          // TODO: shadings are not ported yet (`Shading::new` always fails,
          // so there are no shading patterns).
          abort("shading patterns are not ported yet")
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
  // TODO: shadings are not ported yet.
  abort("shading patterns are not ported yet")
}

///|
fn SvgRenderer::write_native_gradient_defs(self : SvgRenderer) -> Unit {
  if self.gradients.is_empty() {
    return
  }
  // TODO: shadings are not ported yet.
  abort("shading patterns are not ported yet")
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
  // TODO: shadings are not ported yet.
  abort("shading patterns are not ported yet")
}
