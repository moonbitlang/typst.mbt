// Scalar counterparts of `imageops_v128.mbt` for the targets where `@v128`
// is emulated (wasm-gc, js).

///|
/// `out[out_base + j] = sum(image[(left + i) * row_len + j] * ws[i])` for
/// `j < row_len`, summed from 0.0 in the order of `i` (a row of
/// [vertical_sample]).
fn vertical_sample_row(
  image : FixedArray[Float],
  out : FixedArray[Float],
  row_len : Int,
  out_base : Int,
  left : Int,
  ws : Array[Float],
) -> Unit {
  for j in 0..<row_len {
    let mut t : Float = 0.0
    for i, wt in ws {
      t = t + image[(left + i) * row_len + j] * wt
    }
    out[out_base + j] = t
  }
}

///|
/// `t[c] = sum(image[start + i * channels + c] * ws[i])` for `c <
/// channels`, summed from 0.0 in the order of `i` (a pixel of
/// [horizontal_sample]).
fn horizontal_sample_sums(
  image : FixedArray[Float],
  start : Int,
  channels : Int,
  ws : Array[Float],
  t : FixedArray[Float],
) -> Unit {
  t.fill(0.0)
  for i, wt in ws {
    let base = start + i * channels
    for c in 0..<channels {
      t[c] = t[c] + image[base + c] * wt
    }
  }
}
