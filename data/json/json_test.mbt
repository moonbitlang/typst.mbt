// Expected outputs were produced by upstream Typst (serde_json 1.0.151).

///|
fn parse_err(input : String) -> String {
  try @json.from_slice(@utf8.encode(input)) catch {
    err => err.message()
  } noraise {
    _ => "ok"
  }
}

///|
fn parse_ok(input : String) -> @serde.Data {
  @json.from_slice(@utf8.encode(input)) catch {
    err => abort(err.message())
  }
}

///|
test "errors" {
  inspect(parse_err("[1, 2,]"), content="trailing comma at line 1 column 7")
  inspect(parse_err("{\"a\": 1,}"), content="trailing comma at line 1 column 9")
  inspect(parse_err("[1 2]"), content="expected `,` or `]` at line 1 column 4")
  inspect(parse_err("{\"a\" 1}"), content="expected `:` at line 1 column 6")
  inspect(
    parse_err("{1: 2}"),
    content="key must be a string at line 1 column 2",
  )
  inspect(
    parse_err("nul"),
    content="EOF while parsing a value at line 1 column 3",
  )
  inspect(parse_err("nulx"), content="expected ident at line 1 column 4")
  inspect(
    parse_err("\"abc"),
    content="EOF while parsing a string at line 1 column 4",
  )
  inspect(parse_err("01"), content="invalid number at line 1 column 2")
  inspect(
    parse_err("1."),
    content="EOF while parsing a value at line 1 column 2",
  )
  inspect(parse_err("1.x"), content="invalid number at line 1 column 3")
  inspect(
    parse_err("1e"),
    content="EOF while parsing a value at line 1 column 2",
  )
  inspect(parse_err("1ex"), content="invalid number at line 1 column 3")
  inspect(parse_err("1e400"), content="number out of range at line 1 column 5")
  inspect(parse_err("\"\\x\""), content="invalid escape at line 1 column 3")
  inspect(
    parse_err("\"\\ud800\""),
    content="unexpected end of hex escape at line 1 column 8",
  )
  inspect(
    parse_err("\"\\udc00\""),
    content="lone leading surrogate in hex escape at line 1 column 7",
  )
  inspect(
    parse_err("\"\\ud800\\u0041\""),
    content="lone leading surrogate in hex escape at line 1 column 13",
  )
  inspect(
    parse_err("\"\\u12\""),
    content="EOF while parsing a string at line 1 column 6",
  )
  inspect(parse_err("\"\\u12zz\""), content="invalid escape at line 1 column 7")
  inspect(
    parse_err("\"a\tb\""),
    content="control character (\\u0000-\\u001F) found while parsing a string at line 1 column 3",
  )
  inspect(
    parse_err("[1]\n x"),
    content="trailing characters at line 2 column 2",
  )
  inspect(parse_err(""), content="EOF while parsing a value at line 1 column 0")
  inspect(
    parse_err("   "),
    content="EOF while parsing a value at line 1 column 3",
  )
  inspect(
    parse_err("[1, 2"),
    content="EOF while parsing a list at line 1 column 5",
  )
  inspect(
    parse_err("{\"a\": 1"),
    content="EOF while parsing an object at line 1 column 7",
  )
  inspect(
    parse_err("{\"a\""),
    content="EOF while parsing an object at line 1 column 4",
  )
  inspect(
    parse_err("[".repeat(200)),
    content="recursion limit exceeded at line 1 column 128",
  )
  inspect(
    parse_err("-"),
    content="EOF while parsing a value at line 1 column 1",
  )
  inspect(parse_err("-a"), content="invalid number at line 1 column 2")
  inspect(parse_err("[1,\n  ]"), content="trailing comma at line 2 column 3")
  inspect(
    parse_err("{\"a\":1 \"b\":2}"),
    content="expected `,` or `}` at line 1 column 8",
  )
  inspect(
    parse_err("{\"a\":1,"),
    content="EOF while parsing a value at line 1 column 7",
  )
  inspect(
    parse_err("[1,"),
    content="EOF while parsing a value at line 1 column 3",
  )
  inspect(
    parse_err("\"\\ud800x\""),
    content="unexpected end of hex escape at line 1 column 8",
  )
  inspect(
    parse_err("\"\\ud800\\x\""),
    content="unexpected end of hex escape at line 1 column 9",
  )
  inspect(parse_err("é"), content="expected value at line 1 column 1")
  inspect(parse_err("[\"é\", x]"), content="expected value at line 1 column 8")
  inspect(
    parse_err("1e2147483648"),
    content="number out of range at line 1 column 12",
  )
  inspect(
    parse_err("[0.3, 1e400e]"),
    content="number out of range at line 1 column 11",
  )
}

///|
test "invalid utf-8" {
  let err = try @json.from_slice(b"\"\xff\"") catch {
    err => err.message()
  } noraise {
    _ => "ok"
  }
  inspect(err, content="invalid unicode code point at line 1 column 3")
}

///|
test "numbers" {
  let v = parse_ok(
    "[0.3, 1.0000000000000002, 9007199254740993.0, 123456789012345678901234567890e-10, 1.7976931348623157e308, 18446744073709551615, 18446744073709551616, -9223372036854775808, -9223372036854775809, -0, 0.0, 2.2250738585072014e-308, 5e-324, 1e-400, 0.1e1, 1E2, 1e+2, 123.456e-2, 0e2147483648, 1e-2147483648]",
  )
  guard v is Seq(items) else { fail("expected seq") }
  let out = items.map(item => {
    match item {
      Int(i) => "int \{i}"
      Float(f) => "float \{@serde.format_debug(f)}"
      _ => "other"
    }
  })
  debug_inspect(
    out,
    content=(
      #|[
      #|  "float 0.3",
      #|  "float 1.0000000000000002",
      #|  "float 9007199254740994.0",
      #|  "float 1.2345678901234567e19",
      #|  "float 1.7976931348623157e308",
      #|  "float 1.8446744073709552e19",
      #|  "float 1.8446744073709552e19",
      #|  "int -9223372036854775808",
      #|  "float -9.223372036854776e18",
      #|  "float -0.0",
      #|  "float 0.0",
      #|  "float 2.2250738585072014e-308",
      #|  "float 5e-324",
      #|  "float 0.0",
      #|  "float 1.0",
      #|  "float 100.0",
      #|  "float 100.0",
      #|  "float 1.23456",
      #|  "float 0.0",
      #|  "float 0.0",
      #|]
    ),
  )
}

///|
test "values" {
  let v = parse_ok(
    "{\"a\": \"x\\u00e9\\ud83d\\ude00\\n\\/\", \"a\": 2, \"b\": [true, false, null, {}]}",
  )
  debug_inspect(
    v,
    content=(
      #|Map(
      #|  [
      #|    ("a", Str("xé😀\n/")),
      #|    ("a", Int(2)),
      #|    ("b", Seq([Bool(true), Bool(false), None, Map([])])),
      #|  ],
      #|)
    ),
  )
}

///|
test "encode" {
  let value : @serde.Data = Map([
    ("a", Int(1)),
    ("b", Seq([Float(1.5), Str("x\"y\\z\n\u{1}\u{7f}é"), None, Bool(true)])),
    ("c", Map([])),
    ("d", Seq([])),
    ("e", Float(1.0e20)),
    ("f", Float(1.0e16)),
    ("g", Float(0.1)),
    ("h", Float(@double.not_a_number)),
    ("i", Float(@double.neg_infinity)),
    ("j", Float(1.0)),
    ("k", Float(-0.0)),
    ("p", Map([("x", Seq([Seq([])]))])),
  ])
  inspect(
    @json.to_string(value, pretty=false),
    content=(
      #|{"a":1,"b":[1.5,"x\"y\\z\n\u0001é",null,true],"c":{},"d":[],"e":1e+20,"f":1e+16,"g":0.1,"h":null,"i":null,"j":1.0,"k":-0.0,"p":{"x":[[]]}}
    ),
  )
  let value : @serde.Data = Map([
    ("a", Int(1)),
    ("b", Seq([Float(1.5), Str("x"), None, Bool(true)])),
    ("c", Map([])),
    ("d", Seq([])),
    (
      "p",
      Map([("x", Seq([Seq([])])), ("y", Map([("z", Seq([Int(1), Int(2)]))]))]),
    ),
  ])
  inspect(
    @json.to_string(value, pretty=true),
    content=(
      #|{
      #|  "a": 1,
      #|  "b": [
      #|    1.5,
      #|    "x",
      #|    null,
      #|    true
      #|  ],
      #|  "c": {},
      #|  "d": [],
      #|  "p": {
      #|    "x": [
      #|      []
      #|    ],
      #|    "y": {
      #|      "z": [
      #|        1,
      #|        2
      #|      ]
      #|    }
      #|  }
      #|}
    ),
  )
}
