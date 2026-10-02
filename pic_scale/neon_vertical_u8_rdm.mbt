// Port of pic-scale's `neon/vertical_u8_rdm.rs`
// (`convolve_vertical_neon_i16_precision`). As in `neon_vertical_u8.mbt`,
// the 32/16/8/1-column blocks (including the `convolve_32_items_unrolled`
// variants for 2/4/6/8 taps) all apply `vqrdmlahq_s16` per column in tap
// order, so a column-by-column emulation is exact.

///|
/// `convolve_vertical_neon_i16_precision` (`convolve_vertical_neon_row_upper`):
/// pixels expanded to 14 bits, `vqrdmlahq_s16` into `i16` lanes starting at
/// `1 << 5` (`SCALE = 6`), then `vqshrun_n_s16::<6>`.
fn convolve_vertical_neon_i16_precision(
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
  let rounding = 1 << (6 - 1)
  for x in 0..<width {
    acc[x] = rounding
  }
  for j in 0..<bounds_size {
    let w = weights[weights_offset + j]
    let row = src_offset + src_stride * (bounds_start + j)
    for x in 0..<width {
      acc[x] = vqrdmlah_s16(acc[x], expand8_to_14(src[row + x].to_int()), w)
    }
  }
  for x in 0..<width {
    dst[dst_offset + x] = pack_q6_u8(acc[x]).to_byte()
  }
}
