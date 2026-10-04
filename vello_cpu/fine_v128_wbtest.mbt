// The range predicates of the v128 compositing kernels (native and wasm).
// The native test driver skips `panic` tests, so the rejection of
// undersized, negative, overlapping and aliased parameters is checked here
// directly: a rejected call runs the (checked) emulation.

///|
test "in_range and masks_ok reject past-the-end and overflowing ranges" {
  assert_true(in_range(0, 64L, 64))
  assert_false(in_range(0, 64L, 63))
  assert_false(in_range(-4, 32L, 64))
  assert_false(in_range(1, 9223372036854775807L, 0))
  let masks = Array::from_fixed_array(vbytes(8, 1))
  assert_true(masks_ok(masks, Some(0), 32))
  assert_false(masks_ok(masks, Some(1), 32))
  assert_false(masks_ok(masks, Some(-1), 4))
  assert_true(masks_ok([], None, 64))
}

///|
test "pack_ranges_ok rejects short buffers, overlapping rows and aliasing" {
  let scratch = vbytes(4 * TILE_HEIGHT_COMPONENTS, 1)
  assert_true(
    pack_ranges_ok(scratch, region_of(FixedArray::make(64, b'\x00'), 4, 16, 0)),
  )
  assert_false(
    pack_ranges_ok(scratch, region_of(FixedArray::make(63, b'\x00'), 4, 16, 0)),
  )
  assert_false(
    pack_ranges_ok(
      vbytes(4 * TILE_HEIGHT_COMPONENTS - 1, 1),
      region_of(FixedArray::make(64, b'\x00'), 4, 16, 0),
    ),
  )
  assert_false(
    pack_ranges_ok(scratch, region_of(FixedArray::make(68, b'\x00'), 4, 16, -4)),
  )
  // rows overlapping (stride < 4 * width)
  assert_false(
    pack_ranges_ok(scratch, region_of(FixedArray::make(64, b'\x00'), 4, 12, 0)),
  )
  // the scratch being the buffer
  let buf = vbytes(128, 2)
  assert_false(pack_ranges_ok(buf, region_of(buf, 4, 16, 0)))
}
