// Port of `vello_common/src/geometry.rs`.

///|
/// An axis-aligned rectangle with `u16` coordinates, stored as two corners
/// `(x0, y0)` and `(x1, y1)`.
///
/// The rectangle is considered to be empty when `x0 >= x1` or `y0 >= y1`.
priv struct RectU16 {
  x0 : Int
  y0 : Int
  mut x1 : Int
  mut y1 : Int
}

///|
fn RectU16::new(x0 : Int, y0 : Int, x1 : Int, y1 : Int) -> RectU16 {
  { x0, y0, x1, y1, }
}

///|
/// The width of the rectangle (`x1 - x0`), saturating at zero.
fn RectU16::width(self : RectU16) -> Int {
  u16_sat_sub(self.x1, self.x0)
}

///|
/// The height of the rectangle (`y1 - y0`), saturating at zero.
fn RectU16::height(self : RectU16) -> Int {
  u16_sat_sub(self.y1, self.y0)
}

///|
/// Compute the intersection of two rectangles.
fn RectU16::intersect(self : RectU16, other : RectU16) -> RectU16 {
  {
    x0: if self.x0 > other.x0 {
      self.x0
    } else {
      other.x0
    },
    y0: if self.y0 > other.y0 {
      self.y0
    } else {
      other.y0
    },
    x1: if self.x1 < other.x1 {
      self.x1
    } else {
      other.x1
    },
    y1: if self.y1 < other.y1 {
      self.y1
    } else {
      other.y1
    },
  }
}

///|
/// `RectExt::snap_to_tile_coordinates`.
fn RectU16::snap_to_tile_coordinates(self : RectU16) -> RectU16 {
  {
    x0: self.x0 / TILE_WIDTH * TILE_WIDTH,
    y0: self.y0 / TILE_HEIGHT * TILE_HEIGHT,
    x1: checked_next_multiple(self.x1, TILE_WIDTH),
    y1: checked_next_multiple(self.y1, TILE_HEIGHT),
  }
}

///|
/// `u16::checked_next_multiple_of(..).unwrap_or(u16::MAX)`.
fn checked_next_multiple(x : Int, m : Int) -> Int {
  let r = (x + m - 1) / m * m
  if r > 65535 {
    65535
  } else {
    r
  }
}
