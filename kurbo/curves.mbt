// Port of `kurbo` 0.13 `line.rs`, `quadbez.rs` and `cubicbez.rs` (the parts
// used by hayro: evaluation, extrema and bounding boxes).

///|
/// A single line.
pub(all) struct Line {
  /// The line's start point.
  p0 : Point
  /// The line's end point.
  p1 : Point
} derive(Eq, Debug)

///|
/// Create a new line.
pub fn Line::new(p0 : Point, p1 : Point) -> Line {
  { p0, p1, }
}

///|
/// Evaluate the line at parameter `t`.
pub fn Line::eval(self : Line, t : Double) -> Point {
  self.p0.lerp(self.p1, t)
}

///|
/// A single quadratic Bézier segment.
pub(all) struct QuadBez {
  p0 : Point
  p1 : Point
  p2 : Point
} derive(Eq, Debug)

///|
/// Create a new quadratic Bézier segment.
pub fn QuadBez::new(p0 : Point, p1 : Point, p2 : Point) -> QuadBez {
  { p0, p1, p2, }
}

///|
/// Evaluate the curve at parameter `t`.
pub fn QuadBez::eval(self : QuadBez, t : Double) -> Point {
  let mt = 1.0 - t
  (self.p0.to_vec2().scale(mt * mt) +
  (self.p1.to_vec2().scale(mt * 2.0) + self.p2.to_vec2().scale(t)).scale(t)).to_point()
}

///|
/// Compute the extrema of the curve.
pub fn QuadBez::extrema(self : QuadBez) -> Array[Double] {
  let result = []
  let d0 = self.p1.sub(self.p0)
  let d1 = self.p2.sub(self.p1)
  let dd = d1 - d0
  if dd.x != 0.0 {
    let t = -d0.x / dd.x
    if t > 0.0 && t < 1.0 {
      result.push(t)
    }
  }
  if dd.y != 0.0 {
    let t = -d0.y / dd.y
    if t > 0.0 && t < 1.0 {
      result.push(t)
      if result.length() == 2 && result[0] > t {
        result.swap(0, 1)
      }
    }
  }
  result
}

///|
/// A single cubic Bézier segment.
pub(all) struct CubicBez {
  p0 : Point
  p1 : Point
  p2 : Point
  p3 : Point
} derive(Eq, Debug)

///|
/// Create a new cubic Bézier segment.
pub fn CubicBez::new(
  p0 : Point,
  p1 : Point,
  p2 : Point,
  p3 : Point,
) -> CubicBez {
  { p0, p1, p2, p3, }
}

///|
/// Evaluate the curve at parameter `t`.
pub fn CubicBez::eval(self : CubicBez, t : Double) -> Point {
  let mt = 1.0 - t
  let v = self.p0.to_vec2().scale(mt * mt * mt) +
    (self.p1.to_vec2().scale(mt * mt * 3.0) +
    (self.p2.to_vec2().scale(mt * 3.0) + self.p3.to_vec2().scale(t)).scale(t)).scale(
      t,
    )
  v.to_point()
}

///|
/// `Affine * CubicBez`.
pub fn CubicBez::transform(self : CubicBez, t : Affine) -> CubicBez {
  {
    p0: t.apply(self.p0),
    p1: t.apply(self.p1),
    p2: t.apply(self.p2),
    p3: t.apply(self.p3),
  }
}

///|
/// Compute the extrema of the curve.
pub fn CubicBez::extrema(self : CubicBez) -> Array[Double] {
  let result = []
  fn one_coord(result : Array[Double], d0 : Double, d1 : Double, d2 : Double) {
    let a = d0 - 2.0 * d1 + d2
    let b = 2.0 * (d1 - d0)
    let c = d0
    let roots = solve_quadratic(c, b, a)
    for t in roots {
      if t > 0.0 && t < 1.0 {
        result.push(t)
      }
    }
  }

  let d0 = self.p1.sub(self.p0)
  let d1 = self.p2.sub(self.p1)
  let d2 = self.p3.sub(self.p2)
  one_coord(result, d0.x, d1.x, d2.x)
  one_coord(result, d0.y, d1.y, d2.y)
  // Insertion sort (stable; the values are never NaN).
  for i in 1..<result.length() {
    let mut j = i
    while j > 0 && result[j - 1] > result[j] {
      result.swap(j - 1, j)
      j -= 1
    }
  }
  result
}

///|
/// The smallest rectangle that encloses the curve
/// (`ParamCurveExtrema::bounding_box`).
pub fn CubicBez::bounding_box(self : CubicBez) -> Rect {
  let mut bbox = Rect::from_points(self.p0, self.p3)
  for t in self.extrema() {
    bbox = bbox.union_pt(self.eval(t))
  }
  bbox
}
