// Port of `tiny-skia-path/src/stroker.rs` (based on SkStroke.cpp).
//
// Upstream's `&mut Point` out-parameters are returned as values here; where
// upstream's `Point::normalize`/`set_length` would leave a zero vector on
// failure, the zero vector is reproduced explicitly.

///|
/// Skia swaps pointers to inner and outer builders during joining, but not
/// builders itself.
priv struct SwappableBuilders {
  mut inner : PathBuilder
  mut outer : PathBuilder
}

///|
fn SwappableBuilders::swap(self : SwappableBuilders) -> Unit {
  let tmp = self.inner
  self.inner = self.outer
  self.outer = tmp
}

///|
/// Stroke properties.
pub(all) struct Stroke {
  /// A stroke thickness.
  ///
  /// Must be >= 0.
  ///
  /// When set to 0, a hairline stroking will be used.
  ///
  /// Default: 1.0
  width : Float
  /// The limit at which a sharp corner is drawn beveled.
  ///
  /// Default: 4.0
  miter_limit : Float
  /// A stroke line cap.
  ///
  /// Default: Butt
  line_cap : LineCap
  /// A stroke line join.
  ///
  /// Default: Miter
  line_join : LineJoin
  /// A stroke dashing properties.
  ///
  /// Default: None
  dash : StrokeDash?
} derive(Eq, Debug)

///|
pub impl Default for Stroke with fn default() {
  {
    width: 1.0,
    miter_limit: 4.0,
    line_cap: Butt,
    line_join: Miter,
    dash: None,
  }
}

///|
/// Draws at the beginning and end of an open path contour.
pub(all) enum LineCap {
  /// No stroke extension.
  Butt
  /// Adds circle.
  Round
  /// Adds square.
  Square
} derive(Eq, Debug)

///|
pub impl Default for LineCap with fn default() {
  Butt
}

///|
/// Specifies how corners are drawn when a shape is stroked.
///
/// Join affects the four corners of a stroked rectangle, and the connected
/// segments in a stroked path.
///
/// Choose miter join to draw sharp corners. Choose round join to draw a
/// circle with a radius equal to the stroke width on top of the corner.
/// Choose bevel join to minimally connect the thick strokes.
///
/// The fill path constructed to describe the stroked path respects the join
/// setting but may not contain the actual join. For instance, a fill path
/// constructed with round joins does not necessarily include circles at each
/// connected segment.
pub(all) enum LineJoin {
  /// Extends to miter limit, then switches to bevel.
  Miter
  /// Extends to miter limit, then clips the corner.
  MiterClip
  /// Adds circle.
  Round
  /// Connects outside edges.
  Bevel
} derive(Eq, Debug)

///|
pub impl Default for LineJoin with fn default() {
  Miter
}

///|
let quad_recursive_limit : Int = 3

///|
// quads with extreme widths (e.g. (0,1) (1,6) (0,3) width=5e7) recurse to
// point of failure
// largest seen for normal cubics: 5, 26
// largest seen for normal quads: 11
// 3x limits seen in practice
let recursive_limits : FixedArray[Int] = [5 * 3, 26 * 3, 11 * 3, 11 * 3]

///|
priv enum ReductionType {
  Point // all curve points are practically identical
  Line // the control point is on the line between the ends
  Quad // the control point is outside the line between the ends
  Degenerate // the control point is on the line but outside the ends
  Degenerate2 // two control points are on the line but outside ends (cubic)
  Degenerate3 // three areas of max curvature found (for cubic)
} derive(Eq)

///|
fn ReductionType::to_int(self : ReductionType) -> Int {
  match self {
    Point => 0
    Line => 1
    Quad => 2
    Degenerate => 3
    Degenerate2 => 4
    Degenerate3 => 5
  }
}

///|
priv enum StrokeType {
  Outer // use sign-opposite values later to flip perpendicular axis
  Inner
} derive(Eq)

///|
priv enum ResultType {
  Split // the caller should split the quad stroke in two
  Degenerate // the caller should add a line
  Quad // the caller should (continue to try to) add a quad stroke
} derive(Eq)

///|
priv enum IntersectRayType {
  CtrlPt
  ResultType
} derive(Eq)

///|
/// Returns a stoked path.
///
/// `resolution_scale` can be obtained via
/// [`PathStroker::compute_resolution_scale`].
pub fn Path::stroke(
  self : Path,
  stroke : Stroke,
  resolution_scale : Float,
) -> Path? {
  PathStroker::new().stroke(self, stroke, resolution_scale)
}

///|
/// A path stroker.
struct PathStroker {
  mut radius : Float
  mut inv_miter_limit : Float
  mut res_scale : Float
  mut inv_res_scale : Float
  mut inv_res_scale_squared : Float
  mut first_normal : Point
  mut prev_normal : Point
  mut first_unit_normal : Point
  mut prev_unit_normal : Point
  // on original path
  mut first_pt : Point
  mut prev_pt : Point
  mut first_outer_pt : Point
  mut first_outer_pt_index_in_contour : Int
  mut segment_count : Int
  mut prev_is_line : Bool
  // `CapProc` / `JoinProc` function pointers are represented by the enums.
  mut capper : LineCap
  mut joiner : LineJoin
  // outer is our working answer, inner is temp
  inner : PathBuilder
  mut outer : PathBuilder
  cusper : PathBuilder
  mut stroke_type : StrokeType
  mut recursion_depth : Int // track stack depth to abort if numerics run amok
  mut found_tangents : Bool // do less work until tangents meet (cubic)
  mut join_completed : Bool // previous join was not degenerate
}

///|
/// Creates a new PathStroker.
pub fn PathStroker::new() -> PathStroker {
  {
    radius: 0.0,
    inv_miter_limit: 0.0,
    res_scale: 1.0,
    inv_res_scale: 1.0,
    inv_res_scale_squared: 1.0,
    first_normal: Point::zero(),
    prev_normal: Point::zero(),
    first_unit_normal: Point::zero(),
    prev_unit_normal: Point::zero(),
    first_pt: Point::zero(),
    prev_pt: Point::zero(),
    first_outer_pt: Point::zero(),
    first_outer_pt_index_in_contour: 0,
    segment_count: -1,
    prev_is_line: false,
    capper: Butt,
    joiner: Miter,
    inner: PathBuilder::new(),
    outer: PathBuilder::new(),
    cusper: PathBuilder::new(),
    stroke_type: Outer,
    recursion_depth: 0,
    found_tangents: false,
    join_completed: false,
  }
}

///|
pub impl Default for PathStroker with fn default() {
  PathStroker::new()
}

///|
/// Computes a resolution scale.
///
/// Resolution scale is the "intended" resolution for the output. Default is
/// 1.0.
///
/// Larger values (res > 1) indicate that the result should be more precise,
/// since it will be zoomed up, and small errors will be magnified.
///
/// Smaller values (0 < res < 1) indicate that the result can be less precise,
/// since it will be zoomed down, and small errors may be invisible.
pub fn PathStroker::compute_resolution_scale(ts : Transform) -> Float {
  let sx = Point::from_xy(ts.sx, ts.kx).length()
  let sy = Point::from_xy(ts.ky, ts.sy).length()
  if is_finite(sx) && is_finite(sy) {
    let scale = fmax(sx, sy)
    if scale > 0.0 {
      return scale
    }
  }
  1.0
}

///|
/// Stokes the path.
///
/// Can be called multiple times to reuse allocated buffers.
///
/// `resolution_scale` can be obtained via
/// [`PathStroker::compute_resolution_scale`].
pub fn PathStroker::stroke(
  self : PathStroker,
  path : Path,
  stroke : Stroke,
  resolution_scale : Float,
) -> Path? {
  guard non_zero_positive_f32(stroke.width) is Some(width) else { return None }
  self.stroke_inner(
    path,
    width,
    stroke.miter_limit,
    stroke.line_cap,
    stroke.line_join,
    resolution_scale,
  )
}

///|
fn PathStroker::stroke_inner(
  self : PathStroker,
  path : Path,
  width : Float,
  miter_limit : Float,
  line_cap : LineCap,
  line_join : LineJoin,
  res_scale : Float,
) -> Path? {
  // TODO: stroke_rect optimization

  let mut line_join = line_join
  let mut inv_miter_limit : Float = 0.0
  if line_join == Miter {
    if miter_limit <= 1.0 {
      line_join = Bevel
    } else {
      inv_miter_limit = invert(miter_limit)
    }
  }
  if line_join == MiterClip {
    inv_miter_limit = invert(miter_limit)
  }
  self.res_scale = res_scale
  // The '4' below matches the fill scan converter's error term.
  self.inv_res_scale = invert(res_scale * 4.0)
  self.inv_res_scale_squared = sqr(self.inv_res_scale)
  self.radius = half(width)
  self.inv_miter_limit = inv_miter_limit
  self.first_normal = Point::zero()
  self.prev_normal = Point::zero()
  self.first_unit_normal = Point::zero()
  self.prev_unit_normal = Point::zero()
  self.first_pt = Point::zero()
  self.prev_pt = Point::zero()
  self.first_outer_pt = Point::zero()
  self.first_outer_pt_index_in_contour = 0
  self.segment_count = -1
  self.prev_is_line = false
  self.capper = line_cap
  self.joiner = line_join
  self.inner.clear()
  self.outer.clear()
  self.cusper.clear()
  self.stroke_type = Outer
  self.recursion_depth = 0
  self.found_tangents = false
  self.join_completed = false
  let mut last_segment_is_line = false
  let iter = path.segments()
  iter.set_auto_close(true)
  while iter.next() is Some(segment) {
    match segment {
      MoveTo(p) => self.move_to(p)
      LineTo(p) => {
        self.line_to(p, Some(iter))
        last_segment_is_line = true
      }
      QuadTo(p1, p2) => {
        self.quad_to(p1, p2)
        last_segment_is_line = false
      }
      CubicTo(p1, p2, p3) => {
        self.cubic_to(p1, p2, p3)
        last_segment_is_line = false
      }
      Close => {
        if line_cap != Butt {
          // If the stroke consists of a moveTo followed by a close, treat it
          // as if it were followed by a zero-length line. Lines without
          // length can have square and round end caps.
          if self.has_only_move_to() {
            self.line_to(self.move_to_pt(), None)
            last_segment_is_line = true
            continue
          }

          // If the stroke consists of a moveTo followed by one or more
          // zero-length verbs, then followed by a close, treat is as if it
          // were followed by a zero-length line. Lines without length can
          // have square & round end caps.
          if self.is_current_contour_empty() {
            last_segment_is_line = true
            continue
          }
        }
        self.close(last_segment_is_line)
      }
    }
  }
  self.finish(last_segment_is_line)
}

///|
fn PathStroker::builders(self : PathStroker) -> SwappableBuilders {
  { inner: self.inner, outer: self.outer, }
}

///|
fn PathStroker::move_to_pt(self : PathStroker) -> Point {
  self.first_pt
}

///|
fn PathStroker::move_to(self : PathStroker, p : Point) -> Unit {
  if self.segment_count > 0 {
    self.finish_contour(false, false)
  }
  self.segment_count = 0
  self.first_pt = p
  self.prev_pt = p
  self.join_completed = false
}

///|
fn PathStroker::line_to(
  self : PathStroker,
  p : Point,
  iter : PathSegmentsIter?,
) -> Unit {
  let teeny_line = self.prev_pt.equals_within_tolerance(
    p,
    scalar_nearly_zero * self.inv_res_scale,
  )
  if self.capper == Butt && teeny_line {
    return
  }
  if teeny_line &&
    (
      self.join_completed ||
      (match iter {
        Some(i) => i.has_valid_tangent()
        None => false
      })
    ) {
    return
  }
  guard self.pre_join_to(p, true) is Some((normal, unit_normal)) else { return }
  self.outer.line_to(p.x + normal.x, p.y + normal.y)
  self.inner.line_to(p.x - normal.x, p.y - normal.y)
  self.post_join_to(p, normal, unit_normal)
}

///|
fn PathStroker::quad_to(self : PathStroker, p1 : Point, p2 : Point) -> Unit {
  let quad = [self.prev_pt, p1, p2]
  let (reduction, reduction_type) = check_quad_linear(quad)
  if reduction_type == ReductionType::Point {
    // If the stroke consists of a moveTo followed by a degenerate curve,
    // treat it as if it were followed by a zero-length line. Lines without
    // length can have square and round end caps.
    self.line_to(p2, None)
    return
  }
  if reduction_type == ReductionType::Line {
    self.line_to(p2, None)
    return
  }
  if reduction_type == ReductionType::Degenerate {
    self.line_to(reduction, None)
    let save_joiner = self.joiner
    self.joiner = Round
    self.line_to(p2, None)
    self.joiner = save_joiner
    return
  }
  guard self.pre_join_to(p1, false) is Some((normal_ab, unit_ab)) else {
    self.line_to(p2, None)
    return
  }
  let quad_points = QuadConstruct::default()
  self.init_quad(Outer, 0.0, 1.0, quad_points)
  let _ = self.quad_stroke(quad, quad_points)
  self.init_quad(Inner, 0.0, 1.0, quad_points)
  let _ = self.quad_stroke(quad, quad_points)
  let (normal_bc, unit_bc) = match
    set_normal_unit_normal(quad[1], quad[2], self.res_scale, self.radius) {
    Some(v) => v
    None => (normal_ab, unit_ab)
  }
  self.post_join_to(p2, normal_bc, unit_bc)
}

///|
fn PathStroker::cubic_to(
  self : PathStroker,
  pt1 : Point,
  pt2 : Point,
  pt3 : Point,
) -> Unit {
  let cubic = [self.prev_pt, pt1, pt2, pt3]
  let reduction = Array::make(3, Point::zero())
  let (reduction_type, tangent_pt) = check_cubic_linear(cubic, reduction)
  if reduction_type == ReductionType::Point {
    // If the stroke consists of a moveTo followed by a degenerate curve,
    // treat it as if it were followed by a zero-length line. Lines without
    // length can have square and round end caps.
    self.line_to(pt3, None)
    return
  }
  if reduction_type == ReductionType::Line {
    self.line_to(pt3, None)
    return
  }
  if ReductionType::Degenerate.to_int() <= reduction_type.to_int() &&
    ReductionType::Degenerate3.to_int() >= reduction_type.to_int() {
    self.line_to(reduction[0], None)
    let save_joiner = self.joiner
    self.joiner = Round
    if ReductionType::Degenerate2.to_int() <= reduction_type.to_int() {
      self.line_to(reduction[1], None)
    }
    if ReductionType::Degenerate3 == reduction_type {
      self.line_to(reduction[2], None)
    }
    self.line_to(pt3, None)
    self.joiner = save_joiner
    return
  }
  guard self.pre_join_to(tangent_pt, false) is Some((normal_ab, unit_ab)) else {
    self.line_to(pt3, None)
    return
  }
  let t_values = new_t_values()
  let t_values_len = find_cubic_inflections(cubic[:], t_values)
  let mut last_t : Float = 0.0
  for index in 0..<=t_values_len {
    let next_t : Float = if index < t_values_len {
      t_values[index]
    } else {
      1.0
    }
    let quad_points = QuadConstruct::default()
    self.init_quad(Outer, last_t, next_t, quad_points)
    let _ = self.cubic_stroke(cubic, quad_points)
    self.init_quad(Inner, last_t, next_t, quad_points)
    let _ = self.cubic_stroke(cubic, quad_points)
    last_t = next_t
  }
  if find_cubic_cusp(cubic[:]) is Some(cusp) {
    let cusp_loc = eval_cubic_pos_at(cubic[:], cusp)
    self.cusper.push_circle(cusp_loc.x, cusp_loc.y, self.radius)
  }

  // emit the join even if one stroke succeeded but the last one failed
  // this avoids reversing an inner stroke with a partial path followed by
  // another moveto
  let (normal_cd, unit_cd) = self.set_cubic_end_normal(
    cubic, normal_ab, unit_ab,
  )
  self.post_join_to(pt3, normal_cd, unit_cd)
}

///|
fn PathStroker::cubic_stroke(
  self : PathStroker,
  cubic : Array[Point],
  quad_points : QuadConstruct,
) -> Bool {
  if !self.found_tangents {
    let result_type = self.tangents_meet(cubic, quad_points)
    if result_type != ResultType::Quad {
      let ok = points_within_dist(
        quad_points.quad[0],
        quad_points.quad[2],
        self.inv_res_scale,
      )
      if (result_type == ResultType::Degenerate || ok) &&
        self.cubic_mid_on_line(cubic, quad_points) {
        self.add_degenerate_line(quad_points)
        return true
      }
    } else {
      self.found_tangents = true
    }
  }
  if self.found_tangents {
    let result_type = self.compare_quad_cubic(cubic, quad_points)
    if result_type == ResultType::Quad {
      let stroke = quad_points.quad
      if self.stroke_type == Outer {
        self.outer.quad_to(stroke[1].x, stroke[1].y, stroke[2].x, stroke[2].y)
      } else {
        self.inner.quad_to(stroke[1].x, stroke[1].y, stroke[2].x, stroke[2].y)
      }
      return true
    }
    if result_type == ResultType::Degenerate {
      if !quad_points.opposite_tangents {
        self.add_degenerate_line(quad_points)
        return true
      }
    }
  }
  if !is_finite(quad_points.quad[2].x) || !is_finite(quad_points.quad[2].x) {
    return false // just abort if projected quad isn't representable
  }
  self.recursion_depth += 1
  if self.recursion_depth >
    recursive_limits[if self.found_tangents { 1 } else { 0 }] {
    return false // just abort if projected quad isn't representable
  }
  let half = QuadConstruct::default()
  if !half.init_with_start(quad_points) {
    self.add_degenerate_line(quad_points)
    self.recursion_depth -= 1
    return true
  }
  if !self.cubic_stroke(cubic, half) {
    return false
  }
  if !half.init_with_end(quad_points) {
    self.add_degenerate_line(quad_points)
    self.recursion_depth -= 1
    return true
  }
  if !self.cubic_stroke(cubic, half) {
    return false
  }
  self.recursion_depth -= 1
  true
}

///|
fn PathStroker::cubic_mid_on_line(
  self : PathStroker,
  cubic : Array[Point],
  quad_points : QuadConstruct,
) -> Bool {
  let stroke_mid = self.cubic_quad_mid(cubic, quad_points)
  let dist = pt_to_line(stroke_mid, quad_points.quad[0], quad_points.quad[2])
  dist < self.inv_res_scale_squared
}

///|
fn PathStroker::cubic_quad_mid(
  self : PathStroker,
  cubic : Array[Point],
  quad_points : QuadConstruct,
) -> Point {
  let (_, mid, _) = self.cubic_perp_ray(cubic, quad_points.mid_t)
  mid
}

///|
/// Given a cubic and t, return the point on curve, its perpendicular, and the
/// perpendicular tangent.
///
/// Returns `(t_pt, on_pt, tangent)`.
fn PathStroker::cubic_perp_ray(
  self : PathStroker,
  cubic : Array[Point],
  t : Float,
) -> (Point, Point, Point) {
  let t_pt = eval_cubic_pos_at(cubic[:], t)
  let mut dxy = eval_cubic_tangent_at(cubic[:], t)
  let chopped = Array::make(7, Point::zero())
  if dxy.x == 0.0 && dxy.y == 0.0 {
    let mut c_points = cubic
    if is_nearly_zero(t) {
      dxy = cubic[2] - cubic[0]
    } else if is_nearly_zero(1.0 - t) {
      dxy = cubic[3] - cubic[1]
    } else {
      // If the cubic inflection falls on the cusp, subdivide the cubic
      // to find the tangent at that point.
      chop_cubic_at2(cubic[:], t, chopped, 0)
      dxy = chopped[3] - chopped[2]
      if dxy.x == 0.0 && dxy.y == 0.0 {
        dxy = chopped[3] - chopped[1]
        c_points = chopped
      }
    }
    if dxy.x == 0.0 && dxy.y == 0.0 {
      dxy = c_points[3] - c_points[0]
    }
  }
  let (on_pt, tangent) = self.set_ray_points(t_pt, dxy)
  (t_pt, on_pt, tangent)
}

///|
/// Returns `(normal_cd, unit_normal_cd)`.
fn PathStroker::set_cubic_end_normal(
  self : PathStroker,
  cubic : Array[Point],
  normal_ab : Point,
  unit_normal_ab : Point,
) -> (Point, Point) {
  let mut ab = cubic[1] - cubic[0]
  let mut cd = cubic[3] - cubic[2]
  let mut degenerate_ab = degenerate_vector(ab)
  let mut degenerate_cb = degenerate_vector(cd)
  if degenerate_ab && degenerate_cb {
    return (normal_ab, unit_normal_ab)
  }
  if degenerate_ab {
    ab = cubic[2] - cubic[0]
    degenerate_ab = degenerate_vector(ab)
  }
  if degenerate_cb {
    cd = cubic[3] - cubic[1]
    degenerate_cb = degenerate_vector(cd)
  }
  if degenerate_ab || degenerate_cb {
    return (normal_ab, unit_normal_ab)
  }
  match set_normal_unit_normal2(cd, self.radius) {
    Some(v) => v
    // Upstream leaves `normal_cd` untouched (zero) and zeroes the unit normal.
    None => (Point::zero(), Point::zero())
  }
}

///|
fn PathStroker::compare_quad_cubic(
  self : PathStroker,
  cubic : Array[Point],
  quad_points : QuadConstruct,
) -> ResultType {
  // get the quadratic approximation of the stroke
  self.cubic_quad_ends(cubic, quad_points)
  let result_type = self.intersect_ray(CtrlPt, quad_points)
  if result_type != ResultType::Quad {
    return result_type
  }

  // project a ray from the curve to the stroke
  // points near midpoint on quad, midpoint on cubic
  let (ray1, ray0, _) = self.cubic_perp_ray(cubic, quad_points.mid_t)
  self.stroke_close_enough(quad_points.quad.copy(), ray0, ray1, quad_points)
}

///|
/// Given a cubic and a t range, find the start and end if they haven't been
/// found already.
fn PathStroker::cubic_quad_ends(
  self : PathStroker,
  cubic : Array[Point],
  quad_points : QuadConstruct,
) -> Unit {
  if !quad_points.start_set {
    let (_, on_pt, tangent) = self.cubic_perp_ray(cubic, quad_points.start_t)
    quad_points.quad[0] = on_pt
    quad_points.tangent_start = tangent
    quad_points.start_set = true
  }
  if !quad_points.end_set {
    let (_, on_pt, tangent) = self.cubic_perp_ray(cubic, quad_points.end_t)
    quad_points.quad[2] = on_pt
    quad_points.tangent_end = tangent
    quad_points.end_set = true
  }
}

///|
fn PathStroker::close(self : PathStroker, is_line : Bool) -> Unit {
  self.finish_contour(true, is_line)
}

///|
fn PathStroker::finish_contour(
  self : PathStroker,
  close : Bool,
  curr_is_line : Bool,
) -> Unit {
  if self.segment_count > 0 {
    if close {
      call_joiner(
        self.joiner,
        self.prev_unit_normal,
        self.prev_pt,
        self.first_unit_normal,
        self.radius,
        self.inv_miter_limit,
        self.prev_is_line,
        curr_is_line,
        self.builders(),
      )
      self.outer.close()

      // now add inner as its own contour
      let pt = self.inner.last_point().unwrap_or(Point::zero())
      self.outer.move_to(pt.x, pt.y)
      self.outer.reverse_path_to(self.inner)
      self.outer.close()
    } else {
      // add caps to start and end

      // cap the end
      let pt = self.inner.last_point().unwrap_or(Point::zero())
      call_capper(
        self.capper,
        self.prev_pt,
        self.prev_normal,
        pt,
        curr_is_line,
        self.outer,
      )
      self.outer.reverse_path_to(self.inner)

      // cap the start
      call_capper(
        self.capper,
        self.first_pt,
        -self.first_normal,
        self.first_outer_pt,
        self.prev_is_line,
        self.outer,
      )
      self.outer.close()
    }
    if !self.cusper.is_empty() {
      self.outer.push_path_builder(self.cusper)
      self.cusper.clear()
    }
  }

  // since we may re-use `inner`, we rewind instead of reset, to save on
  // reallocating its internal storage.
  self.inner.clear()
  self.segment_count = -1
  self.first_outer_pt_index_in_contour = self.outer.points.length()
}

///|
/// Returns `(normal, unit_normal)`, or `None` when upstream returns `false`.
fn PathStroker::pre_join_to(
  self : PathStroker,
  p : Point,
  curr_is_line : Bool,
) -> (Point, Point)? {
  let prev_x = self.prev_pt.x
  let prev_y = self.prev_pt.y
  let (normal, unit_normal) = match
    set_normal_unit_normal(self.prev_pt, p, self.res_scale, self.radius) {
    Some(v) => v
    None => {
      if self.capper == Butt {
        return None
      }

      // Square caps and round caps draw even if the segment length is zero.
      // Since the zero length segment has no direction, set the orientation
      // to upright as the default orientation.
      (Point::from_xy(self.radius, 0.0), Point::from_xy(1.0, 0.0))
    }
  }
  if self.segment_count == 0 {
    self.first_normal = normal
    self.first_unit_normal = unit_normal
    self.first_outer_pt = Point::from_xy(prev_x + normal.x, prev_y + normal.y)
    self.outer.move_to(self.first_outer_pt.x, self.first_outer_pt.y)
    self.inner.move_to(prev_x - normal.x, prev_y - normal.y)
  } else {
    // we have a previous segment
    call_joiner(
      self.joiner,
      self.prev_unit_normal,
      self.prev_pt,
      unit_normal,
      self.radius,
      self.inv_miter_limit,
      self.prev_is_line,
      curr_is_line,
      self.builders(),
    )
  }
  self.prev_is_line = curr_is_line
  Some((normal, unit_normal))
}

///|
fn PathStroker::post_join_to(
  self : PathStroker,
  p : Point,
  normal : Point,
  unit_normal : Point,
) -> Unit {
  self.join_completed = true
  self.prev_pt = p
  self.prev_unit_normal = unit_normal
  self.prev_normal = normal
  self.segment_count += 1
}

///|
fn PathStroker::init_quad(
  self : PathStroker,
  stroke_type : StrokeType,
  start : Float,
  end : Float,
  quad_points : QuadConstruct,
) -> Unit {
  self.stroke_type = stroke_type
  self.found_tangents = false
  let _ = quad_points.init(start, end)
}

///|
fn PathStroker::quad_stroke(
  self : PathStroker,
  quad : Array[Point],
  quad_points : QuadConstruct,
) -> Bool {
  let result_type = self.compare_quad_quad(quad, quad_points)
  if result_type == ResultType::Quad {
    let path = if self.stroke_type == Outer { self.outer } else { self.inner }
    path.quad_to(
      quad_points.quad[1].x,
      quad_points.quad[1].y,
      quad_points.quad[2].x,
      quad_points.quad[2].y,
    )
    return true
  }
  if result_type == ResultType::Degenerate {
    self.add_degenerate_line(quad_points)
    return true
  }
  self.recursion_depth += 1
  if self.recursion_depth > recursive_limits[quad_recursive_limit] {
    return false // just abort if projected quad isn't representable
  }
  let half = QuadConstruct::default()
  let _ = half.init_with_start(quad_points)
  if !self.quad_stroke(quad, half) {
    return false
  }
  let _ = half.init_with_end(quad_points)
  if !self.quad_stroke(quad, half) {
    return false
  }
  self.recursion_depth -= 1
  true
}

///|
fn PathStroker::compare_quad_quad(
  self : PathStroker,
  quad : Array[Point],
  quad_points : QuadConstruct,
) -> ResultType {
  // get the quadratic approximation of the stroke
  if !quad_points.start_set {
    let (_, on_p, tangent) = self.quad_perp_ray(quad, quad_points.start_t)
    quad_points.quad[0] = on_p
    quad_points.tangent_start = tangent
    quad_points.start_set = true
  }
  if !quad_points.end_set {
    let (_, on_p, tangent) = self.quad_perp_ray(quad, quad_points.end_t)
    quad_points.quad[2] = on_p
    quad_points.tangent_end = tangent
    quad_points.end_set = true
  }
  let result_type = self.intersect_ray(CtrlPt, quad_points)
  if result_type != ResultType::Quad {
    return result_type
  }

  // project a ray from the curve to the stroke
  let (ray1, ray0, _) = self.quad_perp_ray(quad, quad_points.mid_t)
  self.stroke_close_enough(quad_points.quad.copy(), ray0, ray1, quad_points)
}

///|
/// Given a point on the curve and its derivative, scale the derivative by the
/// radius, and compute the perpendicular point and its tangent.
///
/// Returns `(on_p, tangent)`.
fn PathStroker::set_ray_points(
  self : PathStroker,
  tp : Point,
  dxy : Point,
) -> (Point, Point) {
  let dxy = match dxy.set_length(self.radius) {
    Some(d) => d
    None => Point::from_xy(self.radius, 0.0)
  }
  // go opposite ways for outer, inner
  let axis_flip : Float = match self.stroke_type {
    Outer => 1.0
    Inner => -1.0
  }
  let on_p = Point::from_xy(tp.x + axis_flip * dxy.y, tp.y - axis_flip * dxy.x)
  let tangent = Point::from_xy(on_p.x + dxy.x, on_p.y + dxy.y)
  (on_p, tangent)
}

///|
/// Given a quad and t, return the point on curve, its perpendicular, and the
/// perpendicular tangent.
///
/// Returns `(tp, on_p, tangent)`.
fn PathStroker::quad_perp_ray(
  self : PathStroker,
  quad : Array[Point],
  t : Float,
) -> (Point, Point, Point) {
  let tp = eval_quad_at(quad[:], t)
  let mut dxy = eval_quad_tangent_at(quad[:], t)
  if dxy.is_zero() {
    dxy = quad[2] - quad[0]
  }
  let (on_p, tangent) = self.set_ray_points(tp, dxy)
  (tp, on_p, tangent)
}

///|
fn PathStroker::add_degenerate_line(
  self : PathStroker,
  quad_points : QuadConstruct,
) -> Unit {
  if self.stroke_type == Outer {
    self.outer.line_to(quad_points.quad[2].x, quad_points.quad[2].y)
  } else {
    self.inner.line_to(quad_points.quad[2].x, quad_points.quad[2].y)
  }
}

///|
fn PathStroker::stroke_close_enough(
  self : PathStroker,
  stroke : Array[Point],
  ray0 : Point,
  ray1 : Point,
  quad_points : QuadConstruct,
) -> ResultType {
  let half = normalized_f32_clamped(0.5)
  let stroke_mid = eval_quad_at(stroke[:], half)
  // measure the distance from the curve to the quad-stroke midpoint, compare
  // to radius
  if points_within_dist(ray0, stroke_mid, self.inv_res_scale) {
    // if the difference is small
    if sharp_angle(quad_points.quad) {
      return Split
    }
    return Quad
  }

  // measure the distance to quad's bounds (quick reject)
  // an alternative : look for point in triangle
  if !pt_in_quad_bounds(stroke, ray0, self.inv_res_scale) {
    // if far, subdivide
    return Split
  }

  // measure the curve ray distance to the quad-stroke
  let roots = new_t_values()
  let roots_len = intersect_quad_ray(ray0, ray1, stroke, roots)
  if roots_len != 1 {
    return Split
  }
  let quad_pt = eval_quad_at(stroke[:], roots[0])
  let error = self.inv_res_scale * ((1.0 : Float) - fabs(roots[0] - 0.5) * 2.0)
  if points_within_dist(ray0, quad_pt, error) {
    // if the difference is small, we're done
    if sharp_angle(quad_points.quad) {
      return Split
    }
    return Quad
  }

  // otherwise, subdivide
  Split
}

///|
/// Find the intersection of the stroke tangents to construct a stroke quad.
/// Return whether the stroke is a degenerate (a line), a quad, or must be
/// split. Optionally compute the quad's control point.
fn PathStroker::intersect_ray(
  self : PathStroker,
  intersect_ray_type : IntersectRayType,
  quad_points : QuadConstruct,
) -> ResultType {
  let start = quad_points.quad[0]
  let end = quad_points.quad[2]
  let a_len = quad_points.tangent_start - start
  let b_len = quad_points.tangent_end - end

  // Slopes match when denom goes to zero:
  //                   axLen / ayLen ==                   bxLen / byLen
  // (ayLen * byLen) * axLen / ayLen == (ayLen * byLen) * bxLen / byLen
  //          byLen  * axLen         ==  ayLen          * bxLen
  //          byLen  * axLen         -   ayLen          * bxLen         ( == denom )
  let denom = a_len.cross(b_len)
  if denom == 0.0 || !is_finite(denom) {
    quad_points.opposite_tangents = a_len.dot(b_len) < 0.0
    return Degenerate
  }
  quad_points.opposite_tangents = false
  let ab0 = start - end
  let mut numer_a = b_len.cross(ab0)
  let numer_b = a_len.cross(ab0)
  if (numer_a >= 0.0) == (numer_b >= 0.0) {
    // if the control point is outside the quad ends

    // if the perpendicular distances from the quad points to the opposite
    // tangent line are small, a straight line is good enough
    let dist1 = pt_to_line(start, end, quad_points.tangent_end)
    let dist2 = pt_to_line(end, start, quad_points.tangent_start)
    if fmax(dist1, dist2) <= self.inv_res_scale_squared {
      return Degenerate
    }
    return Split
  }

  // check to see if the denominator is teeny relative to the numerator
  // if the offset by one will be lost, the ratio is too large
  numer_a = numer_a / denom
  let valid_divide = numer_a > numer_a - 1.0
  if valid_divide {
    if intersect_ray_type == CtrlPt {
      // the intersection of the tangents need not be on the tangent segment
      // so 0 <= numer_a <= 1 is not necessarily true
      quad_points.quad[1] = Point::from_xy(
        start.x * ((1.0 : Float) - numer_a) +
        quad_points.tangent_start.x * numer_a,
        start.y * ((1.0 : Float) - numer_a) +
        quad_points.tangent_start.y * numer_a,
      )
    }
    return Quad
  }
  quad_points.opposite_tangents = a_len.dot(b_len) < 0.0

  // if the lines are parallel, straight line is good enough
  Degenerate
}

///|
/// Given a cubic and a t-range, determine if the stroke can be described by a
/// quadratic.
fn PathStroker::tangents_meet(
  self : PathStroker,
  cubic : Array[Point],
  quad_points : QuadConstruct,
) -> ResultType {
  self.cubic_quad_ends(cubic, quad_points)
  self.intersect_ray(ResultType, quad_points)
}

///|
fn PathStroker::finish(self : PathStroker, is_line : Bool) -> Path? {
  self.finish_contour(false, is_line)

  // Swap out the outer builder.
  let buf = self.outer
  self.outer = PathBuilder::new()
  buf.finish()
}

///|
fn PathStroker::has_only_move_to(self : PathStroker) -> Bool {
  self.segment_count == 0
}

///|
fn PathStroker::is_current_contour_empty(self : PathStroker) -> Bool {
  self.inner.is_zero_length_since_point(0) &&
  self.outer.is_zero_length_since_point(self.first_outer_pt_index_in_contour)
}

///|
/// `CapProc` dispatch (`cap_factory`). `other_path` is only checked for
/// presence upstream.
fn call_capper(
  cap : LineCap,
  pivot : Point,
  normal : Point,
  stop : Point,
  other_path : Bool,
  path : PathBuilder,
) -> Unit {
  match cap {
    Butt => butt_capper(pivot, normal, stop, other_path, path)
    Round => round_capper(pivot, normal, stop, other_path, path)
    Square => square_capper(pivot, normal, stop, other_path, path)
  }
}

///|
fn butt_capper(
  _pivot : Point,
  _normal : Point,
  stop : Point,
  _other_path : Bool,
  path : PathBuilder,
) -> Unit {
  path.line_to(stop.x, stop.y)
}

///|
fn round_capper(
  pivot : Point,
  normal : Point,
  stop : Point,
  _other_path : Bool,
  path : PathBuilder,
) -> Unit {
  let parallel = normal.rotate_cw()
  let projected_center = pivot + parallel
  path.conic_points_to(
    projected_center + normal,
    projected_center,
    scalar_root_2_over_2,
  )
  path.conic_points_to(projected_center - normal, stop, scalar_root_2_over_2)
}

///|
fn square_capper(
  pivot : Point,
  normal : Point,
  stop : Point,
  other_path : Bool,
  path : PathBuilder,
) -> Unit {
  let parallel = normal.rotate_cw()
  if other_path {
    path.set_last_point(
      Point::from_xy(
        pivot.x + normal.x + parallel.x,
        pivot.y + normal.y + parallel.y,
      ),
    )
    path.line_to(
      pivot.x - normal.x + parallel.x,
      pivot.y - normal.y + parallel.y,
    )
  } else {
    path.line_to(
      pivot.x + normal.x + parallel.x,
      pivot.y + normal.y + parallel.y,
    )
    path.line_to(
      pivot.x - normal.x + parallel.x,
      pivot.y - normal.y + parallel.y,
    )
    path.line_to(stop.x, stop.y)
  }
}

///|
/// `JoinProc` dispatch (`join_factory`).
fn call_joiner(
  join : LineJoin,
  before_unit_normal : Point,
  pivot : Point,
  after_unit_normal : Point,
  radius : Float,
  inv_miter_limit : Float,
  prev_is_line : Bool,
  curr_is_line : Bool,
  builders : SwappableBuilders,
) -> Unit {
  match join {
    Miter =>
      miter_joiner_inner(
        before_unit_normal, pivot, after_unit_normal, radius, inv_miter_limit, false,
        prev_is_line, curr_is_line, builders,
      )
    MiterClip =>
      miter_joiner_inner(
        before_unit_normal, pivot, after_unit_normal, radius, inv_miter_limit, true,
        prev_is_line, curr_is_line, builders,
      )
    Round =>
      round_joiner(
        before_unit_normal, pivot, after_unit_normal, radius, builders,
      )
    Bevel =>
      bevel_joiner(
        before_unit_normal, pivot, after_unit_normal, radius, builders,
      )
  }
}

///|
fn is_clockwise(before : Point, after : Point) -> Bool {
  before.x * after.y > before.y * after.x
}

///|
priv enum AngleType {
  Nearly180
  Sharp
  Shallow
  NearlyLine
} derive(Eq)

///|
fn dot_to_angle_type(dot : Float) -> AngleType {
  if dot >= 0.0 {
    // shallow or line
    if is_nearly_zero((1.0 : Float) - dot) {
      NearlyLine
    } else {
      Shallow
    }
  } else if is_nearly_zero((1.0 : Float) + dot) {
    // sharp or 180
    Nearly180
  } else {
    Sharp
  }
}

///|
fn handle_inner_join(pivot : Point, after : Point, inner : PathBuilder) -> Unit {
  // In the degenerate case that the stroke radius is larger than our segments
  // just connecting the two inner segments may "show through" as a funny
  // diagonal. To pseudo-fix this, we go through the pivot point. This adds
  // an extra point/edge, but I can't see a cheap way to know when this is
  // not needed :(
  inner.line_to(pivot.x, pivot.y)
  inner.line_to(pivot.x - after.x, pivot.y - after.y)
}

///|
fn bevel_joiner(
  before_unit_normal : Point,
  pivot : Point,
  after_unit_normal : Point,
  radius : Float,
  builders : SwappableBuilders,
) -> Unit {
  let mut after = after_unit_normal.scaled(radius)
  if !is_clockwise(before_unit_normal, after_unit_normal) {
    builders.swap()
    after = -after
  }
  builders.outer.line_to(pivot.x + after.x, pivot.y + after.y)
  handle_inner_join(pivot, after, builders.inner)
}

///|
fn round_joiner(
  before_unit_normal : Point,
  pivot : Point,
  after_unit_normal : Point,
  radius : Float,
  builders : SwappableBuilders,
) -> Unit {
  let dot_prod = before_unit_normal.dot(after_unit_normal)
  let angle_type = dot_to_angle_type(dot_prod)
  if angle_type == NearlyLine {
    return
  }
  let mut before = before_unit_normal
  let mut after = after_unit_normal
  let mut dir : PathDirection = CW
  if !is_clockwise(before, after) {
    builders.swap()
    before = -before
    after = -after
    dir = CCW
  }
  let ts = Transform::from_row(radius, 0.0, 0.0, radius, pivot.x, pivot.y)
  let conics = Array::makei(5, _ => {
    Conic::new(Point::zero(), Point::zero(), Point::zero(), 0.0)
  })
  if Conic::build_unit_arc(before, after, dir, ts, conics) is Some(count) {
    for i in 0..<count {
      let conic = conics[i]
      builders.outer.conic_points_to(
        conic.points[1],
        conic.points[2],
        conic.weight,
      )
    }
    after = after.scaled(radius)
    handle_inner_join(pivot, after, builders.inner)
  }
}

///|
fn miter_joiner_inner(
  before_unit_normal : Point,
  pivot : Point,
  after_unit_normal : Point,
  radius : Float,
  inv_miter_limit : Float,
  miter_clip : Bool,
  prev_is_line : Bool,
  curr_is_line : Bool,
  builders : SwappableBuilders,
) -> Unit {
  fn do_blunt_or_clipped(
    builders : SwappableBuilders,
    pivot : Point,
    radius : Float,
    prev_is_line : Bool,
    curr_is_line : Bool,
    before : Point,
    mid : Point,
    after : Point,
    inv_miter_limit : Float,
    miter_clip : Bool,
  ) -> Unit {
    let after = after.scaled(radius)
    if miter_clip {
      let mid = mid.normalize().unwrap_or(Point::zero())
      let cos_beta = before.dot(mid)
      let sin_beta = before.cross(mid)
      let x = if fabs(sin_beta) <= scalar_nearly_zero {
        (1.0 : Float) / inv_miter_limit
      } else {
        ((1.0 : Float) / inv_miter_limit - cos_beta) / sin_beta
      }
      let before = before.scaled(radius)
      let before_tangent = before.rotate_cw()
      let after_tangent = after.rotate_ccw()
      let c1 = pivot + before + before_tangent.scaled(x)
      let c2 = pivot + after + after_tangent.scaled(x)
      if prev_is_line {
        builders.outer.set_last_point(c1)
      } else {
        builders.outer.line_to(c1.x, c1.y)
      }
      builders.outer.line_to(c2.x, c2.y)
    }
    if !curr_is_line {
      builders.outer.line_to(pivot.x + after.x, pivot.y + after.y)
    }
    handle_inner_join(pivot, after, builders.inner)
  }

  fn do_miter(
    builders : SwappableBuilders,
    pivot : Point,
    radius : Float,
    prev_is_line : Bool,
    curr_is_line : Bool,
    mid : Point,
    after : Point,
  ) -> Unit {
    let after = after.scaled(radius)
    if prev_is_line {
      builders.outer.set_last_point(
        Point::from_xy(pivot.x + mid.x, pivot.y + mid.y),
      )
    } else {
      builders.outer.line_to(pivot.x + mid.x, pivot.y + mid.y)
    }
    if !curr_is_line {
      builders.outer.line_to(pivot.x + after.x, pivot.y + after.y)
    }
    handle_inner_join(pivot, after, builders.inner)
  }

  // negate the dot since we're using normals instead of tangents
  let dot_prod = before_unit_normal.dot(after_unit_normal)
  let angle_type = dot_to_angle_type(dot_prod)
  let mut before = before_unit_normal
  let mut after = after_unit_normal
  let mut mid : Point = Point::zero()
  if angle_type == NearlyLine {
    return
  }
  if angle_type == Nearly180 {
    mid = (after - before).scaled(radius / 2.0)
    do_blunt_or_clipped(
      builders, pivot, radius, prev_is_line, false, before, mid, after, inv_miter_limit,
      miter_clip,
    )
    return
  }
  let ccw = !is_clockwise(before, after)
  if ccw {
    builders.swap()
    before = -before
    after = -after
  }

  // Before we enter the world of square-roots and divides,
  // check if we're trying to join an upright right angle
  // (common case for stroking rectangles). If so, special case
  // that (for speed an accuracy).
  // Note: we only need to check one normal if dot==0
  if dot_prod == 0.0 && inv_miter_limit <= scalar_root_2_over_2 {
    mid = (before + after).scaled(radius)
    do_miter(builders, pivot, radius, prev_is_line, curr_is_line, mid, after)
    return
  }

  // choose the most accurate way to form the initial mid-vector
  if angle_type == Sharp {
    mid = Point::from_xy(after.y - before.y, before.x - after.x)
    if ccw {
      mid = -mid
    }
  } else {
    mid = Point::from_xy(before.x + after.x, before.y + after.y)
  }

  // midLength = radius / sinHalfAngle
  // if (midLength > miterLimit * radius) abort
  // if (radius / sinHalf > miterLimit * radius) abort
  // if (1 / sinHalf > miterLimit) abort
  // if (1 / miterLimit > sinHalf) abort
  // My dotProd is opposite sign, since it is built from normals and not
  // tangents hence 1 + dot instead of 1 - dot in the formula
  let sin_half_angle = half((1.0 : Float) + dot_prod).sqrt()
  if sin_half_angle < inv_miter_limit {
    do_blunt_or_clipped(
      builders, pivot, radius, prev_is_line, false, before, mid, after, inv_miter_limit,
      miter_clip,
    )
    return
  }
  mid = mid.set_length(radius / sin_half_angle).unwrap_or(Point::zero())
  do_miter(builders, pivot, radius, prev_is_line, curr_is_line, mid, after)
}

///|
/// Returns `(normal, unit_normal)`.
fn set_normal_unit_normal(
  before : Point,
  after : Point,
  scale : Float,
  radius : Float,
) -> (Point, Point)? {
  guard set_point_length(
      (after.x - before.x) * scale,
      (after.y - before.y) * scale,
      1.0,
    )
    is Some(unit_normal) else {
    return None
  }
  let unit_normal = unit_normal.rotate_ccw()
  Some((unit_normal.scaled(radius), unit_normal))
}

///|
/// Returns `(normal, unit_normal)`.
fn set_normal_unit_normal2(vec : Point, radius : Float) -> (Point, Point)? {
  guard set_point_length(vec.x, vec.y, 1.0) is Some(unit_normal) else {
    return None
  }
  let unit_normal = unit_normal.rotate_ccw()
  Some((unit_normal.scaled(radius), unit_normal))
}

///|
/// The state of the quad stroke under construction.
priv struct QuadConstruct {
  quad : Array[Point] // the stroked quad parallel to the original curve
  mut tangent_start : Point // a point tangent to quad[0]
  mut tangent_end : Point // a point tangent to quad[2]
  mut start_t : Float // a segment of the original curve
  mut mid_t : Float
  mut end_t : Float
  mut start_set : Bool // state to share common points across structs
  mut end_set : Bool
  mut opposite_tangents : Bool // set if coincident tangents have opposite directions
}

///|
fn QuadConstruct::default() -> QuadConstruct {
  {
    quad: [Point::zero(), Point::zero(), Point::zero()],
    tangent_start: Point::zero(),
    tangent_end: Point::zero(),
    start_t: 0.0,
    mid_t: 0.0,
    end_t: 0.0,
    start_set: false,
    end_set: false,
    opposite_tangents: false,
  }
}

///|
/// return false if start and end are too close to have a unique middle
fn QuadConstruct::init(
  self : QuadConstruct,
  start : Float,
  end : Float,
) -> Bool {
  self.start_t = start
  self.mid_t = normalized_f32_clamped(half(start + end))
  self.end_t = end
  self.start_set = false
  self.end_set = false
  self.start_t < self.mid_t && self.mid_t < self.end_t
}

///|
fn QuadConstruct::init_with_start(
  self : QuadConstruct,
  parent : QuadConstruct,
) -> Bool {
  if !self.init(parent.start_t, parent.mid_t) {
    return false
  }
  self.quad[0] = parent.quad[0]
  self.tangent_start = parent.tangent_start
  self.start_set = true
  true
}

///|
fn QuadConstruct::init_with_end(
  self : QuadConstruct,
  parent : QuadConstruct,
) -> Bool {
  if !self.init(parent.mid_t, parent.end_t) {
    return false
  }
  self.quad[2] = parent.quad[2]
  self.tangent_end = parent.tangent_end
  self.end_set = true
  true
}

///|
fn check_quad_linear(quad : Array[Point]) -> (Point, ReductionType) {
  let degenerate_ab = degenerate_vector(quad[1] - quad[0])
  let degenerate_bc = degenerate_vector(quad[2] - quad[1])
  if degenerate_ab && degenerate_bc {
    return (Point::zero(), ReductionType::Point)
  }
  if degenerate_ab || degenerate_bc {
    return (Point::zero(), Line)
  }
  if !quad_in_line(quad) {
    return (Point::zero(), Quad)
  }
  let t = find_quad_max_curvature(quad[:])
  if t == 0.0 || t == 1.0 {
    return (Point::zero(), Line)
  }
  (eval_quad_at(quad[:], t), Degenerate)
}

///|
fn degenerate_vector(v : Point) -> Bool {
  !v.can_normalize()
}

///|
/// Given quad, see if all there points are in a line.
/// Return true if the inside point is close to a line connecting the
/// outermost points.
///
/// Find the outermost point by looking for the largest difference in X or Y.
/// Since the XOR of the indices is 3  (0 ^ 1 ^ 2)
/// the missing index equals: outer_1 ^ outer_2 ^ 3.
fn quad_in_line(quad : Array[Point]) -> Bool {
  let mut pt_max : Float = -1.0
  let mut outer1 = 0
  let mut outer2 = 0
  for index in 0..<2 {
    for inner in (index + 1)..<3 {
      let test_diff = quad[inner] - quad[index]
      let test_max = fmax(fabs(test_diff.x), fabs(test_diff.y))
      if pt_max < test_max {
        outer1 = index
        outer2 = inner
        pt_max = test_max
      }
    }
  }
  let mid = outer1 ^ outer2 ^ 3
  let curvature_slop : Float = 0.000005 // this multiplier is pulled out of the air
  let line_slop = pt_max * pt_max * curvature_slop
  pt_to_line(quad[mid], quad[outer1], quad[outer2]) <= line_slop
}

///|
/// returns the distance squared from the point to the line
fn pt_to_line(pt : Point, line_start : Point, line_end : Point) -> Float {
  let dxy = line_end - line_start
  let ab0 = pt - line_start
  let numer = dxy.dot(ab0)
  let denom = dxy.dot(dxy)
  let t = numer / denom
  if t >= 0.0 && t <= 1.0 {
    let hit = Point::from_xy(
      line_start.x * ((1.0 : Float) - t) + line_end.x * t,
      line_start.y * ((1.0 : Float) - t) + line_end.y * t,
    )
    hit.distance_to_sqd(pt)
  } else {
    pt.distance_to_sqd(line_start)
  }
}

///|
/// Intersect the line with the quad and return the t values on the quad where
/// the line crosses. Returns the number of roots written.
fn intersect_quad_ray(
  line0 : Point,
  line1 : Point,
  quad : Array[Point],
  roots : Array[Float],
) -> Int {
  let vec = line1 - line0
  let r : Array[Float] = [0.0, 0.0, 0.0]
  for n in 0..<3 {
    r[n] = (quad[n].y - line0.y) * vec.x - (quad[n].x - line0.x) * vec.y
  }
  let mut a = r[2]
  let mut b = r[1]
  let c = r[0]
  a = a + (c - (2.0 : Float) * b) // A = a - 2*b + c
  b = b - c // B = -(b - c)
  find_unit_quad_roots(a, (2.0 : Float) * b, c, roots)
}

///|
fn points_within_dist(near_pt : Point, far_pt : Point, limit : Float) -> Bool {
  near_pt.distance_to_sqd(far_pt) <= limit * limit
}

///|
fn sharp_angle(quad : Array[Point]) -> Bool {
  let mut smaller = quad[1] - quad[0]
  let mut larger = quad[1] - quad[2]
  let smaller_len = smaller.length_sqd()
  let mut larger_len = larger.length_sqd()
  if smaller_len > larger_len {
    let tmp = smaller
    smaller = larger
    larger = tmp
    larger_len = smaller_len
  }
  guard smaller.set_length(larger_len) is Some(smaller) else { return false }
  let dot = smaller.dot(larger)
  dot > 0.0
}

///|
/// Return true if the point is close to the bounds of the quad. This is used
/// as a quick reject.
fn pt_in_quad_bounds(
  quad : Array[Point],
  pt : Point,
  inv_res_scale : Float,
) -> Bool {
  let x_min = fmin(fmin(quad[0].x, quad[1].x), quad[2].x)
  if pt.x + inv_res_scale < x_min {
    return false
  }
  let x_max = fmax(fmax(quad[0].x, quad[1].x), quad[2].x)
  if pt.x - inv_res_scale > x_max {
    return false
  }
  let y_min = fmin(fmin(quad[0].y, quad[1].y), quad[2].y)
  if pt.y + inv_res_scale < y_min {
    return false
  }
  let y_max = fmax(fmax(quad[0].y, quad[1].y), quad[2].y)
  if pt.y - inv_res_scale > y_max {
    return false
  }
  true
}

///|
/// Writes up to 3 reduction points into `reduction` and returns the reduction
/// type together with the tangent point (only set for `Quad`).
fn check_cubic_linear(
  cubic : Array[Point],
  reduction : Array[Point],
) -> (ReductionType, Point) {
  let degenerate_ab = degenerate_vector(cubic[1] - cubic[0])
  let degenerate_bc = degenerate_vector(cubic[2] - cubic[1])
  let degenerate_cd = degenerate_vector(cubic[3] - cubic[2])
  if degenerate_ab && degenerate_bc && degenerate_cd {
    return (ReductionType::Point, Point::zero())
  }
  if (if degenerate_ab { 1 } else { 0 }) +
    (if degenerate_bc { 1 } else { 0 }) +
    (if degenerate_cd { 1 } else { 0 }) ==
    2 {
    return (Line, Point::zero())
  }
  if !cubic_in_line(cubic) {
    let tangent_pt = if degenerate_ab { cubic[2] } else { cubic[1] }
    return (Quad, tangent_pt)
  }
  let t_values : Array[Float] = [0.0, 0.0, 0.0]
  let t_values_len = find_cubic_max_curvature(cubic[:], t_values)
  let mut r_count = 0
  // Now loop over the t-values, and reject any that evaluate to either
  // end-point
  for i in 0..<t_values_len {
    let t = t_values[i]
    if (0.0 : Float) >= t || t >= 1.0 {
      continue
    }
    reduction[r_count] = eval_cubic_pos_at(cubic[:], t)
    if reduction[r_count] != cubic[0] && reduction[r_count] != cubic[3] {
      r_count += 1
    }
  }
  let reduction_type : ReductionType = match r_count {
    0 => Line
    1 => Degenerate
    2 => Degenerate2
    _ => Degenerate3
  }
  (reduction_type, Point::zero())
}

///|
/// Given a cubic, determine if all four points are in a line.
///
/// Return true if the inner points is close to a line connecting the
/// outermost points.
///
/// Find the outermost point by looking for the largest difference in X or Y.
/// Given the indices of the outermost points, and that outer_1 is greater
/// than outer_2, this table shows the index of the smaller of the remaining
/// points:
///
/// ```text
///                   outer_2
///               0    1    2    3
///   outer_1     ----------------
///      0     |  -    2    1    1
///      1     |  -    -    0    0
///      2     |  -    -    -    0
///      3     |  -    -    -    -
/// ```
///
/// If outer_1 == 0 and outer_2 == 1, the smaller of the remaining indices (2
/// and 3) is 2.
///
/// This table can be collapsed to: (1 + (2 >> outer_2)) >> outer_1
///
/// Given three indices (outer_1 outer_2 mid_1) from 0..3, the remaining index
/// is:
///
/// ```text
/// mid_2 == (outer_1 ^ outer_2 ^ mid_1)
/// ```
fn cubic_in_line(cubic : Array[Point]) -> Bool {
  let mut pt_max : Float = -1.0
  let mut outer1 = 0
  let mut outer2 = 0
  for index in 0..<3 {
    for inner in (index + 1)..<4 {
      let test_diff = cubic[inner] - cubic[index]
      let test_max = fmax(fabs(test_diff.x), fabs(test_diff.y))
      if pt_max < test_max {
        outer1 = index
        outer2 = inner
        pt_max = test_max
      }
    }
  }
  let mid1 = (1 + (2 >> outer2)) >> outer1
  let mid2 = outer1 ^ outer2 ^ mid1
  let line_slop = pt_max * pt_max * 0.00001 // this multiplier is pulled out of the air
  pt_to_line(cubic[mid1], cubic[outer1], cubic[outer2]) <= line_slop &&
  pt_to_line(cubic[mid2], cubic[outer1], cubic[outer2]) <= line_slop
}
