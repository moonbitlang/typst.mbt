///|
/// FNV-1a (32 bits) of bytes.
fn fnv(bytes : Bytes) -> String {
  let mut h = 0x811c9dc5U
  for b in bytes {
    h = (h ^ b.to_uint()) * 0x01000193U
  }
  h.to_string(radix=16)
}

///|
test "the five files, the same bytes on every target" {
  // Raw bytes on native, base64 on the wasm targets: the lengths and
  // hashes are those of the files of `files/`, in the order of `moon.pkg`.
  let fonts = @fonts.sans()
  inspect(
    fonts.map(font => "\{font.length()} \{fnv(font)}").join("\n"),
    content=(
      #|175748 d7232e6b
      #|207920 7d622cab
      #|175712 d7525a7a
      #|208588 f2de81f7
      #|177104 d23afa6e
    ),
  )
  for font in fonts {
    // TrueType outlines: sfnt version 1.0.
    assert_true(
      font[0] == b'\x00' &&
      font[1] == b'\x01' &&
      font[2] == b'\x00' &&
      font[3] == b'\x00',
    )
  }
  // Decoded once.
  assert_true(physical_equal(fonts, @fonts.sans()))
}
