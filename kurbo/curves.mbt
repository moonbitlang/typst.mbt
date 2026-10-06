// Port of `kurbo` 0.13 `line.rs`, `quadbez.rs` and `cubicbez.rs` (the parts
// used by hayro: evaluation, extrema and bounding boxes).

///|
/// A single line.
pub(all) struct Line {
  /// The line's start point.
  p0 : Point
  /// The line's end point.
  p1 : Point
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Line with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Line with @debug.Debug::{to_repr}

///|
/// Create a new line.
pub fn Line::new(p0 : Point, p1 : Point) -> Line {
  { p0, p1, }
}

///|
/// Evaluate the line at parameter `t`.
pub fn Line::eval(self : Line, t : Double) -> Point {
  self.p0.lerp(self.p1, t)
}

///|
/// A single quadratic Bézier segment.
pub(all) struct QuadBez {
  p0 : Point
  p1 : Point
  p2 : Point
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend QuadBez with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend QuadBez with @debug.Debug::{to_repr}

///|
/// Create a new quadratic Bézier segment.
pub fn QuadBez::new(p0 : Point, p1 : Point, p2 : Point) -> QuadBez {
  { p0, p1, p2, }
}

///|
/// Evaluate the curve at parameter `t`.
pub fn QuadBez::eval(self : QuadBez, t : Double) -> Point {
  let mt = 1.0 - t
  (self.p0.to_vec2().scale(mt * mt) +
  (self.p1.to_vec2().scale(mt * 2.0) + self.p2.to_vec2().scale(t)).scale(t)).to_point()
}

///|
/// Compute the extrema of the curve.
pub fn QuadBez::extrema(self : QuadBez) -> Array[Double] {
  let result = []
  let d0 = self.p1.sub(self.p0)
  let d1 = self.p2.sub(self.p1)
  let dd = d1 - d0
  if dd.x != 0.0 {
    let t = -d0.x / dd.x
    if t > 0.0 && t < 1.0 {
      result.push(t)
    }
  }
  if dd.y != 0.0 {
    let t = -d0.y / dd.y
    if t > 0.0 && t < 1.0 {
      result.push(t)
      if result.length() == 2 && result[0] > t {
        result.swap(0, 1)
      }
    }
  }
  result
}

///|
/// A single cubic Bézier segment.
pub(all) struct CubicBez {
  p0 : Point
  p1 : Point
  p2 : Point
  p3 : Point
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CubicBez with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CubicBez with @debug.Debug::{to_repr}

///|
/// Create a new cubic Bézier segment.
pub fn CubicBez::new(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
) -> CubicBez {
  { p0, p1, p2, p3, }
}

///|
/// Evaluate the curve at parameter `t`.
pub fn CubicBez::eval(self : CubicBez, t : Double) -> Point {
  let mt = 1.0 - t
  let v = self.p0.to_vec2().scale(mt * mt * mt) +
    (self.p1.to_vec2().scale(mt * mt * 3.0) +
    (self.p2.to_vec2().scale(mt * 3.0) + self.p3.to_vec2().scale(t)).scale(t)).scale(
      t,
    )
  v.to_point()
}

///|
/// `Affine * CubicBez`.
pub fn CubicBez::transform(self : CubicBez, t : Affine) -> CubicBez {
  {
    p0: t.apply(self.p0),
    p1: t.apply(self.p1),
    p2: t.apply(self.p2),
    p3: t.apply(self.p3),
  }
}

///|
/// Compute the extrema of the curve.
pub fn CubicBez::extrema(self : CubicBez) -> Array[Double] {
  let result = []
  fn one_coord(result : Array[Double], d0 : Double, d1 : Double, d2 : Double) {
    let a = d0 - 2.0 * d1 + d2
    let b = 2.0 * (d1 - d0)
    let c = d0
    let roots = solve_quadratic(c, b, a)
    for t in roots {
      if t > 0.0 && t < 1.0 {
        result.push(t)
      }
    }
  }

  let d0 = self.p1.sub(self.p0)
  let d1 = self.p2.sub(self.p1)
  let d2 = self.p3.sub(self.p2)
  one_coord(result, d0.x, d1.x, d2.x)
  one_coord(result, d0.y, d1.y, d2.y)
  // Insertion sort (stable; the values are never NaN).
  for i in 1..<result.length() {
    let mut j = i
    while j > 0 && result[j - 1] > result[j] {
      result.swap(j - 1, j)
      j -= 1
    }
  }
  result
}

///|
/// The smallest rectangle that encloses the curve
/// (`ParamCurveExtrema::bounding_box`).
pub fn CubicBez::bounding_box(self : CubicBez) -> Rect {
  let mut bbox = Rect::from_points(self.p0, self.p3)
  for t in self.extrema() {
    bbox = bbox.union_pt(self.eval(t))
  }
  bbox
}

// --- Line: `ParamCurve`, `ParamCurveArclen`, `ParamCurveNearest` ---

///|
/// Get a subsegment of the line (`ParamCurve::subsegment(t0..t1)`).
pub fn Line::subsegment(self : Line, t0 : Double, t1 : Double) -> Line {
  { p0: self.eval(t0), p1: self.eval(t1), }
}

///|
/// The arc length of the line (`ParamCurveArclen::arclen`).
pub fn Line::arclen(self : Line, _accuracy : Double) -> Double {
  self.p1.sub(self.p0).hypot()
}

///|
/// Solve for the parameter that has the given arc length from the start
/// (`ParamCurveArclen::inv_arclen`).
pub fn Line::inv_arclen(
  self : Line,
  arclen : Double,
  _accuracy : Double,
) -> Double {
  arclen / self.p1.sub(self.p0).hypot()
}

///|
/// The length of the line.
pub fn Line::length(self : Line) -> Double {
  self.arclen(DEFAULT_ACCURACY)
}

///|
/// Find the position on the line nearest the given point
/// (`ParamCurveNearest::nearest`).
pub fn Line::nearest(self : Line, p : Point, _accuracy : Double) -> Nearest {
  let d = self.p1.sub(self.p0)
  let v = p.sub(self.p0)

  // Calculate projection parameter `t` of the point onto the line segment
  // s(t), with s(t) = (1-t) * p0 + t * p1.
  //
  // Note when the segment has 0 length, this will be positive or negative
  // infinity or NaN; see the clamping below.
  let t = d.dot(v) / d.hypot2()

  // Clamp the parameter to be on the line segment. This clamps negative
  // infinity and NaN to `0.`, and positive infinity to `1.`.
  let t = fmin(fmax(t, 0.0), 1.0)

  // Calculate ||p - s(t)||^2.
  let distance_sq = (v - d.scale(t)).hypot2()
  { distance_sq, t, }
}

// --- QuadBez ---

///|
/// Raise the order by 1 (upstream `QuadBez::raise`; `raise` is a keyword).
///
/// Returns a cubic Bézier segment that exactly represents this quadratic.
pub fn QuadBez::raise_order(self : QuadBez) -> CubicBez {
  CubicBez::new(
    self.p0,
    self.p0.add_vec(self.p1.sub(self.p0).scale(2.0 / 3.0)),
    self.p2.add_vec(self.p1.sub(self.p2).scale(2.0 / 3.0)),
    self.p2,
  )
}

///|
/// Get a subsegment of the curve (`ParamCurve::subsegment(t0..t1)`).
pub fn QuadBez::subsegment(self : QuadBez, t0 : Double, t1 : Double) -> QuadBez {
  let p0 = self.eval(t0)
  let p2 = self.eval(t1)
  let p1 = p0.add_vec(
    self.p1.sub(self.p0).lerp(self.p2.sub(self.p1), t0).scale(t1 - t0),
  )
  { p0, p1, p2, }
}

///|
/// Subdivide into halves, using de Casteljau.
pub fn QuadBez::subdivide(self : QuadBez) -> (QuadBez, QuadBez) {
  let pm = self.eval(0.5)
  (
    QuadBez::new(self.p0, self.p0.midpoint(self.p1), pm),
    QuadBez::new(pm, self.p1.midpoint(self.p2), self.p2),
  )
}

///|
/// The derivative of the curve (`ParamCurveDeriv::deriv`).
pub fn QuadBez::deriv(self : QuadBez) -> Line {
  Line::new(
    (self.p1.to_vec2() - self.p0.to_vec2()).scale(2.0).to_point(),
    (self.p2.to_vec2() - self.p1.to_vec2()).scale(2.0).to_point(),
  )
}

///|
/// Arclength of a quadratic Bézier segment (`ParamCurveArclen::arclen`).
///
/// This computation is based on an analytical formula. Since that formula
/// suffers from numerical instability when the curve is very close to a
/// straight line, we detect that case and fall back to Legendre-Gauss
/// quadrature.
///
/// Accuracy should be better than 1e-13 over the entire range.
///
/// Adapted from <http://www.malczak.linuxpl.com/blog/quadratic-bezier-curve-length/>
/// with permission.
pub fn QuadBez::arclen(self : QuadBez, _accuracy : Double) -> Double {
  let d2 = self.p0.to_vec2() - self.p1.to_vec2().scale(2.0) + self.p2.to_vec2()
  let a = d2.hypot2()
  let d1 = self.p1.sub(self.p0)
  let c = d1.hypot2()
  if a < 5.0e-4 * c {
    // This case happens for nearly straight Béziers.
    //
    // Calculate arclength using Legendre-Gauss quadrature using formula
    // from Behdad in https://github.com/Pomax/BezierInfo-2/issues/77
    let v0 = (self.p0.to_vec2().scale(-0.492943519233745) +
    self.p1.to_vec2().scale(0.430331482911935) +
    self.p2.to_vec2().scale(0.0626120363218102)).hypot()
    let v1 = self.p2.sub(self.p0).scale(0.4444444444444444).hypot()
    let v2 = (self.p0.to_vec2().scale(-0.0626120363218102) -
    self.p1.to_vec2().scale(0.430331482911935) +
    self.p2.to_vec2().scale(0.492943519233745)).hypot()
    return v0 + v1 + v2
  }
  let b = 2.0 * d2.dot(d1)
  let sabc = (a + b + c).sqrt()
  let a2 = libm_pow(a, -0.5)
  let a32 = powi(a2, 3)
  let c2 = 2.0 * c.sqrt()
  let ba_c2 = b * a2 + c2
  let v0 = 0.25 * a2 * a2 * b * (2.0 * sabc - c2) + sabc
  // TODO: justify and fine-tune this exact constant.
  // The factor of a2 here is a little arbitrary: we really want
  // to test whether ba_c2 is small, but it's also important for
  // this comparison to be scale-invariant. We chose a2 (instead of,
  // for example, c2 on the rhs) because it's unchanged under
  // reversing the parametrization.
  if ba_c2 * a2 < 1.0e-13 {
    // This case happens for Béziers with a sharp kink.
    v0
  } else {
    v0 +
    0.25 *
    a32 *
    (4.0 * c * a - b * b) *
    libm_ln(((2.0 * a + b) * a2 + 2.0 * sabc) / ba_c2)
  }
}

///|
/// Solve for the parameter that has the given arc length from the start
/// (`ParamCurveArclen::inv_arclen`, default implementation).
pub fn QuadBez::inv_arclen(
  self : QuadBez,
  arclen : Double,
  accuracy : Double,
) -> Double {
  inv_arclen_default(arclen, accuracy, () => self.arclen(accuracy), fn(
    t0,
    t1,
    acc,
  ) {
    self.subsegment(t0, t1).arclen(acc)
  })
}

///|
/// Find the position on the curve nearest the given point, using an
/// analytical algorithm based on cubic root finding
/// (`ParamCurveNearest::nearest`).
pub fn QuadBez::nearest(
  self : QuadBez,
  p : Point,
  _accuracy : Double,
) -> Nearest {
  let r_best : Ref[Double?] = { val: None, }
  let t_best : Ref[Double] = { val: 0.0, }
  fn eval_t(t : Double, p0 : Point) {
    let r = p0.sub(p).hypot2()
    let better = match r_best.val {
      Some(rb) => r < rb
      None => true
    }
    if better {
      r_best.val = Some(r)
      t_best.val = t
    }
  }

  fn try_t(t : Double) -> Bool {
    if !(t >= 0.0 && t <= 1.0) {
      return true
    }
    eval_t(t, self.eval(t))
    false
  }

  let d0 = self.p1.sub(self.p0)
  let d1 = self.p0.to_vec2() + self.p2.to_vec2() - self.p1.to_vec2().scale(2.0)
  let d = self.p0.sub(p)
  let c0 = d.dot(d0)
  let c1 = 2.0 * d0.hypot2() + d.dot(d1)
  let c2 = 3.0 * d1.dot(d0)
  let c3 = d1.hypot2()
  let roots = solve_cubic(c0, c1, c2, c3)
  let mut need_ends = false
  if roots.is_empty() {
    need_ends = true
  }
  for t in roots {
    need_ends = try_t(t) || need_ends
  }
  if need_ends {
    eval_t(0.0, self.p0)
    eval_t(1.0, self.p2)
  }
  { t: t_best.val, distance_sq: r_best.val.unwrap(), }
}

// --- CubicBez ---

///|
/// Get a subsegment of the curve (`ParamCurve::subsegment(t0..t1)`).
pub fn CubicBez::subsegment(
  self : CubicBez,
  t0 : Double,
  t1 : Double,
) -> CubicBez {
  let p0 = self.eval(t0)
  let p3 = self.eval(t1)
  let d = self.deriv()
  let scale = (t1 - t0) * (1.0 / 3.0)
  let p1 = p0.add_vec(d.eval(t0).to_vec2().scale(scale))
  let p2 = p3.sub_vec(d.eval(t1).to_vec2().scale(scale))
  { p0, p1, p2, p3, }
}

///|
/// Subdivide into halves, using de Casteljau.
pub fn CubicBez::subdivide(self : CubicBez) -> (CubicBez, CubicBez) {
  let pm = self.eval(0.5)
  (
    CubicBez::new(
      self.p0,
      self.p0.midpoint(self.p1),
      (self.p0.to_vec2() + self.p1.to_vec2().scale(2.0) + self.p2.to_vec2())
      .scale(0.25)
      .to_point(),
      pm,
    ),
    CubicBez::new(
      pm,
      (self.p1.to_vec2() + self.p2.to_vec2().scale(2.0) + self.p3.to_vec2())
      .scale(0.25)
      .to_point(),
      self.p2.midpoint(self.p3),
      self.p3,
    ),
  )
}

///|
/// The derivative of the curve (`ParamCurveDeriv::deriv`).
pub fn CubicBez::deriv(self : CubicBez) -> QuadBez {
  QuadBez::new(
    self.p1.sub(self.p0).scale(3.0).to_point(),
    self.p2.sub(self.p1).scale(3.0).to_point(),
    self.p3.sub(self.p2).scale(3.0).to_point(),
  )
}

///|
fn arclen_quadrature_core(
  coeffs : ReadOnlyArray[(Double, Double)],
  dm : Vec2,
  dm1 : Vec2,
  dm2 : Vec2,
) -> Double {
  let mut sum = neg_zero
  for c in coeffs[:] {
    let (wi, xi) = c
    let d = dm + dm2.scale(xi * xi)
    let dpx = (d + dm1.scale(xi)).hypot()
    let dmx = (d - dm1.scale(xi)).hypot()
    // `2.25f64.sqrt()` is exactly 1.5.
    sum = sum + 1.5 * wi * (dpx + dmx)
  }
  sum
}

///|
fn arclen_rec(c : CubicBez, accuracy : Double, depth : Int) -> Double {
  let d03 = c.p3.sub(c.p0)
  let d01 = c.p1.sub(c.p0)
  let d12 = c.p2.sub(c.p1)
  let d23 = c.p3.sub(c.p2)
  let lp_lc = d01.hypot() + d12.hypot() + d23.hypot() - d03.hypot()
  let dd1 = d12 - d01
  let dd2 = d23 - d12
  // It might be faster to do direct multiplies, the data dependencies would
  // be shorter. The following values don't have the factor of 3 for first
  // deriv
  let dm = (d01 + d23).scale(0.25) + d12.scale(0.5) // first derivative at midpoint
  let dm1 = (dd2 + dd1).scale(0.5) // second derivative at midpoint
  let dm2 = (dd2 - dd1).scale(0.25) // 0.5 * (third derivative at midpoint)
  let mut est = neg_zero
  for co in gauss_legendre_coeffs_8[:] {
    let (wi, xi) = co
    let d_norm2 = (dm + dm1.scale(xi) + dm2.scale(xi * xi)).hypot2()
    let dd_norm2 = (dm1 + dm2.scale(2.0 * xi)).hypot2()
    est = est + wi * (dd_norm2 / d_norm2)
  }
  let est_gauss8_error = fmin(powi(est, 3) * 2.5e-6, 3.0e-2) * lp_lc
  if est_gauss8_error < accuracy {
    return arclen_quadrature_core(gauss_legendre_coeffs_8_half, dm, dm1, dm2)
  }
  let est_gauss16_error = fmin(powi(est, 6) * 1.5e-11, 9.0e-3) * lp_lc
  if est_gauss16_error < accuracy {
    return arclen_quadrature_core(gauss_legendre_coeffs_16_half, dm, dm1, dm2)
  }
  let est_gauss24_error = fmin(powi(est, 9) * 3.5e-16, 3.5e-3) * lp_lc
  if est_gauss24_error < accuracy || depth >= 20 {
    return arclen_quadrature_core(gauss_legendre_coeffs_24_half, dm, dm1, dm2)
  }
  let (c0, c1) = c.subdivide()
  arclen_rec(c0, accuracy * 0.5, depth + 1) +
  arclen_rec(c1, accuracy * 0.5, depth + 1)
}

///|
/// Arclength of a cubic Bézier segment (`ParamCurveArclen::arclen`).
///
/// This is an adaptive subdivision approach using Legendre-Gauss quadrature
/// in the base case, and an error estimate to decide when to subdivide.
pub fn CubicBez::arclen(self : CubicBez, accuracy : Double) -> Double {
  arclen_rec(self, accuracy, 0)
}

///|
/// Solve for the parameter that has the given arc length from the start
/// (`ParamCurveArclen::inv_arclen`, default implementation).
pub fn CubicBez::inv_arclen(
  self : CubicBez,
  arclen : Double,
  accuracy : Double,
) -> Double {
  inv_arclen_default(arclen, accuracy, () => self.arclen(accuracy), fn(
    t0,
    t1,
    acc,
  ) {
    self.subsegment(t0, t1).arclen(acc)
  })
}

///|
/// Determine the inflection points.
///
/// Return value is t parameter for the inflection points of the curve
/// segment. There are a maximum of two for a cubic Bézier.
///
/// See <https://www.caffeineowl.com/graphics/2d/vectorial/cubic-inflexion.html>
/// for the theory.
pub fn CubicBez::inflections(self : CubicBez) -> Array[Double] {
  let a = self.p1.sub(self.p0)
  let b = self.p2.sub(self.p1) - a
  let c = self.p3.sub(self.p0) - self.p2.sub(self.p1).scale(3.0)
  solve_quadratic(a.cross(b), a.cross(c), b.cross(c)).filter(t => {
    t >= 0.0 && t <= 1.0
  })
}

///|
/// Classification result for cusp detection.
pub(all) enum CuspType {
  /// Cusp is a loop.
  Loop
  /// Cusp has two closely spaced inflection points.
  DoubleInflection
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CuspType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CuspType with @debug.Debug::{to_repr}

///|
/// Preprocess a cubic Bézier to ease numerical robustness.
///
/// If the cubic Bézier segment has zero or near-zero derivatives as an
/// interior cusp, perturb the control points to make curvature finite,
/// avoiding numerical robustness problems in offset and stroke.
fn CubicBez::regularize_cusp(self : CubicBez, dimension : Double) -> CubicBez {
  let mut c = self
  // First step: if control point is too near the endpoint, nudge it away
  // along the tangent.
  if self.detect_cusp(dimension) is Some(cusp_type) {
    let d01 = c.p1.sub(c.p0)
    let d01h = d01.hypot()
    let d23 = c.p3.sub(c.p2)
    let d23h = d23.hypot()
    match cusp_type {
      Loop =>
        c = {
          ..c,
          p1: c.p1.add_vec(d01.scale(dimension / d01h)),
          p2: c.p2.sub_vec(d23.scale(dimension / d23h)),
        }
      DoubleInflection => {
        // Avoid making control distance smaller than dimension
        if d01h > 2.0 * dimension {
          c = { ..c, p1: c.p1.sub_vec(d01.scale(dimension / d01h)), }
        }
        if d23h > 2.0 * dimension {
          c = { ..c, p2: c.p2.add_vec(d23.scale(dimension / d23h)), }
        }
      }
    }
  }
  c
}

///|
/// Detect whether there is a cusp.
///
/// Return a cusp classification if there is a cusp with curvature greater
/// than the reciprocal of the given dimension.
fn CubicBez::detect_cusp(self : CubicBez, dimension : Double) -> CuspType? {
  let d01 = self.p1.sub(self.p0)
  let d02 = self.p2.sub(self.p0)
  let d03 = self.p3.sub(self.p0)
  let d12 = self.p2.sub(self.p1)
  let d23 = self.p3.sub(self.p2)
  let det_012 = d01.cross(d02)
  let det_123 = d12.cross(d23)
  let det_013 = d01.cross(d03)
  let det_023 = d02.cross(d03)
  if det_012 * det_123 > 0.0 &&
    det_012 * det_013 < 0.0 &&
    det_012 * det_023 < 0.0 {
    let q = self.deriv()
    // accuracy isn't used for quadratic nearest
    let nearest = q.nearest(point_zero, 1.0e-9)
    // detect whether curvature at minimum derivative exceeds 1/dimension,
    // without division.
    let d = q.eval(nearest.t)
    let d2 = q.deriv().eval(nearest.t)
    let cross = d.to_vec2().cross(d2.to_vec2())
    if powi(nearest.distance_sq, 3) <= powi(cross * dimension, 2) {
      let a = 3.0 * det_012 + det_023 - 2.0 * det_013
      let b = -3.0 * det_012 + det_013
      let c = det_012
      let d = b * b - 4.0 * a * c
      if d > 0.0 {
        return Some(DoubleInflection)
      } else {
        return Some(Loop)
      }
    }
  }
  None
}
