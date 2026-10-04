// Checks the target-selected kernels (`*_v128.mbt` on native/wasm,
// `*_scalar.mbt` elsewhere) against straightforward reference loops.

///|
fn kernel_test_pixels(n : Int, seed : Int) -> FixedArray[UInt] {
  let mut x = seed.reinterpret_as_uint() * 2654435761U + 1
  FixedArray::makei(n, i => {
    x = x * 1103515245U + 12345U
    let r = x >> 8
    // Premultiplied: color channels <= alpha. Mix opaque runs (most of a
    // page), transparent pixels and partial alpha.
    let a = match i / 5 % 4 {
      0 | 1 => 0xFFU
      2 => 0U
      _ => (r >> 16) & 0xFF
    }
    let ch = (v : UInt) => if a == 0 { 0U } else { v % (a + 1) }
    ch(r & 0xFF) |
    (ch((r >> 3) & 0xFF) << 8) |
    (ch((r >> 7) & 0xFF) << 16) |
    (a << 24)
  })
}

///|
test "take_demultiplied matches per-pixel demultiply" {
  for n in [0, 1, 3, 4, 5, 7, 8, 9, 16, 33, 1000] {
    let data = kernel_test_pixels(n, n + 1)
    let out = FixedArray::make(n * 4, b'\x00')
    demultiply_into(data, out)
    for i in 0..<n {
      let c = PremultipliedColorU8(data[i]).demultiply()
      assert_eq(out[i * 4].to_int(), c.red())
      assert_eq(out[i * 4 + 1].to_int(), c.green())
      assert_eq(out[i * 4 + 2].to_int(), c.blue())
      assert_eq(out[i * 4 + 3].to_int(), c.alpha())
    }
  }
}

///|
test "bench demultiply 1191x1684 page" (it : @bench.T) {
  // A mostly opaque page with some anti-aliased pixels.
  let n = 1191 * 1684
  let data = FixedArray::make(n, 0xFFFFFFFFU)
  let noise = kernel_test_pixels(n / 97 + 1, 3)
  for i = 0; i < n; i = i + 97 {
    data[i] = noise[i / 97]
  }
  let out = FixedArray::make(n * 4, b'\x00')
  it.bench(() => {
    demultiply_into(data, out)
    it.keep(out)
  })
}

///|
test "bench demultiply 1191x1684 page (per-pixel reference)" (it : @bench.T) {
  let n = 1191 * 1684
  let data = FixedArray::make(n, 0xFFFFFFFFU)
  let noise = kernel_test_pixels(n / 97 + 1, 3)
  for i = 0; i < n; i = i + 97 {
    data[i] = noise[i / 97]
  }
  let out = FixedArray::make(n * 4, b'\x00')
  it.bench(() => {
    for i in 0..<n {
      let c = PremultipliedColorU8(data[i]).demultiply()
      out[i * 4] = c.red().to_byte()
      out[i * 4 + 1] = c.green().to_byte()
      out[i * 4 + 2] = c.blue().to_byte()
      out[i * 4 + 3] = c.alpha().to_byte()
    }
    it.keep(out)
  })
}

///|
/// The scalar `demultiply_into` (`pixmap_scalar.mbt`), as a reference on
/// every target.
fn ref_demultiply_into(data : FixedArray[UInt], out : FixedArray[Byte]) -> Unit {
  for i in 0..<data.length() {
    demultiply_pixel(data[i], out, i * 4)
  }
}

///|
test "demultiply_into matches the scalar code at every length" {
  for n in 0..<=64 {
    let data = kernel_test_pixels(n, n * 3 + 1)
    // Exact allocation end and sentinels after it.
    for extra in [0, 1, 4, 7] {
      let o1 = FixedArray::make(4 * n + extra, b'\x5a')
      let o2 = FixedArray::make(4 * n + extra, b'\x5a')
      demultiply_into(data, o1)
      ref_demultiply_into(data, o2)
      for i in 0..<o1.length() {
        assert_eq(o1[i], o2[i])
      }
      for i in (4 * n)..<o1.length() {
        assert_eq(o1[i], b'\x5a')
      }
    }
  }
}

///|
test "panic demultiply_into with a short output" {
  let data = kernel_test_pixels(16, 1)
  demultiply_into(data, FixedArray::make(63, b'\x00'))
}

///|
test "panic demultiply_into with a short output and a tail" {
  let data = kernel_test_pixels(5, 1)
  demultiply_into(data, FixedArray::make(19, b'\x00'))
}
