// The `U8Kernel` compositing functions on the targets where `@v128` is
// emulated (wasm-gc, js): the lane emulations of `fine.mbt`
// (`fine_v128.mbt` is the native/wasm counterpart).

///|
fn alpha_composite_solid(
  dest : FixedArray[Byte],
  start : Int32,
  len : Int32,
  src : FixedArray[Int32],
  alpha_buf : Array[Byte],
  alphas : Int32?,
) -> Unit {
  alpha_composite_solid_scalar(dest, start, len, src, alpha_buf, alphas)
}

///|
fn alpha_composite_buffer(
  dest : FixedArray[Byte],
  start : Int32,
  len : Int32,
  src : FixedArray[Byte],
  src_start : Int32,
  alpha_buf : Array[Byte],
  alphas : Int32?,
) -> Unit {
  alpha_composite_buffer_scalar(
    dest, start, len, src, src_start, alpha_buf, alphas,
  )
}

///|
fn pack_region(scratch : FixedArray[Byte], region : Region) -> Unit {
  pack_region_scalar(scratch, region)
}
