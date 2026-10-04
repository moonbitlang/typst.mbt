// v128 versions of the vertical u8 kernels (native and wasm;
// `vertical_scalar.mbt` selects the lane emulations on wasm-gc/js). They
// run upstream's NEON instructions as their wasm SIMD equivalents on 16
// columns at a time, in tap order:
//
// - `vqrdmlahq_s16(acc, x, w)` = `SignedSatQ(acc + ((2 * x * w + 2^15) >>
//   16))` = `i16x8_add_sat_s(acc, i16x8_q15mulr_sat_s(x, w))`: the Q15
//   product `(x * w + 2^14) >> 15` only saturates for `x = w = -2^15`, and
//   `x` (a 14-bit pixel) is never negative.
// - `vmlal_s16` = `i32x4_extmul_*_i16x8_s` + `i32x4_add`.
// - `vqshrun_n_*` + `vqmovn_u16` = arithmetic shift + saturating narrowing.

///|
/// [convolve_vertical_neon_i16_precision] (the `rdm` kernel).
fn vertical_rdm_kernel(
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
  guard width >= 16 &&
    vertical_ranges_ok(
      width, bounds_start, bounds_size, src, src_offset, src_stride, dst, dst_offset,
      weights, weights_offset,
    ) else {
    convolve_vertical_neon_i16_precision(
      width, bounds_start, bounds_size, src, src_offset, src_stride, dst, dst_offset,
      weights, weights_offset, acc,
    )
  }
  let rounding = @v128.i16x8_splat(1 << (6 - 1))
  let mut x = 0
  while x < width {
    // The last block may overlap the previous one (same results).
    let x0 = if x <= width - 16 { x } else { width - 16 }
    let mut lo = rounding
    let mut hi = rounding
    for j in 0..<bounds_size {
      let w = @v128.i16x8_splat(
        weights.unsafe_get(weights_offset + j).reinterpret_as_uint().to_uint16(),
      )
      let row = src_offset + src_stride * (bounds_start + j)
      let p = @v128.v128_load(src, row + x0)
      lo = @v128.i16x8_add_sat_s(
        lo,
        @v128.i16x8_q15mulr_sat_s(
          expand8_to_14x8(@v128.i16x8_extend_low_i8x16_u(p)),
          w,
        ),
      )
      hi = @v128.i16x8_add_sat_s(
        hi,
        @v128.i16x8_q15mulr_sat_s(
          expand8_to_14x8(@v128.i16x8_extend_high_i8x16_u(p)),
          w,
        ),
      )
    }
    @v128.v128_store(
      dst,
      dst_offset + x0,
      @v128.i8x16_narrow_i16x8_u(
        @v128.i16x8_shr_s(lo, 6),
        @v128.i16x8_shr_s(hi, 6),
      ),
    )
    x = x0 + 16
  }
}

///|
/// [convolve_vertical_neon_i32_precision] (the Q15 `i32` kernel).
fn vertical_i32_kernel(
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
  guard width >= 16 &&
    vertical_ranges_ok(
      width, bounds_start, bounds_size, src, src_offset, src_stride, dst, dst_offset,
      weights, weights_offset,
    ) else {
    convolve_vertical_neon_i32_precision(
      width, bounds_start, bounds_size, src, src_offset, src_stride, dst, dst_offset,
      weights, weights_offset, acc,
    )
  }
  let rnd = @v128.i32x4_splat((1 << (PRECISION - 1)).reinterpret_as_uint())
  let mut x = 0
  while x < width {
    let x0 = if x <= width - 16 { x } else { width - 16 }
    let mut a0 = rnd
    let mut a1 = rnd
    let mut a2 = rnd
    let mut a3 = rnd
    for j in 0..<bounds_size {
      let w = @v128.i16x8_splat(
        weights.unsafe_get(weights_offset + j).reinterpret_as_uint().to_uint16(),
      )
      let row = src_offset + src_stride * (bounds_start + j)
      let p = @v128.v128_load(src, row + x0)
      let lo = @v128.i16x8_extend_low_i8x16_u(p)
      let hi = @v128.i16x8_extend_high_i8x16_u(p)
      a0 = @v128.i32x4_add(a0, @v128.i32x4_extmul_low_i16x8_s(lo, w))
      a1 = @v128.i32x4_add(a1, @v128.i32x4_extmul_high_i16x8_s(lo, w))
      a2 = @v128.i32x4_add(a2, @v128.i32x4_extmul_low_i16x8_s(hi, w))
      a3 = @v128.i32x4_add(a3, @v128.i32x4_extmul_high_i16x8_s(hi, w))
    }
    let lo = @v128.i16x8_narrow_i32x4_s(
      @v128.i32x4_shr_s(a0, PRECISION),
      @v128.i32x4_shr_s(a1, PRECISION),
    )
    let hi = @v128.i16x8_narrow_i32x4_s(
      @v128.i32x4_shr_s(a2, PRECISION),
      @v128.i32x4_shr_s(a3, PRECISION),
    )
    @v128.v128_store(dst, dst_offset + x0, @v128.i8x16_narrow_i16x8_u(lo, hi))
    x = x0 + 16
  }
}

///|
/// `expand8_to_14` on `u16` lanes: `(p * 257) >> 2`.
#inline
fn expand8_to_14x8(p : V128) -> V128 {
  @v128.i16x8_shr_u(@v128.v128_or_(@v128.i16x8_shl(p, 8), p), 2)
}

///|
/// Whether every access of a vertical kernel is in bounds.
fn vertical_ranges_ok(
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
) -> Bool {
  width >= 0 &&
  bounds_start >= 0 &&
  bounds_size >= 0 &&
  src_offset >= 0 &&
  src_stride >= 0 &&
  in_range(weights_offset, bounds_size.to_int64(), weights.length()) &&
  in_range(dst_offset, width.to_int64(), dst.length()) &&
  (
    bounds_size == 0 ||
    in_range(
      src_offset,
      src_stride.to_int64() *
      (bounds_start.to_int64() + bounds_size.to_int64() - 1L) +
      width.to_int64(),
      src.length(),
    )
  )
}

///|
/// Whether `[off, off + len)` lies within `[0, total)`, computed without
/// `Int` overflow (the `@v128` loads and stores are not bounds checked).
#inline
fn in_range(off : Int, len : Int64, total : Int) -> Bool {
  off >= 0 && len >= 0L && off.to_int64() + len <= total.to_int64()
}
