// A bit-exact port of the code paths of the `pic-scale` crate (0.7.12) that
// hayro's renderer uses to downsample images: `Scaler::new(
// ResamplingFunction::CatmullRom)` with default settings, u8 planar, RGB and
// RGBA (with alpha premultiplication) plans, as they execute on aarch64 with
// the `neon` + `rdm` features (the NEON kernels are emulated lane by lane).
//
// Checked against the real crate by `oracle_wbtest.mbt`
// (`oracle/src/bin/gen_pic_scale_tests.rs`).

///|
/// Resamples a single-channel u8 image of `src_width` x `src_height` pixels
/// to `dst_width` x `dst_height` (`Scaler::new(CatmullRom)
/// .plan_planar_resampling(..)` + `resample`). Aborts if a dimension is not
/// positive or `src` is too short.
pub fn resize_planar_u8(
  src : Bytes,
  src_width : Int,
  src_height : Int,
  dst_width : Int,
  dst_height : Int,
) -> Bytes {
  resample_u8(src, src_width, src_height, dst_width, dst_height, 1, false)
}

///|
/// Resamples an interleaved RGB u8 image (`plan_rgb_resampling`).
pub fn resize_rgb_u8(
  src : Bytes,
  src_width : Int,
  src_height : Int,
  dst_width : Int,
  dst_height : Int,
) -> Bytes {
  resample_u8(src, src_width, src_height, dst_width, dst_height, 3, false)
}

///|
/// Resamples an interleaved RGBA u8 image with straight alpha, filtering in
/// premultiplied space (`plan_rgba_resampling(.., premultiply_alpha: true)`;
/// skipped when the alpha is constant).
pub fn resize_rgba_u8_premultiplied(
  src : Bytes,
  src_width : Int,
  src_height : Int,
  dst_width : Int,
  dst_height : Int,
) -> Bytes {
  resample_u8(src, src_width, src_height, dst_width, dst_height, 4, true)
}
