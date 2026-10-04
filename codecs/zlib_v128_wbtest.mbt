// Tests of the native/wasm-only helpers of the v128 kernels.

///|
test "in_range does not overflow" {
  assert_true(in_range(0, 16L, 16))
  assert_false(in_range(1, 16L, 16))
  assert_false(in_range(-1, 1L, 16))
  assert_false(in_range(2147483647, 48L, 48))
  assert_false(in_range(2147483640, 16L, 2147483647))
  assert_true(in_range(2147483631, 16L, 2147483647))
}
