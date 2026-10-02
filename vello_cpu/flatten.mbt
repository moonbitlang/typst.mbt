// Port of `vello_common/src/flatten.rs` and `vello_common/src/flatten_simd.rs`
// (flattening filled and stroked paths into lines; the SIMD cubic
// flattening is emulated lane by lane).

// The current tolerance is set to 0.25. Since `sqrt` doesn't work in const
// contexts, we instead hardcode the squared tolerance and derive the others
// from that.

///|
const SQRT_TOL : Double = 0.5

///|
const TOL : Double = 0.25

///|
const TOL_2 : Double = 0.0625

///|
/// A point with `f32` coordinates.
struct FPoint {
  x : Float
  y : Float
} derive(Eq, Show)

///|
fn FPoint::from_kurbo(p : @kurbo.Point) -> FPoint {
  { x: f32(p.x), y: f32(p.y) }
}

///|
/// A line.
struct Line {
  p0 : FPoint
  p1 : FPoint
} derive(Show)

///|
/// Flatten a filled Bézier path into line segments.
///
/// Open subpaths in the input path get closed by connecting the last
/// endpoint in the subpath to the starting point. The output lines may
/// describe open subpaths, as some path elements may have been culled.
fn fill(
  path : Array[@kurbo.PathEl],
  affine : @kurbo.Affine,
  line_buf : Array[Line],
  flatten_ctx : FlattenCtx,
  cull_bbox : RectU16,
) -> Unit {
  line_buf.clear()
  let lb = FlattenerCallback::{
    line_buf,
    start: { x: 0.0, y: 0.0 },
    p0: { x: 0.0, y: 0.0 },
    is_nan: false,
  }
  flatten_impl(path, affine, lb, flatten_ctx, cull_bbox)
  // A path that contains NaN is ill-defined, so ignore it.
  if lb.is_nan {
    line_buf.clear()
  }
}

///|
priv struct FlattenerCallback {
  line_buf : Array[Line]
  mut start : FPoint
  mut p0 : FPoint
  mut is_nan : Bool
}

///|
fn FlattenerCallback::move_to(self : FlattenerCallback, p : @kurbo.Point) -> Unit {
  self.is_nan = self.is_nan || p.x.is_nan() || p.y.is_nan()
  let p = FPoint::from_kurbo(p)
  self.start = p
  self.p0 = p
}

///|
fn FlattenerCallback::line_to(self : FlattenerCallback, p : @kurbo.Point) -> Unit {
  self.is_nan = self.is_nan || p.x.is_nan() || p.y.is_nan()
  let p = FPoint::from_kurbo(p)
  self.line_buf.push({ p0: self.p0, p1: p })
  self.p0 = p
}

///|
fn point_eq(a : @kurbo.Point, b : @kurbo.Point) -> Bool {
  a.x == b.x && a.y == b.y
}

///|
/// `ParamCurveNearest::nearest` for a `kurbo::Line`, returning the squared
/// distance.
fn line_nearest_distance_sq(
  p0 : @kurbo.Point,
  p1 : @kurbo.Point,
  p : @kurbo.Point,
) -> Double {
  let dx = p1.x - p0.x
  let dy = p1.y - p0.y
  let vx = p.x - p0.x
  let vy = p.y - p0.y
  let t = (dx * vx + dy * vy) / (dx * dx + dy * dy)
  let t = dmin(dmax(t, 0.0), 1.0)
  let ex = vx - t * dx
  let ey = vy - t * dy
  ex * ex + ey * ey
}

///|
/// See the docs for the kurbo implementation of flattening. This version
/// works using a similar approach but using f32x4/f32x8 SIMD instead.
fn flatten_impl(
  path : Array[@kurbo.PathEl],
  affine : @kurbo.Affine,
  callback : FlattenerCallback,
  flatten_ctx : FlattenCtx,
  cull_bbox : RectU16,
) -> Unit {
  flatten_ctx.flattened_cubics_len = 0
  // For the culling performed here to be correct, the top y coordinate of
  // the cull bbox must be aligned to strip row boundaries.
  let left = cull_bbox.x0.to_double()
  let top = (cull_bbox.y0 / TILE_HEIGHT * TILE_HEIGHT).to_double()
  let right = cull_bbox.x1.to_double()
  let bottom = cull_bbox.y1.to_double()
  if path.is_empty() {
    return
  }
  let first_el = path[0].transform(affine)
  guard first_el is MoveTo(start_pt) else { return }
  let mut start_pt = start_pt
  let mut last_pt = start_pt
  callback.move_to(start_pt)
  for idx in 1..<path.length() {
    match path[idx].transform(affine) {
      MoveTo(p) => {
        if !point_eq(last_pt, start_pt) {
          callback.line_to(start_pt)
        }
        last_pt = p
        start_pt = p
        callback.move_to(p)
      }
      LineTo(p) => {
        last_pt = p
        callback.line_to(p)
      }
      QuadTo(p1, p2) => {
        let p0 = last_pt
        // If the quadratic Bézier is fully to the right, top, or bottom of
        // the culling bbox, it does not impact pixel coverage or winding.
        if (p0.x > right && p1.x > right && p2.x > right) ||
          (p0.y < top && p1.y < top && p2.y < top) ||
          (p0.y > bottom && p1.y > bottom && p2.y > bottom) {
          callback.move_to(p2)
        } else if (p0.x < left && p1.x < left && p2.x < left) ||
          line_nearest_distance_sq(p0, p2, p1) <= 4.0 * TOL_2 {
          // If the quadratic Bézier is fully to the left of the culling
          // bbox, its exact shape does not matter; and an upper bound on
          // the distance of the curve to the line [p0, p2] is 1/2 of the
          // control-point-to-line distance.
          callback.line_to(p2)
        } else {
          let q = @kurbo.QuadBez::new(p0, p1, p2)
          let params = quad_estimate_subdiv(q, SQRT_TOL)
          let n = {
            let v = f64_as_usize((0.5 / SQRT_TOL * params.val).ceil())
            if v < 1 {
              1
            } else {
              v
            }
          }
          let step = 1.0 / n.to_double()
          for i in 1..<n {
            let u = i.to_double() * step
            let t = quad_determine_subdiv_t(params, u)
            let p = quad_eval(q, t)
            callback.line_to(p)
          }
          callback.line_to(p2)
        }
        last_pt = p2
      }
      CurveTo(p1, p2, p3) => {
        let p0 = last_pt
        if (p0.x > right && p1.x > right && p2.x > right && p3.x > right) ||
          (p0.y < top && p1.y < top && p2.y < top && p3.y < top) ||
          (p0.y > bottom && p1.y > bottom && p2.y > bottom && p3.y > bottom) {
          callback.move_to(p3)
        } else if (p0.x < left && p1.x < left && p2.x < left && p3.x < left) ||
          dmax(
            line_nearest_distance_sq(p0, p3, p1),
            line_nearest_distance_sq(p0, p3, p2),
          ) <=
          16.0 / 9.0 * TOL_2 {
          callback.line_to(p3)
        } else {
          let max = flatten_cubic_simd(p0, p1, p2, p3, flatten_ctx)
          let pts = flatten_ctx.flattened_cubics
          for k in 1..<max {
            callback.line_to(
              @kurbo.Point::new(pts[k * 2].to_double(), pts[k * 2 + 1].to_double()),
            )
          }
        }
        last_pt = p3
      }
      ClosePath =>
        if !point_eq(last_pt, start_pt) {
          callback.line_to(start_pt)
          // If `quad_to` [or another drawing op] is called immediately after
          // `close_path` then the current subpath starts at the initial
          // point of the previous subpath.
          last_pt = start_pt
        }
    }
  }
  if !point_eq(last_pt, start_pt) {
    callback.line_to(start_pt)
  }
}

///|
/// `f64 as usize` (saturating).
fn f64_as_usize(x : Double) -> Int {
  if x != x || x <= 0.0 {
    0
  } else if x >= 2147483647.0 {
    2147483647
  } else {
    x.to_int()
  }
}

///|
/// `QuadBez::eval`.
fn quad_eval(q : @kurbo.QuadBez, t : Double) -> @kurbo.Point {
  let mt = 1.0 - t
  let a = mt * mt
  let b = mt * 2.0
  @kurbo.Point::new(
    q.p0.x * a + (q.p1.x * b + q.p2.x * t) * t,
    q.p0.y * a + (q.p1.y * b + q.p2.y * t) * t,
  )
}

// The below methods are copied from kurbo and needed to implement flattening
// of normal quad curves.

///|
/// `D.powi(4)` for `D = 0.67` (constant-folded with `pow` by LLVM).
let d_powi_4 : Double = 0x3fc9cb1e8c5d1b10L.reinterpret_as_double()

///|
/// An approximation to $\int (1 + 4x^2) ^ -0.25 dx$
fn approx_parabola_integral(x : Double) -> Double {
  let d = 0.67
  x / (1.0 - d + (d_powi_4 + 0.25 * x * x).sqrt().sqrt())
}

///|
/// An approximation to the inverse parabola integral.
fn approx_parabola_inv_integral(x : Double) -> Double {
  let b = 0.39
  x * (1.0 - b + (b * b + 0.25 * x * x).sqrt())
}

///|
priv struct FlattenParams {
  a0 : Double
  a2 : Double
  u0 : Double
  uscale : Double
  /// The number of `subdivisions * 2 * sqrt_tol`.
  val : Double
}

///|
/// Rust's `f64::signum`.
fn f64_signum(x : Double) -> Double {
  if x != x {
    x
  } else if x.reinterpret_as_int64() < 0 {
    -1.0
  } else {
    1.0
  }
}

///|
fn quad_estimate_subdiv(q : @kurbo.QuadBez, sqrt_tol : Double) -> FlattenParams {
  // Determine transformation to $y = x^2$ parabola.
  let d01 = q.p1.sub(q.p0)
  let d12 = q.p2.sub(q.p1)
  let dd = d01 - d12
  let cross = q.p2.sub(q.p0).cross(dd)
  let x0 = d01.dot(dd) * (1.0 / cross)
  let x2 = d12.dot(dd) * (1.0 / cross)
  let scale = (cross / (dd.hypot() * (x2 - x0))).abs()
  // Compute number of subdivisions needed.
  let a0 = approx_parabola_integral(x0)
  let a2 = approx_parabola_integral(x2)
  let val = if !scale.is_nan() && !scale.is_inf() {
    let da = (a2 - a0).abs()
    let sqrt_scale = scale.sqrt()
    if f64_signum(x0) == f64_signum(x2) {
      da * sqrt_scale
    } else {
      // Handle cusp case (segment contains curvature maximum)
      let xmin = sqrt_tol / sqrt_scale
      sqrt_tol * da / approx_parabola_integral(xmin)
    }
  } else {
    0.0
  }
  let u0 = approx_parabola_inv_integral(a0)
  let u2 = approx_parabola_inv_integral(a2)
  let uscale = 1.0 / (u2 - u0)
  { a0, a2, u0, uscale, val }
}

///|
fn quad_determine_subdiv_t(params : FlattenParams, x : Double) -> Double {
  let a = params.a0 + (params.a2 - params.a0) * x
  let u = approx_parabola_inv_integral(a)
  (u - params.u0) * params.uscale
}

// Everything below is a SIMD implementation of flattening of cubic curves.

///|
/// This limit was chosen based on the pre-existing GitHub gist.
const MAX_QUADS : Int = 16

///|
/// The context needed for flattening curves. Points are stored as
/// interleaved `x, y` floats.
struct FlattenCtx {
  even_pts : FixedArray[Float]
  odd_pts : FixedArray[Float]
  a0 : FixedArray[Float]
  da : FixedArray[Float]
  u0 : FixedArray[Float]
  uscale : FixedArray[Float]
  val : FixedArray[Float]
  mut n_quads : Int
  /// Reusable buffer for flattened cubic points.
  mut flattened_cubics : FixedArray[Float]
  mut flattened_cubics_len : Int
}

///|
fn FlattenCtx::new() -> FlattenCtx {
  {
    even_pts: FixedArray::make((MAX_QUADS + 4) * 2, 0.0),
    odd_pts: FixedArray::make(MAX_QUADS * 2, 0.0),
    a0: FixedArray::make(MAX_QUADS, 0.0),
    da: FixedArray::make(MAX_QUADS, 0.0),
    u0: FixedArray::make(MAX_QUADS, 0.0),
    uscale: FixedArray::make(MAX_QUADS, 0.0),
    val: FixedArray::make(MAX_QUADS, 0.0),
    n_quads: 0,
    flattened_cubics: FixedArray::make(64, 0.0),
    flattened_cubics_len: 0,
  }
}

///|
/// Make sure `flattened_cubics` holds at least `points` points.
fn FlattenCtx::ensure_cubics(self : FlattenCtx, points : Int) -> Unit {
  if points * 2 > self.flattened_cubics.length() {
    let mut cap = self.flattened_cubics.length()
    while cap < points * 2 {
      cap = cap * 2
    }
    let new_buf = FixedArray::make(cap, (0.0 : Float))
    FixedArray::blit_to(
      self.flattened_cubics,
      new_buf,
      len=self.flattened_cubics.length(),
    )
    self.flattened_cubics = new_buf
  }
}

///|
/// SIMD version of `approx_parabola_integral` (one lane).
fn approx_parabola_integral_lane(x : Float) -> Float {
  let d_powi_4 : Float = 0.2015112
  let one_minus_d : Float = (1.0 : Float) - (0.67 : Float)
  let temp = madd(0.25, x * x, d_powi_4).sqrt().sqrt()
  let denom = temp + one_minus_d
  x / denom
}

///|
/// SIMD version of `approx_parabola_inv_integral` (one lane).
fn approx_parabola_inv_integral_lane(x : Float) -> Float {
  let b : Float = 0.39
  let one_minus_b : Float = (1.0 : Float) - b
  let temp = madd(0.25, x * x, b * b).sqrt()
  let factor = one_minus_b + temp
  x * factor
}

///|
fn eval_cubics_simd(
  p0 : @kurbo.Point,
  p1 : @kurbo.Point,
  p2 : @kurbo.Point,
  p3 : @kurbo.Point,
  n : Int,
  result : FlattenCtx,
) -> Unit {
  result.n_quads = n
  let dt = (0.5 : Float) / Float::from_int(n)
  // Lanes alternate x and y.
  let p0v : FixedArray[Float] = [f32(p0.x), f32(p0.y)]
  let p1v : FixedArray[Float] = [f32(p1.x), f32(p1.y)]
  let p2v : FixedArray[Float] = [f32(p2.x), f32(p2.y)]
  let p3v : FixedArray[Float] = [f32(p3.x), f32(p3.y)]
  // Use Horner's method to evaluate p(t) as ((a*t + b)*t + c)*t + d.
  let coeff_a = FixedArray::make(2, (0.0 : Float))
  let coeff_b = FixedArray::make(2, (0.0 : Float))
  let coeff_c = FixedArray::make(2, (0.0 : Float))
  for c in 0..<2 {
    coeff_a[c] = madd(p1v[c] - p2v[c], 3.0, p3v[c] - p0v[c])
    coeff_b[c] = madd(p1v[c], -2.0, p0v[c] + p2v[c]) * 3.0
    coeff_c[c] = (p1v[c] - p0v[c]) * 3.0
  }
  let iota : FixedArray[Float] = [0.0, 0.0, 2.0, 2.0, 1.0, 1.0, 3.0, 3.0]
  let t = FixedArray::make(8, (0.0 : Float))
  for l in 0..<8 {
    t[l] = iota[l] * dt
  }
  let t_inc = (4.0 : Float) * dt
  let even_pts = result.even_pts
  let odd_pts = result.odd_pts
  for i in 0..<div_ceil(n, 2) {
    for l in 0..<8 {
      let c = l % 2
      let evaluated = madd(
        madd(madd(coeff_a[c], t[l], coeff_b[c]), t[l], coeff_c[c]),
        t[l],
        p0v[c],
      )
      if l < 4 {
        even_pts[i * 4 + l] = evaluated
      } else {
        odd_pts[i * 4 + l - 4] = evaluated
      }
    }
    for l in 0..<8 {
      t[l] = t[l] + t_inc
    }
  }
  for l in 0..<8 {
    even_pts[n * 2 + l] = p3v[l % 2]
  }
}

///|
/// Lane `l` of an `f32x8` loaded from `arr` at float offset `off` (lanes
/// past the end read as zero, like the default-initialized arrays upstream).
fn lane_at(arr : FixedArray[Float], off : Int) -> Float {
  if off < arr.length() {
    arr[off]
  } else {
    0.0
  }
}

///|
fn estimate_subdiv_simd(sqrt_tol : Float, ctx : FlattenCtx) -> Unit {
  let n = ctx.n_quads
  let even_pts = ctx.even_pts
  let odd_pts = ctx.odd_pts
  let p0 = FixedArray::make(8, (0.0 : Float))
  let p1 = FixedArray::make(8, (0.0 : Float))
  let p2 = FixedArray::make(8, (0.0 : Float))
  for i in 0..<div_ceil(n, 4) {
    for l in 0..<8 {
      p0[l] = lane_at(even_pts, i * 8 + l)
      let p_onehalf = lane_at(odd_pts, i * 8 + l)
      p2[l] = lane_at(even_pts, i * 8 + 2 + l)
      let x = p0[l] * -0.5
      let x1 = madd(p_onehalf, 2.0, x)
      p1[l] = madd(p2[l], -0.5, x1)
      odd_pts[i * 8 + l] = p1[l]
    }
    // Per quad k (0..4): d01x = x lanes, d01y = y lanes.
    let x0_x2 = FixedArray::make(8, (0.0 : Float))
    let cross = FixedArray::make(4, (0.0 : Float))
    let ddx = FixedArray::make(4, (0.0 : Float))
    let ddy = FixedArray::make(4, (0.0 : Float))
    for k in 0..<4 {
      let d01x = p1[2 * k] - p0[2 * k]
      let d01y = p1[2 * k + 1] - p0[2 * k + 1]
      let d12x = p2[2 * k] - p1[2 * k]
      let d12y = p2[2 * k + 1] - p1[2 * k + 1]
      ddx[k] = d01x - d12x
      ddy[k] = d01y - d12y
      let d02x = d01x + d12x
      let d02y = d01y + d12y
      // (d02x * ddy) - (d02y * ddx)
      cross[k] = madd(ddx[k], -d02y, d02x * ddy[k])
      let x0_a = d12x * ddx[k]
      let x2_a = d01x * ddx[k]
      x0_x2[k] = madd(d12y, ddy[k], x0_a) / cross[k]
      x0_x2[k + 4] = madd(d01y, ddy[k], x2_a) / cross[k]
    }
    for k in 0..<4 {
      let dd_hypot = madd(ddy[k], ddy[k], ddx[k] * ddx[k]).sqrt()
      let x0 = x0_x2[k]
      let x2 = x0_x2[k + 4]
      let scale_denom = dd_hypot * (x2 - x0)
      let scale = (cross[k] / scale_denom).abs()
      let a0 = approx_parabola_integral_lane(x0)
      let a2 = approx_parabola_integral_lane(x2)
      let da = a2 - a0
      let da_abs = da.abs()
      let sqrt_scale = scale.sqrt()
      let temp3 = x0.reinterpret_as_int() | x2.reinterpret_as_int()
      let mask = temp3 >= 0
      let noncusp = da_abs * sqrt_scale
      let xmin = sqrt_tol / sqrt_scale
      let approxint = approx_parabola_integral_lane(xmin)
      let cusp = sqrt_tol * da_abs / approxint
      let val_raw = if mask { noncusp } else { cusp }
      let finite = val_raw.abs().reinterpret_as_uint() < 0x7f800000U
      let val = if finite { val_raw } else { 0.0 }
      let u0 = approx_parabola_inv_integral_lane(a0)
      let u2 = approx_parabola_inv_integral_lane(a2)
      let uscale_a = u2 - u0
      let uscale = (1.0 : Float) / uscale_a
      ctx.a0[i * 4 + k] = a0
      ctx.da[i * 4 + k] = da
      ctx.u0[i * 4 + k] = u0
      ctx.uscale[i * 4 + k] = uscale
      ctx.val[i * 4 + k] = val
    }
  }
}

///|
fn output_lines_simd(
  ctx : FlattenCtx,
  i : Int,
  x0 : Float,
  dx : Float,
  n : Int,
  start_idx : Int,
) -> Unit {
  let p0x = ctx.even_pts[i * 2]
  let p0y = ctx.even_pts[i * 2 + 1]
  let p1x = ctx.odd_pts[i * 2]
  let p1y = ctx.odd_pts[i * 2 + 1]
  let p2x = ctx.even_pts[i * 2 + 2]
  let p2y = ctx.even_pts[i * 2 + 3]
  let da = ctx.da[i]
  let a0 = ctx.a0[i]
  let a = FixedArray::make(4, (0.0 : Float))
  for k in 0..<4 {
    let x = madd(Float::from_int(k), dx, x0)
    a[k] = madd(da, x, a0)
  }
  let a_inc = (4.0 : Float) * dx * da
  let uscale = ctx.uscale[i]
  let u0 = ctx.u0[i]
  // See Horner comment above
  let coeff_ax = madd(p1x, -2.0, p0x) + p2x
  let coeff_ay = madd(p1y, -2.0, p0y) + p2y
  let coeff_bx = (p1x - p0x) * 2.0
  let coeff_by = (p1y - p0y) * 2.0
  let blocks = div_ceil(n, 4)
  ctx.ensure_cubics(start_idx + blocks * 4)
  let out = ctx.flattened_cubics
  for j in 0..<blocks {
    for k in 0..<4 {
      let u = approx_parabola_inv_integral_lane(a[k])
      let t = (u - u0) * uscale
      let base = (start_idx + j * 4 + k) * 2
      out[base] = madd(madd(coeff_ax, t, coeff_bx), t, p0x)
      out[base + 1] = madd(madd(coeff_ay, t, coeff_by), t, p0y)
      a[k] = a[k] + a_inc
    }
  }
}

///|
fn flatten_cubic_simd(
  p0 : @kurbo.Point,
  p1 : @kurbo.Point,
  p2 : @kurbo.Point,
  p3 : @kurbo.Point,
  ctx : FlattenCtx,
) -> Int {
  let n_quads = estimate_num_quads(p0, p1, p2, p3, f32(TOL))
  eval_cubics_simd(p0, p1, p2, p3, n_quads, ctx)
  let tol = f32(TOL) * ((1.0 : Float) - to_quad_tol)
  let sqrt_tol = tol.sqrt()
  estimate_subdiv_simd(sqrt_tol, ctx)
  let mut sum : Float = 0.0
  for i in 0..<n_quads {
    sum = sum + ctx.val[i]
  }
  let n = {
    let v = f32_as_usize(((0.5 : Float) * sum / sqrt_tol).ceil())
    if v < 1 {
      1
    } else {
      v
    }
  }
  ctx.ensure_cubics(n + 4)
  let step = sum / Float::from_int(n)
  let step_recip = (1.0 : Float) / step
  let mut val_sum : Float = 0.0
  let mut last_n = 0
  let mut x0base : Float = 0.0
  for i in 0..<n_quads {
    let val = ctx.val[i]
    val_sum = val_sum + val
    let this_n = val_sum * step_recip
    let this_n_next = (1.0 : Float) + this_n.floor()
    let dn = f32_as_usize(this_n_next) - last_n
    if dn > 0 {
      let dx = step / val
      let x0 = x0base * dx
      output_lines_simd(ctx, i, x0, dx, dn, last_n)
    }
    x0base = this_n_next - this_n
    last_n = f32_as_usize(this_n_next)
  }
  ctx.flattened_cubics[n * 2] = ctx.even_pts[n_quads * 2]
  ctx.flattened_cubics[n * 2 + 1] = ctx.even_pts[n_quads * 2 + 1]
  n + 1
}

///|
const TO_QUAD_TOL_D : Double = 0.1

///|
let to_quad_tol : Float = 0.1

///|
fn estimate_num_quads(
  p0 : @kurbo.Point,
  p1 : @kurbo.Point,
  p2 : @kurbo.Point,
  p3 : @kurbo.Point,
  accuracy : Float,
) -> Int {
  let q_accuracy = (accuracy * to_quad_tol).to_double()
  let max_hypot2 = 432.0 * q_accuracy * q_accuracy
  let p1x2x = p1.x * 3.0 - p0.x
  let p1x2y = p1.y * 3.0 - p0.y
  let p2x2x = p2.x * 3.0 - p3.x
  let p2x2y = p2.y * 3.0 - p3.y
  let ex = p2x2x - p1x2x
  let ey = p2x2y - p1x2y
  let err = ex * ex + ey * ey
  let err_div = err / max_hypot2
  estimate(err_div)
}

///|
let estimate_lut : FixedArray[Double] = [
  1.0, 64.0, 729.0, 4096.0, 15625.0, 46656.0, 117649.0, 262144.0, 531441.0, 1000000.0,
  1771561.0, 2985984.0, 4826809.0, 7529536.0, 11390625.0, 16777216.0,
]

///|
fn estimate(err_div : Double) -> Int {
  // Equivalent to `(err_div.powf(1. / 6.0).ceil() as usize).max(1)` clamped
  // to `MAX_QUADS`, using a lookup table.
  for i in 0..<MAX_QUADS {
    if err_div <= estimate_lut[i] {
      return i + 1
    }
  }
  MAX_QUADS
}
