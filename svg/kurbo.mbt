// The pieces of the `kurbo` crate (0.13) behind upstream's `Shape::bbox`:
// path bounding boxes (`BezPath::bounding_box` with
// `CubicBez::bounding_box`) and stroke expansion (`kurbo::stroke`) for
// computing the bounding box of stroked shapes.
//
// Offset curves of cubic segments are computed with a port of
// `offset::offset_cubic` (see `kurbo_offset.mbt`).
//
// TODO: Dashing (`dash_iter`) is not ported; dashes are ignored. This only
// affects the placement of gradients on dashed curves.

///|
priv struct KPoint {
  x : Double
  y : Double
} derive(Eq)

///|
fn KPoint::add(self : KPoint, v : KPoint) -> KPoint {
  { x: self.x + v.x, y: self.y + v.y, }
}

///|
fn KPoint::sub(self : KPoint, v : KPoint) -> KPoint {
  { x: self.x - v.x, y: self.y - v.y, }
}

///|
fn KPoint::scale(self : KPoint, s : Double) -> KPoint {
  { x: s * self.x, y: s * self.y, }
}

///|
fn KPoint::neg(self : KPoint) -> KPoint {
  { x: -self.x, y: -self.y, }
}

///|
fn KPoint::hypot(self : KPoint) -> Double {
  // Avoid f64::hypot as it calls a slow library function.
  self.hypot2().sqrt()
}

///|
/// `Vec2 / f64`: multiplies by the reciprocal.
fn KPoint::div(self : KPoint, s : Double) -> KPoint {
  self.scale(1.0 / s)
}

///|
fn KPoint::normalize(self : KPoint) -> KPoint {
  self.div(self.hypot())
}

///|
fn KPoint::turn_90(self : KPoint) -> KPoint {
  { x: -self.y, y: self.x, }
}

///|
fn KPoint::hypot2(self : KPoint) -> Double {
  self.x * self.x + self.y * self.y
}

///|
fn KPoint::cross(self : KPoint, other : KPoint) -> Double {
  self.x * other.y - self.y * other.x
}

///|
fn KPoint::dot(self : KPoint, other : KPoint) -> Double {
  self.x * other.x + self.y * other.y
}

///|
let k_origin : KPoint = { x: 0.0, y: 0.0, }

///|
/// A path element (`kurbo::PathEl`).
priv enum PathEl {
  MoveTo(KPoint)
  LineTo(KPoint)
  CurveTo(KPoint, KPoint, KPoint)
  ClosePath
}

///|
fn PathEl::end_point(self : PathEl) -> KPoint? {
  match self {
    MoveTo(p) | LineTo(p) | CurveTo(_, _, p) => Some(p)
    ClosePath => None
  }
}

///|
/// A rectangle (`kurbo::Rect`).
priv struct KRect {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// `Rect::from_points`.
fn KRect::from_points(p0 : KPoint, p1 : KPoint) -> KRect {
  {
    x0: f64_min(p0.x, p1.x),
    y0: f64_min(p0.y, p1.y),
    x1: f64_max(p0.x, p1.x),
    y1: f64_max(p0.y, p1.y),
  }
}

///|
/// `Rect::union_pt`.
fn KRect::union_pt(self : KRect, pt : KPoint) -> KRect {
  {
    x0: f64_min(self.x0, pt.x),
    y0: f64_min(self.y0, pt.y),
    x1: f64_max(self.x1, pt.x),
    y1: f64_max(self.y1, pt.y),
  }
}

///|
/// `Rect::union`.
fn KRect::union(self : KRect, other : KRect) -> KRect {
  {
    x0: f64_min(self.x0, other.x0),
    y0: f64_min(self.y0, other.y0),
    x1: f64_max(self.x1, other.x1),
    y1: f64_max(self.y1, other.y1),
  }
}

///|
/// `f64::min` (IEEE `minNum`, as on AArch64: `-0.0` wins over `0.0`).
fn f64_min(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_uint64() > b.reinterpret_as_uint64() {
    // Equal values: prefer the negative zero.
    a
  } else {
    b
  }
}

///|
/// `f64::max` (IEEE `maxNum`, as on AArch64: `0.0` wins over `-0.0`).
fn f64_max(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_uint64() < b.reinterpret_as_uint64() {
    // Equal values: prefer the positive zero.
    a
  } else {
    b
  }
}

///|
/// `f64::is_finite`.
fn f64_is_finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
/// `f64::copysign`.
fn copysign(magnitude : Double, sign : Double) -> Double {
  let m = magnitude.reinterpret_as_uint64() & 0x7FFF_FFFF_FFFF_FFFFUL
  let s = sign.reinterpret_as_uint64() & 0x8000_0000_0000_0000UL
  (m | s).reinterpret_as_double()
}

///|
/// Find real roots of quadratic equation (`kurbo::common::solve_quadratic`).
fn solve_quadratic(c0 : Double, c1 : Double, c2 : Double) -> Array[Double] {
  let result = []
  let sc0 = c0 * (1.0 / c2)
  let sc1 = c1 * (1.0 / c2)
  if !f64_is_finite(sc0) || !f64_is_finite(sc1) {
    // c2 is zero or very small, treat as linear eqn
    let root = -c0 / c1
    if f64_is_finite(root) {
      result.push(root)
    } else if c0 == 0.0 && c1 == 0.0 {
      // Degenerate case
      result.push(0.0)
    }
    return result
  }
  let arg = sc1 * sc1 - 4.0 * sc0
  let root1 = if !f64_is_finite(arg) {
    -sc1
  } else {
    if arg < 0.0 {
      return result
    } else if arg == 0.0 {
      result.push(-0.5 * sc1)
      return result
    }
    -0.5 * (sc1 + copysign(arg.sqrt(), sc1))
  }
  let root2 = sc0 / root1
  if f64_is_finite(root2) {
    if root2 > root1 {
      result.push(root1)
      result.push(root2)
    } else {
      result.push(root2)
      result.push(root1)
    }
  } else {
    result.push(root1)
  }
  result
}

///|
/// The smallest rectangle that encloses the cubic Bézier curve
/// (`CubicBez::bounding_box`).
fn cubic_bounding_box(
  p0 : KPoint,
  p1 : KPoint,
  p2 : KPoint,
  p3 : KPoint,
) -> KRect {
  // `ParamCurveExtrema::extrema`.
  let extrema = []
  let one_coord = (d0 : Double, d1 : Double, d2 : Double) => {
    let a = d0 - 2.0 * d1 + d2
    let b = 2.0 * (d1 - d0)
    let c = d0
    let roots = solve_quadratic(c, b, a)
    for t in roots {
      if t > 0.0 && t < 1.0 {
        extrema.push(t)
      }
    }
  }
  let d0 = p1.sub(p0)
  let d1 = p2.sub(p1)
  let d2 = p3.sub(p2)
  one_coord(d0.x, d1.x, d2.x)
  one_coord(d0.y, d1.y, d2.y)
  extrema.sort_by((a, b) => a.compare(b))
  let eval = (t : Double) => {
    let mt = 1.0 - t
    let coord = (a : Double, b : Double, c : Double, d : Double) => {
      a * (mt * mt * mt) +
      (b * (mt * mt * 3.0) + (c * (mt * 3.0) + d * t) * t) * t
    }
    (
      { x: coord(p0.x, p1.x, p2.x, p3.x), y: coord(p0.y, p1.y, p2.y, p3.y), } :
      KPoint)
  }
  let mut bbox = KRect::from_points(p0, p3)
  for t in extrema {
    bbox = bbox.union_pt(eval(t))
  }
  bbox
}

///|
/// The bounding box of a path (`BezPath::bounding_box`): the union of the
/// bounding boxes of its segments.
fn bez_path_bbox(path : Array[PathEl]) -> KRect {
  let mut bbox : KRect? = None
  let mut start = k_origin
  let mut last = k_origin
  let mut started = false
  let add = (bb : KRect) => {
    bbox = match bbox {
      Some(b) => Some(b.union(bb))
      None => Some(bb)
    }
  }
  for el in path {
    if !started {
      started = true
      match el.end_point() {
        Some(p) => {
          start = p
          last = p
        }
        None => abort("Can't start a segment on a ClosePath")
      }
    }
    match el {
      MoveTo(p) => {
        start = p
        last = p
      }
      LineTo(p) => {
        add(KRect::from_points(last, p))
        last = p
      }
      CurveTo(p1, p2, p3) => {
        add(cubic_bounding_box(last, p1, p2, p3))
        last = p3
      }
      ClosePath =>
        if last != start {
          add(KRect::from_points(last, start))
          last = start
        }
    }
  }
  bbox.unwrap_or({ x0: 0.0, y0: 0.0, x1: 0.0, y1: 0.0, })
}

///|
priv enum KCap {
  KButt
  KRound
  KSquare
}

///|
priv enum KJoin {
  JBevel
  JMiter
  JRound
}

///|
/// A stroke style (`kurbo::Stroke`): width, join, miter limit, caps and an
/// optional dash pattern (offset and lengths).
priv struct KStroke {
  width : Double
  join : KJoin
  miter_limit : Double
  cap : KCap
  dash : (Double, Array[Double])?
}

///|
/// A path being built (`kurbo::BezPath`).
priv struct KPath {
  els : Array[PathEl]
}

///|
fn KPath::new() -> KPath {
  { els: [], }
}

///|
fn KPath::move_to(self : KPath, p : KPoint) -> Unit {
  self.els.push(MoveTo(p))
}

///|
fn KPath::line_to(self : KPath, p : KPoint) -> Unit {
  self.els.push(LineTo(p))
}

///|
fn KPath::curve_to(self : KPath, p1 : KPoint, p2 : KPoint, p3 : KPoint) -> Unit {
  self.els.push(CurveTo(p1, p2, p3))
}

///|
fn KPath::close_path(self : KPath) -> Unit {
  self.els.push(ClosePath)
}

///|
/// The stroke expansion context (`kurbo::StrokeCtx`).
priv struct StrokeCtx {
  output : KPath
  forward_path : KPath
  backward_path : KPath
  mut start_pt : KPoint
  mut start_norm : KPoint
  mut start_tan : KPoint
  mut last_pt : KPoint
  mut last_tan : KPoint
  join_thresh : Double
}

///|
/// The bounding box of the expanded stroke of a path (`kurbo::stroke` with
/// default options and a tolerance of `0.01`, then `bounding_box`).
fn kurbo_stroke_bbox(path : Array[PathEl], style : KStroke) -> KRect {
  let tolerance = 0.01
  // TODO: With a dash pattern, upstream strokes the dashed path
  // (`dash_iter`), which is not ported.
  ignore(style.dash)
  let ctx : StrokeCtx = {
    output: KPath::new(),
    forward_path: KPath::new(),
    backward_path: KPath::new(),
    start_pt: k_origin,
    start_norm: k_origin,
    start_tan: k_origin,
    last_pt: k_origin,
    last_tan: k_origin,
    join_thresh: 2.0 * tolerance / style.width,
  }
  for el in path {
    let p0 = ctx.last_pt
    match el {
      MoveTo(p) => {
        ctx.finish(style)
        ctx.start_pt = p
        ctx.last_pt = p
      }
      LineTo(p1) =>
        if p1 != p0 {
          let tangent = p1.sub(p0)
          ctx.do_join(style, tangent)
          ctx.last_tan = tangent
          ctx.do_line(style, tangent, p1)
        }
      CurveTo(p1, p2, p3) =>
        if p1 != p0 || p2 != p0 || p3 != p0 {
          let (tan0, tan1) = cubic_tangents(p0, p1, p2, p3)
          ctx.do_join(style, tan0)
          ctx.do_cubic(style, p0, p1, p2, p3, tolerance)
          ctx.last_tan = tan1
        }
      ClosePath => {
        if p0 != ctx.start_pt {
          let tangent = ctx.start_pt.sub(p0)
          ctx.do_join(style, tangent)
          ctx.last_tan = tangent
          ctx.do_line(style, tangent, ctx.start_pt)
        }
        ctx.finish_closed(style)
      }
    }
  }
  ctx.finish(style)
  bez_path_bbox(ctx.output.els)
}

///|
/// `PathSeg::Cubic(c).tangents()`.
fn cubic_tangents(
  p0 : KPoint,
  p1 : KPoint,
  p2 : KPoint,
  p3 : KPoint,
) -> (KPoint, KPoint) {
  let eps = 1.0e-12
  let d01 = p1.sub(p0)
  let d0 = if d01.hypot2() > eps {
    d01
  } else {
    let d02 = p2.sub(p0)
    if d02.hypot2() > eps {
      d02
    } else {
      p3.sub(p0)
    }
  }
  let d23 = p3.sub(p2)
  let d1 = if d23.hypot2() > eps {
    d23
  } else {
    let d13 = p3.sub(p1)
    if d13.hypot2() > eps {
      d13
    } else {
      p3.sub(p0)
    }
  }
  (d0, d1)
}

///|
/// Applies the affine map `[a, b, c, d, e, f]` to a point.
fn affine_apply(m : FixedArray[Double], p : KPoint) -> KPoint {
  { x: m[0] * p.x + m[2] * p.y + m[4], y: m[1] * p.x + m[3] * p.y + m[5], }
}

///|
fn round_cap(
  out : KPath,
  tolerance : Double,
  center : KPoint,
  norm : KPoint,
) -> Unit {
  round_join(out, tolerance, center, norm, @math.PI)
}

///|
fn round_join(
  out : KPath,
  tolerance : Double,
  center : KPoint,
  norm : KPoint,
  angle : Double,
) -> Unit {
  let a : FixedArray[Double] = [
    norm.x,
    norm.y,
    -norm.y,
    norm.x,
    center.x,
    center.y,
  ]
  arc_to_cubic_beziers(@math.PI - angle, angle, tolerance, (p1, p2, p3) => {
    out.curve_to(affine_apply(a, p1), affine_apply(a, p2), affine_apply(a, p3))
  })
}

///|
fn round_join_rev(
  out : KPath,
  tolerance : Double,
  center : KPoint,
  norm : KPoint,
  angle : Double,
) -> Unit {
  let a : FixedArray[Double] = [
    norm.x,
    norm.y,
    norm.y,
    -norm.x,
    center.x,
    center.y,
  ]
  arc_to_cubic_beziers(@math.PI - angle, angle, tolerance, (p1, p2, p3) => {
    out.curve_to(affine_apply(a, p1), affine_apply(a, p2), affine_apply(a, p3))
  })
}

///|
/// `Arc::new(Point::ORIGIN, (1.0, 1.0), start_angle, sweep_angle, 0.0)
/// .to_cubic_beziers(tolerance, p)`.
fn arc_to_cubic_beziers(
  start_angle : Double,
  sweep_angle : Double,
  tolerance : Double,
  p : (KPoint, KPoint, KPoint) -> Unit,
) -> Unit {
  let sign = if sweep_angle.is_nan() {
    sweep_angle
  } else if sweep_angle.reinterpret_as_uint64() >> 63 != 0 {
    -1.0
  } else {
    1.0
  }
  let scaled_err = 1.0 / tolerance
  // Number of subdivisions per ellipse based on error tolerance.
  let n_err = f64_max(libm_pow(1.1163 * scaled_err, 1.0 / 6.0), 3.999_999)
  let n = (n_err * sweep_angle.abs() * (1.0 / (2.0 * @math.PI))).ceil()
  let angle_step = sweep_angle / n
  let n = n.to_int()
  let arm_len = 4.0 / 3.0 * libm_tan((0.25 * angle_step).abs()) * sign
  let mut angle0 = start_angle
  let mut p0 = sample_unit_circle(angle0)
  for _ in 0..<n {
    let angle1 = angle0 + angle_step
    let p1 = p0.add(sample_unit_circle(angle0 + @math.PI / 2.0).scale(arm_len))
    let p3 = sample_unit_circle(angle1)
    let p2 = p3.sub(sample_unit_circle(angle1 + @math.PI / 2.0).scale(arm_len))
    angle0 = angle1
    p0 = p3
    // The arc is centered at the origin (`self.center + p`).
    p(k_origin.add(p1), k_origin.add(p2), k_origin.add(p3))
  }
}

///|
/// `sample_ellipse` with unit radii and no rotation.
fn sample_unit_circle(angle : Double) -> KPoint {
  let u = 1.0 * @math.cos(angle)
  let v = 1.0 * @math.sin(angle)
  // `rotate_pt` by zero.
  { x: u * 1.0 - v * 0.0, y: u * 0.0 + v * 1.0, }
}

///|
fn square_cap(
  out : KPath,
  close : Bool,
  center : KPoint,
  norm : KPoint,
) -> Unit {
  let a : FixedArray[Double] = [
    norm.x,
    norm.y,
    -norm.y,
    norm.x,
    center.x,
    center.y,
  ]
  out.line_to(affine_apply(a, { x: 1.0, y: 1.0, }))
  out.line_to(affine_apply(a, { x: -1.0, y: 1.0, }))
  if close {
    out.close_path()
  } else {
    out.line_to(affine_apply(a, { x: -1.0, y: 0.0, }))
  }
}

///|
fn extend_reversed(out : KPath, elements : Array[PathEl]) -> Unit {
  for i = elements.length() - 1; i >= 1; i = i - 1 {
    let end = elements[i - 1].end_point().unwrap()
    match elements[i] {
      LineTo(_) => out.line_to(end)
      CurveTo(p1, p2, _) => out.curve_to(p2, p1, end)
      _ => abort("unreachable")
    }
  }
}

///|
/// Append forward and backward paths to output.
fn StrokeCtx::finish(self : StrokeCtx, style : KStroke) -> Unit {
  let tolerance = 1.0e-3
  if self.forward_path.els.is_empty() {
    return
  }
  self.output.els.append(self.forward_path.els)
  let back_els = self.backward_path.els
  let return_p = back_els[back_els.length() - 1].end_point().unwrap()
  let d = self.last_pt.sub(return_p)
  match style.cap {
    KButt => self.output.line_to(return_p)
    KRound => round_cap(self.output, tolerance, self.last_pt, d)
    KSquare => square_cap(self.output, false, self.last_pt, d)
  }
  extend_reversed(self.output, back_els)
  match style.cap {
    KButt => self.output.close_path()
    KRound => round_cap(self.output, tolerance, self.start_pt, self.start_norm)
    KSquare => square_cap(self.output, true, self.start_pt, self.start_norm)
  }
  self.forward_path.els.clear()
  self.backward_path.els.clear()
}

///|
/// Finish a closed path
fn StrokeCtx::finish_closed(self : StrokeCtx, style : KStroke) -> Unit {
  if self.forward_path.els.is_empty() {
    return
  }
  self.do_join(style, self.start_tan)
  self.output.els.append(self.forward_path.els)
  self.output.close_path()
  let back_els = self.backward_path.els
  let last_pt = back_els[back_els.length() - 1].end_point().unwrap()
  self.output.move_to(last_pt)
  extend_reversed(self.output, back_els)
  self.output.close_path()
  self.forward_path.els.clear()
  self.backward_path.els.clear()
}

///|
fn StrokeCtx::do_join(self : StrokeCtx, style : KStroke, tan0 : KPoint) -> Unit {
  let tolerance = 1.0e-3
  let scale = 0.5 * style.width / tan0.hypot()
  let norm = ({ x: -tan0.y, y: tan0.x, } : KPoint).scale(scale)
  let p0 = self.last_pt
  if self.forward_path.els.is_empty() {
    self.forward_path.move_to(p0.sub(norm))
    self.backward_path.move_to(p0.add(norm))
    self.start_tan = tan0
    self.start_norm = norm
  } else {
    let ab = self.last_tan
    let cd = tan0
    let cross = ab.cross(cd)
    let dot = ab.dot(cd)
    let hypot = libm_hypot(cross, dot)
    if dot <= 0.0 || cross.abs() >= hypot * self.join_thresh {
      match style.join {
        JBevel => {
          self.forward_path.line_to(p0.sub(norm))
          self.backward_path.line_to(p0.add(norm))
        }
        JMiter => {
          if 2.0 * hypot < (hypot + dot) * style.miter_limit * style.miter_limit {
            let last_scale = 0.5 * style.width / ab.hypot()
            let last_norm = ({ x: -ab.y, y: ab.x, } : KPoint).scale(last_scale)
            if cross > 0.0 {
              let fp_last = p0.sub(last_norm)
              let fp_this = p0.sub(norm)
              let h = ab.cross(fp_this.sub(fp_last)) / cross
              let miter_pt = fp_this.sub(cd.scale(h))
              self.forward_path.line_to(miter_pt)
              self.backward_path.line_to(p0)
            } else if cross < 0.0 {
              let fp_last = p0.add(last_norm)
              let fp_this = p0.add(norm)
              let h = ab.cross(fp_this.sub(fp_last)) / cross
              let miter_pt = fp_this.sub(cd.scale(h))
              self.backward_path.line_to(miter_pt)
              self.forward_path.line_to(p0)
            }
          }
          self.forward_path.line_to(p0.sub(norm))
          self.backward_path.line_to(p0.add(norm))
        }
        JRound => {
          let angle = libm_atan2(cross, dot)
          if angle > 0.0 {
            self.backward_path.line_to(p0.add(norm))
            round_join(self.forward_path, tolerance, p0, norm, angle)
          } else {
            self.forward_path.line_to(p0.sub(norm))
            round_join_rev(
              self.backward_path,
              tolerance,
              p0,
              norm.neg(),
              -angle,
            )
          }
        }
      }
    }
  }
}

///|
fn StrokeCtx::do_line(
  self : StrokeCtx,
  style : KStroke,
  tangent : KPoint,
  p1 : KPoint,
) -> Unit {
  let scale = 0.5 * style.width / tangent.hypot()
  let norm = ({ x: -tangent.y, y: tangent.x, } : KPoint).scale(scale)
  self.forward_path.line_to(p1.sub(norm))
  self.backward_path.line_to(p1.add(norm))
  self.last_pt = p1
}

///|
fn StrokeCtx::do_cubic(
  self : StrokeCtx,
  style : KStroke,
  c0 : KPoint,
  c1 : KPoint,
  c2 : KPoint,
  c3 : KPoint,
  tolerance : Double,
) -> Unit {
  // First, detect degenerate linear case

  // Ordinarily, this is the direction of the chord, but if the chord is very
  // short, we take the longer control arm.
  let chord = c3.sub(c0)
  let mut chord_ref = chord
  let mut chord_ref_hypot2 = chord_ref.hypot2()
  let d01 = c1.sub(c0)
  if d01.hypot2() > chord_ref_hypot2 {
    chord_ref = d01
    chord_ref_hypot2 = chord_ref.hypot2()
  }
  let d23 = c3.sub(c2)
  if d23.hypot2() > chord_ref_hypot2 {
    chord_ref = d23
    chord_ref_hypot2 = chord_ref.hypot2()
  }
  // Project Bézier onto chord
  let p0 = c0.dot(chord_ref)
  let p1 = c1.dot(chord_ref)
  let p2 = c2.dot(chord_ref)
  let p3 = c3.dot(chord_ref)
  let endpoint_d = 0.01
  if p3 <= p0 ||
    p1 > p2 ||
    p1 < p0 + endpoint_d * (p3 - p0) ||
    p2 > p3 - endpoint_d * (p3 - p0) {
    // potentially a cusp inside
    let x01 = d01.cross(chord_ref)
    let x23 = d23.cross(chord_ref)
    let x03 = chord.cross(chord_ref)
    let thresh = tolerance * tolerance * chord_ref_hypot2
    if x01 * x01 < thresh && x23 * x23 < thresh && x03 * x03 < thresh {
      // control points are nearly co-linear
      let midpoint : KPoint = {
        x: 0.5 * (c0.x + c3.x),
        y: 0.5 * (c0.y + c3.y),
      }
      // Mapping back from projection of reference chord
      let ref_vec = chord_ref.div(chord_ref_hypot2)
      let ref_pt = midpoint.sub(ref_vec.scale(0.5 * (p0 + p3)))
      self.do_linear(style, c0, c1, c2, c3, [p0, p1, p2, p3], ref_pt, ref_vec)
      return
    }
  }

  let c : CubicBez = { p0: c0, p1: c1, p2: c2, p3: c3, }
  let result = offset_cubic(c, -0.5 * style.width, tolerance)
  for i in 1..<result.length() {
    self.forward_path.els.push(result[i])
  }
  let result = offset_cubic(c, 0.5 * style.width, tolerance)
  for i in 1..<result.length() {
    self.backward_path.els.push(result[i])
  }
  self.last_pt = c3
}

///|
/// Do a cubic which is actually linear.
///
/// The `p` argument is the control points projected to the reference chord.
/// The ref arguments are the inverse map of a projection back to the client
/// coordinate space.
fn StrokeCtx::do_linear(
  self : StrokeCtx,
  style : KStroke,
  c0 : KPoint,
  c1 : KPoint,
  c2 : KPoint,
  c3 : KPoint,
  p : FixedArray[Double],
  ref_pt : KPoint,
  ref_vec : KPoint,
) -> Unit {
  // Always do round join, to model cusp as limit of finite curvature (see
  // Nehab).
  let style : KStroke = {
    width: style.width,
    join: JRound,
    miter_limit: 4.0,
    cap: KButt,
    dash: None,
  }
  // Tangents of endpoints (for connecting to joins)
  let (tan0, tan1) = cubic_tangents(c0, c1, c2, c3)
  self.last_tan = tan0
  // find cusps
  let k0 = p[1] - p[0]
  let k1 = 2.0 * p[2] - 4.0 * p[1] + 2.0 * p[0]
  let k2 = p[3] - 3.0 * p[2] + 3.0 * p[1] - p[0]
  let roots = solve_quadratic(k0, k1, k2)
  // discard cusps right at endpoints
  let epsilon = 1.0e-6
  for t in roots {
    if t > epsilon && t < 1.0 - epsilon {
      let mt = 1.0 - t
      let z = mt * (mt * mt * p[0] + 3.0 * t * (mt * p[1] + t * p[2])) +
        t * t * t * p[3]
      let pt = ref_pt.add(ref_vec.scale(z))
      let tan = pt.sub(self.last_pt)
      self.do_join(style, tan)
      self.do_line(style, tan, pt)
      self.last_tan = tan
    }
  }
  let tan = c3.sub(self.last_pt)
  self.do_join(style, tan)
  self.do_line(style, tan, c3)
  self.last_tan = tan
  self.do_join(style, tan1)
}
