// Port of `vello_common/src/encode.rs` (gradients and images; colors are
// always interpolated in sRGB with premultiplied alpha).

///|
const DEGENERATE_THRESHOLD : Float = 1.0e-6

///|
const NUDGE_VAL : Float = 1.0e-7

///|
/// From tiny-skia's `SCALAR_NEARLY_ZERO`.
let scalar_nearly_zero : Float = (1.0 : Float) / Float::from_int(1 << 12)

///|
/// `FloatExt::is_nearly_zero` for `f32`.
fn f32_is_nearly_zero(x : Float) -> Bool {
  x.abs() <= scalar_nearly_zero
}

///|
/// `FloatExt::is_nearly_zero` for `f64`.
fn f64_is_nearly_zero(x : Double) -> Bool {
  x.abs() <= scalar_nearly_zero.to_double()
}

///|
/// An encoded paint.
priv enum EncodedPaint {
  /// An encoded gradient.
  Gradient(EncodedGradient)
  /// An encoded image.
  Image(EncodedImage)
}

///|
/// Encode the gradient and push it into a vector of encoded paints, returning
/// the corresponding paint in the process.
fn Gradient::encode_into(
  self : Gradient,
  paints : Array[EncodedPaint],
  transform : @kurbo.Affine,
) -> Paint {
  // First make sure that the gradient is valid and not degenerate.
  if validate_gradient(self) is Some(paint) {
    return paint
  }
  let mut may_have_transparency = self.stops
    .iter()
    .any(s => s.color.components[3] != 1.0)
  let mut stops = self.stops
  let first_stop = stops[0]
  let last_stop = stops[stops.length() - 1]
  if first_stop.offset != 0.0 || last_stop.offset != 1.0 {
    let vec = stops.copy()
    if first_stop.offset != 0.0 {
      vec.insert(0, { offset: 0.0, color: first_stop.color, })
    }
    if last_stop.offset != 1.0 {
      vec.push({ offset: 1.0, color: last_stop.color, })
    }
    stops = vec
  }
  let mut base_transform = @kurbo.Affine::identity()
  let kind = match self.kind {
    Linear(start=p0, end=p1) => {
      // We update the transform currently in-place, such that the gradient
      // line always starts at the point (0, 0) and ends at the point (1, 0).
      base_transform = ts_from_line_to_line(
        p0,
        p1,
        @kurbo.Point::new(0.0, 0.0),
        @kurbo.Point::new(1.0, 0.0),
      )
      EncodedKind::Linear
    }
    Radial(start_center=c0, start_radius=r0, end_center=c1, end_radius=r1) => {
      // The implementation of radial gradients is translated from Skia.
      let d_radius = r1 - r0
      let radial_kind = if f32_is_nearly_zero(f32(c1.sub(c0).hypot())) {
        base_transform = @kurbo.Affine::translate(-c1.x, -c1.y)
        base_transform = base_transform.then_scale(
          1.0 / fmaxnm(r0, r1).to_double(),
        )
        let scale = fmaxnm(r1, r0) / d_radius
        let bias = -r0 / d_radius
        RadialKind::Radial(bias~, scale~)
      } else {
        base_transform = ts_from_line_to_line(
          c0,
          c1,
          @kurbo.Point::new(0.0, 0.0),
          @kurbo.Point::new(1.0, 0.0),
        )
        if f32_is_nearly_zero(r1 - r0) {
          let scaled_r0 = r1 / f32(c1.sub(c0).hypot())
          RadialKind::Strip(scaled_r0_squared=scaled_r0 * scaled_r0)
        } else {
          let d_center = f32(c0.sub(c1).hypot())
          let (focal_data, matrix) = FocalData::create(
            r0 / d_center,
            r1 / d_center,
            base_transform,
          )
          base_transform = matrix
          let fp0 = (1.0 : Float) / focal_data.fr1
          let fp1 = focal_data.f_focal_x
          RadialKind::Focal(focal_data~, fp0~, fp1~)
        }
      }
      // Even if the gradient has no stops with transparency, we might have to
      // force alpha-compositing in case the radial gradient is undefined in
      // certain positions.
      may_have_transparency = may_have_transparency ||
        radial_kind.has_undefined()
      EncodedKind::Radial(radial_kind)
    }
  }
  let ranges = encode_stops(stops)
  // This represents the transform that needs to be applied to the starting
  // point of a command before starting with the rendering.
  let transform = base_transform * transform.inverse()
  let (x_advance, y_advance) = x_y_advances(transform)
  let has_undefined = kind.has_undefined()
  let encoded = {
    kind,
    has_undefined,
    transform,
    x_advance,
    y_advance,
    ranges,
    extend_mode: self.extend_mode,
    may_have_transparency,
    u8_lut: None,
    f32_lut: None,
  }
  let idx = paints.length()
  paints.push(Gradient(encoded))
  Indexed(idx)
}

///|
/// Returns a fallback paint in case the gradient is invalid.
///
/// The paint will be either black or contain the color of the first stop of
/// the gradient.
fn validate_gradient(gradient : Gradient) -> Paint? {
  let black_paint = Paint::Solid(PremulColor::from_alpha_color(black))
  // Gradients need at least two stops.
  if gradient.stops.is_empty() {
    return Some(black_paint)
  }
  let first = Some(
    Paint::Solid(PremulColor::from_alpha_color(gradient.stops[0].color)),
  )
  if gradient.stops.length() == 1 {
    return first
  }
  let in_range = (x : Float) => x >= 0.0 && x <= 1.0
  for i in 0..<(gradient.stops.length() - 1) {
    let f = gradient.stops[i]
    let n = gradient.stops[i + 1]
    // Offsets must be between 0 and 1, and not NaN.
    if !in_range(f.offset) {
      return first
    }
    // Stops must be sorted by ascending offset.
    if f.offset > n.offset {
      return first
    }
  }
  // Check the last stop as well.
  let last = gradient.stops[gradient.stops.length() - 1]
  if !in_range(last.offset) {
    return first
  }
  let degenerate_point = (p1 : @kurbo.Point, p2 : @kurbo.Point) => {
    f32((p1.x - p2.x).abs()) <= DEGENERATE_THRESHOLD &&
    f32((p1.y - p2.y).abs()) <= DEGENERATE_THRESHOLD
  }
  let degenerate_val = (v1 : Float, v2 : Float) => {
    (v2 - v1).abs() <= DEGENERATE_THRESHOLD
  }
  match gradient.kind {
    Linear(start~, end~) =>
      // Start and end points must not be too close together.
      if degenerate_point(start, end) {
        return first
      }
    Radial(start_center~, start_radius~, end_center~, end_radius~) => {
      // Radii must not be negative.
      if start_radius < 0.0 || end_radius < 0.0 {
        return first
      }
      // Radii and center points must not be close to the same.
      if degenerate_point(start_center, end_center) &&
        degenerate_val(start_radius, end_radius) {
        return first
      }
    }
  }
  None
}

///|
/// An encoded range between two color stops.
priv struct GradientRange {
  /// The end value of the range.
  x1 : Float
  /// A bias to apply when interpolating the color.
  bias : FixedArray[Float]
  /// The scale factors of the range.
  scale : FixedArray[Float]
}

///|
/// Encode all stops into a sequence of ranges.
fn encode_stops(stops : Array[ColorStop]) -> Array[GradientRange] {
  let clamp = (color : FixedArray[Float]) => {
    // The linear approximation of the gradient can produce values slightly
    // outside of [0.0, 1.0], so clamp them.
    for i in 0..<4 {
      color[i] = fclamp(color[i], 0.0, 1.0)
    }
    color
  }
  let ranges = []
  for i in 0..<(stops.length() - 1) {
    let left_stop = stops[i]
    let right_stop = stops[i + 1]
    let x0 = left_stop.offset
    let x1 = right_stop.offset
    let c0 = clamp(left_stop.color.premultiply())
    let c1 = clamp(right_stop.color.premultiply())
    // Apply a nudge value because we sometimes call `create_range` with the
    // same offset to create the padded stops.
    let x1_minus_x0 = fmaxnm(x1 - x0, NUDGE_VAL)
    let scale = FixedArray::make(4, (0.0 : Float))
    let bias = FixedArray::make(4, (0.0 : Float))
    for k in 0..<4 {
      scale[k] = (c1[k] - c0[k]) / x1_minus_x0
      bias[k] = c0[k] - x0 * scale[k]
    }
    ranges.push({ x1, bias, scale, })
  }
  ranges
}

///|
fn x_y_advances(transform : @kurbo.Affine) -> (@kurbo.Vec2, @kurbo.Vec2) {
  let c = transform.as_coeffs()
  let scale_skew_transform = @kurbo.Affine::new([
    c[0],
    c[1],
    c[2],
    c[3],
    0.0,
    0.0,
  ])
  let x_advance = scale_skew_transform.apply(@kurbo.Point::new(1.0, 0.0))
  let y_advance = scale_skew_transform.apply(@kurbo.Point::new(0.0, 1.0))
  (x_advance.to_vec2(), y_advance.to_vec2())
}

///|
/// Encode an image paint.
fn Image::encode_into(
  self : Image,
  paints : Array[EncodedPaint],
  transform : @kurbo.Affine,
) -> Paint {
  let idx = paints.length()
  let mut sampler = self.sampler
  if sampler.alpha != 1.0 {
    // If the sampler alpha is not 1.0, we need to force alpha compositing.
    abort("not implemented: Applying opacity to image commands")
  }
  let c = transform.as_coeffs()
  // Optimize image quality for integer-only translations.
  if f32_is_nearly_zero(f32(c[0]) - 1.0) &&
    f32_is_nearly_zero(f32(c[1])) &&
    f32_is_nearly_zero(f32(c[2])) &&
    f32_is_nearly_zero(f32(c[3]) - 1.0) &&
    f32_is_nearly_zero(f32(c[4] - c[4].floor())) &&
    f32_is_nearly_zero(f32(c[5] - c[5].floor())) &&
    sampler.quality == Medium {
    sampler = { ..sampler, quality: Low, }
  }
  let transform = transform.inverse()
  let (x_advance, y_advance) = x_y_advances(transform)
  let encoded = {
    may_have_transparency: self.image.may_have_transparency(),
    source: self.image,
    sampler,
    transform,
    x_advance,
    y_advance,
  }
  paints.push(Image(encoded))
  Indexed(idx)
}

///|
/// An encoded image.
priv struct EncodedImage {
  /// The underlying pixmap of the image.
  source : ImageSource
  /// Sampler
  sampler : ImageSampler
  /// Whether the image has opacities.
  may_have_transparency : Bool
  /// A transform to apply to the image.
  transform : @kurbo.Affine
  /// The advance in image coordinates for one step in the x direction.
  x_advance : @kurbo.Vec2
  /// The advance in image coordinates for one step in the y direction.
  y_advance : @kurbo.Vec2
}

///|
/// `EncodedImageExt::has_skew`.
fn EncodedImage::has_skew(self : EncodedImage) -> Bool {
  !f32_is_nearly_zero(f32(self.x_advance.y)) ||
  !f32_is_nearly_zero(f32(self.y_advance.x))
}

///|
/// `EncodedImageExt::nearest_neighbor`.
fn EncodedImage::nearest_neighbor(self : EncodedImage) -> Bool {
  self.sampler.quality == Low
}

///|
/// Focal data for a radial gradient.
priv struct FocalData {
  /// The normalized radius of the outer circle in focal space.
  fr1 : Float
  /// The x-coordinate of the focal point in normalized space [0,1].
  f_focal_x : Float
  /// Whether the focal points have been swapped.
  f_is_swapped : Bool
}

///|
/// Create a new `FocalData` with the given radii and update the matrix.
fn FocalData::create(
  r0 : Float,
  r1 : Float,
  matrix : @kurbo.Affine,
) -> (FocalData, @kurbo.Affine) {
  let mut r0 = r0
  let mut r1 = r1
  let mut matrix = matrix
  let mut swapped = false
  let mut f_focal_x = r0 / (r0 - r1)
  if f32_is_nearly_zero(f_focal_x - 1.0) {
    matrix = matrix.then_translate(@kurbo.Vec2::new(-1.0, 0.0))
    matrix = @kurbo.Affine::scale_non_uniform(-1.0, 1.0) * matrix
    let tmp = r0
    r0 = r1
    r1 = tmp
    f_focal_x = 0.0
    swapped = true
  }
  let focal_matrix = ts_from_line_to_line(
    @kurbo.Point::new(f_focal_x.to_double(), 0.0),
    @kurbo.Point::new(1.0, 0.0),
    @kurbo.Point::new(0.0, 0.0),
    @kurbo.Point::new(1.0, 0.0),
  )
  matrix = focal_matrix * matrix
  let fr1 = r1 / ((1.0 : Float) - f_focal_x).abs()
  let data = { fr1, f_focal_x, f_is_swapped: swapped, }
  if data.is_focal_on_circle() {
    matrix = matrix.then_scale(0.5)
  } else {
    matrix = @kurbo.Affine::scale_non_uniform(
        (fr1 / (fr1 * fr1 - 1.0)).to_double(),
        1.0 / (fr1 * fr1 - 1.0).abs().sqrt().to_double(),
      ) *
      matrix
  }
  matrix = matrix.then_scale(((1.0 : Float) - f_focal_x).abs().to_double())
  (data, matrix)
}

///|
/// Whether the focal is on the circle.
fn FocalData::is_focal_on_circle(self : FocalData) -> Bool {
  f32_is_nearly_zero((1.0 : Float) - self.fr1)
}

///|
/// Whether the focal points have been swapped.
fn FocalData::is_swapped(self : FocalData) -> Bool {
  self.f_is_swapped
}

///|
/// Whether the gradient is well-behaved.
fn FocalData::is_well_behaved(self : FocalData) -> Bool {
  !self.is_focal_on_circle() && self.fr1 > 1.0
}

///|
/// Whether the gradient is natively focal.
fn FocalData::is_natively_focal(self : FocalData) -> Bool {
  f32_is_nearly_zero(self.f_focal_x)
}

///|
/// A radial gradient.
priv enum RadialKind {
  /// A radial gradient, i.e. the start and end center points are the same.
  Radial(bias~ : Float, scale~ : Float)
  /// A strip gradient, i.e. the start and end radius are the same.
  Strip(scaled_r0_squared~ : Float)
  /// A general, two-point conical gradient.
  Focal(focal_data~ : FocalData, fp0~ : Float, fp1~ : Float)
}

///|
/// Whether the gradient is undefined at any location.
fn RadialKind::has_undefined(self : RadialKind) -> Bool {
  match self {
    Radial(..) => false
    Strip(..) => true
    Focal(focal_data~, ..) => !focal_data.is_well_behaved()
  }
}

///|
/// A kind of encoded gradient.
priv enum EncodedKind {
  /// An encoded linear gradient.
  Linear
  /// An encoded radial gradient.
  Radial(RadialKind)
}

///|
/// Whether the gradient is undefined at any location.
fn EncodedKind::has_undefined(self : EncodedKind) -> Bool {
  match self {
    Radial(radial_kind) => radial_kind.has_undefined()
    _ => false
  }
}

///|
/// An encoded gradient.
priv struct EncodedGradient {
  /// The underlying kind of gradient.
  kind : EncodedKind
  /// Whether the gradient can yield undefined `t` values at some locations.
  has_undefined : Bool
  /// A transform that needs to be applied to the position of the first
  /// processed pixel.
  transform : @kurbo.Affine
  /// How much to advance into the x/y direction for one step in the x
  /// direction.
  x_advance : @kurbo.Vec2
  /// How much to advance into the x/y direction for one step in the y
  /// direction.
  y_advance : @kurbo.Vec2
  /// The color ranges of the gradient.
  ranges : Array[GradientRange]
  /// The extend of the gradient.
  extend_mode : Extend
  /// Whether the gradient requires `source_over` compositing.
  may_have_transparency : Bool
  mut u8_lut : GradientLut?
  mut f32_lut : GradientLut?
}

///|
/// Get the lookup table for sampling u8-based gradient values.
fn EncodedGradient::u8_lut(self : EncodedGradient) -> GradientLut {
  match self.u8_lut {
    Some(lut) => lut
    None => {
      let lut = GradientLut::new(self.ranges, true)
      self.u8_lut = Some(lut)
      lut
    }
  }
}

///|
/// Get the lookup table for sampling f32-based gradient values.
fn EncodedGradient::f32_lut(self : EncodedGradient) -> GradientLut {
  match self.f32_lut {
    Some(lut) => lut
    None => {
      let lut = GradientLut::new(self.ranges, false)
      self.f32_lut = Some(lut)
      lut
    }
  }
}

///|
/// Calculates the transform necessary to map the line spanned by points
/// src1, src2 to the line spanned by dst1, dst2.
fn ts_from_line_to_line(
  src1 : @kurbo.Point,
  src2 : @kurbo.Point,
  dst1 : @kurbo.Point,
  dst2 : @kurbo.Point,
) -> @kurbo.Affine {
  let unit_to_line1 = unit_to_line(src1, src2)
  // Calculate the transform necessary to map line1 to the unit vector.
  let line1_to_unit = unit_to_line1.inverse()
  // Then map the unit vector to line2.
  let unit_to_line2 = unit_to_line(dst1, dst2)
  unit_to_line2 * line1_to_unit
}

///|
/// Calculate the transform necessary to map the unit vector to the line
/// spanned by the points `p1` and `p2`.
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
/// A lookup table for sampled gradient values, either as `u8` (`lut_u8`) or
/// as `f32` (`lut_f32`), 4 components per entry.
priv struct GradientLut {
  lut_u8 : FixedArray[Byte]
  lut_f32 : FixedArray[Float]
  len : Int
  scale : Float
}

///|
/// Create a new lookup table.
fn GradientLut::new(ranges : Array[GradientRange], as_u8 : Bool) -> GradientLut {
  let lut_size = determine_lut_size(ranges)
  let lut_u8 = FixedArray::make(if as_u8 { lut_size * 4 } else { 0 }, b'\x00')
  let lut_f32 = FixedArray::make(
    if as_u8 {
      0
    } else {
      lut_size * 4
    },
    (0.0 : Float),
  )
  let scale = Float::from_int(lut_size) - 1.0
  let inv_lut_scale = (1.0 : Float) / scale
  let add_factor : FixedArray[Float] = [
    0.0 * inv_lut_scale,
    1.0 * inv_lut_scale,
    2.0 * inv_lut_scale,
    3.0 * inv_lut_scale,
  ]
  // Calculate how many indices are covered by each range.
  let mut prev_idx = 0
  let result = FixedArray::make(16, (0.0 : Float))
  for range in ranges {
    let max_idx = f32_as_usize(range.x1 * Float::from_int(lut_size))
    let mut idx = prev_idx
    while idx < max_idx {
      for k in 0..<4 {
        let t = madd(Float::from_int(idx), inv_lut_scale, add_factor[k])
        for c in 0..<4 {
          result[k * 4 + c] = madd(range.scale[c], t, range.bias[c])
        }
      }
      for k in 0..<4 {
        let alpha = result[k * 4 + 3]
        for c in 0..<4 {
          // Due to floating-point impreciseness, it can happen that values
          // either become greater than 1 or the RGB channels become greater
          // than the alpha channel.
          result[k * 4 + c] = vmin(vmin(result[k * 4 + c], 1.0), alpha)
        }
      }
      // We always compute 4 samples at a time, but a gradient ramp does not
      // necessarily start at a multiple of 4, therefore we might have to
      // truncate.
      let end = min_int(idx + 4, lut_size)
      for e in idx..<end {
        let k = e - idx
        for c in 0..<4 {
          let v = result[k * 4 + c]
          if as_u8 {
            lut_u8[e * 4 + c] = f32_as_u8(madd(v, 255.0, 0.5)).to_byte()
          } else {
            lut_f32[e * 4 + c] = v
          }
        }
      }
      idx += 4
    }
    prev_idx = max_idx
  }
  { lut_u8, lut_f32, len: lut_size, scale, }
}

///|
/// The maximum size of the gradient LUT.
const MAX_GRADIENT_LUT_SIZE : Int = 4096

///|
fn determine_lut_size(ranges : Array[GradientRange]) -> Int {
  // Inspired by Blend2D.
  let stop_len = match ranges.length() {
    1 => 256
    2 => 512
    _ => 1024
  }
  // In case we have some tricky stops, we might increase the resolution.
  let mut last_x1 : Float = 0.0
  let mut min_size = 0
  for range in ranges {
    let x1 = range.x1
    let res = next_power_of_two(
      min_int(
        f32_as_usize(((1.0 : Float) / (x1 - last_x1)).ceil()),
        MAX_GRADIENT_LUT_SIZE,
      ),
    )
    min_size = max_int(min_size, res)
    last_x1 = x1
  }
  max_int(stop_len, min_size)
}

///|
/// `usize::next_power_of_two`.
fn next_power_of_two(x : Int) -> Int {
  let mut p = 1
  while p < x {
    p = p * 2
  }
  p
}
