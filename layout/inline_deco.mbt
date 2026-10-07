// Port of `typst-layout/src/inline/deco.rs`, including the parts of kurbo
// it uses (`BezPath` segments and `PathSeg::intersect_line`).

///|
/// Add line decorations to a single run of shaped text.
fn decorate(
  frame : @library.Frame,
  deco : @library.Decoration,
  text : @library.TextItem,
  width : @library.Abs,
  shift : @library.Abs,
  pos : @library.Point,
) -> Unit {
  let font_metrics = text.font.metrics()
  if deco.line is Highlight(fill~, stroke~, top_edge~, bottom_edge~, radius~) {
    let (top, bottom) = determine_edges(text, top_edge, bottom_edge)
    let size = @library.Axes::new(width + deco.extent.times(2.0), top + bottom)
    let sides = styled_rect(size, radius, fill, stroke)
    let origin = @library.Point::new(pos.x - deco.extent, pos.y - top - shift)
    frame.prepend_multiple(
      sides
      .map(shape => {
        (origin, @library.FrameItem::Shape(shape, @syntax.Span::detached()))
      })
      .iter(),
    )
    return
  }
  let (stroke, metrics, offset, evade, background) = match deco.line {
    Strikethrough(stroke~, offset~, background~) =>
      (stroke, font_metrics.strikethrough, offset, false, background)
    Overline(stroke~, offset~, evade~, background~) =>
      (stroke, font_metrics.overline, offset, evade, background)
    Underline(stroke~, offset~, evade~, background~) =>
      (stroke, font_metrics.underline, offset, evade, background)
    Highlight(..) => return
  }
  let offset = match offset {
    Custom(v) => v
    Auto => -metrics.position.at(text.size)
  }
  let offset = offset - shift
  let stroke = stroke.unwrap_or(
    @library.FixedStroke::from_pair(
      text.fill.as_decoration(),
      metrics.thickness.at(text.size),
    ),
  )
  let gap_padding = text.size.times(0.08)
  let min_width = text.size.times(0.162)
  let start = pos.x - deco.extent
  let end = pos.x + width + deco.extent
  let push_segment = (from : @library.Abs, to : @library.Abs, prepend : Bool) => {
    let origin = @library.Point::new(from, pos.y + offset)
    let target = @library.Point::new(to - from, @library.Abs::zero())
    if target.x >= min_width || !evade {
      let shape = @library.Geometry::Line(target).stroked(stroke)
      if prepend {
        frame.prepend(origin, Shape(shape, @syntax.Span::detached()))
      } else {
        frame.push(origin, Shape(shape, @syntax.Span::detached()))
      }
    }
  }
  if !evade {
    push_segment(start, end, background)
    return
  }
  let line = KLine::new(
    (pos.x.to_raw(), offset.to_raw()),
    ((pos.x + width).to_raw(), offset.to_raw()),
  )
  let mut x = pos.x
  let intersections : Array[@library.Abs] = []
  for glyph in text.glyphs {
    let dx = glyph.x_offset.at(text.size) + x
    let builder = BezPathBuilder::new(
      font_metrics.units_per_em,
      text.size,
      dx.to_raw(),
    )
    let bbox = match text.font.ttf() {
      Some(ttf) => ttf.outline_glyph(@otf.GlyphId(glyph.id), builder)
      None => None
    }
    let path = builder.path
    x = x + glyph.x_advance.at(text.size)

    // Only do the costly segments intersection test if the line intersects
    // the bounding box.
    let intersect = match bbox {
      Some(bbox) => {
        let y_min = -text.font
          .to_em(bbox.y_max.to_int().to_double())
          .at(text.size)
        let y_max = -text.font
          .to_em(bbox.y_min.to_int().to_double())
          .at(text.size)
        offset >= y_min && offset <= y_max
      }
      None => false
    }
    if intersect {
      // Find all intersections of segments with the line.
      for seg in path_segments(path) {
        for line_t in seg.intersect_line(line) {
          intersections.push(@library.Abs::raw(line.eval_x(line_t)))
        }
      }
    }
  }

  // Add start and end points, taking padding into account.
  intersections.push(start - gap_padding)
  intersections.push(end + gap_padding)
  // When emitting the decorative line segments, we move from left to
  // right. The intersections are not necessarily in this order, yet.
  stable_sort_by(intersections, (a, b) => a.compare(b))
  for i in 0..<(intersections.length() - 1) {
    let l = intersections[i]
    let r = intersections[i + 1]

    // If we are too close, don't draw the segment
    if r - l < gap_padding {
      continue
    }
    push_segment(l + gap_padding, r - gap_padding, background)
  }
}

///|
/// Return the top/bottom edge of the text given the metric of the font.
fn determine_edges(
  text : @library.TextItem,
  top_edge : @library.TopEdge,
  bottom_edge : @library.BottomEdge,
) -> (@library.Abs, @library.Abs) {
  let mut top = @library.Abs::zero()
  let mut bottom = @library.Abs::zero()
  for g in text.glyphs {
    let e = text.font.glyph_edges(top_edge, bottom_edge, text.size, g.id)
    top = top.max(e.top)
    bottom = bottom.max(e.bottom)
  }
  (top, bottom)
}

///|
/// A path element (`kurbo::PathEl`).
priv enum PathEl {
  MoveTo((Double, Double))
  LineTo((Double, Double))
  QuadTo((Double, Double), (Double, Double))
  CurveTo((Double, Double), (Double, Double), (Double, Double))
  ClosePath
}

///|
/// Builds a kurbo `BezPath` for a glyph.
priv struct BezPathBuilder {
  path : Array[PathEl]
  units_per_em : Double
  font_size : @library.Abs
  x_offset : Double
}

///|
fn BezPathBuilder::new(
  units_per_em : Double,
  font_size : @library.Abs,
  x_offset : Double,
) -> BezPathBuilder {
  { path: [], units_per_em, font_size, x_offset, }
}

///|
fn BezPathBuilder::p(
  self : BezPathBuilder,
  x : Float,
  y : Float,
) -> (Double, Double) {
  (self.s(x) + self.x_offset, -self.s(y))
}

///|
fn BezPathBuilder::s(self : BezPathBuilder, v : Float) -> Double {
  @library.Em::from_units(v.to_double(), self.units_per_em)
  .at(self.font_size)
  .to_raw()
}

///|
impl @otf.OutlineBuilder for BezPathBuilder with fn move_to(self, x, y) {
  self.path.push(MoveTo(self.p(x, y)))
}

///|
impl @otf.OutlineBuilder for BezPathBuilder with fn line_to(self, x, y) {
  self.path.push(LineTo(self.p(x, y)))
}

///|
impl @otf.OutlineBuilder for BezPathBuilder with fn quad_to(self, x1, y1, x, y) {
  self.path.push(QuadTo(self.p(x1, y1), self.p(x, y)))
}

///|
impl @otf.OutlineBuilder for BezPathBuilder with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.path.push(CurveTo(self.p(x1, y1), self.p(x2, y2), self.p(x, y)))
}

///|
impl @otf.OutlineBuilder for BezPathBuilder with fn close(self) {
  self.path.push(ClosePath)
}

///|
/// A path segment (`kurbo::PathSeg`).
priv enum PathSeg {
  Line((Double, Double), (Double, Double))
  Quad((Double, Double), (Double, Double), (Double, Double))
  Cubic((Double, Double), (Double, Double), (Double, Double), (Double, Double))
}

///|
/// The segments of a path (`kurbo::segments`).
fn path_segments(elements : Array[PathEl]) -> Array[PathSeg] {
  let out = []
  let mut started = false
  let mut start = (0.0, 0.0)
  let mut last = (0.0, 0.0)
  for el in elements {
    // We first need to check whether this is the first path element we see
    // to fill in the start position.
    if !started {
      let point = match el {
        MoveTo(p) => p
        LineTo(p) => p
        QuadTo(_, p2) => p2
        CurveTo(_, _, p3) => p3
        ClosePath => abort("Can't start a segment on a ClosePath")
      }
      start = point
      last = point
      started = true
    }
    match el {
      MoveTo(p) => {
        start = p
        last = p
      }
      LineTo(p) => {
        out.push(PathSeg::Line(last, p))
        last = p
      }
      QuadTo(p1, p2) => {
        out.push(Quad(last, p1, p2))
        last = p2
      }
      CurveTo(p1, p2, p3) => {
        out.push(Cubic(last, p1, p2, p3))
        last = p3
      }
      ClosePath =>
        if last.0 != start.0 || last.1 != start.1 {
          out.push(PathSeg::Line(last, start))
          last = start
        }
    }
  }
  out
}

///|
/// A line (`kurbo::Line`).
priv struct KLine {
  p0 : (Double, Double)
  p1 : (Double, Double)
}

///|
fn KLine::new(p0 : (Double, Double), p1 : (Double, Double)) -> KLine {
  { p0, p1, }
}

///|
/// The x coordinate of `Line::eval(t)` (`p0.lerp(p1, t)`).
fn KLine::eval_x(self : KLine, t : Double) -> Double {
  self.p0.0 + t * (self.p1.0 - self.p0.0)
}

///|
/// Compute intersections against a line (`PathSeg::intersect_line`). Returns
/// the `line_t` of each intersection.
fn PathSeg::intersect_line(self : PathSeg, line : KLine) -> Array[Double] {
  let epsilon = 1.0e-9
  let (p0x, p0y) = line.p0
  let (p1x, p1y) = line.p1
  let dx = p1x - p0x
  let dy = p1y - p0y
  let result = []
  let in_t = (t : Double) => t >= -epsilon && t <= 1.0 + epsilon
  let in_u = (u : Double) => u >= 0.0 && u <= 1.0
  match self {
    Line(l0, l1) => {
      let det = dx * (l1.1 - l0.1) - dy * (l1.0 - l0.0)
      if det.abs() < epsilon {
        // Lines are coincident (or nearly so).
        return result
      }
      let t = dx * (p0y - l0.1) - dy * (p0x - l0.0)
      // t = position on self
      let t = t / det
      if in_t(t) {
        // u = position on probe line
        let u = (l0.0 - p0x) * (l1.1 - l0.1) - (l0.1 - p0y) * (l1.0 - l0.0)
        let u = u / det
        if in_u(u) {
          result.push(u)
        }
      }
    }
    Quad(q0, q1, q2) => {
      // The basic technique here is to determine x and y as a quadratic
      // polynomial as a function of t. Then plug those values into the line
      // equation for the probe line (giving a sort of signed distance from
      // the probe line) and solve that for t.
      let (px0, px1, px2) = quadratic_bez_coefs(q0.0, q1.0, q2.0)
      let (py0, py1, py2) = quadratic_bez_coefs(q0.1, q1.1, q2.1)
      let c0 = dy * (px0 - p0x) - dx * (py0 - p0y)
      let c1 = dy * px1 - dx * py1
      let c2 = dy * px2 - dx * py2
      let invlen2 = 1.0 / (dx * dx + dy * dy)
      for t in solve_quadratic(c0, c1, c2) {
        if in_t(t) {
          let x = px0 + t * px1 + t * t * px2
          let y = py0 + t * py1 + t * t * py2
          let u = ((x - p0x) * dx + (y - p0y) * dy) * invlen2
          if in_u(u) {
            result.push(u)
          }
        }
      }
    }
    Cubic(c0p, c1p, c2p, c3p) => {
      // Same technique as above, but cubic polynomial.
      let (px0, px1, px2, px3) = cubic_bez_coefs(c0p.0, c1p.0, c2p.0, c3p.0)
      let (py0, py1, py2, py3) = cubic_bez_coefs(c0p.1, c1p.1, c2p.1, c3p.1)
      let c0 = dy * (px0 - p0x) - dx * (py0 - p0y)
      let c1 = dy * px1 - dx * py1
      let c2 = dy * px2 - dx * py2
      let c3 = dy * px3 - dx * py3
      let invlen2 = 1.0 / (dx * dx + dy * dy)
      for t in solve_cubic(c0, c1, c2, c3) {
        if in_t(t) {
          let x = px0 + t * px1 + t * t * px2 + t * t * t * px3
          let y = py0 + t * py1 + t * t * py2 + t * t * t * py3
          let u = ((x - p0x) * dx + (y - p0y) * dy) * invlen2
          if in_u(u) {
            result.push(u)
          }
        }
      }
    }
  }
  result
}

///|
/// Return polynomial coefficients given quadratic Bézier coordinates.
fn quadratic_bez_coefs(
  x0 : Double,
  x1 : Double,
  x2 : Double,
) -> (Double, Double, Double) {
  let p0 = x0
  let p1 = 2.0 * x1 - 2.0 * x0
  let p2 = x2 - 2.0 * x1 + x0
  (p0, p1, p2)
}

///|
/// Return polynomial coefficients given cubic Bézier coordinates.
fn cubic_bez_coefs(
  x0 : Double,
  x1 : Double,
  x2 : Double,
  x3 : Double,
) -> (Double, Double, Double, Double) {
  let p0 = x0
  let p1 = 3.0 * x1 - 3.0 * x0
  let p2 = 3.0 * x2 - 6.0 * x1 + 3.0 * x0
  let p3 = x3 - 3.0 * x2 + 3.0 * x1 - x0
  (p0, p1, p2, p3)
}

///|
/// `f64::mul_add` (a fused multiply-add, emulated with error-free
/// transformations).
fn mul_add(a : Double, b : Double, c : Double) -> Double {
  let p = a * b
  if !f64_is_finite(p) || !f64_is_finite(c) {
    return p + c
  }
  // Dekker's TwoProduct: `a * b = p + e` exactly.
  let split = (x : Double) => {
    let f = 134217729.0 * x // 2^27 + 1
    let hi = f - (f - x)
    (hi, x - hi)
  }
  let (ah, al) = split(a)
  let (bh, bl) = split(b)
  let e = al * bl - (p - ah * bh - al * bh - ah * bl)
  // TwoSum: `p + c = s + t` exactly.
  let s = p + c
  let bb = s - p
  let t = p - (s - bb) + (c - bb)
  s + (t + e)
}

///|
/// Find real roots of cubic equation (`kurbo::common::solve_cubic`).
fn solve_cubic(
  c0 : Double,
  c1 : Double,
  c2 : Double,
  c3 : Double,
) -> Array[Double] {
  let result = []
  let c3_recip = 1.0 / c3
  let onethird = 1.0 / 3.0
  let scaled_c2 = c2 * (onethird * c3_recip)
  let scaled_c1 = c1 * (onethird * c3_recip)
  let scaled_c0 = c0 * c3_recip
  if !(f64_is_finite(scaled_c0) &&
    f64_is_finite(scaled_c1) &&
    f64_is_finite(scaled_c2)) {
    // cubic coefficient is zero or nearly so.
    return solve_quadratic(c0, c1, c2)
  }
  let (c0, c1, c2) = (scaled_c0, scaled_c1, scaled_c2)
  // (d0, d1, d2) is called "Delta" in article
  let d0 = mul_add(-c2, c2, c1)
  let d1 = mul_add(-c1, c2, c0)
  let d2 = c2 * c0 - c1 * c1
  // d is called "Discriminant"
  let d = 4.0 * d0 * d2 - d1 * d1
  // de is called "Depressed.x", Depressed.y = d0
  let de = mul_add(-2.0 * c2, d0, d1)
  if d < 0.0 {
    let sq = (-0.25 * d).sqrt()
    let r = -0.5 * de
    let t1 = @libm.f64_cbrt(r + sq) + @libm.f64_cbrt(r - sq)
    result.push(t1 - c2)
  } else if d == 0.0 {
    let t1 = copysign((-d0).sqrt(), de)
    result.push(t1 - c2)
    result.push(-2.0 * t1 - c2)
  } else {
    let th = libm_atan2(d.sqrt(), -de) * onethird
    // (th_cos, th_sin) is called "CubicRoot"
    let th_sin = libm_sin(th)
    let th_cos = libm_cos(th)
    // (r0, r1, r2) is called "Root"
    let r0 = th_cos
    let ss3 = th_sin * (3.0 : Double).sqrt()
    let r1 = 0.5 * (-th_cos + ss3)
    let r2 = 0.5 * (-th_cos - ss3)
    let t = 2.0 * (-d0).sqrt()
    result.push(mul_add(t, r0, -c2))
    result.push(mul_add(t, r1, -c2))
    result.push(mul_add(t, r2, -c2))
  }
  result
}
