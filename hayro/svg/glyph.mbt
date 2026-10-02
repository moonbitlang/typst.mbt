// Port of `hayro-svg/src/glyph.rs`.

///|
priv struct CachedOutlineGlyph {
  path : @kurbo.BezPath
}

///|
priv struct CachedType3Glyph {
  glyph : @interpret.Type3Glyph
  transform : @kurbo.Affine
  glyph_transform : @kurbo.Affine
  paint : @interpret.Paint
}

///|
fn SvgRenderer::draw_glyph_impl(
  self : SvgRenderer,
  glyph : @interpret.Glyph,
  glyph_transform : @kurbo.Affine,
  props : @interpret.DrawProps,
  mode : @interpret.DrawMode,
) -> Unit {
  if mode is Invisible {
    return
  }
  match glyph {
    Outline(o) => {
      let outline = o.outline()
      let glyph_id = @interpret.CacheKey::cache_key(o.identifier())
      let (cache_key, glyph_path, use_transform, paint_transform) = match mode {
        Fill(_) => {
          let transform = props.transform * glyph_transform
          (glyph_id, outline, transform, transform)
        }
        // TODO: Figure out how to better merge transform and glyph transform for stroked glyphs.
        Stroke(_) | FillAndStroke(_, _) =>
          (
            @interpret.hash128_keys([
              glyph_id,
              @interpret.CacheKey::cache_key(glyph_transform),
            ]),
            outline.transform(glyph_transform),
            props.transform,
            props.transform,
          )
        Invisible =>
          // We exited above.
          abort("unreachable")
      }
      let id = self.outline_glyphs.insert_with(cache_key, () => {
        path: glyph_path,
      })
      self.xml.start_element("use")
      self.xml.write_attribute("xlink:href", "#\{id}")
      self.write_transform(use_transform)
      match mode {
        Fill(_) =>
          self.write_paint(
            props.paint,
            () => outline.bounding_box(),
            paint_transform,
            None,
          )
        Stroke(s) => {
          self.write_stroke_properties(s)
          self.write_paint(
            props.paint,
            () => outline.bounding_box(),
            paint_transform,
            Some(s),
          )
        }
        FillAndStroke(_, s) => {
          self.write_stroke_properties(s)
          self.write_fill_and_stroke_paint(
            props.paint,
            () => outline.bounding_box(),
            paint_transform,
            s,
          )
        }
        Invisible =>
          // We exited above.
          abort("unreachable")
      }
      self.xml.end_element()
    }
    Type3(t) => {
      let cache_key = @interpret.hash128_keys([
        @interpret.CacheKey::cache_key(t),
        @interpret.CacheKey::cache_key(props.transform),
        @interpret.CacheKey::cache_key(glyph_transform),
        @interpret.CacheKey::cache_key(props.paint),
      ])
      if !self.type3_glyphs.contains(cache_key) {
        self.with_dummy(r => {
          t.interpret(r, props.transform, glyph_transform, props.paint)
        })
      }

      // TODO: Apply transforms to group if possible
      let id = self.type3_glyphs.insert_with(cache_key, () => {
        glyph: t,
        transform: props.transform,
        glyph_transform,
        paint: props.paint,
      })
      self.xml.start_element("use")
      self.xml.write_attribute("xlink:href", "#\{id}")
      self.xml.end_element()
    }
  }
}

///|
fn SvgRenderer::write_glyph_defs(self : SvgRenderer) -> Unit {
  if !self.outline_glyphs.is_empty() {
    self.xml.start_element("defs")
    self.xml.write_attribute("id", "outline-glyph")
    for item in self.outline_glyphs.iter() {
      let (id, glyph) = item
      self.xml.start_element("path")
      self.xml.write_attribute("id", id.to_string())
      self.xml.write_attribute("d", to_svg_f32(glyph.path))
      self.xml.end_element()
    }
    self.xml.end_element()
  }
  if !self.type3_glyphs.is_empty() {
    self.xml.start_element("defs")
    self.xml.write_attribute("id", "type3-glyph")
    let type3_glyphs = self.type3_glyphs.iter()
    for item in type3_glyphs {
      let (id, glyph) = item
      self.xml.start_element("g")
      self.xml.write_attribute("id", id.to_string())
      glyph.glyph.interpret(
        self,
        glyph.transform,
        glyph.glyph_transform,
        glyph.paint,
      )
      self.xml.end_element()
    }
    self.xml.end_element()
  }
}
