// Port of `hayro-interpret/src/gradient.rs`: SVG-like gradient conversion for
// encoded shadings.
//
// PDF shadings are very expensive to evaluate. Because of this, at least for
// radial-axial shadings it's useful if we can instead approximate them by
// SVG-like sRGB gradients.

///|
const MAX_GRADIENT_SUBDIVISION_DEPTH : Int = 10

///|
const RADIAL_EPSILON : Double = 1.0e-6

///|
/// An SVG-like gradient.
pub struct SvgGradient {
  /// The kind of the gradient.
  kind : SvgGradientKind
  /// The transform from encoded shading coordinates into the renderer's coordinate space.
  transform : @kurbo.Affine
  /// The stops of the gradient in the sRGB color space.
  stops : Array[SvgGradientStop]
}

///|
/// The kind of the SVG gradient.
pub enum SvgGradientKind {
  /// Linear gradient (`start`/`end`: the normalized start/end point of the
  /// gradient line).
  Linear(start~ : @kurbo.Point, end~ : @kurbo.Point)
  /// Radial gradient (the center point and radius of the start circle and of
  /// the end circle).
  Radial(
    start_center~ : @kurbo.Point,
    start_radius~ : Float,
    end_center~ : @kurbo.Point,
    end_radius~ : Float
  )
}

///|
/// A color stop for an SVG-like gradient.
pub struct SvgGradientStop {
  /// Normalized offset.
  offset : Float
  /// RGBA color components in sRGB.
  color : FixedArray[Float]
}

///|
/// Convert an axial/radial PDF shading into an SVG-like gradient approximation.
pub fn EncodedRadialAxialShading::as_svg_gradient(
  self : EncodedRadialAxialShading,
  pattern : EncodedShadingPattern,
  path_bbox : @kurbo.Rect,
  tolerance : Float,
) -> SvgGradient? {
  // A couple of cases cannot be losslessly represented by an SVG gradient.
  match self.params {
    Axial =>
      if !self.axial_extend_covers_bbox(pattern, path_bbox) {
        return None
      }
    Radial(..) =>
      if !self.radial_extend_covers_bbox(pattern, path_bbox) ||
        pattern.background_color.components()[3] > 0.0 {
        return None
      }
  }
  Some({
    kind: self.native_gradient_kind(),
    transform: pattern.base_transform.inverse(),
    stops: approximate_gradient_stops(
      t => self.sample_t(pattern, t),
      self.normalized_stitching_bounds(),
      tolerance,
    ),
  })
}

///|
fn EncodedRadialAxialShading::native_gradient_kind(
  self : EncodedRadialAxialShading,
) -> SvgGradientKind {
  match self.params {
    Axial => Linear(start=@kurbo.point_zero, end=@kurbo.Point::new(1.0, 0.0))
    Radial(p1~, r~) =>
      Radial(
        start_center=@kurbo.point_zero,
        start_radius=r.x.to_float(),
        end_center=p1,
        end_radius=r.y.to_float(),
      )
  }
}

///|
fn EncodedRadialAxialShading::sample_t(
  self : EncodedRadialAxialShading,
  pattern : EncodedShadingPattern,
  t : Float,
) -> FixedArray[Float] {
  let (t0, t1) = (self.domain[0], self.domain[1])
  let t = t0 + (t1 - t0) * t
  guard self.function.eval([t]) is Some(out) else {
    return [0.0, 0.0, 0.0, 0.0]
  }
  let components = pattern.color_space.to_rgba(out, 1.0, false).components()
  components[3] *= pattern.opacity
  if pattern.transfer_function is Some(tf) {
    return tf.apply(AlphaColor::new(components)).components()
  }
  components
}

///|
fn EncodedRadialAxialShading::axial_extend_covers_bbox(
  self : EncodedRadialAxialShading,
  pattern : EncodedShadingPattern,
  path_bbox : @kurbo.Rect,
) -> Bool {
  let path_bbox = pattern.base_transform.transform_rect_bbox(path_bbox)
  let min_x = path_bbox.min_x()
  let max_x = path_bbox.max_x()
  (self.extend_[0] || min_x >= 0.0) && (self.extend_[1] || max_x <= 1.0)
}

///|
fn EncodedRadialAxialShading::radial_extend_covers_bbox(
  self : EncodedRadialAxialShading,
  pattern : EncodedShadingPattern,
  path_bbox : @kurbo.Rect,
) -> Bool {
  guard self.params is Radial(p1~, r~) else { return false }
  let path_bbox = pattern.base_transform.transform_rect_bbox(path_bbox)
  if p1.x.abs() <= RADIAL_EPSILON && p1.y.abs() <= RADIAL_EPSILON {
    return self.same_center_radial_extend_covers_bbox(path_bbox, r.x, r.y)
  }
  let start_extend_ok = self.extend_[0] || r.x.abs() <= RADIAL_EPSILON
  let end_extend_ok = self.extend_[1] ||
    circle_covers_bbox(@kurbo.Circle::new(p1, r.y), path_bbox)
  start_extend_ok && end_extend_ok
}

///|
fn EncodedRadialAxialShading::same_center_radial_extend_covers_bbox(
  self : EncodedRadialAxialShading,
  path_bbox : @kurbo.Rect,
  r0 : Double,
  r1 : Double,
) -> Bool {
  let mut inner_circle = @kurbo.Circle::new(@kurbo.point_zero, r0)
  let mut outer_circle = @kurbo.Circle::new(@kurbo.point_zero, r1)
  let mut inner_extend = self.extend_[0]
  let mut outer_extend = self.extend_[1]
  if inner_circle.radius > outer_circle.radius {
    let c = inner_circle
    inner_circle = outer_circle
    outer_circle = c
    let e = inner_extend
    inner_extend = outer_extend
    outer_extend = e
  }
  let inner_extend_ok = inner_extend ||
    inner_circle.radius <= RADIAL_EPSILON ||
    circle_outside_bbox(inner_circle, path_bbox)
  let outer_extend_ok = outer_extend ||
    circle_covers_bbox(outer_circle, path_bbox)
  inner_extend_ok && outer_extend_ok
}

///|
fn EncodedRadialAxialShading::normalized_stitching_bounds(
  self : EncodedRadialAxialShading,
) -> Array[Float] {
  let (t0, t1) = (self.domain[0], self.domain[1])
  let dt = t1 - t0
  if dt.abs() <= F32_EPSILON {
    return []
  }
  let bounds = self.function
    .stitching_bounds()
    .map(bound => (bound - t0) / dt)
    .filter(bound => bound > 0.0 && bound < 1.0)
  if dt < 0.0 {
    bounds.rev_inplace()
  }
  bounds
}

///|
fn circle_covers_bbox(circle : @kurbo.Circle, bbox : @kurbo.Rect) -> Bool {
  if circle.radius < 0.0 {
    return false
  }
  let radius_squared = circle.radius * circle.radius
  [
    @kurbo.Point::new(bbox.x0, bbox.y0),
    @kurbo.Point::new(bbox.x1, bbox.y0),
    @kurbo.Point::new(bbox.x0, bbox.y1),
    @kurbo.Point::new(bbox.x1, bbox.y1),
  ]
  .iter()
  .all(point => {
    let delta = point.sub(circle.center)
    delta.hypot2() <= radius_squared
  })
}

///|
/// Rust's `f64::clamp`.
fn f64_clamp(x : Double, min : Double, max : Double) -> Double {
  let mut x = x
  if x < min {
    x = min
  }
  if x > max {
    x = max
  }
  x
}

///|
fn circle_outside_bbox(circle : @kurbo.Circle, bbox : @kurbo.Rect) -> Bool {
  if circle.radius <= 0.0 {
    return true
  }
  let closest = @kurbo.Point::new(
    f64_clamp(circle.center.x, bbox.x0, bbox.x1),
    f64_clamp(circle.center.y, bbox.y0, bbox.y1),
  )
  !circle.contains(closest)
}

///|
fn approximate_gradient_stops(
  sample : (Float) -> FixedArray[Float],
  breakpoints : Array[Float],
  tolerance : Float,
) -> Array[SvgGradientStop] {
  let interval_bounds : Array[Float] = []
  interval_bounds.push(0.0)
  interval_bounds.append(breakpoints)
  interval_bounds.push(1.0)
  let stops = []
  for i in 0..<(interval_bounds.length() - 1) {
    let start_offset = interval_bounds[i]
    let end_offset = interval_bounds[i + 1]
    let start_color = sample(start_offset)
    stops.push(SvgGradientStop::{ offset: start_offset, color: start_color, })
    let end_color = sample(end_offset)
    approximate_gradient_interval(
      sample,
      stops,
      { offset: start_offset, color: start_color, },
      { offset: end_offset, color: end_color, },
      f32_max(tolerance, 0.0),
      0,
    )
  }
  stops
}

///|
priv struct GradientSample {
  offset : Float
  color : FixedArray[Float]
}

///|
fn approximate_gradient_interval(
  sample : (Float) -> FixedArray[Float],
  stops : Array[SvgGradientStop],
  start : GradientSample,
  end : GradientSample,
  tolerance : Float,
  depth : Int,
) -> Unit {
  let offset_delta = end.offset - start.offset
  let quarter_offset = start.offset + offset_delta * 0.25
  let mid_offset = start.offset + offset_delta * 0.5
  let three_quarter_offset = start.offset + offset_delta * 0.75
  let quarter_color = sample(quarter_offset)
  let mid_color = sample(mid_offset)
  let three_quarter_color = sample(three_quarter_offset)
  if (
      color_error(quarter_color, lerp_color(start.color, end.color, 0.25)) <=
      tolerance &&
      color_error(mid_color, lerp_color(start.color, end.color, 0.5)) <=
      tolerance &&
      color_error(three_quarter_color, lerp_color(start.color, end.color, 0.75)) <=
      tolerance
    ) ||
    depth == MAX_GRADIENT_SUBDIVISION_DEPTH {
    stops.push(SvgGradientStop::{ offset: end.offset, color: end.color, })
    return
  }
  let mid = GradientSample::{ offset: mid_offset, color: mid_color, }
  approximate_gradient_interval(sample, stops, start, mid, tolerance, depth + 1)
  approximate_gradient_interval(sample, stops, mid, end, tolerance, depth + 1)
}

///|
fn lerp_color(
  c0 : FixedArray[Float],
  c1 : FixedArray[Float],
  t : Float,
) -> FixedArray[Float] {
  [
    c0[0] + (c1[0] - c0[0]) * t,
    c0[1] + (c1[1] - c0[1]) * t,
    c0[2] + (c1[2] - c0[2]) * t,
    c0[3] + (c1[3] - c0[3]) * t,
  ]
}

///|
fn color_error(c0 : FixedArray[Float], c1 : FixedArray[Float]) -> Float {
  let mut acc : Float = 0.0
  for i in 0..<4 {
    acc = f32_max(acc, (c0[i] - c1[i]).abs())
  }
  acc
}
