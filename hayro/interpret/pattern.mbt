// Port of `hayro-interpret/src/pattern.rs`: PDF patterns.

///|
/// A PDF pattern.
pub(all) enum Pattern {
  /// A shading pattern.
  Shading(ShadingPattern)
  /// A tiling pattern.
  Tiling(TilingPattern)
}

///|
fn Pattern::new(
  object : @hayro_syntax.Object,
  ctx : Context,
  resources : @hayro_syntax.Resources,
) -> Pattern? {
  match object {
    Dict(dict) =>
      match
        ShadingPattern::new(
          dict,
          ctx.interpreter_cache.object_cache,
          ctx.get().graphics_state.non_stroke_alpha,
        ) {
        Some(p) => Some(Shading(p))
        None => None
      }
    Stream(stream) =>
      match TilingPattern::new(stream, ctx, resources) {
        Some(p) => Some(Tiling(p))
        None => None
      }
    _ => None
  }
}

///|
/// Pre-concatenate a transform (returns the updated pattern; upstream
/// mutates a clone).
fn Pattern::pre_concat_transform(
  self : Pattern,
  transform : @kurbo.Affine,
) -> Pattern {
  match self {
    Shading(p) => {
      let matrix = transform * p.matrix
      let transformed_clip_path = match p.shading.clip_path {
        Some(r) => Some(r.transform(matrix))
        None => None
      }
      Shading({
        ..p,
        matrix,
        shading: { ..p.shading, clip_path: transformed_clip_path, },
      })
    }
    Tiling(p) => Tiling({ ..p, matrix: transform * p.matrix, })
  }
}

///|
/// Set the transfer function (returns the updated pattern).
fn Pattern::with_transfer_function(
  self : Pattern,
  tf : ActiveTransferFunction,
) -> Pattern {
  match self {
    Shading(p) => Shading({ ..p, transfer_function: Some(tf), })
    Tiling(_) => self
  }
}

///|
pub impl CacheKey for Pattern with fn cache_key(self) {
  match self {
    Shading(p) => CacheKey::cache_key(p)
    Tiling(p) => CacheKey::cache_key(p)
  }
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Pattern with CacheKey::{cache_key}

///|
/// A shading pattern.
pub(all) struct ShadingPattern {
  /// The underlying shading of the pattern.
  shading : Shading
  /// A transformation matrix to apply prior to rendering.
  matrix : @kurbo.Affine
  /// An additional opacity to apply to the shading pattern.
  opacity : Float
  /// An optional transfer function to apply to the shading's output colors.
  transfer_function : ActiveTransferFunction?
}

///|
fn ShadingPattern::new(
  dict : @hayro_syntax.Dict,
  cache : Cache,
  opacity : Float,
) -> ShadingPattern? {
  let shading = match (dict.get("Shading") : @hayro_syntax.Object?) {
    Some(o) =>
      match @hayro_syntax.dict_or_stream(o) {
        Some((dict, stream)) => Shading::new(dict, stream, cache)
        None => None
      }
    None => None
  }
  guard shading is Some(shading) else { return None }
  let matrix = match (dict.get_fixed("Matrix", 6) : Array[Double]?) {
    Some(m) => @kurbo.Affine::new(FixedArray::from_array(m))
    None => @kurbo.Affine::identity()
  }
  if dict.contains_key("ExtGState") {
    // warn!("shading patterns with ext_g_state are not supported yet");
    ()
  }
  Some({ shading, opacity, matrix, transfer_function: None, })
}

///|
pub impl CacheKey for ShadingPattern with fn cache_key(self) {
  hash128_keys([
    CacheKey::cache_key(self.shading),
    CacheKey::cache_key(self.matrix),
  ])
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ShadingPattern with CacheKey::{cache_key}

///|
/// A tiling pattern.
pub(all) struct TilingPattern {
  priv cache_key : U128
  priv ctx_bbox : @kurbo.Rect
  /// The bbox of the tiling pattern.
  bbox : @kurbo.Rect
  /// The step in the x direction.
  x_step : Float
  /// The step in the y direction.
  y_step : Float
  /// A transformation to apply prior to rendering.
  matrix : @kurbo.Affine
  priv stream : @hayro_syntax.Stream
  priv is_color : Bool
  priv stroke_paint : Color
  priv non_stroking_paint : Color
  priv parent_resources : @hayro_syntax.Resources
  priv cache : InterpreterCache
  priv settings : InterpreterSettings
  priv xref : @hayro_syntax.XRef
  priv nesting_depth : Int
}

///|
fn TilingPattern::new(
  stream : @hayro_syntax.Stream,
  ctx : Context,
  resources : @hayro_syntax.Resources,
) -> TilingPattern? {
  let cache_key = CacheKey::cache_key(stream)
  let dict = stream.dict()
  guard (dict.get("BBox") : @hayro_syntax.Rect?) is Some(bbox) else {
    return None
  }
  let bbox = rect_to_kurbo(bbox)
  guard (dict.get("XStep") : Float?) is Some(x_step) else { return None }
  guard (dict.get("YStep") : Float?) is Some(y_step) else { return None }
  if f32_is_nearly_zero(x_step) ||
    f32_is_nearly_zero(y_step) ||
    bbox.is_zero_area() {
    return None
  }
  guard (dict.get("PaintType") : Byte?) is Some(paint_type) else { return None }
  let is_color = paint_type == 1
  let matrix = match (dict.get_fixed("Matrix", 6) : Array[Double]?) {
    Some(m) => @kurbo.Affine::new(FixedArray::from_array(m))
    None => @kurbo.Affine::identity()
  }
  let state = ctx.get().clone()
  let ctx_bbox = ctx.bbox()
  let fill_cs = state.graphics_state.none_stroke_cs
    .pattern_cs()
    .unwrap_or(ColorSpace::device_gray())
  let stroke_cs = state.graphics_state.stroke_cs
    .pattern_cs()
    .unwrap_or(ColorSpace::device_gray())
  let non_stroking_paint = Color::new(
    fill_cs,
    state.graphics_state.non_stroke_color,
    state.graphics_state.non_stroke_alpha,
  )
  let stroke_paint = Color::new(
    stroke_cs,
    state.graphics_state.stroke_color,
    state.graphics_state.stroke_alpha,
  )
  let nesting_depth = ctx.nesting_depth() + 1
  Some({
    cache_key,
    bbox,
    x_step,
    y_step,
    matrix,
    ctx_bbox,
    is_color,
    stream,
    stroke_paint,
    non_stroking_paint,
    settings: ctx.settings,
    parent_resources: resources,
    cache: ctx.interpreter_cache,
    xref: ctx.xref,
    nesting_depth,
  })
}

///|
/// Interpret the contents of the pattern into the given device.
pub fn TilingPattern::interpret(
  self : TilingPattern,
  device : &Device,
  initial_transform : @kurbo.Affine,
  is_stroke : Bool,
) -> Unit? {
  let state = State::new(initial_transform)
  let context = Context::new_with(
    state.ctm,
    // TODO: bbox?
    self.ctx_bbox.to_path(0.1).transform(initial_transform).bounding_box(),
    self.cache,
    self.xref,
    self.settings,
    state,
    self.nesting_depth,
  )
  guard self.stream.decoded() is Ok(decoded) else { return None }
  let resources = @hayro_syntax.Resources::from_parent(
    (self.stream.dict().get("Resources") : @hayro_syntax.Dict?).unwrap_or(
      @hayro_syntax.Dict::empty(),
    ),
    self.parent_resources,
  )
  let iter = @hayro_syntax.TypedIter::new(decoded)
  let clip_path = {
    path: self.bbox.to_path(0.1).transform(initial_transform),
    fill: NonZero,
  }
  device.push_clip_path(clip_path)
  if self.is_color {
    interpret(iter, resources, context, device)
  } else {
    let paint = if !is_stroke {
      Paint::Color(self.non_stroking_paint)
    } else {
      Paint::Color(self.stroke_paint)
    }
    let device = StencilPatternDevice::new(device, paint)
    interpret(iter, resources, context, device)
  }
  device.pop_clip()
  Some(())
}

///|
pub impl CacheKey for TilingPattern with fn cache_key(self) {
  self.cache_key
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TilingPattern with CacheKey::{cache_key}

///|
priv struct StencilPatternDevice {
  inner : &Device
  paint : Paint
}

///|
fn StencilPatternDevice::new(
  device : &Device,
  paint : Paint,
) -> StencilPatternDevice {
  { inner: device, paint, }
}

// Only filling, stroking of paths and stencil masks are allowed.

///|
impl Device for StencilPatternDevice with fn draw_path(
  self,
  path,
  props,
  draw_mode,
) {
  self.inner.draw_path(path, { ..props, paint: self.paint, }, draw_mode)
}

///|
impl Device for StencilPatternDevice with fn push_clip_path(self, clip_path) {
  self.inner.push_clip_path(clip_path)
}

///|
impl Device for StencilPatternDevice with fn push_transparency_group(_, _, _, _) {
  ()
}

///|
impl Device for StencilPatternDevice with fn draw_glyph(
  self,
  g,
  glyph_transform,
  props,
  draw_mode,
) {
  self.inner.draw_glyph(g, glyph_transform, props, draw_mode)
}

///|
impl Device for StencilPatternDevice with fn draw_image(self, image, props) {
  if image is Stencil(s) {
    self.inner.draw_image(Stencil({ ..s, paint: self.paint, }), props)
  }
}

///|
impl Device for StencilPatternDevice with fn pop_clip(self) {
  self.inner.pop_clip()
}

///|
impl Device for StencilPatternDevice with fn pop_transparency_group(_) {
  ()
}
