///|
/// The bit position is 64-bit like upstream's `usize`: byte offsets of
/// 256 MiB and more must not wrap.
test "bit reader position beyond 2^31 bits" {
  let r = BitReader::new(b"\x00\x01"[:])
  r.bit_offset = 1L << 31
  assert_eq(r.byte_pos(), 1 << 28)
  assert_true(r.at_end())
  assert_true((try? r.read_bit()) is Err(UnexpectedEof))
}
