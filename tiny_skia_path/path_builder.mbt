// Port of `tiny-skia-path` 0.12.0 `src/path_builder.rs`.
//
// NOTE: this is not SkPathBuilder, but rather a reimplementation of SkPath.

///|
priv enum PathDirection {
  /// Clockwise direction for adding closed contours.
  CW
  /// Counter-clockwise direction for adding closed contours.
  CCW
} derive(Eq)

///|
/// A path builder.
pub struct PathBuilder {
  priv mut verbs : Array[PathVerb]
  priv mut points : Array[Point]
  priv mut last_move_to_index : Int
  priv mut move_to_required : Bool
} derive(Debug)

///|
/// Same as upstream's `#[derive(Default)]` (note: `move_to_required` is
/// `false` here, unlike `PathBuilder::new`).
pub impl Default for PathBuilder with fn default() {
  { verbs: [], points: [], last_move_to_index: 0, move_to_required: false, }
}

///|
/// Creates a deep copy of the builder (`Clone`).
pub fn PathBuilder::clone(self : PathBuilder) -> PathBuilder {
  {
    verbs: self.verbs.copy(),
    points: self.points.copy(),
    last_move_to_index: self.last_move_to_index,
    move_to_required: self.move_to_required,
  }
}

///|
/// Creates a new builder.
pub fn PathBuilder::new() -> PathBuilder {
  { verbs: [], points: [], last_move_to_index: 0, move_to_required: true, }
}

///|
/// Creates a new builder with a specified capacity.
///
/// Number of points depends on a verb type:
///
/// - Move - 1
/// - Line - 1
/// - Quad - 2
/// - Cubic - 3
/// - Close - 0
pub fn PathBuilder::with_capacity(
  verbs_capacity : Int,
  points_capacity : Int,
) -> PathBuilder {
  {
    verbs: Array(capacity=verbs_capacity),
    points: Array(capacity=points_capacity),
    last_move_to_index: 0,
    move_to_required: true,
  }
}

///|
/// Creates a new `Path` from `Rect`.
///
/// Never fails since `Rect` is always valid.
///
/// Segments are created clockwise: TopLeft -> TopRight -> BottomRight ->
/// BottomLeft
///
/// The contour is closed.
pub fn PathBuilder::from_rect(rect : Rect) -> Path {
  let verbs : Array[PathVerb] = [Move, Line, Line, Line, Close]
  let points = [
    Point::from_xy(rect.left(), rect.top()),
    Point::from_xy(rect.right(), rect.top()),
    Point::from_xy(rect.right(), rect.bottom()),
    Point::from_xy(rect.left(), rect.bottom()),
  ]
  { bounds: rect, verbs, points, }
}

///|
/// Creates a new `Path` from a circle.
///
/// See [`PathBuilder::push_circle`] for details.
pub fn PathBuilder::from_circle(
  cx : Float,
  cy : Float,
  radius : Float,
) -> Path? {
  let b = PathBuilder::new()
  b.push_circle(cx, cy, radius)
  b.finish()
}

///|
/// Creates a new `Path` from an oval.
///
/// See [`PathBuilder::push_oval`] for details.
pub fn PathBuilder::from_oval(oval : Rect) -> Path? {
  let b = PathBuilder::new()
  b.push_oval(oval)
  b.finish()
}

///|
/// Returns the current number of segments in the builder.
pub fn PathBuilder::len(self : PathBuilder) -> Int {
  self.verbs.length()
}

///|
/// Checks if the builder has any segments added.
pub fn PathBuilder::is_empty(self : PathBuilder) -> Bool {
  self.verbs.is_empty()
}

///|
/// Adds beginning of a contour.
///
/// Multiple continuous MoveTo segments are not allowed.
/// If the previous segment was also MoveTo, it will be overwritten with the
/// current one.
pub fn PathBuilder::move_to(self : PathBuilder, x : Float, y : Float) -> Unit {
  if self.verbs.last() is Some(Move) {
    let last_idx = self.points.length() - 1
    self.points[last_idx] = Point::from_xy(x, y)
  } else {
    self.last_move_to_index = self.points.length()
    self.move_to_required = false
    self.verbs.push(Move)
    self.points.push(Point::from_xy(x, y))
  }
}

///|
fn PathBuilder::inject_move_to_if_needed(self : PathBuilder) -> Unit {
  if self.move_to_required {
    match self.points.get(self.last_move_to_index) {
      Some(p) => self.move_to(p.x, p.y)
      None => self.move_to(0.0, 0.0)
    }
  }
}

///|
/// Adds a line from the last point.
///
/// - If `Path` is empty - adds Move(0, 0) first.
/// - If `Path` ends with Close - adds Move(last_x, last_y) first.
pub fn PathBuilder::line_to(self : PathBuilder, x : Float, y : Float) -> Unit {
  self.inject_move_to_if_needed()
  self.verbs.push(Line)
  self.points.push(Point::from_xy(x, y))
}

///|
/// Adds a quad curve from the last point to `x`, `y`.
///
/// - If `Path` is empty - adds Move(0, 0) first.
/// - If `Path` ends with Close - adds Move(last_x, last_y) first.
pub fn PathBuilder::quad_to(
  self : PathBuilder,
  x1 : Float,
  y1 : Float,
  x : Float,
  y : Float,
) -> Unit {
  self.inject_move_to_if_needed()
  self.verbs.push(Quad)
  self.points.push(Point::from_xy(x1, y1))
  self.points.push(Point::from_xy(x, y))
}

///|
fn PathBuilder::quad_to_pt(self : PathBuilder, p1 : Point, p : Point) -> Unit {
  self.quad_to(p1.x, p1.y, p.x, p.y)
}

///|
// We do not support conic segments, but Skia still relies on them from time
// to time. This method will simply convert the input data into quad segments.
fn PathBuilder::conic_to(
  self : PathBuilder,
  x1 : Float,
  y1 : Float,
  x : Float,
  y : Float,
  weight : Float,
) -> Unit {
  // check for <= 0 or NaN with this test
  if !(weight > 0.0) {
    self.line_to(x, y)
  } else if !is_finite(weight) {
    self.line_to(x1, y1)
    self.line_to(x, y)
  } else if weight == 1.0 {
    self.quad_to(x1, y1, x, y)
  } else {
    self.inject_move_to_if_needed()
    let last = self.last_point().unwrap()
    let quadder = AutoConicToQuads::compute(
      last,
      Point::from_xy(x1, y1),
      Point::from_xy(x, y),
      weight,
    )
    if quadder is Some(quadder) {
      // Points are ordered as: 0 - 1 2 - 3 4 - 5 6 - ..
      // `count` is a number of pairs +1
      let mut offset = 1
      for _ in 0..<quadder.len {
        let pt1 = quadder.points[offset + 0]
        let pt2 = quadder.points[offset + 1]
        self.quad_to(pt1.x, pt1.y, pt2.x, pt2.y)
        offset += 2
      }
    }
  }
}

///|
fn PathBuilder::conic_points_to(
  self : PathBuilder,
  pt1 : Point,
  pt2 : Point,
  weight : Float,
) -> Unit {
  self.conic_to(pt1.x, pt1.y, pt2.x, pt2.y, weight)
}

///|
/// Adds a cubic curve from the last point to `x`, `y`.
///
/// - If `Path` is empty - adds Move(0, 0) first.
/// - If `Path` ends with Close - adds Move(last_x, last_y) first.
pub fn PathBuilder::cubic_to(
  self : PathBuilder,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  x : Float,
  y : Float,
) -> Unit {
  self.inject_move_to_if_needed()
  self.verbs.push(Cubic)
  self.points.push(Point::from_xy(x1, y1))
  self.points.push(Point::from_xy(x2, y2))
  self.points.push(Point::from_xy(x, y))
}

///|
fn PathBuilder::cubic_to_pt(
  self : PathBuilder,
  p1 : Point,
  p2 : Point,
  p : Point,
) -> Unit {
  self.cubic_to(p1.x, p1.y, p2.x, p2.y, p.x, p.y)
}

///|
/// Closes the current contour.
///
/// A closed contour connects the first and the last Point
/// with a line, forming a continuous loop.
///
/// Does nothing when `Path` is empty or already closed.
///
/// Open and closed contour will be filled the same way.
/// Stroking an open contour will add LineCap at contour's start and end.
/// Stroking an closed contour will add LineJoin at contour's start and end.
pub fn PathBuilder::close(self : PathBuilder) -> Unit {
  // don't add a close if it's the first verb or a repeat
  if !self.verbs.is_empty() {
    if !(self.verbs.last() is Some(Close)) {
      self.verbs.push(Close)
    }
  }
  self.move_to_required = true
}

///|
/// Returns the last point if any.
pub fn PathBuilder::last_point(self : PathBuilder) -> Point? {
  self.points.last()
}

///|
fn PathBuilder::set_last_point(self : PathBuilder, pt : Point) -> Unit {
  if self.points.is_empty() {
    self.move_to(pt.x, pt.y)
  } else {
    self.points[self.points.length() - 1] = pt
  }
}

///|
fn PathBuilder::is_zero_length_since_point(
  self : PathBuilder,
  start_pt_index : Int,
) -> Bool {
  let count = self.points.length() - start_pt_index
  if count < 2 {
    return true
  }
  let first = self.points[start_pt_index]
  for i in 1..<count {
    if first != self.points[start_pt_index + i] {
      return false
    }
  }
  true
}

///|
/// Adds a rectangle contour.
///
/// The contour is closed and has a clock-wise direction.
pub fn PathBuilder::push_rect(self : PathBuilder, rect : Rect) -> Unit {
  self.move_to(rect.left(), rect.top())
  self.line_to(rect.right(), rect.top())
  self.line_to(rect.right(), rect.bottom())
  self.line_to(rect.left(), rect.bottom())
  self.close()
}

///|
/// Adds an oval contour bounded by the provided rectangle.
///
/// The contour is closed and has a clock-wise direction.
pub fn PathBuilder::push_oval(self : PathBuilder, oval : Rect) -> Unit {
  let cx = half(oval.left()) + half(oval.right())
  let cy = half(oval.top()) + half(oval.bottom())
  let oval_points : ReadOnlyArray[_] = [
    Point::from_xy(cx, oval.bottom()),
    Point::from_xy(oval.left(), cy),
    Point::from_xy(cx, oval.top()),
    Point::from_xy(oval.right(), cy),
  ]
  let rect_points : ReadOnlyArray[_] = [
    Point::from_xy(oval.right(), oval.bottom()),
    Point::from_xy(oval.left(), oval.bottom()),
    Point::from_xy(oval.left(), oval.top()),
    Point::from_xy(oval.right(), oval.top()),
  ]
  let weight = scalar_root_2_over_2
  self.move_to(oval_points[3].x, oval_points[3].y)
  for i in 0..<4 {
    self.conic_points_to(rect_points[i], oval_points[i], weight)
  }
  self.close()
}

///|
/// Adds a circle contour.
///
/// The contour is closed and has a clock-wise direction.
///
/// Does nothing when:
/// - `radius` <= 0
/// - any value is not finite or really large
pub fn PathBuilder::push_circle(
  self : PathBuilder,
  x : Float,
  y : Float,
  r : Float,
) -> Unit {
  if Rect::from_xywh(x - r, y - r, r + r, r + r) is Some(r) {
    self.push_oval(r)
  }
}

///|
/// Adds a path.
pub fn PathBuilder::push_path(self : PathBuilder, other : Path) -> Unit {
  self.last_move_to_index = self.points.length()
  self.verbs.push_iter(other.verbs.iter())
  self.points.push_iter(other.points.iter())
}

///|
fn PathBuilder::push_path_builder(
  self : PathBuilder,
  other : PathBuilder,
) -> Unit {
  if other.is_empty() {
    return
  }
  if self.last_move_to_index != 0 {
    self.last_move_to_index = self.points.length() + other.last_move_to_index
  }
  self.verbs.push_iter(other.verbs.iter())
  self.points.push_iter(other.points.iter())
}

///|
/// Appends, in a reverse order, the first contour of path ignoring path's
/// last point.
fn PathBuilder::reverse_path_to(
  self : PathBuilder,
  other : PathBuilder,
) -> Unit {
  if other.is_empty() {
    return
  }
  let mut points_offset = other.points.length() - 1
  for i = other.verbs.length() - 1; i >= 0; i = i - 1 {
    match other.verbs[i] {
      Move =>
        // if the path has multiple contours, stop after reversing the last
        break
      Line => {
        // We're moving one point back manually, to prevent points_offset overflow.
        let pt = other.points[points_offset - 1]
        points_offset -= 1
        self.line_to(pt.x, pt.y)
      }
      Quad => {
        let pt1 = other.points[points_offset - 1]
        let pt2 = other.points[points_offset - 2]
        points_offset -= 2
        self.quad_to(pt1.x, pt1.y, pt2.x, pt2.y)
      }
      Cubic => {
        let pt1 = other.points[points_offset - 1]
        let pt2 = other.points[points_offset - 2]
        let pt3 = other.points[points_offset - 3]
        points_offset -= 3
        self.cubic_to(pt1.x, pt1.y, pt2.x, pt2.y, pt3.x, pt3.y)
      }
      Close => ()
    }
  }
}

///|
/// Reset the builder.
pub fn PathBuilder::clear(self : PathBuilder) -> Unit {
  self.verbs.clear()
  self.points.clear()
  self.last_move_to_index = 0
  self.move_to_required = true
}

///|
/// Finishes the builder and returns a `Path`.
///
/// Returns `None` when `Path` is empty or has invalid bounds.
///
/// Upstream consumes the builder; here the builder is left empty (as after
/// `clear`) and the resulting path owns the storage.
pub fn PathBuilder::finish(self : PathBuilder) -> Path? {
  if self.is_empty() {
    return None
  }

  // Just a move to? Bail.
  if self.verbs.length() == 1 {
    return None
  }
  guard Rect::from_points(self.points[:]) is Some(bounds) else { return None }
  let path = { bounds, verbs: self.verbs, points: self.points, }
  self.verbs = []
  self.points = []
  self.last_move_to_index = 0
  self.move_to_required = true
  Some(path)
}
