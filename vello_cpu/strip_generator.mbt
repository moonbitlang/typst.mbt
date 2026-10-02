// Port of `vello_common/src/strip_generator.rs`.

///|
/// How strips are written into a [`StripStorage`].
priv enum GenerationMode {
  /// Clear the strips before generating new ones.
  Replace
  /// Append generated strips to the existing ones.
  Append
}

///|
/// A storage for storing strip-related data.
priv struct StripStorage {
  /// The strips in the storage.
  strips : Array[Strip]
  /// The alphas in the storage.
  alphas : Array[Byte]
  generation_mode : GenerationMode
}

///|
fn StripStorage::new(generation_mode : GenerationMode) -> StripStorage {
  { strips: [], alphas: [], generation_mode, }
}

///|
fn StripStorage::clear(self : StripStorage) -> Unit {
  self.strips.clear()
  self.alphas.clear()
}

///|
fn StripStorage::append(self : StripStorage, other : StripStorage) -> Unit {
  for s in other.strips {
    self.strips.push(s)
  }
  for a in other.alphas {
    self.alphas.push(a)
  }
}

///|
/// An object for easily generating strips for a filled/stroked path.
priv struct StripGenerator {
  line_buf : Array[Line]
  flatten_ctx : FlattenCtx
  stroke_ctx : @kurbo.StrokeCtx
  temp_storage : StripStorage
  tiles : Tiles
  width : Int
  height : Int
}

///|
fn StripGenerator::new(width : Int, height : Int) -> StripGenerator {
  {
    line_buf: [],
    tiles: Tiles::new(height),
    flatten_ctx: FlattenCtx::new(),
    stroke_ctx: @kurbo.StrokeCtx::new(),
    temp_storage: StripStorage::new(Replace),
    width,
    height,
  }
}

///|
/// Generate the strips for a filled path.
fn StripGenerator::generate_filled_path(
  self : StripGenerator,
  path : Array[@kurbo.PathEl],
  fill_rule : Fill,
  transform : @kurbo.Affine,
  aliasing_threshold : Int?,
  strip_storage : StripStorage,
  clip_path : PathDataRef?,
) -> Unit {
  let cull_bbox = match clip_path {
    Some(clip_path) => clip_path.bbox
    None => RectU16::new(0, 0, self.width, self.height)
  }
  fill(path, transform, self.line_buf, self.flatten_ctx, cull_bbox)
  self.generate_with_clip(
    aliasing_threshold, strip_storage, fill_rule, clip_path,
  )
}

///|
/// Generate the strips for a stroked path.
fn StripGenerator::generate_stroked_path(
  self : StripGenerator,
  path : Array[@kurbo.PathEl],
  stroke : @kurbo.Stroke,
  transform : @kurbo.Affine,
  aliasing_threshold : Int?,
  strip_storage : StripStorage,
  clip_path : PathDataRef?,
) -> Unit {
  let cull_bbox = match clip_path {
    Some(clip_path) => clip_path.bbox
    None => RectU16::new(0, 0, self.width, self.height)
  }
  // `flatten::stroke`.
  // TODO: Temporary hack to ensure that strokes are scaled properly by the
  // transform.
  let c = transform.as_coeffs()
  let tolerance = TOL / dmax(dmax(c[0].abs(), c[3].abs()), 1.0)
  let expanded = expand_stroke(path, stroke, tolerance, self.stroke_ctx)
  fill(expanded, transform, self.line_buf, self.flatten_ctx, cull_bbox)
  self.generate_with_clip(aliasing_threshold, strip_storage, NonZero, clip_path)
}

///|
fn StripGenerator::generate_with_clip(
  self : StripGenerator,
  aliasing_threshold : Int?,
  strip_storage : StripStorage,
  fill_rule : Fill,
  clip_path : PathDataRef?,
) -> Unit {
  let _ = self.tiles.make_tiles_analytic_aa(
    self.line_buf,
    self.width,
    self.height,
  )
  self.tiles.sort_tiles()
  let tiles = self.tiles
  let line_buf = self.line_buf
  render_with_clip(self.temp_storage, strip_storage, clip_path, (strips, alphas) => {
    render_strips(
      tiles, strips, alphas, fill_rule, aliasing_threshold, line_buf,
    )
  })
}

///|
/// Generate the strips for a rectangle that is already in screen
/// coordinates.
fn StripGenerator::generate_filled_rect_fast(
  self : StripGenerator,
  rect : @kurbo.Rect,
  strip_storage : StripStorage,
  clip_path : PathDataRef?,
) -> Unit {
  let viewport = @kurbo.Rect::new(
    0.0,
    0.0,
    self.width.to_double(),
    self.height.to_double(),
  )
  let clip_bbox = match clip_path {
    Some(clip) =>
      @kurbo.Rect::new(
        clip.bbox.x0.to_double(),
        clip.bbox.y0.to_double(),
        clip.bbox.x1.to_double(),
        clip.bbox.y1.to_double(),
      )
    None => viewport
  }
  let clamped = rect.abs().intersect(clip_bbox)
  render_with_clip(self.temp_storage, strip_storage, clip_path, (strips, alphas) => {
    render_rect(clamped, strips, alphas)
  })
}

///|
fn render_with_clip(
  temp_storage : StripStorage,
  strip_storage : StripStorage,
  clip_path : PathDataRef?,
  render_fn : (Array[Strip], Array[Byte]) -> Unit,
) -> Unit {
  match strip_storage.generation_mode {
    Replace => strip_storage.strips.clear()
    Append => ()
  }
  match clip_path {
    Some(clip_path) => {
      temp_storage.clear()
      render_fn(temp_storage.strips, temp_storage.alphas)
      let path_data = {
        strips: temp_storage.strips,
        strip_start: 0,
        strip_end: temp_storage.strips.length(),
        alphas: temp_storage.alphas,
        alpha_start: 0,
        bbox: RectU16::new(0, 0, 65535, 65535),
      }
      intersect(clip_path, path_data, strip_storage)
    }
    None => render_fn(strip_storage.strips, strip_storage.alphas)
  }
}
