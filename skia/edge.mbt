// Port of `tiny-skia/src/edge.rs`.
//
// The `Edge` enum (`Line`, `Quadratic`, `Cubic`) is a single mutable struct
// with a kind tag; the shared `LineEdge` fields are fields of the struct.
// `prev`/`next` (`Option<u32>`) use -1 for `None`.

///|
let max_coeff_shift : Int = 6

///|
enum EdgeKind {
  Line
  Quadratic
  Cubic
} derive(Eq)

///|
struct Edge {
  kind : EdgeKind
  // LineEdge. Imitate a linked list.
  mut prev : Int
  mut next : Int
  mut x : Int // FDot16
  mut dx : Int // FDot16
  mut first_y : Int
  mut last_y : Int
  mut winding : Int // 1 or -1
  // QuadraticEdge / CubicEdge.
  mut curve_count : Int // i8
  curve_shift : Int // applied to all dx/ddx/dddx
  dshift : Int // applied to cdx and cdy (cubic only)
  mut cx : Int
  mut cy : Int
  mut cdx : Int
  mut cdy : Int
  mut cddx : Int
  mut cddy : Int
  cdddx : Int // cubic only
  cdddy : Int // cubic only
  c_last_x : Int
  c_last_y : Int
}

///|
fn Edge::line_default() -> Edge {
  {
    kind: Line,
    prev: -1,
    next: -1,
    x: 0,
    dx: 0,
    first_y: 0,
    last_y: 0,
    winding: 0,
    curve_count: 0,
    curve_shift: 0,
    dshift: 0,
    cx: 0,
    cy: 0,
    cdx: 0,
    cdy: 0,
    cddx: 0,
    cddy: 0,
    cdddx: 0,
    cdddy: 0,
    c_last_x: 0,
    c_last_y: 0,
  }
}

///|
/// `LineEdge::new`.
fn Edge::new_line(p0 : @path.Point, p1 : @path.Point, shift : Int) -> Edge? {
  let scale = Float::from_int(1 << (shift + 6))
  let mut x0 = @path.f32_to_i32(p0.x * scale)
  let mut y0 = @path.f32_to_i32(p0.y * scale)
  let mut x1 = @path.f32_to_i32(p1.x * scale)
  let mut y1 = @path.f32_to_i32(p1.y * scale)
  let mut winding = 1
  if y0 > y1 {
    let tx = x0
    x0 = x1
    x1 = tx
    let ty = y0
    y0 = y1
    y1 = ty
    winding = -1
  }
  let top = fdot6_round(y0)
  let bottom = fdot6_round(y1)

  // are we a zero-height line?
  if top == bottom {
    return None
  }
  let slope = fdot6_div(x1 - x0, y1 - y0)
  let dy = compute_dy(top, y0)
  let e = Edge::line_default()
  e.x = fdot6_to_fdot16(x0 + fdot16_mul(slope, dy))
  e.dx = slope
  e.first_y = top
  e.last_y = bottom - 1
  e.winding = winding
  Some(e)
}

///|
fn Edge::is_vertical(self : Edge) -> Bool {
  self.dx == 0
}

///|
/// `LineEdge::update`.
fn Edge::update_line(
  self : Edge,
  x0 : Int,
  y0 : Int,
  x1 : Int,
  y1 : Int,
) -> Bool {
  let y0 = y0 >> 10
  let y1 = y1 >> 10
  let top = fdot6_round(y0)
  let bottom = fdot6_round(y1)

  // are we a zero-height line?
  if top == bottom {
    return false
  }
  let x0 = x0 >> 10
  let x1 = x1 >> 10
  let slope = fdot6_div(x1 - x0, y1 - y0)
  let dy = compute_dy(top, y0)
  self.x = fdot6_to_fdot16(x0 + fdot16_mul(slope, dy))
  self.dx = slope
  self.first_y = top
  self.last_y = bottom - 1
  true
}

///|
/// `QuadraticEdge::new`.
fn Edge::new_quadratic(points : ArrayView[@path.Point], shift : Int) -> Edge? {
  guard Edge::new_quadratic2(points, shift) is Some(quad) else { return None }
  if quad.update_quadratic() {
    Some(quad)
  } else {
    None
  }
}

///|
fn Edge::new_quadratic2(points : ArrayView[@path.Point], shift : Int) -> Edge? {
  let mut shift = shift
  let scale = Float::from_int(1 << (shift + 6))
  let mut x0 = @path.f32_to_i32(points[0].x * scale)
  let mut y0 = @path.f32_to_i32(points[0].y * scale)
  let x1 = @path.f32_to_i32(points[1].x * scale)
  let y1 = @path.f32_to_i32(points[1].y * scale)
  let mut x2 = @path.f32_to_i32(points[2].x * scale)
  let mut y2 = @path.f32_to_i32(points[2].y * scale)
  let mut winding = 1
  if y0 > y2 {
    let tx = x0
    x0 = x2
    x2 = tx
    let ty = y0
    y0 = y2
    y2 = ty
    winding = -1
  }
  let top = fdot6_round(y0)
  let bottom = fdot6_round(y2)

  // are we a zero-height quad (line)?
  if top == bottom {
    return None
  }

  // compute number of steps needed (1 << shift)
  {
    let dx = (left_shift(x1, 1) - x0 - x2) >> 2
    let dy = (left_shift(y1, 1) - y0 - y2) >> 2
    // This is a little confusing:
    // before this line, shift is the scale up factor for AA;
    // after this line, shift is the fCurveShift.
    shift = diff_to_shift(dx, dy, shift)
  }

  // need at least 1 subdivision for our bias trick
  if shift == 0 {
    shift = 1
  } else if shift > max_coeff_shift {
    shift = max_coeff_shift
  }
  let curve_count = 1 << shift

  // We want to reformulate into polynomial form, to make it clear how we
  // should forward-difference.
  //
  // p0 (1 - t)^2 + p1 t(1 - t) + p2 t^2 ==> At^2 + Bt + C
  //
  // A = p0 - 2p1 + p2
  // B = 2(p1 - p0)
  // C = p0
  //
  // Our caller must have constrained our inputs (p0..p2) to all fit into
  // 16.16. However, as seen above, we sometimes compute values that can be
  // larger (e.g. B = 2*(p1 - p0)). To guard against overflow, we will store
  // A and B at 1/2 of their actual value, and just apply a 2x scale during
  // application in updateQuadratic(). Hence we store (shift - 1) in
  // curve_shift.

  let curve_shift = shift - 1
  let mut a = fdot6_to_fixed_div2(x0 - x1 - x1 + x2) // 1/2 the real value
  let mut b = fdot6_to_fdot16(x1 - x0) // 1/2 the real value
  let qx = fdot6_to_fdot16(x0)
  let qdx = b + (a >> shift) // biased by shift
  let qddx = a >> (shift - 1) // biased by shift
  a = fdot6_to_fixed_div2(y0 - y1 - y1 + y2) // 1/2 the real value
  b = fdot6_to_fdot16(y1 - y0) // 1/2 the real value
  let qy = fdot6_to_fdot16(y0)
  let qdy = b + (a >> shift) // biased by shift
  let qddy = a >> (shift - 1) // biased by shift
  let q_last_x = fdot6_to_fdot16(x2)
  let q_last_y = fdot6_to_fdot16(y2)
  let e = Edge::line_default()
  Some({
    ..e,
    kind: Quadratic,
    winding,
    curve_count,
    curve_shift,
    cx: qx,
    cy: qy,
    cdx: qdx,
    cdy: qdy,
    cddx: qddx,
    cddy: qddy,
    c_last_x: q_last_x,
    c_last_y: q_last_y,
  })
}

///|
/// `QuadraticEdge::update`.
fn Edge::update_quadratic(self : Edge) -> Bool {
  let mut success = false
  let mut count = self.curve_count
  let mut oldx = self.cx
  let mut oldy = self.cy
  let mut dx = self.cdx
  let mut dy = self.cdy
  let mut newx = 0
  let mut newy = 0
  let shift = self.curve_shift
  while true {
    count -= 1
    if count > 0 {
      newx = oldx + (dx >> shift)
      dx += self.cddx
      newy = oldy + (dy >> shift)
      dy += self.cddy
    } else {
      // last segment
      newx = self.c_last_x
      newy = self.c_last_y
    }
    success = self.update_line(oldx, oldy, newx, newy)
    oldx = newx
    oldy = newy
    if count == 0 || success {
      break
    }
  }
  self.cx = newx
  self.cy = newy
  self.cdx = dx
  self.cdy = dy
  self.curve_count = count
  success
}

///|
/// `CubicEdge::new`.
fn Edge::new_cubic(points : ArrayView[@path.Point], shift : Int) -> Edge? {
  guard Edge::new_cubic2(points, shift, true) is Some(cubic) else {
    return None
  }
  if cubic.update_cubic() {
    Some(cubic)
  } else {
    None
  }
}

///|
fn Edge::new_cubic2(
  points : ArrayView[@path.Point],
  shift : Int,
  sort_y : Bool,
) -> Edge? {
  let scale = Float::from_int(1 << (shift + 6))
  let mut x0 = @path.f32_to_i32(points[0].x * scale)
  let mut y0 = @path.f32_to_i32(points[0].y * scale)
  let mut x1 = @path.f32_to_i32(points[1].x * scale)
  let mut y1 = @path.f32_to_i32(points[1].y * scale)
  let mut x2 = @path.f32_to_i32(points[2].x * scale)
  let mut y2 = @path.f32_to_i32(points[2].y * scale)
  let mut x3 = @path.f32_to_i32(points[3].x * scale)
  let mut y3 = @path.f32_to_i32(points[3].y * scale)
  let mut winding = 1
  if sort_y && y0 > y3 {
    let t = x0
    x0 = x3
    x3 = t
    let t = x1
    x1 = x2
    x2 = t
    let t = y0
    y0 = y3
    y3 = t
    let t = y1
    y1 = y2
    y2 = t
    winding = -1
  }
  let top = fdot6_round(y0)
  let bot = fdot6_round(y3)

  // are we a zero-height cubic (line)?
  if sort_y && top == bot {
    return None
  }

  // compute number of steps needed (1 << shift)
  // Can't use (center of curve - center of baseline), since center-of-curve
  // need not be the max delta from the baseline (it could even be
  // coincident) so we try just looking at the two off-curve points
  let dx = cubic_delta_from_line(x0, x1, x2, x3)
  let dy = cubic_delta_from_line(y0, y1, y2, y3)
  // add 1 (by observation)
  let mut shift = diff_to_shift(dx, dy, 2) + 1
  // need at least 1 subdivision for our bias trick
  if shift > max_coeff_shift {
    shift = max_coeff_shift
  }

  // Since our in coming data is initially shifted down by 10 (or 8 in
  // antialias). That means the most we can shift up is 8. However, we
  // compute coefficients with a 3*, so the safest upshift is really 6
  let mut up_shift = 6 // largest safe value
  let mut down_shift = shift + up_shift - 10
  if down_shift < 0 {
    down_shift = 0
    up_shift = 10 - shift
  }
  // `left_shift(-1, shift) as i8`
  let curve_count = left_shift(-1, shift) << 24 >> 24
  let curve_shift = shift
  let dshift = down_shift
  let mut b = fdot6_up_shift(3 * (x1 - x0), up_shift)
  let mut c = fdot6_up_shift(3 * (x0 - x1 - x1 + x2), up_shift)
  let mut d = fdot6_up_shift(x3 + 3 * (x1 - x2) - x0, up_shift)
  let cx = fdot6_to_fdot16(x0)
  let cdx = b + (c >> shift) + (d >> (2 * shift)) // biased by shift
  let cddx = 2 * c + ((3 * d) >> (shift - 1)) // biased by 2*shift
  let cdddx = (3 * d) >> (shift - 1) // biased by 2*shift
  b = fdot6_up_shift(3 * (y1 - y0), up_shift)
  c = fdot6_up_shift(3 * (y0 - y1 - y1 + y2), up_shift)
  d = fdot6_up_shift(y3 + 3 * (y1 - y2) - y0, up_shift)
  let cy = fdot6_to_fdot16(y0)
  let cdy = b + (c >> shift) + (d >> (2 * shift)) // biased by shift
  let cddy = 2 * c + ((3 * d) >> (shift - 1)) // biased by 2*shift
  let cdddy = (3 * d) >> (shift - 1) // biased by 2*shift
  let c_last_x = fdot6_to_fdot16(x3)
  let c_last_y = fdot6_to_fdot16(y3)
  let e = Edge::line_default()
  Some({
    ..e,
    kind: Cubic,
    winding,
    curve_count,
    curve_shift,
    dshift,
    cx,
    cy,
    cdx,
    cdy,
    cddx,
    cddy,
    cdddx,
    cdddy,
    c_last_x,
    c_last_y,
  })
}

///|
/// `CubicEdge::update`.
fn Edge::update_cubic(self : Edge) -> Bool {
  let mut success = false
  let mut count = self.curve_count
  let mut oldx = self.cx
  let mut oldy = self.cy
  let mut newx = 0
  let mut newy = 0
  let ddshift = self.curve_shift
  let dshift = self.dshift
  while true {
    count += 1
    if count < 0 {
      newx = oldx + (self.cdx >> dshift)
      self.cdx += self.cddx >> ddshift
      self.cddx += self.cdddx
      newy = oldy + (self.cdy >> dshift)
      self.cdy += self.cddy >> ddshift
      self.cddy += self.cdddy
    } else {
      // last segment
      newx = self.c_last_x
      newy = self.c_last_y
    }

    // we want to say debug_assert(oldy <= newy), but our finite fixedpoint
    // doesn't always achieve that, so we have to explicitly pin it here.
    if newy < oldy {
      newy = oldy
    }
    success = self.update_line(oldx, oldy, newx, newy)
    oldx = newx
    oldy = newy
    if count == 0 || success {
      break
    }
  }
  self.cx = newx
  self.cy = newy
  self.curve_count = count
  success
}

///|
/// This correctly favors the lower-pixel when y0 is on a 1/2 pixel boundary
fn compute_dy(top : Int, y0 : Int) -> Int {
  left_shift(top, 6) + 32 - y0
}

///|
fn diff_to_shift(dx : Int, dy : Int, shift_aa : Int) -> Int {
  // cheap calc of distance from center of p0-p2 to the center of the curve
  let mut dist = cheap_distance(dx, dy)

  // shift down dist (it is currently in dot6)
  // down by 3 should give us 1/8 pixel accuracy (assuming our dist is
  // accurate...) this is chosen by heuristic: make it as big as possible (to
  // minimize segments) ... but small enough so that our curves still look
  // smooth. When shift > 0, we're using AA and everything is scaled up so we
  // can lower the accuracy.
  dist = (dist + (1 << (2 + shift_aa))) >> (3 + shift_aa)

  // each subdivision (shift value) cuts this dist (error) by 1/4
  (32 - dist.clz()) >> 1
}

///|
fn cheap_distance(dx : Int, dy : Int) -> Int {
  let dx = dx.abs()
  let dy = dy.abs()
  // return max + min/2
  if dx > dy {
    dx + (dy >> 1)
  } else {
    dy + (dx >> 1)
  }
}

///|
/// In LineEdge::new, QuadraticEdge::new, CubicEdge::new, the first thing we
/// do is to convert the points into FDot6. This is modulated by the shift
/// parameter, which will either be 0, or something like 2 for antialiasing.
fn fdot6_to_fixed_div2(value : Int) -> Int {
  // we want to return SkFDot6ToFixed(value >> 1), but we don't want to throw
  // away data in value, so just perform a modify up-shift
  left_shift(value, 16 - 6 - 1)
}

///|
fn fdot6_up_shift(x : Int, up_shift : Int) -> Int {
  left_shift(x, up_shift)
}

///|
/// f(1/3) = (8a + 12b + 6c + d) / 27
/// f(2/3) = (a + 6b + 12c + 8d) / 27
///
/// f(1/3)-b = (8a - 15b + 6c + d) / 27
/// f(2/3)-c = (a + 6b - 15c + 8d) / 27
///
/// use 16/512 to approximate 1/27
fn cubic_delta_from_line(a : Int, b : Int, c : Int, d : Int) -> Int {
  // since our parameters may be negative, we don't use <<
  let one_third = ((a * 8 - b * 15 + 6 * c + d) * 19) >> 9
  let two_third = ((a + 6 * b - c * 15 + d * 8) * 19) >> 9
  let x = one_third.abs()
  let y = two_third.abs()
  if x > y {
    x
  } else {
    y
  }
}
