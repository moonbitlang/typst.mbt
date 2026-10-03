// Port of wasmi 1.0.9 `engine/executor/instrs/comparison.rs`.

///|
/// Executes an [`Op::I32Eq`].
fn Executor::execute_i32_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_eq(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Ne`].
fn Executor::execute_i32_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_ne(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LtS`].
fn Executor::execute_i32_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_lt_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LtU`].
fn Executor::execute_i32_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_lt_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LeS`].
fn Executor::execute_i32_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_le_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LeU`].
fn Executor::execute_i32_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_le_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Eq`].
fn Executor::execute_i64_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_eq(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Ne`].
fn Executor::execute_i64_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_ne(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LtS`].
fn Executor::execute_i64_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_lt_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LtU`].
fn Executor::execute_i64_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_lt_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LeS`].
fn Executor::execute_i64_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_le_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LeU`].
fn Executor::execute_i64_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_le_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Eq`].
fn Executor::execute_f32_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_eq(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Ne`].
fn Executor::execute_f32_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_ne(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Lt`].
fn Executor::execute_f32_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_lt(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Le`].
fn Executor::execute_f32_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = @wasmi_core.f32_le(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32NotLt`].
fn Executor::execute_f32_not_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = f32_not_lt(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32NotLe`].
fn Executor::execute_f32_not_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let value = f32_not_le(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Eq`].
fn Executor::execute_f64_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_eq(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Ne`].
fn Executor::execute_f64_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_ne(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Lt`].
fn Executor::execute_f64_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_lt(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Le`].
fn Executor::execute_f64_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = @wasmi_core.f64_le(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64NotLt`].
fn Executor::execute_f64_not_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = f64_not_lt(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64NotLe`].
fn Executor::execute_f64_not_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let value = f64_not_le(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32EqImm16`].
fn Executor::execute_i32_eq_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_eq(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32NeImm16`].
fn Executor::execute_i32_ne_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_ne(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LtSImm16Rhs`].
fn Executor::execute_i32_lt_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_lt_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LtUImm16Rhs`].
fn Executor::execute_i32_lt_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i32_lt_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LeSImm16Rhs`].
fn Executor::execute_i32_le_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let value = @wasmi_core.i32_le_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LeUImm16Rhs`].
fn Executor::execute_i32_le_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i32_le_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64EqImm16`].
fn Executor::execute_i64_eq_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_eq(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64NeImm16`].
fn Executor::execute_i64_ne_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_ne(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LtSImm16Rhs`].
fn Executor::execute_i64_lt_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_lt_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LtUImm16Rhs`].
fn Executor::execute_i64_lt_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = rhs.to_u64()
  let value = @wasmi_core.i64_lt_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LeSImm16Rhs`].
fn Executor::execute_i64_le_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let value = @wasmi_core.i64_le_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LeUImm16Rhs`].
fn Executor::execute_i64_le_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = rhs.to_u64()
  let value = @wasmi_core.i64_le_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LtSImm16Lhs`].
fn Executor::execute_i32_lt_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_lt_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LtUImm16Lhs`].
fn Executor::execute_i32_lt_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_u32()
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_lt_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LeSImm16Lhs`].
fn Executor::execute_i32_le_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  let value = @wasmi_core.i32_le_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32LeUImm16Lhs`].
fn Executor::execute_i32_le_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_u32()
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32_le_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LtSImm16Lhs`].
fn Executor::execute_i64_lt_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_lt_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LtUImm16Lhs`].
fn Executor::execute_i64_lt_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_u64()
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_lt_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LeSImm16Lhs`].
fn Executor::execute_i64_le_s_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  let value = @wasmi_core.i64_le_s(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64LeUImm16Lhs`].
fn Executor::execute_i64_le_u_imm16_lhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = lhs.to_u64()
  let rhs = self.get_stack_slot_as_u64(rhs)
  let value = @wasmi_core.i64_le_u(lhs, rhs)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}
