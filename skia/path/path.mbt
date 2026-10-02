// Port of `tiny-skia-path/src/path.rs`.

///|
/// A path verb.
pub(all) enum PathVerb {
  Move
  Line
  Quad
  Cubic
  Close
} derive(Eq, Debug)

///|
/// A Bezier path.
///
/// Can be created via [`PathBuilder`]. Where [`PathBuilder`] can be
/// retrieved via [`Path::clear`].
///
/// # Guarantees
///
/// - Has a valid, precomputed bounds.
/// - All points are finite.
/// - Has at least two segments.
/// - Each contour starts with a MoveTo.
/// - No duplicated Move.
/// - No duplicated Close.
/// - Zero-length contours are allowed.
pub struct Path {
  verbs : Array[PathVerb]
  points : Array[Point]
  bounds : Rect
} derive(Eq)

///|
/// Returns the number of segments in the path.
pub fn Path::len(self : Path) -> Int {
  self.verbs.length()
}

///|
/// Return if the path is empty.
pub fn Path::is_empty(self : Path) -> Bool {
  self.verbs.is_empty()
}

///|
/// Returns the bounds of the path's points.
///
/// The value is already calculated.
pub fn Path::bounds(self : Path) -> Rect {
  self.bounds
}

///|
/// Calculates path's tight bounds.
///
/// This operation can be expensive.
pub fn Path::compute_tight_bounds(self : Path) -> Rect? {
  // big enough to hold worst-case curve type (cubic) extremas + 1
  let extremas = Array::make(5, Point::zero())
  let mut min = self.points[0]
  let mut max = self.points[0]
  let iter = self.segments()
  let mut last_point = Point::zero()
  while iter.next() is Some(segment) {
    let mut count = 0
    match segment {
      MoveTo(p) => {
        extremas[0] = p
        count = 1
      }
      LineTo(p) => {
        extremas[0] = p
        count = 1
      }
      QuadTo(p0, p1) =>
        count = compute_quad_extremas(last_point, p0, p1, extremas)
      CubicTo(p0, p1, p2) =>
        count = compute_cubic_extremas(last_point, p0, p1, p2, extremas)
      Close => ()
    }
    last_point = iter.last_point
    for i in 0..<count {
      let tmp = extremas[i]
      min = { x: fmin(min.x, tmp.x), y: fmin(min.y, tmp.y), }
      max = { x: fmax(max.x, tmp.x), y: fmax(max.y, tmp.y), }
    }
  }
  Rect::from_ltrb(min.x, min.y, max.x, max.y)
}

///|
/// Returns an internal vector of verbs.
pub fn Path::verbs(self : Path) -> Array[PathVerb] {
  self.verbs
}

///|
/// Returns an internal vector of points.
pub fn Path::points(self : Path) -> Array[Point] {
  self.points
}

///|
/// Returns a transformed in-place path.
///
/// Some points may become NaN/inf therefore this method can fail.
pub fn Path::transform(self : Path, ts : Transform) -> Path? {
  if ts.is_identity() {
    return Some(self)
  }
  let points = self.points.copy()
  ts.map_points(points)

  // Update bounds.
  guard Rect::from_points(points[:]) is Some(bounds) else { return None }
  Some({ verbs: self.verbs, points, bounds, })
}

///|
/// Returns an iterator over path's segments.
pub fn Path::segments(self : Path) -> PathSegmentsIter {
  {
    path: self,
    verb_index: 0,
    points_index: 0,
    is_auto_close: false,
    last_move_to: Point::zero(),
    last_point: Point::zero(),
  }
}

///|
/// Clears the path and returns a `PathBuilder` that will reuse an allocated
/// memory.
pub fn Path::clear(self : Path) -> PathBuilder {
  ignore(self)
  PathBuilder::new()
}

///|
/// Formats the path like upstream's `Debug` impl (segments only).
pub fn Path::to_svg_like(self : Path) -> String {
  let s = StringBuilder()
  for segment in self.segments().to_array() {
    match segment {
      MoveTo(p) => s.write_string("M \{p.x} \{p.y} ")
      LineTo(p) => s.write_string("L \{p.x} \{p.y} ")
      QuadTo(p0, p1) => s.write_string("Q \{p0.x} \{p0.y} \{p1.x} \{p1.y} ")
      CubicTo(p0, p1, p2) =>
        s.write_string("C \{p0.x} \{p0.y} \{p1.x} \{p1.y} \{p2.x} \{p2.y} ")
      Close => s.write_string("Z ")
    }
  }
  let s = s.to_string()
  if s.length() > 0 {
    s.substring(end=s.length() - 1)
  } else {
    s
  }
}

///|
fn compute_quad_extremas(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  extremas : Array[Point],
) -> Int {
  let src = [p0, p1, p2]
  let mut extrema_idx = 0
  if find_quad_extrema(p0.x, p1.x, p2.x) is Some(t) {
    extremas[extrema_idx] = eval_quad_at(src, t)
    extrema_idx += 1
  }
  if find_quad_extrema(p0.y, p1.y, p2.y) is Some(t) {
    extremas[extrema_idx] = eval_quad_at(src, t)
    extrema_idx += 1
  }
  extremas[extrema_idx] = p2
  extrema_idx + 1
}

///|
fn compute_cubic_extremas(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
  extremas : Array[Point],
) -> Int {
  let ts0 = new_t_values()
  let ts1 = new_t_values()
  let n0 = find_cubic_extrema(p0.x, p1.x, p2.x, p3.x, ts0)
  let n1 = find_cubic_extrema(p0.y, p1.y, p2.y, p3.y, ts1)
  let total_len = n0 + n1
  let src = [p0, p1, p2, p3]
  let mut extrema_idx = 0
  for i in 0..<n0 {
    extremas[extrema_idx] = eval_cubic_pos_at(src, ts0[i])
    extrema_idx += 1
  }
  for i in 0..<n1 {
    extremas[extrema_idx] = eval_cubic_pos_at(src, ts1[i])
    extrema_idx += 1
  }
  extremas[total_len] = p3
  total_len + 1
}

///|
/// A path segment.
pub(all) enum PathSegment {
  MoveTo(Point)
  LineTo(Point)
  QuadTo(Point, Point)
  CubicTo(Point, Point, Point)
  Close
} derive(Eq, Debug)

///|
/// A path segments iterator.
pub struct PathSegmentsIter {
  path : Path
  mut verb_index : Int
  mut points_index : Int
  mut is_auto_close : Bool
  mut last_move_to : Point
  mut last_point : Point
}

///|
/// Returns a copy of the iterator state.
pub fn PathSegmentsIter::clone(self : PathSegmentsIter) -> PathSegmentsIter {
  { ..self, }
}

///|
/// Sets the auto closing mode. Off by default.
///
/// When enabled, emits an additional `PathSegment::Line` from the current
/// position to the previous `PathSegment::Move`. And only then emits
/// `PathSegment::Close`.
pub fn PathSegmentsIter::set_auto_close(
  self : PathSegmentsIter,
  flag : Bool,
) -> Unit {
  self.is_auto_close = flag
}

///|
pub fn PathSegmentsIter::last_point(self : PathSegmentsIter) -> Point {
  self.last_point
}

///|
pub fn PathSegmentsIter::last_move_to(self : PathSegmentsIter) -> Point {
  self.last_move_to
}

///|
fn PathSegmentsIter::auto_close(self : PathSegmentsIter) -> PathSegment {
  if self.is_auto_close && self.last_point != self.last_move_to {
    self.verb_index -= 1
    LineTo(self.last_move_to)
  } else {
    Close
  }
}

///|
pub fn PathSegmentsIter::has_valid_tangent(self : PathSegmentsIter) -> Bool {
  let iter = self.clone()
  while iter.next() is Some(segment) {
    match segment {
      MoveTo(_) => return false
      LineTo(p) => {
        if iter.last_point == p {
          continue
        }
        return true
      }
      QuadTo(p1, p2) => {
        if iter.last_point == p1 && iter.last_point == p2 {
          continue
        }
        return true
      }
      CubicTo(p1, p2, p3) => {
        if iter.last_point == p1 &&
          iter.last_point == p2 &&
          iter.last_point == p3 {
          continue
        }
        return true
      }
      Close => return false
    }
  }
  false
}

///|
/// Returns the current verb.
pub fn PathSegmentsIter::curr_verb(self : PathSegmentsIter) -> PathVerb {
  self.path.verbs[self.verb_index - 1]
}

///|
/// Returns the next verb.
pub fn PathSegmentsIter::next_verb(self : PathSegmentsIter) -> PathVerb? {
  self.path.verbs.get(self.verb_index)
}

///|
pub fn PathSegmentsIter::next(self : PathSegmentsIter) -> PathSegment? {
  if self.verb_index < self.path.verbs.length() {
    let verb = self.path.verbs[self.verb_index]
    self.verb_index += 1
    match verb {
      Move => {
        self.points_index += 1
        self.last_move_to = self.path.points[self.points_index - 1]
        self.last_point = self.last_move_to
        Some(MoveTo(self.last_move_to))
      }
      Line => {
        self.points_index += 1
        self.last_point = self.path.points[self.points_index - 1]
        Some(LineTo(self.last_point))
      }
      Quad => {
        self.points_index += 2
        self.last_point = self.path.points[self.points_index - 1]
        Some(QuadTo(self.path.points[self.points_index - 2], self.last_point))
      }
      Cubic => {
        self.points_index += 3
        self.last_point = self.path.points[self.points_index - 1]
        Some(
          CubicTo(
            self.path.points[self.points_index - 3],
            self.path.points[self.points_index - 2],
            self.last_point,
          ),
        )
      }
      Close => {
        let seg = self.auto_close()
        self.last_point = self.last_move_to
        Some(seg)
      }
    }
  } else {
    None
  }
}

///|
/// Collects the remaining segments.
pub fn PathSegmentsIter::to_array(
  self : PathSegmentsIter,
) -> Array[PathSegment] {
  let out = []
  while self.next() is Some(s) {
    out.push(s)
  }
  out
}
