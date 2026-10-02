// Port of pic-scale's `neon/rgba_u8_rdm.rs`
// (`convolve_horizontal_rgba_neon_row_i16` and
// `convolve_horizontal_rgba_neon_rows_4_u8_i16`, which computes each of its
// four rows exactly like the one-row kernel).
//
// One `int16x8_t` accumulator holding two pixel slots: lanes 0..3 (slot A,
// starting at `1 << 5`) and lanes 4..7 (slot B, starting at 0). Blocks of
// 8/4/2 taps put even taps into slot A and odd taps into slot B, in tap
// order, each lane saturating on its own (`vqrdmlahq_s16`). The slots are
// then added with `vadd_s16` (modulo 2^16), a remaining single tap is
// accumulated into that sum with `vqrdmlah_s16`, and the result is packed
// with `vshr_n_s16::<6>` + `vqmovun_s16`.

///|
fn convolve_horizontal_rgba_neon_row_i16(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  filter_weights : FixedWeights,
) -> Unit {
  let rounding = 1 << (6 - 1)
  let lanes = FixedArray::make(8, 0)
  let n = filter_weights.bounds_start.length()
  for x in 0..<n {
    let start = src_offset + filter_weights.bounds_start[x] * 4
    let size = filter_weights.bounds_size[x]
    let w_off = x * filter_weights.aligned_size
    for c in 0..<4 {
      lanes[c] = rounding
      lanes[4 + c] = 0
    }
    let pairs_end = size & -2
    for j in 0..<pairs_end {
      let w = filter_weights.weights[w_off + j]
      let p = start + j * 4
      let slot = (j & 1) * 4
      for c in 0..<4 {
        lanes[slot + c] = vqrdmlah_s16(
          lanes[slot + c],
          expand8_to_14(src[p + c].to_int()),
          w,
        )
      }
    }
    for c in 0..<4 {
      lanes[c] = wrap_i16(lanes[c] + lanes[4 + c])
    }
    if pairs_end < size {
      let j = pairs_end
      let w = filter_weights.weights[w_off + j]
      let p = start + j * 4
      for c in 0..<4 {
        lanes[c] = vqrdmlah_s16(lanes[c], expand8_to_14(src[p + c].to_int()), w)
      }
    }
    let d = dst_offset + x * 4
    for c in 0..<4 {
      dst[d + c] = pack_q6_u8(lanes[c]).to_byte()
    }
  }
}
