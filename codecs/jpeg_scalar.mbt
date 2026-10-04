// Scalar counterparts of `jpeg_v128.mbt` for the targets where `@v128` is
// emulated (wasm-gc, js).

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
  ycbcr_to_rgb_16_scalar(
    y, yo, cb, cbo, cr, cro, output, out_pos, num_components,
  )
}

///|
/// The main loop of [upsample_horizontal]: `output[2..2 + 2 * n]` from
/// `input[0..n + 2]`.
fn upsample_horizontal_core(input : Slice, output : Slice, n : Int) -> Unit {
  for w in 0..<n {
    let sample = 3 * input.at(w + 1) + 2
    output.set(2 + 2 * w, (sample + input.at(w)) >> 2)
    output.set(3 + 2 * w, (sample + input.at(w + 2)) >> 2)
  }
}

///|
/// A row of [upsample_vertical]: `output[start..start + n]` from
/// `input[0..n]` and the closest row `near[0..n]`.
fn upsample_vertical_core(
  input : Slice,
  near : Slice,
  output : Slice,
  start : Int,
  n : Int,
) -> Unit {
  for i in 0..<n {
    output.set(start + i, (3 * input.at(i) + 2 + near.at(i)) >> 2)
  }
}

///|
/// The integer IDCT.
fn idct_int(
  in_vector : FixedArray[Int],
  out_vector : FixedArray[Int],
  out_pos : Int,
  stride : Int,
) -> Unit {
  idct_int_scalar(in_vector, out_vector, out_pos, stride)
}
