// Port of `tiny-skia/src/scan/hairline.rs`.

///|
let max_cubic_subdivide_level : Int = 9

///|
let max_quad_subdivide_level : Int = 5

///|
fn hairline_stroke_path(
  path : @path.Path,
  line_cap : @path.LineCap,
  clip : ScreenIntRect,
  blitter : &Blitter,
) -> Unit {
  hairline_stroke_path_impl(path, line_cap, clip, hair_line_rgn, blitter)
}

///|
fn hair_line_rgn(
  points : ArrayView[@path.Point],
  clip : ScreenIntRect?,
  blitter : &Blitter,
) -> Unit {
  let max : Float = 32767.0
  let fixed_bounds = @path.Rect::from_ltrb(-max, -max, max, max).unwrap()
  let clip_bounds = clip.map(c => c.to_rect())
  for i in 0..<(points.length() - 1) {
    // We have to pre-clip the line to fit in a Fixed, so we just chop the
    // line.
    guard line_intersect([points[i], points[i + 1]], fixed_bounds) is Some(pts) else {
      continue
    }
    let pts = match clip_bounds {
      Some(clip_bounds) =>
        // Perform a clip in scalar space, so we catch huge values which might
        // be missed after we convert to FDot6 (overflow).
        match line_intersect(pts, clip_bounds) {
          Some(p) => p
          None => continue
        }
      None => pts
    }
    let mut x0 = fdot6_from_f32(pts[0].x)
    let mut y0 = fdot6_from_f32(pts[0].y)
    let mut x1 = fdot6_from_f32(pts[1].x)
    let mut y1 = fdot6_from_f32(pts[1].y)
    let dx = x1 - x0
    let dy = y1 - y0
    if dx.abs() > dy.abs() {
      // mostly horizontal
      if x0 > x1 {
        // we want to go left-to-right
        let t = x0
        x0 = x1
        x1 = t
        let t = y0
        y0 = y1
        y1 = t
      }
      let mut ix0 = fdot6_round(x0)
      let ix1 = fdot6_round(x1)
      if ix0 == ix1 {
        // too short to draw
        continue
      }
      let slope = fdot16_div(dy, dx)
      let mut start_y = fdot6_to_fdot16(y0) + ((slope * ((32 - x0) & 63)) >> 6)

      // In some cases, probably due to precision/rounding issues,
      // `start_y` can become equal to the image height,
      // which will lead to panic, because we would be accessing pixels
      // outside the current memory buffer.
      // This is tiny-skia specific issue. Skia handles this part differently.
      let max_y = match clip_bounds {
        Some(clip_bounds) => fdot16_from_f32(clip_bounds.bottom())
        None => 2147483647
      }
      while true {
        if ix0 >= 0 && start_y >= 0 && start_y < max_y {
          blitter.blit_h(ix0, start_y >> 16, 1)
        }
        start_y += slope
        ix0 += 1
        if ix0 >= ix1 {
          break
        }
      }
    } else {
      // mostly vertical
      if y0 > y1 {
        // we want to go top-to-bottom
        let t = x0
        x0 = x1
        x1 = t
        let t = y0
        y0 = y1
        y1 = t
      }
      let mut iy0 = fdot6_round(y0)
      let iy1 = fdot6_round(y1)
      if iy0 == iy1 {
        // too short to draw
        continue
      }
      let slope = fdot16_div(dx, dy)
      let mut start_x = fdot6_to_fdot16(x0) + ((slope * ((32 - y0) & 63)) >> 6)
      while true {
        if start_x >= 0 && iy0 >= 0 {
          blitter.blit_h(start_x >> 16, iy0, 1)
        }
        start_x += slope
        iy0 += 1
        if iy0 >= iy1 {
          break
        }
      }
    }
  }
}

///|
fn hairline_stroke_path_impl(
  path : @path.Path,
  line_cap : @path.LineCap,
  clip : ScreenIntRect,
  line_proc : (ArrayView[@path.Point], ScreenIntRect?, &Blitter) -> Unit,
  blitter : &Blitter,
) -> Unit {
  let mut inset_clip : @path.IntRect? = None
  let mut outset_clip : @path.IntRect? = None
  {
    let cap_out : Float = if line_cap == Butt { 1.0 } else { 2.0 }
    guard path.bounds().outset(cap_out, cap_out).bind(r => r.round_out())
      is Some(ibounds) else {
      return
    }
    if clip.to_int_rect().intersect(ibounds) is None {
      return
    }
    if !clip.to_int_rect().contains(ibounds) {
      // We now cache two scalar rects, to use for culling per-segment (e.g.
      // cubic). Since we're hairlining, the "bounds" of the control points
      // isn't necessarily the limit of where a segment can draw (it might
      // draw up to 1 pixel beyond in aa-hairs).
      //
      // Compute the pt-bounds per segment is easy, so we do that, and then
      // inversely adjust the culling bounds so we can just do a straight
      // compare per segment.
      //
      // insetClip is use for quick-accept (i.e. the segment is not clipped),
      // so we inset it from the clip-bounds (since segment bounds can be off
      // by 1).
      //
      // outsetClip is used for quick-reject (i.e. the segment is entirely
      // outside), so we outset it from the clip-bounds.
      match clip.to_int_rect().make_outset(1, 1) {
        Some(v) => outset_clip = Some(v)
        None => return
      }
      match clip.to_int_rect().inset(1, 1) {
        Some(v) => inset_clip = Some(v)
        None => return
      }
    }
  }
  let clip = Some(clip)
  let mut prev_verb : @path.PathVerb = Move
  let mut first_pt = @path.Point::zero()
  let mut last_pt = @path.Point::zero()
  let iter = path.segments()
  while iter.next() is Some(segment) {
    let verb = iter.curr_verb()
    let next_verb = iter.next_verb()
    let mut last_pt2 = @path.Point::zero()
    match segment {
      MoveTo(p) => {
        first_pt = p
        last_pt = p
        last_pt2 = p
      }
      LineTo(p) => {
        let points = [last_pt, p]
        if line_cap != Butt {
          extend_pts(line_cap, prev_verb, next_verb, points)
        }
        line_proc(points[:], clip, blitter)
        last_pt = p
        last_pt2 = points[0]
      }
      QuadTo(p0, p1) => {
        let points = [last_pt, p0, p1]
        if line_cap != Butt {
          extend_pts(line_cap, prev_verb, next_verb, points)
        }
        hair_quad(
          points,
          clip,
          inset_clip,
          outset_clip,
          compute_quad_level(points),
          line_proc,
          blitter,
        )
        last_pt = p1
        last_pt2 = points[0]
      }
      CubicTo(p0, p1, p2) => {
        let points = [last_pt, p0, p1, p2]
        if line_cap != Butt {
          extend_pts(line_cap, prev_verb, next_verb, points)
        }
        hair_cubic(points, clip, inset_clip, outset_clip, line_proc, blitter)
        last_pt = p2
        last_pt2 = points[0]
      }
      Close => {
        let points = [last_pt, first_pt]
        if line_cap != Butt && prev_verb == Move {
          // cap moveTo/close to match svg expectations for degenerate segments
          extend_pts(line_cap, prev_verb, next_verb, points)
        }
        line_proc(points[:], clip, blitter)
        last_pt2 = points[0]
      }
    }
    if line_cap != Butt {
      if prev_verb == Move && verb is (Line | Quad | Cubic) {
        first_pt = last_pt2 // the curve moved the initial point, so close to it instead
      }
      prev_verb = verb
    }
  }
}

///|
/// Extend pts[0] and pts[n-1] so that the hairline covers the cap.
fn extend_pts(
  line_cap : @path.LineCap,
  prev_verb : @path.PathVerb,
  next_verb : @path.PathVerb?,
  points : Array[@path.Point],
) -> Unit {
  // The area of a circle is PI*R*R. For a unit circle, R=1/2, and the cap
  // covers half of that.
  let cap_outset : Float = if line_cap == Square { 0.5 } else { float_pi / 8.0 }
  let n = points.length()
  if prev_verb == Move {
    let first = points[0]
    let mut offset = 0
    let mut controls = n - 1
    let mut tangent = @path.Point::zero()
    while true {
      offset += 1
      tangent = first - points[offset]
      if !tangent.is_zero() {
        break
      }
      controls -= 1
      if controls == 0 {
        break
      }
    }
    if tangent.is_zero() {
      tangent = @path.Point::from_xy(1.0, 0.0)
      controls = n - 1 // If all points are equal, move all but one.
    } else {
      tangent = pt_normalize(tangent)
    }
    offset = 0
    while true {
      // If the end point and control points are equal, loop to move them in
      // tandem.
      let p = points[offset]
      points[offset] = {
        x: p.x + tangent.x * cap_outset,
        y: p.y + tangent.y * cap_outset,
      }
      offset += 1
      controls += 1
      if controls >= n {
        break
      }
    }
  }
  if next_verb is (Some(Move) | Some(Close) | None) {
    let last = points[n - 1]
    let mut offset = n - 1
    let mut controls = n - 1
    let mut tangent = @path.Point::zero()
    while true {
      offset -= 1
      tangent = last - points[offset]
      if !tangent.is_zero() {
        break
      }
      controls -= 1
      if controls == 0 {
        break
      }
    }
    if tangent.is_zero() {
      tangent = @path.Point::from_xy(-1.0, 0.0)
      controls = n - 1
    } else {
      tangent = pt_normalize(tangent)
    }
    offset = n - 1
    while true {
      let p = points[offset]
      points[offset] = {
        x: p.x + tangent.x * cap_outset,
        y: p.y + tangent.y * cap_outset,
      }
      offset -= 1
      controls += 1
      if controls >= n {
        break
      }
    }
  }
}

///|
fn hair_quad(
  points : Array[@path.Point],
  clip : ScreenIntRect?,
  inset_clip : @path.IntRect?,
  outset_clip : @path.IntRect?,
  level : Int,
  line_proc : (ArrayView[@path.Point], ScreenIntRect?, &Blitter) -> Unit,
  blitter : &Blitter,
) -> Unit {
  let mut clip = clip
  if inset_clip is Some(inset_clip) {
    let inset_clip = inset_clip.to_rect()
    guard outset_clip is Some(outset_clip) else { return }
    let outset_clip = outset_clip.to_rect()
    guard compute_nocheck_bounds(points) is Some(bounds) else { return }
    if !geometric_overlap(outset_clip, bounds) {
      return // nothing to do
    } else if geometric_contains(inset_clip, bounds) {
      clip = None
    }
  }
  hair_quad2(points, clip, level, line_proc, blitter)
}

///|
/// `compute_nocheck_quad_bounds` / `compute_nocheck_cubic_bounds`.
fn compute_nocheck_bounds(points : Array[@path.Point]) -> @path.Rect? {
  let mut min = points[0].to_f32x2()
  let mut max = min
  for i in 1..<points.length() {
    let pair = points[i].to_f32x2()
    min = min.min(pair)
    max = max.max(pair)
  }
  @path.Rect::from_ltrb(min.x(), min.y(), max.x(), max.y())
}

///|
fn geometric_overlap(a : @path.Rect, b : @path.Rect) -> Bool {
  a.left() < b.right() &&
  b.left() < a.right() &&
  a.top() < b.bottom() &&
  b.top() < a.bottom()
}

///|
fn geometric_contains(outer : @path.Rect, inner : @path.Rect) -> Bool {
  inner.right() <= outer.right() &&
  inner.left() >= outer.left() &&
  inner.bottom() <= outer.bottom() &&
  inner.top() >= outer.top()
}

///|
fn hair_quad2(
  points : Array[@path.Point],
  clip : ScreenIntRect?,
  level : Int,
  line_proc : (ArrayView[@path.Point], ScreenIntRect?, &Blitter) -> Unit,
  blitter : &Blitter,
) -> Unit {
  let coeff = @path.QuadCoeff::from_points(points[:])
  let lines = 1 << level
  let tmp = Array::make(lines + 1, @path.Point::zero())
  tmp[0] = points[0]
  let mut t = @path.F32x2::default()
  let dt = @path.F32x2::splat((1.0 : Float) / Float::from_int(lines))
  for i in 1..<lines {
    t = t + dt
    let v = (coeff.a * t + coeff.b) * t + coeff.c
    tmp[i] = @path.Point::from_xy(v.x(), v.y())
  }
  tmp[lines] = points[2]
  line_proc(tmp[:], clip, blitter)
}

///|
fn compute_quad_level(points : Array[@path.Point]) -> Int {
  let d = compute_int_quad_dist(points)
  // Quadratics approach the line connecting their start and end points
  // 4x closer with each subdivision, so we compute the number of
  // subdivisions to be the minimum need to get that distance to be less
  // than a pixel.
  let mut level = (33 - d.reinterpret_as_int().clz()) >> 1
  // sanity check on level (from the previous version)
  if level > max_quad_subdivide_level {
    level = max_quad_subdivide_level
  }
  level
}

///|
fn compute_int_quad_dist(points : Array[@path.Point]) -> UInt {
  // compute the vector between the control point ([1]) and the middle of the
  // line connecting the start and end ([0] and [2])
  let dx = fabs(half(points[0].x + points[2].x) - points[1].x)
  let dy = fabs(half(points[0].y + points[2].y) - points[1].y)

  // convert to whole pixel values (use ceiling to be conservative).
  // assign to unsigned so we can safely add 1/2 of the smaller and still fit
  // in u32, since T::saturate_from() returns 31 bits at most.
  let idx = i32_saturate_from(ceilf(dx)).reinterpret_as_uint()
  let idy = i32_saturate_from(ceilf(dy)).reinterpret_as_uint()

  // use the cheap approx for distance
  if idx > idy {
    idx + (idy >> 1)
  } else {
    idy + (idx >> 1)
  }
}

///|
fn hair_cubic(
  points : Array[@path.Point],
  clip : ScreenIntRect?,
  inset_clip : @path.IntRect?,
  outset_clip : @path.IntRect?,
  line_proc : (ArrayView[@path.Point], ScreenIntRect?, &Blitter) -> Unit,
  blitter : &Blitter,
) -> Unit {
  let mut clip = clip
  if inset_clip is Some(inset_clip) {
    let inset_clip = inset_clip.to_rect()
    guard outset_clip is Some(outset_clip) else { return }
    let outset_clip = outset_clip.to_rect()
    guard compute_nocheck_bounds(points) is Some(bounds) else { return }
    if !geometric_overlap(outset_clip, bounds) {
      return // noting to do
    } else if geometric_contains(inset_clip, bounds) {
      clip = None
    }
  }
  if quick_cubic_niceness_check(points) {
    hair_cubic2(points, clip, line_proc, blitter)
  } else {
    let tmp = Array::make(13, @path.Point::zero())
    let t_values = ts_new_t_values()
    let count = chop_cubic_at_max_curvature(points[:], t_values, tmp)
    for i in 0..<count {
      let offset = i * 3
      let new_points = [
        tmp[offset],
        tmp[offset + 1],
        tmp[offset + 2],
        tmp[offset + 3],
      ]
      hair_cubic2(new_points, clip, line_proc, blitter)
    }
  }
}

///|
/// The off-curve points are "inside" the limits of the on-curve points.
fn quick_cubic_niceness_check(points : Array[@path.Point]) -> Bool {
  lt_90(points[1], points[0], points[3]) &&
  lt_90(points[2], points[0], points[3]) &&
  lt_90(points[1], points[3], points[0]) &&
  lt_90(points[2], points[3], points[0])
}

///|
fn lt_90(p0 : @path.Point, pivot : @path.Point, p2 : @path.Point) -> Bool {
  (p0 - pivot).dot(p2 - pivot) >= 0.0
}

///|
fn hair_cubic2(
  points : Array[@path.Point],
  clip : ScreenIntRect?,
  line_proc : (ArrayView[@path.Point], ScreenIntRect?, &Blitter) -> Unit,
  blitter : &Blitter,
) -> Unit {
  let lines = compute_cubic_segments(points)
  if lines == 1 {
    line_proc([points[0], points[3]][:], clip, blitter)
    return
  }
  let coeff = @path.CubicCoeff::from_points(points[:])
  let tmp = Array::make(
    (1 << max_cubic_subdivide_level) + 1,
    @path.Point::zero(),
  )
  let dt = @path.F32x2::splat((1.0 : Float) / Float::from_int(lines))
  let mut t = @path.F32x2::default()
  tmp[0] = points[0]
  for i in 1..<lines {
    t = t + dt
    tmp[i] = @path.Point::from_f32x2(
      ((coeff.a * t + coeff.b) * t + coeff.c) * t + coeff.d,
    )
  }
  let mut all_finite = true
  for p in tmp {
    if !p.is_finite() {
      all_finite = false
      break
    }
  }
  if all_finite {
    tmp[lines] = points[3]
    line_proc(tmp[0:lines + 1], clip, blitter)
  } else {
    // else some point(s) are non-finite, so don't draw
  }
}

///|
fn compute_cubic_segments(points : Array[@path.Point]) -> Int {
  let p0 = points[0].to_f32x2()
  let p1 = points[1].to_f32x2()
  let p2 = points[2].to_f32x2()
  let p3 = points[3].to_f32x2()
  let one_third = @path.F32x2::splat((1.0 : Float) / 3.0)
  let two_third = @path.F32x2::splat((2.0 : Float) / 3.0)
  let p13 = one_third * p3 + two_third * p0
  let p23 = one_third * p0 + two_third * p3
  let diff = (p1 - p13).abs().max((p2 - p23).abs()).max_component()
  let mut tol : Float = 1.0 / 8.0
  for i in 0..<max_cubic_subdivide_level {
    if diff < tol {
      return 1 << i
    }
    tol *= 4.0
  }
  1 << max_cubic_subdivide_level
}
