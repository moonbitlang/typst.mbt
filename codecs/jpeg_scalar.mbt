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
/// [upsample_horizontal_core_scalar].
fn upsample_horizontal_core(input : Slice, output : Slice, n : Int) -> Unit {
  upsample_horizontal_core_scalar(input, output, n)
}

///|
/// [upsample_vertical_core_scalar].
fn upsample_vertical_core(
  input : Slice,
  near : Slice,
  output : Slice,
  start : Int,
  n : Int,
) -> Unit {
  upsample_vertical_core_scalar(input, near, output, start, n)
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
