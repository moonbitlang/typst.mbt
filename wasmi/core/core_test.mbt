// Ports of upstream's unit tests (and checks of the APIs the oracle does not
// exercise).

///|
test "wasm_float_min_regression_works" {
  inspect(@core.f32_min(-0.0, 0.0).reinterpret_as_uint(), content="2147483648")
  inspect(@core.f32_min(0.0, -0.0).reinterpret_as_uint(), content="2147483648")
}

///|
test "wasm_float_max_regression_works" {
  inspect(@core.f32_max(-0.0, 0.0).reinterpret_as_uint(), content="0")
  inspect(@core.f32_max(0.0, -0.0).reinterpret_as_uint(), content="0")
}

///|
test "copysign_regression_works" {
  let nan = Float::reinterpret_from_uint(0xFFC00000)
  assert_true(nan.is_nan())
  inspect(
    @core.f32_copysign(nan, Float::reinterpret_from_uint(0)).reinterpret_as_uint(),
    content="2143289344",
  )
}

///|
test "simd" {
  assert_eq(
    @core.i32x4_dot_i16x8_s(@core.i16x8_splat(16383), @core.i16x8_splat(16384)),
    @core.i32x4_splat(536838144),
  )
  assert_eq(
    @core.v128_or(@core.i16x8_splat(0), @core.i16x8_splat(0xffff)),
    @core.i16x8_splat(0xffff),
  )
  assert_eq(
    @core.i8x16_narrow_i16x8_s(@core.i16x8_splat(0x80), @core.i16x8_splat(0x80)),
    @core.i8x16_splat(0x7f),
  )
}

///|
test "trap_code_conversion" {
  for i in 0..<11 {
    let code = @core.TrapCode::try_from_u8(i.to_byte())
    assert_eq(code.to_u8(), i.to_byte())
  }
  try @core.TrapCode::try_from_u8(255) catch {
    _ => ()
  } noraise {
    _ => fail("expected an invalid trap code")
  }
}

///|
fn memory_type(minimum : UInt, maximum : UInt?) -> @core.MemoryType {
  let b = @core.MemoryType::builder()
  b.min(minimum.to_uint64()) |> ignore
  b.max(maximum.map(UInt::to_uint64)) |> ignore
  b.build() catch {
    _ => abort("invalid memory type")
  }
}

///|
test "memory subtyping_works" {
  assert_true(memory_type(0, Some(1)).is_subtype_of(memory_type(0, Some(1))))
  assert_true(memory_type(0, Some(1)).is_subtype_of(memory_type(0, Some(2))))
  assert_true(!memory_type(0, Some(2)).is_subtype_of(memory_type(0, Some(1))))
  assert_true(memory_type(2, None).is_subtype_of(memory_type(1, None)))
  assert_true(memory_type(0, None).is_subtype_of(memory_type(0, None)))
  assert_true(memory_type(0, Some(1)).is_subtype_of(memory_type(0, None)))
  assert_true(!memory_type(0, None).is_subtype_of(memory_type(0, Some(1))))
}

///|
test "table subtyping_works" {
  let t = (e, min, max) => @core.TableType::new(e, min, max)
  assert_true(!t(I32, 0, Some(1)).is_subtype_of(t(F64, 0, Some(1))))
  assert_true(t(I32, 0, Some(1)).is_subtype_of(t(I32, 0, Some(1))))
  assert_true(t(I32, 0, Some(1)).is_subtype_of(t(I32, 0, Some(2))))
  assert_true(!t(I32, 0, Some(2)).is_subtype_of(t(I32, 0, Some(1))))
  assert_true(t(I32, 2, None).is_subtype_of(t(I32, 1, None)))
  assert_true(t(I32, 0, None).is_subtype_of(t(I32, 0, None)))
  assert_true(t(I32, 0, Some(1)).is_subtype_of(t(I32, 0, None)))
  assert_true(!t(I32, 0, None).is_subtype_of(t(I32, 0, Some(1))))
}

///|
test "func_type new_big_works" {
  let params = Array::make(100, @core.ValType::I32)
  let results = Array::make(100, @core.ValType::I64)
  let ft = @core.FuncType::new(params, results)
  assert_eq(ft.params().to_owned(), params)
  assert_eq(ft.results().to_owned(), results)
  assert_eq(ft.len_params(), 100)
  assert_eq(ft.len_results(), 100)
}

///|
test "memory static buffer and growth" {
  let buffer = FixedArray::make(4, (7 : Byte))
  let b = @core.MemoryType::builder()
  b.page_size_log2(0) |> ignore
  b.min(2) |> ignore
  let ty = b.build()
  let mem = @core.Memory::new_static(
    ty,
    @core.ResourceLimiterRef::default(),
    buffer,
  )
  inspect(mem.data_size(), content="2")
  inspect(buffer[0], content="b'\\x00'")
  inspect(buffer[2], content="b'\\x07'")
  inspect(mem.grow(2, None, @core.ResourceLimiterRef::default()), content="2")
  inspect(buffer[3], content="b'\\x00'")
  let err = try mem.grow(1, None, @core.ResourceLimiterRef::default()) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(err, content="tried to use too small static buffer")
  // Vector-backed memories keep their contents when reallocating.
  let mem = @core.Memory::new(ty, @core.ResourceLimiterRef::default())
  mem.write(0, b"\x01\x02"[:])
  for _ in 0..<20 {
    mem.grow(3, None, @core.ResourceLimiterRef::default()) |> ignore
  }
  inspect(mem.data_size(), content="62")
  inspect(@core.load32(mem.data(), mem.data_size(), 0, 0), content="513")
  try @core.load32(mem.data(), mem.data_size(), 59, 0) catch {
    e => inspect(e, content="out of bounds memory access")
  } noraise {
    _ => fail("expected a trap")
  }
}

///|
test "untyped and typed values" {
  let v = @core.UntypedVal::from_v128(@core.V128Value::from_lo_hi(1, 2))
  // Scalar writes keep the high bits (`write_lo64`), `from_*` clears them.
  inspect(v.write_i32(-1).hi64(), content="2")
  inspect(v.write_i32(-1).to_bits64(), content="4294967295")
  inspect(@core.UntypedVal::from_i32(-1).to_bits64(), content="4294967295")
  inspect(@core.UntypedVal::from_i8(-1).to_bits64(), content="255")
  inspect(@core.UntypedVal::from_i64(-1).read_i8(), content="-1")
  inspect(@core.UntypedVal::from_i64(-1).read_u16(), content="65535")
  let t = @core.TypedVal::from_f32(1.5)
  inspect(t.ty(), content="F32")
  inspect(t.to_f32(), content="1.5")
  let g = @core.Global::new(@core.TypedVal::from_i32(5), Const)
  let err = try g.set(@core.TypedVal::from_i32(6)) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(err, content="tried to write to immutable global variable")
  let g = @core.Global::new(@core.TypedVal::from_i32(5), Var)
  g.set(@core.TypedVal::from_i32(6))
  inspect(g.get().to_i32(), content="6")
}
