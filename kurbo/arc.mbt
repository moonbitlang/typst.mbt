// Port of `kurbo` 0.13 `arc.rs` (the parts used by stroke expansion).

///|
/// A single elliptical arc segment.
pub(all) struct Arc {
  /// The arc's centre point.
  center : Point
  /// The arc's radii, where the vector's x-component is the radius in the
  /// positive x direction after applying `x_rotation`.
  radii : Vec2
  /// The start angle in radians.
  start_angle : Double
  /// The angle between the start and end of the arc, in radians.
  sweep_angle : Double
  /// How much the arc is rotated, in radians.
  x_rotation : Double
} derive(Eq, Debug)

///|
/// Create a new `Arc`.
pub fn Arc::new(
  center : Point,
  radii : Vec2,
  start_angle : Double,
  sweep_angle : Double,
  x_rotation : Double,
) -> Arc {
  { center, radii, start_angle, sweep_angle, x_rotation, }
}

///|
/// Returns a copy of this `Arc` in the opposite direction.
///
/// The new `Arc` will sweep towards the original `Arc`s
/// start angle.
pub fn Arc::reversed(self : Arc) -> Arc {
  {
    center: self.center,
    radii: self.radii,
    start_angle: self.start_angle + self.sweep_angle,
    sweep_angle: -self.sweep_angle,
    x_rotation: self.x_rotation,
  }
}

///|
fn Arc::angle_at(self : Arc, t : Double) -> Double {
  self.start_angle + self.sweep_angle * t
}

///|
/// Create an iterator generating Bezier path elements.
///
/// The generated elements can be appended to an existing bezier path.
pub fn Arc::append_iter(self : Arc, tolerance : Double) -> ArcAppendIter {
  let sign = signum(self.sweep_angle)
  let scaled_err = fmax(self.radii.x, self.radii.y) / tolerance
  // Number of subdivisions per ellipse based on error tolerance.
  // Note: this may slightly underestimate the error for quadrants.
  let n_err = fmax(libm_pow(1.1163 * scaled_err, 1.0 / 6.0), 3.999_999)
  let n = fceil(n_err * fabs(self.sweep_angle) * (1.0 / (2.0 * PI)))
  let angle_step = self.sweep_angle / n
  let n = f64_to_count(n)
  let arm_len = 4.0 / 3.0 * libm_tan(fabs(0.25 * angle_step)) * sign
  let angle0 = self.start_angle
  let p0 = sample_ellipse(self.radii, self.x_rotation, angle0)
  {
    idx: 0,
    center: self.center,
    radii: self.radii,
    x_rotation: self.x_rotation,
    n,
    arm_len,
    angle_step,
    p0,
    angle0,
  }
}

///|
/// Converts an `Arc` into a series of cubic bezier segments.
///
/// The closure `p` will be invoked with the control points for each segment.
pub fn Arc::to_cubic_beziers(
  self : Arc,
  tolerance : Double,
  p : (Point, Point, Point) -> Unit,
) -> Unit {
  let path = self.append_iter(tolerance)
  while path.next() is Some(CurveTo(p1, p2, p3)) {
    p(p1, p2, p3)
  }
}

///|
/// Evaluate the arc at parameter `t` (`ParamCurve::eval`).
pub fn Arc::eval(self : Arc, t : Double) -> Point {
  self.center.add_vec(
    sample_ellipse(self.radii, self.x_rotation, self.angle_at(t)),
  )
}

///|
/// Get a subsegment of the arc (`ParamCurve::subsegment(t0..t1)`).
pub fn Arc::subsegment(self : Arc, t0 : Double, t1 : Double) -> Arc {
  {
    center: self.center,
    radii: self.radii,
    start_angle: self.angle_at(t0),
    sweep_angle: self.sweep_angle * (t1 - t0),
    x_rotation: self.x_rotation,
  }
}

///|
/// The iterator returned by [`Arc::append_iter`].
pub struct ArcAppendIter {
  priv mut idx : Int
  priv center : Point
  priv radii : Vec2
  priv x_rotation : Double
  priv n : Int
  priv arm_len : Double
  priv angle_step : Double
  priv mut p0 : Vec2
  priv mut angle0 : Double
}

///|
/// The next path element (always a `CurveTo`), if any.
pub fn ArcAppendIter::next(self : ArcAppendIter) -> PathEl? {
  if self.idx >= self.n {
    return None
  }
  let angle1 = self.angle0 + self.angle_step
  let p0 = self.p0
  let p1 = p0 +
    sample_ellipse(self.radii, self.x_rotation, self.angle0 + FRAC_PI_2).scale(
      self.arm_len,
    )
  let p3 = sample_ellipse(self.radii, self.x_rotation, angle1)
  let p2 = p3 -
    sample_ellipse(self.radii, self.x_rotation, angle1 + FRAC_PI_2).scale(
      self.arm_len,
    )
  self.angle0 = angle1
  self.p0 = p3
  self.idx += 1
  Some(
    CurveTo(
      self.center.add_vec(p1),
      self.center.add_vec(p2),
      self.center.add_vec(p3),
    ),
  )
}

///|
/// Take the ellipse radii, how the radii are rotated, and the sweep angle,
/// and return a point on the ellipse.
fn sample_ellipse(radii : Vec2, x_rotation : Double, angle : Double) -> Vec2 {
  let (angle_sin, angle_cos) = sin_cos(angle)
  let u = radii.x * angle_cos
  let v = radii.y * angle_sin
  rotate_pt(Vec2::new(u, v), x_rotation)
}

///|
/// Rotate `pt` about the origin by `angle` radians.
fn rotate_pt(pt : Vec2, angle : Double) -> Vec2 {
  let (angle_sin, angle_cos) = sin_cos(angle)
  Vec2::new(
    pt.x * angle_cos - pt.y * angle_sin,
    pt.x * angle_sin + pt.y * angle_cos,
  )
}
