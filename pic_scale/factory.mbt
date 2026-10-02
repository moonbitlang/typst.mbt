// Ports of the u8 kernel selection of pic-scale's `factory/plane_u8.rs`,
// `factory/rgb_u8.rs` and `factory/rgba_u8.rs` as it resolves on aarch64
// with the `neon` + `rdm` features (no `sve`, no `nightly_i8mm`), the CPU
// reporting `rdm`, and `WorkloadStrategy::PreferSpeed` (the default): the
// `rdm` (Q6 `i16`) kernels are used when the axis' downscale factor is
// below 8, the `i32` (Q15) kernels otherwise. The weights are always
// `numerical_approximation::<i16, 15>(0)`.

///|
/// `HorizontalFilterPass::<u8, f32, N>::horizontal_plan`.
fn horizontal_plan(
  filter_weights : FilterWeights,
  channels : Int,
  src_width : Int,
  dst_width : Int,
) -> HorizontalFiltering {
  let scale_factor : Float = Float::from_int(src_width) /
    Float::from_int(dst_width)
  let rdm = scale_factor < Float::from_int(8)
  let filter_row : RowKernel = match (channels, rdm) {
    (1, true) => convolve_horizontal_plane_neon_rdm_row
    (1, false) => convolve_horizontal_plane_neon_row
    (3, true) => convolve_horizontal_rgb_neon_rdm_row_one
    (3, false) => convolve_horizontal_rgb_neon_row_one
    (4, true) => convolve_horizontal_rgba_neon_row_i16
    _ => convolve_horizontal_rgba_neon_row
  }
  let i_weights = filter_weights.numerical_approximation_i16(PRECISION)
  { filter_row, filter_weights: i_weights, }
}

///|
/// `vertical_strategy_u8` (`VerticalConvolutionPass::<u8, f32, N>`).
fn vertical_strategy_u8(
  filter_weights : FilterWeights,
  src_height : Int,
  dst_height : Int,
) -> VerticalFiltering {
  let scale_factor : Float = Float::from_int(src_height) /
    Float::from_int(dst_height)
  let filter_row : ColumnKernel = if scale_factor < Float::from_int(8) {
    convolve_vertical_neon_i16_precision
  } else {
    convolve_vertical_neon_i32_precision
  }
  let i_weights = filter_weights.numerical_approximation_i16(PRECISION)
  { filter_row, filter_weights: i_weights, }
}
