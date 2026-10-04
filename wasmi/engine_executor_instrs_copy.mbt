// Port of wasmi 1.0.9 `engine/executor/instrs/copy.rs`.

///|
/// Executes an [`Op::Copy`].
fn Executor::execute_copy(
  self : Executor,
  result : @ir.Slot,
  value : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot(value)
  self.set_stack_slot(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::Copy2`].
fn Executor::execute_copy_2(
  self : Executor,
  results : @ir.FixedSlotSpan,
  values : FixedArray[@ir.Slot],
) -> Unit {
  self.execute_copy_2_impl(results, values)
  self.next_instr()
}

///|
/// Internal implementation of [`Op::Copy2`] execution.
fn Executor::execute_copy_2_impl(
  self : Executor,
  results : @ir.FixedSlotSpan,
  values : FixedArray[@ir.Slot],
) -> Unit {
  let result0 = results.span().head()
  let result1 = result0.next()
  // We need `tmp` in case `results[0] == values[1]` to avoid overwriting `values[1]` before reading it.
  let tmp = self.get_stack_slot(values.unsafe_get(1))
  self.set_stack_slot(result0, self.get_stack_slot(values.unsafe_get(0)))
  self.set_stack_slot(result1, tmp)
}

///|
/// Executes an [`Op::CopyImm32`].
fn Executor::execute_copy_imm32(
  self : Executor,
  result : @ir.Slot,
  value : @ir.AnyConst32,
) -> Unit {
  self.set_stack_slot(result, @wasmi_core.UntypedVal::from_u32(value.to_u32()))
  self.next_instr()
}

///|
/// Executes an [`Op::CopyI64Imm32`].
fn Executor::execute_copy_i64imm32(
  self : Executor,
  result : @ir.Slot,
  value : @ir.Const32,
) -> Unit {
  self.set_stack_slot(result, @wasmi_core.UntypedVal::from_i64(value.to_i64()))
  self.next_instr()
}

///|
/// Executes an [`Op::CopyF64Imm32`].
fn Executor::execute_copy_f64imm32(
  self : Executor,
  result : @ir.Slot,
  value : @ir.Const32,
) -> Unit {
  self.set_stack_slot(
    result,
    @wasmi_core.UntypedVal::from_u64(value.to_f64_bits()),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::CopySpan`].
///
/// # Note
///
/// - This instruction assumes that `results` and `values` do _not_ overlap
///   and thus can copy all the elements without a costly temporary buffer.
/// - If `results` and `values` _do_ overlap [`Op::CopySpan`] is used.
fn Executor::execute_copy_span(
  self : Executor,
  results : @ir.SlotSpan,
  values : @ir.SlotSpan,
  len : Int,
) -> Unit {
  self.execute_copy_span_impl(results, values, len)
  self.next_instr()
}

///|
/// Internal implementation of [`Op::CopySpan`] execution.
fn Executor::execute_copy_span_impl(
  self : Executor,
  results : @ir.SlotSpan,
  values : @ir.SlotSpan,
  len : Int,
) -> Unit {
  let results = self.sp + results.head().0
  let values = self.sp + values.head().0
  let lo = self.lo
  let hi = self.hi
  for i in 0..<len {
    lo.unsafe_set(results + i, lo.unsafe_get(values + i))
    hi.unsafe_set(results + i, hi.unsafe_get(values + i))
  }
}

///|
/// Executes an [`Op::CopyMany`].
fn Executor::execute_copy_many(
  self : Executor,
  results : @ir.SlotSpan,
  values : FixedArray[@ir.Slot],
) -> Unit {
  self.ip = self.ip + 1
  self.ip = self.execute_copy_many_impl(self.ip, results, values)
  self.next_instr()
}

///|
/// Copies the `values` to the cells starting at `result`; returns the next
/// result slot (upstream's `copy_values` closure).
fn Executor::copy_values(
  self : Executor,
  result : @ir.Slot,
  values : FixedArray[@ir.Slot],
) -> @ir.Slot {
  let mut result = result
  for value in values {
    let value = self.get_stack_slot(value)
    self.set_stack_slot(result, value)
    result = result.next()
  }
  result
}

///|
/// Internal implementation of [`Op::CopyMany`] execution.
fn Executor::execute_copy_many_impl(
  self : Executor,
  ip : Int,
  results : @ir.SlotSpan,
  values : FixedArray[@ir.Slot],
) -> Int {
  let mut ip = ip
  let mut result = results.head()
  result = self.copy_values(result, values)
  while self.instrs.unsafe_get(ip) is SlotList(regs~) {
    result = self.copy_values(result, regs)
    ip = ip + 1
  }
  match self.instrs.unsafe_get(ip) {
    Slot(slot~) => {
      let value = self.get_stack_slot(slot)
      self.set_stack_slot(result, value)
    }
    Slot2(slots~) => self.copy_values(result, slots) |> ignore
    Slot3(slots~) => self.copy_values(result, slots) |> ignore
    // Safety: Wasmi translator guarantees that slot-list finalizer exists.
    _ => abort("expected slot-list finalizer")
  }
  ip
}
