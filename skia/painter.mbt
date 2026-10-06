// Port of `tiny-skia/src/painter.rs`.

///|
/// A path filling rule.
pub(all) enum FillRule {
  /// Specifies that "inside" is computed by a non-zero sum of signed edge
  /// crossings.
  Winding
  /// Specifies that "inside" is computed by an odd number of edge crossings.
  EvenOdd
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FillRule with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FillRule with @debug.Debug::{to_repr}

///|
pub impl Default for FillRule with fn default() {
  Winding
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FillRule with Default::{default}

///|
/// Controls how a shape should be painted.
pub(all) struct Paint {
  /// A paint shader. Default: black color
  mut shader : Shader
  /// Paint blending mode. Default: SourceOver
  mut blend_mode : BlendMode
  /// Enables anti-aliased painting. Default: true
  mut anti_alias : Bool
  /// Colorspace for blending (gamma correction). Default: Linear
  mut colorspace : ColorSpace
  /// Forces the high quality/precision rendering pipeline. Default: false
  mut force_hq_pipeline : Bool
}

///|
pub impl Default for Paint with fn default() {
  {
    shader: SolidColor(color_black),
    blend_mode: SourceOver,
    anti_alias: true,
    colorspace: Linear,
    force_hq_pipeline: false,
  }
}

///|
pub extend Paint with Default::{default}

///|
/// Returns a copy of the paint.
pub fn Paint::clone(self : Paint) -> Paint {
  { ..self, }
}

///|
/// Sets a paint source to a solid color.
pub fn Paint::set_color(self : Paint, color : Color) -> Unit {
  self.shader = SolidColor(color)
}

///|
/// Sets a paint source to a solid color.
pub fn Paint::set_color_rgba8(
  self : Paint,
  r : Int,
  g : Int,
  b : Int,
  a : Int,
) -> Unit {
  self.set_color(Color::from_rgba8(r, g, b, a))
}

///|
/// Checks that the paint source is a solid color.
pub fn Paint::is_solid_color(self : Paint) -> Bool {
  self.shader is SolidColor(_)
}

///|
/// Draws a filled rectangle onto the pixmap.
///
/// This function is usually slower than filling a rectangular path, but it
/// produces better results. Mainly it doesn't suffer from weird clipping of
/// horizontal/vertical edges.
///
/// Used mainly to render a pixmap onto a pixmap.
///
/// Returns `None` when there is nothing to fill or in case of a numeric
/// overflow.
fn Pixmap::fill_rect_impl(
  self : Pixmap,
  rect : @path.Rect,
  paint : Paint,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  // TODO: we probably can use tiler for rect too
  if transform.is_identity() &&
    !DrawTiler::required(self.width(), self.height()) {
    // TODO: ignore rects outside the pixmap
    let clip = int_size_to_screen_int_rect(self.size, 0, 0)
    let mask = mask.map(m => m.as_submask())
    let subpix = self.as_subpixmap()
    guard RasterPipelineBlitter::new(paint, mask, subpix) is Some(blitter) else { // nothing to do, all good
      return
    }
    if paint.anti_alias {
      scan_fill_rect_aa(rect, clip, blitter)
    } else {
      scan_fill_rect(rect, clip, blitter)
    }
  } else {
    let path = @path.PathBuilder::from_rect(rect)
    self.fill_path_impl(path, paint, Winding, transform, mask)
  }
}

///|
/// Draws a filled path onto the pixmap.
fn Pixmap::fill_path_impl(
  self : Pixmap,
  path : @path.Path,
  paint : Paint,
  fill_rule : FillRule,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  if transform.is_identity() {
    // This is sort of similar to SkDraw::drawPath

    // Skip empty paths and horizontal/vertical lines.
    let path_bounds = path.bounds()
    if is_nearly_zero(path_bounds.width()) ||
      is_nearly_zero(path_bounds.height()) {
      // empty paths and horizontal/vertical lines cannot be filled
      return
    }
    if is_too_big_for_math(path) {
      // path coordinates are too big
      return
    }

    // TODO: ignore paths outside the pixmap
    match DrawTiler::new(self.width(), self.height()) {
      Some(tiler) => {
        let mut path = path // TODO: avoid cloning
        let paint = paint.clone()
        while tiler.next() is Some(tile) {
          let ts = @path.Transform::from_translate(
            -Float::from_int(tile.x()),
            -Float::from_int(tile.y()),
          )
          path = match path.transform(ts) {
            Some(v) => v
            None =>
              // path transformation failed
              return
          }
          paint.shader = paint.shader.transform(ts)
          let clip_rect = int_size_to_screen_int_rect(tile.size(), 0, 0)
          guard self.subpixmap(tile.to_int_rect()) is Some(subpix) else { // technically unreachable
            continue
          }
          let submask = mask.bind(m => m.submask(tile.to_int_rect()))
          match RasterPipelineBlitter::new(paint, submask, subpix) {
            Some(blitter) =>
              // We're ignoring "errors" here, because `fill_path` will return
              // `None` when rendering a tile that doesn't have a path on it.
              // Which is not an error in this case.
              if paint.anti_alias {
                scan_path_aa_fill_path(path, fill_rule, clip_rect, blitter)
              } else {
                scan_path_fill_path(path, fill_rule, clip_rect, blitter)
              }
            None => continue // nothing to do, all good
          }
          let ts = @path.Transform::from_translate(
            Float::from_int(tile.x()),
            Float::from_int(tile.y()),
          )
          path = match path.transform(ts) {
            Some(v) => v
            None => return // technically unreachable
          }
          paint.shader = paint.shader.transform(ts)
        }
      }
      None => {
        let clip_rect = int_size_to_screen_int_rect(self.size, 0, 0)
        let submask = mask.map(m => m.as_submask())
        let subpix = self.as_subpixmap()
        guard RasterPipelineBlitter::new(paint, submask, subpix)
          is Some(blitter) else { // nothing to do, all good
          return
        }
        if paint.anti_alias {
          scan_path_aa_fill_path(path, fill_rule, clip_rect, blitter)
        } else {
          scan_path_fill_path(path, fill_rule, clip_rect, blitter)
        }
      }
    }
  } else {
    let path = match path.transform(transform) {
      Some(v) => v
      None =>
        // path transformation failed
        return
    }
    let paint = paint.clone()
    paint.shader = paint.shader.transform(transform)
    self.fill_path_impl(
      path,
      paint,
      fill_rule,
      @path.Transform::identity(),
      mask,
    )
  }
}

///|
/// Strokes a path.
///
/// Stroking is implemented using two separate algorithms:
///
/// 1. If a stroke width is wider than 1px (after applying the transformation),
///    a path will be converted into a stroked path and then filled using
///    `fill_path`. Which means that we have to allocate a separate `Path`,
///    that can be 2-3x larger then the original path.
/// 2. If a stroke width is thinner than 1px (after applying the
///    transformation), we will use hairline stroking, which doesn't involve
///    a separate path allocation.
///
/// Also, if a `stroke` has a dash array, then path will be converted into
/// a dashed path first and then stroked. Which means a yet another
/// allocation.
fn Pixmap::stroke_path_impl(
  self : Pixmap,
  path : @path.Path,
  paint : Paint,
  stroke : @path.Stroke,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  if stroke.width < 0.0 {
    // negative stroke width isn't allowed
    return
  }
  let res_scale = @path.PathStroker::compute_resolution_scale(transform)
  let path = match stroke.dash {
    Some(dash) =>
      match path.dash(dash, res_scale) {
        Some(v) => v
        None =>
          // path dashing failed
          return
      }
    None => path
  }
  if treat_as_hairline(paint, stroke, transform) is Some(coverage) {
    let paint = paint.clone()
    if coverage == 1.0 {
      // No changes to the `paint`.
      ()
    } else if paint.blend_mode.should_pre_scale_coverage() {
      // This is the old technique, which we preserve for now so
      // we don't change previous results (testing)
      // the new way seems fine, its just (a tiny bit) different.
      let scale = f32_to_i32(coverage * 256.0)
      let new_alpha = (255 * scale) >> 8
      paint.shader = paint.shader.apply_opacity(
        Float::from_int(new_alpha) / 255.0,
      )
    }
    match DrawTiler::new(self.width(), self.height()) {
      Some(tiler) => {
        let mut path = path // TODO: avoid cloning
        let paint = paint.clone()
        if !transform.is_identity() {
          paint.shader = paint.shader.transform(transform)
          path = match path.transform(transform) {
            Some(v) => v
            None =>
              // path transformation failed
              return
          }
        }
        while tiler.next() is Some(tile) {
          let ts = @path.Transform::from_translate(
            -Float::from_int(tile.x()),
            -Float::from_int(tile.y()),
          )
          path = match path.transform(ts) {
            Some(v) => v
            None =>
              // path transformation failed
              return
          }
          paint.shader = paint.shader.transform(ts)
          guard self.subpixmap(tile.to_int_rect()) is Some(subpix) else { // technically unreachable
            continue
          }
          let submask = mask.bind(m => m.submask(tile.to_int_rect()))

          // We're ignoring "errors" here, because `stroke_hairline` will
          // return `None` when rendering a tile that doesn't have a path on
          // it. Which is not an error in this case.
          stroke_hairline(path, paint, stroke.line_cap, submask, subpix)
          let ts = @path.Transform::from_translate(
            Float::from_int(tile.x()),
            Float::from_int(tile.y()),
          )
          path = match path.transform(ts) {
            Some(v) => v
            None => return
          }
          paint.shader = paint.shader.transform(ts)
        }
      }
      None => {
        let subpix = self.as_subpixmap()
        let submask = mask.map(m => m.as_submask())
        if !transform.is_identity() {
          paint.shader = paint.shader.transform(transform)

          // TODO: avoid clone
          let path = match path.transform(transform) {
            Some(v) => v
            None =>
              // path transformation failed
              return
          }
          stroke_hairline(path, paint, stroke.line_cap, submask, subpix)
        } else {
          stroke_hairline(path, paint, stroke.line_cap, submask, subpix)
        }
      }
    }
  } else {
    let path = match path.stroke(stroke, res_scale) {
      Some(v) => v
      None =>
        // path stroking failed
        return
    }
    self.fill_path_impl(path, paint, Winding, transform, mask)
  }
}

///|
fn stroke_hairline(
  path : @path.Path,
  paint : Paint,
  line_cap : @path.LineCap,
  mask : SubMaskRef?,
  pixmap : SubPixmapMut,
) -> Unit {
  let clip = int_size_to_screen_int_rect(pixmap.size, 0, 0)
  guard RasterPipelineBlitter::new(paint, mask, pixmap) is Some(blitter) else { // nothing to do, all good
    return
  }
  if paint.anti_alias {
    hairline_aa_stroke_path(path, line_cap, clip, blitter)
  } else {
    hairline_stroke_path(path, line_cap, clip, blitter)
  }
}

///|
/// Draws a `Pixmap` on top of the current `Pixmap`.
///
/// The same as filling a rectangle with a `pixmap` pattern.
fn Pixmap::draw_pixmap_impl(
  self : Pixmap,
  x : Int,
  y : Int,
  pixmap : Pixmap,
  paint : PixmapPaint,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  let rect = pixmap.size.to_int_rect(x, y).to_rect()

  // TODO: SkSpriteBlitter
  // TODO: partially clipped
  // TODO: clipped out

  // Translate pattern as well as bounds.
  let patt_transform = @path.Transform::from_translate(
    Float::from_int(x),
    Float::from_int(y),
  )
  let paint : Paint = {
    shader: Pattern::new(
      pixmap,
      Pad, // Pad, otherwise we will get weird borders overlap.
      paint.quality,
      paint.opacity,
      patt_transform,
    ),
    blend_mode: paint.blend_mode,
    anti_alias: false, // Skia doesn't use it too.
    force_hq_pipeline: false, // Pattern will use hq anyway.
    colorspace: Linear,
  }
  self.fill_rect_impl(rect, paint, transform, mask)
}

///|
/// Applies a masks.
///
/// When a `Mask` is used for drawing, all of a `Pixmap`'s pixels are drawn
/// over, using the mask as coverage.
pub fn Pixmap::apply_mask(self : Pixmap, mask : Mask) -> Unit {
  if self.size != mask.size {
    // Pixmap and Mask are expected to have the same size
    return
  }

  // Just a dummy.
  let pixmap_src = dummy_pixmap
  let p = RasterPipelineBuilder::new()
  p.push(LoadMaskU8)
  p.push(LoadDestination)
  p.push(DestinationIn)
  p.push(Store)
  let p = p.compile()
  let rect = int_size_to_screen_int_rect(self.size, 0, 0)
  p.run(
    rect,
    AAMaskCtx::default(),
    mask.as_submask().mask_ctx(),
    pixmap_src,
    self.as_subpixmap(),
  )
}

///|
fn treat_as_hairline(
  paint : Paint,
  stroke : @path.Stroke,
  ts : @path.Transform,
) -> Float? {
  fn fast_len(p : @path.Point) -> Float {
    let mut x = fabs(p.x)
    let mut y = fabs(p.y)
    if x < y {
      let t = x
      x = y
      y = t
    }
    x + half(y)
  }

  if stroke.width == 0.0 {
    return Some(1.0)
  }
  if !paint.anti_alias {
    return None
  }

  // We don't care about translate.
  let ts = { ..ts, tx: 0.0, ty: 0.0, }

  // We need to try to fake a thick-stroke with a modulated hairline.
  let points = [
    @path.Point::from_xy(stroke.width, 0.0),
    @path.Point::from_xy(0.0, stroke.width),
  ]
  ts.map_points(points)
  let len0 = fast_len(points[0])
  let len1 = fast_len(points[1])
  if len0 <= 1.0 && len1 <= 1.0 {
    return Some(ave(len0, len1))
  }
  None
}

///|
fn is_too_big_for_math(path : @path.Path) -> Bool {
  // This value is just a guess. smaller is safer, but we don't want to reject
  // largish paths that we don't have to.
  let scale_down_to_allow_for_small_multiplies : Float = 0.25
  let max = scalar_max * scale_down_to_allow_for_small_multiplies
  let b = path.bounds()

  // use ! expression so we return true if bounds contains NaN
  !(b.left() >= -max && b.top() >= -max && b.right() <= max && b.bottom() <= max)
}

///|
priv struct DrawTiler {
  image_width : Int
  image_height : Int
  mut x_offset : Int
  mut y_offset : Int
  finished : Bool
}

///|
/// 8K is 1 too big, since 8K << supersample == 32768 which is too big for
/// Fixed.
let draw_tiler_max_dimensions : Int = 8192 - 1

///|
fn DrawTiler::required(image_width : Int, image_height : Int) -> Bool {
  image_width > draw_tiler_max_dimensions ||
  image_height > draw_tiler_max_dimensions
}

///|
fn DrawTiler::new(image_width : Int, image_height : Int) -> DrawTiler? {
  if DrawTiler::required(image_width, image_height) {
    Some({
      image_width,
      image_height,
      x_offset: 0,
      y_offset: 0,
      finished: false,
    })
  } else {
    None
  }
}

///|
fn DrawTiler::next(self : DrawTiler) -> ScreenIntRect? {
  if self.finished {
    return None
  }

  // TODO: iterate only over tiles that actually affected by the shape

  if self.x_offset < self.image_width && self.y_offset < self.image_height {
    let h = if self.y_offset < self.image_height {
      let v = self.image_height - self.y_offset
      if v < draw_tiler_max_dimensions {
        v
      } else {
        draw_tiler_max_dimensions
      }
    } else {
      self.image_height
    }
    let w = {
      let v = self.image_width - self.x_offset
      if v < draw_tiler_max_dimensions {
        v
      } else {
        draw_tiler_max_dimensions
      }
    }
    let r = ScreenIntRect::from_xywh(
      self.x_offset.reinterpret_as_uint(),
      self.y_offset.reinterpret_as_uint(),
      w.reinterpret_as_uint(),
      h.reinterpret_as_uint(),
    )
    self.x_offset += draw_tiler_max_dimensions
    if self.x_offset >= self.image_width {
      self.x_offset = 0
      self.y_offset += draw_tiler_max_dimensions
    }
    return r
  }
  None
}

///|
/// Draws a filled rectangle onto the pixmap.
///
/// This function is usually slower than filling a rectangular path, but it
/// produces better results. Mainly it doesn't suffer from weird clipping of
/// horizontal/vertical edges.
pub fn Pixmap::fill_rect(
  self : Pixmap,
  rect : @path.Rect,
  paint : Paint,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  if trace_hook.val is Some(f) {
    f(
      "TSK fill_rect \{fbits(rect.left())},\{fbits(rect.top())},\{fbits(rect.right())},\{fbits(rect.bottom())} \{trace_paint(paint)} \{trace_ts(transform)} \{trace_mask(mask)}",
    )
  }
  self.fill_rect_impl(rect, paint, transform, mask)
  self.trace_result()
}

///|
/// Draws a filled path onto the pixmap.
pub fn Pixmap::fill_path(
  self : Pixmap,
  path : @path.Path,
  paint : Paint,
  fill_rule : FillRule,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  if trace_hook.val is Some(f) {
    let rule = match fill_rule {
      Winding => "Winding"
      EvenOdd => "EvenOdd"
    }
    f(
      "TSK fill_path \{trace_path(path)} \{rule} \{trace_paint(paint)} \{trace_ts(transform)} \{trace_mask(mask)}",
    )
  }
  self.fill_path_impl(path, paint, fill_rule, transform, mask)
  self.trace_result()
}

///|
/// Strokes a path.
///
/// Stroking is implemented using two separate algorithms:
///
/// 1. If a stroke width is wider than 1px (after applying the
///    transformation), a path will be converted into a stroked path and then
///    filled using `fill_path`.
/// 2. If a stroke width is thinner than 1px (after applying the
///    transformation), we will use hairline stroking, which doesn't involve
///    a separate path allocation.
///
/// Also, if a `stroke` has a dash array, then path will be converted into
/// a dashed path first and then stroked.
pub fn Pixmap::stroke_path(
  self : Pixmap,
  path : @path.Path,
  paint : Paint,
  stroke : @path.Stroke,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  if trace_hook.val is Some(f) {
    let cap = match stroke.line_cap {
      Butt => "Butt"
      Round => "Round"
      Square => "Square"
    }
    let join = match stroke.line_join {
      Miter => "Miter"
      MiterClip => "MiterClip"
      Round => "Round"
      Bevel => "Bevel"
    }
    f(
      "TSK stroke_path \{trace_path(path)} w=\{fbits(stroke.width)} \{cap} \{join} ml=\{fbits(stroke.miter_limit)} dash=\{stroke.dash is Some(_)} \{trace_paint(paint)} \{trace_ts(transform)} \{trace_mask(mask)}",
    )
  }
  self.stroke_path_impl(path, paint, stroke, transform, mask)
  self.trace_result()
}

///|
/// Draws a `Pixmap` on top of the current `Pixmap`.
///
/// The same as filling a rectangle with a `pixmap` pattern.
pub fn Pixmap::draw_pixmap(
  self : Pixmap,
  x : Int,
  y : Int,
  pixmap : Pixmap,
  paint : PixmapPaint,
  transform : @path.Transform,
  mask : Mask?,
) -> Unit {
  if trace_hook.val is Some(f) {
    f(
      "TSK draw_pixmap \{x} \{y} \{pixmap.width()}x\{pixmap.height()} \{hex64(trace_fnv(pixmap.data()))} \{trace_ts(transform)} \{trace_mask(mask)}",
    )
  }
  self.draw_pixmap_impl(x, y, pixmap, paint, transform, mask)
  self.trace_result()
}
