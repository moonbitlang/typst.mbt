// Port of `vello_cpu/src/render.rs`, `vello_cpu/src/dispatch/single_threaded.rs`
// and `vello_cpu/src/region.rs` (single-threaded, `u8` pipeline, no filters,
// no text).

///|
/// A render context for CPU-based 2D graphics rendering.
///
/// This is the main entry point for drawing operations. It maintains the
/// current rendering state (transforms, paint, stroke, etc.) and dispatches
/// drawing commands to the underlying rasterization engine.
pub struct RenderContext {
  /// Width of the render target in pixels.
  priv width : Int
  /// Height of the render target in pixels.
  priv height : Int
  // The current rendering state (`RenderState`).
  priv mut paint : PaintType
  priv mut paint_transform : @kurbo.Affine
  priv mut stroke : @kurbo.Stroke
  priv mut transform : @kurbo.Affine
  priv mut fill_rule : Fill
  priv mut blend_mode : BlendMode
  /// The current mask in place.
  priv mut mask : Mask?
  /// Optional threshold for aliasing.
  priv mut aliasing_threshold : Int?
  priv encoded_paints : Array[EncodedPaint]
  // The dispatcher (`SingleThreadedDispatcher`).
  priv clip_state : ClipState
  priv recorder : CommandRecorder
  priv strip_generator : StripGenerator
  priv strip_storage : StripStorage
}

///|
/// Create a new render context with the given width and height in pixels.
pub fn RenderContext::new(width : Int, height : Int) -> RenderContext {
  {
    width,
    height,
    paint: Solid(black),
    paint_transform: @kurbo.Affine::identity(),
    stroke: {
      width: 1.0,
      join: Bevel,
      miter_limit: 4.0,
      start_cap: Butt,
      end_cap: Butt,
      dash_pattern: [],
      dash_offset: 0.0,
    },
    transform: @kurbo.Affine::identity(),
    fill_rule: NonZero,
    blend_mode: BlendMode::default(),
    mask: None,
    aliasing_threshold: None,
    encoded_paints: [],
    clip_state: ClipState::new(),
    recorder: CommandRecorder::new(),
    strip_generator: StripGenerator::new(width, height),
    strip_storage: StripStorage::new(Append),
  }
}

///|
fn RenderContext::encode_current_paint(self : RenderContext) -> Paint {
  match self.paint {
    Solid(s) => Paint::Solid(PremulColor::from_alpha_color(s))
    Gradient(g) =>
      g.encode_into(self.encoded_paints, self.effective_paint_transform())
    Image(i) =>
      i.encode_into(self.encoded_paints, self.effective_paint_transform())
  }
}

///|
fn RenderContext::effective_path_transform(self : RenderContext) -> @kurbo.Affine {
  // The root transform stack only contains the identity (no filter layers).
  @kurbo.Affine::identity() * self.transform
}

///|
fn RenderContext::effective_paint_transform(self : RenderContext) -> @kurbo.Affine {
  self.effective_path_transform() * self.paint_transform
}

///|
fn RenderContext::record_fill(
  self : RenderContext,
  strip_start : Int,
  paint : Paint,
) -> Unit {
  let strip_end = self.strip_storage.strips.length()
  self.recorder.push_fill(
    strip_start,
    strip_end,
    paint,
    self.blend_mode,
    self.mask,
  )
}

///|
/// Fill a path.
pub fn RenderContext::fill_path(self : RenderContext, path : @kurbo.BezPath) -> Unit {
  let paint = self.encode_current_paint()
  let transform = self.effective_path_transform()
  let clip_path = self.clip_state.get()
  let strip_start = self.strip_storage.strips.length()
  self.strip_generator.generate_filled_path(
    path.elements(),
    self.fill_rule,
    transform,
    self.aliasing_threshold,
    self.strip_storage,
    clip_path,
  )
  self.record_fill(strip_start, paint)
}

///|
/// Stroke a path.
pub fn RenderContext::stroke_path(self : RenderContext, path : @kurbo.BezPath) -> Unit {
  let paint = self.encode_current_paint()
  let transform = self.effective_path_transform()
  let clip_path = self.clip_state.get()
  let strip_start = self.strip_storage.strips.length()
  self.strip_generator.generate_stroked_path(
    path.elements(),
    self.stroke,
    transform,
    self.aliasing_threshold,
    self.strip_storage,
    clip_path,
  )
  self.record_fill(strip_start, paint)
}

///|
/// Fill a rectangle.
pub fn RenderContext::fill_rect(self : RenderContext, rect : @kurbo.Rect) -> Unit {
  let paint = self.encode_current_paint()
  let transform = self.effective_path_transform()
  let clip_path = self.clip_state.get()
  let strip_start = self.strip_storage.strips.length()
  // Fast path: Use optimized rect filling if we have no skew in the path
  // transform and anti-aliasing is enabled.
  if is_axis_aligned(transform) && self.aliasing_threshold is None {
    // Transform the rect to screen coordinates.
    let transformed_rect = transform.transform_rect_bbox(rect)
    self.strip_generator.generate_filled_rect_fast(
      transformed_rect,
      self.strip_storage,
      clip_path,
    )
  } else {
    // Fall back to path-based rendering for rotated/skewed transforms.
    let temp_path : Array[@kurbo.PathEl] = [
      MoveTo(@kurbo.Point::new(rect.x0, rect.y0)),
      LineTo(@kurbo.Point::new(rect.x1, rect.y0)),
      LineTo(@kurbo.Point::new(rect.x1, rect.y1)),
      LineTo(@kurbo.Point::new(rect.x0, rect.y1)),
      ClosePath,
    ]
    self.strip_generator.generate_filled_path(
      temp_path,
      self.fill_rule,
      transform,
      self.aliasing_threshold,
      self.strip_storage,
      clip_path,
    )
  }
  self.record_fill(strip_start, paint)
}

///|
/// Check if an affine transform has no skewing (i.e. preserves axis
/// alignment).
fn is_axis_aligned(transform : @kurbo.Affine) -> Bool {
  let c = transform.as_coeffs()
  f64_is_nearly_zero(c[1]) && f64_is_nearly_zero(c[2])
}

///|
/// Push a new layer with the given properties.
///
/// Note that the mask, if provided, needs to have the same size as the
/// render context. Otherwise, it will be ignored. Layer clip paths are not
/// supported.
pub fn RenderContext::push_layer(
  self : RenderContext,
  blend_mode : BlendMode?,
  opacity : Float?,
  mask : Mask?,
) -> Unit {
  let mask = match mask {
    Some(m) if m.width() != self.width || m.height() != self.height => None
    m => m
  }
  let blend_mode = blend_mode.unwrap_or(BlendMode::default())
  let opacity = opacity.unwrap_or(1.0)
  self.recorder.push_layer({ blend_mode, opacity, mask })
}

///|
/// Push a new mask layer.
pub fn RenderContext::push_mask_layer(self : RenderContext, mask : Mask) -> Unit {
  self.push_layer(None, None, Some(mask))
}

///|
/// Set the aliasing threshold.
///
/// If set to `None` (which is the recommended option in nearly all cases),
/// anti-aliasing will be applied.
pub fn RenderContext::set_aliasing_threshold(
  self : RenderContext,
  aliasing_threshold : Int?,
) -> Unit {
  self.aliasing_threshold = aliasing_threshold
}

///|
/// Pop the last-pushed layer.
pub fn RenderContext::pop_layer(self : RenderContext) -> Unit {
  self.recorder.pop_layer()
}

///|
/// Set the current stroke.
pub fn RenderContext::set_stroke(self : RenderContext, stroke : @kurbo.Stroke) -> Unit {
  self.stroke = stroke
}

///|
/// Get the current stroke.
pub fn RenderContext::stroke(self : RenderContext) -> @kurbo.Stroke {
  self.stroke
}

///|
/// Set the current paint.
pub fn RenderContext::set_paint(self : RenderContext, paint : PaintType) -> Unit {
  self.paint = paint
}

///|
/// Set the blend mode that should be used when drawing objects.
pub fn RenderContext::set_blend_mode(
  self : RenderContext,
  blend_mode : BlendMode,
) -> Unit {
  self.blend_mode = blend_mode
}

///|
/// Get the currently active blend mode.
pub fn RenderContext::blend_mode(self : RenderContext) -> BlendMode {
  self.blend_mode
}

///|
/// Set the current paint transform.
pub fn RenderContext::set_paint_transform(
  self : RenderContext,
  paint_transform : @kurbo.Affine,
) -> Unit {
  self.paint_transform = paint_transform
}

///|
/// Set the current fill rule.
pub fn RenderContext::set_fill_rule(self : RenderContext, fill_rule : Fill) -> Unit {
  self.fill_rule = fill_rule
}

///|
/// Get the current fill rule.
pub fn RenderContext::fill_rule(self : RenderContext) -> Fill {
  self.fill_rule
}

///|
/// Set the mask to use for path-painting operations.
pub fn RenderContext::set_mask(self : RenderContext, mask : Mask) -> Unit {
  self.mask = Some(mask)
}

///|
/// Reset the mask that is used for path-painting operations.
pub fn RenderContext::reset_mask(self : RenderContext) -> Unit {
  self.mask = None
}

///|
/// Set the current transform.
pub fn RenderContext::set_transform(
  self : RenderContext,
  transform : @kurbo.Affine,
) -> Unit {
  self.transform = transform
}

///|
/// Get the current transform.
pub fn RenderContext::transform(self : RenderContext) -> @kurbo.Affine {
  self.transform
}

///|
/// Push a new clip path to the clip stack.
pub fn RenderContext::push_clip_path(
  self : RenderContext,
  path : @kurbo.BezPath,
) -> Unit {
  // Unlike `effective_path_transform`, we are not applying the root
  // transform here because clipping handles this separately.
  let transform = self.transform
  self.clip_state.push_clip(
    path,
    self.strip_generator,
    self.fill_rule,
    transform,
    self.aliasing_threshold,
  )
}

///|
/// Pop a clip path from the clip stack.
pub fn RenderContext::pop_clip_path(self : RenderContext) -> Unit {
  self.clip_state.pop_clip()
}

///|
/// Flush any pending operations (a no-op when rendering single-threaded).
pub fn RenderContext::flush(_self : RenderContext) -> Unit {
  ()
}

///|
/// Return the width of the scene.
pub fn RenderContext::width(self : RenderContext) -> Int {
  self.width
}

///|
/// Return the height of the scene.
pub fn RenderContext::height(self : RenderContext) -> Int {
  self.height
}

///|
/// Render the current context into a pixmap (replacing its contents).
pub fn RenderContext::render(self : RenderContext, target : Pixmap) -> Unit {
  guard !self.recorder.has_layers() else {
    abort("some layers haven't been popped yet")
  }
  let target_fully_covered = self.width >= target.width &&
    self.height >= target.height
  // If the scene covers the whole pixmap than packing will take care of
  // clearing everything anyway.
  if !target_fully_covered {
    target.buf.fill(b'\x00')
  }
  // `rasterize_u8` / `bucket_and_rasterize`.
  let bucketer = CommandBucketer::from_wh(self.width, self.height)
  bucketer.bucket_commands(
    self.recorder.root_cmds,
    self.recorder.layers,
    self.strip_storage.strips,
  )
  let resources = {
    alphas: self.strip_storage.alphas,
    encoded_paints: self.encoded_paints,
  }
  // `Regions::new`.
  let width = min_int(self.width, target.width)
  let height = min_int(self.height, target.height)
  if width == 0 || height == 0 {
    return
  }
  let row_count = min_int(bucketer.rows.length(), div_ceil(height, TILE_HEIGHT))
  let stride = target.width * 4
  let fine = Fine::new(bucketer.width())
  for row_idx in 0..<row_count {
    let row_y = row_idx * TILE_HEIGHT
    let row_height = min_int(height - row_y, TILE_HEIGHT)
    let region = {
      row_idx,
      width,
      height: row_height,
      buf: target.buf,
      stride,
      offset: row_y * stride,
    }
    rasterize_region(fine, region, bucketer, resources)
  }
}
