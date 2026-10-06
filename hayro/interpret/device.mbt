// Port of `hayro-interpret/src/device.rs`.

///|
/// A trait for a device that can be used to process PDF drawing instructions.
///
/// This is the interface between the interpreter and its backends (the SVG
/// converter in `hayro/svg`, and a rasterizer). Devices are used as trait
/// objects (`&Device`).
pub(open) trait Device {
  /// Draw a path.
  fn draw_path(Self, @kurbo.BezPath, DrawProps, DrawMode) -> Unit
  /// Push a new clip path to the clip stack.
  fn push_clip_path(Self, ClipPath) -> Unit
  /// Push a rectangular clip to the clip stack.
  fn push_clip_rect(Self, @kurbo.Rect) -> Unit = _
  /// Push a new transparency group to the blend stack.
  fn push_transparency_group(Self, Float, SoftMask?, BlendMode) -> Unit
  /// Draw a glyph.
  fn draw_glyph(Self, Glyph, @kurbo.Affine, DrawProps, DrawMode) -> Unit
  /// Draw an image.
  fn draw_image(Self, Image, ImageDrawProps) -> Unit
  /// Pop the last clip path or clip rectangle from the clip stack.
  fn pop_clip(Self) -> Unit
  /// Pop the last transparency group from the blend stack.
  fn pop_transparency_group(Self) -> Unit
  /// Draw a rectangle directly, without going through the general path
  /// pipeline.
  fn draw_rect(Self, @kurbo.Rect, DrawProps, DrawMode) -> Unit = _
  /// Called at the beginning of a marked content sequence (BMC/BDC).
  ///
  /// The tag is the marked content tag (e.g. b"P", b"Span"). The mcid is
  /// the marked content identifier from the properties dict, if present.
  fn begin_marked_content(Self, Bytes, Int?) -> Unit = _
  /// Called at the end of a marked content sequence (EMC).
  fn end_marked_content(Self) -> Unit = _
}

///|
impl Device with fn push_clip_rect(self, rect) {
  self.push_clip_path({ path: rect.to_path(0.1), fill: NonZero, })
}

///|
impl Device with fn draw_rect(self, rect, props, draw_mode) {
  self.draw_path(rect.to_path(0.1), props, draw_mode)
}

///|
impl Device with fn begin_marked_content(_self, _tag, _mcid) {
  ()
}

///|
impl Device with fn end_marked_content(_self) {
  ()
}

///|
/// A device that discards all drawing operations.
pub struct DummyDevice {}

///|
/// Create a new dummy device.
pub fn DummyDevice::new() -> DummyDevice {
  DummyDevice::{ }
}

///|
pub impl Device for DummyDevice with fn draw_path(_, _, _, _) {
  ()
}

///|
pub impl Device for DummyDevice with fn push_clip_path(_, _) {
  ()
}

///|
pub impl Device for DummyDevice with fn push_transparency_group(_, _, _, _) {
  ()
}

///|
pub impl Device for DummyDevice with fn draw_glyph(_, _, _, _, _) {
  ()
}

///|
pub impl Device for DummyDevice with fn draw_image(_, _, _) {
  ()
}

///|
pub impl Device for DummyDevice with fn pop_clip(_) {
  ()
}

///|
pub impl Device for DummyDevice with fn pop_transparency_group(_) {
  ()
}

///|
#deprecated("call as `Device::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DummyDevice with Device::{
  draw_path,
  pop_clip,
  draw_rect,
  begin_marked_content,
  end_marked_content,
  pop_transparency_group,
  draw_image,
  draw_glyph,
  push_clip_path,
  push_clip_rect,
  push_transparency_group,
}
