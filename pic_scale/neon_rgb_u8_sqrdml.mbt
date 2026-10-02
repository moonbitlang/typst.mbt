// Port of pic-scale's `neon/rgb_u8_sqrdml.rs`
// (`convolve_horizontal_rgb_neon_rdm_row_one` and
// `convolve_horizontal_rgb_neon_rdm_rows_4`, which computes each of its four
// rows exactly like the one-row kernel).
//
// One `int16x8_t` accumulator holding two pixel slots: lanes 0..2 (slot A,
// starting at `1 << 5`) and lanes 4..6 (slot B, starting at 0); lanes 3 and
// 7 only ever get zero weights. Blocks of 4 taps put taps `jx, jx + 2` into
// slot A and `jx + 1, jx + 3` into slot B, a block of 2 puts `jx` into A and
// `jx + 1` into B, a single tap goes to A: so tap `j` always goes to slot
// `j % 2`, in tap order. Each lane saturates on its own (`vqrdmlahq_s16`);
// the slots are added with `vadd_s16` (modulo 2^16) and packed with
// `vqshrun_n_s16::<6>`.

///|
fn convolve_horizontal_rgb_neon_rdm_row_one(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  filter_weights : FixedWeights,
) -> Unit {
  let rounding_const = 1 << 5
  let lanes = FixedArray::make(6, 0)
  let n = filter_weights.bounds_start.length()
  for x in 0..<n {
    let start = src_offset + filter_weights.bounds_start[x] * 3
    let size = filter_weights.bounds_size[x]
    let w_off = x * filter_weights.aligned_size
    lanes[0] = rounding_const
    lanes[1] = rounding_const
    lanes[2] = rounding_const
    lanes[3] = 0
    lanes[4] = 0
    lanes[5] = 0
    for j in 0..<size {
      let w = filter_weights.weights[w_off + j]
      let p = start + j * 3
      let slot = (j & 1) * 3
      for c in 0..<3 {
        lanes[slot + c] = vqrdmlah_s16(
          lanes[slot + c],
          expand8_to_14(src[p + c].to_int()),
          w,
        )
      }
    }
    let d = dst_offset + x * 3
    for c in 0..<3 {
      dst[d + c] = pack_q6_u8(wrap_i16(lanes[c] + lanes[3 + c])).to_byte()
    }
  }
}
