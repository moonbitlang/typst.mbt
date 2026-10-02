// Port of `tiny-skia/src/blitter.rs`.
//
// Upstream `u32` coordinates are `Int`s here; `LengthU32` is a positive
// `Int`. Alpha/run slices are passed as an array plus a start offset.

///|
/// Mask is used to describe alpha bitmaps.
priv struct BlitMask {
  image : FixedArray[Int] // [u8; 2]
  bounds : ScreenIntRect
  row_bytes : Int
}

///|
/// Blitter is responsible for actually writing pixels into memory.
///
/// Besides efficiency, they handle clipping and antialiasing.
/// An object that implements Blitter contains all the context needed to
/// generate pixels for the destination and how src/generated pixels map to
/// the destination.
priv trait Blitter {
  /// Blits a horizontal run of one or more pixels.
  fn blit_h(Self, x : Int, y : Int, width : Int) -> Unit = _
  /// Blits a horizontal run of antialiased pixels.
  ///
  /// runs[] is a *sparse* zero-terminated run-length encoding of spans of
  /// constant alpha values.
  ///
  /// The runs[] and antialias[] work together to represent long runs of
  /// pixels with the same alphas. The runs[] contains the number of pixels
  /// with the same alpha, and antialias[] contain the coverage value for
  /// that number of pixels. The runs[] (and antialias[]) are *sparse*. All
  /// array values that are not referenced by runs[] are garbage. The runs[]
  /// is terminated with 0 (`None`).
  fn blit_anti_h(
    Self,
    x : Int,
    y : Int,
    antialias : FixedArray[Int],
    aa_offset : Int,
    runs : FixedArray[Int],
    runs_offset : Int,
  ) -> Unit = _
  /// Blits a vertical run of pixels with a constant alpha value.
  fn blit_v(Self, x : Int, y : Int, height : Int, alpha : Int) -> Unit = _
  fn blit_anti_h2(Self, x : Int, y : Int, alpha0 : Int, alpha1 : Int) -> Unit = _
  fn blit_anti_v2(Self, x : Int, y : Int, alpha0 : Int, alpha1 : Int) -> Unit = _
  /// Blits a solid rectangle one or more pixels wide.
  fn blit_rect(Self, rect : ScreenIntRect) -> Unit = _
  /// Blits a pattern of pixels defined by a rectangle-clipped mask.
  fn blit_mask(Self, mask : BlitMask, clip : ScreenIntRect) -> Unit = _
}

///|
/// The default implementations (upstream: `unreachable!()`).
impl Blitter with fn blit_h(_self, _x, _y, _width) {
  abort("unreachable")
}

///|
impl Blitter with fn blit_anti_h(
  _self,
  _x,
  _y,
  _aa,
  _aa_offset,
  _runs,
  _runs_offset,
) {
  abort("unreachable")
}

///|
impl Blitter with fn blit_v(_self, _x, _y, _height, _alpha) {
  abort("unreachable")
}

///|
impl Blitter with fn blit_anti_h2(_self, _x, _y, _alpha0, _alpha1) {
  abort("unreachable")
}

///|
impl Blitter with fn blit_anti_v2(_self, _x, _y, _alpha0, _alpha1) {
  abort("unreachable")
}

///|
impl Blitter with fn blit_rect(_self, _rect) {
  abort("unreachable")
}

///|
impl Blitter with fn blit_mask(_self, _mask, _clip) {
  abort("unreachable")
}
