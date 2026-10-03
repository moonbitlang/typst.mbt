// Port of wasmi 1.0.9 `engine/executor/instrs/binary.rs`.

// ---------------------------------------------------------------------------
// DivRemExt: optimized divide and remainder implementations for immutable
// non-zero `rhs` values (`NonZeroI32`/`NonZeroU32`/... carried as plain
// integers; the translator guarantees that they are non-zero).

///|
/// Optimized variant of Wasm `i32.div_s` for immutable non-zero `rhs` values.
fn i32_div_s_nonzero(lhs : Int, rhs : Int) -> Int raise WasmiError {
  // `checked_div` with a non-zero `rhs` only fails on overflow.
  if lhs == -2147483647 - 1 && rhs == -1 {
    raise WasmiError::TrapCode(IntegerOverflow)
  }
  lhs / rhs
}

///|
/// Optimized variant of Wasm `i32.div_u` for immutable non-zero `rhs` values.
fn i32_div_u_nonzero(lhs : Int, rhs : UInt) -> Int {
  (lhs.reinterpret_as_uint() / rhs).reinterpret_as_int()
}

///|
/// Optimized variant of Wasm `i32.rem_s` for immutable non-zero `rhs` values.
fn i32_rem_s_nonzero(lhs : Int, rhs : Int) -> Int raise WasmiError {
  @wasmi_core.i32_rem_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
}

///|
/// Optimized variant of Wasm `i32.rem_u` for immutable non-zero `rhs` values.
fn i32_rem_u_nonzero(lhs : Int, rhs : UInt) -> Int {
  (lhs.reinterpret_as_uint() % rhs).reinterpret_as_int()
}

///|
/// Optimized variant of Wasm `i64.div_s` for immutable non-zero `rhs` values.
fn i64_div_s_nonzero(lhs : Int64, rhs : Int64) -> Int64 raise WasmiError {
  // `checked_div` with a non-zero `rhs` only fails on overflow.
  if lhs == -9223372036854775807L - 1L && rhs == -1L {
    raise WasmiError::TrapCode(IntegerOverflow)
  }
  lhs / rhs
}

///|
/// Optimized variant of Wasm `i64.div_u` for immutable non-zero `rhs` values.
fn i64_div_u_nonzero(lhs : Int64, rhs : UInt64) -> Int64 {
  (lhs.reinterpret_as_uint64() / rhs).reinterpret_as_int64()
}

///|
/// Optimized variant of Wasm `i64.rem_s` for immutable non-zero `rhs` values.
fn i64_rem_s_nonzero(lhs : Int64, rhs : Int64) -> Int64 raise WasmiError {
  @wasmi_core.i64_rem_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
}

///|
/// Optimized variant of Wasm `i64.rem_u` for immutable non-zero `rhs` values.
fn i64_rem_u_nonzero(lhs : Int64, rhs : UInt64) -> Int64 {
  (lhs.reinterpret_as_uint64() % rhs).reinterpret_as_int64()
}

///|
/// Executes an [`Op::F32CopysignImm`].
fn Executor::execute_f32_copysign_imm(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Sign,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = rhs.to_f32()
  self.set_stack_slot_as_f32(result, @wasmi_core.f32_copysign(lhs, rhs))
  self.next_instr()
}

///|
/// Executes an [`Op::F64CopysignImm`].
fn Executor::execute_f64_copysign_imm(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Sign,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = rhs.to_f64()
  self.set_stack_slot_as_f64(result, @wasmi_core.f64_copysign(lhs, rhs))
  self.next_instr()
}

// ---------------------------------------------------------------------------
// Macro-generated executors.

///|
/// Executes an [`Op::I32Add`].
fn Executor::execute_i32_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_add(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Sub`].
fn Executor::execute_i32_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_sub(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Mul`].
fn Executor::execute_i32_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_mul(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32BitAnd`].
fn Executor::execute_i32_bitand(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_bitand(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32BitOr`].
fn Executor::execute_i32_bitor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_bitor(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32BitXor`].
fn Executor::execute_i32_bitxor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_bitxor(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32And`].
fn Executor::execute_i32_and(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = i32_and(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Or`].
fn Executor::execute_i32_or(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = i32_or(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Nand`].
fn Executor::execute_i32_nand(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = i32_nand(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Nor`].
fn Executor::execute_i32_nor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = i32_nor(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Add`].
fn Executor::execute_i64_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_add(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Sub`].
fn Executor::execute_i64_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_sub(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Mul`].
fn Executor::execute_i64_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_mul(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64BitAnd`].
fn Executor::execute_i64_bitand(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_bitand(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64BitOr`].
fn Executor::execute_i64_bitor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_bitor(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64BitXor`].
fn Executor::execute_i64_bitxor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_bitxor(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64And`].
fn Executor::execute_i64_and(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = i64_and(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Or`].
fn Executor::execute_i64_or(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = i64_or(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Nand`].
fn Executor::execute_i64_nand(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = i64_nand(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Nor`].
fn Executor::execute_i64_nor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = i64_nor(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Shl`].
fn Executor::execute_i32_shl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_shl(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShrU`].
fn Executor::execute_i32_shr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_shr_u(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShrS`].
fn Executor::execute_i32_shr_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_shr_s(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Rotl`].
fn Executor::execute_i32_rotl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_rotl(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Rotr`].
fn Executor::execute_i32_rotr(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_rotr(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Shl`].
fn Executor::execute_i64_shl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_shl(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShrU`].
fn Executor::execute_i64_shr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_shr_u(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShrS`].
fn Executor::execute_i64_shr_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_shr_s(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Rotl`].
fn Executor::execute_i64_rotl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_rotl(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Rotr`].
fn Executor::execute_i64_rotr(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_rotr(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Add`].
fn Executor::execute_f32_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_add(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Sub`].
fn Executor::execute_f32_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_sub(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Mul`].
fn Executor::execute_f32_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_mul(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Div`].
fn Executor::execute_f32_div(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_div(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Min`].
fn Executor::execute_f32_min(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_min(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Max`].
fn Executor::execute_f32_max(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_max(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Copysign`].
fn Executor::execute_f32_copysign(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_copysign(lhs, rhs)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Add`].
fn Executor::execute_f64_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_add(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Sub`].
fn Executor::execute_f64_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_sub(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Mul`].
fn Executor::execute_f64_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_mul(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Div`].
fn Executor::execute_f64_div(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_div(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Min`].
fn Executor::execute_f64_min(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_min(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Max`].
fn Executor::execute_f64_max(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_max(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Copysign`].
fn Executor::execute_f64_copysign(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_copysign(lhs, rhs)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32DivS`].
fn Executor::execute_i32_div_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_div_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32DivU`].
fn Executor::execute_i32_div_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_div_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RemS`].
fn Executor::execute_i32_rem_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_rem_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RemU`].
fn Executor::execute_i32_rem_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_rem_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64DivS`].
fn Executor::execute_i64_div_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_div_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64DivU`].
fn Executor::execute_i64_div_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_div_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RemS`].
fn Executor::execute_i64_rem_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_rem_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RemU`].
fn Executor::execute_i64_rem_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_rem_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32AddImm16`].
fn Executor::execute_i32_add_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_add(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32MulImm16`].
fn Executor::execute_i32_mul_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_mul(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32BitAndImm16`].
fn Executor::execute_i32_bitand_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_bitand(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32BitOrImm16`].
fn Executor::execute_i32_bitor_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_bitor(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32BitXorImm16`].
fn Executor::execute_i32_bitxor_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_bitxor(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32AndImm16`].
fn Executor::execute_i32_and_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = i32_and(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32OrImm16`].
fn Executor::execute_i32_or_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = i32_or(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32NandImm16`].
fn Executor::execute_i32_nand_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = i32_nand(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32NorImm16`].
fn Executor::execute_i32_nor_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = i32_nor(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64AddImm16`].
fn Executor::execute_i64_add_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_add(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64MulImm16`].
fn Executor::execute_i64_mul_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_mul(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64BitAndImm16`].
fn Executor::execute_i64_bitand_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_bitand(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64BitOrImm16`].
fn Executor::execute_i64_bitor_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_bitor(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64BitXorImm16`].
fn Executor::execute_i64_bitxor_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_bitxor(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64AndImm16`].
fn Executor::execute_i64_and_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = i64_and(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64OrImm16`].
fn Executor::execute_i64_or_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = i64_or(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64NandImm16`].
fn Executor::execute_i64_nand_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = i64_nand(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64NorImm16`].
fn Executor::execute_i64_nor_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = i64_nor(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32DivSImm16Rhs`].
fn Executor::execute_i32_div_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = i32_div_s_nonzero(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RemSImm16Rhs`].
fn Executor::execute_i32_rem_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = i32_rem_s_nonzero(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64DivSImm16Rhs`].
fn Executor::execute_i64_div_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = i64_div_s_nonzero(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RemSImm16Rhs`].
fn Executor::execute_i64_rem_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit raise WasmiError {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = i64_rem_s_nonzero(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32DivUImm16Rhs`].
fn Executor::execute_i32_div_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_u32()
  let value = i32_div_u_nonzero(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RemUImm16Rhs`].
fn Executor::execute_i32_rem_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_u32()
  let value = i32_rem_u_nonzero(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64DivUImm16Rhs`].
fn Executor::execute_i64_div_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_u64()
  let value = i64_div_u_nonzero(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RemUImm16Rhs`].
fn Executor::execute_i64_rem_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_u64()
  let value = i64_rem_u_nonzero(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32SubImm16Lhs`].
fn Executor::execute_i32_sub_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_sub(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64SubImm16Lhs`].
fn Executor::execute_i64_sub_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_sub(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShlImm16`].
fn Executor::execute_i32_shl_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_shl(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShrUImm16`].
fn Executor::execute_i32_shr_u_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_shr_u(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShrSImm16`].
fn Executor::execute_i32_shr_s_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_shr_s(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RotlImm16`].
fn Executor::execute_i32_rotl_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_rotl(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RotrImm16`].
fn Executor::execute_i32_rotr_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_rotr(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShlImm16`].
fn Executor::execute_i64_shl_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_shl(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShrUImm16`].
fn Executor::execute_i64_shr_u_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_shr_u(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShrSImm16`].
fn Executor::execute_i64_shr_s_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_shr_s(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RotlImm16`].
fn Executor::execute_i64_rotl_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_rotl(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RotrImm16`].
fn Executor::execute_i64_rotr_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_rotr(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32DivSImm16Lhs`].
fn Executor::execute_i32_div_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_div_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32DivUImm16Lhs`].
fn Executor::execute_i32_div_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_u32()
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_div_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RemSImm16Lhs`].
fn Executor::execute_i32_rem_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_rem_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RemUImm16Lhs`].
fn Executor::execute_i32_rem_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_u32()
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_rem_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64DivSImm16Lhs`].
fn Executor::execute_i64_div_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_div_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64DivUImm16Lhs`].
fn Executor::execute_i64_div_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_u64()
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_div_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RemSImm16Lhs`].
fn Executor::execute_i64_rem_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_rem_s(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RemUImm16Lhs`].
fn Executor::execute_i64_rem_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit raise WasmiError {
  let lhs = lhs.to_u64()
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_rem_u(lhs, rhs) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShlBy`].
fn Executor::execute_i32_shl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_shl(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShrUBy`].
fn Executor::execute_i32_shr_u_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_shr_u(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32ShrSBy`].
fn Executor::execute_i32_shr_s_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_shr_s(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RotlBy`].
fn Executor::execute_i32_rotl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_rotl(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32RotrBy`].
fn Executor::execute_i32_rotr_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_rotr(lhs, rhs)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShlBy`].
fn Executor::execute_i64_shl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_shl(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShrUBy`].
fn Executor::execute_i64_shr_u_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_shr_u(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64ShrSBy`].
fn Executor::execute_i64_shr_s_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_shr_s(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RotlBy`].
fn Executor::execute_i64_rotl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_rotl(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64RotrBy`].
fn Executor::execute_i64_rotr_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_rotr(lhs, rhs)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}
