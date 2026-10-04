// v128 kernels of `pixmap.mbt` (native and wasm; `pixmap_scalar.mbt` is the
// wasm-gc/js counterpart).

///|
/// Writes the demultiplied RGBA bytes of `data` to `out` (`4 * data.length()`
/// bytes). Four pixels at a time: when all four are opaque their packed
/// little-endian words already are the output bytes; otherwise each pixel
/// goes through [PremultipliedColorU8::demultiply].
fn demultiply_into(data : FixedArray[UInt], out : FixedArray[Byte]) -> Unit {
  let len = data.length()
  guard out.length() >= len * 4 else { abort("index out of bounds") }
  let alpha = @v128.i32x4_splat(0xFF000000U)
  let mut i = 0
  while i + 4 <= len {
    let v = @v128.i32x4_splat(data.unsafe_get(i))
    let v = @v128.i32x4_replace_lane(v, data.unsafe_get(i + 1), 1)
    let v = @v128.i32x4_replace_lane(v, data.unsafe_get(i + 2), 2)
    let v = @v128.i32x4_replace_lane(v, data.unsafe_get(i + 3), 3)
    if @v128.i32x4_all_true(@v128.i32x4_eq(@v128.v128_and_(v, alpha), alpha)) {
      @v128.v128_store(out, i * 4, v)
    } else {
      for j in i..<(i + 4) {
        demultiply_pixel(data.unsafe_get(j), out, j * 4)
      }
    }
    i += 4
  }
  while i < len {
    demultiply_pixel(data.unsafe_get(i), out, i * 4)
    i += 1
  }
}
