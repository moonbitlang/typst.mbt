// Port of pic-scale's `neon/plane_u8_rdm.rs`
// (`convolve_horizontal_plane_neon_rdm_row` and
// `convolve_horizontal_plane_neon_rows_rdm_4_u8`, which computes each of its
// four rows exactly like the one-row kernel).
//
// One `int16x8_t` accumulator (lane 0 starts at `1 << 5`). Taps are consumed
// in blocks of 32/16/8 (tap `j` goes to lane `j % 8`), then at most one
// block of 4 (lanes 0..3, i.e. again `j % 8` as the block starts at a
// multiple of 8) and single taps (lane 0). Each lane saturates on its own
// (`vqrdmlahq_s16`); `vaddvq_s16` sums the lanes modulo 2^16.

///|
fn convolve_horizontal_plane_neon_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  filter_weights : FixedWeights,
) -> Unit {
  let rounding_const = 1 << (6 - 1)
  let lanes = FixedArray::make(8, 0)
  let n = filter_weights.bounds_start.length()
  for x in 0..<n {
    let start = src_offset + filter_weights.bounds_start[x]
    let size = filter_weights.bounds_size[x]
    let w_off = x * filter_weights.aligned_size
    for l in 0..<8 {
      lanes[l] = 0
    }
    lanes[0] = rounding_const
    let blocks_end = size & -4
    for j in 0..<size {
      let lane = if j < blocks_end { j & 7 } else { 0 }
      lanes[lane] = vqrdmlah_s16(
        lanes[lane],
        expand8_to_14(src[start + j].to_int()),
        filter_weights.weights[w_off + j],
      )
    }
    let mut sums = 0
    for l in 0..<8 {
      sums += lanes[l]
    }
    dst[dst_offset + x] = pack_q6_u8(wrap_i16(sums)).to_byte()
  }
}
