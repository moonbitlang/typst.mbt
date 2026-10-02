// Port of `tiny-skia/src/edge_clipper.rs`.

///|
let max_verbs : Int = 18

///|
priv struct EdgeClipper {
  clip : @path.Rect
  can_cull_to_the_right : Bool
  edges : Array[PathEdge]
}

///|
fn EdgeClipper::new(
  clip : @path.Rect,
  can_cull_to_the_right : Bool,
) -> EdgeClipper {
  { clip, can_cull_to_the_right, edges: Array(capacity=max_verbs), }
}

///|
fn EdgeClipper::finish(self : EdgeClipper) -> Array[PathEdge]? {
  if self.edges.is_empty() {
    None
  } else {
    Some(self.edges)
  }
}

///|
fn EdgeClipper::clip_line(
  self : EdgeClipper,
  p0 : @path.Point,
  p1 : @path.Point,
) -> Array[PathEdge]? {
  let points = line_clip([p0, p1], self.clip, self.can_cull_to_the_right)
  if !points.is_empty() {
    for i in 0..<(points.length() - 1) {
      self.push_line(points[i], points[i + 1])
    }
  }
  self.finish()
}

///|
fn EdgeClipper::push_line(
  self : EdgeClipper,
  p0 : @path.Point,
  p1 : @path.Point,
) -> Unit {
  self.edges.push(LineTo(p0, p1))
}

///|
fn EdgeClipper::push_vline(
  self : EdgeClipper,
  x : Float,
  y0 : Float,
  y1 : Float,
  reverse : Bool,
) -> Unit {
  let (y0, y1) = if reverse { (y1, y0) } else { (y0, y1) }
  self.edges.push(
    LineTo(@path.Point::from_xy(x, y0), @path.Point::from_xy(x, y1)),
  )
}

///|
fn EdgeClipper::clip_quad(
  self : EdgeClipper,
  p0 : @path.Point,
  p1 : @path.Point,
  p2 : @path.Point,
) -> Array[PathEdge]? {
  let pts = [p0, p1, p2]
  guard @path.Rect::from_points(pts[:]) is Some(bounds) else { return None }
  if !quick_reject(bounds, self.clip) {
    let mono_y = Array::make(5, @path.Point::zero())
    let count_y = chop_quad_at_y_extrema(pts[:], mono_y)
    for y in 0..<=count_y {
      let mono_x = Array::make(5, @path.Point::zero())
      let y_points = mono_y[y * 2:y * 2 + 3]
      let count_x = chop_quad_at_x_extrema(y_points, mono_x)
      for x in 0..<=count_x {
        let x_points = [mono_x[x * 2], mono_x[x * 2 + 1], mono_x[x * 2 + 2]]
        self.clip_mono_quad(x_points)
      }
    }
  }
  self.finish()
}

///|
/// src[] must be monotonic in X and Y
fn EdgeClipper::clip_mono_quad(
  self : EdgeClipper,
  src : Array[@path.Point],
) -> Unit {
  let pts = Array::make(3, @path.Point::zero())
  let mut reverse = sort_increasing_y(src, pts)

  // are we completely above or below
  if pts[2].y <= self.clip.top() || pts[0].y >= self.clip.bottom() {
    return
  }

  // Now chop so that pts is contained within clip in Y
  chop_quad_in_y(self.clip, pts)
  if pts[0].x > pts[2].x {
    let t = pts[0]
    pts[0] = pts[2]
    pts[2] = t
    reverse = !reverse
  }

  // Now chop in X has needed, and record the segments

  if pts[2].x <= self.clip.left() {
    // wholly to the left
    self.push_vline(self.clip.left(), pts[0].y, pts[2].y, reverse)
    return
  }
  if pts[0].x >= self.clip.right() {
    // wholly to the right
    if !self.can_cull_to_the_right {
      self.push_vline(self.clip.right(), pts[0].y, pts[2].y, reverse)
    }
    return
  }
  let tmp = Array::make(5, @path.Point::zero())

  // are we partially to the left
  if pts[0].x < self.clip.left() {
    if chop_mono_quad_at_x(pts, self.clip.left()) is Some(t) {
      ts_chop_quad_at(pts[:], t, tmp)
      self.push_vline(self.clip.left(), tmp[0].y, tmp[2].y, reverse)
      // clamp to clean up imprecise numerics in the chop
      tmp[2] = { x: self.clip.left(), y: tmp[2].y, }
      tmp[3] = { x: fmax(tmp[3].x, self.clip.left()), y: tmp[3].y, }
      pts[0] = tmp[2]
      pts[1] = tmp[3]
    } else {
      // if chopMonoQuadAtY failed, then we may have hit inexact numerics
      // so we just clamp against the left
      self.push_vline(self.clip.left(), pts[0].y, pts[2].y, reverse)
      return
    }
  }

  // are we partially to the right
  if pts[2].x > self.clip.right() {
    if chop_mono_quad_at_x(pts, self.clip.right()) is Some(t) {
      ts_chop_quad_at(pts[:], t, tmp)
      // clamp to clean up imprecise numerics in the chop
      tmp[1] = { x: fmin(tmp[1].x, self.clip.right()), y: tmp[1].y, }
      tmp[2] = { x: self.clip.right(), y: tmp[2].y, }
      self.push_quad([tmp[0], tmp[1], tmp[2]], reverse)
      self.push_vline(self.clip.right(), tmp[2].y, tmp[4].y, reverse)
    } else {
      // if chopMonoQuadAtY failed, then we may have hit inexact numerics
      // so we just clamp against the right
      pts[1] = { x: fmin(pts[1].x, self.clip.right()), y: pts[1].y, }
      pts[2] = { x: fmin(pts[2].x, self.clip.right()), y: pts[2].y, }
      self.push_quad(pts, reverse)
    }
  } else {
    // wholly inside the clip
    self.push_quad(pts, reverse)
  }
}

///|
fn EdgeClipper::push_quad(
  self : EdgeClipper,
  pts : Array[@path.Point],
  reverse : Bool,
) -> Unit {
  if reverse {
    self.edges.push(QuadTo(pts[2], pts[1], pts[0]))
  } else {
    self.edges.push(QuadTo(pts[0], pts[1], pts[2]))
  }
}

///|
fn EdgeClipper::clip_cubic(
  self : EdgeClipper,
  p0 : @path.Point,
  p1 : @path.Point,
  p2 : @path.Point,
  p3 : @path.Point,
) -> Array[PathEdge]? {
  let pts = [p0, p1, p2, p3]
  guard @path.Rect::from_points(pts[:]) is Some(bounds) else { return None }

  // check if we're clipped out vertically
  if bounds.bottom() > self.clip.top() && bounds.top() < self.clip.bottom() {
    if too_big_for_reliable_float_math(bounds) {
      // can't safely clip the cubic, so we give up and draw a line (which we
      // can safely clip)
      //
      // If we rewrote chopcubicat*extrema and chopmonocubic using doubles, we
      // could very likely always handle the cubic safely, but (it seems) at a
      // big loss in speed, so we'd only want to take that alternate impl if
      // needed.
      return self.clip_line(p0, p3)
    } else {
      let mono_y = Array::make(10, @path.Point::zero())
      let count_y = chop_cubic_at_y_extrema(pts[:], mono_y)
      for y in 0..<=count_y {
        let mono_x = Array::make(10, @path.Point::zero())
        let y_points = mono_y[y * 3:y * 3 + 4]
        let count_x = chop_cubic_at_x_extrema(y_points, mono_x)
        for x in 0..<=count_x {
          let x_points = [
            mono_x[x * 3],
            mono_x[x * 3 + 1],
            mono_x[x * 3 + 2],
            mono_x[x * 3 + 3],
          ]
          self.clip_mono_cubic(x_points)
        }
      }
    }
  }
  self.finish()
}

///|
/// src[] must be monotonic in X and Y
fn EdgeClipper::clip_mono_cubic(
  self : EdgeClipper,
  src : Array[@path.Point],
) -> Unit {
  let pts = Array::make(4, @path.Point::zero())
  let mut reverse = sort_increasing_y(src, pts)

  // are we completely above or below
  if pts[3].y <= self.clip.top() || pts[0].y >= self.clip.bottom() {
    return
  }

  // Now chop so that pts is contained within clip in Y
  chop_cubic_in_y(self.clip, pts)
  if pts[0].x > pts[3].x {
    let t = pts[0]
    pts[0] = pts[3]
    pts[3] = t
    let t = pts[1]
    pts[1] = pts[2]
    pts[2] = t
    reverse = !reverse
  }

  // Now chop in X has needed, and record the segments

  if pts[3].x <= self.clip.left() {
    // wholly to the left
    self.push_vline(self.clip.left(), pts[0].y, pts[3].y, reverse)
    return
  }
  if pts[0].x >= self.clip.right() {
    // wholly to the right
    if !self.can_cull_to_the_right {
      self.push_vline(self.clip.right(), pts[0].y, pts[3].y, reverse)
    }
    return
  }

  // are we partially to the left
  if pts[0].x < self.clip.left() {
    let tmp = Array::make(7, @path.Point::zero())
    chop_mono_cubic_at_x(pts, self.clip.left(), tmp)
    self.push_vline(self.clip.left(), tmp[0].y, tmp[3].y, reverse)

    // tmp[3, 4].fX should all be to the right of clip.left().
    // Since we can't trust the numerics of
    // the chopper, we force those conditions now
    tmp[3] = { x: self.clip.left(), y: tmp[3].y, }
    tmp[4] = { x: fmax(tmp[4].x, self.clip.left()), y: tmp[4].y, }
    pts[0] = tmp[3]
    pts[1] = tmp[4]
    pts[2] = tmp[5]
  }

  // are we partially to the right
  if pts[3].x > self.clip.right() {
    let tmp = Array::make(7, @path.Point::zero())
    chop_mono_cubic_at_x(pts, self.clip.right(), tmp)
    tmp[3] = { x: self.clip.right(), y: tmp[3].y, }
    tmp[2] = { x: fmin(tmp[2].x, self.clip.right()), y: tmp[2].y, }
    self.push_cubic([tmp[0], tmp[1], tmp[2], tmp[3]], reverse)
    self.push_vline(self.clip.right(), tmp[3].y, tmp[6].y, reverse)
  } else {
    // wholly inside the clip
    self.push_cubic(pts, reverse)
  }
}

///|
fn EdgeClipper::push_cubic(
  self : EdgeClipper,
  pts : Array[@path.Point],
  reverse : Bool,
) -> Unit {
  if reverse {
    self.edges.push(CubicTo(pts[3], pts[2], pts[1], pts[0]))
  } else {
    self.edges.push(CubicTo(pts[0], pts[1], pts[2], pts[3]))
  }
}

///|
priv struct EdgeClipperIter {
  edge_iter : PathEdgeIter
  clip : @path.Rect
  can_cull_to_the_right : Bool
}

///|
fn EdgeClipperIter::new(
  path : @path.Path,
  clip : @path.Rect,
  can_cull_to_the_right : Bool,
) -> EdgeClipperIter {
  { edge_iter: edge_iter(path), clip, can_cull_to_the_right, }
}

///|
fn EdgeClipperIter::next(self : EdgeClipperIter) -> Array[PathEdge]? {
  while self.edge_iter.next() is Some(edge) {
    let clipper = EdgeClipper::new(self.clip, self.can_cull_to_the_right)
    match edge {
      LineTo(p0, p1) =>
        if clipper.clip_line(p0, p1) is Some(edges) {
          return Some(edges)
        }
      QuadTo(p0, p1, p2) =>
        if clipper.clip_quad(p0, p1, p2) is Some(edges) {
          return Some(edges)
        }
      CubicTo(p0, p1, p2, p3) =>
        if clipper.clip_cubic(p0, p1, p2, p3) is Some(edges) {
          return Some(edges)
        }
    }
  }
  None
}

///|
fn quick_reject(bounds : @path.Rect, clip : @path.Rect) -> Bool {
  bounds.top() >= clip.bottom() || bounds.bottom() <= clip.top()
}

///|
/// src[] must be monotonic in Y. This routine copies src into dst, and sorts
/// it to be increasing in Y. If it had to reverse the order of the points,
/// it returns true, otherwise it returns false
fn sort_increasing_y(
  src : Array[@path.Point],
  dst : Array[@path.Point],
) -> Bool {
  // We need the data to be monotonically increasing in Y.
  // Never fails, because src is always non-empty.
  let n = src.length()
  if src[0].y > src[n - 1].y {
    for i in 0..<n {
      dst[i] = src[n - 1 - i]
    }
    true
  } else {
    for i in 0..<n {
      dst[i] = src[i]
    }
    false
  }
}

///|
fn chop_quad_in_y(clip : @path.Rect, pts : Array[@path.Point]) -> Unit {
  let tmp = Array::make(5, @path.Point::zero())

  // are we partially above
  if pts[0].y < clip.top() {
    if chop_mono_quad_at_y(pts, clip.top()) is Some(t) {
      // take the 2nd chopped quad
      ts_chop_quad_at(pts[:], t, tmp)
      // clamp to clean up imprecise numerics in the chop
      tmp[2] = { x: tmp[2].x, y: clip.top(), }
      tmp[3] = { x: tmp[3].x, y: fmax(tmp[3].y, clip.top()), }
      pts[0] = tmp[2]
      pts[1] = tmp[3]
    } else {
      // if chop_mono_quad_at_y failed, then we may have hit inexact numerics
      // so we just clamp against the top
      for i in 0..<3 {
        if pts[i].y < clip.top() {
          pts[i] = { x: pts[i].x, y: clip.top(), }
        }
      }
    }
  }

  // are we partially below
  if pts[2].y > clip.bottom() {
    if chop_mono_quad_at_y(pts, clip.bottom()) is Some(t) {
      ts_chop_quad_at(pts[:], t, tmp)
      // clamp to clean up imprecise numerics in the chop
      tmp[1] = { x: tmp[1].x, y: fmin(tmp[1].y, clip.bottom()), }
      tmp[2] = { x: tmp[2].x, y: clip.bottom(), }
      pts[1] = tmp[1]
      pts[2] = tmp[2]
    } else {
      // if chop_mono_quad_at_y failed, then we may have hit inexact numerics
      // so we just clamp against the bottom
      for i in 0..<3 {
        if pts[i].y > clip.bottom() {
          pts[i] = { x: pts[i].x, y: clip.bottom(), }
        }
      }
    }
  }
}

///|
fn chop_mono_quad_at_x(pts : Array[@path.Point], x : Float) -> Float? {
  chop_mono_quad_at(pts[0].x, pts[1].x, pts[2].x, x)
}

///|
fn chop_mono_quad_at_y(pts : Array[@path.Point], y : Float) -> Float? {
  chop_mono_quad_at(pts[0].y, pts[1].y, pts[2].y, y)
}

///|
fn chop_mono_quad_at(
  c0 : Float,
  c1 : Float,
  c2 : Float,
  target : Float,
) -> Float? {
  // Solve F(t) = y where F(t) := [0](1-t)^2 + 2[1]t(1-t) + [2]t^2
  // We solve for t, using quadratic equation, hence we have to rearrange
  // our coefficients to look like At^2 + Bt + C
  let a = c0 - c1 - c1 + c2
  let b = (2.0 : Float) * (c1 - c0)
  let c = c0 - target
  let roots = ts_new_t_values()
  let count = ts_find_unit_quad_roots(a, b, c, roots)
  if count != 0 {
    Some(roots[0])
  } else {
    None
  }
}

///|
fn too_big_for_reliable_float_math(r : @path.Rect) -> Bool {
  // limit set as the largest float value for which we can still reliably
  // compute things like
  // - chopping at XY extrema
  // - chopping at Y or X values for clipping
  //
  // Current value chosen just by experiment. Larger (and still succeeds) is
  // always better.
  let limit = Float::from_int(1 << 22)
  r.left() < -limit ||
  r.top() < -limit ||
  r.right() > limit ||
  r.bottom() > limit
}

///|
fn chop_cubic_in_y(clip : @path.Rect, pts : Array[@path.Point]) -> Unit {
  // are we partially above
  if pts[0].y < clip.top() {
    let tmp = Array::make(7, @path.Point::zero())
    chop_mono_cubic_at_y(pts, clip.top(), tmp)

    // For a large range in the points, we can do a poor job of chopping, such
    // that the t we computed resulted in the lower cubic still being partly
    // above the clip.
    //
    // If just the first or first 2 Y values are above the fTop, we can just
    // smash them down. If the first 3 Ys are above fTop, we can't smash all 3,
    // as that can really distort the cubic. In this case, we take the first
    // output (tmp[3..6] and treat it as a guess, and re-chop against fTop.
    // Then we fall through to checking if we need to smash the first 1 or 2 Y
    // values.
    if tmp[3].y < clip.top() && tmp[4].y < clip.top() && tmp[5].y < clip.top() {
      let tmp2 = [tmp[3], tmp[4], tmp[5], tmp[6]]
      chop_mono_cubic_at_y(tmp2, clip.top(), tmp)
    }

    // tmp[3, 4].y should all be to the below clip.fTop.
    // Since we can't trust the numerics of the chopper, we force those
    // conditions now
    tmp[3] = { x: tmp[3].x, y: clip.top(), }
    tmp[4] = { x: tmp[4].x, y: fmax(tmp[4].y, clip.top()), }
    pts[0] = tmp[3]
    pts[1] = tmp[4]
    pts[2] = tmp[5]
  }

  // are we partially below
  if pts[3].y > clip.bottom() {
    let tmp = Array::make(7, @path.Point::zero())
    chop_mono_cubic_at_y(pts, clip.bottom(), tmp)
    tmp[3] = { x: tmp[3].x, y: clip.bottom(), }
    tmp[2] = { x: tmp[2].x, y: fmin(tmp[2].y, clip.bottom()), }
    pts[1] = tmp[1]
    pts[2] = tmp[2]
    pts[3] = tmp[3]
  }
}

///|
fn chop_mono_cubic_at_x(
  src : Array[@path.Point],
  x : Float,
  dst : Array[@path.Point],
) -> Unit {
  if chop_mono_cubic_at_x_dchop(src[:], x, dst) {
    return
  }
  let src_values : FixedArray[Float] = [src[0].x, src[1].x, src[2].x, src[3].x]
  ts_chop_cubic_at2(src[:], mono_cubic_closest_t(src_values, x), dst, 0)
}

///|
fn chop_mono_cubic_at_y(
  src : Array[@path.Point],
  y : Float,
  dst : Array[@path.Point],
) -> Unit {
  if chop_mono_cubic_at_y_dchop(src[:], y, dst) {
    return
  }
  let src_values : FixedArray[Float] = [src[0].y, src[1].y, src[2].y, src[3].y]
  ts_chop_cubic_at2(src[:], mono_cubic_closest_t(src_values, y), dst, 0)
}

///|
fn mono_cubic_closest_t(src : FixedArray[Float], x : Float) -> Float {
  let mut x = x
  let mut t : Float = 0.5
  let mut last_t : Float = 0.0
  let mut best_t = t
  let mut step : Float = 0.25
  let d = src[0]
  let a = src[3] + (3.0 : Float) * (src[1] - src[2]) - d
  let b = (3.0 : Float) * (src[2] - src[1] - src[1] + d)
  let c = (3.0 : Float) * (src[1] - d)
  x -= d
  let mut closest = scalar_max
  while true {
    let loc = ((a * t + b) * t + c) * t
    let dist = fabs(loc - x)
    if closest > dist {
      closest = dist
      best_t = t
    }
    last_t = t
    t += if loc < x { step } else { -step }
    step *= 0.5
    if !(closest > 0.25 && last_t != t) {
      break
    }
  }
  normalized_f32_exclusive(best_t).unwrap()
}
