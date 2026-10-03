// Port of wasmi 1.0.9 `engine/executor/instrs/return_.rs`.

///|
/// Returns the execution to the caller.
///
/// Any return values are expected to already have been transferred
/// from the returning callee to the caller.
fn Executor::return_impl(self : Executor, store : StoreInner) -> ControlFlow {
  guard self.stack.calls.pop() is Some(returned) else {
    abort("the executing call frame is always on the stack")
  }
  let popped_instance = self.stack.calls.popped_instance()
  self.stack.values.truncate(returned.frame_offset())
  let new_instance = match popped_instance {
    Some(_) => self.stack.calls.instance()
    None => None
  }
  if new_instance is Some(new_instance) {
    self.cache.update(store, new_instance)
  }
  match self.stack.calls.peek() {
    Some(caller) => {
      self.init_call_frame(caller)
      Continue
    }
    None => Break
  }
}

///|
/// Execute an [`Op::Return`].
fn Executor::execute_return(self : Executor, store : StoreInner) -> ControlFlow {
  self.return_impl(store)
}

///|
/// Returns the index of the value stack cell of the first result in the
/// caller frame (upstream returns the caller's `FrameSlots` and the
/// `SlotSpan` of the results).
///
/// The cells `dst..dst+len_results` are valid for all results.
fn Executor::return_caller_results(self : Executor) -> Int {
  guard self.stack.calls.peek() is Some(callee) else {
    abort("the callee must exist on the call stack")
  }
  match self.stack.calls.peek_caller() {
    Some(caller) => {
      // Case: we need to return the `value` back to the caller frame.
      //
      // In this case we transfer the single return `value` to the `results`
      // register span of the caller's call frame.
      //
      // Safety: The caller call frame is still live on the value stack
      //         and therefore it is safe to acquire its value stack pointer.
      let caller_sp = caller.base_offset()
      let results = callee.results()
      caller_sp + results.head().0
    }
    None =>
      // Case: the root call frame is returning.
      //
      // In this case we transfer the single return `value` to the root
      // register span of the entire value stack which is simply its zero index.
      0
  }
}

///|
/// Execute a generic return [`Op`] returning a single value.
fn Executor::execute_return_value(
  self : Executor,
  store : StoreInner,
  value : @wasmi_core.UntypedVal,
) -> ControlFlow {
  let dst = self.return_caller_results()
  // Safety: The `callee.results()` always refer to a span of valid
  //         registers of the `caller` that does not overlap with the
  //         registers of the callee since they reside in different
  //         call frames. Therefore this access is safe.
  self.lo.unsafe_set(dst, value.to_bits64())
  self.hi.unsafe_set(dst, value.hi64())
  self.return_impl(store)
}

///|
/// Execute an [`Op::ReturnSlot`] returning a single [`Slot`] value.
fn Executor::execute_return_reg(
  self : Executor,
  store : StoreInner,
  value : @ir.Slot,
) -> ControlFlow {
  self.execute_return_value(store, self.get_stack_slot(value))
}

///|
/// Execute an [`Op::ReturnSlot2`] returning two [`Slot`] values.
fn Executor::execute_return_reg2(
  self : Executor,
  store : StoreInner,
  values : FixedArray[@ir.Slot],
) -> ControlFlow {
  self.execute_return_reg_n_impl(store, values)
}

///|
/// Execute an [`Op::ReturnSlot3`] returning three [`Slot`] values.
fn Executor::execute_return_reg3(
  self : Executor,
  store : StoreInner,
  values : FixedArray[@ir.Slot],
) -> ControlFlow {
  self.execute_return_reg_n_impl(store, values)
}

///|
/// Executes an [`Op::ReturnSlot2`] or [`Op::ReturnSlot3`] generically.
fn Executor::execute_return_reg_n_impl(
  self : Executor,
  store : StoreInner,
  values : FixedArray[@ir.Slot],
) -> ControlFlow {
  let dst = self.return_caller_results()
  for i, value in values {
    let src = self.sp + value.0
    // Safety: The `callee.results()` always refer to a span of valid
    //         registers of the `caller` that does not overlap with the
    //         registers of the callee since they reside in different
    //         call frames. Therefore this access is safe.
    self.lo.unsafe_set(dst + i, self.lo.unsafe_get(src))
    self.hi.unsafe_set(dst + i, self.hi.unsafe_get(src))
  }
  self.return_impl(store)
}

///|
/// Execute an [`Op::ReturnImm32`] returning a single 32-bit value.
fn Executor::execute_return_imm32(
  self : Executor,
  store : StoreInner,
  value : @ir.AnyConst32,
) -> ControlFlow {
  self.execute_return_value(
    store,
    @wasmi_core.UntypedVal::from_u32(value.to_u32()),
  )
}

///|
/// Execute an [`Op::ReturnI64Imm32`] returning a single 32-bit encoded `i64` value.
fn Executor::execute_return_i64imm32(
  self : Executor,
  store : StoreInner,
  value : @ir.Const32,
) -> ControlFlow {
  self.execute_return_value(
    store,
    @wasmi_core.UntypedVal::from_i64(value.to_i64()),
  )
}

///|
/// Execute an [`Op::ReturnF64Imm32`] returning a single 32-bit encoded `f64` value.
fn Executor::execute_return_f64imm32(
  self : Executor,
  store : StoreInner,
  value : @ir.Const32,
) -> ControlFlow {
  self.execute_return_value(
    store,
    @wasmi_core.UntypedVal::from_u64(value.to_f64_bits()),
  )
}

///|
/// Execute an [`Op::ReturnSpan`] returning many values.
fn Executor::execute_return_span(
  self : Executor,
  store : StoreInner,
  values : @ir.BoundedSlotSpan,
) -> ControlFlow {
  let dst = self.return_caller_results()
  let src = self.sp + values.span().head().0
  for i in 0..<values.len() {
    // Safety: The `callee.results()` always refer to a span of valid
    //         registers of the `caller` that does not overlap with the
    //         registers of the callee since they reside in different
    //         call frames. Therefore this access is safe.
    self.lo.unsafe_set(dst + i, self.lo.unsafe_get(src + i))
    self.hi.unsafe_set(dst + i, self.hi.unsafe_get(src + i))
  }
  self.return_impl(store)
}

///|
/// Execute an [`Op::ReturnMany`] returning many values.
fn Executor::execute_return_many(
  self : Executor,
  store : StoreInner,
  values : FixedArray[@ir.Slot],
) -> ControlFlow {
  self.ip = self.ip + 1
  self.copy_many_return_values(self.ip, values)
  self.return_impl(store)
}

///|
/// Copies `values` to the result cells starting at `dst`; returns the next
/// result cell (upstream's `copy_results` closure).
fn Executor::copy_results(
  self : Executor,
  dst : Int,
  values : FixedArray[@ir.Slot],
) -> Int {
  let mut dst = dst
  for value in values {
    let src = self.sp + value.0
    // Safety: The `callee.results()` always refer to a span of valid
    //         registers of the `caller` that does not overlap with the
    //         registers of the callee since they reside in different
    //         call frames. Therefore this access is safe.
    self.lo.unsafe_set(dst, self.lo.unsafe_get(src))
    self.hi.unsafe_set(dst, self.hi.unsafe_get(src))
    dst = dst + 1
  }
  dst
}

///|
/// Copies many return values to the caller frame.
///
/// # Note
///
/// Used by the execution logic for
///
/// - [`Op::ReturnMany`]
fn Executor::copy_many_return_values(
  self : Executor,
  ip : Int,
  values : FixedArray[@ir.Slot],
) -> Unit {
  let mut result = self.return_caller_results()
  result = self.copy_results(result, values)
  let mut ip = ip
  while self.instrs.unsafe_get(ip) is SlotList(regs~) {
    result = self.copy_results(result, regs)
    ip = ip + 1
  }
  match self.instrs.unsafe_get(ip) {
    Slot(slot~) => {
      let src = self.sp + slot.0
      self.lo.unsafe_set(result, self.lo.unsafe_get(src))
      self.hi.unsafe_set(result, self.hi.unsafe_get(src))
    }
    Slot2(slots~) => self.copy_results(result, slots) |> ignore
    Slot3(slots~) => self.copy_results(result, slots) |> ignore
    // Safety: Wasmi translation guarantees that a slot-list finalizer exists.
    _ => abort("unexpected slot-list finalizer")
  }
}
