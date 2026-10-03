// Validation of hand-written modules; the expected outcomes are those of
// wasmparser 0.228.0 driven like wasmi (`oracle/src/bin/gen_wasmparser_tests.rs`).

///|
fn wasmi_test_features() -> WasmFeatures {
  WasmFeatures::empty()
  .set(MUTABLE_GLOBAL, true)
  .set(MULTI_VALUE, true)
  .set(MULTI_MEMORY, true)
  .set(SATURATING_FLOAT_TO_INT, true)
  .set(SIGN_EXTENSION, true)
  .set(BULK_MEMORY, true)
  .set(REFERENCE_TYPES, true)
  .set(GC_TYPES, true)
  .set(TAIL_CALL, true)
  .set(EXTENDED_CONST, true)
  .set(FLOATS, true)
  .set(MEMORY64, true)
  .set(SIMD, true)
}

///|
fn validate_outcome(bytes : Bytes) -> String {
  let validator = Validator::new_with_features(wasmi_test_features())
  match (try? validator.validate_all(bytes[:])) {
    Ok(_) => "ok"
    Err(e) => e.to_string()
  }
}

///|
test "validate add" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x0a\x09\x01\x07\x00\x20\x00\x41\x01\x6a\x0b",
    ),
    "ok",
  )
}

///|
test "validate align" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x05\x03\x01\x00\x01\x0a\x0a\x01\x08\x00\x41\x00\x28\x03\x00\x1a\x0b",
    ),
    "malformed memop alignment: alignment must not be larger than natural (at offset 0x1e)",
  )
}

///|
test "validate bad_magic" {
  assert_eq(
    validate_outcome(b"\x00\x61\x73\x6e\x01\x00\x00\x00"),
    "magic header not detected: bad magic number - expected=[\n    0x0,\n    0x61,\n    0x73,\n    0x6d,\n] actual=[\n    0x0,\n    0x61,\n    0x73,\n    0x6e,\n] (at offset 0x0)",
  )
}

///|
test "validate bad_utf8" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x07\x06\x01\x02\xc3\x28\x00\x00\x0a\x04\x01\x02\x00\x0b",
    ),
    "malformed UTF-8 encoding (at offset 0x17)",
  )
}

///|
test "validate br_table" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x0e\x01\x0c\x00\x02\x40\x41\x00\x0e\x02\x00\x00\x00\x0b\x0b",
    ),
    "ok",
  )
}

///|
test "validate component" {
  assert_eq(
    validate_outcome(b"\x00\x61\x73\x6d\x0d\x00\x01\x00"),
    "unknown binary version and encoding combination: 0xd and 0x1, note: encoded as a component but the WebAssembly component model feature is not enabled - enable the feature to allow component validation (at offset 0x0)",
  )
}

///|
test "validate custom" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x00\x08\x04\x6e\x61\x6d\x65\x00\x01\x02",
    ),
    "ok",
  )
}

///|
test "validate data_count" {
  // `validate_all` reports the real offset of the end of the module; the
  // wasmi driver of the oracle reports 0x2b because wasmi re-parses the data
  // section payload that ends its header phase (see `wasm_validate_stage`).
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x05\x03\x01\x00\x01\x0c\x01\x02\x0b\x07\x01\x00\x41\x00\x0b\x01\x78",
    ),
    "data count and data section have inconsistent lengths (at offset 0x19)",
  )
}

///|
test "validate dup_export" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x07\x09\x02\x01\x61\x00\x00\x01\x61\x00\x00\x0a\x04\x01\x02\x00\x0b",
    ),
    "duplicate export name `a` already defined (at offset 0x19)",
  )
}

///|
test "validate empty" {
  assert_eq(validate_outcome(b"\x00\x61\x73\x6d\x01\x00\x00\x00"), "ok")
}

///|
test "validate global_const" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x06\x0b\x02\x7f\x01\x41\x00\x0b\x7f\x00\x23\x00\x0b",
    ),
    "constant expression required: global.get of locally defined global (at offset 0x12)",
  )
}

///|
test "validate leb_large" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x06\xff\xff\xff\xff\x1f\x00",
    ),
    "invalid var_u32: integer too large (at offset 0x14)",
  )
}

///|
test "validate leb_long" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x07\x81\x80\x80\x80\x80\x00\x00",
    ),
    "invalid var_u32: integer representation too long (at offset 0x14)",
  )
}

///|
test "validate locals" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x08\x01\x06\x01\xd1\x86\x03\x7f\x0b",
    ),
    "too many locals: locals exceed maximum (at offset 0x17)",
  )
}

///|
test "validate no_end" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x0a\x05\x01\x03\x00\x20\x00",
    ),
    "control frames remain at end of function: END opcode expected (at offset 0x1b)",
  )
}

///|
test "validate order" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x03\x02\x01\x00\x01\x04\x01\x60\x00\x00",
    ),
    "unknown type 0: type index out of bounds (at offset 0xb)",
  )
}

///|
test "validate relaxed" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x2c\x01\x2a\x00\xfd\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfd\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfd\x80\x02\x1a\x0b",
    ),
    "relaxed SIMD support is not enabled (at offset 0x3b)",
  )
}

///|
test "validate select_arity" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x08\x01\x06\x00\x1c\x02\x7f\x7f\x0b",
    ),
    "invalid result arity (at offset 0x3)",
  )
}

///|
test "validate shuffle_lane" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x3b\x01\x39\x00\xfd\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfd\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfd\x0d\x20\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x1a\x0b",
    ),
    "invalid lane index (at offset 0x3d)",
  )
}

///|
test "validate shuffle_ok" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x0a\x3b\x01\x39\x00\xfd\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfd\x0c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfd\x0d\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x1a\x0b",
    ),
    "ok",
  )
}

///|
test "validate threads" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x05\x03\x01\x00\x01\x0a\x0d\x01\x0b\x00\x41\x00\x41\x00\xfe\x00\x02\x00\x1a\x0b",
    ),
    "threads support is not enabled (at offset 0x20)",
  )
}

///|
test "validate truncated_header" {
  assert_eq(
    validate_outcome(b"\x00\x61\x73\x6d\x01\x00"),
    "unexpected end-of-file (at offset 0x4)",
  )
}

///|
test "validate type_mismatch" {
  assert_eq(
    validate_outcome(
      b"\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7f\x01\x7f\x03\x02\x01\x00\x0a\x0c\x01\x0a\x00\x20\x00\x43\x00\x00\x80\x3f\x6a\x0b",
    ),
    "type mismatch: expected i32, found f32 (at offset 0x20)",
  )
}

///|
test "validate unknown_section" {
  assert_eq(
    validate_outcome(b"\x00\x61\x73\x6d\x01\x00\x00\x00\x0e\x00"),
    "malformed section id: 14 (at offset 0xa)",
  )
}

///|
test "validate version2" {
  assert_eq(
    validate_outcome(b"\x00\x61\x73\x6d\x02\x00\x00\x00"),
    "unknown binary version: 0x2 (at offset 0x0)",
  )
}
