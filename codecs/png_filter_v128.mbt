// v128 `filter_row_cost` (native and wasm; `png_filter_scalar.mbt` is the
// wasm-gc/js counterpart). The filters are computed 16 bytes at a time with
// wrapping `u8` lanes, exactly like the scalar code; the bytes before `bpp`
// and the tail of a row are filtered one at a time.
//
// The early exit is checked every 64 bytes instead of after every byte. The
// row sums only grow, so a filter gives up if and only if the scalar code
// gives up; only the returned (over-limit) partial sum and the partially
// written output differ, and neither is used for a filter that gave up (the
// winner is recomputed, see [adaptive_filter]).

///|
/// [filter_row] that also computes [sum_buffer] of the output, giving up
/// (with a partially filtered row) once the cost exceeds `limit`.
fn filter_row_cost(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
  limit : UInt64,
) -> UInt64 {
  let len = current.length()
  guard previous.length() >= len && output.length() >= len + 1 && bpp >= 0 else {
    abort("index out of bounds")
  }
  let first = if bpp < len { bpp } else { len }
  // Sums of a row are below `2^63` (`255 * len`); the limit is clamped.
  let limit = if limit > 0x7FFFFFFFFFFFFFFFUL {
    0x7FFFFFFFFFFFFFFFL
  } else {
    limit.reinterpret_as_int64()
  }
  let mut sum = 0L
  for i in 0..<first {
    sum += filter_cost_byte(filter, bpp, previous, current, output, i)
  }
  // In-bounds 16-byte blocks: `i - bpp >= 0` and `i + 16 <= len`, and
  // `output[i + 1..i + 17]` is in bounds since `output.length() > len`.
  let mut i = first
  let filter = if filter >= 1 && filter <= 4 { filter } else { 0 }
  let zero = @v128.i32x4_splat(0)
  let mut acc = zero
  let mut blocks = 0
  while i + 16 <= len {
    let x = @v128.v128_load(current, i)
    let v = match filter {
      1 => @v128.i8x16_sub(x, @v128.v128_load(current, i - bpp))
      2 => @v128.i8x16_sub(x, @v128.v128_load(previous, i))
      3 => {
        let a = @v128.v128_load(current, i - bpp)
        let b = @v128.v128_load(previous, i)
        // floor((a + b) / 2) = avgr(a, b) - ((a ^ b) & 1)
        let avg = @v128.i8x16_sub(
          @v128.i8x16_avgr_u(a, b),
          @v128.v128_and_(@v128.v128_xor(a, b), @v128.i8x16_splat(1)),
        )
        @v128.i8x16_sub(x, avg)
      }
      4 =>
        @v128.i8x16_sub(
          x,
          paeth16(
            @v128.v128_load(current, i - bpp),
            @v128.v128_load(previous, i),
            @v128.v128_load(previous, i - bpp),
          ),
        )
      _ => x
    }
    @v128.v128_store(output, i + 1, v)
    // |v as i8| as u8 (0x80 counts 128), summed pairwise into u32 lanes.
    let cost = @v128.i16x8_extadd_pairwise_i8x16_u(@v128.i8x16_abs(v))
    acc = @v128.i32x4_add(acc, @v128.i32x4_extadd_pairwise_i16x8_u(cost))
    i += 16
    blocks += 1
    if (blocks & 3) == 0 {
      sum += hsum_i32x4_to_int64(acc)
      acc = zero
      if sum > limit {
        return sum.reinterpret_as_uint64()
      }
    }
  }
  sum += hsum_i32x4_to_int64(acc)
  while i < len {
    sum += filter_cost_byte(filter, bpp, previous, current, output, i)
    i += 1
  }
  sum.reinterpret_as_uint64()
}

///|
/// The Paeth predictor of 16 bytes (upstream `filter_paeth_fpnge`).
#inline
fn paeth16(a : V128, b : V128, c : V128) -> V128 {
  let pa = @v128.i8x16_sub(@v128.i8x16_max_u(b, c), @v128.i8x16_min_u(c, b))
  let pb = @v128.i8x16_sub(@v128.i8x16_max_u(a, c), @v128.i8x16_min_u(c, a))
  // (a < c) == (c < b)
  let same = @v128.v128_not(
    @v128.v128_xor(@v128.i8x16_lt_u(a, c), @v128.i8x16_lt_u(c, b)),
  )
  let pc = @v128.v128_bitselect(
    @v128.i8x16_sub(@v128.i8x16_max_u(pa, pb), @v128.i8x16_min_u(pa, pb)),
    @v128.i8x16_splat(b'\xff'),
    same,
  )
  let use_a = @v128.v128_and_(
    @v128.i8x16_le_u(pa, pb),
    @v128.i8x16_le_u(pa, pc),
  )
  let use_b = @v128.i8x16_le_u(pb, pc)
  @v128.v128_bitselect(a, @v128.v128_bitselect(b, c, use_b), use_a)
}

///|
#inline
fn hsum_i32x4_to_int64(v : V128) -> Int64 {
  UInt64::extend_uint(@v128.i32x4_extract_lane(v, 0)).reinterpret_as_int64() +
  UInt64::extend_uint(@v128.i32x4_extract_lane(v, 1)).reinterpret_as_int64() +
  UInt64::extend_uint(@v128.i32x4_extract_lane(v, 2)).reinterpret_as_int64() +
  UInt64::extend_uint(@v128.i32x4_extract_lane(v, 3)).reinterpret_as_int64()
}

///|
/// Filters byte `i` into `output[i + 1]` and returns its cost (filter 0 is
/// None; `a`/`c` are 0 before `bpp`).
fn filter_cost_byte(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
  i : Int,
) -> Int64 {
  let x = current[i].to_int()
  let a = if i >= bpp { current[i - bpp].to_int() } else { 0 }
  let c = if i >= bpp { previous[i - bpp].to_int() } else { 0 }
  let b = previous[i].to_int()
  let d = match filter {
    1 => x - a
    2 => x - b
    3 => x - (a + b) / 2
    4 => x - filter_paeth(a, b, c)
    _ => x
  }
  let v = d & 0xFF
  output[i + 1] = v.to_byte()
  (if v >= 128 { 256 - v } else { v }).to_int64()
}
