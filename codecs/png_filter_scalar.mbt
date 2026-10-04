// Scalar `filter_row_cost` for the targets where `@v128` is emulated
// (wasm-gc, js); `png_filter_v128.mbt` is the native/wasm counterpart.

///|
/// [filter_row_cost_scalar].
fn filter_row_cost(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
  limit : UInt64,
) -> UInt64 {
  filter_row_cost_scalar(filter, bpp, previous, current, output, limit)
}
