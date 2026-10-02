// Port of `tiny-skia/src/line_clipper.rs`.

///|
let line_clipper_max_points : Int = 4

///|
/// Clip the line pts[0]...pts[1] against clip, ignoring segments that lie
/// completely above or below the clip. For portions to the left or right,
/// turn those into vertical line segments that are aligned to the edge of
/// the clip.
///
/// Return the number of line segments that result, and store the end-points
/// of those segments sequentially in lines as follows:
///
/// 1st segment: lines[0]..lines[1]
/// 2nd segment: lines[1]..lines[2]
/// 3rd segment: lines[2]..lines[3]
///
/// Returns the points (an empty array if the line is clipped out).
fn line_clip(
  src : FixedArray[@path.Point],
  clip : @path.Rect,
  can_cull_to_the_right : Bool,
) -> Array[@path.Point] {
  let (i0, i1) = if src[0].y < src[1].y { (0, 1) } else { (1, 0) }
  let mut index0 = i0
  let mut index1 = i1

  // Check if we're completely clipped out in Y (above or below)
  if src[index1].y <= clip.top() {
    // we're above the clip
    return []
  }
  if src[index0].y >= clip.bottom() {
    // we're below the clip
    return []
  }

  // Chop in Y to produce a single segment, stored in tmp[0..1]
  let tmp = [src[0], src[1]]

  // now compute intersections
  if src[index0].y < clip.top() {
    tmp[index0] = @path.Point::from_xy(
      sect_with_horizontal(src, clip.top()),
      clip.top(),
    )
  }
  if tmp[index1].y > clip.bottom() {
    tmp[index1] = @path.Point::from_xy(
      sect_with_horizontal(src, clip.bottom()),
      clip.bottom(),
    )
  }

  // Chop it into 1..3 segments that are wholly within the clip in X.

  // temp storage for up to 3 segments
  let result_storage = Array::make(line_clipper_max_points, @path.Point::zero())
  let mut line_count = 1
  let mut reverse = false
  if src[0].x < src[1].x {
    index0 = 0
    index1 = 1
    reverse = false
  } else {
    index0 = 1
    index1 = 0
    reverse = true
  }
  let result : Array[@path.Point] = if tmp[index1].x <= clip.left() {
    // wholly to the left
    tmp[0] = { x: clip.left(), y: tmp[0].y, }
    tmp[1] = { x: clip.left(), y: tmp[1].y, }
    reverse = false
    tmp
  } else if tmp[index0].x >= clip.right() {
    // wholly to the right
    if can_cull_to_the_right {
      return []
    }
    tmp[0] = { x: clip.right(), y: tmp[0].y, }
    tmp[1] = { x: clip.right(), y: tmp[1].y, }
    reverse = false
    tmp
  } else {
    let mut offset = 0
    if tmp[index0].x < clip.left() {
      result_storage[offset] = @path.Point::from_xy(clip.left(), tmp[index0].y)
      offset += 1
      result_storage[offset] = @path.Point::from_xy(
        clip.left(),
        sect_clamp_with_vertical(tmp, clip.left()),
      )
    } else {
      result_storage[offset] = tmp[index0]
    }
    offset += 1
    if tmp[index1].x > clip.right() {
      result_storage[offset] = @path.Point::from_xy(
        clip.right(),
        sect_clamp_with_vertical(tmp, clip.right()),
      )
      offset += 1
      result_storage[offset] = @path.Point::from_xy(clip.right(), tmp[index1].y)
    } else {
      result_storage[offset] = tmp[index1]
    }
    line_count = offset
    result_storage
  }

  // Now copy the results into the caller's lines[] parameter
  let points = Array::make(line_count + 1, @path.Point::zero())
  if reverse {
    // copy the pts in reverse order to maintain winding order
    for i in 0..<=line_count {
      points[line_count - i] = result[i]
    }
  } else {
    for i in 0..<=line_count {
      points[i] = result[i]
    }
  }
  points
}

///|
/// Returns X coordinate of intersection with horizontal line at Y.
fn sect_with_horizontal(src : ArrayView[@path.Point], y : Float) -> Float {
  let dy = src[1].y - src[0].y
  if is_nearly_zero(dy) {
    ave(src[0].x, src[1].x)
  } else {
    // need the extra precision so we don't compute a value that exceeds
    // our original limits
    let x0 = src[0].x.to_double()
    let y0 = src[0].y.to_double()
    let x1 = src[1].x.to_double()
    let y1 = src[1].y.to_double()
    let result = x0 + (y.to_double() - y0) * (x1 - x0) / (y1 - y0)

    // The computed X value might still exceed [X0..X1] due to quantum flux
    // when the doubles were added and subtracted, so we have to pin the
    // answer :(
    pin_unsorted_f64(result, x0, x1).to_float()
  }
}

///|
fn sect_clamp_with_vertical(src : ArrayView[@path.Point], x : Float) -> Float {
  let y = sect_with_vertical(src, x)
  // Our caller expects y to be between src[0].y and src[1].y (unsorted), but
  // due to the numerics of floats/doubles, we might have computed a value
  // slightly outside of that, so we have to manually clamp afterwards.
  // See skbug.com/7491
  pin_unsorted_f32(y, src[0].y, src[1].y)
}

///|
/// Returns Y coordinate of intersection with vertical line at X.
fn sect_with_vertical(src : ArrayView[@path.Point], x : Float) -> Float {
  let dx = src[1].x - src[0].x
  if is_nearly_zero(dx) {
    ave(src[0].y, src[1].y)
  } else {
    // need the extra precision so we don't compute a value that exceeds
    // our original limits
    let x0 = src[0].x.to_double()
    let y0 = src[0].y.to_double()
    let x1 = src[1].x.to_double()
    let y1 = src[1].y.to_double()
    let result = y0 + (x.to_double() - x0) * (y1 - y0) / (x1 - x0)
    result.to_float()
  }
}

///|
fn pin_unsorted_f32(value : Float, limit0 : Float, limit1 : Float) -> Float {
  let (limit0, limit1) = if limit1 < limit0 {
    (limit1, limit0)
  } else {
    (limit0, limit1)
  }
  // now the limits are sorted
  if value < limit0 {
    limit0
  } else if value > limit1 {
    limit1
  } else {
    value
  }
}

///|
fn pin_unsorted_f64(value : Double, limit0 : Double, limit1 : Double) -> Double {
  let (limit0, limit1) = if limit1 < limit0 {
    (limit1, limit0)
  } else {
    (limit0, limit1)
  }
  // now the limits are sorted
  if value < limit0 {
    limit0
  } else if value > limit1 {
    limit1
  } else {
    value
  }
}

///|
/// Intersect the line segment against the rect. If there is a non-empty
/// resulting segment, return it. If there is no intersection, return `None`.
///
/// `clip` is assumed to be in increasing order.
fn line_intersect(
  src : FixedArray[@path.Point],
  clip : @path.Rect,
) -> FixedArray[@path.Point]? {
  let bounds = @path.Rect::from_ltrb(
    fmin(src[0].x, src[1].x),
    fmin(src[0].y, src[1].y),
    fmax(src[0].x, src[1].x),
    fmax(src[0].y, src[1].y),
  )
  if bounds is Some(bounds) {
    if contains_no_empty_check(clip, bounds) {
      return Some([src[0], src[1]])
    }

    // check for no overlap, and only permit coincident edges if the line
    // and the edge are collinear
    if nested_lt(bounds.right(), clip.left(), bounds.width()) ||
      nested_lt(clip.right(), bounds.left(), bounds.width()) ||
      nested_lt(bounds.bottom(), clip.top(), bounds.height()) ||
      nested_lt(clip.bottom(), bounds.top(), bounds.height()) {
      return None
    }
  }
  let (index0, index1) = if src[0].y < src[1].y { (0, 1) } else { (1, 0) }
  let tmp : FixedArray[@path.Point] = [src[0], src[1]]

  // now compute Y intersections
  if tmp[index0].y < clip.top() {
    tmp[index0] = @path.Point::from_xy(
      sect_with_horizontal(src, clip.top()),
      clip.top(),
    )
  }
  if tmp[index1].y > clip.bottom() {
    tmp[index1] = @path.Point::from_xy(
      sect_with_horizontal(src, clip.bottom()),
      clip.bottom(),
    )
  }
  let (index0, index1) = if tmp[0].x < tmp[1].x { (0, 1) } else { (1, 0) }

  // check for quick-reject in X again, now that we may have been chopped
  if tmp[index1].x <= clip.left() || tmp[index0].x >= clip.right() {
    // usually we will return false, but we don't if the line is vertical and
    // coincident with the clip.
    if tmp[0].x != tmp[1].x || tmp[0].x < clip.left() || tmp[0].x > clip.right() {
      return None
    }
  }
  if tmp[index0].x < clip.left() {
    tmp[index0] = @path.Point::from_xy(
      clip.left(),
      sect_with_vertical(src, clip.left()),
    )
  }
  if tmp[index1].x > clip.right() {
    tmp[index1] = @path.Point::from_xy(
      clip.right(),
      sect_with_vertical(src, clip.right()),
    )
  }
  Some(tmp)
}

///|
fn nested_lt(a : Float, b : Float, dim : Float) -> Bool {
  a <= b && (a < b || dim > 0.0)
}

///|
/// returns true if outer contains inner, even if inner is empty.
fn contains_no_empty_check(outer : @path.Rect, inner : @path.Rect) -> Bool {
  outer.left() <= inner.left() &&
  outer.top() <= inner.top() &&
  outer.right() >= inner.right() &&
  outer.bottom() >= inner.bottom()
}
