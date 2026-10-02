// Port of `tiny-skia/src/mask.rs`.

///|
/// A mask type.
pub(all) enum MaskType {
  /// Transfers only the Alpha channel from `Pixmap` to `Mask`.
  Alpha
  /// Transfers RGB channels as luminance from `Pixmap` to `Mask`.
  ///
  /// Formula: `Y = 0.2125 * R + 0.7154 * G + 0.0721 * B`
  Luminance
} derive(Eq, Debug)

///|
/// A mask.
///
/// During drawing over `Pixmap`, mask's black (0) "pixels" would block
/// rendering and white (255) will allow it. Anything in between is used for
/// anti-aliasing.
pub struct Mask {
  data : FixedArray[Byte]
  size : @path.IntSize
}

///|
/// Creates a new mask by taking ownership over a mask buffer.
///
/// The size needs to match the data provided.
pub fn Mask::new(width : UInt, height : UInt) -> Mask? {
  guard @path.IntSize::from_wh(width, height) is Some(size) else { return None }
  let len = width.reinterpret_as_int() * height.reinterpret_as_int()
  Some({ data: FixedArray::make(len, b'\x00'), size, })
}

///|
/// Creates a new mask from a `PixmapRef`.
pub fn Mask::from_pixmap(pixmap : Pixmap, mask_type : MaskType) -> Mask {
  let data_len = pixmap.width() * pixmap.height()
  let data = FixedArray::make(data_len, b'\x00')
  match mask_type {
    Alpha =>
      for i in 0..<data_len {
        data[i] = PremultipliedColorU8(pixmap.data[i]).alpha().to_byte()
      }
    Luminance =>
      for i in 0..<data_len {
        let p = PremultipliedColorU8(pixmap.data[i])
        // Normalize.
        let mut r = Float::from_int(p.red()) / 255.0
        let mut g = Float::from_int(p.green()) / 255.0
        let mut b = Float::from_int(p.blue()) / 255.0
        let a = Float::from_int(p.alpha()) / 255.0

        // Demultiply.
        if p.alpha() != 0 {
          r /= a
          g /= a
          b /= a
        }
        let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
        // `f32::clamp` (not NaN-aware).
        let v = luma * a * 255.0
        let v : Float = if v < 0.0 {
          0.0
        } else if v > 255.0 {
          255.0
        } else {
          v
        }
        data[i] = f32_to_u8(@path.ceilf(v)).to_byte()
      }
  }
  { data, size: pixmap.size, }
}

///|
/// Creates a new mask by taking ownership over a mask buffer.
pub fn Mask::from_vec(data : FixedArray[Byte], size : @path.IntSize) -> Mask? {
  let data_len = size.width().reinterpret_as_int() *
    size.height().reinterpret_as_int()
  if data.length() != data_len {
    return None
  }
  Some({ data, size, })
}

///|
/// Returns mask's width.
pub fn Mask::width(self : Mask) -> Int {
  self.size.width().reinterpret_as_int()
}

///|
/// Returns mask's height.
pub fn Mask::height(self : Mask) -> Int {
  self.size.height().reinterpret_as_int()
}

///|
pub fn Mask::size(self : Mask) -> @path.IntSize {
  self.size
}

///|
/// Returns the internal data.
pub fn Mask::data(self : Mask) -> FixedArray[Byte] {
  self.data
}

///|
/// Returns a copy of the mask.
pub fn Mask::clone(self : Mask) -> Mask {
  { data: self.data.copy(), size: self.size, }
}

///|
fn Mask::as_submask(self : Mask) -> SubMaskRef {
  {
    data: self.data,
    offset: 0,
    size: self.size,
    real_width: self.size.width().reinterpret_as_int(),
  }
}

///|
fn Mask::submask(self : Mask, rect : @path.IntRect) -> SubMaskRef? {
  guard self.size.to_int_rect(0, 0).intersect(rect) is Some(rect) else {
    return None
  }
  let row_bytes = self.width()
  let offset = rect.top() * row_bytes + rect.left()
  Some({
    data: self.data,
    offset,
    size: rect.size(),
    real_width: self.size.width().reinterpret_as_int(),
  })
}

///|
fn Mask::as_subpixmap(self : Mask) -> SubPixmapMut {
  {
    pixels: empty_pixels,
    bytes: self.data,
    offset: 0,
    size: self.size,
    real_width: self.width(),
  }
}

///|
fn Mask::subpixmap(self : Mask, rect : @path.IntRect) -> SubPixmapMut? {
  guard self.size.to_int_rect(0, 0).intersect(rect) is Some(rect) else {
    return None
  }
  let row_bytes = self.width()
  let offset = rect.top() * row_bytes + rect.left()
  Some({
    pixels: empty_pixels,
    bytes: self.data,
    offset,
    size: rect.size(),
    real_width: self.width(),
  })
}

///|
/// Draws a filled path onto the mask.
///
/// In terms of RGB (no alpha) image, draws a white path on top of black mask.
///
/// Doesn't reset the existing mask content and draws the path on top of it.
///
/// Almost a direct copy of PixmapMut::fill_path
pub fn Mask::fill_path(
  self : Mask,
  path : @path.Path,
  fill_rule : FillRule,
  anti_alias : Bool,
  transform : @path.Transform,
) -> Unit {
  if transform.is_identity() {
    // This is sort of similar to SkDraw::drawPath

    // Skip empty paths and horizontal/vertical lines.
    let path_bounds = path.bounds()
    if @path.is_nearly_zero(path_bounds.width()) ||
      @path.is_nearly_zero(path_bounds.height()) {
      // empty paths and horizontal/vertical lines cannot be filled
      return
    }
    if is_too_big_for_math(path) {
      // path coordinates are too big
      return
    }

    // TODO: ignore paths outside the pixmap
    match DrawTiler::new(self.width(), self.height()) {
      Some(tiler) => {
        let mut path = path // TODO: avoid cloning
        while tiler.next() is Some(tile) {
          let ts = @path.Transform::from_translate(
            -Float::from_int(tile.x()),
            -Float::from_int(tile.y()),
          )
          path = match path.transform(ts) {
            Some(v) => v
            None =>
              // path transformation failed
              return
          }
          let clip_rect = int_size_to_screen_int_rect(tile.size(), 0, 0)
          guard self.subpixmap(tile.to_int_rect()) is Some(subpix) else { // technically unreachable
            continue
          }
          guard RasterPipelineBlitter::new_mask(subpix) is Some(blitter) else { // nothing to do, all good
            continue
          }

          // We're ignoring "errors" here, because `fill_path` will return
          // `None` when rendering a tile that doesn't have a path on it.
          // Which is not an error in this case.
          if anti_alias {
            scan_path_aa_fill_path(path, fill_rule, clip_rect, blitter)
          } else {
            scan_path_fill_path(path, fill_rule, clip_rect, blitter)
          }
          let ts = @path.Transform::from_translate(
            Float::from_int(tile.x()),
            Float::from_int(tile.y()),
          )
          path = match path.transform(ts) {
            Some(v) => v
            None => return // technically unreachable
          }
        }
      }
      None => {
        let clip_rect = int_size_to_screen_int_rect(self.size, 0, 0)
        let subpix = self.as_subpixmap()
        guard RasterPipelineBlitter::new_mask(subpix) is Some(blitter) else { // nothing to do, all good
          return
        }
        if anti_alias {
          scan_path_aa_fill_path(path, fill_rule, clip_rect, blitter)
        } else {
          scan_path_fill_path(path, fill_rule, clip_rect, blitter)
        }
      }
    }
  } else {
    let path = match path.transform(transform) {
      Some(v) => v
      None =>
        // path transformation failed
        return
    }
    self.fill_path(path, fill_rule, anti_alias, @path.Transform::identity())
  }
}

///|
/// Intersects the provided path with the current clipping path.
///
/// A temporary mask with the same size as the current one will be created.
pub fn Mask::intersect_path(
  self : Mask,
  path : @path.Path,
  fill_rule : FillRule,
  anti_alias : Bool,
  transform : @path.Transform,
) -> Unit {
  let submask = Mask::new(self.size.width(), self.size.height()).unwrap()
  submask.fill_path(path, fill_rule, anti_alias, transform)
  for i in 0..<self.data.length() {
    self.data[i] = premultiply_u8(
      self.data[i].to_int(),
      submask.data[i].to_int(),
    ).to_byte()
  }
}

///|
/// Inverts the mask.
pub fn Mask::invert(self : Mask) -> Unit {
  for i in 0..<self.data.length() {
    self.data[i] = (255 - self.data[i].to_int()).to_byte()
  }
}

///|
/// Clears the mask.
///
/// Zero-fills the internal data buffer.
pub fn Mask::clear(self : Mask) -> Unit {
  self.data.fill(b'\x00')
}

///|
/// A view into a mask region.
priv struct SubMaskRef {
  data : FixedArray[Byte]
  offset : Int
  size : @path.IntSize
  real_width : Int
}

///|
fn SubMaskRef::mask_ctx(self : SubMaskRef) -> MaskCtx {
  { data: self.data, offset: self.offset, real_width: self.real_width, }
}
