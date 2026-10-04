// The range predicates of the v128 kernels (native and wasm). The native
// test driver skips `panic` tests, so the rejection of undersized,
// negative and overflowing parameters is checked here directly: a rejected
// call runs the checked scalar code (which panics) or aborts, so the
// unchecked loads and stores never run.

///|
test "in_range rejects negative, past-the-end and overflowing ranges" {
  assert_true(in_range(0, 0, 0))
  assert_true(in_range(16, 16, 32))
  assert_false(in_range(17, 16, 32))
  assert_false(in_range(-1, 16, 32))
  assert_false(in_range(0, -1, 32))
  assert_false(in_range(1, 9223372036854775807L, 0))
  assert_false(in_range(2147483647, 2L, 2147483647))
  assert_false(in_range(16, 2147483647L, 32))
}

///|
test "filter_ranges_ok rejects short rows and negative bpp" {
  let row = FixedArray::make(20, b'\x00')
  assert_true(filter_ranges_ok(1, row, row, FixedArray::make(21, b'\x00')))
  assert_false(filter_ranges_ok(1, row, row, FixedArray::make(20, b'\x00')))
  assert_false(
    filter_ranges_ok(
      2,
      FixedArray::make(19, b'\x00'),
      row,
      FixedArray::make(21, b'\x00'),
    ),
  )
  assert_false(filter_ranges_ok(-1, row, row, FixedArray::make(21, b'\x00')))
  // An output aliasing the current row is always too short.
  assert_false(filter_ranges_ok(1, row.copy(), row, row))
}

///|
test "vertical_sample_ranges_ok rejects ranges past the image or output" {
  let image = FixedArray::make(32, (0.0 : Float))
  let out = FixedArray::make(16, (0.0 : Float))
  assert_true(vertical_sample_ranges_ok(image, out, 16, 0, 1, 1))
  assert_false(vertical_sample_ranges_ok(image, out, 16, 0, 1, 2))
  assert_false(
    vertical_sample_ranges_ok(FixedArray::make(31, 0.0), out, 16, 0, 1, 1),
  )
  assert_false(vertical_sample_ranges_ok(image, out, 16, 1, 0, 1))
  assert_false(vertical_sample_ranges_ok(image, out, 16, -1, 0, 1))
  assert_false(vertical_sample_ranges_ok(image, out, 16, 0, -1, 1))
  assert_false(vertical_sample_ranges_ok(image, out, 2147483647, 0, 0, 2))
}

///|
test "horizontal_sums_ranges_ok rejects short accumulators and images" {
  let image = FixedArray::make(12, (0.0 : Float))
  let t = FixedArray::make(4, (0.0 : Float))
  assert_true(horizontal_sums_ranges_ok(image, 0, 4, 3, t))
  assert_false(
    horizontal_sums_ranges_ok(image, 0, 4, 3, FixedArray::make(3, 0.0)),
  )
  assert_false(horizontal_sums_ranges_ok(FixedArray::make(11, 0.0), 0, 4, 3, t))
  // Three channels gather a fourth sample: 3 * 2 + 4 > 9.
  assert_false(horizontal_sums_ranges_ok(FixedArray::make(9, 0.0), 0, 3, 3, t))
  assert_false(horizontal_sums_ranges_ok(image, -1, 4, 2, t))
  assert_false(horizontal_sums_ranges_ok(image, 0, 5, 1, t))
}

///|
test "ycbcr_ranges_ok rejects short outputs, samples and other layouts" {
  let s = FixedArray::make(16, 0)
  assert_true(
    ycbcr_ranges_ok(s, 0, s, 0, s, 0, FixedArray::make(48, b'\x00'), 0, 3),
  )
  assert_false(
    ycbcr_ranges_ok(s, 0, s, 0, s, 0, FixedArray::make(47, b'\x00'), 0, 3),
  )
  assert_false(
    ycbcr_ranges_ok(s, 1, s, 0, s, 0, FixedArray::make(64, b'\x00'), 0, 4),
  )
  assert_false(
    ycbcr_ranges_ok(
      s,
      0,
      s,
      0,
      s,
      0,
      FixedArray::make(64, b'\x00'),
      2147483647,
      4,
    ),
  )
  assert_false(
    ycbcr_ranges_ok(s, 0, s, 0, s, 0, FixedArray::make(64, b'\x00'), 0, 2),
  )
}

///|
test "slice_range_ok rejects slices past their array" {
  let arr = FixedArray::make(20, 0)
  let s : Slice = { arr, off: 2, len: 18, }
  assert_true(slice_range_ok(s, 0, 18L))
  assert_false(slice_range_ok(s, 0, 19L))
  assert_false(slice_range_ok(s, 2, 17L))
  assert_false(slice_range_ok({ arr, off: -1, len: 1, }, 0, 1L))
  assert_false(slice_range_ok(s, -1, 1L))
  assert_false(slice_range_ok(s, 1, 9223372036854775807L))
}
