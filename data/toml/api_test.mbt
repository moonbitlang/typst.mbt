///|
test "parse: data shape" {
  let v = @toml.parse(
    (
      #|a = 1
      #|b = [1.5, "x", true]
      #|c = 1979-05-27T07:32:00Z
      #|[t]
      #|u = {v = 2}
      #|[[aot]]
      #|[[aot]]
      #|w = -inf
    ),
  )
  let expected : @serde.Data = Map([
    ("a", Int(1L)),
    ("b", Seq([Float(1.5), Str("x"), Bool(true)])),
    ("c", Map([(@serde.toml_datetime_field, Str("1979-05-27T07:32:00Z"))])),
    ("t", Map([("u", Map([("v", Int(2L))]))])),
    ("aot", Seq([Map([]), Map([("w", Float(@double.neg_infinity))])])),
  ])
  assert_eq(v, expected)
}

///|
test "parse: error type" {
  let err = try @toml.parse("3") catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  assert_true(
    err is @toml.TomlError(message="expected `.`, `=`", span=Some((1, 1))),
  )
}

///|
test "parse: datetime display" {
  // `toml_datetime::Datetime` `Display`: `T` separator, uppercase `Z`,
  // fractional seconds trimmed of trailing zeros (and truncated to
  // nanoseconds), offsets as `+HH:MM` (`-00:00` becomes `+00:00`).
  check_parse(
    "a = 1979-05-27t07:32:00.120z\nb = 1979-05-27 07:32:00.000-00:00\nc = 07:32:00.1234567891\nd = 2000-02-29",
    "ok {\"a\": D(1979-05-27T07:32:00.12Z), \"b\": D(1979-05-27T07:32:00+00:00), \"c\": D(07:32:00.123456789), \"d\": D(2000-02-29)}",
  )
}

///|
test "parse: nan sign" {
  guard @toml.parse("a = nan\nb = -nan")
    is Map([("a", Float(a)), ("b", Float(b))]) else {
    fail("unexpected shape")
  }
  assert_true(a.is_nan() && b.is_nan())
  assert_eq(a.reinterpret_as_uint64() >> 63, 0UL)
  assert_eq(b.reinterpret_as_uint64() >> 63, 1UL)
}

///|
test "to_string: non-table roots and bytes" {
  // `write_document` requires the root to become a table.
  check_ser(Int(3L), true, "ERR unsupported rust type")
  check_ser(Str("x"), false, "ERR unsupported rust type")
  check_ser(Seq([Int(1L)]), false, "ERR unsupported rust type")
  check_ser(Seq([None]), false, "ERR unsupported None value")
  check_ser(None, false, "ERR unsupported None value")
  // `serialize_bytes` serializes a sequence of `u8`s.
  check_ser(Map([("b", Bytes(b"\x01\xff"))]), false, "b = [1, 255]\n")
  // A NaN loses its sign.
  check_ser(
    Map([("n", Float(-@double.not_a_number.abs()))]),
    false,
    "n = nan\n",
  )
}
