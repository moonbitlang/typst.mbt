// Port of `hayro-svg/src/lib.rs`: converting PDF pages to SVG files.

///|
/// A cache used by the SVG converter.
///
/// Ideally, such a cache should be constructed once per PDF and then reused
/// across multiple conversion invocations on the same document.
pub struct RenderCache {
  priv interpreter_cache : @interpret.InterpreterCache
}

///|
/// Create a new render cache.
pub fn RenderCache::new() -> RenderCache {
  { interpreter_cache: @interpret.InterpreterCache::new(), }
}

///|
/// Convert the given page into an SVG string.
pub fn convert(
  page : @hayro_syntax.Page,
  cache : RenderCache,
  interpreter_settings : @interpret.InterpreterSettings,
  render_settings : SvgRenderSettings,
) -> String {
  let state = @interpret.Context::new(
    @interpret.transform_to_kurbo(page.initial_transform(true)),
    @kurbo.Rect::new(
      0.0,
      0.0,
      page.render_dimensions().0.to_double(),
      page.render_dimensions().1.to_double(),
    ),
    cache.interpreter_cache,
    page.xref(),
    interpreter_settings,
  )
  let device = SvgRenderer::new(page, render_settings)
  device.write_header(page.render_dimensions())
  @interpret.interpret_page(page, state, device)
  device.finish()
}

///|
/// Settings to apply during SVG rendering.
pub(all) struct SvgRenderSettings {
  /// The background color in format [red, green, blue, alpha].
  /// Determines the background color of the generated SVG root element.
  bg_color : FixedArray[Byte]
}

///|
pub impl Default for SvgRenderSettings with fn default() {
  { bg_color: [0, 0, 0, 0], }
}

///|
priv struct SvgRenderer {
  render_settings : SvgRenderSettings
  mut xml : @xmlwriter.XmlWriter
  outline_glyphs : Deduplicator[CachedOutlineGlyph]
  type3_glyphs : Deduplicator[CachedType3Glyph]
  clip_paths : Deduplicator[CachedClipPath]
  masks : Deduplicator[MaskKind]
  shadings : Deduplicator[CachedShading]
  gradients : Deduplicator[CachedNativeGradient]
  shading_patterns : Deduplicator[CachedShadingPattern]
  tiling_patterns : Deduplicator[CachedTilingPattern]
  active_clips : Array[Id]
  dimensions : (Float, Float)
}

///|
fn SvgRenderer::write_transform(
  self : SvgRenderer,
  transform : @kurbo.Affine,
) -> Unit {
  let c = transform.as_coeffs()
  let has_scale = !@interpret.f32_is_nearly_equal(c[0].to_float(), 1.0) ||
    !@interpret.f32_is_nearly_equal(c[3].to_float(), 1.0)
  let has_skew = !@interpret.f32_is_nearly_equal(c[1].to_float(), 0.0) ||
    !@interpret.f32_is_nearly_equal(c[2].to_float(), 0.0)
  let has_translate = !@interpret.f32_is_nearly_equal(c[4].to_float(), 0.0) ||
    !@interpret.f32_is_nearly_equal(c[5].to_float(), 0.0)
  let is_identity = !has_scale && !has_skew && !has_translate
  if !is_identity {
    let transform = match (has_scale, has_skew, has_translate) {
      (true, false, false) =>
        "scale(\{f32_str(c[0].to_float())} \{f32_str(c[3].to_float())})"
      (false, false, true) =>
        "translate(\{f32_str(c[4].to_float())} \{f32_str(c[5].to_float())})"
      _ => "matrix(\{convert_transform(transform)})"
    }
    self.xml.write_attribute("transform", transform)
  }
}

///|
fn SvgRenderer::push_transparency_group_inner(
  self : SvgRenderer,
  opacity : Float,
  mask : MaskKind?,
  blend_mode : @interpret.BlendMode,
) -> Unit {
  let mask_id = match mask {
    Some(m) => Some(self.get_mask_id(m))
    None => None
  }
  self.xml.start_element("g")
  if mask_id is Some(mask_id) {
    self.xml.write_attribute("mask", "url(#\{mask_id})")
  }
  if blend_mode != Normal {
    let bm_name = match blend_mode {
      Normal => "normal"
      Multiply => "multiply"
      Screen => "screen"
      Overlay => "overlay"
      Darken => "darken"
      Lighten => "lighten"
      ColorDodge => "color-dodge"
      ColorBurn => "color-burn"
      HardLight => "hard-light"
      SoftLight => "soft-light"
      Difference => "difference"
      Exclusion => "exclusion"
      Hue => "hue"
      Saturation => "saturation"
      Color => "color"
      Luminosity => "luminosity"
    }
    self.xml.write_attribute("style", "mix-blend-mode:\{bm_name}")
  }
  if !@interpret.f32_is_nearly_equal(opacity, 1.0) {
    self.xml.write_attribute("opacity", f32_str(opacity))
  }
  if self.active_clips.last() is Some(clip_id) {
    self.xml.write_attribute("clip-path", "url(#\{clip_id})")
  }
}

///|
fn SvgRenderer::write_stroke_properties(
  self : SvgRenderer,
  stroke_props : @interpret.StrokeProps,
) -> Unit {
  if !@interpret.f32_is_nearly_equal(stroke_props.line_width, 1.0) {
    self.xml.write_attribute("stroke-width", f32_str(stroke_props.line_width))
  }
  match stroke_props.line_cap {
    Butt => ()
    Square => self.xml.write_attribute("stroke-linecap", "square")
    Round => self.xml.write_attribute("stroke-linecap", "round")
  }
  match stroke_props.line_join {
    Bevel => self.xml.write_attribute("stroke-linejoin", "bevel")
    Miter => ()
    Round => self.xml.write_attribute("stroke-linejoin", "round")
  }
  if !@interpret.f32_is_nearly_equal(stroke_props.miter_limit, 4.0) {
    self.xml.write_attribute(
      "stroke-miterlimit",
      f32_str(stroke_props.miter_limit),
    )
  }
  if !@interpret.f32_is_nearly_equal(stroke_props.dash_offset, 0.0) {
    self.xml.write_attribute(
      "stroke-dashoffset",
      f32_str(stroke_props.dash_offset),
    )
  }
  if !stroke_props.dash_array.is_empty() {
    self.xml.write_attribute(
      "stroke-dasharray",
      stroke_props.dash_array.map(f32_str).join(","),
    )
  }
}

///|
fn SvgRenderer::with_group(
  self : SvgRenderer,
  mask : @interpret.SoftMask?,
  blend_mode : @interpret.BlendMode,
  func : (SvgRenderer) -> Unit,
) -> Unit {
  let push_group = mask is Some(_) ||
    blend_mode != Normal ||
    !self.active_clips.is_empty()
  if push_group {
    self.push_transparency_group_impl(1.0, mask, blend_mode)
  }
  func(self)
  if push_group {
    self.pop_transparency_group_impl()
  }
}

///|
impl @interpret.Device for SvgRenderer with fn draw_path(
  self,
  path,
  props,
  draw_mode,
) {
  self.with_group(props.soft_mask, props.blend_mode, r => {
    r.draw_path_impl(path, props, draw_mode)
  })
}

///|
impl @interpret.Device for SvgRenderer with fn draw_rect(
  self,
  rect,
  props,
  draw_mode,
) {
  self.with_group(props.soft_mask, props.blend_mode, r => {
    r.draw_rect_impl(rect, props, draw_mode)
  })
}

///|
impl @interpret.Device for SvgRenderer with fn push_clip_path(self, clip_path) {
  let parent = self.active_clips.last()
  let key = @interpret.hash128(h => {
    h.write_u128(@interpret.CacheKey::cache_key(clip_path))
    match parent {
      Some(p) => {
        h.write_u8(b'\x01')
        h.write_u32(p.kind.to_uint())
        h.write_usize(p.index)
      }
      None => h.write_u8(b'\x00')
    }
  })
  let clip_id = self.clip_paths.insert_with(key, () => {
    CachedClipPath::Path(
      path=clip_path.path.clone(),
      fill_rule=clip_path.fill,
      parent~,
    )
  })
  self.active_clips.push(clip_id)
}

///|
impl @interpret.Device for SvgRenderer with fn push_clip_rect(self, rect) {
  let parent = self.active_clips.last()
  let key = @interpret.hash128(h => {
    h.write_u128(@interpret.CacheKey::cache_key(rect))
    match parent {
      Some(p) => {
        h.write_u8(b'\x01')
        h.write_u32(p.kind.to_uint())
        h.write_usize(p.index)
      }
      None => h.write_u8(b'\x00')
    }
  })
  let clip_id = self.clip_paths.insert_with(key, () => {
    CachedClipPath::Rect(rect~, parent~)
  })
  self.active_clips.push(clip_id)
}

///|
impl @interpret.Device for SvgRenderer with fn push_transparency_group(
  self,
  opacity,
  mask,
  blend_mode,
) {
  self.push_transparency_group_impl(opacity, mask, blend_mode)
}

///|
fn SvgRenderer::push_transparency_group_impl(
  self : SvgRenderer,
  opacity : Float,
  mask : @interpret.SoftMask?,
  blend_mode : @interpret.BlendMode,
) -> Unit {
  self.push_transparency_group_inner(
    opacity,
    match mask {
      Some(m) => Some(MaskKind::SoftMask(m))
      None => None
    },
    blend_mode,
  )
}

///|
impl @interpret.Device for SvgRenderer with fn draw_glyph(
  self,
  glyph,
  glyph_transform,
  props,
  draw_mode,
) {
  self.with_group(props.soft_mask, props.blend_mode, r => {
    r.draw_glyph_impl(glyph, glyph_transform, props, draw_mode)
  })
}

///|
impl @interpret.Device for SvgRenderer with fn draw_image(self, image, props) {
  self.with_group(props.soft_mask, props.blend_mode, r => {
    let mut transform = props.transform
    match image {
      Stencil(s) =>
        s.with_stencil(
          (s, paint) => {
            transform = transform *
              @kurbo.Affine::scale_non_uniform(
                s.scale_factors.0.to_double(),
                s.scale_factors.1.to_double(),
              )
            r.draw_stencil_image(s, transform, paint)
          },
          None,
        )
      Raster(raster) =>
        raster.with_rgba(
          (image, alpha) => {
            let (sx, sy) = image.scale_factors()
            transform = transform *
              @kurbo.Affine::scale_non_uniform(sx.to_double(), sy.to_double())
            r.draw_rgba_image(image, transform, alpha)
          },
          None,
        )
    }
  })
}

///|
impl @interpret.Device for SvgRenderer with fn pop_clip(self) {
  let _ = self.active_clips.pop()
}

///|
impl @interpret.Device for SvgRenderer with fn pop_transparency_group(self) {
  self.pop_transparency_group_impl()
}

///|
fn SvgRenderer::pop_transparency_group_impl(self : SvgRenderer) -> Unit {
  self.xml.end_element()
}

///|
fn SvgRenderer::new(
  page : @hayro_syntax.Page,
  render_settings : SvgRenderSettings,
) -> SvgRenderer {
  {
    render_settings,
    xml: @xmlwriter.XmlWriter::new(@xmlwriter.Options::default()),
    outline_glyphs: Deduplicator::new('g'),
    type3_glyphs: Deduplicator::new('e'),
    clip_paths: Deduplicator::new('c'),
    masks: Deduplicator::new('m'),
    shadings: Deduplicator::new('s'),
    gradients: Deduplicator::new('n'),
    shading_patterns: Deduplicator::new('v'),
    tiling_patterns: Deduplicator::new('t'),
    active_clips: [],
    dimensions: page.render_dimensions(),
  }
}

///|
fn SvgRenderer::write_header(self : SvgRenderer, size : (Float, Float)) -> Unit {
  let bg_color = self.render_settings.bg_color
  self.xml.start_element("svg")
  self.xml.write_attribute(
    "viewBox",
    "0 0 \{f32_str(size.0)} \{f32_str(size.1)}",
  )
  self.xml.write_attribute("width", f32_str(size.0))
  self.xml.write_attribute("height", f32_str(size.1))
  self.xml.write_attribute("xmlns", "http://www.w3.org/2000/svg")
  self.xml.write_attribute("xmlns:xlink", "http://www.w3.org/1999/xlink")
  if bg_color[3] > 0 {
    self.xml.write_attribute(
      "style",
      "background-color: rgba(\{bg_color[0]}, \{bg_color[1]}, \{bg_color[2]}, \{bg_color[3]});",
    )
  }
}

///|
// We need this because we have a small problem. `xmlwriter` doesn't allow us to write sub-streams
// of XML while we are writing our main stream. This means that objects that need to be interpreted
// (like patterns or mask) all need to be written to the XML in the end. On the other hand, once
// we get to `finish` all of the registerd resources must already have been registered. This isn't
// the case if masks or patterns use new resources that haven't been registered before. As a result,
fn SvgRenderer::with_dummy(
  self : SvgRenderer,
  f : (SvgRenderer) -> Unit,
) -> Unit {
  let old_xml = self.xml
  self.xml = @xmlwriter.XmlWriter::new(@xmlwriter.Options::default())
  f(self)
  self.xml = old_xml
}

///|
fn SvgRenderer::finish(self : SvgRenderer) -> String {
  self.write_glyph_defs()
  self.write_mask_defs()
  self.write_clip_path_defs()
  self.write_shading_defs()
  self.write_native_gradient_defs()
  self.write_shading_pattern_defs()
  self.write_tiling_pattern_defs()
  // Close the `svg` element.
  self.xml.end_element()
  self.xml.end_document()
}

///|
fn convert_transform(transform : @kurbo.Affine) -> String {
  transform.as_coeffs().iter().map(c => f32_str(c.to_float())).join(" ")
}

///|
priv struct Deduplicator[T] {
  kind : Char
  vec : Array[T]
  present : Map[@interpret.U128, Id]
}

///|
fn[T] Deduplicator::new(kind : Char) -> Deduplicator[T] {
  { kind, vec: [], present: {}, }
}

///|
fn[T] Deduplicator::contains(
  self : Deduplicator[T],
  hash : @interpret.U128,
) -> Bool {
  self.present.contains(hash)
}

///|
fn[T] Deduplicator::insert_with(
  self : Deduplicator[T],
  hash : @interpret.U128,
  f : () -> T,
) -> Id {
  match self.present.get(hash) {
    Some(id) => id
    None => {
      let index = self.vec.length()
      self.vec.push(f())
      let id = { kind: self.kind, index, }
      self.present[hash] = id
      id
    }
  }
}

///|
fn[T] Deduplicator::insert(self : Deduplicator[T], value : T) -> Id {
  let index = self.vec.length()
  self.vec.push(value)
  { kind: self.kind, index, }
}

///|
fn[T] Deduplicator::iter(self : Deduplicator[T]) -> Array[(Id, T)] {
  self.vec.mapi((i, v) => ({ kind: self.kind, index: i, }, v))
}

///|
fn[T] Deduplicator::is_empty(self : Deduplicator[T]) -> Bool {
  self.vec.is_empty()
}

///|
priv struct Id {
  kind : Char
  index : Int
}

///|
impl Show for Id with fn output(self, logger) {
  logger.write_char(self.kind)
  logger.write_string(self.index.to_string())
}

///|
/// Rust's `impl Display for f32`.
fn f32_str(x : Float) -> String {
  rust_display_f32(x)
}

///|
/// Rust's `impl Display for f64`.
fn f64_str(x : Double) -> String {
  rust_display_f64(x)
}
