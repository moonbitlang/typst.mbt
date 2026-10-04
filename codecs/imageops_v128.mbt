// v128 kernels of the `image` crate's resampling (`imageops_sample.mbt`;
// native and wasm, `imageops_scalar.mbt` is the wasm-gc/js counterpart).
// Upstream's loops are scalar `f32` code; the lanes compute exactly the same
// separately rounded products and sums in the same order.

///|
/// Four consecutive `Float`s of `a` starting at `i` (in bounds) as `f32x4`.
#inline
fn gather_f32x4(a : FixedArray[Float], i : Int) -> V128 {
  let v = @v128.f32x4_splat(a.unsafe_get(i))
  let v = @v128.f32x4_replace_lane(v, a.unsafe_get(i + 1), 1)
  let v = @v128.f32x4_replace_lane(v, a.unsafe_get(i + 2), 2)
  @v128.f32x4_replace_lane(v, a.unsafe_get(i + 3), 3)
}

///|
/// Stores the four lanes of `v` at `a[i..i + 4]` (in bounds).
#inline
fn scatter_f32x4(a : FixedArray[Float], i : Int, v : V128) -> Unit {
  a.unsafe_set(i, @v128.f32x4_extract_lane(v, 0))
  a.unsafe_set(i + 1, @v128.f32x4_extract_lane(v, 1))
  a.unsafe_set(i + 2, @v128.f32x4_extract_lane(v, 2))
  a.unsafe_set(i + 3, @v128.f32x4_extract_lane(v, 3))
}

///|
/// `out[out_base + j] = sum(image[(left + i) * row_len + j] * ws[i])` for
/// `j < row_len`, summed from 0.0 in the order of `i` (a row of
/// [vertical_sample]), four samples at a time.
fn vertical_sample_row(
  image : FixedArray[Float],
  out : FixedArray[Float],
  row_len : Int,
  out_base : Int,
  left : Int,
  ws : Array[Float],
) -> Unit {
  let n = ws.length()
  let mut j = 0
  if n > 0 &&
    row_len > 0 &&
    left >= 0 &&
    (left + n) * row_len <= image.length() &&
    out_base >= 0 &&
    out_base + row_len <= out.length() {
    let zero = @v128.f32x4_splat(0.0)
    // 16 samples (four independent sums) per pass over the weights.
    while j + 16 <= row_len {
      let mut a0 = zero
      let mut a1 = zero
      let mut a2 = zero
      let mut a3 = zero
      for i in 0..<n {
        let base = (left + i) * row_len + j
        let wt = @v128.f32x4_splat(ws.unsafe_get(i))
        a0 = @v128.f32x4_add(a0, @v128.f32x4_mul(gather_f32x4(image, base), wt))
        a1 = @v128.f32x4_add(
          a1,
          @v128.f32x4_mul(gather_f32x4(image, base + 4), wt),
        )
        a2 = @v128.f32x4_add(
          a2,
          @v128.f32x4_mul(gather_f32x4(image, base + 8), wt),
        )
        a3 = @v128.f32x4_add(
          a3,
          @v128.f32x4_mul(gather_f32x4(image, base + 12), wt),
        )
      }
      scatter_f32x4(out, out_base + j, a0)
      scatter_f32x4(out, out_base + j + 4, a1)
      scatter_f32x4(out, out_base + j + 8, a2)
      scatter_f32x4(out, out_base + j + 12, a3)
      j += 16
    }
    while j + 4 <= row_len {
      let mut acc = zero
      for i in 0..<n {
        let px = gather_f32x4(image, (left + i) * row_len + j)
        acc = @v128.f32x4_add(
          acc,
          @v128.f32x4_mul(px, @v128.f32x4_splat(ws.unsafe_get(i))),
        )
      }
      scatter_f32x4(out, out_base + j, acc)
      j += 4
    }
  }
  while j < row_len {
    let mut t : Float = 0.0
    for i, wt in ws {
      t = t + image[(left + i) * row_len + j] * wt
    }
    out[out_base + j] = t
    j += 1
  }
}

///|
/// `t[c] = sum(image[start + i * channels + c] * ws[i])` for `c <
/// channels`, summed from 0.0 in the order of `i` (a pixel of
/// [horizontal_sample]): one f32x4 lane per channel for 3 or 4 channels
/// (with 3, lane 3 sums the next pixel's first sample and is ignored).
fn horizontal_sample_sums(
  image : FixedArray[Float],
  start : Int,
  channels : Int,
  ws : Array[Float],
  t : FixedArray[Float],
) -> Unit {
  let n = ws.length()
  if (channels == 3 || channels == 4) &&
    start >= 0 &&
    t.length() >= channels &&
    start + (n - 1) * channels + 4 <= image.length() {
    let mut acc = @v128.f32x4_splat(0.0)
    for i in 0..<n {
      acc = @v128.f32x4_add(
        acc,
        @v128.f32x4_mul(
          gather_f32x4(image, start + i * channels),
          @v128.f32x4_splat(ws.unsafe_get(i)),
        ),
      )
    }
    t[0] = @v128.f32x4_extract_lane(acc, 0)
    t[1] = @v128.f32x4_extract_lane(acc, 1)
    t[2] = @v128.f32x4_extract_lane(acc, 2)
    if channels == 4 {
      t[3] = @v128.f32x4_extract_lane(acc, 3)
    }
    return
  }
  t.fill(0.0)
  for i, wt in ws {
    let base = start + i * channels
    for c in 0..<channels {
      t[c] = t[c] + image[base + c] * wt
    }
  }
}
