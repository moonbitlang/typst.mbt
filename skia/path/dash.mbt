// Port of `tiny-skia-path/src/dash.rs`.
//
// This module is a mix of SkDashPath, SkDashPathEffect, SkContourMeasure and
// SkPathMeasure.

///|
/// A stroke dashing properties.
///
/// Contains an array of pairs, where the first number indicates an "on"
/// interval and the second one indicates an "off" interval; a dash offset
/// value and internal properties.
///
/// # Guarantees
///
/// - The dash array always have an even number of values.
/// - All dash array values are finite and >= 0.
/// - There is at least two dash array values.
/// - The sum of all dash array values is positive and finite.
/// - Dash offset is finite.
pub struct StrokeDash {
  priv array : Array[Float]
  priv offset : Float
  priv interval_len : Float
  priv first_len : Float // TODO: PositiveF32
  priv first_index : Int
} derive(Eq, Debug)

///|
/// Creates a new stroke dashing object.
pub fn StrokeDash::new(
  dash_array : Array[Float],
  dash_offset : Float,
) -> StrokeDash? {
  guard finite_f32(dash_offset) is Some(dash_offset) else { return None }
  if dash_array.length() < 2 || dash_array.length() % 2 != 0 {
    return None
  }
  if dash_array.iter().any(n => n < 0.0) {
    return None
  }
  let mut interval_len : Float = 0.0
  for n in dash_array {
    interval_len = interval_len + n
  }
  guard non_zero_positive_f32(interval_len) is Some(interval_len) else {
    return None
  }
  let dash_offset = adjust_dash_offset(dash_offset, interval_len)
  let (first_len, first_index) = find_first_interval(dash_array, dash_offset)
  Some({
    array: dash_array,
    offset: dash_offset,
    interval_len,
    first_len,
    first_index,
  })
}

///|
/// Adjust phase to be between 0 and len, "flipping" phase if negative.
/// e.g., if len is 100, then phase of -20 (or -120) is equivalent to 80.
fn adjust_dash_offset(offset : Float, len : Float) -> Float {
  let mut offset = offset
  if offset < 0.0 {
    offset = -offset
    if offset > len {
      offset = fmodf(offset, len)
    }
    offset = len - offset

    // Due to finite precision, it's possible that phase == len,
    // even after the subtract (if len >>> phase), so fix that here.
    if offset == len {
      offset = 0.0
    }
    offset
  } else if offset >= len {
    fmodf(offset, len)
  } else {
    offset
  }
}

///|
fn find_first_interval(
  dash_array : Array[Float],
  dash_offset : Float,
) -> (Float, Int) {
  let mut dash_offset = dash_offset
  for i, gap in dash_array {
    if dash_offset > gap || (dash_offset == gap && gap != 0.0) {
      dash_offset = dash_offset - gap
    } else {
      return (gap - dash_offset, i)
    }
  }

  // If we get here, phase "appears" to be larger than our length. This
  // shouldn't happen with perfect precision, but we can accumulate errors
  // during the initial length computation (rounding can make our sum be too
  // big or too small. In that event, we just have to eat the error here.
  (dash_array[0], 0)
}

///|
/// Converts the current path into a dashed one.
///
/// `resolution_scale` can be obtained via
/// [`PathStroker::compute_resolution_scale`].
///
/// Returns `None` when more than 1_000_000 dashes had to be produced
/// or when the final path has an invalid bounding box.
pub fn Path::dash(
  self : Path,
  dash : StrokeDash,
  resolution_scale : Float,
) -> Path? {
  dash_impl(self, dash, resolution_scale)
}

///|
fn dash_impl(src : Path, dash : StrokeDash, res_scale : Float) -> Path? {
  // We do not support the `cull_path` branch here.
  // Skia has a lot of code for cases when a path contains only a single
  // zero-length line or when a path is a rect. Not sure why.
  // We simply ignoring it for the sake of simplicity.

  // We also doesn't support the `SpecialLineRec` case.
  // I have no idea what the point in it.

  fn is_even(x : Int) -> Bool {
    x % 2 == 0
  }

  let pb = PathBuilder::new()
  let mut dash_count : Float = 0.0
  let contours = ContourMeasureIter::new(src, res_scale)
  while contours.next() is Some(contour) {
    let mut skip_first_segment = contour.is_closed
    let mut added_segment = false
    let length = contour.length
    let mut index = dash.first_index

    // Since the path length / dash length ratio may be arbitrarily large, we
    // can exert significant memory pressure while attempting to build the
    // filtered path. To avoid this, we simply give up dashing beyond a
    // certain threshold.
    //
    // The original bug report (http://crbug.com/165432) is based on a path
    // yielding more than 90 million dash segments and crashing the memory
    // allocator. A limit of 1 million segments seems reasonable: at 2 verbs
    // per segment * 9 bytes per verb, this caps the maximum dash memory
    // overhead at roughly 17MB per path.
    let max_dash_count = 1000000
    dash_count = dash_count +
      length * Float::from_int(dash.array.length() >> 1) / dash.interval_len
    if dash_count > Float::from_int(max_dash_count) {
      return None
    }

    // Using double precision to avoid looping indefinitely due to single
    // precision rounding (for extreme path_length/dash_length ratios). See
    // test_infinite_dash() unittest.
    // (Upstream tiny-skia actually uses `f32` here.)
    let mut distance : Float = 0.0
    let mut d_len = dash.first_len
    while distance < length {
      added_segment = false
      if is_even(index) && !skip_first_segment {
        added_segment = true
        contour.push_segment(distance, distance + d_len, true, pb)
      }
      distance = distance + d_len

      // clear this so we only respect it the first time around
      skip_first_segment = false

      // wrap around our intervals array if necessary
      index += 1
      if index == dash.array.length() {
        index = 0
      }

      // fetch our next d_len
      d_len = dash.array[index]
    }

    // extend if we ended on a segment and we need to join up with the
    // (skipped) initial segment
    if contour.is_closed && is_even(dash.first_index) && dash.first_len >= 0.0 {
      contour.push_segment(0.0, dash.first_len, !added_segment, pb)
    }
  }
  pb.finish()
}

///|
let max_t_value : Int = 0x3FFFFFFF

///|
priv struct ContourMeasureIter {
  iter : PathSegmentsIter
  tolerance : Float
}

///|
fn ContourMeasureIter::new(
  path : Path,
  res_scale : Float,
) -> ContourMeasureIter {
  // can't use tangents, since we need [0..1..................2] to be seen
  // as definitely not a line (it is when drawn, but not parametrically)
  // so we compare midpoints
  let cheap_dist_limit : Float = 0.5 // just made this value up
  { iter: path.segments(), tolerance: cheap_dist_limit * invert(res_scale), }
}

///|
/// If it encounters a zero-length contour, it is skipped.
fn ContourMeasureIter::next(self : ContourMeasureIter) -> ContourMeasure? {
  // Note:
  // as we accumulate distance, we have to check that the result of +=
  // actually made it larger, since a very small delta might be > 0, but
  // still have no effect on distance (if distance >>> delta).
  //
  // We do this check below, and in compute_quad_segs and compute_cubic_segs

  let contour = ContourMeasure::default()
  let mut point_index = 0
  let mut distance : Float = 0.0
  let mut have_seen_close = false
  let mut prev_p = Point::zero()
  while self.iter.next() is Some(seg) {
    match seg {
      MoveTo(p0) => {
        contour.points.push(p0)
        prev_p = p0
      }
      LineTo(p0) => {
        let prev_d = distance
        distance = contour.compute_line_seg(prev_p, p0, distance, point_index)
        if distance > prev_d {
          contour.points.push(p0)
          point_index += 1
        }
        prev_p = p0
      }
      QuadTo(p0, p1) => {
        let prev_d = distance
        distance = contour.compute_quad_segs(
          prev_p,
          p0,
          p1,
          distance,
          0,
          max_t_value,
          point_index,
          self.tolerance,
        )
        if distance > prev_d {
          contour.points.push(p0)
          contour.points.push(p1)
          point_index += 2
        }
        prev_p = p1
      }
      CubicTo(p0, p1, p2) => {
        let prev_d = distance
        distance = contour.compute_cubic_segs(
          prev_p,
          p0,
          p1,
          p2,
          distance,
          0,
          max_t_value,
          point_index,
          self.tolerance,
        )
        if distance > prev_d {
          contour.points.push(p0)
          contour.points.push(p1)
          contour.points.push(p2)
          point_index += 3
        }
        prev_p = p2
      }
      Close => have_seen_close = true
    }

    // TODO: to contour iter?
    if self.iter.next_verb() is Some(Move) {
      break
    }
  }
  if !is_finite(distance) {
    return None
  }
  if have_seen_close {
    let prev_d = distance
    let first_pt = contour.points[0]
    distance = contour.compute_line_seg(
      contour.points[point_index],
      first_pt,
      distance,
      point_index,
    )
    if distance > prev_d {
      contour.points.push(first_pt)
    }
  }
  contour.length = distance
  contour.is_closed = have_seen_close
  if contour.points.is_empty() {
    None
  } else {
    Some(contour)
  }
}

///|
priv enum SegmentType {
  Line
  Quad
  Cubic
}

///|
priv struct Segment {
  distance : Float // total distance up to this point
  point_index : Int // index into the ContourMeasure::points array
  t_value : Int
  kind : SegmentType
}

///|
fn Segment::scalar_t(self : Segment) -> Float {
  // 1/kMaxTValue can't be represented as a float, but it's close and the
  // limits work fine.
  let max_t_reciprocal : Float = (1.0 : Float) / Float::from_int(max_t_value)
  Float::from_int(self.t_value) * max_t_reciprocal
}

///|
priv struct ContourMeasure {
  segments : Array[Segment]
  points : Array[Point]
  mut length : Float
  mut is_closed : Bool
}

///|
fn ContourMeasure::default() -> ContourMeasure {
  { segments: [], points: [], length: 0.0, is_closed: false, }
}

///|
fn ContourMeasure::push_segment(
  self : ContourMeasure,
  start_d : Float,
  stop_d : Float,
  start_with_move_to : Bool,
  pb : PathBuilder,
) -> Unit {
  let mut start_d = start_d
  let mut stop_d = stop_d
  if start_d < 0.0 {
    start_d = 0.0
  }
  if stop_d > self.length {
    stop_d = self.length
  }
  if !(start_d <= stop_d) {
    // catch NaN values as well
    return
  }
  if self.segments.is_empty() {
    return
  }
  guard self.distance_to_segment(start_d) is Some((seg_index, start_t)) else {
    return
  }
  let mut start_t = start_t
  let mut seg = self.segments[seg_index]
  guard self.distance_to_segment(stop_d) is Some((stop_seg_index, stop_t)) else {
    return
  }
  let stop_seg = self.segments[stop_seg_index]
  if start_with_move_to {
    let p = compute_pos(self.points[seg.point_index:], seg.kind, start_t)
    pb.move_to(p.x, p.y)
  }
  if seg.point_index == stop_seg.point_index {
    segment_to(self.points[seg.point_index:], seg.kind, start_t, stop_t, pb)
  } else {
    let mut new_seg_index = seg_index
    while true {
      segment_to(self.points[seg.point_index:], seg.kind, start_t, 1.0, pb)
      let old_point_index = seg.point_index
      while true {
        new_seg_index += 1
        if self.segments[new_seg_index].point_index != old_point_index {
          break
        }
      }
      seg = self.segments[new_seg_index]
      start_t = 0.0
      if seg.point_index >= stop_seg.point_index {
        break
      }
    }
    segment_to(self.points[seg.point_index:], seg.kind, 0.0, stop_t, pb)
  }
}

///|
fn ContourMeasure::distance_to_segment(
  self : ContourMeasure,
  distance : Float,
) -> (Int, Float)? {
  let mut index = find_segment(self.segments, distance)
  // don't care if we hit an exact match or not, so we xor index if it is
  // negative
  index = index ^ (index >> 31)
  let seg = self.segments[index]

  // now interpolate t-values with the prev segment (if possible)
  let mut start_t : Float = 0.0
  let mut start_d : Float = 0.0
  // check if the prev segment is legal, and references the same set of points
  if index > 0 {
    start_d = self.segments[index - 1].distance
    if self.segments[index - 1].point_index == seg.point_index {
      start_t = self.segments[index - 1].scalar_t()
    }
  }
  let t = start_t +
    (seg.scalar_t() - start_t) * (distance - start_d) / (seg.distance - start_d)
  guard normalized_f32(t) is Some(t) else { return None }
  Some((index, t))
}

///|
fn ContourMeasure::compute_line_seg(
  self : ContourMeasure,
  p0 : Point,
  p1 : Point,
  distance : Float,
  point_index : Int,
) -> Float {
  let d = p0.distance(p1)
  let prev_d = distance
  let distance = distance + d
  if distance > prev_d {
    self.segments.push({
      distance,
      point_index,
      t_value: max_t_value,
      kind: SegmentType::Line,
    })
  }
  distance
}

///|
fn ContourMeasure::compute_quad_segs(
  self : ContourMeasure,
  p0 : Point,
  p1 : Point,
  p2 : Point,
  distance : Float,
  min_t : Int,
  max_t : Int,
  point_index : Int,
  tolerance : Float,
) -> Float {
  let mut distance = distance
  if t_span_big_enough(max_t - min_t) != 0 &&
    quad_too_curvy(p0, p1, p2, tolerance) {
    let tmp = Array::make(5, Point::zero())
    let half_t = (min_t + max_t) >> 1
    chop_quad_at([p0, p1, p2][:], normalized_f32_exclusive_half, tmp)
    distance = self.compute_quad_segs(
      tmp[0],
      tmp[1],
      tmp[2],
      distance,
      min_t,
      half_t,
      point_index,
      tolerance,
    )
    distance = self.compute_quad_segs(
      tmp[2],
      tmp[3],
      tmp[4],
      distance,
      half_t,
      max_t,
      point_index,
      tolerance,
    )
  } else {
    let d = p0.distance(p2)
    let prev_d = distance
    distance = distance + d
    if distance > prev_d {
      self.segments.push({
        distance,
        point_index,
        t_value: max_t,
        kind: SegmentType::Quad,
      })
    }
  }
  distance
}

///|
fn ContourMeasure::compute_cubic_segs(
  self : ContourMeasure,
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
  distance : Float,
  min_t : Int,
  max_t : Int,
  point_index : Int,
  tolerance : Float,
) -> Float {
  let mut distance = distance
  if t_span_big_enough(max_t - min_t) != 0 &&
    cubic_too_curvy(p0, p1, p2, p3, tolerance) {
    let tmp = Array::make(7, Point::zero())
    let half_t = (min_t + max_t) >> 1
    chop_cubic_at2([p0, p1, p2, p3][:], normalized_f32_exclusive_half, tmp, 0)
    distance = self.compute_cubic_segs(
      tmp[0],
      tmp[1],
      tmp[2],
      tmp[3],
      distance,
      min_t,
      half_t,
      point_index,
      tolerance,
    )
    distance = self.compute_cubic_segs(
      tmp[3],
      tmp[4],
      tmp[5],
      tmp[6],
      distance,
      half_t,
      max_t,
      point_index,
      tolerance,
    )
  } else {
    let d = p0.distance(p3)
    let prev_d = distance
    distance = distance + d
    if distance > prev_d {
      self.segments.push({
        distance,
        point_index,
        t_value: max_t,
        kind: SegmentType::Cubic,
      })
    }
  }
  distance
}

///|
fn find_segment(base : Array[Segment], key : Float) -> Int {
  let mut lo = 0
  let mut hi = base.length() - 1
  while lo < hi {
    let mid = (hi + lo) >> 1
    if base[mid].distance < key {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if base[hi].distance < key {
    hi += 1
    hi = hi.lnot()
  } else if key < base[hi].distance {
    hi = hi.lnot()
  }
  hi
}

///|
/// `compute_pos_tan` with only the position requested.
fn compute_pos(
  points : ArrayView[Point],
  seg_kind : SegmentType,
  t : Float,
) -> Point {
  match seg_kind {
    SegmentType::Line =>
      Point::from_xy(
        dash_interp(points[0].x, points[1].x, t),
        dash_interp(points[0].y, points[1].y, t),
      )
    SegmentType::Quad => eval_quad_at(points[0:3], t)
    SegmentType::Cubic => eval_cubic_pos_at(points[0:4], t)
  }
}

///|
fn segment_to(
  points : ArrayView[Point],
  seg_kind : SegmentType,
  start_t : Float,
  stop_t : Float,
  pb : PathBuilder,
) -> Unit {
  if start_t == stop_t {
    if pb.last_point() is Some(pt) {
      // If the dash as a zero-length on segment, add a corresponding
      // zero-length line. The stroke code will add end caps to zero length
      // lines as appropriate.
      pb.line_to(pt.x, pt.y)
    }
    return
  }
  match seg_kind {
    SegmentType::Line =>
      if stop_t == 1.0 {
        pb.line_to(points[1].x, points[1].y)
      } else {
        pb.line_to(
          dash_interp(points[0].x, points[1].x, stop_t),
          dash_interp(points[0].y, points[1].y, stop_t),
        )
      }
    SegmentType::Quad => {
      let tmp0 = Array::make(5, Point::zero())
      let tmp1 = Array::make(5, Point::zero())
      if start_t == 0.0 {
        if stop_t == 1.0 {
          pb.quad_to_pt(points[1], points[2])
        } else {
          let stop_t = normalized_f32_exclusive_bounded(stop_t)
          chop_quad_at(points, stop_t, tmp0)
          pb.quad_to_pt(tmp0[1], tmp0[2])
        }
      } else {
        let start_tt = normalized_f32_exclusive_bounded(start_t)
        chop_quad_at(points, start_tt, tmp0)
        if stop_t == 1.0 {
          pb.quad_to_pt(tmp0[3], tmp0[4])
        } else {
          let new_t = (stop_t - start_t) / ((1.0 : Float) - start_t)
          let new_t = normalized_f32_exclusive_bounded(new_t)
          chop_quad_at(tmp0[2:], new_t, tmp1)
          pb.quad_to_pt(tmp1[1], tmp1[2])
        }
      }
    }
    SegmentType::Cubic => {
      let tmp0 = Array::make(7, Point::zero())
      let tmp1 = Array::make(7, Point::zero())
      if start_t == 0.0 {
        if stop_t == 1.0 {
          pb.cubic_to_pt(points[1], points[2], points[3])
        } else {
          let stop_t = normalized_f32_exclusive_bounded(stop_t)
          chop_cubic_at2(points[0:4], stop_t, tmp0, 0)
          pb.cubic_to_pt(tmp0[1], tmp0[2], tmp0[3])
        }
      } else {
        let start_tt = normalized_f32_exclusive_bounded(start_t)
        chop_cubic_at2(points[0:4], start_tt, tmp0, 0)
        if stop_t == 1.0 {
          pb.cubic_to_pt(tmp0[4], tmp0[5], tmp0[6])
        } else {
          let new_t = (stop_t - start_t) / ((1.0 : Float) - start_t)
          let new_t = normalized_f32_exclusive_bounded(new_t)
          chop_cubic_at2(tmp0[3:7], new_t, tmp1, 0)
          pb.cubic_to_pt(tmp1[1], tmp1[2], tmp1[3])
        }
      }
    }
  }
}

///|
fn t_span_big_enough(t_span : Int) -> Int {
  t_span >> 10
}

///|
fn quad_too_curvy(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  tolerance : Float,
) -> Bool {
  // diff = (a/4 + b/2 + c/4) - (a/2 + c/2)
  // diff = -a/4 + b/2 - c/4
  let dx = half(p1.x) - half(half(p0.x + p2.x))
  let dy = half(p1.y) - half(half(p0.y + p2.y))
  let dist = fmax(fabs(dx), fabs(dy))
  dist > tolerance
}

///|
fn cubic_too_curvy(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
  tolerance : Float,
) -> Bool {
  let one_third : Float = (1.0 : Float) / 3.0
  let two_third : Float = (2.0 : Float) / 3.0
  let n0 = cheap_dist_exceeds_limit(
    p1,
    interp_safe(p0.x, p3.x, one_third),
    interp_safe(p0.y, p3.y, one_third),
    tolerance,
  )
  let n1 = cheap_dist_exceeds_limit(
    p2,
    interp_safe(p0.x, p3.x, two_third),
    interp_safe(p0.y, p3.y, two_third),
    tolerance,
  )
  n0 || n1
}

///|
fn cheap_dist_exceeds_limit(
  pt : Point,
  x : Float,
  y : Float,
  tolerance : Float,
) -> Bool {
  let dist = fmax(fabs(x - pt.x), fabs(y - pt.y))
  // just made up the 1/2
  dist > tolerance
}

///|
/// Linearly interpolate between A and B, based on t.
///
/// If t is 0, return A. If t is 1, return B else interpolate.
fn dash_interp(a : Float, b : Float, t : Float) -> Float {
  a + (b - a) * t
}

///|
fn interp_safe(a : Float, b : Float, t : Float) -> Float {
  a + (b - a) * t
}
