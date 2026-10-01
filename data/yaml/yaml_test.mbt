// Hand-written tests for the public API (expected values from the upstream
// Typst oracle).

///|
fn parse_err(input : Bytes) -> (String, @yaml.Location?) {
  try @yaml.parse(input) catch {
    @yaml.YamlError(message~, location~) => (message, location)
  } noraise {
    _ => abort("expected an error")
  }
}

///|
test "bad.yaml error message and location" {
  // tests/suite/loading/yaml.typ: yaml-invalid
  let (message, location) = parse_err(b"this_will_break: [)\n")
  assert_eq(
    message, "did not find expected ',' or ']' at line 2 column 1, while parsing a flow sequence at line 1 column 18",
  )
  assert_eq(location, Some({ index: 20, line: 2, column: 1, }))
}

///|
test "yaml-types.yaml" {
  let data = @yaml.parse(
    b"null_key: [null, ~]\n\"string\": text\ninteger: 5\nfloat: 1.12\nmapping: { '1': \"one\", '2': \"two\"}\nseq: [1, 2, 3, 4]\nbool: false\ntrue: bool\n1: ok\n",
  )
  assert_eq(
    data,
    Map([
      ("null_key", Seq([None, None])),
      ("string", Str("text")),
      ("integer", Int(5)),
      ("float", Float(1.12)),
      ("mapping", Map([("1", Str("one")), ("2", Str("two"))])),
      ("seq", Seq([Int(1), Int(2), Int(3), Int(4)])),
      ("bool", Bool(false)),
      ("true", Str("bool")),
      ("1", Str("ok")),
    ]),
  )
}

///|
test "large integers" {
  // tests/suite/loading/edge-case.typ
  assert_eq(@yaml.parse(b"9223372036854775807"), Int(9223372036854775807L))
  assert_eq(
    @yaml.parse(b"-9223372036854775808"),
    Int(-9223372036854775807L - 1L),
  )
  assert_eq(@yaml.parse(b"9223372036854775808"), Float(9223372036854775808.0))
  assert_eq(@yaml.parse(b"-9223372036854775809"), Float(-9223372036854775808.0))
  assert_eq(@yaml.parse(b"18446744073709551615"), Float(18446744073709551615.0))
  assert_eq(@yaml.parse(b"18446744073709551616"), Float(18446744073709551616.0))
  assert_eq(
    @yaml.parse(b"170141183460469231731687303715884105727"),
    Float(1.7014118346046923e38),
  )
  assert_eq(
    @yaml.parse(b"-170141183460469231731687303715884105728"),
    Float(-1.7014118346046923e38),
  )
  assert_eq(
    @yaml.parse(b"340282366920938463463374607431768211455"),
    Float(3.402823669209385e38),
  )
  // Larger than u128: not an integer, but a valid float.
  assert_eq(
    @yaml.parse(b"340282366920938463463374607431768211456"),
    Float(3.402823669209385e38),
  )
}

///|
test "duplicate keys are kept in document order" {
  assert_eq(
    @yaml.parse(b"a: 1\nb: 2\na: 3\n"),
    Map([("a", Int(1)), ("b", Int(2)), ("a", Int(3))]),
  )
}

///|
test "non-string scalar keys keep their source text" {
  assert_eq(
    @yaml.parse(b"1: a\ntrue: b\n~: c\n0x10: d\n'': e\n? \n: f\n!!int 2: g\n"),
    Map([
      ("1", Str("a")),
      ("true", Str("b")),
      ("~", Str("c")),
      ("0x10", Str("d")),
      ("", Str("e")),
      ("", Str("f")),
      ("2", Str("g")),
    ]),
  )
}

///|
test "error locations" {
  assert_eq(
    parse_err(b"[" + Bytes::make(200, b'[')),
    (
      "recursion limit exceeded at line 1 column 129",
      Some({ index: 128, line: 1, column: 129, }),
    ),
  )
  assert_eq(
    parse_err(b"a\n---\nb"),
    (
      "deserializing from YAML containing more than one document is not supported",
      None,
    ),
  )
  // Reader errors carry the zero mark.
  assert_eq(
    parse_err(b"abc: \xff"),
    (
      "invalid leading UTF-8 octet at position 5",
      Some({ index: 0, line: 1, column: 1, }),
    ),
  )
  // Byte (not character) indices.
  assert_eq(
    parse_err(@utf8.encode("é: [\n")),
    (
      "did not find expected node content at line 2 column 1, while parsing a flow node",
      Some({ index: 6, line: 2, column: 1, }),
    ),
  )
  assert_eq(
    parse_err(b"a:\n  b: !foo x\n"),
    (
      "a.b: invalid type: enum, expected a Typst value at line 2 column 6",
      Some({ index: 8, line: 2, column: 6, }),
    ),
  )
  assert_eq(
    parse_err(b"- *x"),
    (
      "unknown anchor at line 1 column 3",
      Some({ index: 2, line: 1, column: 3, }),
    ),
  )
}

///|
test "nesting depth" {
  let ok = Bytes::make(128, b'[') + Bytes::make(128, b']')
  let mut data = @yaml.parse(ok)
  let mut depth = 0
  while data is Seq(items) {
    depth += 1
    data = if items.is_empty() { None } else { items[0] }
  }
  assert_eq(depth, 128)
}

///|
test "encode bytes is unsupported" {
  assert_eq(
    show_encode(Bytes(b"ab")),
    "err:serialization and deserialization of bytes in YAML is not implemented",
  )
  assert_eq(
    show_encode(Seq([Int(1), Bytes(b"ab")])),
    "err:serialization and deserialization of bytes in YAML is not implemented",
  )
}

///|
test "encode basics" {
  assert_eq(
    @yaml.to_string(
      Map([
        ("a", Int(1)),
        ("b", Seq([Float(1.5), Str("x: y"), None])),
        ("c", Map([])),
      ]),
    ),
    "a: 1\nb:\n- 1.5\n- 'x: y'\n- null\nc: {}\n",
  )
}

///|
/// `n` repetitions of the ASCII byte `b`.
fn rep(b : Byte, n : Int) -> Bytes {
  Bytes::make(n, b)
}

///|
test "reader validates input in 16 KiB chunks" {
  // The invalid byte lies in the second chunk, so the type error of the
  // first element surfaces first.
  assert_eq(
    show_parse(b"- !foo x\n- y\n" + rep(b'#', 17000) + b"\n\xff"),
    "err:.[0]: invalid type: enum, expected a Typst value at line 1 column 3 at 1:3",
  )
  // Within the first chunk, the reader error comes first.
  assert_eq(
    show_parse(b"- !foo x\n- y\n" + rep(b'#', 100) + b"\n\xff"),
    "err:invalid leading UTF-8 octet at position 114 at 1:1",
  )
  assert_eq(
    show_parse(b"- y\n" + rep(b'#', 17000) + b"\n\xff"),
    "err:invalid leading UTF-8 octet at position 17005 at 1:1",
  )
  assert_eq(
    show_parse(b"a: " + rep(b'x', 16381) + b"\xc3"),
    "err:incomplete UTF-8 octet sequence at position 16384 at 1:1",
  )
  assert_eq(
    show_parse(b"- 1\n- 2\n- " + rep(b'z', 17000) + b"\n- [\n"),
    "err:did not find expected node content at line 5 column 1, while parsing a flow node at 5:1",
  )
  assert_eq(
    show_parse(b"a\n---\n" + rep(b'#', 17000) + b"\n\xff"),
    "err:deserializing from YAML containing more than one document is not supported",
  )
  // Multi-byte characters straddling a chunk boundary.
  let tail = @utf8.encode("\u{e9}\u{4e2d}\u{e9}")
  assert_eq(
    @yaml.parse(b"a: " + rep(b'x', 16380) + tail + b"\nb: 1"),
    Map([
      ("a", Str(String::make(16380, 'x') + "\u{e9}\u{4e2d}\u{e9}")),
      ("b", Int(1)),
    ]),
  )
}
