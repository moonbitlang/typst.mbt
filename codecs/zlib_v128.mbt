// v128 kernels of the zlib-rs port (native and wasm; `zlib_scalar.mbt` is
// the wasm-gc/js counterpart). They compute exactly the same values as the
// scalar code: zlib-rs itself uses NEON for `compare256` and `adler32` on
// aarch64 with identical results.
//
// `@v128` memory operations are not bounds checked; every caller checks the
// accessed range first.

///|
/// `u64::from_le_bytes(window[i..i + 8])` without a bounds check.
#inline
fn load_u64_le_unchecked(window : FixedArray[Byte], i : Int) -> UInt64 {
  @v128.i64x2_extract_lane(@v128.v128_load64_zero(window, i), 0)
}

///|
/// `u32::from_le_bytes(window[i..i + 4])` without a bounds check.
#inline
fn load_u32_le_unchecked(window : FixedArray[Byte], i : Int) -> UInt {
  @v128.i32x4_extract_lane(@v128.v128_load32_zero(window, i), 0)
}

///|
/// [compare256] for in-bounds ranges: compares 16 bytes at a time. Only
/// called by [compare256] after checking `0 <= a, b <= window.length() -
/// 256`, so every load (`a + i`, `b + i` with `i <= 240`) is in bounds.
fn compare256_unchecked(window : FixedArray[Byte], a : Int, b : Int) -> Int {
  for i = 0; i < 256; i = i + 16 {
    let x = @v128.v128_load(window, a + i)
    let y = @v128.v128_load(window, b + i)
    let diff = @v128.v128_xor(x, y)
    if @v128.v128_any_true(diff) {
      let lo = @v128.i64x2_extract_lane(diff, 0)
      if lo != 0 {
        return i + lo.ctz() / 8
      }
      return i + 8 + @v128.i64x2_extract_lane(diff, 1).ctz() / 8
    }
  }
  256
}

///|
/// [adler32] of `data[off..off + len]` (the range must be in bounds).
///
/// Per block of at most `ADLER_NMAX` bytes, 16-byte chunks update
/// `adler += sum(b)` and `sum2 += 16 * adler + sum((16 - j) * b[j])`. The
/// lane sums are taken modulo 2^32, which is exact because the block's true
/// `sum2` is below 2^32 (the definition of `ADLER_NMAX`).
fn adler32_fixed(
  start_checksum : UInt,
  data : FixedArray[Byte],
  off : Int,
  len : Int,
) -> UInt {
  // All loads below are within `data[off..off + len]`.
  guard in_range(off, len.to_int64(), data.length()) else {
    abort("index out of bounds")
  }
  let mut sum2 = (start_checksum >> 16) & 0xffff
  let mut adler = start_checksum & 0xffff
  let weights_hi = @v128.i16x8_const(16, 15, 14, 13, 12, 11, 10, 9)
  let weights_lo = @v128.i16x8_const(8, 7, 6, 5, 4, 3, 2, 1)
  let zero = @v128.i32x4_splat(0)
  let mut i = off
  let end = off + len
  while i < end {
    let n = @cmp.minimum(ADLER_NMAX, end - i)
    let block_end = i + n
    let chunks = n / 16
    // sum2 gains n * adler from the bytes of this block.
    sum2 += n.reinterpret_as_uint() * adler
    let mut vs1 = zero
    let mut vs_prev = zero
    let mut vs2 = zero
    for _ in 0..<chunks {
      let v = @v128.v128_load(data, i)
      vs_prev = @v128.i32x4_add(vs_prev, vs1)
      let w16 = @v128.i16x8_extadd_pairwise_i8x16_u(v)
      vs1 = @v128.i32x4_add(vs1, @v128.i32x4_extadd_pairwise_i16x8_u(w16))
      let lo = @v128.i16x8_extend_low_i8x16_u(v)
      let hi = @v128.i16x8_extend_high_i8x16_u(v)
      vs2 = @v128.i32x4_add(vs2, @v128.i32x4_dot_i16x8_s(lo, weights_hi))
      vs2 = @v128.i32x4_add(vs2, @v128.i32x4_dot_i16x8_s(hi, weights_lo))
      i += 16
    }
    let s1 = hsum_u32x4(vs1)
    let s2 = (hsum_u32x4(vs_prev) << 4) + hsum_u32x4(vs2)
    // The remaining bytes of the block, one at a time (`n * adler` is
    // already in `sum2`, so only the block's own prefix sums are added).
    let mut a = s1
    let mut b = s2
    while i < block_end {
      a += data.unsafe_get(i).to_int().reinterpret_as_uint()
      b += a
      i += 1
    }
    adler = (adler + a) % ADLER_BASE
    sum2 = (sum2 + b) % ADLER_BASE
  }
  adler | (sum2 << 16)
}

///|
#inline
fn hsum_u32x4(v : V128) -> UInt {
  @v128.i32x4_extract_lane(v, 0) +
  @v128.i32x4_extract_lane(v, 1) +
  @v128.i32x4_extract_lane(v, 2) +
  @v128.i32x4_extract_lane(v, 3)
}
