// Port of `moxcms::transform` (transform construction and executors).
//
// Only the 8-bit and `f32` executors are ported, with the code paths that
// `moxcms` 0.8.1 selects on aarch64 with its default features (NEON shaper
// fixed-point paths and NEON Q0.15 LUT interpolators, `rdm` available). The
// NEON arithmetic is emulated lane by lane with identical rounding.

///|
/// Barycentric interpolation weights size.
pub(all) enum BarycentricWeightScale {
  /// Low scale weights is enough for common case.
  Low
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BarycentricWeightScale with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BarycentricWeightScale with @debug.Debug::{to_repr}

///|
/// Defines the interpolation method (only the default `Linear` is available
/// without the `options` feature).
pub(all) enum InterpolationMethod {
  /// Trilinear/Quadlinear interpolation
  Linear
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InterpolationMethod with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InterpolationMethod with @debug.Debug::{to_repr}

///|
/// Declares additional transformation options.
pub(all) struct TransformOptions {
  rendering_intent : RenderingIntent
  /// If set it will try to use Transfer Characteristics from CICP on
  /// transform.
  allow_use_cicp_transfer : Bool
  /// Prefers fixed point where implemented as default.
  prefer_fixed_point : Bool
  /// Interpolation method for 3D LUT.
  interpolation_method : InterpolationMethod
  /// Barycentric weights scale.
  barycentric_weight_scale : BarycentricWeightScale
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TransformOptions with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TransformOptions with @debug.Debug::{to_repr}

///|
pub fn TransformOptions::default() -> TransformOptions {
  {
    rendering_intent: Perceptual,
    allow_use_cicp_transfer: true,
    prefer_fixed_point: true,
    interpolation_method: Linear,
    barycentric_weight_scale: Low,
  }
}

///|
/// Layout declares a data layout. For RGB it shows also the channel order.
/// Cmyk8 uses the same layout as Rgba8.
pub(all) enum Layout {
  Rgb
  Rgba
  Cmyka
  Gray
  GrayAlpha
  Inks5
  Inks6
  Inks7
  Inks8
  Inks9
  Inks10
  Inks11
  Inks12
  Inks13
  Inks14
  Inks15
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Layout with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Layout with @debug.Debug::{to_repr}

///|
pub fn Layout::channels(self : Layout) -> Int {
  match self {
    Rgb => 3
    Rgba => 4
    Gray => 1
    GrayAlpha => 2
    Cmyka => 5
    Inks5 => 5
    Inks6 => 6
    Inks7 => 7
    Inks8 => 8
    Inks9 => 9
    Inks10 => 10
    Inks11 => 11
    Inks12 => 12
    Inks13 => 13
    Inks14 => 14
    Inks15 => 15
  }
}

///|
/// `T::NOT_FINITE_LINEAR_TABLE_SIZE` for `f32`.
let not_finite_linear_table_size : Int = 16384

///|
/// The `T`/`BIT_DEPTH`/`LINEAR_CAP`/`GAMMA_CAP` parameters of
/// `create_transform_nbit`.
priv struct Depth {
  finite : Bool
  bit_depth : Int
  linear_cap : Int
  gamma_cap : Int
}

///|
let depth_u8 : Depth = {
  finite: true,
  bit_depth: 8,
  linear_cap: 256,
  gamma_cap: 4096,
}

///|
let depth_f32 : Depth = {
  finite: false,
  bit_depth: 1,
  linear_cap: 65536,
  gamma_cap: 32768,
}

///|
/// `f32::as_()` into `T` (saturating `as u8` for 8-bit, identity for `f32`).
fn Depth::as_t(self : Depth, v : Float) -> Float {
  if self.finite {
    Float::from_int(@pxfm.f32_as_u8(v))
  } else {
    v
  }
}

///|
/// Sample type abstraction (`PointeeSizeExpressible` and friends).
priv trait Sample {
  /// `PointeeSizeExpressible::_as_usize`.
  fn as_usize(Self) -> Int
  /// Converts a table entry (an `f32` holding a `T` value) to `T`.
  fn from_table(Float) -> Self
  /// `((1 << BIT_DEPTH) - 1).as_()`.
  fn max_colors() -> Self
  /// `LutBarycentricReduction<T, u8>::reduce`.
  fn reduce_u8(Self) -> Int
  /// Output of the Q0.15 LUT executors.
  fn from_q0_15(Int) -> Self
}

///|
impl Sample for Byte with fn as_usize(self) {
  self.to_int()
}

///|
impl Sample for Byte with fn from_table(v) {
  @pxfm.f32_as_u8(v).to_byte()
}

///|
impl Sample for Byte with fn max_colors() {
  b'\xFF'
}

///|
impl Sample for Byte with fn reduce_u8(self) {
  self.to_int()
}

///|
impl Sample for Byte with fn from_q0_15(v) {
  // `vmax_s16(v, 0)`, `vmin_s16(v, 255)`, `as u32`, `as u8`
  let v = if v < 0 { 0 } else if v > 255 { 255 } else { v }
  v.to_byte()
}

///|
impl Sample for Float with fn as_usize(self) {
  let max_14_bit : Float = 16383.0
  @pxfm.f32_as_u16(
    @pxfm.min_f32(@pxfm.max_f32(self * max_14_bit, 0.0), max_14_bit),
  )
}

///|
impl Sample for Float with fn from_table(v) {
  v
}

///|
impl Sample for Float with fn max_colors() {
  // `((1 << 1) - 1) as f32`
  1.0
}

///|
impl Sample for Float with fn reduce_u8(self) {
  @pxfm.f32_as_u8(
    @pxfm.max_f32(@pxfm.min_f32(@pxfm.round_f32(self * 255.0), 255.0), 0.0),
  )
}

///|
impl Sample for Float with fn from_q0_15(v) {
  // `vcvtq_f32_s32(vmovl_s16(v)) * (1 / 16383)`
  Float::from_int(v) * (Float::from_int(1) / Float::from_int(16383))
}

///|
/// Transformation executor for 8-bit data.
///
/// `src` and `dst` are interleaved samples; the number of pixels in both must
/// match.
pub struct Transform8BitExecutor {
  priv run : (ArrayView[Byte], FixedArray[Byte]) -> Unit raise CmsError
}

///|
/// Transforms `src` into `dst` (`TransformExecutor::transform`).
pub fn Transform8BitExecutor::transform(
  self : Transform8BitExecutor,
  src : ArrayView[Byte],
  dst : FixedArray[Byte],
) -> Unit raise CmsError {
  (self.run)(src, dst)
}

///|
/// Transformation executor for `f32` data (normalized to `[0, 1]`).
pub struct TransformF32Executor {
  priv run : (ArrayView[Float], FixedArray[Float]) -> Unit raise CmsError
}

///|
/// Transforms `src` into `dst` (`TransformExecutor::transform`).
pub fn TransformF32Executor::transform(
  self : TransformF32Executor,
  src : ArrayView[Float],
  dst : FixedArray[Float],
) -> Unit raise CmsError {
  (self.run)(src, dst)
}

///|
/// A transform kernel: `(src, dst)` with interleaved samples.
type Kernel[T] = (ArrayView[T], FixedArray[T]) -> Unit raise CmsError

///|
/// Common lane checks of the executors.
fn check_lanes(
  src_len : Int,
  src_channels : Int,
  dst_len : Int,
  dst_channels : Int,
) -> Unit raise CmsError {
  if src_len / src_channels != dst_len / dst_channels {
    raise LaneSizeMismatch
  }
  if src_len % src_channels != 0 {
    raise LaneMultipleOfChannels
  }
  if dst_len % dst_channels != 0 {
    raise LaneMultipleOfChannels
  }
}

///|
fn ColorProfile::get_device_to_pcs(
  self : ColorProfile,
  intent : RenderingIntent,
) -> LutWarehouse? {
  match intent {
    AbsoluteColorimetric => self.lut_a_to_b_colorimetric
    Saturation => self.lut_a_to_b_saturation
    RelativeColorimetric => self.lut_a_to_b_colorimetric
    Perceptual => self.lut_a_to_b_perceptual
  }
}

///|
fn ColorProfile::get_pcs_to_device(
  self : ColorProfile,
  intent : RenderingIntent,
) -> LutWarehouse? {
  match intent {
    AbsoluteColorimetric => self.lut_b_to_a_colorimetric
    Saturation => self.lut_b_to_a_saturation
    RelativeColorimetric => self.lut_b_to_a_colorimetric
    Perceptual => self.lut_b_to_a_perceptual
  }
}

///|
/// Builds the executor kernel shared by the 8-bit and `f32` transforms.
fn[T : Sample] ColorProfile::create_transform_nbit(
  self : ColorProfile,
  depth : Depth,
  src_layout : Layout,
  dst_pr : ColorProfile,
  dst_layout : Layout,
  options : TransformOptions,
) -> Kernel[T] raise CmsError {
  if self.color_space == Rgb &&
    dst_pr.pcs == Xyz &&
    dst_pr.color_space == Rgb &&
    self.pcs == Xyz &&
    self.is_matrix_shaper() &&
    dst_pr.is_matrix_shaper() {
    if src_layout == Gray || src_layout == GrayAlpha {
      raise InvalidLayout
    }
    if dst_layout == Gray || dst_layout == GrayAlpha {
      raise InvalidLayout
    }
    if self.has_device_to_pcs_lut() || dst_pr.has_pcs_to_device_lut() {
      return make_lut_transform(
        depth, src_layout, self, dst_layout, dst_pr, options,
      )
    }
    let transform = self.transform_matrix(dst_pr)
    if self.are_all_trc_the_same() && dst_pr.are_all_trc_the_same() {
      let linear = self.build_r_linearize_table(
        depth,
        depth.linear_cap,
        options.allow_use_cicp_transfer,
      )
      let gamma = dst_pr.build_gamma_table(
        dst_pr.red_trc,
        depth,
        depth.gamma_cap,
        options.allow_use_cicp_transfer,
      )
      let profile_transform = {
        linear,
        gamma,
        adaptation_matrix: transform.to_f32(),
      }
      return make_optimized_transform(
        depth, src_layout, dst_layout, profile_transform, options,
      )
    }
    let lin_r = self.build_r_linearize_table(
      depth,
      depth.linear_cap,
      options.allow_use_cicp_transfer,
    )
    let lin_g = self.build_g_linearize_table(
      depth,
      depth.linear_cap,
      options.allow_use_cicp_transfer,
    )
    let lin_b = self.build_b_linearize_table(
      depth,
      depth.linear_cap,
      options.allow_use_cicp_transfer,
    )
    let gamma_r = dst_pr.build_gamma_table(
      dst_pr.red_trc,
      depth,
      depth.gamma_cap,
      options.allow_use_cicp_transfer,
    )
    let gamma_g = dst_pr.build_gamma_table(
      dst_pr.green_trc,
      depth,
      depth.gamma_cap,
      options.allow_use_cicp_transfer,
    )
    let gamma_b = dst_pr.build_gamma_table(
      dst_pr.blue_trc,
      depth,
      depth.gamma_cap,
      options.allow_use_cicp_transfer,
    )
    let profile_transform = {
      r_linear: lin_r,
      g_linear: lin_g,
      b_linear: lin_b,
      r_gamma: gamma_r,
      g_gamma: gamma_g,
      b_gamma: gamma_b,
      adaptation_matrix: transform.to_f32(),
    }
    make_rgb_xyz_rgb_transform(depth, src_layout, dst_layout, profile_transform)
  } else if self.color_space == Gray &&
    self.gray_trc is Some(_) &&
    (
      dst_pr.color_space == Rgb ||
      (dst_pr.color_space == Gray && dst_pr.gray_trc is Some(_))
    ) &&
    self.pcs == Xyz &&
    dst_pr.pcs == Xyz {
    if src_layout != GrayAlpha && src_layout != Gray {
      raise InvalidLayout
    }
    if self.has_device_to_pcs_lut() || dst_pr.has_pcs_to_device_lut() {
      return make_lut_transform(
        depth, src_layout, self, dst_layout, dst_pr, options,
      )
    }
    let gray_linear = self.build_gray_linearize_table(depth, depth.linear_cap)
    if dst_pr.color_space == Gray {
      // Gray -> Gray case
      let gray_gamma = dst_pr.build_gamma_table(
        dst_pr.gray_trc,
        depth,
        depth.gamma_cap,
        options.allow_use_cicp_transfer,
      )
      make_gray_to_x(depth, src_layout, dst_layout, gray_linear, gray_gamma)
    } else if dst_pr.are_all_trc_the_same() {
      // Gray -> RGB where all TRC is the same
      let rgb_gamma = dst_pr.build_gamma_table(
        dst_pr.red_trc,
        depth,
        depth.gamma_cap,
        options.allow_use_cicp_transfer,
      )
      make_gray_to_x(depth, src_layout, dst_layout, gray_linear, rgb_gamma)
    } else {
      // Gray -> RGB where all TRC is NOT the same
      let red_gamma = dst_pr.build_gamma_table(
        dst_pr.red_trc,
        depth,
        depth.gamma_cap,
        options.allow_use_cicp_transfer,
      )
      let green_gamma = dst_pr.build_gamma_table(
        dst_pr.green_trc,
        depth,
        depth.gamma_cap,
        options.allow_use_cicp_transfer,
      )
      let blue_gamma = dst_pr.build_gamma_table(
        dst_pr.blue_trc,
        depth,
        depth.gamma_cap,
        options.allow_use_cicp_transfer,
      )
      let gray_linear2 = FixedArray::make(65536, Float::from_int(0))
      for i in 0..<gray_linear.length() {
        gray_linear2[i] = gray_linear[i]
      }
      make_gray_to_unfused(
        depth, src_layout, dst_layout, gray_linear2, red_gamma, green_gamma, blue_gamma,
      )
    }
  } else if self.color_space == Rgb &&
    dst_pr.color_space == Gray &&
    dst_pr.gray_trc is Some(_) &&
    dst_pr.pcs == Xyz &&
    self.pcs == Xyz {
    if src_layout == Gray || src_layout == GrayAlpha {
      raise InvalidLayout
    }
    if dst_layout != Gray && dst_layout != GrayAlpha {
      raise InvalidLayout
    }
    if self.has_device_to_pcs_lut() || dst_pr.has_pcs_to_device_lut() {
      return make_lut_transform(
        depth, src_layout, self, dst_layout, dst_pr, options,
      )
    }
    // Deviation: RGB -> Gray (`make_rgb_to_gray`) is not ported.
    raise UnsupportedProfileConnection
  } else if (
      self.color_space.is_three_channels() ||
      self.color_space == Cmyk ||
      self.color_space == Color4
    ) &&
    (
      dst_pr.color_space.is_three_channels() ||
      dst_pr.color_space == Cmyk ||
      dst_pr.color_space == Color4
    ) &&
    (dst_pr.pcs == Xyz || dst_pr.pcs == Lab) &&
    (self.pcs == Xyz || self.pcs == Lab) {
    if src_layout == Gray || src_layout == GrayAlpha {
      raise InvalidLayout
    }
    if dst_layout == Gray || dst_layout == GrayAlpha {
      raise InvalidLayout
    }
    make_lut_transform(depth, src_layout, self, dst_layout, dst_pr, options)
  } else {
    make_lut_transform(depth, src_layout, self, dst_layout, dst_pr, options)
  }
}

///|
/// Creates transform between source and destination profile.
/// Only 8 bit is supported.
pub fn ColorProfile::create_transform_8bit(
  self : ColorProfile,
  src_layout : Layout,
  dst_pr : ColorProfile,
  dst_layout : Layout,
  options : TransformOptions,
) -> Transform8BitExecutor raise CmsError {
  let run : Kernel[Byte] = self.create_transform_nbit(
    depth_u8, src_layout, dst_pr, dst_layout, options,
  )
  { run, }
}

///|
/// Creates transform between source and destination profile.
/// Data has to be normalized into [0, 1] range; `f32` is treated as 14-bit
/// values. The result may be negative or more than 1.
pub fn ColorProfile::create_transform_f32(
  self : ColorProfile,
  src_layout : Layout,
  dst_pr : ColorProfile,
  dst_layout : Layout,
  options : TransformOptions,
) -> TransformF32Executor raise CmsError {
  // `Cmyka` is mapped to `Rgba` upstream; the interceptors are never installed.
  let src_layout = if src_layout == Cmyka { Rgba } else { src_layout }
  let dst_layout = if dst_layout == Cmyka { Rgba } else { dst_layout }
  let run : Kernel[Float] = self.create_transform_nbit(
    depth_f32, src_layout, dst_pr, dst_layout, options,
  )
  { run, }
}
