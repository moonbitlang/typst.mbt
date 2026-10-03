// Port of wasmi 1.0.9 `engine/executor/instrs/call.rs`.
//
// Upstream's `CallContext` marker types (`ReturnCall0`, `ReturnCall`,
// `NestedCall0`, `NestedCall`) become the `kind : CallKind` and
// `has_params : Bool` arguments.

///|
/// Dispatches and executes the host function.
///
/// The parameters of the host function are the top-most
/// `max(len_params, len_results)` cells of `value_stack`; its results are
/// written back to the same cells.
///
/// # Note
///
/// Upstream lends the cells to the host function as one `FuncInOut` buffer;
/// here the parameters are copied into `FuncInOut::params` and the results
/// copied back from `FuncInOut::results`.
///
/// # Errors
///
/// Returns the error of the host function if an error occurred.
fn dispatch_host_func(
  store : StoreInner,
  value_stack : ValueStack,
  host_func : HostFuncEntity,
  instance : Instance?,
) -> Unit raise WasmiError {
  let len_params = host_func.len_params
  let len_results = host_func.len_results
  let max_inout = if len_params > len_results {
    len_params
  } else {
    len_results
  }
  let start = value_stack.len() - max_inout
  let params = Array::makei(len_params, i => value_stack.get(start + i))
  let results = Array::make(len_results, @wasmi_core.UntypedVal::default())
  let params_results : FuncInOut = { params, results, }
  // Note: We drop the values that have been temporarily added to
  //       the stack to act as parameter and result buffer for the
  //       called host function. Since the host function failed we
  //       need to clean up the temporary buffer values here.
  //       This is required for resumable calls to work properly.
  errdefer value_stack.drop(max_inout)
  (host_func.func)(store, instance, params_results)
  for i in 0..<len_results {
    value_stack.set(start + i, params_results.results[i])
  }
}

///|
/// The kind of a function call.
priv enum CallKind {
  /// A nested function call.
  Nested
  /// A tailing function call.
  Tail
}

///|
/// Updates the instruction pointer of the caller [`CallFrame`] before dispatching a call.
///
/// # Note
///
/// The `offset` denotes how many [`Op`] words make up the call instruction.
fn Executor::update_instr_ptr_at(self : Executor, offset : Int) -> Unit {
  // Note: we explicitly do not mutate `self.ip` since that would make
  // other parts of the code more fragile with respect to instruction ordering.
  self.ip = self.ip + offset
  guard self.stack.calls.peek() is Some(caller) else {
    abort("caller call frame must be on the stack")
  }
  caller.update_instr_ptr(self.ip)
}

///|
/// Fetches the [`Op::CallIndirectParams`] parameter for a call [`Op`] and
/// returns its table index; the `index` operand is stored into
/// `self.call_indirect_index` (upstream returns both as a pair).
///
/// # Note
///
/// - This advances the instruction pointer to the next [`Op`].
fn Executor::pull_call_indirect_params(self : Executor) -> @ir.Table {
  self.ip = self.ip + 1
  match self.instrs.unsafe_get(self.ip) {
    CallIndirectParams(index~, table~) => {
      let index : UInt64 = self.get_stack_slot_as_u64(index)
      self.call_indirect_index = index
      table
    }
    // Safety: Wasmi translation guarantees that correct instruction parameter follows.
    _ => abort("expected `Op::CallIndirectParams`")
  }
}

///|
/// Fetches the [`Op::CallIndirectParamsImm16`] parameter for a call [`Op`]
/// (see [`Executor::pull_call_indirect_params`]).
///
/// # Note
///
/// - This advances the instruction pointer to the next [`Op`].
fn Executor::pull_call_indirect_params_imm16(self : Executor) -> @ir.Table {
  self.ip = self.ip + 1
  match self.instrs.unsafe_get(self.ip) {
    CallIndirectParamsImm16(index~, table~) => {
      let index : UInt64 = index.to_u64()
      self.call_indirect_index = index
      table
    }
    // Safety: Wasmi translation guarantees that correct instruction parameter follows.
    _ => abort("expected `Op::CallIndirectParamsImm16`")
  }
}

///|
/// Creates a [`CallFrame`] for calling the [`EngineFunc`] (in the scratch
/// frame `self.callee`).
fn Executor::dispatch_compiled_func(
  self : Executor,
  has_params : Bool,
  results : @ir.SlotSpan,
  func : CompiledFuncEntity,
) -> CallFrame raise WasmiError {
  let uninit_params = self.params
  let frame = self.stack.values.alloc_call_frame(func, uninit_params) catch {
    e => raise WasmiError::TrapCode(e)
  }
  // We have to re-fetch the cell arrays since we just called
  // [`ValueStack::alloc_call_frame`] which might reallocate them.
  self.sync_cells()
  let called = self.callee
  called.init(func.instrs(), 0, frame + func.consts().length(), frame, results)
  if has_params {
    self.copy_call_params(uninit_params)
  }
  uninit_params.init_zeroes()
  called
}

///|
/// Copies the parameters from caller for the callee [`CallFrame`].
///
/// This will also adjust the instruction pointer to point to the
/// last call parameter [`Op`] if any.
fn Executor::copy_call_params(
  self : Executor,
  uninit_params : FrameParams,
) -> Unit {
  self.ip = self.ip + 1
  if self.instrs.unsafe_get(self.ip) is SlotList(..) {
    self.copy_call_params_list(uninit_params)
  }
  match self.instrs.unsafe_get(self.ip) {
    Slot(slot~) => {
      let i = self.sp + slot.0
      uninit_params.init_next_bits(self.lo.unsafe_get(i), self.hi.unsafe_get(i))
    }
    Slot2(slots~) => self.copy_regs(uninit_params, slots)
    Slot3(slots~) => self.copy_regs(uninit_params, slots)
    // Safety: Wasmi translation guarantees that register list finalizer exists.
    _ => abort("expected register-list finalizer")
  }
}

///|
/// Copies an array of [`Slot`] to the `dst` [`Slot`] span.
fn Executor::copy_regs(
  self : Executor,
  uninit_params : FrameParams,
  regs : FixedArray[@ir.Slot],
) -> Unit {
  for value in regs {
    let i = self.sp + value.0
    // Safety: The `callee.results()` always refer to a span of valid
    //         registers of the `caller` that does not overlap with the
    //         registers of the callee since they reside in different
    //         call frames. Therefore this access is safe.
    uninit_params.init_next_bits(self.lo.unsafe_get(i), self.hi.unsafe_get(i))
  }
}

///|
/// Copies a list of [`Op::SlotList`] to the `dst` [`Slot`] span.
/// Copies the parameters from `src` for the called [`CallFrame`].
///
/// This will make the instruction pointer point to the [`Op`] following the
/// last [`Op::SlotList`] if any.
fn Executor::copy_call_params_list(
  self : Executor,
  uninit_params : FrameParams,
) -> Unit {
  while self.instrs.unsafe_get(self.ip) is SlotList(regs~) {
    self.copy_regs(uninit_params, regs)
    self.ip = self.ip + 1
  }
}

///|
/// Prepares a [`EngineFunc`] call with optional call parameters.
fn Executor::prepare_compiled_func_call(
  self : Executor,
  kind : CallKind,
  has_params : Bool,
  store : StoreInner,
  results : @ir.SlotSpan,
  func : EngineFunc,
  instance : Instance?,
) -> Unit raise WasmiError {
  let mut instance = instance
  let func = self.code_map.get(Some(store.fuel), func)
  let called = self.dispatch_compiled_func(has_params, results, func)
  match kind {
    Nested =>
      // We need to update the instruction pointer of the caller call frame.
      self.update_instr_ptr_at(1)
    Tail => {
      // In case of a tail call we have to remove the caller call frame after
      // allocating the callee call frame. This moves all cells of the callee frame
      // and may invalidate pointers to it.
      //
      // Safety:
      //
      // We provide `merge_call_frames` properly with `frame` that has just been allocated
      // on the value stack which is what the function expects. After this operation we ensure
      // that `self.sp` is adjusted via a call to `init_call_frame` since it may have been
      // invalidated by this method.
      let caller_instance = self.stack.merge_call_frames(called)
      if caller_instance is Some(caller_instance) && instance is None {
        instance = Some(caller_instance)
      }
    }
  }
  self.init_call_frame(called)
  self.stack.calls.push(called, instance) catch {
    e => raise WasmiError::TrapCode(e)
  }
}

///|
/// Executes an [`Op::ReturnCallInternal0`].
fn Executor::execute_return_call_internal_0(
  self : Executor,
  store : StoreInner,
  func : EngineFunc,
) -> Unit raise WasmiError {
  self.execute_return_call_internal_impl(false, store, func)
}

///|
/// Executes an [`Op::ReturnCallInternal`].
fn Executor::execute_return_call_internal(
  self : Executor,
  store : StoreInner,
  func : EngineFunc,
) -> Unit raise WasmiError {
  self.execute_return_call_internal_impl(true, store, func)
}

///|
/// Executes an [`Op::ReturnCallInternal`] or [`Op::ReturnCallInternal0`].
fn Executor::execute_return_call_internal_impl(
  self : Executor,
  has_params : Bool,
  store : StoreInner,
  func : EngineFunc,
) -> Unit raise WasmiError {
  let results = self.caller_results()
  self.prepare_compiled_func_call(Tail, has_params, store, results, func, None)
}

///|
/// Returns the `results` [`SlotSpan`] of the top-most [`CallFrame`] on the [`CallStack`].
///
/// # Note
///
/// We refer to the top-most [`CallFrame`] as the `caller` since this method is used for
/// tail call instructions for which the top-most [`CallFrame`] is the caller.
fn Executor::caller_results(self : Executor) -> @ir.SlotSpan {
  guard self.stack.calls.peek() is Some(caller) else {
    abort("must have caller on the stack")
  }
  caller.results()
}

///|
/// Executes an [`Op::CallInternal0`].
fn Executor::execute_call_internal_0(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func : EngineFunc,
) -> Unit raise WasmiError {
  self.prepare_compiled_func_call(Nested, false, store, results, func, None)
}

///|
/// Executes an [`Op::CallInternal`].
fn Executor::execute_call_internal(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func : EngineFunc,
) -> Unit raise WasmiError {
  self.prepare_compiled_func_call(Nested, true, store, results, func, None)
}

///|
/// Executes an [`Op::ReturnCallImported0`].
fn Executor::execute_return_call_imported_0(
  self : Executor,
  store : StoreInner,
  func : @ir.Func,
) -> ControlFlow raise WasmiError {
  self.execute_return_call_imported_impl(false, store, func)
}

///|
/// Executes an [`Op::ReturnCallImported`].
fn Executor::execute_return_call_imported(
  self : Executor,
  store : StoreInner,
  func : @ir.Func,
) -> ControlFlow raise WasmiError {
  self.execute_return_call_imported_impl(true, store, func)
}

///|
/// Executes an [`Op::ReturnCallImported`] or [`Op::ReturnCallImported0`].
fn Executor::execute_return_call_imported_impl(
  self : Executor,
  has_params : Bool,
  store : StoreInner,
  func : @ir.Func,
) -> ControlFlow raise WasmiError {
  let func = self.get_func(func)
  self.execute_call_imported_impl(Tail, has_params, store, None, func)
}

///|
/// Executes an [`Op::CallImported0`].
fn Executor::execute_call_imported_0(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func : @ir.Func,
) -> Unit raise WasmiError {
  let func = self.get_func(func)
  let _ = self.execute_call_imported_impl(
    Nested,
    false,
    store,
    Some(results),
    func,
  )
}

///|
/// Executes an [`Op::CallImported`].
fn Executor::execute_call_imported(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func : @ir.Func,
) -> Unit raise WasmiError {
  let func = self.get_func(func)
  let _ = self.execute_call_imported_impl(
    Nested,
    true,
    store,
    Some(results),
    func,
  )
}

///|
/// Executes an imported or indirect (tail) call instruction.
fn Executor::execute_call_imported_impl(
  self : Executor,
  kind : CallKind,
  has_params : Bool,
  store : StoreInner,
  results : @ir.SlotSpan?,
  func : Func,
) -> ControlFlow raise WasmiError {
  match store.resolve_func(func) {
    Wasm(func) => {
      let instance = func.instance
      let func_body = func.body
      let results = match results {
        Some(results) => results
        None => self.caller_results()
      }
      self.prepare_compiled_func_call(
        kind,
        has_params,
        store,
        results,
        func_body,
        Some(instance),
      )
      self.cache.update(store, instance)
      Continue
    }
    Host(host_func) =>
      self.execute_host_func(kind, has_params, store, results, func, host_func)
  }
}

///|
/// Executes a host function.
///
/// # Note
///
/// This uses the value stack to store parameters and results of the host function call.
/// Upstream returns an `ErrorKind::ResumableHostTrap` if the host function
/// returned an error while there are still call frames on the call stack;
/// since resumable calls are not ported (and the root execution unwraps it
/// again) the host error is returned unchanged.
fn Executor::execute_host_func(
  self : Executor,
  kind : CallKind,
  has_params : Bool,
  store : StoreInner,
  results : @ir.SlotSpan?,
  _func : Func,
  host_func : HostFuncEntity,
) -> ControlFlow raise WasmiError {
  let len_params = host_func.len_params
  let len_results = host_func.len_results
  let max_inout = if len_params > len_results {
    len_params
  } else {
    len_results
  }
  let instance = self.stack.calls.instance_expect()
  let caller = match kind {
    Nested => self.stack.calls.peek()
    Tail => self.stack.calls.pop()
  }
  guard caller is Some(caller) else {
    abort("need to have a caller on the call stack")
  }
  let popped_instance = match kind {
    Nested => None
    Tail => self.stack.calls.popped_instance()
  }
  let buffer = self.stack.values.extend_by(max_inout) catch {
    e => raise WasmiError::TrapCode(e)
  }
  // We have to re-fetch the cell arrays since we just called
  // [`ValueStack::extend_by`] which might reallocate them.
  self.sync_cells()
  if has_params {
    let uninit_params = self.params
    uninit_params.init(self.stack.values, buffer, buffer + max_inout)
    self.copy_call_params(uninit_params)
  }
  if kind is Nested {
    self.update_instr_ptr_at(1)
  }
  let results = match results {
    Some(results) => results
    None => caller.results()
  }
  self.dispatch_host_func(store, host_func, instance)
  self.cache.update(store, instance)
  let results = results.head().0
  match kind {
    Nested => {
      let returned = self.stack.values.drop_return(max_inout)
      for i in 0..<len_results {
        // # Safety (1)
        //
        // We can safely acquire the stack pointer to the caller's and callee's (host)
        // call frames because we just allocated the host call frame and can be sure that
        // they are different.
        // In the following we make sure to not access registers out of bounds of each
        // call frame since we rely on Wasm validation and proper Wasm translation to
        // provide us with valid result registers.
        let dst = self.sp + results + i
        self.lo.unsafe_set(dst, self.lo.unsafe_get(returned + i))
        self.hi.unsafe_set(dst, self.hi.unsafe_get(returned + i))
      }
      Continue
    }
    Tail => {
      let (regs, cf) = match self.stack.calls.peek() {
        // Case: return the caller's caller frame registers.
        Some(frame) => (frame.base_offset(), Continue)
        // Case: call stack is empty -> return the root frame registers.
        None => (0, Break)
      }
      let returned = self.stack.values.drop_return(max_inout)
      for i in 0..<len_results {
        // # Safety (1)
        //
        // We can safely acquire the stack pointer to the caller's and callee's (host)
        // call frames because we just allocated the host call frame and can be sure that
        // they are different.
        // In the following we make sure to not access registers out of bounds of each
        // call frame since we rely on Wasm validation and proper Wasm translation to
        // provide us with valid result registers.
        let dst = regs + results + i
        self.lo.unsafe_set(dst, self.lo.unsafe_get(returned + i))
        self.hi.unsafe_set(dst, self.hi.unsafe_get(returned + i))
      }
      self.stack.values.truncate(caller.frame_offset())
      let new_instance = match popped_instance {
        Some(_) => self.stack.calls.instance()
        None => None
      }
      if new_instance is Some(new_instance) {
        self.cache.update(store, new_instance)
      }
      if self.stack.calls.peek() is Some(caller) {
        self.init_call_frame(caller)
      }
      cf
    }
  }
}

///|
/// Convenience forwarder to [`dispatch_host_func`].
fn Executor::dispatch_host_func(
  self : Executor,
  store : StoreInner,
  host_func : HostFuncEntity,
  instance : Instance,
) -> Unit raise WasmiError {
  dispatch_host_func(store, self.stack.values, host_func, Some(instance))
}

///|
/// Executes an [`Op::ReturnCallIndirect0`].
fn Executor::execute_return_call_indirect_0(
  self : Executor,
  store : StoreInner,
  func_type : @ir.FuncType,
) -> ControlFlow raise WasmiError {
  let table = self.pull_call_indirect_params()
  let index = self.call_indirect_index
  self.execute_call_indirect_impl(
    Tail,
    false,
    store,
    None,
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::ReturnCallIndirect0Imm16`].
fn Executor::execute_return_call_indirect_0_imm16(
  self : Executor,
  store : StoreInner,
  func_type : @ir.FuncType,
) -> ControlFlow raise WasmiError {
  let table = self.pull_call_indirect_params_imm16()
  let index = self.call_indirect_index
  self.execute_call_indirect_impl(
    Tail,
    false,
    store,
    None,
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::ReturnCallIndirect`].
fn Executor::execute_return_call_indirect(
  self : Executor,
  store : StoreInner,
  func_type : @ir.FuncType,
) -> ControlFlow raise WasmiError {
  let table = self.pull_call_indirect_params()
  let index = self.call_indirect_index
  self.execute_call_indirect_impl(
    Tail,
    true,
    store,
    None,
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::ReturnCallIndirectImm16`].
fn Executor::execute_return_call_indirect_imm16(
  self : Executor,
  store : StoreInner,
  func_type : @ir.FuncType,
) -> ControlFlow raise WasmiError {
  let table = self.pull_call_indirect_params_imm16()
  let index = self.call_indirect_index
  self.execute_call_indirect_impl(
    Tail,
    true,
    store,
    None,
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::CallIndirect0`].
fn Executor::execute_call_indirect_0(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func_type : @ir.FuncType,
) -> Unit raise WasmiError {
  let table = self.pull_call_indirect_params()
  let index = self.call_indirect_index
  let _ = self.execute_call_indirect_impl(
    Nested,
    false,
    store,
    Some(results),
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::CallIndirect0Imm16`].
fn Executor::execute_call_indirect_0_imm16(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func_type : @ir.FuncType,
) -> Unit raise WasmiError {
  let table = self.pull_call_indirect_params_imm16()
  let index = self.call_indirect_index
  let _ = self.execute_call_indirect_impl(
    Nested,
    false,
    store,
    Some(results),
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::CallIndirect`].
fn Executor::execute_call_indirect(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func_type : @ir.FuncType,
) -> Unit raise WasmiError {
  let table = self.pull_call_indirect_params()
  let index = self.call_indirect_index
  let _ = self.execute_call_indirect_impl(
    Nested,
    true,
    store,
    Some(results),
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::CallIndirectImm16`].
fn Executor::execute_call_indirect_imm16(
  self : Executor,
  store : StoreInner,
  results : @ir.SlotSpan,
  func_type : @ir.FuncType,
) -> Unit raise WasmiError {
  let table = self.pull_call_indirect_params_imm16()
  let index = self.call_indirect_index
  let _ = self.execute_call_indirect_impl(
    Nested,
    true,
    store,
    Some(results),
    func_type,
    index,
    table,
  )
}

///|
/// Executes an [`Op::CallIndirect`] and [`Op::CallIndirect0`].
fn Executor::execute_call_indirect_impl(
  self : Executor,
  kind : CallKind,
  has_params : Bool,
  store : StoreInner,
  results : @ir.SlotSpan?,
  func_type : @ir.FuncType,
  index : UInt64,
  table : @ir.Table,
) -> ControlFlow raise WasmiError {
  let table = self.get_table(table)
  guard store.resolve_table(table).get_untyped(index) is Some(funcref) else {
    raise WasmiError::TrapCode(TableOutOfBounds)
  }
  guard store.funcref_from_untyped(funcref) is Some(func) else {
    raise WasmiError::TrapCode(IndirectCallToNull)
  }
  let actual_signature = store.resolve_func(func).ty_dedup()
  let expected_signature = self.get_func_type_dedup(func_type)
  if actual_signature != expected_signature {
    raise WasmiError::TrapCode(BadSignature)
  }
  self.execute_call_imported_impl(kind, has_params, store, results, func)
}
