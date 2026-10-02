// TEMPORARY stub of the moxcms package (replaced by the real port).

///|
pub(all) struct Xyzd {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
pub fn Xyzd::new(x : Double, y : Double, z : Double) -> Xyzd {
  { x, y, z, }
}

///|
pub(all) enum DataColorSpace {
  Xyz
  Lab
  Rgb
  Gray
  Cmyk
} derive(Eq, Debug)

///|
pub(all) enum Layout {
  Rgb
  Rgba
  Gray
  GrayAlpha
} derive(Eq, Debug)

///|
pub suberror CmsError {
  CmsError
} derive(Debug)

///|
pub struct ColorProfile {
  mut white_point : Xyzd
  color_space : DataColorSpace
}

///|
pub struct TransformOptions {
  dummy : Int
}

///|
pub fn TransformOptions::default() -> TransformOptions {
  { dummy: 0, }
}

///|
pub fn ColorProfile::new_from_slice(
  _data : BytesView,
) -> ColorProfile raise CmsError {
  raise CmsError
}

///|
pub fn ColorProfile::new_srgb() -> ColorProfile {
  { white_point: Xyzd::new(0.0, 0.0, 0.0), color_space: Rgb, }
}

///|
pub fn ColorProfile::clone(self : ColorProfile) -> ColorProfile {
  { white_point: self.white_point, color_space: self.color_space, }
}

///|
pub struct Transform8BitExecutor {
  dummy : Int
}

///|
pub struct TransformF32Executor {
  dummy : Int
}

///|
pub fn ColorProfile::create_transform_8bit(
  _self : ColorProfile,
  _src_layout : Layout,
  _dst : ColorProfile,
  _dst_layout : Layout,
  _options : TransformOptions,
) -> Transform8BitExecutor raise CmsError {
  raise CmsError
}

///|
pub fn ColorProfile::create_transform_f32(
  _self : ColorProfile,
  _src_layout : Layout,
  _dst : ColorProfile,
  _dst_layout : Layout,
  _options : TransformOptions,
) -> TransformF32Executor raise CmsError {
  raise CmsError
}

///|
pub fn Transform8BitExecutor::transform(
  _self : Transform8BitExecutor,
  _src : BytesView,
  _dst : FixedArray[Byte],
) -> Unit raise CmsError {
  raise CmsError
}

///|
pub fn TransformF32Executor::transform(
  _self : TransformF32Executor,
  _src : ArrayView[Float],
  _dst : FixedArray[Float],
) -> Unit raise CmsError {
  raise CmsError
}

///|
pub fn ColorProfile::set_white_point(self : ColorProfile, w : Xyzd) -> Unit {
  self.white_point = w
}
