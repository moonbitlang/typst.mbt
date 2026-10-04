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
fn kernel_test_ints(n : Int, seed : Int, lo : Int, hi : Int) -> FixedArray[Int] {
  let bytes = kernel_test_bytes(4 * n, seed)
  // 32 random bits per value, reduced into `lo..=hi` in `Int64`.
  let range = hi.to_int64() - lo.to_int64() + 1L
  FixedArray::makei(n, i => {
    let r = bytes[4 * i].to_int64() |
      (bytes[4 * i + 1].to_int64() << 8) |
      (bytes[4 * i + 2].to_int64() << 16) |
      (bytes[4 * i + 3].to_int64() << 24)
    (lo.to_int64() + r % range).to_int()
  })
}

///|
test "ycbcr_to_rgb_16 matches the scalar conversion" {
  // Samples in 0..=255 (decoder output) and beyond (wrapping `as i16`,
  // saturation).
  for range in [(0, 255), (-70000, 70000), (-200, 600)] {
    let (lo, hi) = range
    for seed in 0..<20 {
      let y = kernel_test_ints(40, seed, lo, hi)
      let cb = kernel_test_ints(40, seed + 100, lo, hi)
      let cr = kernel_test_ints(40, seed + 200, lo, hi)
      for nc in [3, 4] {
        for off in [0, 3, 24] {
          let out1 = FixedArray::make(16 * nc + 5, b'\x00')
          let out2 = FixedArray::make(16 * nc + 5, b'\x00')
          ycbcr_to_rgb_16(y, off, cb, off / 3, cr, off / 2, out1, 5, nc)
          ycbcr_to_rgb_16_scalar(y, off, cb, off / 3, cr, off / 2, out2, 5, nc)
          for i in 0..<out1.length() {
            assert_eq(out1[i], out2[i])
          }
        }
      }
    }
  }
}

///|
test "upsamplers match the reference filters" {
  for len in [3, 4, 5, 6, 7, 8, 9, 15, 16, 17, 33, 64, 100] {
    for seed in 0..<4 {
      let src = kernel_test_ints(len + 7, seed, 0, 255)
      let near = kernel_test_ints(len + 7, seed + 9, 0, 255)
      let far = kernel_test_ints(len + 7, seed + 19, 0, 255)
      let off = seed % 3
      let input : Slice = { arr: src, off, len, }
      let in_near : Slice = { arr: near, off: off + 1, len, }
      let in_far : Slice = { arr: far, off: 2, len, }
      // horizontal
      let out_arr = FixedArray::make(2 * len + 9, -1)
      let output : Slice = { arr: out_arr, off: 3, len: 2 * len, }
      upsample_horizontal(input, output)
      let inp = (i : Int) => src[off + i]
      assert_eq(out_arr[3], inp(0))
      assert_eq(out_arr[4], (inp(0) * 3 + inp(1) + 2) >> 2)
      for w in 0..<(len - 2) {
        let sample = 3 * inp(w + 1) + 2
        assert_eq(out_arr[3 + 2 + 2 * w], (sample + inp(w)) >> 2)
        assert_eq(out_arr[3 + 3 + 2 * w], (sample + inp(w + 2)) >> 2)
      }
      assert_eq(out_arr[2], -1)
      assert_eq(out_arr[3 + 2 * len], -1)
      // vertical
      let vout = FixedArray::make(2 * len + 4, -1)
      upsample_vertical(input, in_near, in_far, {
        arr: vout,
        off: 1,
        len: 2 * len,
      })
      for i in 0..<len {
        assert_eq(vout[1 + i], (3 * inp(i) + 2 + near[off + 1 + i]) >> 2)
        assert_eq(vout[1 + len + i], (3 * inp(i) + 2 + far[2 + i]) >> 2)
      }
      assert_eq(vout[0], -1)
      assert_eq(vout[1 + 2 * len], -1)
    }
  }
}

///|
test "bench upsample_horizontal 1024 samples x16" (it : @bench.T) {
  let src = kernel_test_ints(1024, 1, 0, 255)
  let out = FixedArray::make(2048, 0)
  it.bench(() => {
    for _ in 0..<16 {
      upsample_horizontal({ arr: src, off: 0, len: 1024, }, {
        arr: out,
        off: 0,
        len: 2048,
      }) catch {
        _ => ()
      }
    }
    it.keep(out)
  })
}

///|
test "bench upsample_vertical 1024 samples x16" (it : @bench.T) {
  let src = kernel_test_ints(1024, 1, 0, 255)
  let near = kernel_test_ints(1024, 2, 0, 255)
  let out = FixedArray::make(2048, 0)
  it.bench(() => {
    for _ in 0..<16 {
      upsample_vertical(
        { arr: src, off: 0, len: 1024, },
        { arr: near, off: 0, len: 1024, },
        { arr: near, off: 0, len: 1024, },
        { arr: out, off: 0, len: 2048, },
      ) catch {
        _ => ()
      }
    }
    it.keep(out)
  })
}

///|
fn kernel_test_floats(n : Int, seed : Int, scale : Float) -> FixedArray[Float] {
  let ints = kernel_test_ints(n, seed, -100000, 100000)
  FixedArray::makei(n, i => Float::from_int(ints[i]) / 100000.0 * scale)
}

///|
test "vertical_sample_row matches the scalar sums" {
  for row_len in [1, 3, 4, 5, 8, 12, 13, 16, 17, 31, 36, 50] {
    for n in [1, 2, 3, 6, 7] {
      let image = kernel_test_floats((n + 3) * row_len, row_len + n, 255.0)
      let ws = Array::from_fixed_array(kernel_test_floats(n, n, 1.5))
      for left in 0..<3 {
        let out = FixedArray::make(row_len + 2, (-1.0 : Float))
        vertical_sample_row(image, out, row_len, 1, left, ws)
        for j in 0..<row_len {
          let mut t : Float = 0.0
          for i in 0..<n {
            t = t + image[(left + i) * row_len + j] * ws[i]
          }
          assert_eq(out[1 + j].reinterpret_as_uint(), t.reinterpret_as_uint())
        }
        assert_eq(out[0], -1.0)
        assert_eq(out[row_len + 1], -1.0)
      }
    }
  }
}

///|
test "horizontal_sample_sums matches the scalar sums" {
  for channels in 1..<=4 {
    for n in [1, 2, 3, 5, 8] {
      let image = kernel_test_floats(
        (n + 3) * channels + 1,
        n + channels,
        255.0,
      )
      let ws = Array::from_fixed_array(kernel_test_floats(n, n + 7, 1.5))
      for start in [0, 1, channels] {
        // Ending exactly at the image end (the scalar fallback for 3
        // channels) and with spare samples.
        let len = start + n * channels + start % 2
        let img = FixedArray::makei(len, i => image[i])
        let t = FixedArray::make(4, (-1.0 : Float))
        horizontal_sample_sums(img, start, channels, ws, t)
        for c in 0..<channels {
          let mut e : Float = 0.0
          for i in 0..<n {
            e = e + img[start + i * channels + c] * ws[i]
          }
          assert_eq(t[c].reinterpret_as_uint(), e.reinterpret_as_uint())
        }
      }
    }
  }
}

///|
test "bench horizontal_sample 1200x800 rgb -> 500 cols" (it : @bench.T) {
  let w = 1200
  let h = 800
  let image = kernel_test_floats(w * h * 3, 1, 255.0)
  let filt : Filter = { kernel: catmullrom_kernel, support: 2.0, }
  it.bench(() => {
    it.keep(
      horizontal_sample(
        image,
        w.reinterpret_as_uint(),
        h.reinterpret_as_uint(),
        3,
        500,
        filt,
        Rgb8,
      ),
    )
  })
}

///|
test "bench vertical_sample 1200x800 rgba -> 600 rows" (it : @bench.T) {
  let w = 1200
  let h = 800
  let image = kernel_test_floats(w * h * 4, 1, 255.0)
  let filt : Filter = { kernel: catmullrom_kernel, support: 2.0, }
  it.bench(() => {
    it.keep(
      vertical_sample(
        image,
        w.reinterpret_as_uint(),
        h.reinterpret_as_uint(),
        4,
        600,
        filt,
      ),
    )
  })
}

///|
test "idct_int matches the scalar IDCT" {
  for seed in 0..<200 {
    let (lo, hi) = match seed % 4 {
      0 => (-64, 64)
      1 => (-1024, 1024)
      2 => (-40000, 40000)
      _ => (-2147483647, 2147483647)
    }
    let coeffs = kernel_test_ints(64, seed, lo, hi)
    if seed % 5 == 0 {
      // DC only / sparse blocks
      for i in 1..<64 {
        if i % (seed % 7 + 2) != 0 {
          coeffs[i] = 0
        }
      }
    }
    if seed % 11 == 0 {
      coeffs.fill(0)
      coeffs[0] = seed * 37 - 4000
    }
    for stride in [8, 13] {
      // Some rows out of range (skipped by `store8`).
      for len in [7 * stride + 8, 5 * stride + 3] {
        let out1 = FixedArray::make(len, -7)
        let out2 = FixedArray::make(len, -7)
        idct_int(coeffs, out1, 0, stride)
        idct_int_scalar(coeffs, out2, 0, stride)
        for i in 0..<len {
          assert_eq(out1[i], out2[i])
        }
      }
    }
  }
}

///|
test "bench idct_int x1000" (it : @bench.T) {
  let blocks = Array::makei(16, b => kernel_test_ints(64, b, -300, 300))
  let out = FixedArray::make(64, 0)
  it.bench(() => {
    for i in 0..<1000 {
      idct_int(blocks[i % 16], out, 0, 8)
    }
    it.keep(out)
  })
}

///|
test "bench ycbcr_to_rgb_16 x1000" (it : @bench.T) {
  let y = kernel_test_ints(16016, 1, 0, 255)
  let cb = kernel_test_ints(16016, 2, 0, 255)
  let cr = kernel_test_ints(16016, 3, 0, 255)
  let out = FixedArray::make(16016 * 3, b'\x00')
  it.bench(() => {
    for c in 0..<1000 {
      ycbcr_to_rgb_16(y, c * 16, cb, c * 16, cr, c * 16, out, c * 48, 3)
    }
    it.keep(out)
  })
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

///|
/// A 1191x400 RGBA page-like image: white with short text-like runs.
fn bench_page() -> Bytes {
  let w = 1191 * 4
  let h = 400
  let noise = kernel_test_bytes(w * h, 17)
  Bytes::makei(w * h, i => {
    let x = i % w
    let y = i / w
    if y % 24 < 14 && x % 700 < 500 && noise[i].to_int() < 90 {
      noise[i / 4 * 4]
    } else {
      b'\xff'
    }
  })
}

///|
test "bench encode_png_balanced 1191x400 page" (it : @bench.T) {
  let page = bench_page()
  it.bench(() => it.keep(encode_png_balanced(page[:], 1191, 400, Rgba)))
}

///|
test "panic ycbcr_to_rgb_16 with an out-of-range offset" {
  let y = FixedArray::make(16, 0)
  let out = FixedArray::make(48, b'\x00')
  ycbcr_to_rgb_16(y, 0, y, 0, y, 0, out, 2147483647, 3)
}
