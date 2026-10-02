// Port of `usvg` 0.47.0 `src/tree/geom.rs`.

///|
/// View box.
priv struct ViewBox {
  /// Value of the `viewBox` attribute.
  rect : NonZeroRect
  /// Value of the `preserveAspectRatio` attribute.
  aspect : @svgtypes.AspectRatio
}

///|
/// Converts `viewBox` into `Transform`.
fn ViewBox::to_transform(self : ViewBox, img_size : Size) -> Transform {
  let vr = self.rect
  let sx = img_size.width() / vr.width()
  let sy = img_size.height() / vr.height()
  let (sx, sy) = if self.aspect.align == @svgtypes.Align::None {
    (sx, sy)
  } else {
    let s = if self.aspect.slice {
      if sx < sy {
        sy
      } else {
        sx
      }
    } else if sx > sy {
      sy
    } else {
      sx
    }
    (s, s)
  }
  let x = -vr.x() * sx
  let y = -vr.y() * sy
  let w = img_size.width() - vr.width() * sx
  let h = img_size.height() - vr.height() * sy
  let (tx, ty) = aligned_pos(self.aspect.align, x, y, w, h)
  Transform::from_row(sx, 0.0, 0.0, sy, tx, ty)
}

///|
/// A bounding box calculator.
priv struct BBox {
  left : Float
  top : Float
  right : Float
  bottom : Float
}

///|
fn BBox::from_rect(r : Rect) -> BBox {
  { left: r.left(), top: r.top(), right: r.right(), bottom: r.bottom() }
}

///|
fn BBox::from_non_zero_rect(r : NonZeroRect) -> BBox {
  { left: r.left(), top: r.top(), right: r.right(), bottom: r.bottom() }
}

///|
let f32_max : Float = Float::reinterpret_from_uint(0x7F7FFFFFU)

///|
let f32_min : Float = Float::reinterpret_from_uint(0xFF7FFFFFU)

///|
impl Default for BBox with default() {
  { left: f32_max, top: f32_max, right: f32_min, bottom: f32_min }
}

///|
/// Checks if the bounding box is default, i.e. invalid.
fn BBox::is_default(self : BBox) -> Bool {
  self.left == f32_max &&
  self.top == f32_max &&
  self.right == f32_min &&
  self.bottom == f32_min
}

///|
/// Expand the bounding box to the specified bounds.
fn BBox::expand(self : BBox, r : BBox) -> BBox {
  {
    left: self.left.min(r.left),
    top: self.top.min(r.top),
    right: self.right.max(r.right),
    bottom: self.bottom.max(r.bottom),
  }
}

///|
/// Converts a bounding box into [`Rect`].
fn BBox::to_rect(self : BBox) -> Rect? {
  if !self.is_default() {
    Rect::from_ltrb(self.left, self.top, self.right, self.bottom)
  } else {
    None
  }
}

///|
/// Converts a bounding box into [`NonZeroRect`].
fn BBox::to_non_zero_rect(self : BBox) -> NonZeroRect? {
  if !self.is_default() {
    NonZeroRect::from_ltrb(self.left, self.top, self.right, self.bottom)
  } else {
    None
  }
}

///|
/// Returns object aligned position.
fn aligned_pos(
  align : @svgtypes.Align,
  x : Float,
  y : Float,
  w : Float,
  h : Float,
) -> (Float, Float) {
  match align {
    None => (x, y)
    XMinYMin => (x, y)
    XMidYMin => (x + w / 2.0, y)
    XMaxYMin => (x + w, y)
    XMinYMid => (x, y + h / 2.0)
    XMidYMid => (x + w / 2.0, y + h / 2.0)
    XMaxYMid => (x + w, y + h / 2.0)
    XMinYMax => (x, y + h)
    XMidYMax => (x + w / 2.0, y + h)
    XMaxYMax => (x + w, y + h)
  }
}
