// The vertical kernels on the targets where `@v128` is emulated (wasm-gc,
// js): the lane emulations (`vertical_v128.mbt` is the native/wasm
// counterpart).

///|
/// [convolve_vertical_neon_i16_precision] (the `rdm` kernel).
fn vertical_rdm_kernel(
  width : Int,
  bounds_start : Int,
  bounds_size : Int,
  src : FixedArray[Byte],
  src_offset : Int,
  src_stride : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  weights : FixedArray[Int],
  weights_offset : Int,
  acc : FixedArray[Int],
) -> Unit {
  convolve_vertical_neon_i16_precision(
    width, bounds_start, bounds_size, src, src_offset, src_stride, dst, dst_offset,
    weights, weights_offset, acc,
  )
}

///|
/// [convolve_vertical_neon_i32_precision] (the Q15 `i32` kernel).
fn vertical_i32_kernel(
  width : Int,
  bounds_start : Int,
  bounds_size : Int,
  src : FixedArray[Byte],
  src_offset : Int,
  src_stride : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  weights : FixedArray[Int],
  weights_offset : Int,
  acc : FixedArray[Int],
) -> Unit {
  convolve_vertical_neon_i32_precision(
    width, bounds_start, bounds_size, src, src_offset, src_stride, dst, dst_offset,
    weights, weights_offset, acc,
  )
}
