///|
/// The bit position is 64-bit like upstream's `usize`: byte offsets of
/// 256 MiB and more must not wrap.
test "reader bit position beyond 2^31 bits" {
  let r = Reader::new(b"\x00\x01"[:])
  r.cur_pos = 1L << 31
  assert_eq(r.byte_pos(), 1 << 28)
  assert_true(r.at_end())
  assert_eq(r.read_byte(), None)
  assert_eq(r.tail(), None)
}
