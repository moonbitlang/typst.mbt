// Placeholder definitions for types used by the `Routines` contracts whose
// ports are pending. Each is replaced wholesale by its real port (in its own
// file named after the upstream module).

///|
/// A finished layout with items at fixed positions. (placeholder; see
/// layout/frame.rs)
pub struct Frame {
  /// The size of the frame.
  size : Axes[Abs]
}

///|
/// Create a new, empty frame.
pub fn Frame::new(size : Axes[Abs]) -> Frame {
  { size, }
}

///|
/// The size of the frame.
pub fn Frame::size(self : Frame) -> Axes[Abs] {
  self.size
}

///|
/// A single region to layout into (upstream `layout::Region`; renamed
/// because `Region` is the text region of `text/lang.rs`). (placeholder; see
/// layout/regions.rs)
pub(all) struct LayoutRegion {
  /// The size of the region.
  size : Axes[Abs]
  /// Whether elements should expand to fill the regions instead of shrinking
  /// to fit the content.
  expand : Axes[Bool]
}

///|
/// Create a new region.
pub fn LayoutRegion::new(size : Axes[Abs], expand : Axes[Bool]) -> LayoutRegion {
  { size, expand, }
}
