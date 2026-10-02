// Port of `tiny-skia-path` 0.12.0 `src/size.rs`.

///|
/// An integer size.
///
/// # Guarantees
///
/// - Width and height are positive and non-zero.
pub struct IntSize {
  priv width : UInt
  priv height : UInt
} derive(Eq, Debug, Hash)

///|
/// Creates a new `IntSize` from width and height.
pub fn IntSize::from_wh(width : UInt, height : UInt) -> IntSize? {
  if width == 0 || height == 0 {
    return None
  }
  Some({ width, height, })
}

///|
fn IntSize::from_wh_safe(width : UInt, height : UInt) -> IntSize {
  { width, height, }
}

///|
/// Returns width.
pub fn IntSize::width(self : IntSize) -> UInt {
  self.width
}

///|
/// Returns height.
pub fn IntSize::height(self : IntSize) -> UInt {
  self.height
}

///|
/// Returns width and height as a tuple.
pub fn IntSize::dimensions(self : IntSize) -> (UInt, UInt) {
  (self.width(), self.height())
}

///|
/// Scales current size by the specified factor.
pub fn IntSize::scale_by(self : IntSize, factor : Float) -> IntSize? {
  IntSize::from_wh(
    f32_as_u32(round_f32(u32_as_f32(self.width()) * factor)),
    f32_as_u32(round_f32(u32_as_f32(self.height()) * factor)),
  )
}

///|
/// Scales current size to the specified size.
pub fn IntSize::scale_to(self : IntSize, to : IntSize) -> IntSize {
  size_scale(self, to, false)
}

///|
/// Scales current size to the specified width.
pub fn IntSize::scale_to_width(self : IntSize, new_width : UInt) -> IntSize? {
  let new_height = (u32_as_f32(new_width) *
  u32_as_f32(self.height()) /
  u32_as_f32(self.width())).ceil()
  IntSize::from_wh(new_width, f32_as_u32(new_height))
}

///|
/// Scales current size to the specified height.
pub fn IntSize::scale_to_height(self : IntSize, new_height : UInt) -> IntSize? {
  let new_width = (u32_as_f32(new_height) *
  u32_as_f32(self.width()) /
  u32_as_f32(self.height())).ceil()
  IntSize::from_wh(f32_as_u32(new_width), new_height)
}

///|
/// Converts into [`Size`].
pub fn IntSize::to_size(self : IntSize) -> Size {
  Size::from_wh(u32_as_f32(self.width()), u32_as_f32(self.height())).unwrap()
}

///|
/// Converts into [`IntRect`] at the provided position.
pub fn IntSize::to_int_rect(self : IntSize, x : Int, y : Int) -> IntRect {
  IntRect::from_xywh(x, y, self.width(), self.height()).unwrap()
}

///|
fn size_scale(s1 : IntSize, s2 : IntSize, expand : Bool) -> IntSize {
  let rw = f32_as_u32(
    (u32_as_f32(s2.height()) * u32_as_f32(s1.width()) / u32_as_f32(s1.height())).ceil(),
  )
  let with_h = if expand { rw <= s2.width() } else { rw >= s2.width() }
  if !with_h {
    IntSize::from_wh(rw, s2.height()).unwrap()
  } else {
    let h = f32_as_u32(
      (u32_as_f32(s2.width()) * u32_as_f32(s1.height()) / u32_as_f32(s1.width())).ceil(),
    )
    IntSize::from_wh(s2.width(), h).unwrap()
  }
}

///|
/// A size.
///
/// # Guarantees
///
/// - Width and height are positive, non-zero and finite.
pub struct Size {
  priv width : NonZeroPositiveF32
  priv height : NonZeroPositiveF32
} derive(Eq, Debug, Hash)

///|
/// Creates a new `Size` from width and height.
pub fn Size::from_wh(width : Float, height : Float) -> Size? {
  guard NonZeroPositiveF32::new(width) is Some(width) else { return None }
  guard NonZeroPositiveF32::new(height) is Some(height) else { return None }
  Some({ width, height, })
}

///|
/// Returns width.
pub fn Size::width(self : Size) -> Float {
  self.width.get()
}

///|
/// Returns height.
pub fn Size::height(self : Size) -> Float {
  self.height.get()
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
  Size::from_wh(self.width() * factor, self.height() * factor)
}

///|
/// Scales current size to the specified width.
pub fn Size::scale_to_width(self : Size, new_width : Float) -> Size? {
  let new_height = new_width * self.height() / self.width()
  Size::from_wh(new_width, new_height)
}

///|
/// Scales current size to the specified height.
pub fn Size::scale_to_height(self : Size, new_height : Float) -> Size? {
  let new_width = new_height * self.width() / self.height()
  Size::from_wh(new_width, new_height)
}

///|
/// Converts into [`IntSize`].
pub fn Size::to_int_size(self : Size) -> IntSize {
  let w = f32_as_u32(round_f32(self.width()))
  let h = f32_as_u32(round_f32(self.height()))
  IntSize::from_wh(if w < 1 { 1 } else { w }, if h < 1 { 1 } else { h }).unwrap()
}

///|
/// Converts the current size to `Rect` at provided position.
pub fn Size::to_rect(self : Size, x : Float, y : Float) -> Rect? {
  Rect::from_xywh(x, y, self.width.get(), self.height.get())
}

///|
/// Converts the current size to `NonZeroRect` at provided position.
pub fn Size::to_non_zero_rect(self : Size, x : Float, y : Float) -> NonZeroRect {
  NonZeroRect::from_xywh(x, y, self.width.get(), self.height.get()).unwrap()
}

///|
fn size_scale_f64(s1 : Size, s2 : Size, expand : Bool) -> Size {
  let rw = s2.height.get() * s1.width.get() / s1.height.get()
  let with_h = if expand { rw <= s2.width.get() } else { rw >= s2.width.get() }
  if !with_h {
    Size::from_wh(rw, s2.height.get()).unwrap()
  } else {
    let h = s2.width.get() * s1.height.get() / s1.width.get()
    Size::from_wh(s2.width.get(), h).unwrap()
  }
}
