// Port of pic-scale's `neon/vertical_u8.rs`
// (`convolve_vertical_neon_i32_precision`).
//
// Each output byte is an independent column. The NEON code processes the
// row in blocks of 32/16/8/1 columns (and 4/2/1 source rows at a time), but
// every block performs the same per-lane operations in the same tap order,
// so a column-by-column emulation is exact. The accumulators are kept in
// `acc` (one per column) and the taps are applied in order.

///|
/// `convolve_vertical_neon_i32_precision` (`convolve_vertical_neon_row_full::
/// <false, 15>`): `vmlal_s16` into `i32` lanes starting at `1 << 14`, then
/// `vqshrun_n_s32::<15>` + `vqmovn_u16`.
fn convolve_vertical_neon_i32_precision(
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
  let rnd_const = 1 << (PRECISION - 1)
  for x in 0..<width {
    acc[x] = rnd_const
  }
  for j in 0..<bounds_size {
    let w = weights[weights_offset + j]
    let row = src_offset + src_stride * (bounds_start + j)
    for x in 0..<width {
      acc[x] = acc[x] + src[row + x].to_int() * w
    }
  }
  for x in 0..<width {
    dst[dst_offset + x] = pack_q15_u8(acc[x]).to_byte()
  }
}
