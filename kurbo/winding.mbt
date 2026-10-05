// Winding numbers (kurbo 0.13.1: `PathSeg::winding` in bezpath.rs,
// `solve_monotonic_for_y` in quadbez.rs and cubicbez.rs,
// `ParamCurveExtrema::extrema_ranges`, `Shape::contains`).

///|
fn min2(a : Double, b : Double) -> Double {
  if b < a {
    b
  } else {
    a
  }
}

///|
fn max2(a : Double, b : Double) -> Double {
  if b > a {
    b
  } else {
    a
  }
}

///|
/// Finds the value of `t` for which `self.eval(t)` is about `y`.
///
/// Assumes that this segment is monotonic in `y` and that it crosses
/// the height `y`. (Under these assumptions, there is a unique answer.)
fn QuadBez::solve_monotonic_for_y(self : QuadBez, y : Double) -> Double {
  let start = self.p0
  let end = self.p2
  let a = end.y - 2.0 * self.p1.y + start.y
  let b = 2.0 * (self.p1.y - start.y)
  let c = start.y - y
  for t in solve_quadratic(c, b, a) {
    if 0.0 <= t && t <= 1.0 {
      return t
    }
  }
  // Even though we asserted that our y range contains `y`, it's possible
  // that we failed to find a solution numerically. (For example, rounding
  // of a, b, or c might have pushed the root outside of [0.0, 1.0].)
  // If we failed to find a solution, the real solution should be close
  // to one of the endpoints. So just find whichever endpoint was closer.
  if (start.y - y).abs() <= (end.y - y).abs() {
    0.0
  } else {
    1.0
  }
}

///|
/// Finds the value of `t` for which `self.eval(t)` is about `y`.
///
/// Assumes that this segment is monotonic in `y` and that it crosses
/// the height `y`. (Under these assumptions, there is a unique answer.)
fn CubicBez::solve_monotonic_for_y(self : CubicBez, y : Double) -> Double {
  let start = self.p0
  let end = self.p3
  let p1 = self.p1
  let p2 = self.p2
  let a = end.y - 3.0 * p2.y + 3.0 * p1.y - start.y
  let b = 3.0 * (p2.y - 2.0 * p1.y + start.y)
  let c = 3.0 * (p1.y - start.y)
  let d = start.y - y
  for t in solve_cubic(d, c, b, a) {
    if 0.0 <= t && t <= 1.0 {
      return t
    }
  }
  // See `QuadBez::solve_monotonic_for_y`.
  if (start.y - y).abs() <= (end.y - y).abs() {
    0.0
  } else {
    1.0
  }
}

///|
/// Compute the winding number contribution of a single segment.
///
/// Assumes that this segment is monotonic in `y`. We consider `self` to
/// contain the endpoint with smaller y, and not contain the endpoint with
/// larger y, so that consecutive segments are handled correctly.
fn PathSeg::winding_inner(self : PathSeg, p : Point) -> Int {
  let start = self.start()
  let end = self.end()
  let sign = if end.y > start.y {
    if p.y < start.y || p.y >= end.y {
      return 0
    }
    -1
  } else if end.y < start.y {
    if p.y < end.y || p.y >= start.y {
      return 0
    }
    1
  } else {
    return 0
  }
  match self {
    Line(_) => {
      if p.x < min2(start.x, end.x) {
        return 0
      }
      if p.x >= max2(start.x, end.x) {
        return sign
      }
      // line equation ax + by = c
      let a = end.y - start.y
      let b = start.x - end.x
      let c = a * start.x + b * start.y
      if (a * p.x + b * p.y - c) * sign.to_double() <= 0.0 {
        sign
      } else {
        0
      }
    }
    Quad(quad) => {
      let p1 = quad.p1
      if p.x < min2(min2(start.x, end.x), p1.x) {
        return 0
      }
      if p.x >= max2(max2(start.x, end.x), p1.x) {
        return sign
      }
      let t = quad.solve_monotonic_for_y(p.y)
      let x = quad.eval(t).x
      if p.x >= x {
        sign
      } else {
        0
      }
    }
    Cubic(cubic) => {
      let p1 = cubic.p1
      let p2 = cubic.p2
      if p.x < min2(min2(min2(start.x, end.x), p1.x), p2.x) {
        return 0
      }
      if p.x >= max2(max2(max2(start.x, end.x), p1.x), p2.x) {
        return sign
      }
      let t = cubic.solve_monotonic_for_y(p.y)
      let x = cubic.eval(t).x
      if p.x >= x {
        sign
      } else {
        0
      }
    }
  }
}

///|
/// Compute the winding number contribution of a single segment.
///
/// Cast a ray to the left and count intersections.
pub fn PathSeg::winding(self : PathSeg, p : Point) -> Int {
  // `ParamCurveExtrema::extrema_ranges`: parameter ranges, each of which
  // is monotonic within the range.
  let mut sum = 0
  let mut t0 = 0.0
  for t in self.extrema() {
    sum += self.subsegment(t0, t).winding_inner(p)
    t0 = t
  }
  sum + self.subsegment(t0, 1.0).winding_inner(p)
}

///|
/// Winding number of point (`Shape::winding`).
pub fn BezPath::winding(self : BezPath, pt : Point) -> Int {
  let mut sum = 0
  for seg in self.segments() {
    sum += seg.winding(pt)
  }
  sum
}

///|
/// Returns `true` if the point is inside the path (`Shape::contains`: the
/// non-zero winding rule).
pub fn BezPath::contains(self : BezPath, pt : Point) -> Bool {
  self.winding(pt) != 0
}
