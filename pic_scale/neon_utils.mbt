// Scalar emulation of the AArch64 NEON lane operations used by the pic-scale
// u8 kernels (`neon/utils.rs` and the intrinsics called directly by the
// kernels). Every helper reproduces one lane of the instruction exactly
// (ARM ARM pseudocode), including saturation, rounding and wrapping.

///|
/// `SignedSatQ(x, 16)`.
fn sat_i16(x : Int) -> Int {
  if x > 32767 {
    32767
  } else if x < -32768 {
    -32768
  } else {
    x
  }
}

///|
/// Truncation of an integer to an `i16` lane (`vadd_s16`, `vaddvq_s16`).
fn wrap_i16(x : Int) -> Int {
  ((x & 0xffff) ^ 0x8000) - 0x8000
}

///|
/// One lane of `vqrdmlahq_s16(acc, x, w)` (SQRDMLAH, `esize = 16`):
/// `SignedSatQ(((acc << 16) + 2 * x * w + (1 << 15)) >> 16, 16)`. As the low
/// 16 bits of `acc << 16` are zero this equals the form below.
fn vqrdmlah_s16(acc : Int, x : Int, w : Int) -> Int {
  sat_i16(acc + ((2 * x * w + 32768) >> 16))
}

///|
/// One lane of `vqrdmulhq_s32(a, b)` (SQRDMULH, `esize = 32`):
/// `SignedSatQ((2 * a * b + (1 << 31)) >> 32, 32)`.
fn vqrdmulh_s32(a : Int, b : Int) -> Int {
  let v = (2L * a.to_int64() * b.to_int64() + 0x80000000L) >> 32
  if v > 0x7fffffffL {
    0x7fffffff
  } else if v < -0x80000000L {
    -0x7fffffff - 1
  } else {
    v.to_int()
  }
}

///|
/// `expand8_to_14`/`expand8_high_to_14`: `vzip(row, row)` duplicates each
/// byte into a `u16` lane (`p * 257`), then `vshrq_n_u16::<2>` keeps 14 bits.
fn expand8_to_14(p : Int) -> Int {
  (p * 257) >> 2
}

///|
/// `vqshrun_n_s32::<15>` followed by `vqmovn_u16` (and the equivalent
/// `max(0) >> 15` then `min(255)` of the horizontal kernels): an `i32`
/// accumulator in Q15 to a saturated `u8`.
fn pack_q15_u8(acc : Int) -> Int {
  let v = acc >> 15
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}

///|
/// `vqshrun_n_s16::<6>` (and `vshr_n_s16::<6>` + `vqmovun_s16`): an `i16`
/// accumulator in Q6 to a saturated `u8`.
fn pack_q6_u8(acc : Int) -> Int {
  let v = acc >> 6
  if v < 0 {
    0
  } else if v > 255 {
    255
  } else {
    v
  }
}
