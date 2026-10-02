// The pieces of the `kurbo` crate (0.13.1) used by `SimplifyingPathParser`:
// `SvgArc`, `Arc::from_svg_arc` (`src/svg.rs`) and `Arc::append_iter` /
// `Arc::to_cubic_beziers` (`src/arc.rs`). Not an upstream svgtypes module.

///|
/// `kurbo::Point` / `kurbo::Vec2`.
priv struct KVec2 {
  x : Double
  y : Double
} derive(Eq)

///|
fn KVec2::add(self : KVec2, v : KVec2) -> KVec2 {
  { x: self.x + v.x, y: self.y + v.y, }
}

///|
fn KVec2::sub(self : KVec2, v : KVec2) -> KVec2 {
  { x: self.x - v.x, y: self.y - v.y, }
}

///|
/// `f64 * Vec2`.
fn KVec2::scale(self : KVec2, s : Double) -> KVec2 {
  { x: s * self.x, y: s * self.y, }
}

///|
/// `Vec2::atan2`.
fn KVec2::atan2(self : KVec2) -> Double {
  libm_atan2(self.y, self.x)
}

///|
/// An SVG arc segment (`kurbo::SvgArc`).
priv struct SvgArc {
  from : KVec2
  to : KVec2
  radii : KVec2
  x_rotation : Double
  large_arc : Bool
  sweep : Bool
}

///|
/// A single elliptical arc segment (`kurbo::Arc`).
priv struct KArc {
  center : KVec2
  radii : KVec2
  start_angle : Double
  sweep_angle : Double
  x_rotation : Double
}

///|
/// Checks that arc is actually a straight line.
///
/// In this case, it can be replaced with a `LineTo`.
fn SvgArc::is_straight_line(self : SvgArc) -> Bool {
  self.radii.x.abs() <= 1.0e-5 ||
  self.radii.y.abs() <= 1.0e-5 ||
  self.from == self.to
}

///|
/// Creates an `Arc` from a `SvgArc`.
///
/// Returns `None` if `arc` is actually a straight line.
fn KArc::from_svg_arc(arc : SvgArc) -> KArc? {
  // Have to check this first, otherwise `sum_of_sq` will be 0.
  if arc.is_straight_line() {
    return None
  }
  let mut rx = arc.radii.x.abs()
  let mut ry = arc.radii.y.abs()
  let xr = arc.x_rotation % (2.0 * pi)
  let (sin_phi, cos_phi) = libm_sin_cos(xr)
  let hd_x = (arc.from.x - arc.to.x) * 0.5
  let hd_y = (arc.from.y - arc.to.y) * 0.5
  let hs_x = (arc.from.x + arc.to.x) * 0.5
  let hs_y = (arc.from.y + arc.to.y) * 0.5

  // F6.5.1
  let p : KVec2 = {
    x: cos_phi * hd_x + sin_phi * hd_y,
    y: -sin_phi * hd_x + cos_phi * hd_y,
  }

  // Sanitize the radii.
  // If rf > 1 it means the radii are too small for the arc to
  // possibly connect the end points. In this situation we scale
  // them up according to the formula provided by the SVG spec.

  // F6.6.2
  let rf = p.x * p.x / (rx * rx) + p.y * p.y / (ry * ry)
  if rf > 1.0 {
    let scale = rf.sqrt()
    rx *= scale
    ry *= scale
  }
  let rxry = rx * ry
  let rxpy = rx * p.y
  let rypx = ry * p.x
  let sum_of_sq = rxpy * rxpy + rypx * rypx

  // F6.5.2
  let sign_coe = if arc.large_arc == arc.sweep { -1.0 } else { 1.0 }
  let coe = sign_coe * ((rxry * rxry - sum_of_sq) / sum_of_sq).abs().sqrt()
  let transformed_cx = coe * rxpy / ry
  let transformed_cy = -coe * rypx / rx

  // F6.5.3
  let center : KVec2 = {
    x: cos_phi * transformed_cx - sin_phi * transformed_cy + hs_x,
    y: sin_phi * transformed_cx + cos_phi * transformed_cy + hs_y,
  }
  let start_v : KVec2 = {
    x: (p.x - transformed_cx) / rx,
    y: (p.y - transformed_cy) / ry,
  }
  let end_v : KVec2 = {
    x: (-p.x - transformed_cx) / rx,
    y: (-p.y - transformed_cy) / ry,
  }
  let start_angle = start_v.atan2()
  let mut sweep_angle = (end_v.atan2() - start_angle) % (2.0 * pi)
  if arc.sweep && sweep_angle < 0.0 {
    sweep_angle += 2.0 * pi
  } else if !arc.sweep && sweep_angle > 0.0 {
    sweep_angle -= 2.0 * pi
  }
  Some({
    center,
    radii: { x: rx, y: ry, },
    start_angle,
    sweep_angle,
    x_rotation: arc.x_rotation,
  })
}

///|
let frac_pi_2 : Double = 1.5707963267948966

///|
/// Converts an `Arc` into a series of cubic bezier segments
/// (`Arc::append_iter` + `Arc::to_cubic_beziers`).
///
/// The closure `p` will be invoked with the control points for each segment.
fn KArc::to_cubic_beziers(
  self : KArc,
  tolerance : Double,
  p : (KVec2, KVec2, KVec2) -> Unit,
) -> Unit {
  let sign = f64_signum(self.sweep_angle)
  let scaled_err = f64_max(self.radii.x, self.radii.y) / tolerance
  // Number of subdivisions per ellipse based on error tolerance.
  // Note: this may slightly underestimate the error for quadrants.
  let n_err = f64_max(libm_pow(1.1163 * scaled_err, 1.0 / 6.0), 3.999_999)
  let n = (n_err * self.sweep_angle.abs() * (1.0 / (2.0 * pi))).ceil()
  let angle_step = self.sweep_angle / n
  let n = f64_as_usize(n)
  let arm_len = 4.0 / 3.0 * libm_tan((0.25 * angle_step).abs()) * sign
  let mut angle0 = self.start_angle
  let mut p0 = sample_ellipse(self.radii, self.x_rotation, angle0)
  for _ in 0..<n {
    let angle1 = angle0 + angle_step
    let p1 = p0.add(
      sample_ellipse(self.radii, self.x_rotation, angle0 + frac_pi_2).scale(
        arm_len,
      ),
    )
    let p3 = sample_ellipse(self.radii, self.x_rotation, angle1)
    let p2 = p3.sub(
      sample_ellipse(self.radii, self.x_rotation, angle1 + frac_pi_2).scale(
        arm_len,
      ),
    )
    angle0 = angle1
    p0 = p3
    p(self.center.add(p1), self.center.add(p2), self.center.add(p3))
  }
}

///|
/// Take the ellipse radii, how the radii are rotated, and the sweep angle, and return a point on
/// the ellipse.
fn sample_ellipse(radii : KVec2, x_rotation : Double, angle : Double) -> KVec2 {
  let (angle_sin, angle_cos) = libm_sin_cos(angle)
  let u = radii.x * angle_cos
  let v = radii.y * angle_sin
  rotate_pt({ x: u, y: v, }, x_rotation)
}

///|
/// Rotate `pt` about the origin by `angle` radians.
fn rotate_pt(pt : KVec2, angle : Double) -> KVec2 {
  let (angle_sin, angle_cos) = libm_sin_cos(angle)
  {
    x: pt.x * angle_cos - pt.y * angle_sin,
    y: pt.x * angle_sin + pt.y * angle_cos,
  }
}
