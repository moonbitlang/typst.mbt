// Port of pic-scale's `neon/check_alpha.rs`
// (`neon_has_non_constant_cap_alpha_rgba8`).

///|
/// Whether some pixel's alpha differs from the first pixel's alpha (the
/// NEON code sums `alpha ^ first_alpha` per row; the sums cannot wrap).
fn neon_has_non_constant_cap_alpha_rgba8(
  store : FixedArray[Byte],
  width : Int,
  height : Int,
  stride : Int,
) -> Bool {
  if store.length() == 0 {
    return true
  }
  let first_alpha = store[3]
  for y in 0..<height {
    let row = y * stride
    for x in 0..<width {
      if store[row + x * 4 + 3] != first_alpha {
        return true
      }
    }
  }
  false
}
