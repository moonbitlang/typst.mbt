// Port of wasmi 1.0.9 `engine/executor/instrs/load.rs`.

///|
/// Executes an [`Op::V128Load`].
fn Executor::execute_v128_load(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load(memory.data(), memory.data_size(), address, offset)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128LoadAt`].
fn Executor::execute_v128_load_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128LoadOffset16`].
fn Executor::execute_v128_load_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8x8S`].
fn Executor::execute_v128_load8x8_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load8x8_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8x8_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load8x8SAt`].
fn Executor::execute_v128_load8x8_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load8x8_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8x8_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8x8SOffset16`].
fn Executor::execute_v128_load8x8_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load8x8_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8x8U`].
fn Executor::execute_v128_load8x8_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load8x8_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8x8_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load8x8UAt`].
fn Executor::execute_v128_load8x8_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load8x8_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8x8_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8x8UOffset16`].
fn Executor::execute_v128_load8x8_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load8x8_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load16x4S`].
fn Executor::execute_v128_load16x4_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load16x4_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16x4_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load16x4SAt`].
fn Executor::execute_v128_load16x4_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load16x4_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16x4_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load16x4SOffset16`].
fn Executor::execute_v128_load16x4_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load16x4_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load16x4U`].
fn Executor::execute_v128_load16x4_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load16x4_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16x4_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load16x4UAt`].
fn Executor::execute_v128_load16x4_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load16x4_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16x4_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load16x4UOffset16`].
fn Executor::execute_v128_load16x4_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load16x4_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32x2S`].
fn Executor::execute_v128_load32x2_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32x2_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32x2_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load32x2SAt`].
fn Executor::execute_v128_load32x2_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32x2_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32x2_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32x2SOffset16`].
fn Executor::execute_v128_load32x2_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load32x2_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32x2U`].
fn Executor::execute_v128_load32x2_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32x2_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32x2_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load32x2UAt`].
fn Executor::execute_v128_load32x2_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32x2_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32x2_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32x2UOffset16`].
fn Executor::execute_v128_load32x2_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load32x2_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8Splat`].
fn Executor::execute_v128_load8_splat(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load8_splat(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8_splat(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load8SplatAt`].
fn Executor::execute_v128_load8_splat_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load8_splat_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8_splat_at(
        memory.data(),
        memory.data_size(),
        address,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8SplatOffset16`].
fn Executor::execute_v128_load8_splat_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load8_splat(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load16Splat`].
fn Executor::execute_v128_load16_splat(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load16_splat(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16_splat(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load16SplatAt`].
fn Executor::execute_v128_load16_splat_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load16_splat_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16_splat_at(
        memory.data(),
        memory.data_size(),
        address,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load16SplatOffset16`].
fn Executor::execute_v128_load16_splat_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load16_splat(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32Splat`].
fn Executor::execute_v128_load32_splat(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32_splat(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32_splat(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load32SplatAt`].
fn Executor::execute_v128_load32_splat_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32_splat_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32_splat_at(
        memory.data(),
        memory.data_size(),
        address,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32SplatOffset16`].
fn Executor::execute_v128_load32_splat_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load32_splat(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load64Splat`].
fn Executor::execute_v128_load64_splat(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load64_splat(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load64_splat(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load64SplatAt`].
fn Executor::execute_v128_load64_splat_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load64_splat_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load64_splat_at(
        memory.data(),
        memory.data_size(),
        address,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load64SplatOffset16`].
fn Executor::execute_v128_load64_splat_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load64_splat(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32Zero`].
fn Executor::execute_v128_load32_zero(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32_zero(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32_zero(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load32ZeroAt`].
fn Executor::execute_v128_load32_zero_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load32_zero_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32_zero_at(
        memory.data(),
        memory.data_size(),
        address,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load32ZeroOffset16`].
fn Executor::execute_v128_load32_zero_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load32_zero(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load64Zero`].
fn Executor::execute_v128_load64_zero(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load64_zero(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load64_zero(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load64ZeroAt`].
fn Executor::execute_v128_load64_zero_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.v128_load64_zero_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load64_zero_at(
        memory.data(),
        memory.data_size(),
        address,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load64ZeroOffset16`].
fn Executor::execute_v128_load64_zero_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.v128_load64_zero(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::Load32`].
fn Executor::execute_load32(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.load32(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.load32(memory.data(), memory.data_size(), address, offset)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::Load32At`].
fn Executor::execute_load32_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.load32_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.load32_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::Load32Offset16`].
fn Executor::execute_load32_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.load32(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::Load64`].
fn Executor::execute_load64(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.load64(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.load64(memory.data(), memory.data_size(), address, offset)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::Load64At`].
fn Executor::execute_load64_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.load64_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.load64_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::Load64Offset16`].
fn Executor::execute_load64_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.load64(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_u64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load8s`].
fn Executor::execute_i32_load8_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load8_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load8_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Load8sAt`].
fn Executor::execute_i32_load8_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load8_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load8_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load8sOffset16`].
fn Executor::execute_i32_load8_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i32_load8_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load8u`].
fn Executor::execute_i32_load8_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load8_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load8_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Load8uAt`].
fn Executor::execute_i32_load8_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load8_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load8_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load8uOffset16`].
fn Executor::execute_i32_load8_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i32_load8_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load16s`].
fn Executor::execute_i32_load16_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load16_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load16_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Load16sAt`].
fn Executor::execute_i32_load16_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load16_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load16_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load16sOffset16`].
fn Executor::execute_i32_load16_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i32_load16_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load16u`].
fn Executor::execute_i32_load16_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load16_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load16_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32Load16uAt`].
fn Executor::execute_i32_load16_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i32_load16_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i32_load16_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32Load16uOffset16`].
fn Executor::execute_i32_load16_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i32_load16_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i32(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load8s`].
fn Executor::execute_i64_load8_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load8_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load8_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Load8sAt`].
fn Executor::execute_i64_load8_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load8_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load8_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load8sOffset16`].
fn Executor::execute_i64_load8_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i64_load8_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load8u`].
fn Executor::execute_i64_load8_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load8_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load8_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Load8uAt`].
fn Executor::execute_i64_load8_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load8_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load8_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load8uOffset16`].
fn Executor::execute_i64_load8_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i64_load8_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load16s`].
fn Executor::execute_i64_load16_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load16_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load16_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Load16sAt`].
fn Executor::execute_i64_load16_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load16_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load16_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load16sOffset16`].
fn Executor::execute_i64_load16_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i64_load16_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load16u`].
fn Executor::execute_i64_load16_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load16_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load16_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Load16uAt`].
fn Executor::execute_i64_load16_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load16_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load16_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load16uOffset16`].
fn Executor::execute_i64_load16_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i64_load16_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load32s`].
fn Executor::execute_i64_load32_s(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load32_s(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load32_s(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Load32sAt`].
fn Executor::execute_i64_load32_s_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load32_s_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load32_s_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load32sOffset16`].
fn Executor::execute_i64_load32_s_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i64_load32_s(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load32u`].
fn Executor::execute_i64_load32_u(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_load_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  let memory = self.fetch_optional_memory(2)
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  // execute_load_extend
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load32_u(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        offset,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load32_u(
        memory.data(),
        memory.data_size(),
        address,
        offset,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64Load32uAt`].
fn Executor::execute_i64_load32_u_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_load_at_impl
  let memory = self.fetch_optional_memory(1)
  // execute_load_extend_at
  let address = address.to_u64()
  let loaded_value = try {
    if memory.is_default() {
      @wasmi_core.i64_load32_u_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.i64_load32_u_at(memory.data(), memory.data_size(), address)
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64Load32uOffset16`].
fn Executor::execute_i64_load32_u_offset16(
  self : Executor,
  result : @ir.Slot,
  ptr : @ir.Slot,
  offset : @ir.Offset16,
) -> Unit raise WasmiError {
  // execute_load_offset16_impl
  let address = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  // execute_load_extend_mem0
  let loaded_value = @wasmi_core.i64_load32_u(
    self.cache.memory_data,
    self.cache.memory_len,
    address,
    offset,
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_i64(result, loaded_value)
  self.next_instr()
}
