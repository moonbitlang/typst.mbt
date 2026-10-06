// Port of `tiny-skia-path` 0.12.0 `src/rect.rs`.

///|
/// An integer rectangle.
///
/// # Guarantees
///
/// - Width and height are in 1..=i32::MAX range.
/// - x+width and y+height does not overflow.
pub struct IntRect {
  priv x : Int
  priv y : Int
  priv width : UInt
  priv height : UInt
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IntRect with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IntRect with @debug.Debug::{to_repr}

///|
/// Creates a new `IntRect`.
pub fn IntRect::from_xywh(
  x : Int,
  y : Int,
  width : UInt,
  height : UInt,
) -> IntRect? {
  if width > 0x7FFFFFFFU || height > 0x7FFFFFFFU {
    return None
  }
  guard i32_checked_add(x, width.reinterpret_as_int()) is Some(_) else {
    return None
  }
  guard i32_checked_add(y, height.reinterpret_as_int()) is Some(_) else {
    return None
  }
  if width == 0 || height == 0 {
    return None
  }
  Some({ x, y, width, height, })
}

///|
/// Creates a new `IntRect`.
pub fn IntRect::from_ltrb(
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> IntRect? {
  guard i32_checked_sub(right, left) is Some(width) && width >= 0 else {
    return None
  }
  guard i32_checked_sub(bottom, top) is Some(height) && height >= 0 else {
    return None
  }
  IntRect::from_xywh(
    left,
    top,
    width.reinterpret_as_uint(),
    height.reinterpret_as_uint(),
  )
}

///|
/// Returns rect's X position.
pub fn IntRect::x(self : IntRect) -> Int {
  self.x
}

///|
/// Returns rect's Y position.
pub fn IntRect::y(self : IntRect) -> Int {
  self.y
}

///|
/// Returns rect's width.
pub fn IntRect::width(self : IntRect) -> UInt {
  self.width
}

///|
/// Returns rect's height.
pub fn IntRect::height(self : IntRect) -> UInt {
  self.height
}

///|
/// Returns rect's left edge.
pub fn IntRect::left(self : IntRect) -> Int {
  self.x
}

///|
/// Returns rect's top edge.
pub fn IntRect::top(self : IntRect) -> Int {
  self.y
}

///|
/// Returns rect's right edge.
pub fn IntRect::right(self : IntRect) -> Int {
  // No overflow is guaranteed by constructors.
  self.x + self.width.reinterpret_as_int()
}

///|
/// Returns rect's bottom edge.
pub fn IntRect::bottom(self : IntRect) -> Int {
  // No overflow is guaranteed by constructors.
  self.y + self.height.reinterpret_as_int()
}

///|
/// Returns rect's size.
pub fn IntRect::size(self : IntRect) -> IntSize {
  IntSize::from_wh_safe(self.width, self.height)
}

///|
/// Checks that the rect is completely includes `other` Rect.
pub fn IntRect::contains(self : IntRect, other : IntRect) -> Bool {
  self.x <= other.x &&
  self.y <= other.y &&
  self.right() >= other.right() &&
  self.bottom() >= other.bottom()
}

///|
/// Returns an intersection of two rectangles.
///
/// Returns `None` otherwise.
pub fn IntRect::intersect(self : IntRect, other : IntRect) -> IntRect? {
  let left = if self.x >= other.x { self.x } else { other.x }
  let top = if self.y >= other.y { self.y } else { other.y }
  let right = if self.right() <= other.right() {
    self.right()
  } else {
    other.right()
  }
  let bottom = if self.bottom() <= other.bottom() {
    self.bottom()
  } else {
    other.bottom()
  }
  guard i32_checked_sub(right, left) is Some(w) && w >= 0 else { return None }
  guard i32_checked_sub(bottom, top) is Some(h) && h >= 0 else { return None }
  IntRect::from_xywh(
    left,
    top,
    w.reinterpret_as_uint(),
    h.reinterpret_as_uint(),
  )
}

///|
/// Insets the rectangle.
pub fn IntRect::inset(self : IntRect, dx : Int, dy : Int) -> IntRect? {
  IntRect::from_ltrb(
    self.left() + dx,
    self.top() + dy,
    self.right() - dx,
    self.bottom() - dy,
  )
}

///|
/// Outsets the rectangle.
pub fn IntRect::make_outset(self : IntRect, dx : Int, dy : Int) -> IntRect? {
  IntRect::from_ltrb(
    i32_saturating_sub(self.left(), dx),
    i32_saturating_sub(self.top(), dy),
    i32_saturating_add(self.right(), dx),
    i32_saturating_add(self.bottom(), dy),
  )
}

///|
/// Translates the rect by the specified offset.
pub fn IntRect::translate(self : IntRect, tx : Int, ty : Int) -> IntRect? {
  IntRect::from_xywh(self.x() + tx, self.y() + ty, self.width(), self.height())
}

///|
/// Translates the rect to the specified position.
pub fn IntRect::translate_to(self : IntRect, x : Int, y : Int) -> IntRect? {
  IntRect::from_xywh(x, y, self.width(), self.height())
}

///|
/// Converts into `Rect`.
pub fn IntRect::to_rect(self : IntRect) -> Rect {
  // Can't fail, because `IntRect` is always valid.
  Rect::from_ltrb(
    i32_as_f32(self.x),
    i32_as_f32(self.y),
    i32_as_f32(self.x) + u32_as_f32(self.width),
    i32_as_f32(self.y) + u32_as_f32(self.height),
  ).unwrap()
}

///|
/// A rectangle defined by left, top, right and bottom edges.
///
/// Can have zero width and/or height. But not a negative one.
///
/// # Guarantees
///
/// - All values are finite.
/// - Left edge is <= right.
/// - Top edge is <= bottom.
/// - Width and height are <= f32::MAX.
pub struct Rect {
  priv left : FiniteF32
  priv top : FiniteF32
  priv right : FiniteF32
  priv bottom : FiniteF32
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with @debug.Debug::{to_repr}

///|
pub impl Show for Rect with fn output(self, logger) {
  logger.write_string(
    "Rect { left: \{self.left.get()}, top: \{self.top.get()}, right: \{self.right.get()}, bottom: \{self.bottom.get()} }",
  )
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Rect with Show::{to_string, output}

///|
/// Creates new `Rect`.
pub fn Rect::from_ltrb(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> Rect? {
  guard FiniteF32::new(left) is Some(left) else { return None }
  guard FiniteF32::new(top) is Some(top) else { return None }
  guard FiniteF32::new(right) is Some(right) else { return None }
  guard FiniteF32::new(bottom) is Some(bottom) else { return None }
  if left.get() <= right.get() && top.get() <= bottom.get() {
    // Width and height must not overflow.
    guard checked_f32_sub(right.get(), left.get()) is Some(_) else {
      return None
    }
    guard checked_f32_sub(bottom.get(), top.get()) is Some(_) else {
      return None
    }
    Some({ left, top, right, bottom, })
  } else {
    None
  }
}

///|
/// Creates new `Rect`.
pub fn Rect::from_xywh(x : Float, y : Float, w : Float, h : Float) -> Rect? {
  Rect::from_ltrb(x, y, w + x, h + y)
}

///|
/// Returns the left edge.
pub fn Rect::left(self : Rect) -> Float {
  self.left.get()
}

///|
/// Returns the top edge.
pub fn Rect::top(self : Rect) -> Float {
  self.top.get()
}

///|
/// Returns the right edge.
pub fn Rect::right(self : Rect) -> Float {
  self.right.get()
}

///|
/// Returns the bottom edge.
pub fn Rect::bottom(self : Rect) -> Float {
  self.bottom.get()
}

///|
/// Returns rect's X position.
pub fn Rect::x(self : Rect) -> Float {
  self.left.get()
}

///|
/// Returns rect's Y position.
pub fn Rect::y(self : Rect) -> Float {
  self.top.get()
}

///|
/// Returns rect's width.
pub fn Rect::width(self : Rect) -> Float {
  self.right.get() - self.left.get()
}

///|
/// Returns rect's height.
pub fn Rect::height(self : Rect) -> Float {
  self.bottom.get() - self.top.get()
}

///|
/// Returns true if the rect is empty.
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.left == self.right || self.top == self.bottom
}

///|
/// Converts into an `IntRect` by adding 0.5 and discarding the fractional
/// portion.
///
/// Width and height are guarantee to be >= 1.
pub fn Rect::round(self : Rect) -> IntRect? {
  let left = i32_saturate_round(self.left())
  let top = i32_saturate_round(self.top())
  let right = i32_saturate_round(self.right())
  let bottom = i32_saturate_round(self.bottom())
  let w = i32_saturating_sub(right, left)
  let h = i32_saturating_sub(bottom, top)
  IntRect::from_xywh(
    left,
    top,
    (if w > 1 { w } else { 1 }).reinterpret_as_uint(),
    (if h > 1 { h } else { 1 }).reinterpret_as_uint(),
  )
}

///|
/// Converts into an `IntRect` rounding outwards.
///
/// Width and height are guarantee to be >= 1.
pub fn Rect::round_out(self : Rect) -> IntRect? {
  let left = i32_saturate_floor(self.left())
  let top = i32_saturate_floor(self.top())
  let right = i32_saturate_ceil(self.right())
  let bottom = i32_saturate_ceil(self.bottom())
  let w = i32_saturating_sub(right, left)
  let h = i32_saturating_sub(bottom, top)
  IntRect::from_xywh(
    left,
    top,
    (if w > 1 { w } else { 1 }).reinterpret_as_uint(),
    (if h > 1 { h } else { 1 }).reinterpret_as_uint(),
  )
}

///|
/// Returns an intersection of two rectangles.
///
/// Returns `None` otherwise.
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect? {
  let left = fmax(self.x(), other.x())
  let top = fmax(self.y(), other.y())
  let right = fmin(self.right(), other.right())
  let bottom = fmin(self.bottom(), other.bottom())
  Rect::from_ltrb(left, top, right, bottom)
}

///|
/// Returns the union of two rectangles.
///
/// Returns `None` if the width or height would overflow.
pub fn Rect::join(self : Rect, other : Rect) -> Rect? {
  if other.is_empty() {
    return Some(self)
  }
  if self.is_empty() {
    return Some(other)
  }
  let left = fmin(self.x(), other.x())
  let top = fmin(self.y(), other.y())
  let right = fmax(self.right(), other.right())
  let bottom = fmax(self.bottom(), other.bottom())
  Rect::from_ltrb(left, top, right, bottom)
}

///|
/// Creates a Rect from Point array.
///
/// Returns None if count is zero or if Point array contains an infinity or NaN.
pub fn Rect::from_points(points : ArrayView[Point]) -> Rect? {
  let mut offset = 0
  let mut min = F32x4::default()
  let mut max = F32x4::default()

  // Handle trivial-size lists without creating vectors, since they won't
  // actually use the vector min/max code
  match points.length() {
    0 => return None
    1 => {
      let { x, y, } = points[0]
      return Rect::from_xywh(x, y, 0.0, 0.0)
    }
    2 => {
      let { x: x0, y: y0, } = points[0]
      let { x: x1, y: y1, } = points[1]
      // Avoid min/max to preserve a NaN for rejection by from_ltrb
      let (l, r) = if x0 < x1 { (x0, x1) } else { (x1, x0) }
      let (t, b) = if y0 < y1 { (y0, y1) } else { (y1, y0) }
      return Rect::from_ltrb(l, t, r, b)
    }
    i if (i & 1) != 0 => {
      let pt = points[0]
      min = F32x4(pt.x, pt.y, pt.x, pt.y)
      max = min
      offset = 1
    }
    _ => {
      let pt0 = points[0]
      let pt1 = points[1]
      min = F32x4(pt0.x, pt0.y, pt1.x, pt1.y)
      max = min
      offset = 2
    }
  }
  let mut accum = F32x4::default()
  while offset != points.length() {
    let pt0 = points[offset + 0]
    let pt1 = points[offset + 1]
    let xy = F32x4(pt0.x, pt0.y, pt1.x, pt1.y)
    accum = accum * xy
    min = min.min(xy)
    max = max.max(xy)
    offset += 2
  }
  let all_finite = accum * F32x4::default() == F32x4::default()
  if all_finite {
    Rect::from_ltrb(
      fmin(min.0, min.2),
      fmin(min.1, min.3),
      fmax(max.0, max.2),
      fmax(max.1, max.3),
    )
  } else {
    None
  }
}

///|
/// Insets the rectangle by the specified offset.
pub fn Rect::inset(self : Rect, dx : Float, dy : Float) -> Rect? {
  Rect::from_ltrb(
    self.left() + dx,
    self.top() + dy,
    self.right() - dx,
    self.bottom() - dy,
  )
}

///|
/// Outsets the rectangle by the specified offset.
pub fn Rect::outset(self : Rect, dx : Float, dy : Float) -> Rect? {
  self.inset(-dx, -dy)
}

///|
/// Transforms the rect using the provided `Transform`.
///
/// If the transform is a skew, the result will be a bounding box around the
/// skewed rectangle.
pub fn Rect::transform(self : Rect, ts : Transform) -> Rect? {
  if ts.is_identity() {
    Some(self)
  } else if ts.has_skew() {
    // we need to transform all 4 corners
    let lt = Point::from_xy(self.left(), self.top())
    let rt = Point::from_xy(self.right(), self.top())
    let lb = Point::from_xy(self.left(), self.bottom())
    let rb = Point::from_xy(self.right(), self.bottom())
    let pts = [lt, rt, lb, rb]
    ts.map_points(pts)
    Rect::from_points(pts[:])
  } else {
    // Faster (more common) case
    let lt = Point::from_xy(self.left(), self.top())
    let rb = Point::from_xy(self.right(), self.bottom())
    let pts = [lt, rb]
    ts.map_points(pts)
    Rect::from_points(pts[:])
  }
}

///|
/// Applies a bounding box transform.
pub fn Rect::bbox_transform(self : Rect, bbox : NonZeroRect) -> Rect {
  let x = self.x() * bbox.width() + bbox.x()
  let y = self.y() * bbox.height() + bbox.y()
  let w = self.width() * bbox.width()
  let h = self.height() * bbox.height()
  Rect::from_xywh(x, y, w, h).unwrap()
}

///|
/// Converts into [`NonZeroRect`].
pub fn Rect::to_non_zero_rect(self : Rect) -> NonZeroRect? {
  NonZeroRect::from_xywh(self.x(), self.y(), self.width(), self.height())
}

///|
fn checked_f32_sub(a : Float, b : Float) -> Float? {
  let n = a.to_double() - b.to_double()
  // Not sure if this is perfectly correct.
  if n > @float.min_value.to_double() && n < @float.max_value.to_double() {
    Some(Float::from_double(n))
  } else {
    None
  }
}

///|
/// A rectangle defined by left, top, right and bottom edges.
///
/// Similar to [`Rect`], but width and height guarantee to be non-zero and
/// positive.
///
/// # Guarantees
///
/// - All values are finite.
/// - Left edge is < right.
/// - Top edge is < bottom.
/// - Width and height are <= f32::MAX.
/// - Width and height are > 0.0
pub struct NonZeroRect {
  priv left : FiniteF32
  priv top : FiniteF32
  priv right : FiniteF32
  priv bottom : FiniteF32
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NonZeroRect with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NonZeroRect with @debug.Debug::{to_repr}

///|
pub impl Show for NonZeroRect with fn output(self, logger) {
  logger.write_string(
    "NonZeroRect { left: \{self.left.get()}, top: \{self.top.get()}, right: \{self.right.get()}, bottom: \{self.bottom.get()} }",
  )
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NonZeroRect with Show::{to_string, output}

///|
/// Creates new `NonZeroRect`.
pub fn NonZeroRect::from_ltrb(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> NonZeroRect? {
  guard FiniteF32::new(left) is Some(left) else { return None }
  guard FiniteF32::new(top) is Some(top) else { return None }
  guard FiniteF32::new(right) is Some(right) else { return None }
  guard FiniteF32::new(bottom) is Some(bottom) else { return None }
  if left.get() < right.get() && top.get() < bottom.get() {
    // Width and height must not overflow.
    guard checked_f32_sub(right.get(), left.get()) is Some(_) else {
      return None
    }
    guard checked_f32_sub(bottom.get(), top.get()) is Some(_) else {
      return None
    }
    Some({ left, top, right, bottom, })
  } else {
    None
  }
}

///|
/// Creates new `NonZeroRect`.
pub fn NonZeroRect::from_xywh(
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> NonZeroRect? {
  NonZeroRect::from_ltrb(x, y, w + x, h + y)
}

///|
/// Returns the left edge.
pub fn NonZeroRect::left(self : NonZeroRect) -> Float {
  self.left.get()
}

///|
/// Returns the top edge.
pub fn NonZeroRect::top(self : NonZeroRect) -> Float {
  self.top.get()
}

///|
/// Returns the right edge.
pub fn NonZeroRect::right(self : NonZeroRect) -> Float {
  self.right.get()
}

///|
/// Returns the bottom edge.
pub fn NonZeroRect::bottom(self : NonZeroRect) -> Float {
  self.bottom.get()
}

///|
/// Returns rect's X position.
pub fn NonZeroRect::x(self : NonZeroRect) -> Float {
  self.left.get()
}

///|
/// Returns rect's Y position.
pub fn NonZeroRect::y(self : NonZeroRect) -> Float {
  self.top.get()
}

///|
/// Returns rect's width.
pub fn NonZeroRect::width(self : NonZeroRect) -> Float {
  self.right.get() - self.left.get()
}

///|
/// Returns rect's height.
pub fn NonZeroRect::height(self : NonZeroRect) -> Float {
  self.bottom.get() - self.top.get()
}

///|
/// Returns rect's size.
pub fn NonZeroRect::size(self : NonZeroRect) -> Size {
  Size::from_wh(self.width(), self.height()).unwrap()
}

///|
/// Translates the rect to the specified position.
pub fn NonZeroRect::translate_to(
  self : NonZeroRect,
  x : Float,
  y : Float,
) -> NonZeroRect? {
  NonZeroRect::from_xywh(x, y, self.width(), self.height())
}

///|
/// Transforms the rect using the provided `Transform`.
///
/// If the transform is a skew, the result will be a bounding box around the
/// skewed rectangle.
pub fn NonZeroRect::transform(
  self : NonZeroRect,
  ts : Transform,
) -> NonZeroRect? {
  if ts.is_identity() {
    Some(self)
  } else {
    guard self.to_rect().transform(ts) is Some(r) else { return None }
    r.to_non_zero_rect()
  }
}

///|
/// Applies a bounding box transform.
pub fn NonZeroRect::bbox_transform(
  self : NonZeroRect,
  bbox : NonZeroRect,
) -> NonZeroRect {
  let x = self.x() * bbox.width() + bbox.x()
  let y = self.y() * bbox.height() + bbox.y()
  let w = self.width() * bbox.width()
  let h = self.height() * bbox.height()
  NonZeroRect::from_xywh(x, y, w, h).unwrap()
}

///|
/// Converts into [`Rect`].
pub fn NonZeroRect::to_rect(self : NonZeroRect) -> Rect {
  Rect::from_xywh(self.x(), self.y(), self.width(), self.height()).unwrap()
}

///|
/// Converts into [`IntRect`].
pub fn NonZeroRect::to_int_rect(self : NonZeroRect) -> IntRect {
  let w = f32_as_u32(self.width().ceil())
  let h = f32_as_u32(self.height().ceil())
  IntRect::from_xywh(
    f32_as_i32(self.x().floor()),
    f32_as_i32(self.y().floor()),
    if w < 1 {
      1
    } else {
      w
    },
    if h < 1 {
      1
    } else {
      h
    },
  ).unwrap()
}
