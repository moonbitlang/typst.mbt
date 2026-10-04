// The horizontal row kernels on the targets where `@v128` is emulated
// (wasm-gc, js): the lane emulations (`horizontal_v128.mbt` is the
// native/wasm counterpart).

///|
fn rgba_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  convolve_horizontal_rgba_neon_row_i16(src, src_offset, dst, dst_offset, fw)
}

///|
fn rgb_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  convolve_horizontal_rgb_neon_rdm_row_one(src, src_offset, dst, dst_offset, fw)
}

///|
fn plane_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  convolve_horizontal_plane_neon_rdm_row(src, src_offset, dst, dst_offset, fw)
}

///|
fn rgba_q15_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  convolve_horizontal_rgba_neon_row(src, src_offset, dst, dst_offset, fw)
}

///|
fn rgb_q15_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  convolve_horizontal_rgb_neon_row_one(src, src_offset, dst, dst_offset, fw)
}
