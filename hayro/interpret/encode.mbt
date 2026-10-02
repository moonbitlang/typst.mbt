// Port of `hayro-interpret/src/encode.rs`: encoding shading patterns for easy
// sampling.

///|
/// A shading pattern that was encoded so it can be sampled.
pub struct EncodedShadingPattern {
  /// The base transform of the shading pattern.
  base_transform : @kurbo.Affine
  priv color_space : ColorSpace
  priv background_color : AlphaColor
  /// The encoded shading type.
  shading_type : EncodedShadingType
  priv opacity : Float
  priv transfer_function : ActiveTransferFunction?
}

///|
/// The encoded shading type.
pub enum EncodedShadingType {
  /// Function-based shading.
  FunctionBased(EncodedFunctionBasedShading)
  /// Axial or radial shading.
  RadialAxial(EncodedRadialAxialShading)
  /// Mesh-based shading sampled into device pixels.
  Sampled(EncodedSampledShading)
  /// Empty dummy shading.
  Dummy(EncodedDummyShading)
}

///|
/// Encoded function-based shading.
pub struct EncodedFunctionBasedShading {
  priv domain : @kurbo.Rect
  priv function : ShadingFunction
}

///|
/// Encoded axial or radial shading.
pub struct EncodedRadialAxialShading {
  priv function : ShadingFunction
  priv params : RadialAxialParams
  priv domain : FixedArray[Float]
  priv extend : FixedArray[Bool]
}

///|
/// Encoded sampled mesh shading.
///
/// The samples are keyed by `(x << 16) | y` (upstream `(u16, u16)`).
pub struct EncodedSampledShading {
  priv samples : Map[Int, ColorComponents]
  priv function : ShadingFunction?
}

///|
/// Encoded dummy shading.
pub struct EncodedDummyShading {}

///|
/// Sample the shading at the given position.
pub fn EncodedShadingPattern::sample(
  self : EncodedShadingPattern,
  pos : @kurbo.Point,
) -> FixedArray[Float] {
  match self.shading_type.eval(pos, self.background_color, self.color_space) {
    Some(v) => {
      let components = v.components()
      components[3] *= self.opacity
      if self.transfer_function is Some(tf) {
        return tf.apply(AlphaColor::new(components)).components()
      }
      components
    }
    None => [0.0, 0.0, 0.0, 0.0]
  }
}

///|
/// Encode the shading pattern.
pub fn ShadingPattern::encode(self : ShadingPattern) -> EncodedShadingPattern {
  let (shading_type, base_transform) = match self.shading.shading_type {
    FunctionBased(domain~, matrix~, function~) =>
      (
        encode_function_shading(domain, function),
        (self.matrix * matrix).inverse(),
      )
    RadialAxial(coords~, domain~, function~, extend~, axial~) => {
      let (encoded, initial_transform) = encode_axial_shading(
        coords, domain, function, extend, axial,
      )
      (encoded, initial_transform * self.matrix.inverse())
    }
    TriangleMesh(triangles~, function~) => {
      let full_transform = self.matrix
      let samples = sample_triangles(triangles, full_transform)
      (
        EncodedShadingType::Sampled({ samples, function, }),
        @kurbo.Affine::identity(),
      )
    }
    CoonsPatchMesh(patches~, function~) => {
      let triangles = []
      for patch in patches {
        patch.to_triangles(triangles)
      }
      let full_transform = self.matrix
      let samples = sample_triangles(triangles, full_transform)
      (
        EncodedShadingType::Sampled({ samples, function, }),
        @kurbo.Affine::identity(),
      )
    }
    TensorProductPatchMesh(patches~, function~) => {
      let triangles = []
      for patch in patches {
        patch.to_triangles(triangles)
      }
      let full_transform = self.matrix
      let samples = sample_triangles(triangles, full_transform)
      (
        EncodedShadingType::Sampled({ samples, function, }),
        @kurbo.Affine::identity(),
      )
    }
    Dummy =>
      (
        EncodedShadingType::Dummy(EncodedDummyShading::{ }),
        @kurbo.Affine::identity(),
      )
  }
  let color_space = self.shading.color_space
  let background_color = match self.shading.background {
    Some(b) => color_space.to_rgba(b, 1.0, false)
    None => alpha_color_transparent
  }
  {
    color_space,
    background_color,
    shading_type,
    base_transform,
    opacity: self.opacity,
    transfer_function: self.transfer_function,
  }
}

///|
fn encode_axial_shading(
  coords : FixedArray[Float],
  domain : FixedArray[Float],
  function : ShadingFunction,
  extend : FixedArray[Bool],
  is_axial : Bool,
) -> (EncodedShadingType, @kurbo.Affine) {
  let (params, initial_transform) = if is_axial {
    let (x_0, y_0, x_1, y_1) = (coords[0], coords[1], coords[2], coords[3])
    let initial_transform = ts_from_line_to_line(
      @kurbo.Point::new(x_0.to_double(), y_0.to_double()),
      @kurbo.Point::new(x_1.to_double(), y_1.to_double()),
      @kurbo.point_zero,
      @kurbo.Point::new(1.0, 0.0),
    )
    (RadialAxialParams::Axial, initial_transform)
  } else {
    let (x_0, y_0, r0, x_1, y_1, r_1) = (
      coords[0],
      coords[1],
      coords[2],
      coords[3],
      coords[4],
      coords[5],
    )
    let initial_transform = @kurbo.Affine::translate(
      (-x_0).to_double(),
      (-y_0).to_double(),
    )
    let new_x1 = x_1 - x_0
    let new_y1 = y_1 - y_0
    let p1 = @kurbo.Point::new(new_x1.to_double(), new_y1.to_double())
    let r = @kurbo.Point::new(r0.to_double(), r_1.to_double())
    (RadialAxialParams::Radial(p1~, r~), initial_transform)
  }
  (
    EncodedShadingType::RadialAxial({ function, params, domain, extend, }),
    initial_transform,
  )
}

///|
/// Rust's saturating `f64 as u16` cast.
fn f64_as_u16(x : Double) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 65535.0 {
    65535
  } else {
    x.to_int()
  }
}

///|
fn sample_triangles(
  triangles : Array[Triangle],
  transform : @kurbo.Affine,
) -> Map[Int, ColorComponents] {
  let map : Map[Int, ColorComponents] = Map::new()
  for t in triangles {
    let t = {
      let p0 = transform.apply(t.p0.point)
      let p1 = transform.apply(t.p1.point)
      let p2 = transform.apply(t.p2.point)
      let v0 = { ..t.p0, point: p0, }
      let v1 = { ..t.p1, point: p1, }
      let v2 = { ..t.p2, point: p2, }
      Triangle::new(v0, v1, v2)
    }
    let bbox = t.bounding_box()
    for y in f64_as_u16(bbox.y0.floor())..<f64_as_u16(bbox.y1.ceil()) {
      for x in f64_as_u16(bbox.x0.floor())..<f64_as_u16(bbox.x1.ceil()) {
        let point = @kurbo.Point::new(x.to_double(), y.to_double())
        if t.contains_point(point) {
          map[(x << 16) | y] = t.interpolate(point)
        }
      }
    }
  }
  map
}

///|
fn encode_function_shading(
  domain : FixedArray[Float],
  function : ShadingFunction,
) -> EncodedShadingType {
  let domain = @kurbo.Rect::new(
    domain[0].to_double(),
    domain[2].to_double(),
    domain[1].to_double(),
    domain[3].to_double(),
  )
  EncodedShadingType::FunctionBased({ domain, function, })
}

///|
priv enum RadialAxialParams {
  Axial
  Radial(p1~ : @kurbo.Point, r~ : @kurbo.Point)
}

///|
/// Rust's `f32::MIN`.
const F32_MIN : Float = -3.40282347e+38

///|
fn EncodedShadingType::eval(
  self : EncodedShadingType,
  pos : @kurbo.Point,
  bg_color : AlphaColor,
  color_space : ColorSpace,
) -> AlphaColor? {
  match self {
    FunctionBased({ domain, function, }) =>
      if !domain.contains(pos) {
        Some(bg_color)
      } else {
        guard function.eval([pos.x.to_float(), pos.y.to_float()]) is Some(out) else {
          return None
        }
        // TODO: Clamp out-of-range values.
        Some(color_space.to_rgba(out, 1.0, false))
      }
    RadialAxial({ function, params, domain, extend, }) => {
      let (t0, t1) = (domain[0], domain[1])
      let mut t = match params {
        Axial => pos.x.to_float()
        Radial(p1~, r~) =>
          radial_pos(pos, p1, r, extend[0], extend[1]).unwrap_or(F32_MIN)
      }
      if t == F32_MIN {
        return Some(bg_color)
      }
      if t < 0.0 {
        if extend[0] {
          t = 0.0
        } else {
          return Some(bg_color)
        }
      } else if t > 1.0 {
        if extend[1] {
          t = 1.0
        } else {
          return Some(bg_color)
        }
      }
      let t = t0 + (t1 - t0) * t
      guard function.eval([t]) is Some(val) else { return None }
      Some(color_space.to_rgba(val, 1.0, false))
    }
    Sampled({ samples, function, }) => {
      let sample_point = (f64_as_u16(pos.x) << 16) | f64_as_u16(pos.y)
      if samples.get(sample_point) is Some(color) {
        if function is Some(function) {
          guard function.eval(color.copy()) is Some(val) else { return None }
          Some(color_space.to_rgba(val, 1.0, false))
        } else {
          Some(color_space.to_rgba(color, 1.0, false))
        }
      } else {
        Some(bg_color)
      }
    }
    Dummy(_) => Some(alpha_color_transparent)
  }
}

///|
fn ts_from_line_to_line(
  src1 : @kurbo.Point,
  src2 : @kurbo.Point,
  dst1 : @kurbo.Point,
  dst2 : @kurbo.Point,
) -> @kurbo.Affine {
  let unit_to_line1 = unit_to_line(src1, src2)
  let line1_to_unit = unit_to_line1.inverse()
  let unit_to_line2 = unit_to_line(dst1, dst2)
  unit_to_line2 * line1_to_unit
}

///|
fn unit_to_line(p0 : @kurbo.Point, p1 : @kurbo.Point) -> @kurbo.Affine {
  @kurbo.Affine::new([
    p1.y - p0.y,
    p0.x - p1.x,
    p1.x - p0.x,
    p1.y - p0.y,
    p0.x,
    p0.y,
  ])
}

///|
fn radial_pos(
  pos : @kurbo.Point,
  p1 : @kurbo.Point,
  r : @kurbo.Point,
  min_extend : Bool,
  max_extend : Bool,
) -> Float? {
  let r0 = r.x.to_float()
  let dx = p1.x.to_float()
  let dy = p1.y.to_float()
  let dr = r.y.to_float() - r0
  let px = pos.x.to_float()
  let py = pos.y.to_float()
  let a = dx * dx + dy * dy - dr * dr
  let b = (-2.0 : Float) * (px * dx + py * dy + r0 * dr)
  let c = px * px + py * py - r0 * r0
  let discriminant = b * b - (4.0 : Float) * a * c

  // No solution available.
  if discriminant < 0.0 {
    return None
  }
  if a.abs() < 1.0e-6 {
    if b.abs() < 1.0e-6 {
      return None
    }
    let t = -c / b
    if (!min_extend && t < 0.0) || (!max_extend && t > 1.0) {
      return None
    }
    let r_t = r0 + dr * t
    if r_t < 0.0 {
      return None
    }
    return Some(t)
  }
  let sqrt_d = discriminant.sqrt()
  let t1 = (-b - sqrt_d) / ((2.0 : Float) * a)
  let t2 = (-b + sqrt_d) / ((2.0 : Float) * a)
  let max = f32_max(t1, t2)
  let mut take_max = Some(max)
  let min = f32_min(t1, t2)
  let mut take_min = Some(min)
  if (!min_extend && min < 0.0) || r0 + dr * min < 0.0 {
    take_min = None
  }
  if (!max_extend && max > 1.0) || r0 + dr * max < 0.0 {
    take_max = None
  }
  match (take_min, take_max) {
    (Some(_), Some(max)) => Some(max)
    (Some(min), None) => Some(min)
    (None, Some(max)) => Some(max)
    (None, None) => None
  }
}
