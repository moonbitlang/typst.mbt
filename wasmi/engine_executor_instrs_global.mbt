// Port of wasmi 1.0.9 `engine/executor/instrs/global.rs`.

///|
/// Executes an [`Op::GlobalGet`].
fn Executor::execute_global_get(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  global : @ir.Global,
) -> Unit {
  let value = match global.0 {
    0 => self.cache.global.get_untyped()
    _ => {
      let global = self.get_global(global)
      store.resolve_global(global).get_untyped()
    }
  }
  self.set_stack_slot(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::GlobalSet`].
fn Executor::execute_global_set(
  self : Executor,
  store : StoreInner,
  global : @ir.Global,
  input : @ir.Slot,
) -> Unit {
  let input = self.get_stack_slot(input)
  self.execute_global_set_impl(store, global, input)
}

///|
/// Executes an [`Op::GlobalSetI32Imm16`].
fn Executor::execute_global_set_i32imm16(
  self : Executor,
  store : StoreInner,
  global : @ir.Global,
  input : @ir.Const16,
) -> Unit {
  let input = @wasmi_core.UntypedVal::from_i32(input.to_i32())
  self.execute_global_set_impl(store, global, input)
}

///|
/// Executes an [`Op::GlobalSetI64Imm16`].
fn Executor::execute_global_set_i64imm16(
  self : Executor,
  store : StoreInner,
  global : @ir.Global,
  input : @ir.Const16,
) -> Unit {
  let input = @wasmi_core.UntypedVal::from_i64(input.to_i64())
  self.execute_global_set_impl(store, global, input)
}

///|
/// Executes a generic `global.set` instruction.
fn Executor::execute_global_set_impl(
  self : Executor,
  store : StoreInner,
  global : @ir.Global,
  new_value : @wasmi_core.UntypedVal,
) -> Unit {
  match global.0 {
    0 => self.cache.global.set_untyped(new_value)
    _ => {
      let global = self.get_global(global)
      // Safety:
      // - Wasmi translation won't create `global.set` instructions for immutable globals.
      // - Wasm validation ensures that values with matching types are written to globals.
      store.resolve_global(global).set_untyped(new_value)
    }
  }
  self.next_instr()
}
