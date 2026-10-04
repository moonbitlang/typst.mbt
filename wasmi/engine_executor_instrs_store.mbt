// Port of wasmi 1.0.9 `engine/executor/instrs/store.rs`.

///|
/// Executes an [`Op::V128Store`].
fn Executor::execute_v128_store(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_v128(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.v128_store(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128StoreOffset16`].
fn Executor::execute_v128_store_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_v128(value)
  // execute_store_wrap_mem0
  @wasmi_core.v128_store(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::V128StoreAt`].
fn Executor::execute_v128_store_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_v128(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.v128_store_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::Store32`].
fn Executor::execute_store32(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_u32(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.store32(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store32(memory.data(), memory.data_size(), ptr, offset, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::Store32Offset16`].
fn Executor::execute_store32_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_u32(value)
  // execute_store_wrap_mem0
  @wasmi_core.store32(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::Store32At`].
fn Executor::execute_store32_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_u32(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.store32_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store32_at(memory.data(), memory.data_size(), address, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::Store64`].
fn Executor::execute_store64(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_u64(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.store64(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store64(memory.data(), memory.data_size(), ptr, offset, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::Store64Offset16`].
fn Executor::execute_store64_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_u64(value)
  // execute_store_wrap_mem0
  @wasmi_core.store64(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::Store64At`].
fn Executor::execute_store64_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_u64(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.store64_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store64_at(memory.data(), memory.data_size(), address, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32StoreImm16`].
fn Executor::execute_i32_store_imm16(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i32().reinterpret_as_uint()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.store32(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store32(memory.data(), memory.data_size(), ptr, offset, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32StoreOffset16Imm16`].
fn Executor::execute_i32_store_offset16_imm16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Const16,
) -> Unit raise WasmiError {
  let value = value.to_i32().reinterpret_as_uint()
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.store32(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32StoreAtImm16`].
fn Executor::execute_i32_store_at_imm16(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Const16,
) -> Unit raise WasmiError {
  let value = value.to_i32().reinterpret_as_uint()
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.store32_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store32_at(memory.data(), memory.data_size(), address, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64StoreImm16`].
fn Executor::execute_i64_store_imm16(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i64().reinterpret_as_uint64()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.store64(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store64(memory.data(), memory.data_size(), ptr, offset, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64StoreOffset16Imm16`].
fn Executor::execute_i64_store_offset16_imm16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Const16,
) -> Unit raise WasmiError {
  let value = value.to_i64().reinterpret_as_uint64()
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.store64(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64StoreAtImm16`].
fn Executor::execute_i64_store_at_imm16(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Const16,
) -> Unit raise WasmiError {
  let value = value.to_i64().reinterpret_as_uint64()
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.store64_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.store64_at(memory.data(), memory.data_size(), address, value)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store8Imm`].
fn Executor::execute_i32_store8_imm(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i8()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.i32_store8(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store8(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Store8Offset16Imm`].
fn Executor::execute_i32_store8_offset16_imm(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : Int,
) -> Unit raise WasmiError {
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.i32_store8(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store8AtImm`].
fn Executor::execute_i32_store8_at_imm(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : Int,
) -> Unit raise WasmiError {
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.i32_store8_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store8_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store8`].
fn Executor::execute_i32_store8(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i32(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.i32_store8(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store8(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Store8Offset16`].
fn Executor::execute_i32_store8_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i32(value)
  // execute_store_wrap_mem0
  @wasmi_core.i32_store8(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store8At`].
fn Executor::execute_i32_store8_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_i32(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.i32_store8_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store8_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store16Imm`].
fn Executor::execute_i32_store16_imm(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i16()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.i32_store16(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store16(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Store16Offset16Imm`].
fn Executor::execute_i32_store16_offset16_imm(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : Int,
) -> Unit raise WasmiError {
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.i32_store16(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store16AtImm`].
fn Executor::execute_i32_store16_at_imm(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : Int,
) -> Unit raise WasmiError {
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.i32_store16_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store16_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store16`].
fn Executor::execute_i32_store16(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i32(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.i32_store16(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store16(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Store16Offset16`].
fn Executor::execute_i32_store16_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i32(value)
  // execute_store_wrap_mem0
  @wasmi_core.i32_store16(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I32Store16At`].
fn Executor::execute_i32_store16_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_i32(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.i32_store16_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_store16_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store8Imm`].
fn Executor::execute_i64_store8_imm(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i8().to_int64()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.i64_store8(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store8(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Store8Offset16Imm`].
fn Executor::execute_i64_store8_offset16_imm(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : Int,
) -> Unit raise WasmiError {
  let value = value.to_int64()
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.i64_store8(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store8AtImm`].
fn Executor::execute_i64_store8_at_imm(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : Int,
) -> Unit raise WasmiError {
  let value = value.to_int64()
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.i64_store8_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store8_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store8`].
fn Executor::execute_i64_store8(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i64(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.i64_store8(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store8(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Store8Offset16`].
fn Executor::execute_i64_store8_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i64(value)
  // execute_store_wrap_mem0
  @wasmi_core.i64_store8(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store8At`].
fn Executor::execute_i64_store8_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_i64(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.i64_store8_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store8_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store16Imm`].
fn Executor::execute_i64_store16_imm(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i16().to_int64()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.i64_store16(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store16(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Store16Offset16Imm`].
fn Executor::execute_i64_store16_offset16_imm(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : Int,
) -> Unit raise WasmiError {
  let value = value.to_int64()
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.i64_store16(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store16AtImm`].
fn Executor::execute_i64_store16_at_imm(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : Int,
) -> Unit raise WasmiError {
  let value = value.to_int64()
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.i64_store16_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store16_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store16`].
fn Executor::execute_i64_store16(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i64(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.i64_store16(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store16(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Store16Offset16`].
fn Executor::execute_i64_store16_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i64(value)
  // execute_store_wrap_mem0
  @wasmi_core.i64_store16(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store16At`].
fn Executor::execute_i64_store16_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_i64(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.i64_store16_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store16_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store32Imm16`].
fn Executor::execute_i64_store32_imm16(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // fetch_value_and_offset_imm
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let value = imm16.to_i32().to_int64()
  let offset_hi = @ir.Offset64Hi(imm32.to_u32())
  // execute_store_imm
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  try {
    if memory.is_default() {
      @wasmi_core.i64_store32(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store32(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Store32Offset16Imm16`].
fn Executor::execute_i64_store32_offset16_imm16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Const16,
) -> Unit raise WasmiError {
  let value = value.to_i32().to_int64()
  // execute_store_offset16_imm16
  let ptr = self.get_stack_slot_as_u64(ptr)
  @wasmi_core.i64_store32(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store32AtImm16`].
fn Executor::execute_i64_store32_at_imm16(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Const16,
) -> Unit raise WasmiError {
  let value = value.to_i32().to_int64()
  // execute_store_at_imm16
  let memory = self.fetch_optional_memory(1)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.i64_store32_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store32_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store32`].
fn Executor::execute_i64_store32(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_store
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i64(value)
  // execute_store_wrap
  try {
    if memory.is_default() {
      @wasmi_core.i64_store32(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store32(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Store32Offset16`].
fn Executor::execute_i64_store32_offset16(
  self : Executor,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_offset16
  let ptr = self.get_stack_slot_as_u64(ptr)
  let value = self.get_stack_slot_as_i64(value)
  // execute_store_wrap_mem0
  @wasmi_core.i64_store32(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset.to_u64(),
    value,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::I64Store32At`].
fn Executor::execute_i64_store32_at(
  self : Executor,
  store : StoreInner,
  address : @ir.Address32,
  value : @ir.Slot,
) -> Unit raise WasmiError {
  // execute_store_at
  let memory = self.fetch_optional_memory(1)
  let value = self.get_stack_slot_as_i64(value)
  let address = address.to_u64()
  // execute_store_wrap_at
  try {
    if memory.is_default() {
      @wasmi_core.i64_store32_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        value,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_store32_at(
        memory.data(),
        memory.data_size(),
        address,
        value,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}
