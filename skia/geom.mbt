// Port of `tiny-skia/src/geom.rs`.

///|
/// A screen `IntRect`.
///
/// # Guarantees
///
/// - X and Y are in 0..=i32::MAX range.
/// - Width and height are in 1..=i32::MAX range.
/// - x+width and y+height does not overflow.
///
/// The unsigned upstream values are stored as `Int`s (they all fit).
pub struct ScreenIntRect {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
/// Creates a new `ScreenIntRect`.
pub fn ScreenIntRect::from_xywh(
  x : UInt,
  y : UInt,
  width : UInt,
  height : UInt,
) -> ScreenIntRect? {
  let max = 0x7FFFFFFFU
  if x > max || y > max || width > max || height > max {
    return None
  }
  // `x.checked_add(width)` in u32: cannot overflow since both are <= i32::MAX.
  if width == 0 || height == 0 {
    return None
  }
  Some({
    x: x.reinterpret_as_int(),
    y: y.reinterpret_as_int(),
    width: width.reinterpret_as_int(),
    height: height.reinterpret_as_int(),
  })
}

///|
fn ScreenIntRect::from_xywh_safe(
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> ScreenIntRect {
  { x, y, width, height, }
}

///|
pub fn ScreenIntRect::x(self : ScreenIntRect) -> Int {
  self.x
}

///|
pub fn ScreenIntRect::y(self : ScreenIntRect) -> Int {
  self.y
}

///|
pub fn ScreenIntRect::width(self : ScreenIntRect) -> Int {
  self.width
}

///|
pub fn ScreenIntRect::height(self : ScreenIntRect) -> Int {
  self.height
}

///|
pub fn ScreenIntRect::left(self : ScreenIntRect) -> Int {
  self.x
}

///|
pub fn ScreenIntRect::top(self : ScreenIntRect) -> Int {
  self.y
}

///|
/// Returns rect's right edge. The upstream `u32` addition cannot overflow.
pub fn ScreenIntRect::right(self : ScreenIntRect) -> Int {
  self.x + self.width
}

///|
pub fn ScreenIntRect::bottom(self : ScreenIntRect) -> Int {
  self.y + self.height
}

///|
pub fn ScreenIntRect::size(self : ScreenIntRect) -> @path.IntSize {
  @path.IntSize::from_wh(
    self.width.reinterpret_as_uint(),
    self.height.reinterpret_as_uint(),
  ).unwrap()
}

///|
/// Checks that the rect is completely includes `other` Rect.
pub fn ScreenIntRect::contains(
  self : ScreenIntRect,
  other : ScreenIntRect,
) -> Bool {
  self.x <= other.x &&
  self.y <= other.y &&
  self.right() >= other.right() &&
  self.bottom() >= other.bottom()
}

///|
/// Converts into a `IntRect`.
pub fn ScreenIntRect::to_int_rect(self : ScreenIntRect) -> @path.IntRect {
  @path.IntRect::from_xywh(
    self.x,
    self.y,
    self.width.reinterpret_as_uint(),
    self.height.reinterpret_as_uint(),
  ).unwrap()
}

///|
/// Converts into a `Rect`.
pub fn ScreenIntRect::to_rect(self : ScreenIntRect) -> @path.Rect {
  @path.Rect::from_ltrb(
    u32f(self.x),
    u32f(self.y),
    u32f(self.x) + u32f(self.width),
    u32f(self.y) + u32f(self.height),
  ).unwrap()
}

///|
/// `x as f32` for a non-negative `Int` holding a `u32`.
fn u32f(x : Int) -> Float {
  Float::from_uint(x.reinterpret_as_uint())
}

///|
/// `IntSizeExt::to_screen_int_rect`.
fn int_size_to_screen_int_rect(
  size : @path.IntSize,
  x : Int,
  y : Int,
) -> ScreenIntRect {
  ScreenIntRect::from_xywh(
    x.reinterpret_as_uint(),
    y.reinterpret_as_uint(),
    size.width(),
    size.height(),
  ).unwrap()
}

///|
/// `IntRectExt::to_screen_int_rect`.
fn int_rect_to_screen_int_rect(r : @path.IntRect) -> ScreenIntRect? {
  if r.x() < 0 || r.y() < 0 {
    return None
  }
  ScreenIntRect::from_xywh(
    r.x().reinterpret_as_uint(),
    r.y().reinterpret_as_uint(),
    r.width(),
    r.height(),
  )
}
