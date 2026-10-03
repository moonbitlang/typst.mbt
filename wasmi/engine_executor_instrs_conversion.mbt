// Port of wasmi 1.0.9 `engine/executor/instrs/conversion.rs`.

///|
/// Executes an [`Op::I32WrapI64`].
fn Executor::execute_i32_wrap_i64(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i32_wrap_i64(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncSatF32S`].
fn Executor::execute_i32_trunc_sat_f32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i32_trunc_sat_f32_s(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncSatF32U`].
fn Executor::execute_i32_trunc_sat_f32_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i32_trunc_sat_f32_u(value)
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncSatF64S`].
fn Executor::execute_i32_trunc_sat_f64_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i32_trunc_sat_f64_s(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncSatF64U`].
fn Executor::execute_i32_trunc_sat_f64_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i32_trunc_sat_f64_u(value)
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncSatF32S`].
fn Executor::execute_i64_trunc_sat_f32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i64_trunc_sat_f32_s(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncSatF32U`].
fn Executor::execute_i64_trunc_sat_f32_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i64_trunc_sat_f32_u(value)
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncSatF64S`].
fn Executor::execute_i64_trunc_sat_f64_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i64_trunc_sat_f64_s(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncSatF64U`].
fn Executor::execute_i64_trunc_sat_f64_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i64_trunc_sat_f64_u(value)
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Extend8S`].
fn Executor::execute_i32_extend8_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i32_extend8_s(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Extend16S`].
fn Executor::execute_i32_extend16_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i32_extend16_s(value)
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Extend8S`].
fn Executor::execute_i64_extend8_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64_extend8_s(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Extend16S`].
fn Executor::execute_i64_extend16_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64_extend16_s(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Extend32S`].
fn Executor::execute_i64_extend32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64_extend32_s(value)
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32DemoteF64`].
fn Executor::execute_f32_demote_f64(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f32_demote_f64(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64PromoteF32`].
fn Executor::execute_f64_promote_f32(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f64_promote_f32(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32ConvertI32S`].
fn Executor::execute_f32_convert_i32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.f32_convert_i32_s(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32ConvertI32U`].
fn Executor::execute_f32_convert_i32_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_u32(input)
  let value = @wasmi_core.f32_convert_i32_u(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32ConvertI64S`].
fn Executor::execute_f32_convert_i64_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.f32_convert_i64_s(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32ConvertI64U`].
fn Executor::execute_f32_convert_i64_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_u64(input)
  let value = @wasmi_core.f32_convert_i64_u(value)
  self.set_stack_slot_as_f32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64ConvertI32S`].
fn Executor::execute_f64_convert_i32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.f64_convert_i32_s(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64ConvertI32U`].
fn Executor::execute_f64_convert_i32_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_u32(input)
  let value = @wasmi_core.f64_convert_i32_u(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64ConvertI64S`].
fn Executor::execute_f64_convert_i64_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.f64_convert_i64_s(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64ConvertI64U`].
fn Executor::execute_f64_convert_i64_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_u64(input)
  let value = @wasmi_core.f64_convert_i64_u(value)
  self.set_stack_slot_as_f64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncF32S`].
fn Executor::execute_i32_trunc_f32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i32_trunc_f32_s(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncF32U`].
fn Executor::execute_i32_trunc_f32_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i32_trunc_f32_u(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncF64S`].
fn Executor::execute_i32_trunc_f64_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i32_trunc_f64_s(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32TruncF64U`].
fn Executor::execute_i32_trunc_f64_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i32_trunc_f64_u(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncF32S`].
fn Executor::execute_i64_trunc_f32_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i64_trunc_f32_s(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncF32U`].
fn Executor::execute_i64_trunc_f32_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.i64_trunc_f32_u(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncF64S`].
fn Executor::execute_i64_trunc_f64_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i64_trunc_f64_s(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64TruncF64U`].
fn Executor::execute_i64_trunc_f64_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit raise WasmiError {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.i64_trunc_f64_u(value) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, value)
  self.next_instr()
}
