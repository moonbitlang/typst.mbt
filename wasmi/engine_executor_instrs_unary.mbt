// Port of wasmi 1.0.9 `engine/executor/instrs/unary.rs`.

///|
/// Executes an [`Op::I32Clz`].
fn Executor::execute_i32_clz(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i32_clz(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Ctz`].
fn Executor::execute_i32_ctz(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i32_ctz(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Popcnt`].
fn Executor::execute_i32_popcnt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i32_popcnt(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Clz`].
fn Executor::execute_i64_clz(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64_clz(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Ctz`].
fn Executor::execute_i64_ctz(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64_ctz(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Popcnt`].
fn Executor::execute_i64_popcnt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64_popcnt(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Abs`].
fn Executor::execute_f32_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_abs(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Neg`].
fn Executor::execute_f32_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_neg(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Ceil`].
fn Executor::execute_f32_ceil(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_ceil(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Floor`].
fn Executor::execute_f32_floor(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_floor(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Trunc`].
fn Executor::execute_f32_trunc(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_trunc(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Nearest`].
fn Executor::execute_f32_nearest(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_nearest(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32Sqrt`].
fn Executor::execute_f32_sqrt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32_sqrt(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Abs`].
fn Executor::execute_f64_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_abs(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Neg`].
fn Executor::execute_f64_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_neg(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Ceil`].
fn Executor::execute_f64_ceil(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_ceil(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Floor`].
fn Executor::execute_f64_floor(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_floor(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Trunc`].
fn Executor::execute_f64_trunc(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_trunc(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Nearest`].
fn Executor::execute_f64_nearest(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_nearest(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64Sqrt`].
fn Executor::execute_f64_sqrt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64_sqrt(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}
