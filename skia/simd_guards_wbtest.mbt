// The range predicate of the v128 demultiply (native and wasm; the native
// test driver skips `panic` tests, so the rejection is checked directly).

///|
test "demultiply_ranges_ok rejects short outputs" {
  let data = FixedArray::make(16, 0U)
  assert_true(demultiply_ranges_ok(data, FixedArray::make(64, b'\x00')))
  assert_false(demultiply_ranges_ok(data, FixedArray::make(63, b'\x00')))
  assert_true(
    demultiply_ranges_ok(FixedArray::make(0, 0U), FixedArray::make(0, b'\x00')),
  )
}
