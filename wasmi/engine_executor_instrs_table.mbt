// Port of wasmi 1.0.9 `engine/executor/instrs/table.rs`.
//
// Table grows use the default (absent) resource limiter like the store does.

///|
/// Returns the [`Op::TableIndex`] parameter for an [`Op`].
fn Executor::fetch_table_index(self : Executor, offset : Int) -> @ir.Table {
  match self.instrs.unsafe_get(self.ip + offset) {
    TableIndex(index~) => index
    // Safety: Wasmi translation guarantees that [`Op::TableIndex`] exists.
    _ => abort("expected `Op::TableIndex`")
  }
}

///|
/// Returns the [`Op::ElemIndex`] parameter for an [`Op`].
fn Executor::fetch_element_segment_index(
  self : Executor,
  offset : Int,
) -> @ir.Elem {
  match self.instrs.unsafe_get(self.ip + offset) {
    ElemIndex(index~) => index
    // Safety: Wasmi translation guarantees that [`Op::ElemIndex`] exists.
    _ => abort("expected `Op::ElemIndex`")
  }
}

///|
/// Executes an [`Op::TableGet`].
fn Executor::execute_table_get(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  index : @ir.Slot,
) -> Unit raise WasmiError {
  let index : UInt64 = self.get_stack_slot_as_u64(index)
  self.execute_table_get_impl(store, result, index)
}

///|
/// Executes an [`Op::TableGetImm`].
fn Executor::execute_table_get_imm(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  index : @ir.Const32,
) -> Unit raise WasmiError {
  let index : UInt64 = index.to_u64()
  self.execute_table_get_impl(store, result, index)
}

///|
/// Executes a `table.get` instruction generically.
fn Executor::execute_table_get_impl(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  index : UInt64,
) -> Unit raise WasmiError {
  let table_index = self.fetch_table_index(1)
  let table = self.get_table(table_index)
  guard store.resolve_table(table).get_untyped(index) is Some(value) else {
    raise WasmiError::TrapCode(TableOutOfBounds)
  }
  self.set_stack_slot(result, value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::TableSize`].
fn Executor::execute_table_size(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  table_index : @ir.Table,
) -> Unit {
  self.execute_table_size_impl(store, result, table_index)
  self.next_instr()
}

///|
/// Executes a generic `table.size` instruction.
fn Executor::execute_table_size_impl(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  table_index : @ir.Table,
) -> Unit {
  let table = self.get_table(table_index)
  let size = store.resolve_table(table).size()
  self.set_stack_slot(result, @wasmi_core.UntypedVal::from_u64(size))
}

///|
/// Executes an [`Op::TableSet`].
fn Executor::execute_table_set(
  self : Executor,
  store : StoreInner,
  index : @ir.Slot,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  let index : UInt64 = self.get_stack_slot_as_u64(index)
  self.execute_table_set_impl(store, index, value)
}

///|
/// Executes an [`Op::TableSetAt`].
fn Executor::execute_table_set_at(
  self : Executor,
  store : StoreInner,
  index : @ir.Const32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  let index : UInt64 = index.to_u64()
  self.execute_table_set_impl(store, index, value)
}

///|
/// Executes a generic `table.set` instruction.
fn Executor::execute_table_set_impl(
  self : Executor,
  store : StoreInner,
  index : UInt64,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  let table_index = self.fetch_table_index(1)
  let table = self.get_table(table_index)
  let value = self.get_stack_slot(value)
  store.resolve_table(table).set_untyped(index, value) catch {
    _ => raise WasmiError::TrapCode(TableOutOfBounds)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::TableCopy`].
fn Executor::execute_table_copy(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  src : @ir.Slot,
  len : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let src : UInt64 = self.get_stack_slot_as_u64(src)
  let len : UInt64 = self.get_stack_slot_as_u64(len)
  let dst_table_index = self.fetch_table_index(1)
  let src_table_index = self.fetch_table_index(2)
  if dst_table_index == src_table_index {
    // Case: copy within the same table
    let table = self.get_table(dst_table_index)
    let fuel = store.fuel()
    store.resolve_table(table).copy_within(dst, src, len, Some(fuel)) catch {
      e => raise WasmiError::Table(e)
    }
  } else {
    // Case: copy between two different tables
    let dst_table = self.get_table(dst_table_index)
    let src_table = self.get_table(src_table_index)
    // Copy from one table to another table:
    let dst_table = store.resolve_table(dst_table)
    let src_table = store.resolve_table(src_table)
    let fuel = store.fuel()
    @wasmi_core.Table::copy(dst_table, dst, src_table, src, len, Some(fuel)) catch {
      e => raise WasmiError::Table(e)
    }
  }
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::TableInit`].
fn Executor::execute_table_init(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  src : @ir.Slot,
  len : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let src : UInt = self.get_stack_slot_as_u32(src)
  let len : UInt = self.get_stack_slot_as_u32(len)
  let table_index = self.fetch_table_index(1)
  let element_index = self.fetch_element_segment_index(2)
  let table = store.resolve_table(self.get_table(table_index))
  let element = store.resolve_element(self.get_element_segment(element_index))
  let fuel = store.fuel()
  table.init(element.as_ref(), dst, src, len, Some(fuel)) catch {
    e => raise WasmiError::Table(e)
  }
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::TableFill`].
fn Executor::execute_table_fill(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  len : @ir.Slot,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let len : UInt64 = self.get_stack_slot_as_u64(len)
  let table_index = self.fetch_table_index(1)
  let value = self.get_stack_slot(value)
  let table = self.get_table(table_index)
  let fuel = store.fuel()
  store.resolve_table(table).fill_untyped(dst, value, len, Some(fuel)) catch {
    e => raise WasmiError::Table(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::TableGrow`].
fn Executor::execute_table_grow(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  delta : @ir.Slot,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  let delta : UInt64 = self.get_stack_slot_as_u64(delta)
  let table_index = self.fetch_table_index(1)
  if delta == 0 {
    // Case: growing by 0 elements means there is nothing to do
    self.execute_table_size_impl(store, result, table_index)
    return self.next_instr_at(2)
  }
  let table = self.get_table(table_index)
  let value = self.get_stack_slot(value)
  let entity = store.resolve_table(table)
  let return_value = try
    entity.grow_untyped(
      delta,
      value,
      Some(store.fuel()),
      @wasmi_core.ResourceLimiterRef::default(),
    )
  catch {
    GrowOutOfBounds | OutOfSystemMemory => {
      let table_ty = entity.ty()
      if table_ty.is_64() {
        0xFFFF_FFFF_FFFF_FFFFUL
      } else {
        0xFFFF_FFFFUL
      }
    }
    OutOfFuel(required_fuel~) =>
      // Upstream: `ResumableOutOfFuelError` (unwrapped to a fuel error by
      // non-resumable executions).
      raise WasmiError::Fuel(@wasmi_core.FuelError::out_of_fuel(required_fuel))
    ResourceLimiterDeniedAllocation =>
      raise WasmiError::TrapCode(GrowthOperationLimited)
    error => abort("`memory.grow`: internal interpreter error: \{error}")
  } noraise {
    return_value => return_value
  }
  self.set_stack_slot(result, @wasmi_core.UntypedVal::from_u64(return_value))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::ElemDrop`].
fn Executor::execute_element_drop(
  self : Executor,
  store : StoreInner,
  segment_index : @ir.Elem,
) -> Unit {
  let segment = self.get_element_segment(segment_index)
  store.resolve_element(segment).drop_items()
  self.next_instr()
}
