// Port of wasmi 1.0.9 `engine/executor/instrs/select.rs`.

///|
/// Executes an [`Op::SelectI32Eq`].
fn Executor::execute_select_i32_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let selected = if @wasmi_core.i32_eq(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LtS`].
fn Executor::execute_select_i32_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let selected = if @wasmi_core.i32_lt_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LtU`].
fn Executor::execute_select_i32_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let selected = if @wasmi_core.i32_lt_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LeS`].
fn Executor::execute_select_i32_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let selected = if @wasmi_core.i32_le_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LeU`].
fn Executor::execute_select_i32_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let selected = if @wasmi_core.i32_le_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32And`].
fn Executor::execute_select_i32_and(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let selected = if i32_and(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32Or`].
fn Executor::execute_select_i32_or(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  let selected = if i32_or(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64Eq`].
fn Executor::execute_select_i64_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let selected = if @wasmi_core.i64_eq(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LtS`].
fn Executor::execute_select_i64_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let selected = if @wasmi_core.i64_lt_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LtU`].
fn Executor::execute_select_i64_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  let selected = if @wasmi_core.i64_lt_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LeS`].
fn Executor::execute_select_i64_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let selected = if @wasmi_core.i64_le_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LeU`].
fn Executor::execute_select_i64_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  let selected = if @wasmi_core.i64_le_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64And`].
fn Executor::execute_select_i64_and(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let selected = if i64_and(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64Or`].
fn Executor::execute_select_i64_or(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  let selected = if i64_or(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectF32Eq`].
fn Executor::execute_select_f32_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let selected = if @wasmi_core.f32_eq(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectF32Lt`].
fn Executor::execute_select_f32_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let selected = if @wasmi_core.f32_lt(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectF32Le`].
fn Executor::execute_select_f32_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  let selected = if @wasmi_core.f32_le(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectF64Eq`].
fn Executor::execute_select_f64_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let selected = if @wasmi_core.f64_eq(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectF64Lt`].
fn Executor::execute_select_f64_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let selected = if @wasmi_core.f64_lt(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectF64Le`].
fn Executor::execute_select_f64_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  let selected = if @wasmi_core.f64_le(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32EqImm16`].
fn Executor::execute_select_i32_eq_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let selected = if @wasmi_core.i32_eq(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LtSImm16Rhs`].
fn Executor::execute_select_i32_lt_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let selected = if @wasmi_core.i32_lt_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LtUImm16Rhs`].
fn Executor::execute_select_i32_lt_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = rhs.to_u32()
  let selected = if @wasmi_core.i32_lt_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LeSImm16Rhs`].
fn Executor::execute_select_i32_le_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let selected = if @wasmi_core.i32_le_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32LeUImm16Rhs`].
fn Executor::execute_select_i32_le_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = rhs.to_u32()
  let selected = if @wasmi_core.i32_le_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32AndImm16`].
fn Executor::execute_select_i32_and_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let selected = if i32_and(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI32OrImm16`].
fn Executor::execute_select_i32_or_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  let selected = if i32_or(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64EqImm16`].
fn Executor::execute_select_i64_eq_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let selected = if @wasmi_core.i64_eq(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LtSImm16Rhs`].
fn Executor::execute_select_i64_lt_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let selected = if @wasmi_core.i64_lt_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LtUImm16Rhs`].
fn Executor::execute_select_i64_lt_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = rhs.to_u64()
  let selected = if @wasmi_core.i64_lt_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LeSImm16Rhs`].
fn Executor::execute_select_i64_le_s_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let selected = if @wasmi_core.i64_le_s(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64LeUImm16Rhs`].
fn Executor::execute_select_i64_le_u_imm16_rhs(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = rhs.to_u64()
  let selected = if @wasmi_core.i64_le_u(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64AndImm16`].
fn Executor::execute_select_i64_and_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let selected = if i64_and(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::SelectI64OrImm16`].
fn Executor::execute_select_i64_or_imm16(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
) -> Unit {
  guard self.instrs.unsafe_get(self.ip + 1) is Slot2(slots~) else {
    abort("expected `Op::Slot2`")
  }
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  let selected = if i64_or(lhs, rhs) {
    slots.unsafe_get(0)
  } else {
    slots.unsafe_get(1)
  }
  self.set_stack_slot(result, self.get_stack_slot(selected))
  self.next_instr_at(2)
}
