// Port of the unit tests of `hayro-jbig2/src/segment.rs`.

///|
test "segment header example 1" {
  // 7.2.8 Segment header example, EXAMPLE 1:
  // "A segment header consisting of the sequence of bytes:
  // 0x00 0x00 0x00 0x20 0x86 0x6B 0x02 0x1E 0x05 0x04"
  //
  // Plus 4 bytes for data length (not shown in example).
  let data = b"\x00\x00\x00\x20\x86\x6B\x02\x1E\x05\x04\x00\x00\x00\x10"
  let reader = Reader::new(data[:])
  let header = parse_segment_header(reader)

  // "0x00 0x00 0x00 0x20: This segment's number is 0x00000020, or 32 decimal."
  assert_eq(header.segment_number, 32)

  // "0x86: This segment's type is 6. Its page association field is one byte
  // long. It is retained by only its attached extension segments."
  assert_true(header.segment_type is ImmediateTextRegion)
  assert_false(header._retain_flag)

  // "0x02 0x1E 0x05: The three segments that it refers to are numbers 2, 30, and 5."
  assert_eq(header.referred_to_segments, [2, 30, 5])

  // "0x04: This segment is associated with page number 4."
  assert_eq(header._page_association, 4)
  assert_eq(header.data_length, Some(16))
}

///|
test "segment header example 2" {
  // 7.2.8 Segment header example, EXAMPLE 2.
  let data = b"\x00\x00\x02\x34\x40\xE0\x00\x00\x09\x02\xFD\x01\x00\x00\x02\x00\x1E\x00\x05\x02\x00\x02\x01\x02\x02\x02\x03\x02\x04\x00\x00\x04\x01\x00\x00\x00\x20"
  let reader = Reader::new(data[:])
  let header = parse_segment_header(reader)

  // "00 00 02 34: This segment's number is 0x00000234, or 564 decimal."
  assert_eq(header.segment_number, 564)

  // "40: This segment's type is 0. Its page association field is four bytes long."
  assert_true(header.segment_type is SymbolDictionary)
  assert_true(header._retain_flag)

  // "01 00 ... 02 04: The nine segments that it refers to are ..."
  assert_eq(header.referred_to_segments, [
    256, 2, 30, 5, 512, 513, 514, 515, 516,
  ])

  // "00 00 04 01: This segment is associated with page number 1025."
  assert_eq(header._page_association, 1025)
  assert_eq(header.data_length, Some(32))
}

///|
test "binary search picks the same entry as Rust's slice::binary_search_by" {
  let entries : Array[(UInt, Int)] = [(1, 0), (3, 1), (3, 2), (3, 3), (7, 4)]
  // Rust's implementation narrows to the last of equal keys here.
  assert_eq(binary_search_by_key(entries, 3), Some(3))
  assert_eq(binary_search_by_key(entries, 1), Some(0))
  assert_eq(binary_search_by_key(entries, 7), Some(4))
  assert_eq(binary_search_by_key(entries, 4), None)
}
