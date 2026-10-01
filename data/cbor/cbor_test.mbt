// Expected outputs were produced by upstream Typst (ciborium 0.2.2).

///|
fn decode_err(bytes : Array[Int]) -> String {
  let data = Bytes::from_array(bytes.map(b => b.to_byte()))
  try @cbor.from_slice(data) catch {
    err => err.message()
  } noraise {
    _ => "ok"
  }
}

///|
fn decode(bytes : Array[Int]) -> @serde.Data {
  let data = Bytes::from_array(bytes.map(b => b.to_byte()))
  @cbor.from_slice(data) catch {
    err => abort(err.message())
  }
}

///|
test "decode errors" {
  inspect(
    decode_err([0xa1, 0x01, 0x01]),
    content="invalid type: integer `1`, expected str",
  )
  inspect(
    decode_err([0xc1, 0x01]),
    content="invalid type: enum, expected a Typst value",
  )
  inspect(
    decode_err([0xf0]),
    content="invalid type: simple, expected known simple value",
  )
  inspect(decode_err([0xff]), content="invalid type: break, expected non-break")
  inspect(decode_err([0x1c]), content="syntax error")
  inspect(decode_err([0x62, 0xff, 0xfe]), content="syntax error")
  inspect(
    decode_err([0xa1, 0x41, 0x61, 0x01]),
    content="invalid type: bytes, expected str",
  )
  inspect(
    decode_err([0xa1, 0xf9, 0x3c, 0x00, 0x01]),
    content="invalid type: floating point `1.0`, expected str",
  )
  inspect(
    decode_err([0xa1, 0x20, 0x01]),
    content="invalid type: integer `-1`, expected str",
  )
  inspect(
    decode_err([0xa1, 0xf6, 0x01]),
    content="invalid type: null, expected str",
  )
  inspect(
    decode_err([0xa1, 0x80, 0x01]),
    content="invalid type: sequence, expected str",
  )
  let nested = Array::make(300, 0x81)
  nested.push(0x01)
  inspect(decode_err(nested), content="recursion limit exceeded")
  inspect(decode_err([0x5f, 0x61, 0x61, 0xff]), content="syntax error")
  inspect(
    decode_err([
      0xc3, 0x50, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
      0xff, 0xff, 0xff, 0xff, 0xff,
    ]),
    content="integer too large",
  )
  inspect(decode_err([]), content="IO error: failed to fill whole buffer")
  inspect(
    decode_err([0xa1, 0xf4, 0x01]),
    content="invalid type: boolean `false`, expected str",
  )
  inspect(
    decode_err([0xa1, 0xfa, 0x3f, 0xc0, 0x00, 0x00, 0x01]),
    content="invalid type: floating point `1.5`, expected str",
  )
  inspect(
    decode_err([
      0xc2, 0x51, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    ]),
    content="invalid type: enum, expected a Typst value",
  )
  inspect(
    decode_err([0xf8, 0x10]),
    content="invalid type: simple, expected known simple value",
  )
  // A character split across segments.
  inspect(
    decode_err([0x7f, 0x61, 0xc3, 0x61, 0xa9, 0xff]),
    content="syntax error",
  )
}

///|
test "decode values" {
  debug_inspect(
    decode([
      0x9f, 0x01, 0x5f, 0x41, 0x61, 0x42, 0x62, 0x63, 0xff, 0x7f, 0x61, 0x78, 0x62,
      0xc3, 0xa9, 0xff, 0xbf, 0x61, 0x6b, 0xf7, 0xff, 0xf9, 0x3c, 0x00, 0xfa, 0x3f,
      0xc0, 0x00, 0x00, 0xff,
    ]),
    content=(
      #|Seq(
      #|  [
      #|    Int(1),
      #|    Bytes(<Bytes: [0x61, 0x62, 0x63]>),
      #|    Str("xé"),
      #|    Map([("k", None)]),
      #|    Float(1),
      #|    Float(1.5),
      #|  ],
      #|)

    ),
  )
  debug_inspect(
    decode([0xa2, 0x61, 0x61, 0x01, 0x61, 0x61, 0x02, 0x00]),
    content=(
      #|Map([("a", Int(1)), ("a", Int(2))])
    ),
  )
  debug_inspect(
    decode([0xa1, 0xc1, 0x61, 0x61, 0x01]),
    content=(
      #|Map([("a", Int(1))])
    ),
  )
}

///|
test "decode integers" {
  // `cbor-integers` from upstream `tests/suite/loading/edge-case.typ`.
  let bytes = [
    162, 109, 114, 101, 112, 114, 101, 115, 101, 110, 116, 97, 98, 108, 101, 162,
    103, 105, 54, 52, 95, 109, 97, 120, 27, 127, 255, 255, 255, 255, 255, 255, 255,
    103, 105, 54, 52, 95, 109, 105, 110, 59, 127, 255, 255, 255, 255, 255, 255, 255,
    101, 108, 97, 114, 103, 101, 167, 112, 105, 54, 52, 95, 109, 97, 120, 95, 112,
    108, 117, 115, 95, 111, 110, 101, 27, 128, 0, 0, 0, 0, 0, 0, 0, 113, 105, 54,
    52, 95, 109, 105, 110, 95, 109, 105, 110, 117, 115, 95, 111, 110, 101, 59, 128,
    0, 0, 0, 0, 0, 0, 0, 103, 117, 54, 52, 95, 109, 97, 120, 27, 255, 255, 255, 255,
    255, 255, 255, 255, 112, 117, 54, 52, 95, 109, 97, 120, 95, 112, 108, 117, 115,
    95, 111, 110, 101, 194, 73, 1, 0, 0, 0, 0, 0, 0, 0, 0, 104, 105, 49, 50, 56, 95,
    109, 97, 120, 194, 80, 127, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 104, 105, 49, 50, 56, 95, 109, 105, 110, 195, 80, 127, 255,
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 104, 117,
    49, 50, 56, 95, 109, 97, 120, 194, 80, 255, 255, 255, 255, 255, 255, 255, 255, 255,
    255, 255, 255, 255, 255, 255, 255,
  ]
  guard decode(bytes) is Map([(_, Map(repr)), (_, Map(large))]) else {
    fail("unexpected shape")
  }
  let show = (entries : Array[(String, @serde.Data)]) => entries.map(e => match
    e.1 {
    Int(i) => "\{e.0}: int \{i}"
    Float(f) => "\{e.0}: float \{@serde.format_debug(f)}"
    _ => "\{e.0}: other"
  })
  debug_inspect(
    show(repr),
    content=(
      #|[
      #|  "i64_max: int 9223372036854775807",
      #|  "i64_min: int -9223372036854775808",
      #|]

    ),
  )
  debug_inspect(
    show(large),
    content=(
      #|[
      #|  "i64_max_plus_one: float 9.223372036854776e18",
      #|  "i64_min_minus_one: float -9.223372036854776e18",
      #|  "u64_max: float 1.8446744073709552e19",
      #|  "u64_max_plus_one: float 1.8446744073709552e19",
      #|  "i128_max: float 1.7014118346046923e38",
      #|  "i128_min: float -1.7014118346046923e38",
      #|  "u128_max: float 3.402823669209385e38",
      #|]
    ),
  )
}

///|
test "encode" {
  let value : @serde.Data = Map([
    ("a", Int(1)),
    ("b", Seq([Float(1.5), Str("x"), None, Bool(true), Bool(false)])),
    ("c", Map([])),
    ("d", Seq([])),
    ("e", Float(1.0e20)),
    ("f", Float(0.1)),
    ("g", Float(0.0 / 0.0)),
    ("h", Float(-1.0 / 0.0)),
    ("i", Float(-0.0)),
    ("j", Float(65504.0)),
    ("k", Float(5.960464477539063e-8)),
    ("l", Float(1.0e-7)),
    ("m", Float(100000.0)),
    ("n", Int(-24)),
    ("o", Int(-25)),
    ("p", Int(-256)),
    ("q", Int(-257)),
    ("r", Int(255)),
    ("s", Int(256)),
    ("t", Int(65535)),
    ("u", Int(65536)),
    ("v", Int(4294967295)),
    ("w", Int(4294967296)),
    ("x", Int(9223372036854775807)),
    ("y", Int(-9223372036854775807L - 1L)),
    ("z", Bytes(b"\x01\x02")),
    (
      "aa",
      Map([("func", Str("strong")), ("body", Map([("func", Str("text")), ("text", Str("a"))]))]),
    ),
    ("ab", Str("→")),
    ("ac", Str("1pt")),
    ("ad", Float(3.4028234663852886e38)),
    ("ae", Float(6.103515625e-5)),
    ("af", Float(1.0000000000000002)),
  ])
  let expected = [
    184, 32, 97, 97, 1, 97, 98, 133, 249, 62, 0, 97, 120, 246, 245, 244, 97, 99, 160,
    97, 100, 128, 97, 101, 251, 68, 21, 175, 29, 120, 181, 140, 64, 97, 102, 251, 63,
    185, 153, 153, 153, 153, 153, 154, 97, 103, 249, 126, 0, 97, 104, 249, 252, 0,
    97, 105, 249, 128, 0, 97, 106, 249, 123, 255, 97, 107, 249, 0, 1, 97, 108, 251,
    62, 122, 215, 242, 154, 188, 175, 72, 97, 109, 250, 71, 195, 80, 0, 97, 110, 55,
    97, 111, 56, 24, 97, 112, 56, 255, 97, 113, 57, 1, 0, 97, 114, 24, 255, 97, 115,
    25, 1, 0, 97, 116, 25, 255, 255, 97, 117, 26, 0, 1, 0, 0, 97, 118, 26, 255, 255,
    255, 255, 97, 119, 27, 0, 0, 0, 1, 0, 0, 0, 0, 97, 120, 27, 127, 255, 255, 255,
    255, 255, 255, 255, 97, 121, 59, 127, 255, 255, 255, 255, 255, 255, 255, 97, 122,
    66, 1, 2, 98, 97, 97, 162, 100, 102, 117, 110, 99, 102, 115, 116, 114, 111, 110,
    103, 100, 98, 111, 100, 121, 162, 100, 102, 117, 110, 99, 100, 116, 101, 120, 116,
    100, 116, 101, 120, 116, 97, 97, 98, 97, 98, 99, 226, 134, 146, 98, 97, 99, 99,
    49, 112, 116, 98, 97, 100, 250, 127, 127, 255, 255, 98, 97, 101, 249, 4, 0, 98,
    97, 102, 251, 63, 240, 0, 0, 0, 0, 0, 1,
  ]
  let actual = @cbor.to_bytes(value).to_array().map(b => b.to_int())
  assert_eq(actual, expected)
}
