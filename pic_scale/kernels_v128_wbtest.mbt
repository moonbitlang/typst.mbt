// The range predicates of the v128 kernels (native and wasm). The native
// test driver skips `panic` tests, so the rejection of undersized,
// negative, overflowing and aliased parameters is checked here directly: a
// rejected call runs the (checked) emulation.

///|
test "vertical_ranges_ok rejects what the panic tests feed the kernels" {
  let src = kbytes(64, 1)
  let dst = FixedArray::make(32, b'\x00')
  let w : FixedArray[Int] = [16384, 16384]
  let acc = FixedArray::make(32, 0)
  assert_true(vertical_ranges_ok(32, 0, 2, src, 0, 32, dst, 0, w, 0, acc))
  // short accumulator, source, output
  assert_false(
    vertical_ranges_ok(
      32,
      0,
      2,
      src,
      0,
      32,
      dst,
      0,
      w,
      0,
      FixedArray::make(31, 0),
    ),
  )
  assert_false(
    vertical_ranges_ok(32, 0, 2, kbytes(63, 1), 0, 32, dst, 0, w, 0, acc),
  )
  assert_false(
    vertical_ranges_ok(
      32,
      0,
      1,
      src,
      0,
      32,
      FixedArray::make(31, b'\x00'),
      0,
      w,
      0,
      acc,
    ),
  )
  // overflowing stride, negative offsets, short weights
  assert_false(
    vertical_ranges_ok(16, 1, 2, src, 0, 2147483647, dst, 0, w, 0, acc),
  )
  assert_false(vertical_ranges_ok(16, 0, 2, src, -1, 16, dst, 0, w, 0, acc))
  assert_false(vertical_ranges_ok(16, 0, 2, src, 0, 16, dst, -1, w, 0, acc))
  assert_false(vertical_ranges_ok(16, 0, 2, src, 0, 16, dst, 0, w, 1, acc))
  // aliasing and weights outside `i16`
  assert_false(vertical_ranges_ok(16, 0, 2, src, 0, 16, src, 0, w, 0, acc))
  let wa = FixedArray::make(32, 32767)
  assert_false(vertical_ranges_ok(16, 0, 1, src, 0, 16, dst, 0, wa, 0, wa))
  assert_false(
    vertical_ranges_ok(16, 0, 1, src, 0, 16, dst, 0, [32768], 0, acc),
  )
  assert_true(
    vertical_ranges_ok(16, 0, 1, src, 0, 16, dst, 0, [-32768], 0, acc),
  )
}

///|
test "horizontal_ranges_ok rejects what the panic tests feed the kernels" {
  let fw = kweights(4, 3, 8, 1, 0)
  assert_true(
    horizontal_ranges_ok(
      kbytes(32, 1),
      0,
      FixedArray::make(16, b'\x00'),
      0,
      fw,
      4,
    ),
  )
  // a tap past the source's end
  let far = kweights(4, 3, 8, 1, 0)
  far.bounds_start[3] = 6
  far.bounds_size[3] = 3
  assert_false(
    horizontal_ranges_ok(
      kbytes(32, 1),
      0,
      FixedArray::make(16, b'\x00'),
      0,
      far,
      4,
    ),
  )
  // short output, negative source offset, short weights
  assert_false(
    horizontal_ranges_ok(
      kbytes(24, 1),
      0,
      FixedArray::make(11, b'\x00'),
      0,
      fw,
      3,
    ),
  )
  assert_false(
    horizontal_ranges_ok(
      kbytes(8, 1),
      -1,
      FixedArray::make(4, b'\x00'),
      0,
      fw,
      1,
    ),
  )
  let short = { ..fw, weights: FixedArray::makei(11, i => fw.weights[i]), }
  assert_false(
    horizontal_ranges_ok(
      kbytes(32, 1),
      0,
      FixedArray::make(16, b'\x00'),
      0,
      short,
      4,
    ),
  )
  // aliasing and weights outside `i16`
  let buf = kbytes(64, 2)
  assert_false(horizontal_ranges_ok(buf, 0, buf, 32, fw, 4))
  let big = kweights(4, 3, 8, 1, 32768)
  assert_false(
    horizontal_ranges_ok(
      kbytes(32, 1),
      0,
      FixedArray::make(16, b'\x00'),
      0,
      big,
      4,
    ),
  )
}
