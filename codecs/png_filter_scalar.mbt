// Scalar `filter_row_cost` for the targets where `@v128` is emulated
// (wasm-gc, js); `png_filter_v128.mbt` is the native/wasm counterpart.

///|
/// Applies a row filter, writing the filtered row into `output[1..]`
/// (upstream `filter_internal`; filter codes: 1 = Sub, 2 = Up, 3 = Avg, 4 =
/// Paeth), and computes [sum_buffer] of the output, giving up
/// (with a partially filtered row) once the cost exceeds `limit`.
/// Specialized loops without bounds checks (performance; same results).
fn filter_row_cost(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
  output : FixedArray[Byte],
  limit : UInt64,
) -> UInt64 {
  let len = current.length()
  guard previous.length() >= len && output.length() >= len + 1 && bpp >= 0 else {
    abort("index out of bounds")
  }
  let first = if bpp < len { bpp } else { len }
  // Sums of a row are below `2^63` (`255 * len`); the limit is clamped.
  let limit = if limit > 0x7FFFFFFFFFFFFFFFUL {
    0x7FFFFFFFFFFFFFFFL
  } else {
    limit.reinterpret_as_int64()
  }
  let mut sum = 0L
  match filter {
    1 => {
      for i in 0..<first {
        let v = current.unsafe_get(i).to_int()
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
      for i in first..<len {
        let v = (
            current.unsafe_get(i).to_int() -
            current.unsafe_get(i - bpp).to_int()
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    }
    2 =>
      for i in 0..<len {
        let v = (
            current.unsafe_get(i).to_int() - previous.unsafe_get(i).to_int()
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    3 => {
      for i in 0..<first {
        let v = (
            current.unsafe_get(i).to_int() - previous.unsafe_get(i).to_int() / 2
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
      for i in first..<len {
        let a = current.unsafe_get(i - bpp).to_int()
        let b = previous.unsafe_get(i).to_int()
        let v = (current.unsafe_get(i).to_int() - (a + b) / 2) & 0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    }
    4 => {
      for i in 0..<first {
        let v = (
            current.unsafe_get(i).to_int() -
            filter_paeth(0, previous.unsafe_get(i).to_int(), 0)
          ) &
          0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
      for i in first..<len {
        let pred = filter_paeth(
          current.unsafe_get(i - bpp).to_int(),
          previous.unsafe_get(i).to_int(),
          previous.unsafe_get(i - bpp).to_int(),
        )
        let v = (current.unsafe_get(i).to_int() - pred) & 0xFF
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
        if sum > limit {
          return sum.reinterpret_as_uint64()
        }
      }
    }
    _ =>
      for i in 0..<len {
        let v = current.unsafe_get(i).to_int()
        output.unsafe_set(i + 1, v.to_byte())
        sum += (if v >= 128 { 256 - v } else { v }).to_int64()
      }
  }
  sum.reinterpret_as_uint64()
}
