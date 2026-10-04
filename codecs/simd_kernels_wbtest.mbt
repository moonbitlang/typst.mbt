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
/// Reference PNG filter: the whole row, byte by byte (upstream
/// `filter_internal` + `sum_buffer`).
fn ref_filter_row(
  filter : Int,
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
) -> (FixedArray[Byte], UInt64) {
  let len = current.length()
  let out = FixedArray::make(len + 1, b'\x00')
  let mut sum = 0UL
  for i in 0..<len {
    let x = current[i].to_int()
    let a = if i >= bpp { current[i - bpp].to_int() } else { 0 }
    let c = if i >= bpp { previous[i - bpp].to_int() } else { 0 }
    let b = previous[i].to_int()
    let d = match filter {
      1 => x - a
      2 => x - b
      3 => x - (a + b) / 2
      4 => x - filter_paeth(a, b, c)
      _ => x
    }
    let v = d & 0xFF
    out[i + 1] = v.to_byte()
    sum += (if v >= 128 { 256 - v } else { v }).to_uint64()
  }
  (out, sum)
}

///|
fn png_test_row(len : Int, seed : Int, kind : Int) -> FixedArray[Byte] {
  let noise = kernel_test_bytes(len, seed)
  match kind {
    // random
    0 => noise
    // smooth gradient (small differences, many Paeth ties)
    1 => FixedArray::makei(len, i => ((i / 3 + seed) & 0xff).to_byte())
    // mostly white with sparse noise, incl. 0x80
    _ =>
      FixedArray::makei(len, i => {
        if i % 37 == 5 {
          noise[i]
        } else if i % 53 == 7 {
          b'\x80'
        } else {
          b'\xff'
        }
      })
  }
}

///|
test "filter_row_cost matches the reference filter" {
  for
    len in [0, 1, 2, 3, 4, 5, 15, 16, 17, 31, 32, 33, 47, 63, 64, 65, 100, 257] {
    for bpp in [1, 2, 3, 4, 6, 8] {
      for kind in 0..<3 {
        for kind2 in 0..<3 {
          let previous = png_test_row(len, 3 + len, kind)
          let current = png_test_row(len, 7 + bpp, kind2)
          for filter in 0..<5 {
            let (ref_out, ref_sum) = ref_filter_row(
              filter, bpp, previous, current,
            )
            let out = FixedArray::make(len + 1, b'\x00')
            let sum = filter_row_cost(
              filter, bpp, previous, current, out, 0xFFFFFFFFFFFFFFFFUL,
            )
            assert_eq(sum, ref_sum)
            for i in 1..<=len {
              assert_eq(out[i], ref_out[i])
            }
            // The early exit gives up iff the full sum exceeds the limit;
            // below it the result is exact.
            for
              limit in [
                0UL,
                ref_sum / 2,
                if ref_sum > 0 {
                  ref_sum - 1
                } else {
                  0
                },
                ref_sum,
                ref_sum + 1,
              ] {
              let out2 = FixedArray::make(len + 1, b'\x00')
              let cost = filter_row_cost(
                filter, bpp, previous, current, out2, limit,
              )
              assert_eq(cost > limit, ref_sum > limit)
              if ref_sum <= limit {
                assert_eq(cost, ref_sum)
                for i in 1..<=len {
                  assert_eq(out2[i], ref_out[i])
                }
              }
            }
          }
        }
      }
    }
  }
}

///|
test "paeth16 matches filter_paeth on all byte triples" {
  // Exhaustive in a and b for a sample of c values (and all c for a few).
  let cs = [0, 1, 2, 64, 127, 128, 129, 200, 254, 255]
  let out = FixedArray::make(17, b'\x00')
  for c in cs {
    for a in 0..<256 {
      for b0 = 0; b0 < 256; b0 = b0 + 16 {
        let prev = FixedArray::makei(32, i => {
          if i < 16 {
            c.to_byte()
          } else {
            (b0 + i - 16).to_byte()
          }
        })
        let cur = FixedArray::makei(32, i => {
          if i < 16 {
            a.to_byte()
          } else {
            b'\x00'
          }
        })
        // bpp = 16: lanes 16..32 see a = cur[i - 16], b = prev[i],
        // c = prev[i - 16].
        let out = FixedArray::make(33, b'\x00')
        filter_row_cost(4, 16, prev, cur, out, 0xFFFFFFFFFFFFFFFFUL) |> ignore
        for l in 0..<16 {
          let b = b0 + l
          let expected = (0 - filter_paeth(a, b, c)) & 0xFF
          assert_eq(out[16 + l + 1].to_int(), expected)
        }
      }
    }
  }
  ignore(out)
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

///|
test "bench adaptive_filter 64 rows of 4764 bytes" (it : @bench.T) {
  let rows = Array::makei(64, r => png_test_row(4764, r, r % 3))
  let out = FixedArray::make(4765, b'\x00')
  it.bench(() => {
    let mut acc = 0
    for r in 1..<64 {
      acc += adaptive_filter(4, rows[r - 1], rows[r], out)
    }
    it.keep(acc)
  })
}
