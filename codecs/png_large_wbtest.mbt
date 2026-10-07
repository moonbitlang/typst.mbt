// A test with an input of 2^28 bytes (native only: a quarter of a gigabyte).

///|
test "png: the code length codes of a block with 2^28 bytes of input left" {
  // `remaining_input.len() * 8` is not an `Int`: the decompressor must read
  // the code length codes (and not wait for more input for ever). The
  // input is a view of 2^28 + 16 bytes of zeros after the start of a
  // dynamic block; a block of zeros has no valid code, which is an error
  // as soon as the codes are read.
  // A zlib header and a dynamic block: BFINAL = 1, BTYPE = 2.
  let data = b"\x78\x01\x05" + Bytes::make(0x10000000 + 16, 0)
  let decoder = Decompressor::new()
  let output = FixedArray::make(64, b'\x00')
  try decoder.read(data[:], output, 0, 64, 0, false) catch {
    BadCodeLengthHuffmanTree => ()
    e => fail("another error: \{e.debug()}")
  } noraise {
    produced => fail("no error (\{produced} bytes)")
  }
}
