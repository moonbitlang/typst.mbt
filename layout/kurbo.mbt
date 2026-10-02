// The few pieces of the `kurbo` crate (0.13) used by the layout engine:
// cubic Bézier bounding boxes (`ParamCurveExtrema::bounding_box` of
// `CubicBez`) with `common::solve_quadratic`.

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
/// A rectangle (`kurbo::Rect`).
priv struct KRect {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
/// `Rect::from_points`.
fn KRect::from_points(p0 : (Double, Double), p1 : (Double, Double)) -> KRect {
  {
    x0: f64_min(p0.0, p1.0),
    y0: f64_min(p0.1, p1.1),
    x1: f64_max(p0.0, p1.0),
    y1: f64_max(p0.1, p1.1),
  }
}

///|
/// `Rect::union_pt`.
fn KRect::union_pt(self : KRect, pt : (Double, Double)) -> KRect {
  {
    x0: f64_min(self.x0, pt.0),
    y0: f64_min(self.y0, pt.1),
    x1: f64_max(self.x1, pt.0),
    y1: f64_max(self.y1, pt.1),
  }
}

///|
/// Find real roots of quadratic equation (`kurbo::common::solve_quadratic`).
///
/// The implementation is not as numerically robust as possible, but it does
/// handle the case where the leading coefficient is zero or near zero.
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
    // Likely, calculation of sc1 * sc1 overflowed. Find one root using
    // sc1 x + x² = 0, other root as sc0 / root1.
    -sc1
  } else {
    if arg < 0.0 {
      return result
    } else if arg == 0.0 {
      result.push(-0.5 * sc1)
      return result
    }
    // See https://math.stackexchange.com/questions/866331
    -0.5 * (sc1 + copysign(arg.sqrt(), sc1))
  }
  let root2 = sc0 / root1
  if f64_is_finite(root2) {
    // Sort just to be friendly and make results deterministic.
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
/// `f64::copysign`.
fn copysign(magnitude : Double, sign : Double) -> Double {
  let m = magnitude.reinterpret_as_uint64() & 0x7FFF_FFFF_FFFF_FFFFUL
  let s = sign.reinterpret_as_uint64() & 0x8000_0000_0000_0000UL
  (m | s).reinterpret_as_double()
}

///|
/// The smallest rectangle that encloses the cubic Bézier curve with the
/// given control points in the range (0..1) (`CubicBez::bounding_box`).
fn cubic_bounding_box(
  p0 : (Double, Double),
  p1 : (Double, Double),
  p2 : (Double, Double),
  p3 : (Double, Double),
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
  let d0 = (p1.0 - p0.0, p1.1 - p0.1)
  let d1 = (p2.0 - p1.0, p2.1 - p1.1)
  let d2 = (p3.0 - p2.0, p3.1 - p2.1)
  one_coord(d0.0, d1.0, d2.0)
  one_coord(d0.1, d1.1, d2.1)
  extrema.sort_by((a, b) => a.compare(b))

  // `CubicBez::eval`.
  let eval = (t : Double) => {
    let mt = 1.0 - t
    let coord = (a : Double, b : Double, c : Double, d : Double) => {
      a * (mt * mt * mt) +
      (b * (mt * mt * 3.0) + (c * (mt * 3.0) + d * t) * t) * t
    }
    (coord(p0.0, p1.0, p2.0, p3.0), coord(p0.1, p1.1, p2.1, p3.1))
  }
  let mut bbox = KRect::from_points(p0, p3)
  for t in extrema {
    bbox = bbox.union_pt(eval(t))
  }
  bbox
}

///|
/// `f64::is_finite`.
fn f64_is_finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}
