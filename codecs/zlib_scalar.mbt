// Scalar counterparts of `zlib_v128.mbt` for the targets where `@v128` is
// emulated (wasm-gc, js).

///|
/// `u64::from_le_bytes(window[i..i + 8])` without a bounds check.
#inline
fn load_u64_le_unchecked(window : FixedArray[Byte], i : Int) -> UInt64 {
  let lo = window.unsafe_get(i).to_int() |
    (window.unsafe_get(i + 1).to_int() << 8) |
    (window.unsafe_get(i + 2).to_int() << 16) |
    (window.unsafe_get(i + 3).to_int() << 24)
  let hi = window.unsafe_get(i + 4).to_int() |
    (window.unsafe_get(i + 5).to_int() << 8) |
    (window.unsafe_get(i + 6).to_int() << 16) |
    (window.unsafe_get(i + 7).to_int() << 24)
  UInt64::extend_uint(lo.reinterpret_as_uint()) |
  (UInt64::extend_uint(hi.reinterpret_as_uint()) << 32)
}

///|
/// `u32::from_le_bytes(window[i..i + 4])` without a bounds check.
#inline
fn load_u32_le_unchecked(window : FixedArray[Byte], i : Int) -> UInt {
  // Intrinsic conversions only (core's `Byte::to_uint` is not inlined).
  (window.unsafe_get(i).to_int() |
  (window.unsafe_get(i + 1).to_int() << 8) |
  (window.unsafe_get(i + 2).to_int() << 16) |
  (window.unsafe_get(i + 3).to_int() << 24)).reinterpret_as_uint()
}

///|
/// [compare256] for in-bounds ranges (checked by [compare256]).
fn compare256_unchecked(window : FixedArray[Byte], a : Int, b : Int) -> Int {
  // Compare eight bytes at a time (like zlib-rs' `compare256_rust_u64`);
  // the result is the same as comparing byte by byte.
  for i = 0; i < 256; i = i + 8 {
    let diff = load_u64_le_unchecked(window, a + i) ^
      load_u64_le_unchecked(window, b + i)
    if diff != 0 {
      return i + diff.ctz() / 8
    }
  }
  256
}

///|
/// [adler32] of `data[off..off + len]` (the range must be in bounds).
fn adler32_fixed(
  start_checksum : UInt,
  data : FixedArray[Byte],
  off : Int,
  len : Int,
) -> UInt {
  guard in_range(off, len.to_int64(), data.length()) else {
    abort("index out of bounds")
  }
  let mut sum2 = (start_checksum >> 16) & 0xffff
  let mut adler = start_checksum & 0xffff
  let mut i = off
  let end = off + len
  while i < end {
    let n = @cmp.minimum(ADLER_NMAX, end - i)
    for j in i..<(i + n) {
      adler += data.unsafe_get(j).to_int().reinterpret_as_uint()
      sum2 += adler
    }
    adler %= ADLER_BASE
    sum2 %= ADLER_BASE
    i += n
  }
  adler | (sum2 << 16)
}
