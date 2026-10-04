// Port of wasmi 1.0.9 `engine/executor/instrs/memory.rs`.
//
// Upstream converts the `u64` operands with `usize::try_from` (infallible on
// 64-bit targets) and bounds checks with slice accesses
// (`memory.get(index..).and_then(|memory| memory.get(..len))`), see
// `slice_in_bounds`. Memory grows use the default (absent) resource limiter
// like the store does.

///|
/// Returns `true` if `memory[index..][..len]` is in bounds for a buffer of
/// `size` bytes (or elements).
fn slice_in_bounds(size : Int, index : UInt64, len : UInt64) -> Bool {
  let size = size.to_uint64()
  index <= size && len <= size - index
}

///|
/// Returns the [`Op::MemoryIndex`] parameter for an [`Op`].
fn Executor::fetch_memory_index(self : Executor, offset : Int) -> @ir.Memory {
  match self.instrs.unsafe_get(self.ip + offset) {
    MemoryIndex(index~) => index
    // Safety: Wasmi translation guarantees that [`Op::MemoryIndex`] exists.
    _ => abort("expected `Op::MemoryIndex`")
  }
}

///|
/// Returns the [`Op::DataIndex`] parameter for an [`Op`].
fn Executor::fetch_data_segment_index(
  self : Executor,
  offset : Int,
) -> @ir.Data {
  match self.instrs.unsafe_get(self.ip + offset) {
    DataIndex(index~) => index
    // Safety: Wasmi translation guarantees that [`Op::DataIndex`] exists.
    _ => abort("expected `Op::DataIndex`")
  }
}

///|
/// Executes an [`Op::DataDrop`].
fn Executor::execute_data_drop(
  self : Executor,
  store : StoreInner,
  segment_index : @ir.Data,
) -> Unit {
  let segment = self.get_data_segment(segment_index)
  store.resolve_data(segment).drop_bytes()
  self.next_instr()
}

///|
/// Executes an [`Op::MemorySize`].
fn Executor::execute_memory_size(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  memory : @ir.Memory,
) -> Unit {
  self.execute_memory_size_impl(store, result, memory)
  self.next_instr()
}

///|
/// Underlying implementation of [`Op::MemorySize`].
fn Executor::execute_memory_size_impl(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  memory : @ir.Memory,
) -> Unit {
  let memory = self.get_memory(memory)
  let size = store.resolve_memory(memory).size()
  self.set_stack_slot(result, @wasmi_core.UntypedVal::from_u64(size))
}

///|
/// Executes an [`Op::MemoryGrow`].
fn Executor::execute_memory_grow(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  delta : @ir.Slot,
) -> Unit raise WasmiError {
  let delta : UInt64 = self.get_stack_slot_as_u64(delta)
  let memory = self.fetch_memory_index(1)
  if delta == 0 {
    // Case: growing by 0 pages means there is nothing to do
    self.execute_memory_size_impl(store, result, memory)
    return self.next_instr_at(2)
  }
  let memory = self.get_memory(memory)
  let entity = store.resolve_memory(memory)
  let return_value = try
    entity.grow(
      delta,
      Some(store.fuel()),
      @wasmi_core.ResourceLimiterRef::default(),
    )
  catch {
    OutOfBoundsGrowth | OutOfSystemMemory => {
      let memory_ty = entity.ty()
      if memory_ty.is_64() {
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
    error => abort("`table.grow`: internal interpreter error: \{error}")
  } noraise {
    return_value => {
      // The `memory.grow` operation might have invalidated the cached
      // linear memory so we need to reset it in order for the cache to
      // reload in case it is used again.
      //
      // Safety: the instance has not changed thus calling this is valid.
      self.cache.update_memory(store)
      return_value
    }
  }
  self.set_stack_slot(result, @wasmi_core.UntypedVal::from_u64(return_value))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::MemoryCopy`].
fn Executor::execute_memory_copy(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  src : @ir.Slot,
  len : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let src : UInt64 = self.get_stack_slot_as_u64(src)
  let len : UInt64 = self.get_stack_slot_as_u64(len)
  let dst_index = dst
  let src_index = src
  let dst_memory = self.fetch_memory_index(1)
  let src_memory = self.fetch_memory_index(2)
  if src_memory == dst_memory {
    return self.execute_memory_copy_within_impl(
      store, src_memory, dst_index, src_index, len,
    )
  }
  let src_memory = store.resolve_memory(self.get_memory(src_memory))
  let dst_memory = store.resolve_memory(self.get_memory(dst_memory))
  let fuel = store.fuel()
  // These accesses just perform the bounds checks required by the Wasm spec.
  if !slice_in_bounds(src_memory.data_size(), src_index, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  if !slice_in_bounds(dst_memory.data_size(), dst_index, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  fuel.consume_fuel_if(costs => costs.fuel_for_copying_bytes(len)) catch {
    e => raise WasmiError::Fuel(e)
  }
  FixedArray::unsafe_blit(
    dst_memory.data(),
    dst_index.to_int(),
    src_memory.data(),
    src_index.to_int(),
    len.to_int(),
  )
  self.next_instr_at(3)
}

///|
/// Executes a generic `memory.copy` instruction.
fn Executor::execute_memory_copy_within_impl(
  self : Executor,
  store : StoreInner,
  memory : @ir.Memory,
  dst_index : UInt64,
  src_index : UInt64,
  len : UInt64,
) -> Unit raise WasmiError {
  let memory = store.resolve_memory(self.get_memory(memory))
  let fuel = store.fuel()
  let size = memory.data_size()
  // These accesses just perform the bounds checks required by the Wasm spec.
  if !slice_in_bounds(size, src_index, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  if !slice_in_bounds(size, dst_index, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  fuel.consume_fuel_if(costs => costs.fuel_for_copying_bytes(len)) catch {
    e => raise WasmiError::Fuel(e)
  }
  let bytes = memory.data()
  FixedArray::unsafe_blit(
    bytes,
    dst_index.to_int(),
    bytes,
    src_index.to_int(),
    len.to_int(),
  )
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::MemoryFill`].
fn Executor::execute_memory_fill(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  value : @ir.Slot,
  len : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let value : Byte = self.get_stack_slot_as_u64(value).to_byte()
  let len : UInt64 = self.get_stack_slot_as_u64(len)
  self.execute_memory_fill_impl(store, dst, value, len)
}

///|
/// Executes an [`Op::MemoryFillImm`].
fn Executor::execute_memory_fill_imm(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  value : Int,
  len : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let len : UInt64 = self.get_stack_slot_as_u64(len)
  self.execute_memory_fill_impl(store, dst, value.to_byte(), len)
}

///|
/// Executes a generic `memory.fill` instruction.
fn Executor::execute_memory_fill_impl(
  self : Executor,
  store : StoreInner,
  dst : UInt64,
  value : Byte,
  len : UInt64,
) -> Unit raise WasmiError {
  let memory = self.fetch_memory_index(1)
  let memory = store.resolve_memory(self.get_memory(memory))
  let fuel = store.fuel()
  if !slice_in_bounds(memory.data_size(), dst, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  fuel.consume_fuel_if(costs => costs.fuel_for_copying_bytes(len)) catch {
    e => raise WasmiError::Fuel(e)
  }
  if len > 0 {
    let start = dst.to_int()
    memory.data().fill(value, start~, end=start + len.to_int())
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::MemoryInit`].
fn Executor::execute_memory_init(
  self : Executor,
  store : StoreInner,
  dst : @ir.Slot,
  src : @ir.Slot,
  len : @ir.Slot,
) -> Unit raise WasmiError {
  let dst : UInt64 = self.get_stack_slot_as_u64(dst)
  let src : UInt = self.get_stack_slot_as_u32(src)
  let len : UInt = self.get_stack_slot_as_u32(len)
  let dst_index = dst
  let src_index = src.to_uint64()
  let len = len.to_uint64()
  let memory_index : @ir.Memory = self.fetch_memory_index(1)
  let data_index : @ir.Data = self.fetch_data_segment_index(2)
  let memory = store.resolve_memory(self.get_memory(memory_index))
  let data = store.resolve_data(self.get_data_segment(data_index))
  let fuel = store.fuel()
  if !slice_in_bounds(memory.data_size(), dst_index, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  let data = data.bytes()
  if !slice_in_bounds(data.length(), src_index, len) {
    raise WasmiError::TrapCode(MemoryOutOfBounds)
  }
  fuel.consume_fuel_if(costs => costs.fuel_for_copying_bytes(len)) catch {
    e => raise WasmiError::Fuel(e)
  }
  if len > 0 {
    memory
    .data()
    .blit_from_bytes(dst_index.to_int(), data, src_index.to_int(), len.to_int())
  }
  self.next_instr_at(3)
}
