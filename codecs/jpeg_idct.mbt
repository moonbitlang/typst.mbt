// Port of `zune-jpeg` (v0.5.15) `src/idct.rs` and `src/idct/scalar.rs`: the
// integer IDCT.
//
// On aarch64 upstream uses `idct_neon` for the full IDCT; it computes
// exactly the same values as the scalar `idct_int` (same two passes with
// wrapping 32-bit arithmetic, saturating narrowing followed by a clamp to
// 0..=255, and the same DC-only shortcut), except that it leaves the input
// coefficients untouched, which is not observable by the callers. The 4x4
// and 1x1 IDCTs are the scalar ones on every platform.
//
// Output is written to `out[out_pos..]` with the given row `stride`.

///|
const SCALE_BITS : Int = 512 + 65536 + (128 << 17)

///|
fn idct_int_1x1(
  in_vector : FixedArray[Int],
  out_vector : FixedArray[Int],
  out_pos : Int,
  stride : Int,
) -> Unit raise DecodeErrors {
  let coeff = clamp255((in_vector[0] + 4 + 1024) >> 3)
  // upstream panics when the output is too short
  if out_pos + 7 * stride + 8 > out_vector.length() {
    raise Panic("range end index out of range for slice")
  }
  let mut pos = out_pos
  for i in 0..<8 {
    if i > 0 {
      pos += stride
    }
    for j in 0..<8 {
      out_vector[pos + j] = coeff
    }
  }
}

///|
/// Clamp values between 0 and 255.
fn clamp255(a : Int) -> Int {
  if a < 0 {
    0
  } else if a > 255 {
    255
  } else {
    a
  }
}

///|
/// Store 8 values at `out[pos..pos + 8]` if they fit (upstream writes to a
/// temporary buffer otherwise, "to prevent some bad images from crashing").
fn store8(
  out : FixedArray[Int],
  pos : Int,
  v0 : Int,
  v1 : Int,
  v2 : Int,
  v3 : Int,
  v4 : Int,
  v5 : Int,
  v6 : Int,
  v7 : Int,
) -> Unit {
  if pos >= 0 && pos + 8 <= out.length() {
    out[pos] = v0
    out[pos + 1] = v1
    out[pos + 2] = v2
    out[pos + 3] = v3
    out[pos + 4] = v4
    out[pos + 5] = v5
    out[pos + 6] = v6
    out[pos + 7] = v7
  }
}

///|
fn idct_int_scalar(
  in_vector : FixedArray[Int],
  out_vector : FixedArray[Int],
  out_pos : Int,
  stride : Int,
) -> Unit {
  let mut all_zero = true
  for i in 1..<64 {
    if in_vector[i] != 0 {
      all_zero = false
      break
    }
  }
  if all_zero {
    // (the NEON shortcut stores through `get_mut(..).unwrap_or(tmp)`)
    let coeff = clamp255((in_vector[0] + 4 + 1024) >> 3)
    let mut pos = out_pos
    for _ in 0..<8 {
      store8(
        out_vector, pos, coeff, coeff, coeff, coeff, coeff, coeff, coeff, coeff,
      )
      pos += stride
    }
    return
  }
  let v = FixedArray::make(64, 0)
  // vertical pass
  for ptr in 0..<8 {
    let p2 = in_vector[ptr + 16]
    let p3 = in_vector[ptr + 48]
    let p1 = (p2 + p3) * 2217
    let t2 = p1 + p3 * -7567
    let t3 = p1 + p2 * 3135
    let p2 = in_vector[ptr]
    let p3 = in_vector[32 + ptr]
    let t0 = (p2 + p3) << 12
    let t1 = (p2 - p3) << 12
    let x0 = t0 + t3 + 512
    let x3 = t0 - t3 + 512
    let x1 = t1 + t2 + 512
    let x2 = t1 - t2 + 512
    let mut t0 = in_vector[ptr + 56]
    let mut t1 = in_vector[ptr + 40]
    let mut t2 = in_vector[ptr + 24]
    let mut t3 = in_vector[ptr + 8]
    let p3 = t0 + t2
    let p4 = t1 + t3
    let p1 = t0 + t3
    let p2 = t1 + t2
    let p5 = (p3 + p4) * 4816
    t0 = t0 * 1223
    t1 = t1 * 8410
    t2 = t2 * 12586
    t3 = t3 * 6149
    let p1 = p5 + p1 * -3685
    let p2 = p5 + p2 * -10497
    let p3 = p3 * -8034
    let p4 = p4 * -1597
    t3 = t3 + (p1 + p4)
    t2 = t2 + (p2 + p3)
    t1 = t1 + (p2 + p4)
    t0 = t0 + (p1 + p3)
    v[ptr] = (x0 + t3) >> 10
    v[ptr + 8] = (x1 + t2) >> 10
    v[ptr + 16] = (x2 + t1) >> 10
    v[ptr + 24] = (x3 + t0) >> 10
    v[ptr + 32] = (x3 - t0) >> 10
    v[ptr + 40] = (x2 - t1) >> 10
    v[ptr + 48] = (x1 - t2) >> 10
    v[ptr + 56] = (x0 - t3) >> 10
  }
  // horizontal pass
  let mut pos = out_pos
  let mut i = 0
  while i < 64 {
    let p2 = v[i + 2]
    let p3 = v[i + 6]
    let p1 = (p2 + p3) * 2217
    let t2 = p1 + p3 * -7567
    let t3 = p1 + p2 * 3135
    let p2 = v[i]
    let p3 = v[i + 4]
    let t0 = (p2 + p3) << 12
    let t1 = (p2 - p3) << 12
    let x0 = t0 + t3 + SCALE_BITS
    let x3 = t0 - t3 + SCALE_BITS
    let x1 = t1 + t2 + SCALE_BITS
    let x2 = t1 - t2 + SCALE_BITS
    let mut t0 = v[i + 7]
    let mut t1 = v[i + 5]
    let mut t2 = v[i + 3]
    let mut t3 = v[i + 1]
    let p3 = t0 + t2
    let p4 = t1 + t3
    let p1 = t0 + t3
    let p2 = t1 + t2
    // f2f(1.175875602)
    let p5 = (p3 + p4) * 4816
    t0 = t0 * 1223
    t1 = t1 * 8410
    t2 = t2 * 12586
    t3 = t3 * 6149
    let p1 = p5 + p1 * -3685
    let p2 = p5 + p2 * -10497
    let p3 = p3 * -8034
    let p4 = p4 * -1597
    t3 = t3 + (p1 + p4)
    t2 = t2 + (p2 + p3)
    t1 = t1 + (p2 + p4)
    t0 = t0 + (p1 + p3)
    store8(
      out_vector,
      pos,
      clamp255((x0 + t3) >> 17),
      clamp255((x1 + t2) >> 17),
      clamp255((x2 + t1) >> 17),
      clamp255((x3 + t0) >> 17),
      clamp255((x3 - t0) >> 17),
      clamp255((x2 - t1) >> 17),
      clamp255((x1 - t2) >> 17),
      clamp255((x0 - t3) >> 17),
    )
    i += 8
    pos += stride
  }
}

///|
/// IDCT assuming only the upper 4x4 is filled.
fn idct4x4(
  in_vector : FixedArray[Int],
  out_vector : FixedArray[Int],
  out_pos : Int,
  stride : Int,
) -> Unit {
  let mut pos = out_pos
  // vertical pass
  for ptr in 0..<4 {
    let i0 = (in_vector[ptr] << 12) + 512
    let i2 = in_vector[ptr + 16]
    let p1 = i2 * 2217
    let p3 = i2 * 5352
    let x0 = i0 + p3
    let x1 = i0 + p1
    let x2 = i0 - p1
    let x3 = i0 - p3
    // odd part
    let i4 = in_vector[ptr + 24]
    let i3 = in_vector[ptr + 8]
    let p5 = (i4 + i3) * 4816
    let p1 = p5 + i3 * -3685
    let p2 = p5 + i4 * -10497
    let t3 = p5 + i3 * 867
    let t2 = p5 + i4 * -5945
    let t1 = p2 + i3 * -1597
    let t0 = p1 + i4 * -8034
    in_vector[ptr] = (x0 + t3) >> 10
    in_vector[ptr + 8] = (x1 + t2) >> 10
    in_vector[ptr + 16] = (x2 + t1) >> 10
    in_vector[ptr + 24] = (x3 + t0) >> 10
    in_vector[ptr + 32] = (x3 - t0) >> 10
    in_vector[ptr + 40] = (x2 - t1) >> 10
    in_vector[ptr + 48] = (x1 - t2) >> 10
    in_vector[ptr + 56] = (x0 - t3) >> 10
  }
  // horizontal pass
  for r in 0..<8 {
    let i = 8 * r
    let i2 = in_vector[i + 2]
    let i0 = in_vector[i]
    let t0 = (i0 << 12) + SCALE_BITS
    let t2 = i2 * 2217
    let t3 = i2 * 5352
    let x0 = t0 + t3
    let x3 = t0 - t3
    let x1 = t0 + t2
    let x2 = t0 - t2
    // odd part
    let i3 = in_vector[i + 3]
    let i1 = in_vector[i + 1]
    let p5 = (i3 + i1) * 4816
    let p1 = p5 + i1 * -3685
    let p2 = p5 + i3 * -10497
    let t3 = p5 + i1 * 867
    let t2 = p5 + i3 * -5945
    let t1 = p2 + i1 * -1597
    let t0 = p1 + i3 * -8034
    store8(
      out_vector,
      pos,
      clamp255((x0 + t3) >> 17),
      clamp255((x1 + t2) >> 17),
      clamp255((x2 + t1) >> 17),
      clamp255((x3 + t0) >> 17),
      clamp255((x3 - t0) >> 17),
      clamp255((x2 - t1) >> 17),
      clamp255((x1 - t2) >> 17),
      clamp255((x0 - t3) >> 17),
    )
    pos += stride
  }
  for r in 4..<8 {
    for c in 0..<4 {
      in_vector[r * 8 + c] = 0
    }
  }
}
