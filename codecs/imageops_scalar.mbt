// Scalar counterparts of `imageops_v128.mbt` for the targets where `@v128`
// is emulated (wasm-gc, js).

///|
/// [vertical_sample_row_scalar].
fn vertical_sample_row(
  image : FixedArray[Float],
  out : FixedArray[Float],
  row_len : Int,
  out_base : Int,
  left : Int,
  ws : Array[Float],
) -> Unit {
  vertical_sample_row_scalar(image, out, row_len, out_base, left, ws)
}

///|
/// [horizontal_sample_sums_scalar].
fn horizontal_sample_sums(
  image : FixedArray[Float],
  start : Int,
  channels : Int,
  ws : Array[Float],
  t : FixedArray[Float],
) -> Unit {
  horizontal_sample_sums_scalar(image, start, channels, ws, t)
}
