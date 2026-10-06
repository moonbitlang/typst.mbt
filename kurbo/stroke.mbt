// Port of `kurbo` 0.13 `stroke.rs`: stroke expansion and dashing. (The
// `Join` and `Cap` enums live in `common.mbt`.)

///|
/// The visual style of a stroke.
pub(all) struct Stroke {
  /// Width of the stroke.
  width : Double
  /// Style for connecting segments of the stroke.
  join : Join
  /// Limit for miter joins.
  miter_limit : Double
  /// Style for capping the beginning of an open subpath.
  start_cap : Cap
  /// Style for capping the end of an open subpath.
  end_cap : Cap
  /// Lengths of dashes in alternating on/off order.
  dash_pattern : Array[Double]
  /// Offset of the first dash.
  dash_offset : Double
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stroke with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stroke with @debug.Debug::{to_repr}

///|
/// Options for path stroking.
pub struct StrokeOpts {
  priv opt_level : StrokeOptLevel
  /// When `true`, dashes are emitted in the order they appear along the
  /// path. The default `false` delays a subpath's first dash so it can be
  /// merged with a dash that wraps through `ClosePath`; this option disables
  /// both the reorder and the wraparound merge, so a dash spanning the seam
  /// is truncated there.
  priv stable_dash_order : Bool
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StrokeOpts with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StrokeOpts with @debug.Debug::{to_repr}

///|
/// Optimization level for computing stroke outlines.
///
/// Note that in the current implementation, this setting has no effect.
/// However, having a tradeoff between optimization of number of segments
/// and speed makes sense and may be added in the future, so applications
/// should set it appropriately. For real time rendering, the appropriate
/// value is `Subdivide`.
pub(all) enum StrokeOptLevel {
  /// Adaptively subdivide segments in half.
  Subdivide
  /// Compute optimized subdivision points to minimize error.
  Optimized
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StrokeOptLevel with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StrokeOptLevel with @debug.Debug::{to_repr}

///|
pub impl Default for StrokeOpts with fn default() {
  let opt_level = StrokeOptLevel::Subdivide
  { opt_level, stable_dash_order: false, }
}

///|
pub extend StrokeOpts with Default::{default}

///|
pub impl Default for Stroke with fn default() {
  Stroke::new(1.0)
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Stroke with Default::{default}

///|
/// Creates a new stroke with the specified width.
pub fn Stroke::new(width : Double) -> Stroke {
  {
    width,
    join: Join::Round,
    miter_limit: 4.0,
    start_cap: Cap::Round,
    end_cap: Cap::Round,
    dash_pattern: [],
    dash_offset: 0.0,
  }
}

///|
/// Builder method for setting the join style.
pub fn Stroke::with_join(self : Stroke, join : Join) -> Stroke {
  { ..self, join, }
}

///|
/// Builder method for setting the limit for miter joins.
pub fn Stroke::with_miter_limit(self : Stroke, limit : Double) -> Stroke {
  { ..self, miter_limit: limit, }
}

///|
/// Builder method for setting the cap style for the start of the stroke.
pub fn Stroke::with_start_cap(self : Stroke, cap : Cap) -> Stroke {
  { ..self, start_cap: cap, }
}

///|
/// Builder method for setting the cap style for the end of the stroke.
pub fn Stroke::with_end_cap(self : Stroke, cap : Cap) -> Stroke {
  { ..self, end_cap: cap, }
}

///|
/// Builder method for setting the cap style.
pub fn Stroke::with_caps(self : Stroke, cap : Cap) -> Stroke {
  { ..self, start_cap: cap, end_cap: cap, }
}

///|
/// Builder method for setting the dashing parameters.
pub fn Stroke::with_dashes(
  self : Stroke,
  offset : Double,
  pattern : Array[Double],
) -> Stroke {
  { ..self, dash_offset: offset, dash_pattern: pattern.copy(), }
}

///|
/// Returns `true` if all floating-point stroke parameters are finite.
pub fn Stroke::is_finite(self : Stroke) -> Bool {
  is_finite(self.width) &&
  is_finite(self.miter_limit) &&
  is_finite(self.dash_offset) &&
  self.dash_pattern.iter().all(dash => is_finite(dash))
}

///|
/// Returns `true` if any floating-point stroke parameter is `NaN`.
pub fn Stroke::is_nan(self : Stroke) -> Bool {
  self.width.is_nan() ||
  self.miter_limit.is_nan() ||
  self.dash_offset.is_nan() ||
  self.dash_pattern.iter().any(dash => dash.is_nan())
}

///|
/// Set optimization level for computing stroke outlines.
pub fn StrokeOpts::opt_level(
  self : StrokeOpts,
  opt_level : StrokeOptLevel,
) -> StrokeOpts {
  { ..self, opt_level, }
}

///|
/// When `true`, dashes are emitted in the order they appear along the path.
pub fn StrokeOpts::stable_dash_order(
  self : StrokeOpts,
  stable : Bool,
) -> StrokeOpts {
  { ..self, stable_dash_order: stable, }
}

///|
/// A structure that is used for creating strokes.
///
/// See also [`stroke_with`].
pub struct StrokeCtx {
  // As a possible future optimization, we might not need separate storage
  // for forward and backward paths, we can add forward to the output
  // in-place. However, this structure is clearer and the cost fairly modest.
  priv output : BezPath
  priv forward_path : BezPath
  priv backward_path : BezPath
  priv result_path : BezPath
  priv mut start_pt : Point
  priv mut start_norm : Vec2
  priv mut start_tan : Vec2
  priv mut last_pt : Point
  priv mut last_tan : Vec2
  // Precomputation of the join threshold, to optimize per-join logic.
  // If hypot < (hypot + dot) * join_thresh, omit join altogether.
  priv mut join_thresh : Double
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StrokeCtx with @debug.Debug::{to_repr}

///|
/// Create a new (empty) stroke context.
pub fn StrokeCtx::new() -> StrokeCtx {
  {
    output: BezPath::new(),
    forward_path: BezPath::new(),
    backward_path: BezPath::new(),
    result_path: BezPath::new(),
    start_pt: point_zero,
    start_norm: vec2_zero,
    start_tan: vec2_zero,
    last_pt: point_zero,
    last_tan: vec2_zero,
    join_thresh: 0.0,
  }
}

///|
pub impl Default for StrokeCtx with fn default() {
  StrokeCtx::new()
}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StrokeCtx with Default::{default}

///|
/// Return the path that defines the expanded stroke.
pub fn StrokeCtx::output(self : StrokeCtx) -> BezPath {
  self.output
}

///|
fn StrokeCtx::reset(self : StrokeCtx) -> Unit {
  self.output.truncate(0)
  self.forward_path.truncate(0)
  self.backward_path.truncate(0)
  self.start_pt = point_zero
  self.start_norm = vec2_zero
  self.start_tan = vec2_zero
  self.last_pt = point_zero
  self.last_tan = vec2_zero
  self.join_thresh = 0.0
}

///|
/// Expand a stroke into a fill.
///
/// The `tolerance` parameter controls the accuracy of the result. In
/// general, the number of subdivisions in the output scales at least to the
/// -1/4 power of the parameter, for example making it 1/16 as big generates
/// twice as many segments. Currently the algorithm is not tuned for
/// extremely fine tolerances. The theoretically optimum scaling exponent is
/// -1/6, but achieving this may require slow numerical techniques
/// (currently a subject of research). The appropriate value depends on the
/// application; if the result of the stroke will be scaled up, a smaller
/// value is needed.
///
/// This method attempts a fairly high degree of correctness, but ultimately
/// is based on computing parallel curves and adding joins and caps, rather
/// than computing the rigorously correct parallel sweep (which requires
/// evolutes in the general case). See [Nehab 2020] for more discussion.
///
/// [Nehab 2020]: https://dl.acm.org/doi/10.1145/3386569.3392392
pub fn stroke(
  path : Iter[PathEl],
  style : Stroke,
  opts : StrokeOpts,
  tolerance : Double,
) -> BezPath {
  let ctx = StrokeCtx::new()
  stroke_with(path, style, opts, tolerance, ctx)
  ctx.output
}

///|
/// Expand a stroke into a fill.
///
/// This is the same as [`stroke`], except for the fact that you can
/// explicitly pass a `StrokeCtx`. By doing so, you can reuse the same
/// context over multiple calls and ensure that the number of reallocations
/// is minimized.
///
/// Unlike [`stroke`], this method doesn't return an owned version of the
/// expanded stroke as a [`BezPath`]. Instead, you can get a reference to the
/// resulting path by calling [`StrokeCtx::output`].
pub fn stroke_with(
  path : Iter[PathEl],
  style : Stroke,
  opts : StrokeOpts,
  tolerance : Double,
  ctx : StrokeCtx,
) -> Unit {
  if style.dash_pattern.is_empty() {
    stroke_undashed(path, style, tolerance, ctx)
  } else {
    let dashed = dash_iter(
      path,
      style.dash_offset,
      style.dash_pattern,
      opts.stable_dash_order,
    )
    stroke_undashed(Iter::new(() => dashed.next()), style, tolerance, ctx)
  }
}

///|
/// Version of stroke expansion for styles with no dashes.
fn stroke_undashed(
  path : Iter[PathEl],
  style : Stroke,
  tolerance : Double,
  ctx : StrokeCtx,
) -> Unit {
  ctx.reset()
  ctx.join_thresh = 2.0 * tolerance / style.width
  while path.next() is Some(el) {
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
      QuadTo(p1, p2) =>
        if p1 != p0 || p2 != p0 {
          let q = QuadBez::new(p0, p1, p2)
          let (tan0, tan1) = PathSeg::Quad(q).tangents()
          ctx.do_join(style, tan0)
          ctx.do_cubic(style, q.raise_order(), tolerance)
          ctx.last_tan = tan1
        }
      CurveTo(p1, p2, p3) =>
        if p1 != p0 || p2 != p0 || p3 != p0 {
          let c = CubicBez::new(p0, p1, p2, p3)
          let (tan0, tan1) = PathSeg::Cubic(c).tangents()
          ctx.do_join(style, tan0)
          ctx.do_cubic(style, c, tolerance)
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
}

///|
fn round_cap(
  out : BezPath,
  tolerance : Double,
  center : Point,
  norm : Vec2,
) -> Unit {
  round_join(out, tolerance, center, norm, PI)
}

///|
fn round_join(
  out : BezPath,
  tolerance : Double,
  center : Point,
  norm : Vec2,
  angle : Double,
) -> Unit {
  let a = Affine::new([norm.x, norm.y, -norm.y, norm.x, center.x, center.y])
  let arc = Arc::new(point_zero, Vec2::new(1.0, 1.0), PI - angle, angle, 0.0)
  arc.to_cubic_beziers(tolerance, (p1, p2, p3) => {
    out.curve_to(a.apply(p1), a.apply(p2), a.apply(p3))
  })
}

///|
fn round_join_rev(
  out : BezPath,
  tolerance : Double,
  center : Point,
  norm : Vec2,
  angle : Double,
) -> Unit {
  let a = Affine::new([norm.x, norm.y, norm.y, -norm.x, center.x, center.y])
  let arc = Arc::new(point_zero, Vec2::new(1.0, 1.0), PI - angle, angle, 0.0)
  arc.to_cubic_beziers(tolerance, (p1, p2, p3) => {
    out.curve_to(a.apply(p1), a.apply(p2), a.apply(p3))
  })
}

///|
fn square_cap(out : BezPath, close : Bool, center : Point, norm : Vec2) -> Unit {
  let a = Affine::new([norm.x, norm.y, -norm.y, norm.x, center.x, center.y])
  out.line_to(a.apply(Point::new(1.0, 1.0)))
  out.line_to(a.apply(Point::new(-1.0, 1.0)))
  if close {
    out.close_path()
  } else {
    out.line_to(a.apply(Point::new(-1.0, 0.0)))
  }
}

///|
fn extend_reversed(out : BezPath, elements : Array[PathEl]) -> Unit {
  for i = elements.length() - 1; i >= 1; i = i - 1 {
    let end = elements[i - 1].end_point().unwrap()
    match elements[i] {
      LineTo(_) => out.line_to(end)
      QuadTo(p1, _) => out.quad_to(p1, end)
      CurveTo(p1, p2, _) => out.curve_to(p2, p1, end)
      _ => abort("unreachable")
    }
  }
}

///|
/// Append forward and backward paths to output.
fn StrokeCtx::finish(self : StrokeCtx, style : Stroke) -> Unit {
  // TODO: scale
  let tolerance = 1.0e-3
  if self.forward_path.is_empty() {
    return
  }
  self.output.extend_path(self.forward_path)
  let back_els = self.backward_path.elements
  let return_p = back_els[back_els.length() - 1].end_point().unwrap()
  let d = self.last_pt.sub(return_p)
  match style.end_cap {
    Butt => self.output.line_to(return_p)
    Round => round_cap(self.output, tolerance, self.last_pt, d)
    Square => square_cap(self.output, false, self.last_pt, d)
  }
  extend_reversed(self.output, back_els)
  match style.start_cap {
    Butt => self.output.close_path()
    Round => round_cap(self.output, tolerance, self.start_pt, self.start_norm)
    Square => square_cap(self.output, true, self.start_pt, self.start_norm)
  }
  self.forward_path.truncate(0)
  self.backward_path.truncate(0)
}

///|
/// Finish a closed path
fn StrokeCtx::finish_closed(self : StrokeCtx, style : Stroke) -> Unit {
  if self.forward_path.is_empty() {
    return
  }
  self.do_join(style, self.start_tan)
  self.output.extend_path(self.forward_path)
  self.output.close_path()
  let back_els = self.backward_path.elements
  let last_pt = back_els[back_els.length() - 1].end_point().unwrap()
  self.output.move_to(last_pt)
  extend_reversed(self.output, back_els)
  self.output.close_path()
  self.forward_path.truncate(0)
  self.backward_path.truncate(0)
}

///|
fn StrokeCtx::do_join(self : StrokeCtx, style : Stroke, tan0 : Vec2) -> Unit {
  // TODO: scale
  let tolerance = 1.0e-3
  let scale = 0.5 * style.width / tan0.hypot()
  let norm = Vec2::new(-tan0.y, tan0.x).scale(scale)
  let p0 = self.last_pt
  if self.forward_path.elements.is_empty() {
    self.forward_path.move_to(p0.sub_vec(norm))
    self.backward_path.move_to(p0.add_vec(norm))
    self.start_tan = tan0
    self.start_norm = norm
  } else {
    let ab = self.last_tan
    let cd = tan0
    let cross = ab.cross(cd)
    let dot = ab.dot(cd)
    let hypot = libm_hypot(cross, dot)
    // possible TODO: a minor speedup could be squaring both sides
    if dot <= 0.0 || fabs(cross) >= hypot * self.join_thresh {
      match style.join {
        Bevel => {
          self.forward_path.line_to(p0.sub_vec(norm))
          self.backward_path.line_to(p0.add_vec(norm))
        }
        Miter => {
          if 2.0 * hypot < (hypot + dot) * powi(style.miter_limit, 2) {
            // TODO: maybe better to store last_norm or derive from path?
            let last_scale = 0.5 * style.width / ab.hypot()
            let last_norm = Vec2::new(-ab.y, ab.x).scale(last_scale)
            if cross > 0.0 {
              let fp_last = p0.sub_vec(last_norm)
              let fp_this = p0.sub_vec(norm)
              let h = ab.cross(fp_this.sub(fp_last)) / cross
              let miter_pt = fp_this.sub_vec(cd.scale(h))
              self.forward_path.line_to(miter_pt)
              self.backward_path.line_to(p0)
            } else if cross < 0.0 {
              let fp_last = p0.add_vec(last_norm)
              let fp_this = p0.add_vec(norm)
              let h = ab.cross(fp_this.sub(fp_last)) / cross
              let miter_pt = fp_this.sub_vec(cd.scale(h))
              self.backward_path.line_to(miter_pt)
              self.forward_path.line_to(p0)
            }
          }
          self.forward_path.line_to(p0.sub_vec(norm))
          self.backward_path.line_to(p0.add_vec(norm))
        }
        Round => {
          let angle = libm_atan2(cross, dot)
          if angle > 0.0 {
            self.backward_path.line_to(p0.add_vec(norm))
            round_join(self.forward_path, tolerance, p0, norm, angle)
          } else {
            self.forward_path.line_to(p0.sub_vec(norm))
            round_join_rev(self.backward_path, tolerance, p0, -norm, -angle)
          }
        }
      }
    }
  }
}

///|
fn StrokeCtx::do_line(
  self : StrokeCtx,
  style : Stroke,
  tangent : Vec2,
  p1 : Point,
) -> Unit {
  let scale = 0.5 * style.width / tangent.hypot()
  let norm = Vec2::new(-tangent.y, tangent.x).scale(scale)
  self.forward_path.line_to(p1.sub_vec(norm))
  self.backward_path.line_to(p1.add_vec(norm))
  self.last_pt = p1
}

///|
fn StrokeCtx::do_cubic(
  self : StrokeCtx,
  style : Stroke,
  c : CubicBez,
  tolerance : Double,
) -> Unit {
  // First, detect degenerate linear case

  // Ordinarily, this is the direction of the chord, but if the chord is very
  // short, we take the longer control arm.
  let chord = c.p3.sub(c.p0)
  let mut chord_ref = chord
  let mut chord_ref_hypot2 = chord_ref.hypot2()
  let d01 = c.p1.sub(c.p0)
  if d01.hypot2() > chord_ref_hypot2 {
    chord_ref = d01
    chord_ref_hypot2 = chord_ref.hypot2()
  }
  let d23 = c.p3.sub(c.p2)
  if d23.hypot2() > chord_ref_hypot2 {
    chord_ref = d23
    chord_ref_hypot2 = chord_ref.hypot2()
  }
  // Project Bézier onto chord
  let p0 = c.p0.to_vec2().dot(chord_ref)
  let p1 = c.p1.to_vec2().dot(chord_ref)
  let p2 = c.p2.to_vec2().dot(chord_ref)
  let p3 = c.p3.to_vec2().dot(chord_ref)
  let endpoint_d = 0.01
  if p3 <= p0 ||
    p1 > p2 ||
    p1 < p0 + endpoint_d * (p3 - p0) ||
    p2 > p3 - endpoint_d * (p3 - p0) {
    // potentially a cusp inside
    let x01 = d01.cross(chord_ref)
    let x23 = d23.cross(chord_ref)
    let x03 = chord.cross(chord_ref)
    let thresh = powi(tolerance, 2) * chord_ref_hypot2
    if x01 * x01 < thresh && x23 * x23 < thresh && x03 * x03 < thresh {
      // control points are nearly co-linear
      let midpoint = c.p0.midpoint(c.p3)
      // Mapping back from projection of reference chord
      let ref_vec = chord_ref.div_f64(chord_ref_hypot2)
      let ref_pt = midpoint.sub_vec(ref_vec.scale(0.5 * (p0 + p3)))
      self.do_linear(style, c, [p0, p1, p2, p3], ref_pt, ref_vec)
      return
    }
  }
  offset_cubic(c, -0.5 * style.width, tolerance, self.result_path)
  for i in 1..<self.result_path.elements.length() {
    self.forward_path.push(self.result_path.elements[i])
  }
  offset_cubic(c, 0.5 * style.width, tolerance, self.result_path)
  for i in 1..<self.result_path.elements.length() {
    self.backward_path.push(self.result_path.elements[i])
  }
  self.last_pt = c.p3
}

///|
/// Do a cubic which is actually linear.
///
/// The `p` argument is the control points projected to the reference chord.
/// The ref arguments are the inverse map of a projection back to the client
/// coordinate space.
fn StrokeCtx::do_linear(
  self : StrokeCtx,
  style : Stroke,
  c : CubicBez,
  p : FixedArray[Double],
  ref_pt : Point,
  ref_vec : Vec2,
) -> Unit {
  // Always do round join, to model cusp as limit of finite curvature (see
  // Nehab).
  let style = Stroke::new(style.width).with_join(Join::Round)
  // Tangents of endpoints (for connecting to joins)
  let (tan0, tan1) = PathSeg::Cubic(c).tangents()
  self.last_tan = tan0
  // find cusps
  let c0 = p[1] - p[0]
  let c1 = 2.0 * p[2] - 4.0 * p[1] + 2.0 * p[0]
  let c2 = p[3] - 3.0 * p[2] + 3.0 * p[1] - p[0]
  let roots = solve_quadratic(c0, c1, c2)
  // discard cusps right at endpoints
  let epsilon = 1.0e-6
  for t in roots {
    if t > epsilon && t < 1.0 - epsilon {
      let mt = 1.0 - t
      let z = mt * (mt * mt * p[0] + 3.0 * t * (mt * p[1] + t * p[2])) +
        t * t * t * p[3]
      let p = ref_pt.add_vec(ref_vec.scale(z))
      let tan = p.sub(self.last_pt)
      self.do_join(style, tan)
      self.do_line(style, tan, p)
      self.last_tan = tan
    }
  }
  let tan = c.p3.sub(self.last_pt)
  self.do_join(style, tan)
  self.do_line(style, tan, c.p3)
  self.last_tan = tan
  self.do_join(style, tan1)
}

///|
/// An implementation of dashing as an iterator-to-iterator transformation.
priv struct DashIterator {
  inner : Iter[PathEl]
  mut input_done : Bool
  mut closepath_pending : Bool
  dashes : Array[Double]
  mut dash_ix : Int
  init_dash_ix : Int
  init_dash_remaining : Double
  init_is_active : Bool
  mut is_active : Bool
  mut state : DashState
  mut current_seg : PathSeg
  mut t : Double
  mut dash_remaining : Double
  mut seg_remaining : Double
  mut start_pt : Point
  mut last_pt : Point
  stash : Array[PathEl]
  mut stash_ix : Int
  stable_dash_order : Bool
  mut needs_moveto : Bool
}

///|
priv enum DashState {
  NeedInput
  ToStash
  Working
  FromStash
} derive(Eq)

///|
fn DashIterator::next(self : DashIterator) -> PathEl? {
  while true {
    match self.state {
      NeedInput => {
        if self.input_done {
          return None
        }
        self.get_input()
        if self.input_done {
          return None
        }
        self.state = ToStash
      }
      ToStash =>
        if self.step() is Some(el) {
          if self.stable_dash_order {
            return Some(el)
          }
          self.stash.push(el)
        }
      Working => if self.step() is Some(el) { return Some(el) }
      FromStash =>
        if self.stash_ix < self.stash.length() {
          let el = self.stash[self.stash_ix]
          self.stash_ix += 1
          return Some(el)
        } else {
          self.stash.clear()
          self.stash_ix = 0
          if self.input_done {
            return None
          }
          if self.closepath_pending {
            self.closepath_pending = false
            self.state = NeedInput
          } else {
            self.state = ToStash
          }
        }
    }
  }
  None
}

///|
fn seg_to_el(el : PathSeg) -> PathEl {
  match el {
    Line(l) => LineTo(l.p1)
    Quad(q) => QuadTo(q.p1, q.p2)
    Cubic(c) => CurveTo(c.p1, c.p2, c.p3)
  }
}

///|
const DASH_ACCURACY : Double = 1.0e-6

///|
/// Create a new dashing iterator.
///
/// Handling of dashes is fairly orthogonal to stroke expansion. This
/// iterator is an internal detail of the stroke expansion logic, but is also
/// available separately, and is expected to be useful when doing stroke
/// expansion on GPU.
///
/// It is implemented as an iterator-to-iterator transform. Because it
/// consumes the input sequentially and produces consistent output with
/// correct joins, it requires internal state and may allocate.
///
/// Accuracy is currently hard-coded to 1e-6. This is better than generally
/// expected, and care is taken to get cusps correct, among other things.
///
/// Like upstream, `dashes` must not be empty (aborts otherwise).
pub fn dash(
  inner : Iter[PathEl],
  dash_offset : Double,
  dashes : Array[Double],
) -> Iter[PathEl] {
  let it = dash_iter(inner, dash_offset, dashes, false)
  Iter::new(() => it.next())
}

///|
fn dash_iter(
  inner : Iter[PathEl],
  dash_offset : Double,
  dashes : Array[Double],
  stable_dash_order : Bool,
) -> DashIterator {
  // Ensure that offset is positive and minimal by normalization using period
  let mut period = neg_zero
  for d in dashes {
    period = period + d
  }
  // The SVG spec requires odd-length dash arrays to be doubled to become
  // even-length:
  // <https://www.w3.org/TR/SVG2/painting.html#StrokeDasharrayProperty>
  // This prevents gaps and dashes from swapping with one another as the
  // offset increases.
  let period = if dashes.length() % 2 == 1 { 2.0 * period } else { period }
  let dash_offset = rem_euclid(dash_offset, period)
  let mut dash_ix = 0
  let mut dash_remaining = dashes[dash_ix] - dash_offset
  let mut is_active = true
  // Find place in dashes array for initial offset.
  while dash_remaining < 0.0 {
    dash_ix = (dash_ix + 1) % dashes.length()
    dash_remaining += dashes[dash_ix]
    is_active = !is_active
  }
  {
    inner,
    input_done: false,
    closepath_pending: false,
    dashes,
    dash_ix,
    init_dash_ix: dash_ix,
    init_dash_remaining: dash_remaining,
    init_is_active: is_active,
    is_active,
    state: NeedInput,
    current_seg: Line(Line::new(point_zero, point_zero)),
    t: 0.0,
    dash_remaining,
    seg_remaining: 0.0,
    start_pt: point_zero,
    last_pt: point_zero,
    stash: [],
    stash_ix: 0,
    stable_dash_order,
    needs_moveto: true,
  }
}

///|
fn DashIterator::get_input(self : DashIterator) -> Unit {
  while true {
    if self.closepath_pending {
      self.handle_closepath()
      break
    }
    guard self.inner.next() is Some(next_el) else {
      self.input_done = true
      self.state = FromStash
      return
    }
    let p0 = self.last_pt
    match next_el {
      MoveTo(p) => {
        if !self.stash.is_empty() {
          self.state = FromStash
        }
        self.start_pt = p
        self.last_pt = p
        self.reset_phase()
        continue
      }
      LineTo(p1) => {
        let l = Line::new(p0, p1)
        self.seg_remaining = l.arclen(DASH_ACCURACY)
        self.current_seg = Line(l)
        self.last_pt = p1
      }
      QuadTo(p1, p2) => {
        let q = QuadBez::new(p0, p1, p2)
        self.seg_remaining = q.arclen(DASH_ACCURACY)
        self.current_seg = Quad(q)
        self.last_pt = p2
      }
      CurveTo(p1, p2, p3) => {
        let c = CubicBez::new(p0, p1, p2, p3)
        self.seg_remaining = c.arclen(DASH_ACCURACY)
        self.current_seg = Cubic(c)
        self.last_pt = p3
      }
      ClosePath => {
        self.closepath_pending = true
        if p0 != self.start_pt {
          let l = Line::new(p0, self.start_pt)
          self.seg_remaining = l.arclen(DASH_ACCURACY)
          self.current_seg = Line(l)
          self.last_pt = self.start_pt
        } else {
          self.handle_closepath()
        }
      }
    }
    break
  }
  self.t = 0.0
}

///|
/// Move arc length forward to next event.
fn DashIterator::step(self : DashIterator) -> PathEl? {
  let mut result = None
  if self.state == ToStash && self.needs_moveto {
    self.needs_moveto = false
    if self.is_active {
      result = Some(MoveTo(self.current_seg.start()))
    } else {
      self.state = Working
    }
  } else if self.dash_remaining < self.seg_remaining {
    // next transition is a dash transition
    let seg = self.current_seg.subsegment(self.t, 1.0)
    let t1 = seg.inv_arclen(self.dash_remaining, DASH_ACCURACY)
    if self.is_active {
      let subseg = seg.subsegment(0.0, t1)
      result = Some(seg_to_el(subseg))
      self.state = Working
    } else {
      let p = seg.eval(t1)
      result = Some(MoveTo(p))
    }
    self.is_active = !self.is_active
    self.t += t1 * (1.0 - self.t)
    self.seg_remaining -= self.dash_remaining
    self.dash_ix += 1
    if self.dash_ix == self.dashes.length() {
      self.dash_ix = 0
    }
    self.dash_remaining = self.dashes[self.dash_ix]
  } else {
    if self.is_active {
      let seg = self.current_seg.subsegment(self.t, 1.0)
      result = Some(seg_to_el(seg))
    }
    self.dash_remaining -= self.seg_remaining
    self.get_input()
  }
  result
}

///|
fn DashIterator::handle_closepath(self : DashIterator) -> Unit {
  if self.state == ToStash {
    // Have looped back without breaking a dash, just play it back
    self.stash.push(ClosePath)
  } else if self.is_active && !self.stable_dash_order {
    // connect with path in stash, skip MoveTo.
    self.stash_ix = 1
  }
  self.state = FromStash
  self.reset_phase()
}

///|
fn DashIterator::reset_phase(self : DashIterator) -> Unit {
  self.dash_ix = self.init_dash_ix
  self.dash_remaining = self.init_dash_remaining
  self.is_active = self.init_is_active
  self.needs_moveto = true
}
