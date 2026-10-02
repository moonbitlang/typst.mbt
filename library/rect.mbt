// Port of `typst-library/src/layout/rect.rs`.

///|
/// A rectangle in 2D.
pub(all) struct Rect {
  /// The top left corner (minimum coordinate).
  min : Point
  /// The bottom right corner (maximum coordinate).
  max : Point
} derive(Eq, Hash)

///|
/// Create a new rectangle from the minimum/maximum coordinate.
pub fn Rect::new(min : Point, max : Point) -> Rect {
  { min, max, }
}

///|
/// Create a new rectangle from the position and size.
pub fn Rect::from_pos_size(pos : Point, size : Axes[Abs]) -> Rect {
  { min: pos, max: pos + size.to_point(), }
}

///|
/// Compute the size of the rectangle.
pub fn Rect::size(self : Rect) -> Axes[Abs] {
  Axes::new(self.max.x - self.min.x, self.max.y - self.min.y)
}
