// What the oracle of damaged PNGs (`png_oracle_test.mbt`) does not reach:
// the names of the chunk types, and sizes that only a file of hundreds of
// megabytes has.

///|
test "png: the chunk types are their names" {
  let types : Array[(UInt, String)] = [
    (PNG_IHDR, "IHDR"),
    (PNG_PLTE, "PLTE"),
    (PNG_IDAT, "IDAT"),
    (PNG_IEND, "IEND"),
    (PNG_TRNS, "tRNS"),
    (PNG_BKGD, "bKGD"),
    (PNG_PHYS, "pHYs"),
    (PNG_CHRM, "cHRM"),
    (PNG_GAMA, "gAMA"),
    (PNG_SRGB, "sRGB"),
    (PNG_ICCP, "iCCP"),
    (PNG_CICP, "cICP"),
    (PNG_MDCV, "mDCV"),
    (PNG_CLLI, "cLLI"),
    (PNG_EXIF, "eXIf"),
    (PNG_TEXT, "tEXt"),
    (PNG_ZTXT, "zTXt"),
    (PNG_ITXT, "iTXt"),
    (PNG_SBIT, "sBIT"),
    (PNG_ACTL, "acTL"),
    (PNG_FCTL, "fcTL"),
    (PNG_FDAT, "fdAT"),
  ]
  for ty in types {
    let (value, name) = ty
    let mut bytes = 0U
    for c in name {
      bytes = (bytes << 8) | c.to_int().reinterpret_as_uint()
    }
    assert_eq(bytes, value)
    // An uppercase first letter is a critical chunk.
    assert_eq(chunk_is_critical(value), name is ['A'..='Z', ..])
    assert_true(
      chunk_type_debug(value).has_prefix("ChunkType { type: \{name}, "),
    )
  }
  assert_eq(
    chunk_type_debug(0x41800044),
    "ChunkType { type: A\\u{80}\\0D, critical: true, private: false, reserved: false, safecopy: false }",
  )
}

///|
test "png: the pixels of a row of 2^28 bytes of one-bit samples" {
  // `input_len * 8` is not an `Int`.
  assert_eq(unpack_bits_pixels(0x10000000, 0x7FFFFFF9, 1, 1), 0x7FFFFFF9)
  assert_eq(unpack_bits_pixels(0x10000000, 0x7FFF0000, 1, 1), 0x7FFF0000)
  // An output that the input has no samples for is not written (upstream
  // asserts that there is none).
  assert_eq(unpack_bits_pixels(3, 100, 1, 1), 24)
  assert_eq(unpack_bits_pixels(3, 100, 4, 2), 12)
  assert_eq(unpack_bits_pixels(3, 9, 3, 8), 3)
  assert_eq(unpack_bits_pixels(5, 9, 3, 8), 3)
  assert_eq(unpack_bits_pixels(2, 13, 1, 1), 13)
}
