// Checks the target-selected kernels (`*_v128.mbt` on native/wasm,
// `*_scalar.mbt` elsewhere) against straightforward reference loops.

///|
fn kernel_test_bytes(n : Int, seed : Int) -> FixedArray[Byte] {
  let mut x = seed.reinterpret_as_uint() * 2654435761U + 1
  FixedArray::makei(n, _ => {
    x = x * 1103515245U + 12345U
    (x >> 16).reinterpret_as_int().to_byte()
  })
}

///|
test "compare256 matches a byte loop" {
  let window = FixedArray::make(1024, b'\x00')
  let src = kernel_test_bytes(1024, 7)
  for a_off in [0, 1, 7, 13] {
    for b_off in [300, 301, 509, 700] {
      for mismatch in 0..<=256 {
        window.fill(b'\x00')
        for i in 0..<256 {
          window[a_off + i] = src[i]
          window[b_off + i] = src[i]
        }
        if mismatch < 256 {
          window[b_off + mismatch] = (window[b_off + mismatch].to_int() ^ 0x5a).to_byte()
        }
        let mut expected = 256
        for i in 0..<256 {
          if window[a_off + i] != window[b_off + i] {
            expected = i
            break
          }
        }
        assert_eq(compare256(window, a_off, b_off), expected)
        assert_eq(compare256(window, b_off, a_off), expected)
      }
    }
  }
  // Ranges near the end of the window take the checked fallback.
  let w = kernel_test_bytes(300, 3)
  assert_eq(compare256(w, 10, 10), 256)
  assert_eq(compare256(w, 44, 44), 256)
}

///|
test "read_u64_le/read_u32_le" {
  let w = kernel_test_bytes(40, 11)
  for i in 0..<=32 {
    let mut v = 0UL
    for k in 0..<8 {
      v = v | (w[i + k].to_uint64() << (8 * k))
    }
    assert_eq(read_u64_le(w, i), v)
    assert_eq(read_u32_le(w, i), (v & 0xffffffffUL).to_uint())
  }
}

///|
test "adler32_fixed matches adler32" {
  let data = kernel_test_bytes(3 * ADLER_NMAX + 77, 5)
  let ones = FixedArray::make(3 * ADLER_NMAX + 77, b'\xff')
  for arr in [data, ones] {
    for off in [0, 1, 15, 16, 17] {
      for
        len in [
          0,
          1,
          15,
          16,
          17,
          31,
          32,
          33,
          255,
          4096,
          ADLER_NMAX - 1,
          ADLER_NMAX,
          ADLER_NMAX + 1,
          2 * ADLER_NMAX + 5,
          3 * ADLER_NMAX + 60,
        ] {
        let bytes = Bytes::makei(len, i => arr[off + i])
        for start in [1U, 0xfff0ffefU, 0x12345678U % 65521U] {
          assert_eq(
            adler32_fixed(start, arr, off, len),
            adler32(start, bytes[:]),
          )
        }
      }
    }
  }
}

///|
fn bench_window() -> FixedArray[Byte] {
  // Mostly-equal data like a rendered page: long runs with sparse changes.
  let w = FixedArray::make(65536, b'\xff')
  let noise = kernel_test_bytes(65536, 9)
  for i = 0; i < 65536; i = i + 997 {
    w[i] = noise[i]
  }
  w
}

///|
test "bench compare256" (it : @bench.T) {
  let w = bench_window()
  it.bench(() => {
    let mut acc = 0
    for i = 0; i < 60000; i = i + 64 {
      acc += compare256(w, i, i + 1)
    }
    it.keep(acc)
  })
}

///|
test "bench read_u64_le" (it : @bench.T) {
  let w = bench_window()
  it.bench(() => {
    let mut acc = 0UL
    for i in 0..<65000 {
      acc = acc ^ read_u64_le(w, i)
    }
    it.keep(acc)
  })
}

///|
test "bench adler32 64 KiB" (it : @bench.T) {
  let w = bench_window()
  it.bench(() => it.keep(adler32_fixed(1, w, 0, w.length())))
}
