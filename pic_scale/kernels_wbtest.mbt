// The target-selected row/column kernels (`*_v128.mbt` on native/wasm, the
// lane emulations on wasm-gc/js) against the lane emulations, which are
// compiled on every target: shapes and offsets, exact buffer ends (incl. the
// RGB over-read edge), sentinels around the output, aliased buffers,
// weights at and beyond the `i16` range, and undersized buffers (panics).

///|
fn kbytes(n : Int, seed : Int) -> FixedArray[Byte] {
  let r = SplitMix::{ state: seed.to_uint64() * 0x9E3779B97F4A7C15UL + 1, }
  FixedArray::makei(n, _ => (r.next() & 0xff).to_int().to_byte())
}

///|
/// `n` output pixels with taps `bounds_start[x]..+ bounds_size[x]` (at most
/// `aligned` each, within `src_pixels`) and weights summing to about 1.0 in
/// Q15, overridden by `edge` (if non-zero) for every first tap.
fn kweights(
  n : Int,
  aligned : Int,
  src_pixels : Int,
  seed : Int,
  edge : Int,
) -> FixedWeights {
  let r = SplitMix::{ state: seed.to_uint64() + 77, }
  let bounds_start = FixedArray::make(n, 0)
  let bounds_size = FixedArray::make(n, 0)
  let weights = FixedArray::make(n * aligned, 0)
  for x in 0..<n {
    let size = if src_pixels == 0 {
      0
    } else {
      @cmp.minimum(r.below(aligned.to_uint64() + 1).to_int(), src_pixels)
    }
    let start = r.below((src_pixels - size + 1).to_uint64()).to_int()
    bounds_start[x] = start
    bounds_size[x] = size
    for j in 0..<size {
      // Mostly positive, some negative lobes.
      weights[x * aligned + j] = r.below(40000).to_int() - 8000
    }
    if edge != 0 && size > 0 {
      weights[x * aligned] = edge
    }
  }
  {
    weights,
    bounds_start,
    bounds_size,
    aligned_size: aligned,
    weights_fit_i16: weights_fit_i16(weights, 0, weights.length()),
  }
}

///|
/// The emulation of each horizontal kernel and its channel count.
fn horizontal_kernels() -> Array[(RowKernel, RowKernel, Int, String)] {
  [
    (rgba_rdm_row, convolve_horizontal_rgba_neon_row_i16, 4, "rgba rdm"),
    (rgb_rdm_row, convolve_horizontal_rgb_neon_rdm_row_one, 3, "rgb rdm"),
    (plane_rdm_row, convolve_horizontal_plane_neon_rdm_row, 1, "plane rdm"),
    (rgba_q15_row, convolve_horizontal_rgba_neon_row, 4, "rgba q15"),
    (rgb_q15_row, convolve_horizontal_rgb_neon_row_one, 3, "rgb q15"),
  ]
}

///|
fn assert_same_bytes(
  a : FixedArray[Byte],
  b : FixedArray[Byte],
  what : String,
) -> Unit raise {
  assert_eq(a.length(), b.length())
  for i in 0..<a.length() {
    if a[i] != b[i] {
      fail("\{what}: byte \{i} differs: \{a[i]} vs \{b[i]}")
    }
  }
}

///|
test "horizontal kernels match the emulation" {
  for k in horizontal_kernels() {
    let (kernel, emulation, ch, name) = k
    for n in 0..<12 {
      for aligned in [1, 2, 3, 4, 5, 8, 9] {
        for src_pixels in [0, 1, 2, 7, 16] {
          for seed in 0..<3 {
            let fw = kweights(n, aligned, src_pixels, seed * 31 + n, 0)
            for src_offset in [0, 1, 5, 15] {
              // The source ends exactly at the last pixel (RGB over-read
              // edge) or has spare bytes.
              for spare in [0, 1, 2, 3] {
                let src = kbytes(src_offset + src_pixels * ch + spare, seed + n)
                for dst_offset in [0, 3, 15] {
                  for extra in [0, 2] {
                    let len = dst_offset + n * ch + extra
                    let d1 = FixedArray::make(len, b'\x5a')
                    let d2 = FixedArray::make(len, b'\x5a')
                    kernel(src, src_offset, d1, dst_offset, fw)
                    emulation(src, src_offset, d2, dst_offset, fw)
                    assert_same_bytes(d1, d2, name)
                  }
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
test "horizontal kernels with weights at and beyond the i16 range" {
  for k in horizontal_kernels() {
    let (kernel, emulation, ch, name) = k
    for edge in [32767, -32768, 32768, -32769, 70000] {
      let fw = kweights(9, 4, 12, edge, edge)
      assert_eq(fw.weights_fit_i16, edge >= -32768 && edge <= 32767)
      let src = kbytes(12 * ch + 3, 5)
      let d1 = FixedArray::make(9 * ch, b'\x00')
      let d2 = FixedArray::make(9 * ch, b'\x00')
      kernel(src, 0, d1, 0, fw)
      emulation(src, 0, d2, 0, fw)
      assert_same_bytes(d1, d2, name)
    }
  }
}

///|
test "horizontal kernels with the output aliasing the source" {
  for k in horizontal_kernels() {
    let (kernel, emulation, ch, name) = k
    for dst_offset in [0, 1, 4, 13] {
      let fw = kweights(8, 5, 10, dst_offset, 0)
      let b1 = kbytes(10 * ch + 2 + dst_offset + 8 * ch, 9)
      let b2 = b1.copy()
      kernel(b1, 0, b1, dst_offset, fw)
      emulation(b2, 0, b2, dst_offset, fw)
      assert_same_bytes(b1, b2, name)
    }
  }
}

///|
test "panic rgba_rdm_row with a short source" {
  let fw = kweights(4, 3, 8, 1, 0)
  fw.bounds_start[3] = 6
  fw.bounds_size[3] = 3
  rgba_rdm_row(kbytes(8 * 4, 1), 0, FixedArray::make(16, b'\x00'), 0, fw)
}

///|
test "panic rgb_rdm_row with a short output" {
  let fw = kweights(4, 3, 8, 1, 0)
  rgb_rdm_row(kbytes(8 * 3, 1), 0, FixedArray::make(11, b'\x00'), 0, fw)
}

///|
test "panic plane_rdm_row with a negative source offset" {
  let fw = kweights(4, 3, 8, 1, 0)
  fw.bounds_start[0] = 0
  fw.bounds_size[0] = 1
  plane_rdm_row(kbytes(8, 1), -1, FixedArray::make(4, b'\x00'), 0, fw)
}

///|
test "panic rgba_q15_row with short weights" {
  let fw = kweights(4, 3, 8, 1, 0)
  fw.bounds_start[3] = 0
  fw.bounds_size[3] = 3
  let short = { ..fw, weights: FixedArray::makei(11, i => fw.weights[i]), }
  rgba_q15_row(kbytes(8 * 4, 1), 0, FixedArray::make(16, b'\x00'), 0, short)
}

///|
/// The emulation of each vertical kernel.
fn vertical_kernels() -> Array[(ColumnKernel, ColumnKernel, String)] {
  [
    (vertical_rdm_kernel, convolve_vertical_neon_i16_precision, "rdm"),
    (vertical_i32_kernel, convolve_vertical_neon_i32_precision, "i32"),
  ]
}

///|
test "vertical kernels match the emulation" {
  for k in vertical_kernels() {
    let (kernel, emulation, name) = k
    for width in 0..<=40 {
      for bounds_size in 0..<5 {
        for bounds_start in [0, 2] {
          for src_offset in [0, 1, 15] {
            let src_stride = width + src_offset % 3
            let rows = bounds_start + bounds_size
            // Exactly up to the last tap row's end.
            let src_len = if rows == 0 {
              src_offset
            } else {
              src_offset + src_stride * (rows - 1) + width
            }
            let src = kbytes(src_len, width * 7 + bounds_size)
            let r = SplitMix::{ state: (width + bounds_size).to_uint64(), }
            let weights = FixedArray::makei(bounds_size + 3, _ => {
              r.below(40000).to_int() - 8000
            })
            for weights_offset in [0, 3] {
              for dst_offset in [0, 1, 15] {
                for extra in [0, 3] {
                  let d1 = FixedArray::make(dst_offset + width + extra, b'\x5a')
                  let d2 = FixedArray::make(dst_offset + width + extra, b'\x5a')
                  kernel(
                    width,
                    bounds_start,
                    bounds_size,
                    src,
                    src_offset,
                    src_stride,
                    d1,
                    dst_offset,
                    weights,
                    weights_offset,
                    FixedArray::make(width, 0),
                  )
                  emulation(
                    width,
                    bounds_start,
                    bounds_size,
                    src,
                    src_offset,
                    src_stride,
                    d2,
                    dst_offset,
                    weights,
                    weights_offset,
                    FixedArray::make(width, 0),
                  )
                  assert_same_bytes(d1, d2, name)
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
test "vertical kernels with the output aliasing the source" {
  // A 34-byte buffer of 17 x 100 then 17 x 0: rows 0 and 1, the output
  // over row 0 (the emulation gives 17 x 50).
  for k in vertical_kernels() {
    let (kernel, emulation, name) = k
    let b1 = FixedArray::makei(34, i => if i < 17 { b'\x64' } else { b'\x00' })
    let b2 = b1.copy()
    let weights : FixedArray[Int] = [16384, 16384]
    kernel(17, 0, 2, b1, 0, 17, b1, 0, weights, 0, FixedArray::make(17, 0))
    emulation(17, 0, 2, b2, 0, 17, b2, 0, weights, 0, FixedArray::make(17, 0))
    assert_same_bytes(b1, b2, name)
    for i in 0..<17 {
      assert_eq(b1[i], b'\x32')
    }
    // Other overlaps.
    for dst_offset in [1, 5, 16, 20] {
      let c1 = kbytes(70, dst_offset)
      let c2 = c1.copy()
      let w : FixedArray[Int] = [12000, 9000, 11768]
      kernel(20, 0, 3, c1, 0, 20, c1, dst_offset, w, 0, FixedArray::make(20, 0))
      emulation(
        20,
        0,
        3,
        c2,
        0,
        20,
        c2,
        dst_offset,
        w,
        0,
        FixedArray::make(20, 0),
      )
      assert_same_bytes(c1, c2, name)
    }
  }
}

///|
test "vertical kernels with weights at and beyond the i16 range" {
  for k in vertical_kernels() {
    let (kernel, emulation, name) = k
    for edge in [32767, -32768, 32768, -32769, 100000] {
      let src = kbytes(3 * 24, 3)
      let weights : FixedArray[Int] = [edge, 5000, -3000]
      let d1 = FixedArray::make(24, b'\x00')
      let d2 = FixedArray::make(24, b'\x00')
      kernel(24, 0, 3, src, 0, 24, d1, 0, weights, 0, FixedArray::make(24, 0))
      emulation(
        24,
        0,
        3,
        src,
        0,
        24,
        d2,
        0,
        weights,
        0,
        FixedArray::make(24, 0),
      )
      assert_same_bytes(d1, d2, name)
    }
  }
}

///|
test "panic vertical_rdm_kernel with a short accumulator" {
  vertical_rdm_kernel(
    32,
    0,
    2,
    kbytes(64, 1),
    0,
    32,
    FixedArray::make(32, b'\x00'),
    0,
    [16384, 16384],
    0,
    FixedArray::make(31, 0),
  )
}

///|
test "panic vertical_i32_kernel with a short source" {
  vertical_i32_kernel(
    32,
    0,
    2,
    kbytes(63, 1),
    0,
    32,
    FixedArray::make(32, b'\x00'),
    0,
    [16384, 16384],
    0,
    FixedArray::make(32, 0),
  )
}

///|
test "panic vertical_rdm_kernel with a short output" {
  vertical_rdm_kernel(
    32,
    0,
    1,
    kbytes(32, 1),
    0,
    32,
    FixedArray::make(31, b'\x00'),
    0,
    [32767],
    0,
    FixedArray::make(32, 0),
  )
}

///|
test "panic vertical_i32_kernel with an overflowing stride" {
  vertical_i32_kernel(
    16,
    1,
    2,
    kbytes(64, 1),
    0,
    2147483647,
    FixedArray::make(16, b'\x00'),
    0,
    [16384, 16384],
    0,
    FixedArray::make(16, 0),
  )
}

///|
test "vertical kernels with the accumulator aliasing the weights" {
  // The emulation initializes `acc` before reading the weights.
  for k in vertical_kernels() {
    let (kernel, emulation, name) = k
    let src = FixedArray::make(16, b'\xff')
    let w1 = FixedArray::make(16, 32767)
    let w2 = FixedArray::make(16, 32767)
    let d1 = FixedArray::make(16, b'\x00')
    let d2 = FixedArray::make(16, b'\x00')
    kernel(16, 0, 1, src, 0, 16, d1, 0, w1, 0, w1)
    emulation(16, 0, 1, src, 0, 16, d2, 0, w2, 0, w2)
    assert_same_bytes(d1, d2, name)
  }
}
