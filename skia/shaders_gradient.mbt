// Port of `tiny-skia/src/shaders/gradient.rs`, `linear_gradient.rs`,
// `radial_gradient.rs` and `sweep_gradient.rs`.

///|
/// The default SCALAR_NEARLY_ZERO threshold of .0024 is too big and causes
/// regressions for svg gradients defined in the wild.
let degenerate_threshold : Float = 1.0 / Float::from_int(1 << 15)

///|
/// A gradient point.
pub(all) struct GradientStop {
  position : Float
  color : Color
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend GradientStop with Eq::{not_equal, equal}

///|
/// Creates a new gradient point.
///
/// `position` will be clamped to a 0..=1 range.
pub fn GradientStop::new(position : Float, color : Color) -> GradientStop {
  { position: normalized_f32_clamped(position), color, }
}

///|
pub(all) struct Gradient {
  stops : Array[GradientStop]
  tile_mode : SpreadMode
  transform : @path.Transform
  points_to_unit : @path.Transform
  colors_are_opaque : Bool
  has_uniform_stops : Bool
}

///|
fn Gradient::new(
  stops : Array[GradientStop],
  tile_mode : SpreadMode,
  transform : @path.Transform,
  points_to_unit : @path.Transform,
) -> Gradient {
  let stops = stops.copy()

  // Note: we let the caller skip the first and/or last position.
  // i.e. pos[0] = 0.3, pos[1] = 0.7
  // In these cases, we insert dummy entries to ensure that the final data
  // will be bracketed by [0, 1].
  // i.e. our_pos[0] = 0, our_pos[1] = 0.3, our_pos[2] = 0.7, our_pos[3] = 1
  let dummy_first = stops[0].position != 0.0
  let dummy_last = stops[stops.length() - 1].position != 1.0

  // Now copy over the colors, adding the dummies as needed.
  if dummy_first {
    stops.insert(0, GradientStop::new(0.0, stops[0].color))
  }
  if dummy_last {
    stops.push(GradientStop::new(1.0, stops[stops.length() - 1].color))
  }
  let colors_are_opaque = stops.iter().all(p => p.color.is_opaque())

  // Pin the last value to 1.0, and make sure positions are monotonic.
  let start_index = if dummy_first { 0 } else { 1 }
  let mut prev : Float = 0.0
  let mut has_uniform_stops = true
  let uniform_step = stops[start_index].position - prev
  for i in start_index..<stops.length() {
    let curr : Float = if i + 1 == stops.length() {
      // The last one must be zero.
      1.0
    } else {
      bound(stops[i].position, prev, 1.0)
    }
    has_uniform_stops = has_uniform_stops &&
      is_nearly_equal(uniform_step, curr - prev)
    stops[i] = { ..stops[i], position: normalized_f32_clamped(curr), }
    prev = curr
  }
  {
    stops,
    tile_mode,
    transform,
    points_to_unit,
    colors_are_opaque,
    has_uniform_stops,
  }
}

///|
fn Gradient::push_stages(
  self : Gradient,
  p : RasterPipelineBuilder,
  cs : ColorSpace,
  push_stages_pre : (RasterPipelineBuilder) -> Unit,
  push_stages_post : (RasterPipelineBuilder) -> Unit,
) -> Bool {
  p.push(SeedShader)
  guard self.transform.invert() is Some(ts) else {
    // failed to invert a gradient transform. Nothing will be rendered
    return false
  }
  let ts = ts.post_concat(self.points_to_unit)
  p.push_transform(ts)
  push_stages_pre(p)
  match self.tile_mode {
    Reflect => p.push(ReflectX1)
    Repeat => p.push(RepeatX1)
    Pad =>
      if self.has_uniform_stops {
        // We clamp only when the stops are evenly spaced.
        // If not, there may be hard stops, and clamping ruins hard stops at 0
        // and/or 1. In that case, we must make sure we're using the general
        // "gradient" stage, which is the only stage that will correctly
        // handle unclamped t.
        p.push(PadX1)
      }
  }

  // The two-stop case with stops at 0 and 1.
  if self.stops.length() == 2 {
    let c0 = cs.expand_color(self.stops[0].color)
    let c1 = cs.expand_color(self.stops[1].color)
    p.ctx.evenly_spaced_2_stop_gradient.factor = GradientColor::new(
      c1.r - c0.r,
      c1.g - c0.g,
      c1.b - c0.b,
      c1.a - c0.a,
    )
    p.ctx.evenly_spaced_2_stop_gradient.bias = GradientColor::from_color(c0)
    p.push(EvenlySpaced2StopGradient)
  } else {
    // Unlike Skia, we do not support the `evenly_spaced_gradient` stage.
    // In our case, there is no performance difference.

    let ctx = GradientCtx::default()

    // Remove the dummy stops inserted by Gradient::new
    // because they are naturally handled by the search method.
    let (first_stop, last_stop) = if self.stops.length() > 2 {
      let first = if self.stops[0].color != self.stops[1].color { 0 } else { 1 }
      let len = self.stops.length()
      let last = if self.stops[len - 2].color != self.stops[len - 1].color {
        len - 1
      } else {
        len - 2
      }
      (first, last)
    } else {
      (0, 1)
    }
    let mut t_l = self.stops[first_stop].position
    let mut c_l = GradientColor::from_color(
      cs.expand_color(self.stops[first_stop].color),
    )
    ctx.push_const_color(c_l)
    ctx.t_values.push(0.0)
    // N.B. lastStop is the index of the last stop, not one after.
    for i in first_stop..<last_stop {
      let t_r = self.stops[i + 1].position
      let c_r = GradientColor::from_color(
        cs.expand_color(self.stops[i + 1].color),
      )
      if t_l < t_r {
        // For each stop we calculate a bias B and a scale factor F, such that
        // for any t between stops n and n+1, the color we want is
        // B[n] + F[n]*t.
        let f = GradientColor::new(
          (c_r.r - c_l.r) / (t_r - t_l),
          (c_r.g - c_l.g) / (t_r - t_l),
          (c_r.b - c_l.b) / (t_r - t_l),
          (c_r.a - c_l.a) / (t_r - t_l),
        )
        ctx.factors.push(f)
        ctx.biases.push(
          GradientColor::new(
            c_l.r - f.r * t_l,
            c_l.g - f.g * t_l,
            c_l.b - f.b * t_l,
            c_l.a - f.a * t_l,
          ),
        )
        ctx.t_values.push(normalized_f32_clamped(t_l))
      }
      t_l = t_r
      c_l = c_r
    }
    ctx.push_const_color(c_l)
    ctx.t_values.push(normalized_f32_clamped(t_l))
    ctx.len = ctx.factors.length()

    // Will with zeros until we have enough data to fit into F32x16.
    while ctx.factors.length() < 16 {
      ctx.factors.push(GradientColor::new(0.0, 0.0, 0.0, 0.0))
      ctx.biases.push(GradientColor::new(0.0, 0.0, 0.0, 0.0))
    }
    p.push(Gradient)
    p.ctx.gradient = ctx
  }
  if !self.colors_are_opaque {
    p.push(Premultiply)
  }
  push_stages_post(p)
  true
}

///|
fn Gradient::apply_opacity(self : Gradient, opacity : Float) -> Gradient {
  let stops = self.stops.map(stop => {
    ..stop,
    color: stop.color.apply_opacity(opacity),
  })
  {
    ..self,
    stops,
    colors_are_opaque: stops.iter().all(p => p.color.is_opaque()),
  }
}

// linear_gradient.rs

///|
/// A linear gradient shader.
pub(all) struct LinearGradient {
  base : Gradient
}

///|
/// Creates a new linear gradient shader.
///
/// Returns `Shader::SolidColor` when:
/// - `stops.len()` == 1
/// - `start` and `end` are very close
///
/// Returns `None` when:
///
/// - `stops` is empty
/// - `start` == `end`
/// - `transform` is not invertible
pub fn LinearGradient::new(
  start : @path.Point,
  end : @path.Point,
  stops : Array[GradientStop],
  mode : SpreadMode,
  transform : @path.Transform,
) -> Shader? {
  if stops.is_empty() {
    return None
  }
  if stops.length() == 1 {
    return Some(SolidColor(stops[0].color))
  }
  let length = (end - start).length()
  if !is_finite(length) {
    return None
  }
  if is_nearly_zero_within_tolerance(length, degenerate_threshold) {
    // Degenerate gradient, the only tricky complication is when in clamp
    // mode, the limit of the gradient approaches two half planes of solid
    // color (first and last). However, they are divided by the line
    // perpendicular to the start and end point, which becomes undefined once
    // start and end are exactly the same, so just use the end color for a
    // stable solution.

    // Except for special circumstances of clamped gradients,
    // every gradient shape (when degenerate) can be mapped to the same
    // fallbacks. The specific shape factories must account for special
    // clamped conditions separately, this will always return the last color
    // for clamped gradients.
    match mode {
      Pad =>
        // Depending on how the gradient shape degenerates,
        // there may be a more specialized fallback representation
        // for the factories to use, but this is a reasonable default.
        return Some(SolidColor(stops[stops.length() - 1].color))
      Reflect | Repeat =>
        // repeat and mirror are treated the same: the border colors are
        // never visible, but approximate the final color as infinite
        // repetitions of the colors, so it can be represented as the average
        // color of the gradient.
        return Some(SolidColor(average_gradient_color(stops)))
    }
  }
  guard transform.invert() is Some(_) else { return None }
  guard points_to_unit_ts(start, end) is Some(unit_ts) else { return None }
  Some(
    LinearGradient({ base: Gradient::new(stops, mode, transform, unit_ts), }),
  )
}

///|
fn LinearGradient::push_stages(
  self : LinearGradient,
  cs : ColorSpace,
  p : RasterPipelineBuilder,
) -> Bool {
  self.base.push_stages(p, cs, _ => (), _ => ())
}

///|
fn points_to_unit_ts(
  start : @path.Point,
  end : @path.Point,
) -> @path.Transform? {
  let vec = end - start
  let mag = vec.length()
  let inv = if mag != 0.0 { invert(mag) } else { 0.0 }
  let vec = vec.scale(inv)
  let mut ts = ts_from_sin_cos_at(-vec.y, vec.x, start.x, start.y)
  ts = ts.post_translate(-start.x, -start.y)
  ts = ts.post_scale(inv, inv)
  Some(ts)
}

///|
fn average_gradient_color(points : Array[GradientStop]) -> Color {
  // The gradient is a piecewise linear interpolation between colors. For a
  // given interval, the integral between the two endpoints is
  // 0.5 * (ci + cj) * (pj - pi), which provides that intervals average color.
  // The overall average color is thus the sum of each piece. The thing to
  // keep in mind is that the provided gradient definition may implicitly use
  // p=0 and p=1.
  let blend : FixedArray[Float] = [0.0, 0.0, 0.0, 0.0]
  fn load(c : Color) -> FixedArray[Float] {
    [c.r, c.g, c.b, c.a]
  }

  // Bake 1/(colorCount - 1) uniform stop difference into this scale factor
  let w_scale : Float = 0.5
  for i in 0..<(points.length() - 1) {
    // Calculate the average color for the interval between pos(i) and
    // pos(i+1)
    let c0 = load(points[i].color)
    let c1 = load(points[i + 1].color)
    // when pos == null, there are colorCount uniformly distributed stops,
    // going from 0 to 1, so pos[i + 1] - pos[i] = 1/(colorCount-1)
    let w = points[i + 1].position - points[i].position
    for k in 0..<4 {
      blend[k] = blend[k] + w_scale * w * (c1[k] + c0[k])
    }
  }

  // Now account for any implicit intervals at the start or end of the stop
  // definitions
  if points[0].position > 0.0 {
    // The first color is fixed between p = 0 to pos[0], so
    // 0.5 * (ci + cj) * (pj - pi) becomes 0.5 * (c + c) * (pj - 0) = c * pj
    let c = load(points[0].color)
    for k in 0..<4 {
      blend[k] = blend[k] + points[0].position * c[k]
    }
  }
  let last_idx = points.length() - 1
  if points[last_idx].position < 1.0 {
    // The last color is fixed between pos[n-1] to p = 1, so
    // 0.5 * (ci + cj) * (pj - pi) becomes 0.5 * (c + c) * (1 - pi) = c * (1 - pi)
    let c = load(points[last_idx].color)
    for k in 0..<4 {
      blend[k] = blend[k] + ((1.0 : Float) - points[last_idx].position) * c[k]
    }
  }
  Color::from_rgba(blend[0], blend[1], blend[2], blend[3]).unwrap()
}

///|
fn ts_from_sin_cos_at(
  sin : Float,
  cos : Float,
  px : Float,
  py : Float,
) -> @path.Transform {
  let cos_inv = (1.0 : Float) - cos
  @path.Transform::from_row(
    cos,
    sin,
    -sin,
    cos,
    sdot(sin, py, cos_inv, px),
    sdot(-sin, px, cos_inv, py),
  )
}

///|
fn sdot(a : Float, b : Float, c : Float, d : Float) -> Float {
  a * b + c * d
}

// radial_gradient.rs

///|
struct FocalData {
  r1 : Float // r1 after mapping focal point to (0, 0)
  focal_x : Float // f
  is_swapped : Bool
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FocalData with Eq::{not_equal, equal}

///|
/// Returns the focal data and the updated matrix.
fn FocalData::set(
  r0 : Float,
  r1 : Float,
  matrix : @path.Transform,
) -> (FocalData, @path.Transform)? {
  let mut r0 = r0
  let mut r1 = r1
  let mut matrix = matrix
  let mut is_swapped = false
  let mut focal_x = r0 / (r0 - r1)
  if is_nearly_zero(focal_x - 1.0) {
    // swap r0, r1
    matrix = matrix.post_translate(-1.0, 0.0).post_scale(-1.0, 1.0)
    let t = r0
    r0 = r1
    r1 = t
    focal_x = 0.0 // because r0 is now 0
    is_swapped = true
  }

  // Map {focal point, (1, 0)} to {(0, 0), (1, 0)}
  let from0 = @path.Point::from_xy(focal_x, 0.0)
  let from1 = @path.Point::from_xy(1.0, 0.0)
  let to0 = @path.Point::from_xy(0.0, 0.0)
  let to1 = @path.Point::from_xy(1.0, 0.0)
  guard ts_from_poly_to_poly(from0, from1, to0, to1) is Some(focal_matrix) else {
    return None
  }
  matrix = matrix.post_concat(focal_matrix)
  let r1 = r1 / fabs((1.0 : Float) - focal_x) // focalMatrix has a scale of 1/(1-f).
  let fd : FocalData = { r1, focal_x, is_swapped, }

  // The following transformations are just to accelerate the shader
  // computation by saving some arithmetic operations.
  if fd.is_focal_on_circle() {
    matrix = matrix.post_scale(0.5, 0.5)
  } else {
    matrix = matrix.post_scale(
      fd.r1 / (fd.r1 * fd.r1 - 1.0),
      (1.0 : Float) / fabs(fd.r1 * fd.r1 - 1.0).sqrt(),
    )
  }
  matrix = matrix.post_scale(
    fabs((1.0 : Float) - focal_x),
    fabs((1.0 : Float) - focal_x),
  ) // scale |1 - f|
  Some((fd, matrix))
}

///|
fn FocalData::is_focal_on_circle(self : FocalData) -> Bool {
  is_nearly_zero((1.0 : Float) - self.r1)
}

///|
fn FocalData::is_well_behaved(self : FocalData) -> Bool {
  !self.is_focal_on_circle() && self.r1 > 1.0
}

///|
fn FocalData::is_natively_focal(self : FocalData) -> Bool {
  is_nearly_zero(self.focal_x)
}

///|
enum GradientType {
  Radial(Float, Float) // radius1, radius2
  Strip(Float) // scaled_r0
  Focal(FocalData)
}

///|
/// A radial gradient shader.
///
/// This is not `SkRadialGradient` like in Skia, but rather
/// `SkTwoPointConicalGradient` without the start radius.
pub(all) struct RadialGradient {
  base : Gradient
  priv gradient_type : GradientType
}

///|
/// Creates a new two-point conical (radial) gradient shader.
///
/// Returns `Shader::SolidColor` when:
/// - `stops.len()` == 1
///
/// Returns `None` when:
///
/// - `stops` is empty
/// - `start_radius` < 0 or `end_radius` < 0
/// - `transform` is not invertible
pub fn RadialGradient::new(
  start_point : @path.Point,
  start_radius : Float,
  end_point : @path.Point,
  end_radius : Float,
  stops : Array[GradientStop],
  mode : SpreadMode,
  transform : @path.Transform,
) -> Shader? {
  if start_radius < 0.0 || end_radius < 0.0 {
    return None
  }
  match stops.length() {
    0 => return None
    1 => return Some(SolidColor(stops[0].color))
    _ => ()
  }
  guard transform.invert() is Some(_) else { return None }
  let length = (start_point - end_point).length()
  if !is_finite(length) {
    return None
  }
  if is_nearly_zero_within_tolerance(length, degenerate_threshold) {
    if is_nearly_equal_within_tolerance(
        start_radius, end_radius, degenerate_threshold,
      ) {
      // Degenerate case, where the interpolation region area approaches
      // zero. The proper behavior depends on the tile mode, which is
      // consistent with the default degenerate gradient behavior, except
      // when mode = clamp and the radii > 0.
      if mode == Pad && end_radius > degenerate_threshold {
        // The interpolation region becomes an infinitely thin ring at the
        // radius, so the final gradient will be the first color repeated
        // from p=0 to 1, and then a hard stop switching to the last color at
        // p=1.
        let start_color = stops[0].color
        let end_color = stops[stops.length() - 1].color
        let new_stops = [
          GradientStop::new(0.0, start_color),
          GradientStop::new(1.0, start_color),
          GradientStop::new(1.0, end_color),
        ]
        // If the center positions are the same, then the gradient is the
        // radial variant of a 2 pt conical gradient, an actual radial
        // gradient (startRadius == 0), or it is fully degenerate
        // (startRadius == endRadius).
        return RadialGradient::new_radial_unchecked(
          start_point, end_radius, new_stops, mode, transform,
        )
      }
      // TODO: Consider making a degenerate gradient
      return None
    }
    if is_nearly_zero_within_tolerance(start_radius, degenerate_threshold) {
      // If the center positions are the same, then the gradient
      // is the radial variant of a 2 pt conical gradient,
      // an actual radial gradient (startRadius == 0),
      // or it is fully degenerate (startRadius == endRadius).
      // We can treat this gradient as a simple radial, which is faster. If
      // we got here, we know that endRadius is not equal to 0, so this
      // produces a meaningful gradient.
      return RadialGradient::new_radial_unchecked(
        start_point, end_radius, stops, mode, transform,
      )
    }
  }
  create_radial(
    start_point, start_radius, end_point, end_radius, stops, mode, transform,
  )
}

///|
fn RadialGradient::new_radial_unchecked(
  center : @path.Point,
  radius : Float,
  stops : Array[GradientStop],
  mode : SpreadMode,
  transform : @path.Transform,
) -> Shader? {
  let inv = invert(radius)
  let points_to_unit = @path.Transform::from_translate(-center.x, -center.y).post_scale(
    inv, inv,
  )
  Some(
    RadialGradient({
      base: Gradient::new(stops, mode, transform, points_to_unit),
      gradient_type: Radial(0.0, radius),
    }),
  )
}

///|
fn RadialGradient::push_stages(
  self : RadialGradient,
  cs : ColorSpace,
  p : RasterPipelineBuilder,
) -> Bool {
  let (p0, p1) : (Float, Float) = match self.gradient_type {
    Radial(radius1, radius2) =>
      if radius1 == 0.0 {
        (1.0, 0.0)
      } else {
        let d_radius = radius2 - radius1
        // For concentric gradients: t = t * scale + bias
        let p0 = fmax(radius1, radius2) / d_radius
        let p1 = -radius1 / d_radius
        (p0, p1)
      }
    Strip(scaled_r0) => (scaled_r0 * scaled_r0, 0.0) // unused
    Focal(fd) => ((1.0 : Float) / fd.r1, fd.focal_x)
  }
  p.ctx.two_point_conical_gradient.mask.fill(0)
  p.ctx.two_point_conical_gradient.p0 = p0
  p.ctx.two_point_conical_gradient.p1 = p1
  self.base.push_stages(
    p,
    cs,
    p => {
      match self.gradient_type {
        Radial(_, _) => {
          p.push(XYToRadius)
          // Apply scale/bias to map t from [0, 1] based on r_max to proper t
          // where t=0 at r0 and t=1 at r1
          if !(p0 == 1.0 && p1 == 0.0) {
            p.push(ApplyConcentricScaleBias)
          }
        }
        Strip(_) => {
          p.push(XYTo2PtConicalStrip)
          p.push(Mask2PtConicalNan)
        }
        Focal(fd) => {
          if fd.is_focal_on_circle() {
            p.push(XYTo2PtConicalFocalOnCircle)
          } else if fd.is_well_behaved() {
            p.push(XYTo2PtConicalWellBehaved)
          } else if fd.is_swapped || (1.0 : Float) - fd.focal_x < 0.0 {
            p.push(XYTo2PtConicalSmaller)
          } else {
            p.push(XYTo2PtConicalGreater)
          }
          if !fd.is_well_behaved() {
            p.push(Mask2PtConicalDegenerates)
          }
          if (1.0 : Float) - fd.focal_x < 0.0 {
            p.push(NegateX)
          }
          if !fd.is_natively_focal() {
            p.push(Alter2PtConicalCompensateFocal)
          }
          if fd.is_swapped {
            p.push(Alter2PtConicalUnswap)
          }
        }
      }
    },
    p => {
      match self.gradient_type {
        Strip(_) => p.push(ApplyVectorMask)
        Focal(fd) if !fd.is_well_behaved() => p.push(ApplyVectorMask)
        _ => ()
      }
    },
  )
}

///|
fn create_radial(
  c0 : @path.Point,
  r0 : Float,
  c1 : @path.Point,
  r1 : Float,
  stops : Array[GradientStop],
  mode : SpreadMode,
  transform : @path.Transform,
) -> Shader? {
  let mut gradient_type : GradientType = Radial(0.0, 0.0)
  let mut gradient_matrix = @path.Transform::identity()
  if is_nearly_zero((c0 - c1).length()) {
    if is_nearly_zero(fmax(r0, r1)) || is_nearly_equal(r0, r1) {
      // Degenerate case; avoid dividing by zero. Should have been caught
      // by caller but just in case, recheck here.
      return None
    }

    // Concentric case: we can pretend we're radial (with a tiny twist).
    let scale = (1.0 : Float) / fmax(r0, r1)
    gradient_matrix = @path.Transform::from_translate(-c1.x, -c1.y).post_scale(
      scale, scale,
    )
    gradient_type = Radial(r0, r1)
  } else {
    guard map_to_unit_x(c0, c1) is Some(m) else { return None }
    gradient_matrix = m
    let d_center = (c0 - c1).length()
    gradient_type = if is_nearly_zero(r0 - r1) {
      let scaled_r0 = r0 / d_center
      Strip(scaled_r0)
    } else {
      Focal({ r1: 0.0, focal_x: 0.0, is_swapped: false, })
    }
  }
  if gradient_type is Focal(_) {
    let d_center = (c0 - c1).length()
    guard FocalData::set(r0 / d_center, r1 / d_center, gradient_matrix)
      is Some((fd, m)) else {
      return None
    }
    gradient_matrix = m
    gradient_type = Focal(fd)
  }
  Some(
    RadialGradient({
      base: Gradient::new(stops, mode, transform, gradient_matrix),
      gradient_type,
    }),
  )
}

///|
fn map_to_unit_x(
  origin : @path.Point,
  x_is_one : @path.Point,
) -> @path.Transform? {
  ts_from_poly_to_poly(
    origin,
    x_is_one,
    @path.Point::from_xy(0.0, 0.0),
    @path.Point::from_xy(1.0, 0.0),
  )
}

///|
fn ts_from_poly_to_poly(
  src1 : @path.Point,
  src2 : @path.Point,
  dst1 : @path.Point,
  dst2 : @path.Point,
) -> @path.Transform? {
  let tmp = from_poly2(src1, src2)
  guard tmp.invert() is Some(res) else { return None }
  let tmp = from_poly2(dst1, dst2)
  Some(tmp.pre_concat(res))
}

///|
fn from_poly2(p0 : @path.Point, p1 : @path.Point) -> @path.Transform {
  @path.Transform::from_row(
    p1.y - p0.y,
    p0.x - p1.x,
    p1.x - p0.x,
    p1.y - p0.y,
    p0.x,
    p0.y,
  )
}

// sweep_gradient.rs

///|
/// A radial gradient.
pub(all) struct SweepGradient {
  base : Gradient
  t0 : Float
  t1 : Float
}

///|
/// Creates a new sweep gradient shader.
pub fn SweepGradient::new(
  center : @path.Point,
  start_angle : Float,
  end_angle : Float,
  stops : Array[GradientStop],
  mode : SpreadMode,
  transform : @path.Transform,
) -> Shader? {
  let mut mode = mode
  if !is_finite(start_angle) || !is_finite(end_angle) || start_angle > end_angle {
    return None
  }
  match stops.length() {
    0 => return None
    1 => return Some(SolidColor(stops[0].color))
    _ => ()
  }
  guard transform.invert() is Some(_) else { return None }
  if is_nearly_equal_within_tolerance(
      start_angle, end_angle, degenerate_threshold,
    ) {
    if mode == Pad && end_angle > degenerate_threshold {
      // In this case, the first color is repeated from 0 to the angle, then
      // a hardstop switches to the last color (all other colors are
      // compressed to the infinitely thin interpolation region).
      let front_color = stops[0].color
      let back_color = stops[stops.length() - 1].color
      let new_stops = [
        GradientStop::new(0.0, front_color),
        GradientStop::new(1.0, front_color),
        GradientStop::new(1.0, back_color),
      ]
      return SweepGradient::new(
        center, 0.0, end_angle, new_stops, mode, transform,
      )
    }
    // TODO: Consider making a degenerate fallback shader similar to Skia.
    // Tiny Skia currently opts to return `None` in some places.
    return None
  }
  if start_angle <= 0.0 && end_angle >= 360.0 {
    mode = Pad
  }
  let t0 = start_angle / 360.0
  let t1 = end_angle / 360.0
  Some(
    SweepGradient({
      base: Gradient::new(
        stops,
        mode,
        transform,
        @path.Transform::from_translate(-center.x, -center.y),
      ),
      t0,
      t1,
    }),
  )
}

///|
fn SweepGradient::push_stages(
  self : SweepGradient,
  cs : ColorSpace,
  p : RasterPipelineBuilder,
) -> Bool {
  let scale = (1.0 : Float) / (self.t1 - self.t0)
  let bias = -scale * self.t0
  p.ctx.two_point_conical_gradient.p0 = scale
  p.ctx.two_point_conical_gradient.p1 = bias
  self.base.push_stages(
    p,
    cs,
    p => {
      p.push(XYToUnitAngle)
      if scale != 1.0 && bias != 0.0 {
        p.push(ApplyConcentricScaleBias)
      }
    },
    _ => (),
  )
}
