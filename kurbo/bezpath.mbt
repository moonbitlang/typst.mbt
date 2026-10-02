// Port of `kurbo` 0.13 `bezpath.rs` (the parts used by hayro).

///|
/// The element of a Bézier path.
pub(all) enum PathEl {
  /// Move directly to the point without drawing anything, starting a new
  /// subpath.
  MoveTo(Point)
  /// Draw a line from the current location to the point.
  LineTo(Point)
  /// Draw a quadratic bezier using the current location and the two points.
  QuadTo(Point, Point)
  /// Draw a cubic bezier using the current location and the three points.
  CurveTo(Point, Point, Point)
  /// Close off the path.
  ClosePath
} derive(Eq, Debug)

///|
/// Is this path element finite?
pub fn PathEl::is_finite(self : PathEl) -> Bool {
  match self {
    MoveTo(p) => p.is_finite()
    LineTo(p) => p.is_finite()
    QuadTo(p, p2) => p.is_finite() && p2.is_finite()
    CurveTo(p, p2, p3) => p.is_finite() && p2.is_finite() && p3.is_finite()
    ClosePath => true
  }
}

///|
/// `Affine * PathEl`.
pub fn PathEl::transform(self : PathEl, t : Affine) -> PathEl {
  match self {
    MoveTo(p) => MoveTo(t.apply(p))
    LineTo(p) => LineTo(t.apply(p))
    QuadTo(p1, p2) => QuadTo(t.apply(p1), t.apply(p2))
    CurveTo(p1, p2, p3) => CurveTo(t.apply(p1), t.apply(p2), t.apply(p3))
    ClosePath => ClosePath
  }
}

///|
/// A Bézier path.
pub struct BezPath {
  priv elements : Array[PathEl]
} derive(Eq, Debug)

///|
/// Create a new path.
pub fn BezPath::new() -> BezPath {
  { elements: [], }
}

///|
/// Create a path from a vector of path elements.
pub fn BezPath::from_vec(v : Array[PathEl]) -> BezPath {
  { elements: v, }
}

///|
/// Push a generic path element onto the path.
pub fn BezPath::push(self : BezPath, el : PathEl) -> Unit {
  self.elements.push(el)
}

///|
/// Push a "move to" element onto the path.
pub fn BezPath::move_to(self : BezPath, p : Point) -> Unit {
  self.push(MoveTo(p))
}

///|
/// Push a "line to" element onto the path.
pub fn BezPath::line_to(self : BezPath, p : Point) -> Unit {
  self.push(LineTo(p))
}

///|
/// Push a "quad to" element onto the path.
pub fn BezPath::quad_to(self : BezPath, p1 : Point, p2 : Point) -> Unit {
  self.push(QuadTo(p1, p2))
}

///|
/// Push a "curve to" element onto the path.
pub fn BezPath::curve_to(
  self : BezPath,
  p1 : Point,
  p2 : Point,
  p3 : Point,
) -> Unit {
  self.push(CurveTo(p1, p2, p3))
}

///|
/// Push a "close path" element onto the path.
pub fn BezPath::close_path(self : BezPath) -> Unit {
  self.push(ClosePath)
}

///|
/// Get the path elements.
pub fn BezPath::elements(self : BezPath) -> Array[PathEl] {
  self.elements
}

///|
/// Returns `true` if the path contains no segments.
pub fn BezPath::is_empty(self : BezPath) -> Bool {
  self.elements.iter().all(el => el is (MoveTo(_) | ClosePath))
}

///|
/// Shorten the path, keeping the first `len` elements.
pub fn BezPath::truncate(self : BezPath, len : Int) -> Unit {
  if len < self.elements.length() {
    self.elements.truncate(len)
  }
}

///|
/// Append the elements of another path (`Extend<PathEl>`).
pub fn BezPath::extend_path(self : BezPath, other : BezPath) -> Unit {
  for el in other.elements {
    self.elements.push(el)
  }
}

///|
/// Clone the path.
pub fn BezPath::clone(self : BezPath) -> BezPath {
  { elements: self.elements.copy(), }
}

///|
/// `Affine * BezPath`.
pub fn BezPath::transform(self : BezPath, t : Affine) -> BezPath {
  { elements: self.elements.map(el => el.transform(t)), }
}

///|
/// Iterate over the path segments.
pub fn BezPath::segments(self : BezPath) -> Array[PathSeg] {
  segments(self.elements)
}

///|
/// The smallest rectangle that encloses the path (`Shape::bounding_box`).
pub fn BezPath::bounding_box(self : BezPath) -> Rect {
  let mut bbox : Rect? = None
  for seg in self.segments() {
    let seg_bb = seg.bounding_box()
    bbox = match bbox {
      Some(bb) => Some(bb.union(seg_bb))
      None => Some(seg_bb)
    }
  }
  bbox.unwrap_or(rect_zero)
}

///|
/// A segment of a Bézier path.
pub(all) enum PathSeg {
  /// A line segment.
  Line(Line)
  /// A quadratic bezier segment.
  Quad(QuadBez)
  /// A cubic bezier segment.
  Cubic(CubicBez)
} derive(Eq, Debug)

///|
/// Transform path elements into path segments.
///
/// Like upstream, panics (aborts) if the elements start with a `ClosePath`.
pub fn segments(elements : Array[PathEl]) -> Array[PathSeg] {
  let result = []
  let mut start_last : (Point, Point)? = None
  for el in elements {
    let (start, last) = match start_last {
      Some(sl) => sl
      None => {
        let point = match el {
          MoveTo(p) => p
          LineTo(p) => p
          QuadTo(_, p2) => p2
          CurveTo(_, _, p3) => p3
          ClosePath => abort("Can't start a segment on a ClosePath")
        }
        (point, point)
      }
    }
    match el {
      MoveTo(p) => start_last = Some((p, p))
      LineTo(p) => {
        result.push(PathSeg::Line(Line::new(last, p)))
        start_last = Some((start, p))
      }
      QuadTo(p1, p2) => {
        result.push(PathSeg::Quad(QuadBez::new(last, p1, p2)))
        start_last = Some((start, p2))
      }
      CurveTo(p1, p2, p3) => {
        result.push(PathSeg::Cubic(CubicBez::new(last, p1, p2, p3)))
        start_last = Some((start, p3))
      }
      ClosePath =>
        if last != start {
          result.push(PathSeg::Line(Line::new(last, start)))
          start_last = Some((start, start))
        } else {
          start_last = Some((start, last))
        }
    }
  }
  result
}

///|
/// Evaluate the segment at parameter `t`.
pub fn PathSeg::eval(self : PathSeg, t : Double) -> Point {
  match self {
    Line(line) => line.eval(t)
    Quad(quad) => quad.eval(t)
    Cubic(cubic) => cubic.eval(t)
  }
}

///|
/// The start point.
pub fn PathSeg::start(self : PathSeg) -> Point {
  match self {
    Line(line) => line.p0
    Quad(quad) => quad.p0
    Cubic(cubic) => cubic.p0
  }
}

///|
/// The end point.
pub fn PathSeg::end(self : PathSeg) -> Point {
  match self {
    Line(line) => line.p1
    Quad(quad) => quad.p2
    Cubic(cubic) => cubic.p3
  }
}

///|
/// Compute the extrema of the curve.
pub fn PathSeg::extrema(self : PathSeg) -> Array[Double] {
  match self {
    Line(_) => []
    Quad(quad) => quad.extrema()
    Cubic(cubic) => cubic.extrema()
  }
}

///|
/// The smallest rectangle that encloses the segment
/// (`ParamCurveExtrema::bounding_box`).
pub fn PathSeg::bounding_box(self : PathSeg) -> Rect {
  let mut bbox = Rect::from_points(self.start(), self.end())
  for t in self.extrema() {
    bbox = bbox.union_pt(self.eval(t))
  }
  bbox
}
