// Port of `hayro-jpeg2000/src/j2c/rect.rs`.

///|
priv struct IntRect {
  x0 : UInt
  y0 : UInt
  x1 : UInt
  y1 : UInt
}

///|
fn IntRect::from_ltrb(x0 : UInt, y0 : UInt, x1 : UInt, y1 : UInt) -> IntRect {
  { x0, y0, x1, y1, }
}

///|
fn IntRect::from_xywh(x : UInt, y : UInt, w : UInt, h : UInt) -> IntRect {
  { x0: x, y0: y, x1: x + w, y1: y + h, }
}

///|
fn IntRect::width(self : IntRect) -> UInt {
  // See B-11.
  self.x1 - self.x0
}

///|
fn IntRect::height(self : IntRect) -> UInt {
  // See B-11.
  self.y1 - self.y0
}

///|
fn IntRect::intersect(self : IntRect, other : IntRect) -> IntRect {
  if self.x1 < other.x0 ||
    other.x1 < self.x0 ||
    self.y1 < other.y0 ||
    other.y1 < self.y0 {
    IntRect::from_xywh(0, 0, 0, 0)
  } else {
    IntRect::from_ltrb(
      max_u32(self.x0, other.x0),
      max_u32(self.y0, other.y0),
      min_u32(self.x1, other.x1),
      min_u32(self.y1, other.y1),
    )
  }
}
