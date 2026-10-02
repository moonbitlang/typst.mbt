// Port of pic-scale's `neon/rgb_u8.rs` (`convolve_horizontal_rgb_neon_row_one`
// and `convolve_horizontal_rgb_neon_rows_4`, which computes each of its four
// rows exactly like the one-row kernel).
//
// One `i32` lane per channel starting at `1 << 14`, `vmlal_s16` per tap
// (never overflows), then `vqshrun_n_s32::<15>` + `vqmovn_u16`.

///|
fn convolve_horizontal_rgb_neon_row_one(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  filter_weights : FixedWeights,
) -> Unit {
  let rnd_const = 1 << (PRECISION - 1)
  let n = filter_weights.bounds_start.length()
  for x in 0..<n {
    let start = src_offset + filter_weights.bounds_start[x] * 3
    let size = filter_weights.bounds_size[x]
    let w_off = x * filter_weights.aligned_size
    let mut r = rnd_const
    let mut g = rnd_const
    let mut b = rnd_const
    for j in 0..<size {
      let w = filter_weights.weights[w_off + j]
      let p = start + j * 3
      r = r + src[p].to_int() * w
      g = g + src[p + 1].to_int() * w
      b = b + src[p + 2].to_int() * w
    }
    let d = dst_offset + x * 3
    dst[d] = pack_q15_u8(r).to_byte()
    dst[d + 1] = pack_q15_u8(g).to_byte()
    dst[d + 2] = pack_q15_u8(b).to_byte()
  }
}
