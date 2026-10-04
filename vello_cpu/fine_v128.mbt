// v128 versions of the `U8Kernel` compositing functions of `fine.mbt`
// (native and wasm; `fine_scalar.mbt` selects the lane emulations on
// wasm-gc/js). vello_cpu computes these on `u8x32`/`u16x32` vectors
// (NEON); here 4 pixels (16 bytes) at a time in `u16` lanes with the same
// wrapping `u16` arithmetic: `div_255(v) = (v + 255) >> 8`, `norm_mul(a, b)
// = div_255(a * b)`. The results of `div_255` are at most 255, so the
// saturating narrowing to `u8` is the plain truncation of the emulation.

///|
/// `div_255` on `u16` lanes.
#inline
fn div_255x8(v : V128) -> V128 {
  @v128.i16x8_shr_u(@v128.i16x8_add(v, @v128.i16x8_splat(255)), 8)
}

///|
/// The masks of pixels `i..i + 4` (`alpha_buf[i..]`), each replicated over
/// its pixel's four bytes.
#inline
fn masks_4px(alpha_buf : Array[Byte], i : Int) -> V128 {
  let m = @v128.i32x4_splat(
    alpha_buf.unsafe_get(i).to_int().reinterpret_as_uint(),
  )
  let m = @v128.i32x4_replace_lane(
    m,
    alpha_buf.unsafe_get(i + 1).to_int().reinterpret_as_uint(),
    1,
  )
  let m = @v128.i32x4_replace_lane(
    m,
    alpha_buf.unsafe_get(i + 2).to_int().reinterpret_as_uint(),
    2,
  )
  let m = @v128.i32x4_replace_lane(
    m,
    alpha_buf.unsafe_get(i + 3).to_int().reinterpret_as_uint(),
    3,
  )
  @v128.i32x4_mul(m, @v128.i32x4_splat(0x01010101))
}

///|
/// `dest = div_255(bg * (255 - norm_mul(src_a, m)) + src * m)` for 4 pixels
/// (`alpha_fill`), `bg`/`src`/`src_a`/`m` as bytes.
#inline
fn composite_masked_4px(bg : V128, src : V128, src_a : V128, m : V128) -> V128 {
  @v128.i8x16_narrow_i16x8_u(
    composite_masked_u16(
      @v128.i16x8_extend_low_i8x16_u(bg),
      @v128.i16x8_extend_low_i8x16_u(src),
      @v128.i16x8_extend_low_i8x16_u(src_a),
      @v128.i16x8_extend_low_i8x16_u(m),
    ),
    composite_masked_u16(
      @v128.i16x8_extend_high_i8x16_u(bg),
      @v128.i16x8_extend_high_i8x16_u(src),
      @v128.i16x8_extend_high_i8x16_u(src_a),
      @v128.i16x8_extend_high_i8x16_u(m),
    ),
  )
}

///|
/// [composite_masked_4px] on `u16` lanes.
#inline
fn composite_masked_u16(bg : V128, src : V128, a : V128, m : V128) -> V128 {
  let inv = @v128.i16x8_sub(
    @v128.i16x8_splat(255),
    div_255x8(@v128.i16x8_mul(a, m)),
  )
  div_255x8(@v128.i16x8_add(@v128.i16x8_mul(bg, inv), @v128.i16x8_mul(src, m)))
}

///|
/// `dest = norm_mul(bg, 255 - src_a) + src` (wrapping `u8`) for 4 pixels
/// (`fill`).
#inline
fn composite_over_4px(bg : V128, src : V128, src_a : V128) -> V128 {
  let c255 = @v128.i16x8_splat(255)
  let lo = div_255x8(
    @v128.i16x8_mul(
      @v128.i16x8_extend_low_i8x16_u(bg),
      @v128.i16x8_sub(c255, @v128.i16x8_extend_low_i8x16_u(src_a)),
    ),
  )
  let hi = div_255x8(
    @v128.i16x8_mul(
      @v128.i16x8_extend_high_i8x16_u(bg),
      @v128.i16x8_sub(c255, @v128.i16x8_extend_high_i8x16_u(src_a)),
    ),
  )
  @v128.i8x16_add(@v128.i8x16_narrow_i16x8_u(lo, hi), src)
}

///|
/// The alpha byte of each of the 4 pixels, replicated over its pixel.
#inline
fn alphas_4px(src : V128) -> V128 {
  @v128.i8x16_shuffle(
    src, src, 3, 3, 3, 3, 7, 7, 7, 7, 11, 11, 11, 11, 15, 15, 15, 15,
  )
}

///|
/// Composites a solid color onto a buffer using alpha blending.
fn alpha_composite_solid(
  dest : FixedArray[Byte],
  start : Int,
  len : Int,
  src : FixedArray[Int],
  alpha_buf : Array[Byte],
  alphas : Int?,
) -> Unit {
  // Whole chunks only, like the emulation (8 pixels with masks, 16 without).
  let chunk = if alphas is Some(_) { 32 } else { 64 }
  let n = len / chunk * chunk
  guard start >= 0 &&
    start + n <= dest.length() &&
    src.length() >= 4 &&
    (match alphas {
      Some(off) => off >= 0 && off + n / 4 <= alpha_buf.length()
      None => true
    }) else {
    alpha_composite_solid_scalar(dest, start, len, src, alpha_buf, alphas)
  }
  let color = @v128.i32x4_splat(
    ((src[0] & 0xFF) |
    ((src[1] & 0xFF) << 8) |
    ((src[2] & 0xFF) << 16) |
    ((src[3] & 0xFF) << 24)).reinterpret_as_uint(),
  )
  let src_a = alphas_4px(color)
  let mut i = 0
  match alphas {
    Some(alpha_off) =>
      while i < n {
        let bg = @v128.v128_load(dest, start + i)
        let m = masks_4px(alpha_buf, alpha_off + i / 4)
        @v128.v128_store(
          dest,
          start + i,
          composite_masked_4px(bg, color, src_a, m),
        )
        i += 16
      }
    None =>
      while i < n {
        let bg = @v128.v128_load(dest, start + i)
        @v128.v128_store(dest, start + i, composite_over_4px(bg, color, src_a))
        i += 16
      }
  }
}

///|
/// Composites a source buffer onto a destination buffer using alpha
/// blending.
fn alpha_composite_buffer(
  dest : FixedArray[Byte],
  start : Int,
  len : Int,
  src : FixedArray[Byte],
  src_start : Int,
  alpha_buf : Array[Byte],
  alphas : Int?,
) -> Unit {
  let n = len / 32 * 32
  guard start >= 0 &&
    start + n <= dest.length() &&
    src_start >= 0 &&
    src_start + n <= src.length() &&
    (match alphas {
      Some(off) => off >= 0 && off + n / 4 <= alpha_buf.length()
      None => true
    }) else {
    alpha_composite_buffer_scalar(
      dest, start, len, src, src_start, alpha_buf, alphas,
    )
  }
  let mut i = 0
  match alphas {
    Some(alpha_off) =>
      while i < n {
        let bg = @v128.v128_load(dest, start + i)
        let s = @v128.v128_load(src, src_start + i)
        let m = masks_4px(alpha_buf, alpha_off + i / 4)
        @v128.v128_store(
          dest,
          start + i,
          composite_masked_4px(bg, s, alphas_4px(s), m),
        )
        i += 16
      }
    None =>
      while i < n {
        let bg = @v128.v128_load(dest, start + i)
        let s = @v128.v128_load(src, src_start + i)
        @v128.v128_store(
          dest,
          start + i,
          composite_over_4px(bg, s, alphas_4px(s)),
        )
        i += 16
      }
  }
}

///|
/// Writes the column-major scratch (`x * 16 + y * 4`) to the region's rows,
/// one column (four pixels of four rows) at a time.
fn pack_region(scratch : FixedArray[Byte], region : Region) -> Unit {
  let buf = region.buf
  let w = region.width
  guard region.height == TILE_HEIGHT &&
    w >= 0 &&
    w * TILE_HEIGHT_COMPONENTS <= scratch.length() &&
    region.offset >= 0 &&
    region.stride >= 0 &&
    region.offset + 3 * region.stride + w * 4 <= buf.length() else {
    pack_region_scalar(scratch, region)
  }
  let r0 = region.offset
  let r1 = r0 + region.stride
  let r2 = r1 + region.stride
  let r3 = r2 + region.stride
  for x in 0..<w {
    let col = @v128.v128_load(scratch, x * TILE_HEIGHT_COMPONENTS)
    @v128.v128_store32_lane(buf, r0 + x * 4, col, 0)
    @v128.v128_store32_lane(buf, r1 + x * 4, col, 1)
    @v128.v128_store32_lane(buf, r2 + x * 4, col, 2)
    @v128.v128_store32_lane(buf, r3 + x * 4, col, 3)
  }
}
