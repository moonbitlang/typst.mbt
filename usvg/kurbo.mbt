// The pieces of `kurbo` 0.13.1 that usvg uses: SVG arcs (`SvgArc`,
// `Arc::from_svg_arc`, `Arc::to_cubic_beziers`; `src/svg.rs`,
// `src/arc.rs`).

///|
priv struct KPoint {
  x : Double
  y : Double
} derive(Eq)

///|
fn KPoint::add(self : KPoint, v : KPoint) -> KPoint {
  { x: self.x + v.x, y: self.y + v.y }
}

///|
fn KPoint::sub(self : KPoint, v : KPoint) -> KPoint {
  { x: self.x - v.x, y: self.y - v.y }
}

///|
fn KPoint::scale(self : KPoint, s : Double) -> KPoint {
  { x: s * self.x, y: s * self.y }
}

///|
/// A single SVG arc segment.
priv struct KSvgArc {
  /// The arc's start point.
  from : KPoint
  /// The arc's end point.
  to : KPoint
  /// The arc's radii, where the vector's x-component is the radius in the
  /// positive x direction after applying `x_rotation`.
  radii : KPoint
  /// How much the arc is rotated, in radians.
  x_rotation : Double
  /// Does this arc sweep through more than π radians?
  large_arc : Bool
  /// Determines if the arc should begin moving at positive angles.
  sweep : Bool
}

///|
/// Checks that arc is actually a straight line.
///
/// In this case, it can be replaced with a LineTo.
fn KSvgArc::is_straight_line(self : KSvgArc) -> Bool {
  self.radii.x.abs() <= 1.0e-5 ||
  self.radii.y.abs() <= 1.0e-5 ||
  self.from == self.to
}

///|
/// A single elliptical arc segment.
priv struct KArc {
  center : KPoint
  radii : KPoint
  start_angle : Double
  sweep_angle : Double
  x_rotation : Double
}

///|
let k_pi : Double = 3.14159265358979323846264338327950288

///|
let k_frac_pi_2 : Double = 1.57079632679489661923132169163975144

///|
/// Creates an `Arc` from a `SvgArc`.
///
/// Returns `None` if `arc` is actually a straight line.
fn KArc::from_svg_arc(arc : KSvgArc) -> KArc? {
  // Have to check this first, otherwise `sum_of_sq` will be 0.
  if arc.is_straight_line() {
    return None
  }
  let mut rx = arc.radii.x.abs()
  let mut ry = arc.radii.y.abs()
  let xr = arc.x_rotation % (2.0 * k_pi)
  let sin_phi = libm_sin(xr)
  let cos_phi = libm_cos(xr)
  let hd_x = (arc.from.x - arc.to.x) * 0.5
  let hd_y = (arc.from.y - arc.to.y) * 0.5
  let hs_x = (arc.from.x + arc.to.x) * 0.5
  let hs_y = (arc.from.y + arc.to.y) * 0.5

  // F6.5.1
  let p : KPoint = {
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
  let center : KPoint = {
    x: cos_phi * transformed_cx - sin_phi * transformed_cy + hs_x,
    y: sin_phi * transformed_cx + cos_phi * transformed_cy + hs_y,
  }
  let start_v : KPoint = {
    x: (p.x - transformed_cx) / rx,
    y: (p.y - transformed_cy) / ry,
  }
  let end_v : KPoint = {
    x: (-p.x - transformed_cx) / rx,
    y: (-p.y - transformed_cy) / ry,
  }
  let start_angle = libm_atan2(start_v.y, start_v.x)
  let mut sweep_angle = (libm_atan2(end_v.y, end_v.x) - start_angle) %
    (2.0 * k_pi)
  if arc.sweep && sweep_angle < 0.0 {
    sweep_angle += 2.0 * k_pi
  } else if !arc.sweep && sweep_angle > 0.0 {
    sweep_angle -= 2.0 * k_pi
  }
  Some({
    center,
    radii: { x: rx, y: ry },
    start_angle,
    sweep_angle,
    x_rotation: arc.x_rotation,
  })
}

///|
/// Rust's `f64::signum`.
fn signum_f64(x : Double) -> Double {
  if x.is_nan() {
    x
  } else if is_sign_positive_f64(x) {
    1.0
  } else {
    -1.0
  }
}

///|
/// Converts an `Arc` into a series of cubic bezier segments
/// (`Arc::append_iter`).
///
/// The closure `p` will be invoked with the control points for each segment.
fn KArc::to_cubic_beziers(
  self : KArc,
  tolerance : Double,
  p : (KPoint, KPoint, KPoint) -> Unit,
) -> Unit {
  let sign = signum_f64(self.sweep_angle)
  let scaled_err = self.radii.x.max(self.radii.y) / tolerance
  // Number of subdivisions per ellipse based on error tolerance.
  // Note: this may slightly underestimate the error for quadrants.
  let n_err = libm_pow(1.1163 * scaled_err, 1.0 / 6.0).max(3.999_999)
  let n = (n_err * self.sweep_angle.abs() * (1.0 / (2.0 * k_pi))).ceil()
  let angle_step = self.sweep_angle / n
  let n = f64_as_usize(n)
  let arm_len = 4.0 / 3.0 * libm_tan((0.25 * angle_step).abs()) * sign
  let mut angle0 = self.start_angle
  let mut p0 = sample_ellipse(self.radii, self.x_rotation, angle0)
  for _ in 0..<n {
    let angle1 = angle0 + angle_step
    let p1 = p0.add(
      sample_ellipse(self.radii, self.x_rotation, angle0 + k_frac_pi_2).scale(
        arm_len,
      ),
    )
    let p3 = sample_ellipse(self.radii, self.x_rotation, angle1)
    let p2 = p3.sub(
      sample_ellipse(self.radii, self.x_rotation, angle1 + k_frac_pi_2).scale(
        arm_len,
      ),
    )
    angle0 = angle1
    p0 = p3
    p(self.center.add(p1), self.center.add(p2), self.center.add(p3))
  }
}

///|
/// Rust's saturating `f64 as usize` cast.
fn f64_as_usize(x : Double) -> Int {
  if x.is_nan() || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// Take the ellipse radii, how the radii are rotated, and the sweep angle, and return a point on
/// the ellipse.
fn sample_ellipse(radii : KPoint, x_rotation : Double, angle : Double) -> KPoint {
  let angle_sin = libm_sin(angle)
  let angle_cos = libm_cos(angle)
  let u = radii.x * angle_cos
  let v = radii.y * angle_sin
  rotate_pt({ x: u, y: v }, x_rotation)
}

///|
/// Rotate `pt` about the origin by `angle` radians.
fn rotate_pt(pt : KPoint, angle : Double) -> KPoint {
  let angle_sin = libm_sin(angle)
  let angle_cos = libm_cos(angle)
  {
    x: pt.x * angle_cos - pt.y * angle_sin,
    y: pt.x * angle_sin + pt.y * angle_cos,
  }
}
