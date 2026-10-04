// Scalar counterparts of `pixmap_v128.mbt` for the targets where `@v128` is
// emulated (wasm-gc, js).

///|
/// Writes the demultiplied RGBA bytes of `data` to `out` (`4 * data.length()`
/// bytes).
fn demultiply_into(data : FixedArray[UInt], out : FixedArray[Byte]) -> Unit {
  let len = data.length()
  guard out.length() >= len * 4 else { abort("index out of bounds") }
  for i in 0..<len {
    demultiply_pixel(data.unsafe_get(i), out, i * 4)
  }
}
