// LEB128 and other `BinaryReader` edge cases (behavior and messages of
// wasmparser 0.228.0's `binary_reader.rs`).

///|
fn reader(bytes : Bytes) -> @wasmparser.BinaryReader {
  @wasmparser.BinaryReader::new(bytes[:], 0)
}

///|
fn err_string(f : () -> Unit raise @wasmparser.BinaryReaderError) -> String {
  try f() catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
}

///|
test "read_var_u32" {
  assert_eq(reader(b"\x00").read_var_u32(), 0)
  assert_eq(reader(b"\x7f").read_var_u32(), 127)
  assert_eq(reader(b"\x80\x01").read_var_u32(), 128)
  assert_eq(reader(b"\xff\xff\xff\xff\x0f").read_var_u32(), 0xFFFF_FFFF)
  // Non-canonical but in range.
  assert_eq(reader(b"\x80\x80\x80\x80\x00").read_var_u32(), 0)
  assert_eq(
    err_string(() => reader(b"\xff\xff\xff\xff\x1f").read_var_u32() |> ignore),
    "invalid var_u32: integer too large (at offset 0x4)",
  )
  assert_eq(
    err_string(() => {
      reader(b"\x80\x80\x80\x80\x80\x00").read_var_u32() |> ignore
    }),
    "invalid var_u32: integer representation too long (at offset 0x4)",
  )
  assert_eq(
    err_string(() => reader(b"\x80\x80").read_var_u32() |> ignore),
    "unexpected end-of-file (at offset 0x2)",
  )
}

///|
test "read_var_i32" {
  assert_eq(reader(b"\x7f").read_var_i32(), -1)
  assert_eq(reader(b"\x3f").read_var_i32(), 63)
  assert_eq(reader(b"\x40").read_var_i32(), -64)
  assert_eq(reader(b"\x80\x7f").read_var_i32(), -128)
  assert_eq(reader(b"\xff\xff\xff\xff\x07").read_var_i32(), 0x7FFF_FFFF)
  assert_eq(reader(b"\x80\x80\x80\x80\x78").read_var_i32(), -0x8000_0000)
  assert_eq(
    err_string(() => reader(b"\xff\xff\xff\xff\x0f").read_var_i32() |> ignore),
    "invalid var_i32: integer too large (at offset 0x4)",
  )
  assert_eq(
    err_string(() => {
      reader(b"\x80\x80\x80\x80\x80\x00").read_var_i32() |> ignore
    }),
    "invalid var_i32: integer representation too long (at offset 0x4)",
  )
}

///|
test "read_var_i64" {
  assert_eq(reader(b"\x7f").read_var_i64(), -1L)
  assert_eq(
    reader(b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00").read_var_i64(),
    0x7FFF_FFFF_FFFF_FFFFL,
  )
  assert_eq(
    reader(b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x7f").read_var_i64(),
    -0x7FFF_FFFF_FFFF_FFFFL - 1L,
  )
  assert_eq(
    err_string(() => {
      reader(b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01").read_var_i64()
      |> ignore
    }),
    "invalid var_i64: integer too large (at offset 0x9)",
  )
  assert_eq(
    err_string(() => {
      reader(b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x00").read_var_i64()
      |> ignore
    }),
    "invalid var_i64: integer representation too long (at offset 0x9)",
  )
}

///|
test "read_var_u64" {
  assert_eq(
    reader(b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01").read_var_u64(),
    0xFFFF_FFFF_FFFF_FFFFUL,
  )
  assert_eq(
    err_string(() => {
      reader(b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\x02").read_var_u64()
      |> ignore
    }),
    "invalid var_u64: integer too large (at offset 0x9)",
  )
}

///|
test "read_var_s33" {
  assert_eq(reader(b"\x7f").read_var_s33(), -1L)
  assert_eq(reader(b"\x40").read_var_s33(), -64L)
  assert_eq(reader(b"\x3f").read_var_s33(), 63L)
  assert_eq(reader(b"\xff\xff\xff\xff\x0f").read_var_s33(), 0xFFFF_FFFFL)
  // The 5-byte form is not sign-extended (like upstream).
  assert_eq(reader(b"\xff\xff\xff\xff\x7f").read_var_s33(), 0x7_FFFF_FFFFL)
  assert_eq(
    err_string(() => reader(b"\xff\xff\xff\xff\x1f").read_var_s33() |> ignore),
    "invalid var_s33: integer representation too long (at offset 0x4)",
  )
}

///|
test "read_string" {
  assert_eq(reader(b"\x03abc").read_string(), "abc")
  assert_eq(reader(b"\x04\xf0\x9f\x98\x80").read_string(), "\u{1F600}")
  // Overlong encoding of '/', surrogates and truncated sequences are
  // rejected like `str::from_utf8`.
  for
    bad in [b"\x02\xc0\xaf", b"\x03\xed\xa0\x80", b"\x02\xe2\x82", b"\x01\xff"] {
    assert_eq(
      err_string(() => reader(bad).read_string() |> ignore),
      "malformed UTF-8 encoding (at offset \{"0x" + (bad.length() - 1).to_string(radix=16)})",
    )
  }
  assert_eq(
    err_string(() => reader(b"\x05ab").read_string() |> ignore),
    "unexpected end-of-file (at offset 0x1)",
  )
}

///|
test "read_operator" {
  let r = reader(b"\x41\x7f\x0e\x02\x01\x02\x00\x0b")
  assert_eq(r.read_operator(), I32Const(value=-1))
  match r.read_operator() {
    BrTable(targets~) => {
      assert_eq(targets.targets().to_owned(), [1, 2])
      assert_eq(targets.default(), 0)
    }
    _ => fail("expected br_table")
  }
  assert_eq(r.read_operator(), End)
  assert_true(r.eof())
  assert_eq(
    err_string(() => reader(b"\xff").read_operator() |> ignore),
    "illegal opcode: 0xff (at offset 0x0)",
  )
  assert_eq(
    err_string(() => reader(b"\xfd\xff\x03").read_operator() |> ignore),
    "unknown 0xfd subopcode: 0x1ff (at offset 0x0)",
  )
}
