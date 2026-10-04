// v128 kernels of the zune-jpeg port (native and wasm; `jpeg_scalar.mbt` is
// the wasm-gc/js counterpart). Upstream uses NEON versions of these on
// aarch64 that compute the same values (see the notes in
// `jpeg_color_convert.mbt`); they are vectorized here from the scalar code,
// with wrapping `i32` lanes like MoonBit's `Int`.
//
// The sample buffers are `FixedArray[Int]` (upstream `i16`); lanes are
// gathered with `replace_lane`, which the C compiler merges into vector
// loads on native.

///|
/// Four consecutive `Int`s of `a` starting at `i` (in bounds) as `i32x4`.
#inline
fn gather_i32x4(a : FixedArray[Int], i : Int) -> V128 {
  let v = @v128.i32x4_splat(a.unsafe_get(i).reinterpret_as_uint())
  let v = @v128.i32x4_replace_lane(
    v,
    a.unsafe_get(i + 1).reinterpret_as_uint(),
    1,
  )
  let v = @v128.i32x4_replace_lane(
    v,
    a.unsafe_get(i + 2).reinterpret_as_uint(),
    2,
  )
  @v128.i32x4_replace_lane(v, a.unsafe_get(i + 3).reinterpret_as_uint(), 3)
}

///|
/// Sign-extends the low 16 bits of each lane (`as i16`).
#inline
fn i16_lanes(v : V128) -> V128 {
  @v128.i32x4_shr_s(@v128.i32x4_shl(v, 16), 16)
}

///|
/// Convert 16 YCbCr samples (`y[yo..yo + 16]` etc.) to RGB (`num_components
/// == 3`) or RGBA (`4`) at `output[out_pos..]`.
fn ycbcr_to_rgb_16(
  y : FixedArray[Int],
  yo : Int,
  cb : FixedArray[Int],
  cbo : Int,
  cr : FixedArray[Int],
  cro : Int,
  output : FixedArray[Byte],
  out_pos : Int,
  num_components : Int,
) -> Unit {
  guard (num_components == 3 || num_components == 4) &&
    yo >= 0 &&
    yo + 16 <= y.length() &&
    cbo >= 0 &&
    cbo + 16 <= cb.length() &&
    cro >= 0 &&
    cro + 16 <= cr.length() &&
    out_pos >= 0 &&
    out_pos + 16 * num_components <= output.length() else {
    // (panics like the scalar code on out-of-bounds accesses)
    ycbcr_to_rgb_16_scalar(
      y, yo, cb, cbo, cr, cro, output, out_pos, num_components,
    )
  }
  let c128 = @v128.i32x4_splat(128)
  let y0 = gather_i32x4(y, yo)
  let y1 = gather_i32x4(y, yo + 4)
  let y2 = gather_i32x4(y, yo + 8)
  let y3 = gather_i32x4(y, yo + 12)
  let cb0 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cb, cbo), c128))
  let cb1 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cb, cbo + 4), c128))
  let cb2 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cb, cbo + 8), c128))
  let cb3 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cb, cbo + 12), c128))
  let cr0 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cr, cro), c128))
  let cr1 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cr, cro + 4), c128))
  let cr2 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cr, cro + 8), c128))
  let cr3 = i16_lanes(@v128.i32x4_sub(gather_i32x4(cr, cro + 12), c128))
  // i32 -> i16 -> u8 with saturation is `clamp(x, 0, 255)`.
  let r = @v128.i8x16_narrow_i16x8_u(
    @v128.i16x8_narrow_i32x4_s(ycc_red(y0, cr0), ycc_red(y1, cr1)),
    @v128.i16x8_narrow_i32x4_s(ycc_red(y2, cr2), ycc_red(y3, cr3)),
  )
  let g = @v128.i8x16_narrow_i16x8_u(
    @v128.i16x8_narrow_i32x4_s(ycc_green(y0, cb0, cr0), ycc_green(y1, cb1, cr1)),
    @v128.i16x8_narrow_i32x4_s(ycc_green(y2, cb2, cr2), ycc_green(y3, cb3, cr3)),
  )
  let b = @v128.i8x16_narrow_i16x8_u(
    @v128.i16x8_narrow_i32x4_s(ycc_blue(y0, cb0), ycc_blue(y1, cb1)),
    @v128.i16x8_narrow_i32x4_s(ycc_blue(y2, cb2), ycc_blue(y3, cb3)),
  )
  if num_components == 4 {
    let a = @v128.i8x16_splat(b'\xFF')
    let rg_lo = @v128.i8x16_shuffle(
      r, g, 0, 16, 1, 17, 2, 18, 3, 19, 4, 20, 5, 21, 6, 22, 7, 23,
    )
    let rg_hi = @v128.i8x16_shuffle(
      r, g, 8, 24, 9, 25, 10, 26, 11, 27, 12, 28, 13, 29, 14, 30, 15, 31,
    )
    let ba_lo = @v128.i8x16_shuffle(
      b, a, 0, 16, 1, 17, 2, 18, 3, 19, 4, 20, 5, 21, 6, 22, 7, 23,
    )
    let ba_hi = @v128.i8x16_shuffle(
      b, a, 8, 24, 9, 25, 10, 26, 11, 27, 12, 28, 13, 29, 14, 30, 15, 31,
    )
    @v128.v128_store(
      output,
      out_pos,
      @v128.i8x16_shuffle(
        rg_lo, ba_lo, 0, 1, 16, 17, 2, 3, 18, 19, 4, 5, 20, 21, 6, 7, 22, 23,
      ),
    )
    @v128.v128_store(
      output,
      out_pos + 16,
      @v128.i8x16_shuffle(
        rg_lo, ba_lo, 8, 9, 24, 25, 10, 11, 26, 27, 12, 13, 28, 29, 14, 15, 30, 31,
      ),
    )
    @v128.v128_store(
      output,
      out_pos + 32,
      @v128.i8x16_shuffle(
        rg_hi, ba_hi, 0, 1, 16, 17, 2, 3, 18, 19, 4, 5, 20, 21, 6, 7, 22, 23,
      ),
    )
    @v128.v128_store(
      output,
      out_pos + 48,
      @v128.i8x16_shuffle(
        rg_hi, ba_hi, 8, 9, 24, 25, 10, 11, 26, 27, 12, 13, 28, 29, 14, 15, 30, 31,
      ),
    )
  } else {
    // Byte j of the 48 output bytes is channel j % 3 of pixel j / 3: first
    // r/g, then b.
    let t0 = @v128.i8x16_shuffle(
      r, g, 0, 16, 0, 1, 17, 0, 2, 18, 0, 3, 19, 0, 4, 20, 0, 5,
    )
    let t1 = @v128.i8x16_shuffle(
      r, g, 21, 0, 6, 22, 0, 7, 23, 0, 8, 24, 0, 9, 25, 0, 10, 26,
    )
    let t2 = @v128.i8x16_shuffle(
      r, g, 0, 11, 27, 0, 12, 28, 0, 13, 29, 0, 14, 30, 0, 15, 31, 0,
    )
    @v128.v128_store(
      output,
      out_pos,
      @v128.i8x16_shuffle(
        t0, b, 0, 1, 16, 3, 4, 17, 6, 7, 18, 9, 10, 19, 12, 13, 20, 15,
      ),
    )
    @v128.v128_store(
      output,
      out_pos + 16,
      @v128.i8x16_shuffle(
        t1, b, 0, 21, 2, 3, 22, 5, 6, 23, 8, 9, 24, 11, 12, 25, 14, 15,
      ),
    )
    @v128.v128_store(
      output,
      out_pos + 32,
      @v128.i8x16_shuffle(
        t2, b, 26, 1, 2, 27, 4, 5, 28, 7, 8, 29, 10, 11, 30, 13, 14, 31,
      ),
    )
  }
}

///|
/// `y * Y_CF + YUV_RND`.
#inline
fn ycc_y0(y : V128) -> V128 {
  @v128.i32x4_add(
    @v128.i32x4_mul(y, @v128.i32x4_splat(Y_CF.reinterpret_as_uint())),
    @v128.i32x4_splat(YUV_RND.reinterpret_as_uint()),
  )
}

///|
#inline
fn ycc_red(y : V128, cr : V128) -> V128 {
  @v128.i32x4_shr_s(
    @v128.i32x4_add(
      ycc_y0(y),
      @v128.i32x4_mul(cr, @v128.i32x4_splat(CR_CF.reinterpret_as_uint())),
    ),
    YUV_PREC,
  )
}

///|
#inline
fn ycc_green(y : V128, cb : V128, cr : V128) -> V128 {
  @v128.i32x4_shr_s(
    @v128.i32x4_add(
      @v128.i32x4_add(
        ycc_y0(y),
        @v128.i32x4_mul(
          cr,
          @v128.i32x4_splat(C_G_CR_COEF_1.reinterpret_as_uint()),
        ),
      ),
      @v128.i32x4_mul(
        cb,
        @v128.i32x4_splat(C_G_CB_COEF_2.reinterpret_as_uint()),
      ),
    ),
    YUV_PREC,
  )
}

///|
#inline
fn ycc_blue(y : V128, cb : V128) -> V128 {
  @v128.i32x4_shr_s(
    @v128.i32x4_add(
      ycc_y0(y),
      @v128.i32x4_mul(cb, @v128.i32x4_splat(CB_CF.reinterpret_as_uint())),
    ),
    YUV_PREC,
  )
}

///|
/// Stores the four lanes of `v` at `a[i..i + 4]` (in bounds).
#inline
fn scatter_i32x4(a : FixedArray[Int], i : Int, v : V128) -> Unit {
  a.unsafe_set(i, @v128.i32x4_extract_lane(v, 0).reinterpret_as_int())
  a.unsafe_set(i + 1, @v128.i32x4_extract_lane(v, 1).reinterpret_as_int())
  a.unsafe_set(i + 2, @v128.i32x4_extract_lane(v, 2).reinterpret_as_int())
  a.unsafe_set(i + 3, @v128.i32x4_extract_lane(v, 3).reinterpret_as_int())
}

///|
/// Whether `s[start..start + len]` is within its array.
#inline
fn slice_range_ok(s : Slice, start : Int, len : Int) -> Bool {
  start >= 0 && len >= 0 && s.off >= 0 && s.off + start + len <= s.arr.length()
}

///|
/// The main loop of [upsample_horizontal]: `output[2..2 + 2 * n]` from
/// `input[0..n + 2]`, four input samples at a time.
fn upsample_horizontal_core(input : Slice, output : Slice, n : Int) -> Unit {
  let mut w = 0
  if n > 0 &&
    slice_range_ok(input, 0, n + 2) &&
    slice_range_ok(output, 2, 2 * n) {
    let two = @v128.i32x4_splat(2)
    let inp = input.arr
    let out = output.arr
    while w + 4 <= n {
      let i = input.off + w
      let a = gather_i32x4(inp, i)
      let b = gather_i32x4(inp, i + 1)
      let c = gather_i32x4(inp, i + 2)
      // 3 * b + 2
      let sample = @v128.i32x4_add(
        @v128.i32x4_add(@v128.i32x4_shl(b, 1), b),
        two,
      )
      let even = @v128.i32x4_shr_s(@v128.i32x4_add(sample, a), 2)
      let odd = @v128.i32x4_shr_s(@v128.i32x4_add(sample, c), 2)
      let o = output.off + 2 + 2 * w
      scatter_i32x4(
        out,
        o,
        @v128.i8x16_shuffle(
          even, odd, 0, 1, 2, 3, 16, 17, 18, 19, 4, 5, 6, 7, 20, 21, 22, 23,
        ),
      )
      scatter_i32x4(
        out,
        o + 4,
        @v128.i8x16_shuffle(
          even, odd, 8, 9, 10, 11, 24, 25, 26, 27, 12, 13, 14, 15, 28, 29, 30, 31,
        ),
      )
      w += 4
    }
  }
  while w < n {
    let sample = 3 * input.at(w + 1) + 2
    output.set(2 + 2 * w, (sample + input.at(w)) >> 2)
    output.set(3 + 2 * w, (sample + input.at(w + 2)) >> 2)
    w += 1
  }
}

///|
/// A row of [upsample_vertical]: `output[start..start + n]` from
/// `input[0..n]` and the closest row `near[0..n]`, four at a time.
fn upsample_vertical_core(
  input : Slice,
  near : Slice,
  output : Slice,
  start : Int,
  n : Int,
) -> Unit {
  let mut i = 0
  if n > 0 &&
    slice_range_ok(input, 0, n) &&
    slice_range_ok(near, 0, n) &&
    slice_range_ok(output, start, n) {
    let two = @v128.i32x4_splat(2)
    while i + 4 <= n {
      let x = gather_i32x4(input.arr, input.off + i)
      let y = gather_i32x4(near.arr, near.off + i)
      // (3 * x + 2 + y) >> 2
      let v = @v128.i32x4_add(@v128.i32x4_add(@v128.i32x4_shl(x, 1), x), two)
      scatter_i32x4(
        output.arr,
        output.off + start + i,
        @v128.i32x4_shr_s(@v128.i32x4_add(v, y), 2),
      )
      i += 4
    }
  }
  while i < n {
    output.set(start + i, (3 * input.at(i) + 2 + near.at(i)) >> 2)
    i += 1
  }
}

///|
/// One 1-D pass of `idct_int` on eight `i32x4` rows `m[base..base + 8]` (in
/// place; each lane is an independent column): the same wrapping sums as
/// the scalar passes, with the given rounding `bias` and final shift.
fn idct_pass(
  m : FixedArray[V128],
  base : Int,
  bias : V128,
  shift : Int,
) -> Unit {
  let p2 = m[base + 2]
  let p3 = m[base + 6]
  let p1 = @v128.i32x4_mul(@v128.i32x4_add(p2, p3), ks(2217))
  let t2 = @v128.i32x4_add(p1, @v128.i32x4_mul(p3, ks(-7567)))
  let t3 = @v128.i32x4_add(p1, @v128.i32x4_mul(p2, ks(3135)))
  let p2 = m[base]
  let p3 = m[base + 4]
  let t0 = @v128.i32x4_shl(@v128.i32x4_add(p2, p3), 12)
  let t1 = @v128.i32x4_shl(@v128.i32x4_sub(p2, p3), 12)
  let x0 = @v128.i32x4_add(@v128.i32x4_add(t0, t3), bias)
  let x3 = @v128.i32x4_add(@v128.i32x4_sub(t0, t3), bias)
  let x1 = @v128.i32x4_add(@v128.i32x4_add(t1, t2), bias)
  let x2 = @v128.i32x4_add(@v128.i32x4_sub(t1, t2), bias)
  let t0 = m[base + 7]
  let t1 = m[base + 5]
  let t2 = m[base + 3]
  let t3 = m[base + 1]
  let p3 = @v128.i32x4_add(t0, t2)
  let p4 = @v128.i32x4_add(t1, t3)
  let p1 = @v128.i32x4_add(t0, t3)
  let p2 = @v128.i32x4_add(t1, t2)
  let p5 = @v128.i32x4_mul(@v128.i32x4_add(p3, p4), ks(4816))
  let t0 = @v128.i32x4_mul(t0, ks(1223))
  let t1 = @v128.i32x4_mul(t1, ks(8410))
  let t2 = @v128.i32x4_mul(t2, ks(12586))
  let t3 = @v128.i32x4_mul(t3, ks(6149))
  let p1 = @v128.i32x4_add(p5, @v128.i32x4_mul(p1, ks(-3685)))
  let p2 = @v128.i32x4_add(p5, @v128.i32x4_mul(p2, ks(-10497)))
  let p3 = @v128.i32x4_mul(p3, ks(-8034))
  let p4 = @v128.i32x4_mul(p4, ks(-1597))
  let t3 = @v128.i32x4_add(t3, @v128.i32x4_add(p1, p4))
  let t2 = @v128.i32x4_add(t2, @v128.i32x4_add(p2, p3))
  let t1 = @v128.i32x4_add(t1, @v128.i32x4_add(p2, p4))
  let t0 = @v128.i32x4_add(t0, @v128.i32x4_add(p1, p3))
  m[base] = @v128.i32x4_shr_s(@v128.i32x4_add(x0, t3), shift)
  m[base + 1] = @v128.i32x4_shr_s(@v128.i32x4_add(x1, t2), shift)
  m[base + 2] = @v128.i32x4_shr_s(@v128.i32x4_add(x2, t1), shift)
  m[base + 3] = @v128.i32x4_shr_s(@v128.i32x4_add(x3, t0), shift)
  m[base + 4] = @v128.i32x4_shr_s(@v128.i32x4_sub(x3, t0), shift)
  m[base + 5] = @v128.i32x4_shr_s(@v128.i32x4_sub(x2, t1), shift)
  m[base + 6] = @v128.i32x4_shr_s(@v128.i32x4_sub(x1, t2), shift)
  m[base + 7] = @v128.i32x4_shr_s(@v128.i32x4_sub(x0, t3), shift)
}

///|
/// Transposes the 4x4 `i32` matrix `m[i..i + 4]` (rows) in place.
fn transpose4(m : FixedArray[V128], i : Int) -> Unit {
  let a = m[i]
  let b = m[i + 1]
  let c = m[i + 2]
  let d = m[i + 3]
  // a0 b0 a1 b1 / a2 b2 a3 b3 / c0 d0 c1 d1 / c2 d2 c3 d3
  let ab_lo = @v128.i8x16_shuffle(
    a, b, 0, 1, 2, 3, 16, 17, 18, 19, 4, 5, 6, 7, 20, 21, 22, 23,
  )
  let ab_hi = @v128.i8x16_shuffle(
    a, b, 8, 9, 10, 11, 24, 25, 26, 27, 12, 13, 14, 15, 28, 29, 30, 31,
  )
  let cd_lo = @v128.i8x16_shuffle(
    c, d, 0, 1, 2, 3, 16, 17, 18, 19, 4, 5, 6, 7, 20, 21, 22, 23,
  )
  let cd_hi = @v128.i8x16_shuffle(
    c, d, 8, 9, 10, 11, 24, 25, 26, 27, 12, 13, 14, 15, 28, 29, 30, 31,
  )
  m[i] = @v128.i8x16_shuffle(
    ab_lo, cd_lo, 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23,
  )
  m[i + 1] = @v128.i8x16_shuffle(
    ab_lo, cd_lo, 8, 9, 10, 11, 12, 13, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31,
  )
  m[i + 2] = @v128.i8x16_shuffle(
    ab_hi, cd_hi, 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 18, 19, 20, 21, 22, 23,
  )
  m[i + 3] = @v128.i8x16_shuffle(
    ab_hi, cd_hi, 8, 9, 10, 11, 12, 13, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31,
  )
}

///|
/// The integer IDCT (upstream `idct_neon` on aarch64): both passes on four
/// columns (then four rows) at a time, with 4x4 transposes in between.
fn idct_int(
  in_vector : FixedArray[Int],
  out_vector : FixedArray[Int],
  out_pos : Int,
  stride : Int,
) -> Unit {
  guard in_vector.length() >= 64 else {
    idct_int_scalar(in_vector, out_vector, out_pos, stride)
  }
  let mut all_zero = true
  for i in 1..<64 {
    if in_vector.unsafe_get(i) != 0 {
      all_zero = false
      break
    }
  }
  if all_zero {
    idct_int_scalar(in_vector, out_vector, out_pos, stride)
    return
  }
  // m[0..8]: rows 0..7 of columns 0..3; m[8..16]: of columns 4..7.
  let zero = @v128.i32x4_splat(0)
  let m = FixedArray::make(16, zero)
  for r in 0..<8 {
    m[r] = gather_i32x4(in_vector, 8 * r)
    m[8 + r] = gather_i32x4(in_vector, 8 * r + 4)
  }
  // vertical pass
  let b512 = @v128.i32x4_splat(512)
  idct_pass(m, 0, b512, 10)
  idct_pass(m, 8, b512, 10)
  // Transpose: m[0..8] becomes columns 0..7 of rows 0..3, m[8..16] those
  // of rows 4..7.
  transpose4(m, 0)
  transpose4(m, 4)
  transpose4(m, 8)
  transpose4(m, 12)
  for j in 0..<4 {
    let t = m[4 + j]
    m[4 + j] = m[8 + j]
    m[8 + j] = t
  }
  // horizontal pass
  let bias = @v128.i32x4_splat(SCALE_BITS.reinterpret_as_uint())
  idct_pass(m, 0, bias, 17)
  idct_pass(m, 8, bias, 17)
  // Back to rows: m[g * 8 + j] / m[g * 8 + 4 + j] are columns 0..3 / 4..7
  // of row 4 * g + j.
  let lo = zero
  let hi = @v128.i32x4_splat(255)
  for i in 0..<16 {
    m[i] = @v128.i32x4_min_s(@v128.i32x4_max_s(m[i], lo), hi)
  }
  transpose4(m, 0)
  transpose4(m, 4)
  transpose4(m, 8)
  transpose4(m, 12)
  let mut pos = out_pos
  for row in 0..<8 {
    let g = row / 4 * 8
    let j = row % 4
    // `store8`: rows that do not fit are skipped.
    if pos >= 0 && pos + 8 <= out_vector.length() {
      scatter_i32x4(out_vector, pos, m[g + j])
      scatter_i32x4(out_vector, pos + 4, m[g + 4 + j])
    }
    pos += stride
  }
}

///|
/// `i32x4.splat(c)`.
#inline
fn ks(c : Int) -> V128 {
  @v128.i32x4_splat(c.reinterpret_as_uint())
}
