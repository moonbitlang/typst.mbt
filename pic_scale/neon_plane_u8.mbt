// Port of pic-scale's `neon/plane_u8.rs` (`convolve_horizontal_plane_neon_row`
// and `convolve_horizontal_plane_neon_rows_4_u8`, which computes each of its
// four rows exactly like the one-row kernel).
//
// `vmlal_s16` into four `i32` lanes (lane 0 starts at `1 << 14`), summed by
// `vaddvq_s32`: the lanes never overflow, so the result is the plain sum.

///|
/// `PRECISION` of `support.rs`.
const PRECISION : Int = 15

///|
fn convolve_horizontal_plane_neon_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  filter_weights : FixedWeights,
) -> Unit {
  let rnd_const = 1 << (PRECISION - 1)
  let n = filter_weights.bounds_start.length()
  for x in 0..<n {
    let start = src_offset + filter_weights.bounds_start[x]
    let size = filter_weights.bounds_size[x]
    let w_off = x * filter_weights.aligned_size
    let mut store = rnd_const
    for j in 0..<size {
      store = store +
        src[start + j].to_int() * filter_weights.weights[w_off + j]
    }
    dst[dst_offset + x] = pack_q15_u8(store).to_byte()
  }
}
