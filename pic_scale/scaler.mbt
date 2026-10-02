// Port of the parts of pic-scale's `scaler.rs` (`build_single_step_plan`),
// `plan/alpha_planner.rs` (`build_single_step_plan_with_alpha`),
// `plan/non_alpha_plan.rs`, `plan/alpha_plan.rs` and `plan/noop_plan.rs`
// that `Scaler::new(ResamplingFunction::CatmullRom)` reaches for u8 images
// (single threaded; no multi-step upscaling, no supersampling).

///|
/// Plans and runs one resample of an `channels`-channel u8 image
/// (`plan_*_resampling` + `ResamplingPlan::resample`).
fn resample_u8(
  src : Bytes,
  src_width : Int,
  src_height : Int,
  dst_width : Int,
  dst_height : Int,
  channels : Int,
  premultiply_alpha : Bool,
) -> Bytes {
  if src_width <= 0 || src_height <= 0 || dst_width <= 0 || dst_height <= 0 {
    abort("One of image dimensions is 0, this should not happen")
  }
  let expected = src_width * src_height * channels
  if src.length() < expected {
    abort(
      "Image buffer len expected to be \{expected} [w(\{src_width})*h(\{src_height})*channels(\{channels})] but received \{src.length()}",
    )
  }
  let src = src[:expected].to_fixedarray()
  let dst = FixedArray::make(dst_width * dst_height * channels, b'\x00')
  // `validate_sizes!` copies the image when the sizes match (`NoopPlan`).
  if src_width == dst_width && src_height == dst_height {
    FixedArray::blit_to(src, dst, len=expected)
    return Bytes::from_array(dst)
  }
  let should_do_horizontal = src_width != dst_width
  let should_do_vertical = src_height != dst_height
  let vertical_plan = if should_do_vertical {
    let vertical_filters = generate_weights(src_height, dst_height)
    Some(vertical_strategy_u8(vertical_filters, src_height, dst_height))
  } else {
    None
  }
  let horizontal_plan = if should_do_horizontal {
    let horizontal_filters = generate_weights(src_width, dst_width)
    Some(horizontal_plan(horizontal_filters, channels, src_width, dst_width))
  } else {
    None
  }
  // `maybe_premultiply_alpha` with forward and backward alpha handling.
  let (store, has_alpha_premultiplied) = if premultiply_alpha &&
    neon_has_non_constant_cap_alpha_rgba8(
      src,
      src_width,
      src_height,
      src_width * 4,
    ) {
    let scratch = FixedArray::make(expected, b'\x00')
    let stride = src_width * 4
    for y in 0..<src_height {
      neon_premultiply_alpha_rgba(
        scratch,
        y * stride,
        src,
        y * stride,
        src_width,
      )
    }
    (scratch, true)
  } else {
    (src, false)
  }
  let src_stride = src_width * channels
  let dst_stride = dst_width * channels
  match (vertical_plan, horizontal_plan) {
    (Some(v), Some(h)) =>
      trampoline_filter(h, v, store, src_width, dst, dst_height, channels)
    (Some(v), None) =>
      v.filter(store, src_stride, dst, dst_stride, dst_stride, dst_height)
    (None, Some(h)) => h.filter(store, src_stride, dst, dst_stride, dst_height)
    (None, None) => ()
  }
  if has_alpha_premultiplied {
    for y in 0..<dst_height {
      neon_unpremultiply_alpha_rgba(dst, y * dst_stride, dst_width)
    }
  }
  Bytes::from_array(dst)
}
