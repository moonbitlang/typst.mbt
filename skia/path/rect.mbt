// Port of `tiny-skia-path/src/rect.rs` and `size.rs`.

///|
/// An integer rectangle. Width and height are guarantee to be > 0.
pub struct IntRect {
  x : Int
  y : Int
  width : UInt
  height : UInt
} derive(Eq, Debug)

///|
fn i32_checked_add(a : Int, b : Int) -> Int? {
  let r = a.to_int64() + b.to_int64()
  if r > 2147483647L || r < -2147483648L {
    None
  } else {
    Some(r.to_int())
  }
}

///|
/// Creates a new `IntRect`.
pub fn IntRect::from_xywh(
  x : Int,
  y : Int,
  width : UInt,
  height : UInt,
) -> IntRect? {
  // `i32::try_from(width)`.
  if width > 0x7fffffffU || height > 0x7fffffffU {
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
  let w = right.to_int64() - left.to_int64()
  let h = bottom.to_int64() - top.to_int64()
  if w < -2147483648L || w > 2147483647L || w < 0L {
    return None
  }
  if h < -2147483648L || h > 2147483647L || h < 0L {
    return None
  }
  IntRect::from_xywh(
    left,
    top,
    w.to_int().reinterpret_as_uint(),
    h.to_int().reinterpret_as_uint(),
  )
}

///|
pub fn IntRect::x(self : IntRect) -> Int {
  self.x
}

///|
pub fn IntRect::y(self : IntRect) -> Int {
  self.y
}

///|
pub fn IntRect::width(self : IntRect) -> UInt {
  self.width
}

///|
pub fn IntRect::height(self : IntRect) -> UInt {
  self.height
}

///|
pub fn IntRect::left(self : IntRect) -> Int {
  self.x
}

///|
pub fn IntRect::top(self : IntRect) -> Int {
  self.y
}

///|
pub fn IntRect::right(self : IntRect) -> Int {
  self.x + self.width.reinterpret_as_int()
}

///|
pub fn IntRect::bottom(self : IntRect) -> Int {
  self.y + self.height.reinterpret_as_int()
}

///|
/// Returns rect's size.
pub fn IntRect::size(self : IntRect) -> IntSize {
  { width: self.width, height: self.height, }
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
pub fn IntRect::intersect(self : IntRect, other : IntRect) -> IntRect? {
  let left = if self.x > other.x { self.x } else { other.x }
  let top = if self.y > other.y { self.y } else { other.y }
  let right = if self.right() < other.right() {
    self.right()
  } else {
    other.right()
  }
  let bottom = if self.bottom() < other.bottom() {
    self.bottom()
  } else {
    other.bottom()
  }
  let w = right.to_int64() - left.to_int64()
  let h = bottom.to_int64() - top.to_int64()
  if w < 0L || h < 0L || w > 2147483647L || h > 2147483647L {
    return None
  }
  IntRect::from_xywh(
    left,
    top,
    w.to_int().reinterpret_as_uint(),
    h.to_int().reinterpret_as_uint(),
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
  IntRect::from_xywh(self.x + tx, self.y + ty, self.width, self.height)
}

///|
/// Translates the rect to the specified position.
pub fn IntRect::translate_to(self : IntRect, x : Int, y : Int) -> IntRect? {
  IntRect::from_xywh(x, y, self.width, self.height)
}

///|
/// Converts into `Rect`.
pub fn IntRect::to_rect(self : IntRect) -> Rect {
  Rect::from_ltrb(
    i32_to_f32(self.x),
    i32_to_f32(self.y),
    i32_to_f32(self.x) + u32_to_f32(self.width),
    i32_to_f32(self.y) + u32_to_f32(self.height),
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
  left : Float
  top : Float
  right : Float
  bottom : Float
} derive(Eq, Debug)

///|
/// Creates new `Rect`.
pub fn Rect::from_ltrb(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> Rect? {
  if !is_finite(left) ||
    !is_finite(top) ||
    !is_finite(right) ||
    !is_finite(bottom) {
    return None
  }
  if left <= right && top <= bottom {
    // Width and height must not overflow.
    guard checked_f32_sub(right, left) is Some(_) else { return None }
    guard checked_f32_sub(bottom, top) is Some(_) else { return None }
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
pub fn Rect::left(self : Rect) -> Float {
  self.left
}

///|
pub fn Rect::top(self : Rect) -> Float {
  self.top
}

///|
pub fn Rect::right(self : Rect) -> Float {
  self.right
}

///|
pub fn Rect::bottom(self : Rect) -> Float {
  self.bottom
}

///|
pub fn Rect::x(self : Rect) -> Float {
  self.left
}

///|
pub fn Rect::y(self : Rect) -> Float {
  self.top
}

///|
pub fn Rect::width(self : Rect) -> Float {
  self.right - self.left
}

///|
pub fn Rect::height(self : Rect) -> Float {
  self.bottom - self.top
}

///|
/// Checks that the rect has a zero width or height.
pub fn Rect::is_empty(self : Rect) -> Bool {
  self.left == self.right || self.top == self.bottom
}

///|
/// Converts into an `IntRect` by adding 0.5 and discarding the fractional
/// portion. Width and height are guarantee to be >= 1.
pub fn Rect::round(self : Rect) -> IntRect? {
  let left = i32_saturate_round(self.left)
  let top = i32_saturate_round(self.top)
  let right = i32_saturate_round(self.right)
  let bottom = i32_saturate_round(self.bottom)
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
/// Converts into an `IntRect` rounding outwards. Width and height are
/// guarantee to be >= 1.
pub fn Rect::round_out(self : Rect) -> IntRect? {
  let left = i32_saturate_floor(self.left)
  let top = i32_saturate_floor(self.top)
  let right = i32_saturate_ceil(self.right)
  let bottom = i32_saturate_ceil(self.bottom)
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
pub fn Rect::intersect(self : Rect, other : Rect) -> Rect? {
  let left = fmax(self.x(), other.x())
  let top = fmax(self.y(), other.y())
  let right = fmin(self.right, other.right)
  let bottom = fmin(self.bottom, other.bottom)
  Rect::from_ltrb(left, top, right, bottom)
}

///|
/// Returns the union of two rectangles.
pub fn Rect::join(self : Rect, other : Rect) -> Rect? {
  if other.is_empty() {
    return Some(self)
  }
  if self.is_empty() {
    return Some(other)
  }
  let left = fmin(self.x(), other.x())
  let top = fmin(self.y(), other.y())
  let right = fmax(self.right, other.right)
  let bottom = fmax(self.bottom, other.bottom)
  Rect::from_ltrb(left, top, right, bottom)
}

///|
/// Creates a Rect from Point array. Returns None if count is zero or if
/// Point array contains an infinity or NaN.
pub fn Rect::from_points(points : ArrayView[Point]) -> Rect? {
  let mut offset = 0
  // min/max as f32x4 lanes.
  let mut min0 : Float = 0
  let mut min1 : Float = 0
  let mut min2 : Float = 0
  let mut min3 : Float = 0
  match points.length() {
    0 => return None
    1 => {
      let p = points[0]
      return Rect::from_xywh(p.x, p.y, 0.0, 0.0)
    }
    2 => {
      let p0 = points[0]
      let p1 = points[1]
      // Avoid min/max to preserve a NaN for rejection by from_ltrb
      let (l, r) = if p0.x < p1.x { (p0.x, p1.x) } else { (p1.x, p0.x) }
      let (t, b) = if p0.y < p1.y { (p0.y, p1.y) } else { (p1.y, p0.y) }
      return Rect::from_ltrb(l, t, r, b)
    }
    n =>
      if (n & 1) != 0 {
        let pt = points[0]
        min0 = pt.x
        min1 = pt.y
        min2 = pt.x
        min3 = pt.y
        offset = 1
      } else {
        let pt0 = points[0]
        let pt1 = points[1]
        min0 = pt0.x
        min1 = pt0.y
        min2 = pt1.x
        min3 = pt1.y
        offset = 2
      }
  }
  let mut max0 = min0
  let mut max1 = min1
  let mut max2 = min2
  let mut max3 = min3
  let mut a0 : Float = 0
  let mut a1 : Float = 0
  let mut a2 : Float = 0
  let mut a3 : Float = 0
  while offset != points.length() {
    let pt0 = points[offset]
    let pt1 = points[offset + 1]
    a0 = a0 * pt0.x
    a1 = a1 * pt0.y
    a2 = a2 * pt1.x
    a3 = a3 * pt1.y
    min0 = fmin(min0, pt0.x)
    min1 = fmin(min1, pt0.y)
    min2 = fmin(min2, pt1.x)
    min3 = fmin(min3, pt1.y)
    max0 = fmax(max0, pt0.x)
    max1 = fmax(max1, pt0.y)
    max2 = fmax(max2, pt1.x)
    max3 = fmax(max3, pt1.y)
    offset += 2
  }
  let all_finite = a0 * 0 == 0 && a1 * 0 == 0 && a2 * 0 == 0 && a3 * 0 == 0
  if all_finite {
    Rect::from_ltrb(
      fmin(min0, min2),
      fmin(min1, min3),
      fmax(max0, max2),
      fmax(max1, max3),
    )
  } else {
    None
  }
}

///|
/// Insets the rectangle by the specified offset.
pub fn Rect::inset(self : Rect, dx : Float, dy : Float) -> Rect? {
  Rect::from_ltrb(
    self.left + dx,
    self.top + dy,
    self.right - dx,
    self.bottom - dy,
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
/// This method is expensive.
pub fn Rect::transform(self : Rect, ts : Transform) -> Rect? {
  if ts.is_identity() {
    Some(self)
  } else if ts.has_skew() {
    // we need to transform all 4 corners
    let lt = Point::from_xy(self.left, self.top)
    let rt = Point::from_xy(self.right, self.top)
    let lb = Point::from_xy(self.left, self.bottom)
    let rb = Point::from_xy(self.right, self.bottom)
    let pts = [lt, rt, lb, rb]
    ts.map_points(pts)
    Rect::from_points(pts)
  } else {
    // Faster (more common) case
    let lt = Point::from_xy(self.left, self.top)
    let rb = Point::from_xy(self.right, self.bottom)
    let pts = [lt, rb]
    ts.map_points(pts)
    Rect::from_points(pts)
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
  if n > -f32_max.to_double() && n < f32_max.to_double() {
    Some(n.to_float())
  } else {
    None
  }
}

///|
/// A rectangle defined by left, top, right and bottom edges.
///
/// Similar to [`Rect`], but width and height guarantee to be non-zero and
/// positive.
pub struct NonZeroRect {
  left : Float
  top : Float
  right : Float
  bottom : Float
} derive(Eq, Debug)

///|
/// Creates new `NonZeroRect`.
pub fn NonZeroRect::from_ltrb(
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> NonZeroRect? {
  if !is_finite(left) ||
    !is_finite(top) ||
    !is_finite(right) ||
    !is_finite(bottom) {
    return None
  }
  if left < right && top < bottom {
    guard checked_f32_sub(right, left) is Some(_) else { return None }
    guard checked_f32_sub(bottom, top) is Some(_) else { return None }
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
pub fn NonZeroRect::left(self : NonZeroRect) -> Float {
  self.left
}

///|
pub fn NonZeroRect::top(self : NonZeroRect) -> Float {
  self.top
}

///|
pub fn NonZeroRect::right(self : NonZeroRect) -> Float {
  self.right
}

///|
pub fn NonZeroRect::bottom(self : NonZeroRect) -> Float {
  self.bottom
}

///|
pub fn NonZeroRect::x(self : NonZeroRect) -> Float {
  self.left
}

///|
pub fn NonZeroRect::y(self : NonZeroRect) -> Float {
  self.top
}

///|
pub fn NonZeroRect::width(self : NonZeroRect) -> Float {
  self.right - self.left
}

///|
pub fn NonZeroRect::height(self : NonZeroRect) -> Float {
  self.bottom - self.top
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
pub fn NonZeroRect::transform(
  self : NonZeroRect,
  ts : Transform,
) -> NonZeroRect? {
  if ts.is_identity() {
    Some(self)
  } else {
    self.to_rect().transform(ts).bind(r => r.to_non_zero_rect())
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
  let w = f32_to_u32(ceilf(self.width()))
  let h = f32_to_u32(ceilf(self.height()))
  IntRect::from_xywh(
    f32_to_i32(floorf(self.x())),
    f32_to_i32(floorf(self.y())),
    if w > 1 {
      w
    } else {
      1
    },
    if h > 1 {
      h
    } else {
      1
    },
  ).unwrap()
}

///|
/// An integer size. Width and height are guarantee to be > 0.
pub struct IntSize {
  width : UInt
  height : UInt
} derive(Eq, Debug, Hash)

///|
/// Creates a new `IntSize` from width and height.
pub fn IntSize::from_wh(width : UInt, height : UInt) -> IntSize? {
  if width == 0 || height == 0 {
    None
  } else {
    Some({ width, height, })
  }
}

///|
pub fn IntSize::width(self : IntSize) -> UInt {
  self.width
}

///|
pub fn IntSize::height(self : IntSize) -> UInt {
  self.height
}

///|
/// Returns width and height as a tuple.
pub fn IntSize::dimensions(self : IntSize) -> (UInt, UInt) {
  (self.width, self.height)
}

///|
/// Scales current size by the specified factor.
pub fn IntSize::scale_by(self : IntSize, factor : Float) -> IntSize? {
  IntSize::from_wh(
    f32_to_u32(roundf(u32_to_f32(self.width) * factor)),
    f32_to_u32(roundf(u32_to_f32(self.height) * factor)),
  )
}

///|
/// Scales current size to the specified size.
pub fn IntSize::scale_to(self : IntSize, to : IntSize) -> IntSize {
  int_size_scale(self, to, false)
}

///|
/// Scales current size to the specified width.
pub fn IntSize::scale_to_width(self : IntSize, new_width : UInt) -> IntSize? {
  let new_height = ceilf(
    u32_to_f32(new_width) * u32_to_f32(self.height) / u32_to_f32(self.width),
  )
  IntSize::from_wh(new_width, f32_to_u32(new_height))
}

///|
/// Scales current size to the specified height.
pub fn IntSize::scale_to_height(self : IntSize, new_height : UInt) -> IntSize? {
  let new_width = ceilf(
    u32_to_f32(new_height) * u32_to_f32(self.width) / u32_to_f32(self.height),
  )
  IntSize::from_wh(f32_to_u32(new_width), new_height)
}

///|
/// Converts into [`Size`].
pub fn IntSize::to_size(self : IntSize) -> Size {
  Size::from_wh(u32_to_f32(self.width), u32_to_f32(self.height)).unwrap()
}

///|
/// Converts into [`IntRect`] at the provided position.
pub fn IntSize::to_int_rect(self : IntSize, x : Int, y : Int) -> IntRect {
  IntRect::from_xywh(x, y, self.width, self.height).unwrap()
}

///|
fn int_size_scale(s1 : IntSize, s2 : IntSize, expand : Bool) -> IntSize {
  let rw = f32_to_u32(
    ceilf(u32_to_f32(s2.height) * u32_to_f32(s1.width) / u32_to_f32(s1.height)),
  )
  let with_h = if expand { rw <= s2.width } else { rw >= s2.width }
  if !with_h {
    IntSize::from_wh(rw, s2.height).unwrap()
  } else {
    let h = f32_to_u32(
      ceilf(u32_to_f32(s2.width) * u32_to_f32(s1.height) / u32_to_f32(s1.width)),
    )
    IntSize::from_wh(s2.width, h).unwrap()
  }
}

///|
/// A size. Width and height are guarantee to be > 0 and finite.
pub struct Size {
  width : Float
  height : Float
} derive(Eq, Debug)

///|
/// Creates a new `Size` from width and height.
pub fn Size::from_wh(width : Float, height : Float) -> Size? {
  guard non_zero_positive_f32(width) is Some(width) else { return None }
  guard non_zero_positive_f32(height) is Some(height) else { return None }
  Some({ width, height, })
}

///|
pub fn Size::width(self : Size) -> Float {
  self.width
}

///|
pub fn Size::height(self : Size) -> Float {
  self.height
}

///|
/// Scales current size to specified size.
pub fn Size::scale_to(self : Size, to : Size) -> Size {
  size_scale_f64(self, to, false)
}

///|
/// Expands current size to specified size.
pub fn Size::expand_to(self : Size, to : Size) -> Size {
  size_scale_f64(self, to, true)
}

///|
/// Scales current size by the specified factor.
pub fn Size::scale_by(self : Size, factor : Float) -> Size? {
  Size::from_wh(self.width * factor, self.height * factor)
}

///|
/// Scales current size to the specified width.
pub fn Size::scale_to_width(self : Size, new_width : Float) -> Size? {
  let new_height = new_width * self.height / self.width
  Size::from_wh(new_width, new_height)
}

///|
/// Scales current size to the specified height.
pub fn Size::scale_to_height(self : Size, new_height : Float) -> Size? {
  let new_width = new_height * self.width / self.height
  Size::from_wh(new_width, new_height)
}

///|
/// Converts into [`IntSize`].
pub fn Size::to_int_size(self : Size) -> IntSize {
  let w = f32_to_u32(roundf(self.width))
  let h = f32_to_u32(roundf(self.height))
  IntSize::from_wh(if w > 1 { w } else { 1 }, if h > 1 { h } else { 1 }).unwrap()
}

///|
/// Converts the current size to `Rect` at provided position.
pub fn Size::to_rect(self : Size, x : Float, y : Float) -> Rect? {
  Rect::from_xywh(x, y, self.width, self.height)
}

///|
/// Converts the current size to `NonZeroRect` at provided position.
pub fn Size::to_non_zero_rect(self : Size, x : Float, y : Float) -> NonZeroRect {
  NonZeroRect::from_xywh(x, y, self.width, self.height).unwrap()
}

///|
fn size_scale_f64(s1 : Size, s2 : Size, expand : Bool) -> Size {
  let rw = s2.height * s1.width / s1.height
  let with_h = if expand { rw <= s2.width } else { rw >= s2.width }
  if !with_h {
    Size::from_wh(rw, s2.height).unwrap()
  } else {
    let h = s2.width * s1.height / s1.width
    Size::from_wh(s2.width, h).unwrap()
  }
}
