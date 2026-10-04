// Boundary tests of the target-selected kernels (`*_v128.mbt` on
// native/wasm, the scalar files on wasm-gc/js) against their scalar twins
// (compiled on every target): every small length, offsets, exact
// allocation ends, sentinels around the outputs, aliased buffers, and
// undersized buffers (which must panic, not touch memory; the native test
// driver skips `panic` tests, so `simd_guards_wbtest.mbt` checks that the
// v128 range predicates reject those parameters).

///|
const SENTINEL : Int = 0x5A

///|
fn assert_bytes_eq(a : FixedArray[Byte], b : FixedArray[Byte]) -> Unit raise {
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    if a[i] != b[i] {
      fail("byte \{i} differs: \{a[i]} vs \{b[i]}")
    }
  }
}

///|
fn assert_ints_eq(a : FixedArray[Int], b : FixedArray[Int]) -> Unit raise {
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    if a[i] != b[i] {
      fail("int \{i} differs: \{a[i]} vs \{b[i]}")
    }
  }
}

///|
fn assert_floats_eq(a : FixedArray[Float], b : FixedArray[Float]) -> Unit raise {
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    if a[i].reinterpret_as_uint() != b[i].reinterpret_as_uint() {
      fail("float \{i} differs: \{a[i]} vs \{b[i]}")
    }
  }
}

// -- PNG filters --

///|
test "filter_row_cost matches its scalar twin at every length" {
  for len in 0..<=64 {
    for bpp in [1, 2, 3, 4, 6, 8, 16] {
      for kind in 0..<3 {
        let previous = png_test_row(len, 11 + len, kind)
        let current = png_test_row(len, 5 + bpp, (kind + 1) % 3)
        for filter in 0..<6 {
          // Exact allocation end (`len + 1`) and sentinels after it.
          for extra in [0, 3] {
            let out1 = FixedArray::make(len + 1 + extra, SENTINEL.to_byte())
            let out2 = FixedArray::make(len + 1 + extra, SENTINEL.to_byte())
            let c1 = filter_row_cost(
              filter, bpp, previous, current, out1, 0xFFFFFFFFFFFFFFFFUL,
            )
            let c2 = filter_row_cost_scalar(
              filter, bpp, previous, current, out2, 0xFFFFFFFFFFFFFFFFUL,
            )
            assert_eq(c1, c2)
            assert_bytes_eq(out1, out2)
            assert_eq(out1[0], SENTINEL.to_byte())
            // Limits: the same decision, exact below the limit.
            for limit in [0UL, c2 / 3, c2] {
              let o1 = FixedArray::make(len + 1, b'\x00')
              let o2 = FixedArray::make(len + 1, b'\x00')
              let l1 = filter_row_cost(
                filter, bpp, previous, current, o1, limit,
              )
              let l2 = filter_row_cost_scalar(
                filter, bpp, previous, current, o2, limit,
              )
              assert_eq(l1 > limit, l2 > limit)
              if l2 <= limit {
                assert_eq(l1, l2)
                assert_bytes_eq(o1, o2)
              }
            }
          }
        }
      }
    }
  }
}

///|
test "filter_row_cost with the output aliasing the previous row" {
  // (An output aliasing `current` is always too short: `output.length() >
  // current.length()` fails, see the panic test below.)
  for len in [0, 1, 5, 16, 17, 40, 64, 100] {
    for bpp in [1, 3, 4] {
      for filter in 0..<5 {
        let cur = png_test_row(len, len + bpp, 0)
        let prev = png_test_row(len + 1 + bpp, len + 3, 1)
        let p1 = prev.copy()
        let p2 = prev.copy()
        let d1 = filter_row_cost(filter, bpp, p1, cur, p1, 0xFFFFFFFFFFFFFFFFUL)
        let d2 = filter_row_cost_scalar(
          filter, bpp, p2, cur, p2, 0xFFFFFFFFFFFFFFFFUL,
        )
        assert_eq(d1, d2)
        assert_bytes_eq(p1, p2)
      }
    }
  }
}

///|
test "panic filter_row_cost with the output aliasing the current row" {
  let row = png_test_row(20, 1, 0)
  filter_row_cost(1, 1, row.copy(), row, row, 0xFFFFFFFFFFFFFFFFUL) |> ignore
}

///|
/// Upstream's adaptive filter (`png::filter::adaptive_filter`): every
/// filter in full, the least `sum_buffer` cost (ties to the later one),
/// stopping at a zero cost.
fn ref_adaptive_filter(
  bpp : Int,
  previous : FixedArray[Byte],
  current : FixedArray[Byte],
) -> (Int, FixedArray[Byte]) {
  let mut min_cost = 0xFFFFFFFFFFFFFFFFUL
  let mut choice = 0
  let mut best = FixedArray::make(current.length() + 1, b'\x00')
  for filter in [2, 1, 3, 4] {
    let (out, cost) = ref_filter_row(filter, bpp, previous, current)
    if cost <= min_cost {
      min_cost = cost
      choice = filter
      best = out
      if cost == 0 {
        break
      }
    }
  }
  (choice, best)
}

///|
test "adaptive_filter chooses upstream's filter and bytes" {
  // The early exit of the v128 filters checks the limit less often than
  // the scalar code; the choice and the written row must not depend on it.
  for len in [0, 1, 2, 7, 16, 63, 64, 65, 130, 1000] {
    for bpp in [1, 2, 3, 4, 8] {
      for kind in 0..<3 {
        for kind2 in 0..<3 {
          let previous = png_test_row(len, len * 7 + kind, kind)
          let current = png_test_row(len, len * 3 + bpp + kind2, kind2)
          let (choice, expected) = ref_adaptive_filter(bpp, previous, current)
          let out = FixedArray::make(len + 1, SENTINEL.to_byte())
          let scratch = FixedArray::make(len + 1, b'\x00')
          assert_eq(
            adaptive_filter(bpp, previous, current, out, scratch),
            choice,
          )
          assert_eq(out[0], SENTINEL.to_byte())
          for i in 1..<=len {
            assert_eq(out[i], expected[i])
          }
        }
      }
    }
  }
}

///|
test "panic filter_row_cost with an output of the row's length" {
  let row = png_test_row(20, 1, 0)
  filter_row_cost(1, 1, row, row.copy(), FixedArray::make(20, b'\x00'), 0)
  |> ignore
}

///|
test "panic filter_row_cost with a short previous row" {
  let row = png_test_row(20, 1, 0)
  filter_row_cost(
    2,
    1,
    FixedArray::make(19, b'\x00'),
    row,
    FixedArray::make(21, b'\x00'),
    0,
  )
  |> ignore
}

///|
test "panic filter_row_cost with a negative bpp" {
  let row = png_test_row(20, 1, 0)
  filter_row_cost(1, -1, row, row.copy(), FixedArray::make(21, b'\x00'), 0)
  |> ignore
}

// -- zlib --

///|
test "adler32_fixed at every offset and length" {
  let data = kernel_test_bytes(64 + 16, 31)
  for off in 0..<16 {
    for len in 0..<=64 {
      let expected = adler32(1, Bytes::from_array(data[off:off + len])[:])
      assert_eq(adler32_fixed(1, data, off, len), expected)
    }
  }
  // Ending exactly at the array's end.
  for len in 0..<=64 {
    let arr = kernel_test_bytes(len, len)
    assert_eq(
      adler32_fixed(7, arr, 0, len),
      adler32(7, Bytes::from_array(arr[:])[:]),
    )
  }
}

///|
test "panic adler32_fixed past the end" {
  let arr = kernel_test_bytes(32, 1)
  adler32_fixed(1, arr, 17, 16) |> ignore
}

///|
test "panic adler32_fixed with a negative offset" {
  let arr = kernel_test_bytes(32, 1)
  adler32_fixed(1, arr, -1, 16) |> ignore
}

///|
test "panic adler32_fixed with an overflowing range" {
  let arr = kernel_test_bytes(32, 1)
  adler32_fixed(1, arr, 16, 2147483647) |> ignore
}

///|
test "compare256 at the window's end and every mismatch position" {
  // Ranges ending exactly at the end take the v128 path, one byte more
  // the checked fallback (which panics past the end, see below).
  let n = 300
  let w = FixedArray::makei(n, i => (i * 7 % 251).to_byte())
  for a in [0, 1, 15, n - 256] {
    let b = a
    assert_eq(compare256(w, a, b), 256)
  }
  for mismatch in 0..<256 {
    let w2 = FixedArray::make(512 + 16, b'\x00')
    for i in 0..<256 {
      w2[i] = (i * 13).to_byte()
      w2[256 + 16 + i] = (i * 13).to_byte()
    }
    w2[256 + 16 + mismatch] = (w2[256 + 16 + mismatch].to_int() ^ 1).to_byte()
    assert_eq(compare256(w2, 0, 256 + 16), mismatch)
    assert_eq(compare256(w2, 256 + 16, 0), mismatch)
  }
}

///|
test "panic compare256 past the window's end" {
  let w = FixedArray::make(300, b'\x00')
  compare256(w, 0, 45) |> ignore
}

///|
test "PosTable round-trips u16 values at both ends" {
  for n in [1, 2, 7, 8, 9, 16, 17] {
    let t = PosTable::make(n)
    for i in 0..<n {
      t.unsafe_set(i, 0xffff - i)
    }
    t.unsafe_set(n - 1, 0x1ffff) // truncated to 0xffff
    for i in 0..<(n - 1) {
      assert_eq(t.unsafe_get(i), 0xffff - i)
    }
    assert_eq(t.unsafe_get(n - 1), 0xffff)
    t.fill_zero()
    for i in 0..<n {
      assert_eq(t.unsafe_get(i), 0)
    }
  }
}

// -- image resampling --

///|
test "vertical_sample_row matches its scalar twin at every length" {
  for row_len in 0..<=40 {
    for n in 0..<4 {
      let image = kernel_test_floats((n + 2) * row_len, row_len * 5 + n, 255.0)
      let ws = Array::from_fixed_array(kernel_test_floats(n, n + 3, 1.5))
      for left in 0..<3 {
        if (left + n) * row_len > image.length() {
          continue
        }
        for out_base in [0, 1, 7, 15] {
          let o1 = FixedArray::make(out_base + row_len + 2, (-1.0 : Float))
          let o2 = FixedArray::make(out_base + row_len + 2, (-1.0 : Float))
          vertical_sample_row(image, o1, row_len, out_base, left, ws)
          vertical_sample_row_scalar(image, o2, row_len, out_base, left, ws)
          assert_floats_eq(o1, o2)
          // Exact allocation end.
          let e1 = FixedArray::make(out_base + row_len, (-1.0 : Float))
          let e2 = FixedArray::make(out_base + row_len, (-1.0 : Float))
          vertical_sample_row(image, e1, row_len, out_base, left, ws)
          vertical_sample_row_scalar(image, e2, row_len, out_base, left, ws)
          assert_floats_eq(e1, e2)
        }
      }
    }
  }
}

///|
test "vertical_sample_row with the output aliasing the image" {
  // `image = out = [1, 2, 3, 4, 5]`, row_len 4, out_base 1, ws [1]: each
  // written sample is read again by the scalar code.
  let a1 : FixedArray[Float] = [1, 2, 3, 4, 5]
  let a2 = a1.copy()
  vertical_sample_row(a1, a1, 4, 1, 0, [1.0])
  vertical_sample_row_scalar(a2, a2, 4, 1, 0, [1.0])
  assert_floats_eq(a1, a2)
  for row_len in [4, 16, 17, 33] {
    for out_base in [0, 1, 5, row_len] {
      let b1 = kernel_test_floats(4 * row_len + out_base, row_len, 9.0)
      let b2 = b1.copy()
      let ws : Array[Float] = [0.5, 0.25, 0.25]
      vertical_sample_row(b1, b1, row_len, out_base, 0, ws)
      vertical_sample_row_scalar(b2, b2, row_len, out_base, 0, ws)
      assert_floats_eq(b1, b2)
    }
  }
}

///|
test "panic vertical_sample_row past the image's end" {
  let image = kernel_test_floats(31, 1, 1.0)
  let out = FixedArray::make(16, (0.0 : Float))
  vertical_sample_row(image, out, 16, 0, 1, [1.0])
}

///|
test "panic vertical_sample_row past the output's end" {
  let image = kernel_test_floats(64, 1, 1.0)
  let out = FixedArray::make(16, (0.0 : Float))
  vertical_sample_row(image, out, 16, 1, 0, [1.0])
}

///|
test "horizontal_sample_sums matches its scalar twin" {
  for channels in 1..<=5 {
    for n in 0..<7 {
      for start in 0..<16 {
        for spare in 0..<5 {
          let len = start + n * channels + spare
          let image = kernel_test_floats(len, len + channels, 255.0)
          let ws = Array::from_fixed_array(kernel_test_floats(n, n + 11, 1.5))
          // `t` longer than `channels`: the surplus is cleared like the
          // scalar code does.
          for t_len in [channels, channels + 1, channels + 3] {
            let t1 = FixedArray::make(t_len, (-1.0 : Float))
            let t2 = FixedArray::make(t_len, (-1.0 : Float))
            horizontal_sample_sums(image, start, channels, ws, t1)
            horizontal_sample_sums_scalar(image, start, channels, ws, t2)
            assert_floats_eq(t1, t2)
          }
        }
      }
    }
  }
}

///|
test "horizontal_sample_sums clears the surplus of the accumulator" {
  let image : FixedArray[Float] = [1, 2, 3, 99]
  let t1 : FixedArray[Float] = [-1, -1, -1, -1]
  let t2 = t1.copy()
  horizontal_sample_sums(image, 0, 3, [1.0], t1)
  horizontal_sample_sums_scalar(image, 0, 3, [1.0], t2)
  assert_floats_eq(t1, t2)
  assert_eq(t1[3], 0.0)
}

///|
test "horizontal_sample_sums with the accumulator aliasing the image" {
  for channels in [3, 4] {
    let a1 = kernel_test_floats(4 * channels + 4, channels, 9.0)
    let a2 = a1.copy()
    let ws : Array[Float] = [0.5, 0.5, 1.0]
    horizontal_sample_sums(a1, 1, channels, ws, a1)
    horizontal_sample_sums_scalar(a2, 1, channels, ws, a2)
    assert_floats_eq(a1, a2)
  }
}

///|
test "panic horizontal_sample_sums with a short accumulator" {
  let image = kernel_test_floats(32, 1, 1.0)
  horizontal_sample_sums(image, 0, 4, [1.0, 1.0], FixedArray::make(3, 0.0))
}

///|
test "panic horizontal_sample_sums past the image's end" {
  let image = kernel_test_floats(11, 1, 1.0)
  horizontal_sample_sums(image, 0, 4, [1.0, 1.0, 1.0], FixedArray::make(4, 0.0))
}

// -- JPEG --

///|
test "upsample_horizontal_core matches its scalar twin" {
  for n in 0..<=40 {
    for in_off in [0, 1, 3, 15] {
      for out_off in [0, 2, 7, 15] {
        let src = kernel_test_ints(in_off + n + 2, n + in_off, 0, 255)
        let input : Slice = { arr: src, off: in_off, len: n + 2, }
        // Exact allocation end and sentinels after the output.
        for extra in [0, 2] {
          let o1 = FixedArray::make(out_off + 2 + 2 * n + extra, -7)
          let o2 = FixedArray::make(out_off + 2 + 2 * n + extra, -7)
          upsample_horizontal_core(
            input,
            { arr: o1, off: out_off, len: 2 * n + 2, },
            n,
          )
          upsample_horizontal_core_scalar(
            input,
            { arr: o2, off: out_off, len: 2 * n + 2, },
            n,
          )
          assert_ints_eq(o1, o2)
        }
      }
    }
  }
}

///|
test "upsample_horizontal_core with the output aliasing the input" {
  for n in [4, 8, 9, 17, 33] {
    for offs in [(0, 0), (0, 1), (5, 0), (2, 3)] {
      let (in_off, out_off) = offs
      let a1 = kernel_test_ints(2 * n + 16, n, 0, 255)
      let a2 = a1.copy()
      upsample_horizontal_core(
        { arr: a1, off: in_off, len: n + 2, },
        { arr: a1, off: out_off, len: 2 * n + 2, },
        n,
      )
      upsample_horizontal_core_scalar(
        { arr: a2, off: in_off, len: n + 2, },
        { arr: a2, off: out_off, len: 2 * n + 2, },
        n,
      )
      assert_ints_eq(a1, a2)
    }
  }
}

///|
test "upsample_vertical_core matches its scalar twin" {
  for n in 0..<=40 {
    for off in [0, 1, 4, 15] {
      for start in [0, 3, 16] {
        let src = kernel_test_ints(off + n, n + off, 0, 255)
        let near = kernel_test_ints(off + n + 1, n + 99, 0, 255)
        for extra in [0, 3] {
          let o1 = FixedArray::make(off + start + n + extra, -7)
          let o2 = FixedArray::make(off + start + n + extra, -7)
          upsample_vertical_core(
            { arr: src, off, len: n, },
            { arr: near, off: off + 1, len: n, },
            { arr: o1, off, len: start + n, },
            start,
            n,
          )
          upsample_vertical_core_scalar(
            { arr: src, off, len: n, },
            { arr: near, off: off + 1, len: n, },
            { arr: o2, off, len: start + n, },
            start,
            n,
          )
          assert_ints_eq(o1, o2)
        }
      }
    }
  }
}

///|
test "upsample_vertical_core with the output aliasing an input" {
  for n in [4, 8, 9, 17] {
    for shift in [0, 1, 3] {
      // output == input
      let a1 = kernel_test_ints(2 * n + 8, n, 0, 255)
      let a2 = a1.copy()
      let near = kernel_test_ints(n, n + 1, 0, 255)
      upsample_vertical_core(
        { arr: a1, off: 0, len: n, },
        { arr: near, off: 0, len: n, },
        { arr: a1, off: shift, len: n, },
        0,
        n,
      )
      upsample_vertical_core_scalar(
        { arr: a2, off: 0, len: n, },
        { arr: near, off: 0, len: n, },
        { arr: a2, off: shift, len: n, },
        0,
        n,
      )
      assert_ints_eq(a1, a2)
      // output == near
      let b1 = kernel_test_ints(2 * n + 8, n + 5, 0, 255)
      let b2 = b1.copy()
      let input = kernel_test_ints(n, n + 2, 0, 255)
      upsample_vertical_core(
        { arr: input, off: 0, len: n, },
        { arr: b1, off: shift, len: n, },
        { arr: b1, off: 0, len: n, },
        0,
        n,
      )
      upsample_vertical_core_scalar(
        { arr: input, off: 0, len: n, },
        { arr: b2, off: shift, len: n, },
        { arr: b2, off: 0, len: n, },
        0,
        n,
      )
      assert_ints_eq(b1, b2)
    }
  }
}

///|
test "panic upsample_horizontal_core past the output's end" {
  let src = kernel_test_ints(20, 1, 0, 255)
  let out = FixedArray::make(2 + 2 * 16 - 1, 0)
  upsample_horizontal_core(
    { arr: src, off: 0, len: 18, },
    { arr: out, off: 0, len: 34, },
    16,
  )
}

///|
test "panic upsample_vertical_core past the input's end" {
  let src = kernel_test_ints(15, 1, 0, 255)
  let out = FixedArray::make(16, 0)
  upsample_vertical_core(
    { arr: src, off: 0, len: 16, },
    { arr: src, off: 0, len: 16, },
    { arr: out, off: 0, len: 16, },
    0,
    16,
  )
}

///|
test "idct_int matches its scalar twin at every output position" {
  for seed in 0..<6 {
    // Sparse and dense blocks (and the all-zero AC shortcut).
    let coeffs = kernel_test_ints(64, seed, -1024, 1023)
    if seed % 3 == 0 {
      for i in 1..<64 {
        coeffs[i] = 0
      }
    }
    for stride in [8, 9, 16] {
      for out_pos in [0, 1, 5, 15] {
        // Rows past the end are skipped: lengths cutting through rows.
        for
          len in [
            0,
            out_pos + 7,
            out_pos + 8 + stride,
            out_pos + 7 * stride + 8,
            out_pos + 8 * stride + 3,
          ] {
          let o1 = FixedArray::make(len, -9)
          let o2 = FixedArray::make(len, -9)
          idct_int(coeffs, o1, out_pos, stride)
          idct_int_scalar(coeffs, o2, out_pos, stride)
          assert_ints_eq(o1, o2)
        }
      }
    }
    // Negative and overflowing positions write nothing.
    for out_pos in [-8, -1, 2147483647, 2147483640] {
      let o1 = FixedArray::make(70, -9)
      let o2 = FixedArray::make(70, -9)
      idct_int(coeffs, o1, out_pos, 8)
      idct_int_scalar(coeffs, o2, out_pos, 8)
      assert_ints_eq(o1, o2)
    }
    // In place (the output aliasing the coefficients).
    let a1 = coeffs.copy()
    let a2 = coeffs.copy()
    idct_int(a1, a1, 0, 8)
    idct_int_scalar(a2, a2, 0, 8)
    assert_ints_eq(a1, a2)
  }
}

///|
test "panic idct_int with fewer than 64 coefficients" {
  idct_int(FixedArray::make(63, 1), FixedArray::make(64, 0), 0, 8)
}

///|
test "ycbcr_to_rgb_16 matches its scalar twin at every offset" {
  let y = kernel_test_ints(48, 1, -300, 600)
  let cb = kernel_test_ints(48, 2, -300, 600)
  let cr = kernel_test_ints(48, 3, -300, 600)
  for nc in [3, 4] {
    for off in 0..<16 {
      for out_pos in [0, 1, 7, 15] {
        // Exact end and spare room.
        for extra in [0, 5] {
          let len = out_pos + 16 * nc + extra
          let o1 = FixedArray::make(len, SENTINEL.to_byte())
          let o2 = FixedArray::make(len, SENTINEL.to_byte())
          ycbcr_to_rgb_16(y, off, cb, 32 - off, cr, off * 2, o1, out_pos, nc)
          ycbcr_to_rgb_16_scalar(
            y,
            off,
            cb,
            32 - off,
            cr,
            off * 2,
            o2,
            out_pos,
            nc,
          )
          assert_bytes_eq(o1, o2)
        }
      }
    }
  }
}

///|
test "panic ycbcr_to_rgb_16 past the output's end" {
  let y = FixedArray::make(16, 100)
  ycbcr_to_rgb_16(y, 0, y, 0, y, 0, FixedArray::make(47, b'\x00'), 0, 3)
}

///|
test "panic ycbcr_to_rgb_16 past a sample array's end" {
  let y = FixedArray::make(16, 100)
  ycbcr_to_rgb_16(y, 1, y, 0, y, 0, FixedArray::make(64, b'\x00'), 0, 4)
}
