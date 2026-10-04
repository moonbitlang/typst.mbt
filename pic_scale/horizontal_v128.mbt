// v128 versions of the horizontal u8 row kernels (native and wasm;
// `horizontal_scalar.mbt` selects the lane emulations on wasm-gc/js). Each
// keeps upstream's accumulator layout (slots, lanes, tap order) and maps
// the NEON instructions to their wasm SIMD equivalents (see
// `vertical_v128.mbt`). Rows with out-of-range taps run the emulation (which
// panics like upstream); RGB pixels are loaded with up to 2 bytes of
// over-read, so RGB pixels whose taps end within 2 bytes of the buffer's
// end are computed one channel at a time. Rows whose weights are not `i16`
// values (the rdm lanes hold `i16` weights, the emulation full `Int`s;
// `numerical_approximation_i16` clamps them) or whose `dst` aliases `src`
// also run the emulation.

///|
/// Whether every pixel's taps of a row (`channels` bytes per pixel) are
/// within `src`, the output within `dst` and the weights within their array.
fn horizontal_ranges_ok(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
  channels : Int,
) -> Bool {
  let n = fw.bounds_start.length()
  if physical_equal(src, dst) ||
    !fw.weights_fit_i16 ||
    src_offset < 0 ||
    !in_range(dst_offset, n.to_int64() * channels.to_int64(), dst.length()) ||
    fw.bounds_size.length() < n ||
    fw.aligned_size < 0 ||
    n.to_int64() * fw.aligned_size.to_int64() > fw.weights.length().to_int64() {
    return false
  }
  for x in 0..<n {
    let start = fw.bounds_start.unsafe_get(x)
    let size = fw.bounds_size.unsafe_get(x)
    if start < 0 ||
      size < 0 ||
      size > fw.aligned_size ||
      !in_range(
        src_offset,
        (start.to_int64() + size.to_int64()) * channels.to_int64(),
        src.length(),
      ) {
      return false
    }
  }
  true
}

///|
/// `i16x8` with lanes 0..3 = `a` and lanes 4..7 = `b` (16-bit weights).
#inline
fn weights_2x4(a : Int, b : Int) -> V128 {
  @v128.i32x4_replace_lane(
    @v128.i32x4_replace_lane(
      @v128.i32x4_splat(((a & 0xffff) | (a << 16)).reinterpret_as_uint()),
      ((b & 0xffff) | (b << 16)).reinterpret_as_uint(),
      2,
    ),
    ((b & 0xffff) | (b << 16)).reinterpret_as_uint(),
    3,
  )
}

///|
/// `vqrdmlahq_s16(acc, expand8_to_14(p), w)` for the low 8 bytes of `p`.
#inline
fn rdmlah_u8x8(acc : V128, p : V128, w : V128) -> V128 {
  @v128.i16x8_add_sat_s(
    acc,
    @v128.i16x8_q15mulr_sat_s(
      expand8_to_14x8(@v128.i16x8_extend_low_i8x16_u(p)),
      w,
    ),
  )
}

///|
/// Adds lanes 4..7 to lanes 0..3 (`vadd_s16(vget_low, vget_high)`).
#inline
fn add_slots(acc : V128) -> V128 {
  @v128.i16x8_add(
    acc,
    @v128.i8x16_shuffle(
      acc, acc, 8, 9, 10, 11, 12, 13, 14, 15, 8, 9, 10, 11, 12, 13, 14, 15,
    ),
  )
}

///|
/// `vqshrun_n_s16::<6>` of the low lanes, as bytes.
#inline
fn pack_q6(acc : V128) -> V128 {
  let v = @v128.i16x8_shr_s(acc, 6)
  @v128.i8x16_narrow_i16x8_u(v, v)
}

///|
/// [convolve_horizontal_rgba_neon_row_i16].
fn rgba_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  guard horizontal_ranges_ok(src, src_offset, dst, dst_offset, fw, 4) else {
    convolve_horizontal_rgba_neon_row_i16(src, src_offset, dst, dst_offset, fw)
  }
  let init = @v128.i16x8_const(32, 32, 32, 32, 0, 0, 0, 0)
  let weights = fw.weights
  for x in 0..<fw.bounds_start.length() {
    let start = src_offset + fw.bounds_start.unsafe_get(x) * 4
    let size = fw.bounds_size.unsafe_get(x)
    let w_off = x * fw.aligned_size
    let mut acc = init
    let pairs_end = size & -2
    let mut j = 0
    while j < pairs_end {
      let w = weights_2x4(
        weights.unsafe_get(w_off + j),
        weights.unsafe_get(w_off + j + 1),
      )
      acc = rdmlah_u8x8(acc, @v128.v128_load64_zero(src, start + j * 4), w)
      j += 2
    }
    acc = add_slots(acc)
    if pairs_end < size {
      let w = @v128.i16x8_splat(
        weights.unsafe_get(w_off + pairs_end).reinterpret_as_uint().to_uint16(),
      )
      acc = rdmlah_u8x8(
        acc,
        @v128.v128_load32_zero(src, start + pairs_end * 4),
        w,
      )
    }
    @v128.v128_store32_lane(dst, dst_offset + x * 4, pack_q6(acc), 0)
  }
}

///|
/// [convolve_horizontal_rgb_neon_rdm_row_one].
fn rgb_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  guard horizontal_ranges_ok(src, src_offset, dst, dst_offset, fw, 3) else {
    convolve_horizontal_rgb_neon_rdm_row_one(
      src, src_offset, dst, dst_offset, fw,
    )
  }
  let init = @v128.i16x8_const(32, 32, 32, 0, 0, 0, 0, 0)
  // Lanes 3 and 7 get zero weights.
  let mask = @v128.i16x8_const(
    0xffff, 0xffff, 0xffff, 0, 0xffff, 0xffff, 0xffff, 0,
  )
  let weights = fw.weights
  for x in 0..<fw.bounds_start.length() {
    let start = src_offset + fw.bounds_start.unsafe_get(x) * 3
    let size = fw.bounds_size.unsafe_get(x)
    let w_off = x * fw.aligned_size
    if !in_range(start, size.to_int64() * 3 + 2, src.length()) {
      rgb_rdm_pixel(src, start, size, dst, dst_offset + x * 3, weights, w_off)
      continue
    }
    let mut acc = init
    let mut j = 0
    // Tap `j` goes to slot `j % 2`.
    while j <= size - 2 {
      let w = @v128.v128_and_(
        weights_2x4(
          weights.unsafe_get(w_off + j),
          weights.unsafe_get(w_off + j + 1),
        ),
        mask,
      )
      // Bytes 0..2 and 3..5 into lanes 0..2 and 4..6.
      let p = @v128.i8x16_shuffle(
        @v128.v128_load64_zero(src, start + j * 3),
        @v128.i8x16_splat(b'\x00'),
        0,
        1,
        2,
        16,
        3,
        4,
        5,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
      )
      acc = rdmlah_u8x8(acc, p, w)
      j += 2
    }
    if j < size {
      let w = @v128.v128_and_(
        weights_2x4(weights.unsafe_get(w_off + j), 0),
        mask,
      )
      let p = @v128.i8x16_shuffle(
        @v128.v128_load32_zero(src, start + j * 3),
        @v128.i8x16_splat(b'\x00'),
        0,
        1,
        2,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
        16,
      )
      acc = rdmlah_u8x8(acc, p, w)
    }
    let out = pack_q6(add_slots(acc))
    let d = dst_offset + x * 3
    // Three bytes (a four-byte store would clobber the next pixel's first
    // byte, which is written later anyway, but stay exact at the row end).
    dst.unsafe_set(
      d,
      @v128.i8x16_extract_lane_u(out, 0).reinterpret_as_int().to_byte(),
    )
    dst.unsafe_set(
      d + 1,
      @v128.i8x16_extract_lane_u(out, 1).reinterpret_as_int().to_byte(),
    )
    dst.unsafe_set(
      d + 2,
      @v128.i8x16_extract_lane_u(out, 2).reinterpret_as_int().to_byte(),
    )
  }
}

///|
/// [convolve_horizontal_plane_neon_rdm_row].
fn plane_rdm_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  guard horizontal_ranges_ok(src, src_offset, dst, dst_offset, fw, 1) else {
    convolve_horizontal_plane_neon_rdm_row(src, src_offset, dst, dst_offset, fw)
  }
  let init = @v128.i16x8_const(32, 0, 0, 0, 0, 0, 0, 0)
  let weights = fw.weights
  for x in 0..<fw.bounds_start.length() {
    let start = src_offset + fw.bounds_start.unsafe_get(x)
    let size = fw.bounds_size.unsafe_get(x)
    let w_off = x * fw.aligned_size
    let mut acc = init
    let blocks_end = size & -4
    let mut j = 0
    // Tap `j < blocks_end` goes to lane `j % 8`: blocks of 8, then a block
    // of 4 (lanes 0..3).
    while j < blocks_end {
      let count = if j <= blocks_end - 8 { 8 } else { 4 }
      let w = @v128.i16x8_narrow_i32x4_s(
        gather_weights4(weights, w_off + j),
        if count == 8 {
          gather_weights4(weights, w_off + j + 4)
        } else {
          @v128.i32x4_splat(0)
        },
      )
      let p = if count == 8 {
        @v128.v128_load64_zero(src, start + j)
      } else {
        @v128.v128_load32_zero(src, start + j)
      }
      acc = rdmlah_u8x8(acc, p, w)
      j += count
    }
    // Single taps into lane 0.
    while j < size {
      let w = @v128.i16x8_replace_lane(
        @v128.i16x8_splat(0),
        weights.unsafe_get(w_off + j).reinterpret_as_uint() & 0xffff,
        0,
      )
      acc = rdmlah_u8x8(
        acc,
        @v128.v128_load8_lane(src, start + j, @v128.i16x8_splat(0), 0),
        w,
      )
      j += 1
    }
    // `vaddvq_s16`: the lane sum modulo 2^16.
    let mut sum = 0
    sum += @v128.i16x8_extract_lane_s(acc, 0).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 1).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 2).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 3).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 4).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 5).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 6).reinterpret_as_int()
    sum += @v128.i16x8_extract_lane_s(acc, 7).reinterpret_as_int()
    dst.unsafe_set(dst_offset + x, pack_q6_u8(wrap_i16(sum)).to_byte())
  }
}

///|
/// Four consecutive weights as `i32x4`.
#inline
fn gather_weights4(w : FixedArray[Int], i : Int) -> V128 {
  let v = @v128.i32x4_splat(w.unsafe_get(i).reinterpret_as_uint())
  let v = @v128.i32x4_replace_lane(
    v,
    w.unsafe_get(i + 1).reinterpret_as_uint(),
    1,
  )
  let v = @v128.i32x4_replace_lane(
    v,
    w.unsafe_get(i + 2).reinterpret_as_uint(),
    2,
  )
  @v128.i32x4_replace_lane(v, w.unsafe_get(i + 3).reinterpret_as_uint(), 3)
}

///|
/// The `i32` (Q15) kernels for 3 and 4 channels: one `i32` lane per channel
/// (`vmlal_s16`, never overflows), then `vqshrun_n_s32::<15>` +
/// `vqmovn_u16`. With 3 channels lane 3 reads the next byte and is ignored.
fn q15_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
  channels : Int,
) -> Unit {
  let rnd = @v128.i32x4_splat((1 << (PRECISION - 1)).reinterpret_as_uint())
  let weights = fw.weights
  for x in 0..<fw.bounds_start.length() {
    let start = src_offset + fw.bounds_start.unsafe_get(x) * channels
    let size = fw.bounds_size.unsafe_get(x)
    let w_off = x * fw.aligned_size
    if !in_range(
        start,
        size.to_int64() * channels.to_int64() + 4 - channels.to_int64(),
        src.length(),
      ) {
      // (RGB: lane 3 of the last tap would read past the end.)
      for c in 0..<channels {
        let mut v = 1 << (PRECISION - 1)
        for j in 0..<size {
          v = v +
            src.unsafe_get(start + j * channels + c).to_int() *
            weights.unsafe_get(w_off + j)
        }
        dst.unsafe_set(dst_offset + x * channels + c, pack_q15_u8(v).to_byte())
      }
      continue
    }
    let mut acc = rnd
    for j in 0..<size {
      let p = @v128.i32x4_extend_low_i16x8_u(
        @v128.i16x8_extend_low_i8x16_u(
          @v128.v128_load32_zero(src, start + j * channels),
        ),
      )
      let w = @v128.i32x4_splat(
        weights.unsafe_get(w_off + j).reinterpret_as_uint(),
      )
      acc = @v128.i32x4_add(acc, @v128.i32x4_mul(p, w))
    }
    let v = @v128.i32x4_shr_s(acc, PRECISION)
    let v = @v128.i16x8_narrow_i32x4_s(v, v)
    let out = @v128.i8x16_narrow_i16x8_u(v, v)
    let d = dst_offset + x * channels
    if channels == 4 {
      @v128.v128_store32_lane(dst, d, out, 0)
    } else {
      dst.unsafe_set(
        d,
        @v128.i8x16_extract_lane_u(out, 0).reinterpret_as_int().to_byte(),
      )
      dst.unsafe_set(
        d + 1,
        @v128.i8x16_extract_lane_u(out, 1).reinterpret_as_int().to_byte(),
      )
      dst.unsafe_set(
        d + 2,
        @v128.i8x16_extract_lane_u(out, 2).reinterpret_as_int().to_byte(),
      )
    }
  }
}

///|
/// [convolve_horizontal_rgba_neon_row].
fn rgba_q15_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  guard horizontal_ranges_ok(src, src_offset, dst, dst_offset, fw, 4) else {
    convolve_horizontal_rgba_neon_row(src, src_offset, dst, dst_offset, fw)
  }
  q15_row(src, src_offset, dst, dst_offset, fw, 4)
}

///|
/// [convolve_horizontal_rgb_neon_row_one].
fn rgb_q15_row(
  src : FixedArray[Byte],
  src_offset : Int,
  dst : FixedArray[Byte],
  dst_offset : Int,
  fw : FixedWeights,
) -> Unit {
  guard horizontal_ranges_ok(src, src_offset, dst, dst_offset, fw, 3) else {
    convolve_horizontal_rgb_neon_row_one(src, src_offset, dst, dst_offset, fw)
  }
  q15_row(src, src_offset, dst, dst_offset, fw, 3)
}

///|
/// One pixel of [convolve_horizontal_rgb_neon_rdm_row_one], one channel at
/// a time (the taps are in bounds).
fn rgb_rdm_pixel(
  src : FixedArray[Byte],
  start : Int,
  size : Int,
  dst : FixedArray[Byte],
  d : Int,
  weights : FixedArray[Int],
  w_off : Int,
) -> Unit {
  for c in 0..<3 {
    let mut a = 1 << 5
    let mut b = 0
    for j in 0..<size {
      let x = expand8_to_14(src.unsafe_get(start + j * 3 + c).to_int())
      let w = weights.unsafe_get(w_off + j)
      if (j & 1) == 0 {
        a = vqrdmlah_s16(a, x, w)
      } else {
        b = vqrdmlah_s16(b, x, w)
      }
    }
    dst.unsafe_set(d + c, pack_q6_u8(wrap_i16(a + b)).to_byte())
  }
}
