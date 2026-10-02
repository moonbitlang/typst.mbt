// Port of `kurbo::offset` (0.13): computation of offset curves of cubic
// Béziers, used by stroke expansion. Includes the `CubicBez`/`QuadBez`
// helpers it needs (`regularize_cusp`, `inflections`, `nearest`) and the
// root finders `solve_cubic` and `solve_itp`.

///|
priv struct CubicBez {
  p0 : KPoint
  p1 : KPoint
  p2 : KPoint
  p3 : KPoint
}

///|
priv struct QuadBez {
  p0 : KPoint
  p1 : KPoint
  p2 : KPoint
}

///|
fn CubicBez::eval(self : CubicBez, t : Double) -> KPoint {
  let mt = 1.0 - t
  let v = self.p0
    .scale_r(mt * mt * mt)
    .add(
      self.p1
      .scale_r(mt * mt * 3.0)
      .add(self.p2.scale_r(mt * 3.0).add(self.p3.scale_r(t)).scale_r(t))
      .scale_r(t),
    )
  v
}

///|
/// `Vec2 * f64` (the vector on the left).
fn KPoint::scale_r(self : KPoint, s : Double) -> KPoint {
  { x: self.x * s, y: self.y * s, }
}

///|
fn CubicBez::deriv(self : CubicBez) -> QuadBez {
  {
    p0: self.p1.sub(self.p0).scale(3.0),
    p1: self.p2.sub(self.p1).scale(3.0),
    p2: self.p3.sub(self.p2).scale(3.0),
  }
}

///|
fn QuadBez::eval(self : QuadBez, t : Double) -> KPoint {
  let mt = 1.0 - t
  self.p0
  .scale_r(mt * mt)
  .add(self.p1.scale_r(mt * 2.0).add(self.p2.scale_r(t)).scale_r(t))
}

///|
/// The derivative of a quadratic Bézier: a line, returned as its endpoints.
fn QuadBez::deriv(self : QuadBez) -> (KPoint, KPoint) {
  (self.p1.sub(self.p0).scale(2.0), self.p2.sub(self.p1).scale(2.0))
}

///|
/// Find the nearest point, using analytical algorithm based on cubic root
/// finding (`QuadBez::nearest`). Returns `(t, distance_sq)`.
fn QuadBez::nearest(self : QuadBez, p : KPoint) -> (Double, Double) {
  let mut r_best : Double? = None
  let mut t_best = 0.0
  let eval_t = (t : Double, p0 : KPoint) => {
    let r = p0.sub(p).hypot2()
    let better = match r_best {
      Some(r_best) => r < r_best
      None => true
    }
    if better {
      r_best = Some(r)
      t_best = t
    }
  }
  let try_t = (t : Double) => {
    if !(t >= 0.0 && t <= 1.0) {
      return true
    }
    eval_t(t, self.eval(t))
    false
  }
  let d0 = self.p1.sub(self.p0)
  let d1 = self.p0.add(self.p2).sub(self.p1.scale(2.0))
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
    let r = try_t(t)
    need_ends = need_ends || r
  }
  if need_ends {
    eval_t(0.0, self.p0)
    eval_t(1.0, self.p2)
  }
  (t_best, r_best.unwrap())
}

///|
/// `f64::mul_add` (a fused multiply-add, emulated with error-free
/// transformations).
fn mul_add(a : Double, b : Double, c : Double) -> Double {
  let p = a * b
  if !f64_is_finite(p) || !f64_is_finite(c) {
    return p + c
  }
  // Dekker's TwoProduct: `a * b = p + e` exactly.
  let split = (x : Double) => {
    let f = 134217729.0 * x // 2^27 + 1
    let hi = f - (f - x)
    (hi, x - hi)
  }
  let (ah, al) = split(a)
  let (bh, bl) = split(b)
  let e = al * bl - (p - ah * bh - al * bh - ah * bl)
  // TwoSum: `p + c = s + t` exactly.
  let s = p + c
  let bb = s - p
  let t = p - (s - bb) + (c - bb)
  s + (t + e)
}

///|
/// Find real roots of cubic equation (`kurbo::common::solve_cubic`).
fn solve_cubic(
  c0 : Double,
  c1 : Double,
  c2 : Double,
  c3 : Double,
) -> Array[Double] {
  let result = []
  let c3_recip = 1.0 / c3
  let onethird = 1.0 / 3.0
  let scaled_c2 = c2 * (onethird * c3_recip)
  let scaled_c1 = c1 * (onethird * c3_recip)
  let scaled_c0 = c0 * c3_recip
  if !(f64_is_finite(scaled_c0) &&
    f64_is_finite(scaled_c1) &&
    f64_is_finite(scaled_c2)) {
    // cubic coefficient is zero or nearly so.
    return solve_quadratic(c0, c1, c2)
  }
  let (c0, c1, c2) = (scaled_c0, scaled_c1, scaled_c2)
  // (d0, d1, d2) is called "Delta" in article
  let d0 = mul_add(-c2, c2, c1)
  let d1 = mul_add(-c1, c2, c0)
  let d2 = c2 * c0 - c1 * c1
  // d is called "Discriminant"
  let d = 4.0 * d0 * d2 - d1 * d1
  // de is called "Depressed.x", Depressed.y = d0
  let de = mul_add(-2.0 * c2, d0, d1)
  if d < 0.0 {
    let sq = (-0.25 * d).sqrt()
    let r = -0.5 * de
    let t1 = libm_cbrt(r + sq) + libm_cbrt(r - sq)
    result.push(t1 - c2)
  } else if d == 0.0 {
    let t1 = copysign((-d0).sqrt(), de)
    result.push(t1 - c2)
    result.push(-2.0 * t1 - c2)
  } else {
    let th = libm_atan2(d.sqrt(), -de) * onethird
    // (th_cos, th_sin) is called "CubicRoot"
    let th_sin = @math.sin(th)
    let th_cos = @math.cos(th)
    // (r0, r1, r2) is called "Root"
    let r0 = th_cos
    let ss3 = th_sin * (3.0 : Double).sqrt()
    let r1 = 0.5 * (-th_cos + ss3)
    let r2 = 0.5 * (-th_cos - ss3)
    let t = 2.0 * (-d0).sqrt()
    result.push(mul_add(t, r0, -c2))
    result.push(mul_add(t, r1, -c2))
    result.push(mul_add(t, r2, -c2))
  }
  result
}

///|
/// Solve an arbitrary function for a zero-crossing with the ITP method
/// (`kurbo::common::solve_itp`).
fn solve_itp(
  f : (Double) -> Double,
  a : Double,
  b : Double,
  epsilon : Double,
  n0 : Int,
  k1 : Double,
  ya : Double,
  yb : Double,
) -> Double {
  let mut a = a
  let mut b = b
  let mut ya = ya
  let mut yb = yb
  let n1_2 = f64_max(libm_log2((b - a) / epsilon).ceil() - 1.0, 0.0).to_int()
  let nmax = n0 + n1_2
  let mut scaled_epsilon = epsilon * (1UL << nmax).to_double()
  while b - a > 2.0 * epsilon {
    let x1_2 = 0.5 * (a + b)
    let r = scaled_epsilon - 0.5 * (b - a)
    let xf = (yb * a - ya * b) / (yb - ya)
    let sigma = x1_2 - xf
    // This has k2 = 2 hardwired for efficiency.
    let delta = k1 * ((b - a) * (b - a))
    let xt = if delta <= (x1_2 - xf).abs() {
      xf + copysign(delta, sigma)
    } else {
      x1_2
    }
    let xitp = if (xt - x1_2).abs() <= r {
      xt
    } else {
      x1_2 - copysign(r, sigma)
    }
    let yitp = f(xitp)
    if yitp > 0.0 {
      b = xitp
      yb = yitp
    } else if yitp < 0.0 {
      a = xitp
      ya = yitp
    } else {
      return 0.5 * (xitp + xitp)
    }
    scaled_epsilon *= 0.5
  }
  0.5 * (a + b)
}

///|
/// Find inflection points (`CubicBez::inflections`).
fn CubicBez::inflections(self : CubicBez) -> Array[Double] {
  let a = self.p1.sub(self.p0)
  let b = self.p2.sub(self.p1).sub(a)
  let c = self.p3.sub(self.p0).sub(self.p2.sub(self.p1).scale(3.0))
  solve_quadratic(a.cross(b), a.cross(c), b.cross(c)).filter(t => {
    t >= 0.0 && t <= 1.0
  })
}

///|
priv enum CuspType {
  Loop
  DoubleInflection
}

///|
/// Preprocess a cubic Bézier to ease numerical robustness
/// (`CubicBez::regularize_cusp`).
fn CubicBez::regularize_cusp(self : CubicBez, dimension : Double) -> CubicBez {
  let mut p1 = self.p1
  let mut p2 = self.p2
  // First step: if control point is too near the endpoint, nudge it away
  // along the tangent.
  if self.detect_cusp(dimension) is Some(cusp_type) {
    let d01 = self.p1.sub(self.p0)
    let d01h = d01.hypot()
    let d23 = self.p3.sub(self.p2)
    let d23h = d23.hypot()
    match cusp_type {
      Loop => {
        p1 = p1.add(d01.scale(dimension / d01h))
        p2 = p2.sub(d23.scale(dimension / d23h))
      }
      DoubleInflection => {
        // Avoid making control distance smaller than dimension
        if d01h > 2.0 * dimension {
          p1 = p1.sub(d01.scale(dimension / d01h))
        }
        if d23h > 2.0 * dimension {
          p2 = p2.add(d23.scale(dimension / d23h))
        }
      }
    }
  }
  { ..self, p1, p2, }
}

///|
/// Detect whether there is a cusp (`CubicBez::detect_cusp`).
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
    let (nearest_t, distance_sq) = q.nearest(k_origin)
    // detect whether curvature at minimum derivative exceeds 1/dimension,
    // without division.
    let d = q.eval(nearest_t)
    let (l0, l1) = q.deriv()
    // `Line::eval`: `p0.lerp(p1, t)`.
    let d2 = l0.add(l1.sub(l0).scale(nearest_t))
    let cross = d.cross(d2)
    if distance_sq * distance_sq * distance_sq <=
      cross * dimension * (cross * dimension) {
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

///|
/// State used for computing an offset curve of a single cubic.
priv struct CubicOffset {
  /// The cubic being offset. This has been regularized.
  c : CubicBez
  /// The derivative of `c`.
  q : QuadBez
  /// The offset distance (same as the argument).
  d : Double
  /// `c0 + c1 t + c2 t^2` is the cross product of second and first
  /// derivatives of the underlying cubic, multiplied by the offset. This is
  /// used for computing cusps on the offset curve.
  c0 : Double
  c1 : Double
  c2 : Double
  /// The tolerance (same as the argument).
  tolerance : Double
}

///|
/// We never let cusp values have an absolute value smaller than this. When
/// a cusp is found, determine its sign and use this value.
let cusp_epsilon : Double = 1.0e-12

///|
/// Number of points for least-squares fit and error evaluation.
let n_lse : Int = 8

///|
/// The proportion of transverse error that is blended in the least-squares
/// logic.
let blend : Double = 1.0e-3

///|
/// Maximum recursion depth.
let max_depth : Int = 8

///|
/// State local to a subdivision
priv struct OffsetRec {
  t0 : Double
  t1 : Double
  // unit tangent at t0
  utan0 : KPoint
  // unit tangent at t1
  utan1 : KPoint
  cusp0 : Double
  cusp1 : Double
  /// Recursion depth
  depth : Int
}

///|
/// Result of error evaluation
priv struct ErrEval {
  /// Maximum detected error
  err_squared : Double
  /// Unit normals sampled uniformly across approximation
  unorms : Array[KPoint]
  /// Difference between point on source curve and normal from approximation.
  err_vecs : Array[KPoint]
}

///|
/// Compute an approximate offset curve (`kurbo::offset::offset_cubic`).
///
/// The parallel curve of `c` offset by `d` is returned as path elements
/// (starting with a `MoveTo`).
fn offset_cubic(c : CubicBez, d : Double, tolerance : Double) -> Array[PathEl] {
  let result = KPath::new()
  // A tuning parameter for regularization.
  let dim_tune = 0.25
  let c_regularized = c.regularize_cusp(tolerance * dim_tune)
  let co = CubicOffset::new(c_regularized, d, tolerance)
  let (tan0, tan1) = cubic_tangents(c.p0, c.p1, c.p2, c.p3)
  let utan0 = tan0.normalize()
  let utan1 = tan1.normalize()
  let cusp0 = co.endpoint_cusp(co.q.p0, co.c0)
  let cusp1 = co.endpoint_cusp(co.q.p2, co.c0 + co.c1 + co.c2)
  result.move_to(c.p0.add(utan0.turn_90().scale(d)))
  let rec : OffsetRec = {
    t0: 0.0,
    t1: 1.0,
    utan0,
    utan1,
    cusp0,
    cusp1,
    depth: 0,
  }
  co.offset_rec(rec, result)
  result.els
}

///|
/// Create a new curve from Bézier segment and offset.
fn CubicOffset::new(
  c : CubicBez,
  d : Double,
  tolerance : Double,
) -> CubicOffset {
  let q = c.deriv()
  let d2 = 2.0 * d
  let p1xp0 = q.p1.cross(q.p0)
  let p2xp0 = q.p2.cross(q.p0)
  let p2xp1 = q.p2.cross(q.p1)
  {
    c,
    q,
    d,
    c0: d2 * p1xp0,
    c1: d2 * (p2xp0 - 2.0 * p1xp0),
    c2: d2 * (p2xp1 - p2xp0 + p1xp0),
    tolerance,
  }
}

///|
/// Compute curvature of the source curve times offset plus 1.
fn CubicOffset::cusp_sign(self : CubicOffset, t : Double) -> Double {
  let ds2 = self.q.eval(t).hypot2()
  ((self.c2 * t + self.c1) * t + self.c0) / (ds2 * ds2.sqrt()) + 1.0
}

///|
/// Compute cusp value of endpoint.
fn CubicOffset::endpoint_cusp(
  _self : CubicOffset,
  tan : KPoint,
  y : Double,
) -> Double {
  // Robustness to avoid divide-by-zero when derivatives vanish
  let tan_dist_epsilon = 1.0e-12
  let tan_dist = f64_max(tan.hypot(), tan_dist_epsilon)
  let rsqrt = 1.0 / tan_dist
  y * (rsqrt * rsqrt * rsqrt) + 1.0
}

///|
/// `f64::signum`.
fn signum(x : Double) -> Double {
  if x.is_nan() {
    x
  } else if x.reinterpret_as_uint64() >> 63 != 0 {
    -1.0
  } else {
    1.0
  }
}

///|
/// Primary entry point for recursive subdivision.
fn CubicOffset::offset_rec(
  self : CubicOffset,
  rec : OffsetRec,
  result : KPath,
) -> Unit {
  // First, determine whether the offset curve contains a cusp. If the sign
  // of the cusp value (curvature times offset plus 1) is different at the
  // subdivision endpoints, then there is definitely a cusp inside. Find it
  // and subdivide there.
  if rec.cusp0 * rec.cusp1 < 0.0 {
    let a = rec.t0
    let b = rec.t1
    let s = signum(rec.cusp1)
    let f = (t : Double) => s * self.cusp_sign(t)
    let k1 = 0.2 / (b - a)
    let itp_eps = 1.0e-12
    let t = solve_itp(f, a, b, itp_eps, 1, k1, s * rec.cusp0, s * rec.cusp1)
    let utan_t = self.q.eval(t).normalize()
    let cusp_t_minus = copysign(cusp_epsilon, rec.cusp0)
    let cusp_t_plus = copysign(cusp_epsilon, rec.cusp1)
    self.subdivide(rec, result, t, utan_t, cusp_t_minus, cusp_t_plus)
    return
  }
  // We determine the first approximation to the offset curve.
  let (a0, b0) = self.draw_arc(rec)
  let mut a = a0
  let mut b = b0
  let dt = (rec.t1 - rec.t0) * (1.0 / (n_lse + 1).to_double())
  // These represent t values on the source curve.
  let ts = Array::makei(n_lse, i => rec.t0 + (i + 1).to_double() * dt)
  let mut c_approx = self.apply(rec, a, b)
  let mut err = self.eval_err(rec, c_approx, ts)
  // Number of least-squares refinement steps.
  let n_refine = 2
  for _ in 0..<n_refine {
    if err.err_squared <= self.tolerance * self.tolerance {
      break
    }
    let (a2, b2) = self.refine_least_squares(rec, a, b, err)
    let c_approx2 = self.apply(rec, a2, b2)
    let err2 = self.eval_err(rec, c_approx2, ts)
    if err2.err_squared >= err.err_squared {
      break
    }
    err = err2
    a = a2
    b = b2
    c_approx = c_approx2
  }
  if rec.depth < max_depth && err.err_squared > self.tolerance * self.tolerance {
    let (t, utan) = self.find_subdivision_point(rec)
    let cusp = self.cusp_sign(t)
    self.subdivide(rec, result, t, utan, cusp, cusp)
  } else {
    result.curve_to(c_approx.p1, c_approx.p2, c_approx.p3)
  }
}

///|
/// Recursively subdivide.
fn CubicOffset::subdivide(
  self : CubicOffset,
  rec : OffsetRec,
  result : KPath,
  t : Double,
  utan_t : KPoint,
  cusp_t_minus : Double,
  cusp_t_plus : Double,
) -> Unit {
  let rec0 : OffsetRec = {
    t0: rec.t0,
    t1: t,
    utan0: rec.utan0,
    utan1: utan_t,
    cusp0: rec.cusp0,
    cusp1: cusp_t_minus,
    depth: rec.depth + 1,
  }
  self.offset_rec(rec0, result)
  let rec1 : OffsetRec = {
    t0: t,
    t1: rec.t1,
    utan0: utan_t,
    utan1: rec.utan1,
    cusp0: cusp_t_plus,
    cusp1: rec.cusp1,
    depth: rec.depth + 1,
  }
  self.offset_rec(rec1, result)
}

///|
/// Convert from (a, b) parameter space to the approximate cubic Bézier.
fn CubicOffset::apply(
  self : CubicOffset,
  rec : OffsetRec,
  a : Double,
  b : Double,
) -> CubicBez {
  // Scale factor from derivatives to displacements
  let s = 1.0 / 3.0 * (rec.t1 - rec.t0)
  let p0 = self.c.eval(rec.t0).add(rec.utan0.turn_90().scale(self.d))
  let l0 = s * self.q.eval(rec.t0).hypot() + a * self.d
  let mut p1 = p0
  if l0 * rec.cusp0 > 0.0 {
    p1 = p1.add(rec.utan0.scale(l0))
  }
  let p3 = self.c.eval(rec.t1).add(rec.utan1.turn_90().scale(self.d))
  let mut p2 = p3
  let l1 = s * self.q.eval(rec.t1).hypot() - b * self.d
  if l1 * rec.cusp1 > 0.0 {
    p2 = p2.sub(rec.utan1.scale(l1))
  }
  { p0, p1, p2, p3, }
}

///|
/// Compute arc approximation.
fn CubicOffset::draw_arc(
  _self : CubicOffset,
  rec : OffsetRec,
) -> (Double, Double) {
  let th = libm_atan2(rec.utan1.cross(rec.utan0), rec.utan1.dot(rec.utan0))
  let a = 2.0 / 3.0 / (1.0 + @math.cos(0.5 * th)) * 2.0 * @math.sin(0.5 * th)
  let b = -a
  (a, b)
}

///|
/// Evaluate error and also refine t values.
fn CubicOffset::eval_err(
  self : CubicOffset,
  rec : OffsetRec,
  c_approx : CubicBez,
  ts : Array[Double],
) -> ErrEval {
  let qa = c_approx.deriv()
  let mut err_squared = 0.0
  let unorms = Array::make(n_lse, k_origin)
  let err_vecs = Array::make(n_lse, k_origin)
  for i in 0..<n_lse {
    let ta = (i + 1).to_double() * (1.0 / (n_lse + 1).to_double())
    let mut t = ts[i]
    let p = self.c.eval(t)
    // Newton step to refine t value
    let pa = c_approx.eval(ta)
    let tana = qa.eval(ta)
    t += tana.dot(pa.sub(p)) / tana.dot(self.q.eval(t))
    t = f64_min(f64_max(t, rec.t0), rec.t1)
    ts[i] = t
    let cusp = signum(rec.cusp0)
    let unorm = tana.normalize().turn_90().scale(cusp)
    unorms[i] = unorm
    let p_new = self.c.eval(t).add(unorm.scale(self.d))
    let err_vec = pa.sub(p_new)
    err_vecs[i] = err_vec
    let mut dist_err_squared = err_vec.hypot2()
    if !f64_is_finite(dist_err_squared) {
      // A hack to make sure we reject bad refinements
      dist_err_squared = 1.0e12
    }
    err_squared = f64_max(dist_err_squared, err_squared)
  }
  { err_squared, unorms, err_vecs, }
}

///|
/// Compute Bézier weights for evenly subdivided t values.
fn mk_a_weights(rev : Bool) -> Array[Double] {
  let result = Array::make(n_lse, 0.0)
  for i in 0..<n_lse {
    let t = (i + 1).to_double() / (n_lse + 1).to_double()
    let mt = 1.0 - t
    let ix = if rev { n_lse - 1 - i } else { i }
    result[ix] = 3.0 * mt * t * mt
  }
  result
}

///|
let a_weights : Array[Double] = mk_a_weights(false)

///|
let b_weights : Array[Double] = mk_a_weights(true)

///|
/// Refine an approximation, minimizing least squares error.
fn CubicOffset::refine_least_squares(
  self : CubicOffset,
  rec : OffsetRec,
  a : Double,
  b : Double,
  err : ErrEval,
) -> (Double, Double) {
  let mut aa = 0.0
  let mut ab = 0.0
  let mut ac = 0.0
  let mut bb = 0.0
  let mut bc = 0.0
  for i in 0..<n_lse {
    let n = err.unorms[i]
    let err_vec = err.err_vecs[i]
    let c_n = err_vec.dot(n)
    let c_t = err_vec.cross(n)
    let a_n = a_weights[i] * rec.utan0.dot(n)
    let a_t = a_weights[i] * rec.utan0.cross(n)
    let b_n = b_weights[i] * rec.utan1.dot(n)
    let b_t = b_weights[i] * rec.utan1.cross(n)
    aa += a_n * a_n + blend * (a_t * a_t)
    ab += a_n * b_n + blend * a_t * b_t
    ac += a_n * c_n + blend * a_t * c_t
    bb += b_n * b_n + blend * (b_t * b_t)
    bc += b_n * c_n + blend * b_t * c_t
  }
  let idet = 1.0 / (self.d * (aa * bb - ab * ab))
  let delta_a = idet * (ac * bb - ab * bc)
  let delta_b = idet * (aa * bc - ac * ab)
  (a - delta_a, b - delta_b)
}

///|
/// Decide where to subdivide when error is exceeded. Returns `(t, utan)`.
fn CubicOffset::find_subdivision_point(
  self : CubicOffset,
  rec : OffsetRec,
) -> (Double, KPoint) {
  let t = 0.5 * (rec.t0 + rec.t1)
  let q_t = self.q.eval(t)
  let x0 = rec.utan0.cross(q_t).abs()
  let x1 = rec.utan1.cross(q_t).abs()
  let subdivide_thresh = 0.1
  if x0 > subdivide_thresh * x1 && x1 > subdivide_thresh * x0 {
    let utan = q_t.normalize()
    return (t, utan)
  }
  let chord = self.c.eval(rec.t1).sub(self.c.eval(rec.t0))
  if chord.cross(rec.utan0) * chord.cross(rec.utan1) < 0.0 {
    let tan = rec.utan0.add(rec.utan1)
    if self.subdivide_for_tangent(rec.utan0, rec.t0, rec.t1, tan, false)
      is Some(subdivision) {
      return subdivision
    }
  }
  // Curve definitely has an inflection point
  // Try to subdivide based on integral of absolute curvature.

  // Tangents at recursion endpoints and inflection points.
  let tangents = [rec.utan0]
  let ts = [rec.t0]
  for t in self.c.inflections() {
    if t > rec.t0 && t < rec.t1 {
      tangents.push(self.q.eval(t))
      ts.push(t)
    }
  }
  tangents.push(rec.utan1)
  ts.push(rec.t1)
  let arc_angles = []
  let mut sum = 0.0
  for i in 0..<(tangents.length() - 1) {
    let tan0 = tangents[i]
    let tan1 = tangents[i + 1]
    let th = libm_atan2(tan0.cross(tan1), tan0.dot(tan1))
    sum += th.abs()
    arc_angles.push(th)
  }
  let mut target = sum * 0.5
  let mut i = 0
  while arc_angles[i].abs() < target {
    target -= arc_angles[i].abs()
    i += 1
  }
  let angle = copysign(target, arc_angles[i])
  let rotation : KPoint = { x: @math.cos(angle), y: @math.sin(angle), }
  let base = tangents[i]
  // `Vec2::rotate_scale`.
  let tan : KPoint = {
    x: base.x * rotation.x - base.y * rotation.y,
    y: base.x * rotation.y + base.y * rotation.x,
  }
  let utan0 = if i == 0 { rec.utan0 } else { base.normalize() }
  self.subdivide_for_tangent(utan0, ts[i], ts[i + 1], tan, true).unwrap()
}

///|
/// Find a subdivision point, given a tangent vector.
fn CubicOffset::subdivide_for_tangent(
  self : CubicOffset,
  utan0 : KPoint,
  t0 : Double,
  t1 : Double,
  tan : KPoint,
  force : Bool,
) -> (Double, KPoint)? {
  let mut t = 0.0
  let mut n_soln = 0
  // set up quadratic equation for matching tangents
  let z0 = tan.cross(self.q.p0)
  let z1 = tan.cross(self.q.p1)
  let z2 = tan.cross(self.q.p2)
  let c0 = z0
  let c1 = 2.0 * (z1 - z0)
  let c2 = z2 - z1 - (z1 - z0)
  for root in solve_quadratic(c0, c1, c2) {
    if root >= t0 && root <= t1 {
      t = root
      n_soln += 1
    }
  }
  if n_soln != 1 {
    if !force {
      return None
    }
    // Numerical failure, try to subdivide at cusp; we pick the smaller
    // derivative.
    if self.q.eval(t0).hypot2() > self.q.eval(t1).hypot2() {
      t = t1
    } else {
      t = t0
    }
  }
  let q = self.q.eval(t)
  let utan_epsilon = 1.0e-12
  let utan = if n_soln == 1 && q.hypot2() >= utan_epsilon {
    q.normalize()
  } else if tan.hypot2() >= utan_epsilon {
    // Curve has a zero-derivative cusp but angles well defined
    tan.normalize()
  } else {
    // 180 degree U-turn, arbitrarily pick a direction.
    utan0.turn_90()
  }
  Some((t, utan))
}
