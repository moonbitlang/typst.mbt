// Port of wasmi 1.0.9 `engine/executor/instrs/simd.rs`.

///|
/// Converts an IR lane index into a `@wasmi_core.ImmLaneIdx2`.
fn lane_idx2(lane : Int) -> @wasmi_core.ImmLaneIdx2 {
  @wasmi_core.ImmLaneIdx2(lane.to_byte())
}

///|
/// Converts an IR lane index into a `@wasmi_core.ImmLaneIdx4`.
fn lane_idx4(lane : Int) -> @wasmi_core.ImmLaneIdx4 {
  @wasmi_core.ImmLaneIdx4(lane.to_byte())
}

///|
/// Converts an IR lane index into a `@wasmi_core.ImmLaneIdx8`.
fn lane_idx8(lane : Int) -> @wasmi_core.ImmLaneIdx8 {
  @wasmi_core.ImmLaneIdx8(lane.to_byte())
}

///|
/// Converts an IR lane index into a `@wasmi_core.ImmLaneIdx16`.
fn lane_idx16(lane : Int) -> @wasmi_core.ImmLaneIdx16 {
  @wasmi_core.ImmLaneIdx16(lane.to_byte())
}

///|
/// Fetches a [`Slot`] from an [`Op::Slot`] instruction parameter.
fn Executor::fetch_register(self : Executor) -> @ir.Slot {
  match self.instrs.unsafe_get(self.ip + 1) {
    Slot(slot~) => slot
    // Safety: Wasmi translation guarantees that [`Op::Slot`] exists.
    _ => abort("expected `Op::Slot`")
  }
}

///|
/// Fetches the value of an [`Op::Const32`] instruction parameter.
fn Executor::fetch_const32(self : Executor) -> @ir.AnyConst32 {
  match self.instrs.unsafe_get(self.ip + 1) {
    Const32(value~) => value
    // Safety: Wasmi translation guarantees that [`Op::Const32`] exists.
    _ => abort("expected `Op::Const32`")
  }
}

///|
/// Fetches the value of an [`Op::I64Const32`] instruction parameter.
fn Executor::fetch_i64const32(self : Executor) -> Int64 {
  match self.instrs.unsafe_get(self.ip + 1) {
    I64Const32(value~) => value.to_i64()
    // Safety: Wasmi translation guarantees that [`Op::I64Const32`] exists.
    _ => abort("expected `Op::I64Const32`")
  }
}

///|
/// Fetches the value of an [`Op::F64Const32`] instruction parameter.
fn Executor::fetch_f64const32(self : Executor) -> Double {
  match self.instrs.unsafe_get(self.ip + 1) {
    F64Const32(value~) => value.to_f64_bits().reinterpret_as_double()
    // Safety: Wasmi translation guarantees that [`Op::F64Const32`] exists.
    _ => abort("expected `Op::F64Const32`")
  }
}

///|
/// Executes an [`Op::I8x16Shuffle`] instruction.
fn Executor::execute_i8x16_shuffle(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let selector = self.fetch_register()
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let selector = self.get_stack_slot_as_v128(selector).to_le_bytes()
  // Safety: Wasmi translation guarantees that the indices are within bounds.
  let selector = FixedArray::makei(16, i => {
    @wasmi_core.ImmLaneIdx32(selector[i])
  })
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.i8x16_shuffle(lhs, rhs, selector),
  )
  self.next_instr_at(2)
}

///|
/// Generically execute a SIMD replace lane instruction.
fn Executor::execute_replace_lane_impl(
  self : Executor,
  result : @ir.Slot,
  value : @wasmi_core.V128Value,
  delta : Int,
) -> Unit {
  self.set_stack_slot_as_v128(result, value)
  self.next_instr_at(delta)
}

///|
/// Executes an [`Op::I8x16ReplaceLaneImm`] instruction.
fn Executor::execute_i8x16_replace_lane_imm(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
  value : Int,
) -> Unit {
  let input = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i8x16_replace_lane(input, lane_idx16(lane.0), value)
  self.execute_replace_lane_impl(result, value, 1)
}

///|
/// Executes an [`Op::I16x8ReplaceLaneImm`] instruction.
fn Executor::execute_i16x8_replace_lane_imm(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_const32().to_i32()
  let input = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_replace_lane(input, lane_idx8(lane.0), value)
  self.execute_replace_lane_impl(result, value, 2)
}

///|
/// Executes an [`Op::I32x4ReplaceLaneImm`] instruction.
fn Executor::execute_i32x4_replace_lane_imm(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_const32().to_i32()
  let input = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_replace_lane(input, lane_idx4(lane.0), value)
  self.execute_replace_lane_impl(result, value, 2)
}

///|
/// Executes an [`Op::I64x2ReplaceLaneImm32`] instruction.
fn Executor::execute_i64x2_replace_lane_imm32(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_i64const32()
  let input = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_replace_lane(input, lane_idx2(lane.0), value)
  self.execute_replace_lane_impl(result, value, 2)
}

///|
/// Executes an [`Op::F32x4ReplaceLaneImm`] instruction.
fn Executor::execute_f32x4_replace_lane_imm(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = Float::reinterpret_from_uint(self.fetch_const32().to_f32_bits())
  let input = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_replace_lane(input, lane_idx4(lane.0), value)
  self.execute_replace_lane_impl(result, value, 2)
}

///|
/// Executes an [`Op::F64x2ReplaceLaneImm32`] instruction.
fn Executor::execute_f64x2_replace_lane_imm32(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_f64const32()
  let input = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_replace_lane(input, lane_idx2(lane.0), value)
  self.execute_replace_lane_impl(result, value, 2)
}

///|
/// Executes an [`Op::V128Bitselect`].
fn Executor::execute_v128_bitselect(
  self : Executor,
  result : @ir.Slot,
  a : @ir.Slot,
  b : @ir.Slot,
) -> Unit {
  let c = self.fetch_register()
  let a = self.get_stack_slot_as_v128(a)
  let b = self.get_stack_slot_as_v128(b)
  let c = self.get_stack_slot_as_v128(c)
  self.set_stack_slot_as_v128(result, @wasmi_core.v128_bitselect(a, b, c))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32x4RelaxedDotI8x16I7x16AddS`].
fn Executor::execute_i32x4_relaxed_dot_i8x16_i7x16_add_s(
  self : Executor,
  result : @ir.Slot,
  a : @ir.Slot,
  b : @ir.Slot,
) -> Unit {
  let c = self.fetch_register()
  let a = self.get_stack_slot_as_v128(a)
  let b = self.get_stack_slot_as_v128(b)
  let c = self.get_stack_slot_as_v128(c)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.i32x4_relaxed_dot_i8x16_i7x16_add_s(a, b, c),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::F32x4RelaxedMadd`].
fn Executor::execute_f32x4_relaxed_madd(
  self : Executor,
  result : @ir.Slot,
  a : @ir.Slot,
  b : @ir.Slot,
) -> Unit {
  let c = self.fetch_register()
  let a = self.get_stack_slot_as_v128(a)
  let b = self.get_stack_slot_as_v128(b)
  let c = self.get_stack_slot_as_v128(c)
  self.set_stack_slot_as_v128(result, @wasmi_core.f32x4_relaxed_madd(a, b, c))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::F32x4RelaxedNmadd`].
fn Executor::execute_f32x4_relaxed_nmadd(
  self : Executor,
  result : @ir.Slot,
  a : @ir.Slot,
  b : @ir.Slot,
) -> Unit {
  let c = self.fetch_register()
  let a = self.get_stack_slot_as_v128(a)
  let b = self.get_stack_slot_as_v128(b)
  let c = self.get_stack_slot_as_v128(c)
  self.set_stack_slot_as_v128(result, @wasmi_core.f32x4_relaxed_nmadd(a, b, c))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::F64x2RelaxedMadd`].
fn Executor::execute_f64x2_relaxed_madd(
  self : Executor,
  result : @ir.Slot,
  a : @ir.Slot,
  b : @ir.Slot,
) -> Unit {
  let c = self.fetch_register()
  let a = self.get_stack_slot_as_v128(a)
  let b = self.get_stack_slot_as_v128(b)
  let c = self.get_stack_slot_as_v128(c)
  self.set_stack_slot_as_v128(result, @wasmi_core.f64x2_relaxed_madd(a, b, c))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::F64x2RelaxedNmadd`].
fn Executor::execute_f64x2_relaxed_nmadd(
  self : Executor,
  result : @ir.Slot,
  a : @ir.Slot,
  b : @ir.Slot,
) -> Unit {
  let c = self.fetch_register()
  let a = self.get_stack_slot_as_v128(a)
  let b = self.get_stack_slot_as_v128(b)
  let c = self.get_stack_slot_as_v128(c)
  self.set_stack_slot_as_v128(result, @wasmi_core.f64x2_relaxed_nmadd(a, b, c))
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I8x16ReplaceLane`].
fn Executor::execute_i8x16_replace_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_register()
  let input = self.get_stack_slot_as_v128(input)
  let value = self.get_stack_slot_as_i32(value)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.i8x16_replace_lane(input, lane_idx16(lane.0), value),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I16x8ReplaceLane`].
fn Executor::execute_i16x8_replace_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_register()
  let input = self.get_stack_slot_as_v128(input)
  let value = self.get_stack_slot_as_i32(value)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.i16x8_replace_lane(input, lane_idx8(lane.0), value),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I32x4ReplaceLane`].
fn Executor::execute_i32x4_replace_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_register()
  let input = self.get_stack_slot_as_v128(input)
  let value = self.get_stack_slot_as_i32(value)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.i32x4_replace_lane(input, lane_idx4(lane.0), value),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I64x2ReplaceLane`].
fn Executor::execute_i64x2_replace_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_register()
  let input = self.get_stack_slot_as_v128(input)
  let value = self.get_stack_slot_as_i64(value)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.i64x2_replace_lane(input, lane_idx2(lane.0), value),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::F32x4ReplaceLane`].
fn Executor::execute_f32x4_replace_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_register()
  let input = self.get_stack_slot_as_v128(input)
  let value = self.get_stack_slot_as_f32(value)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.f32x4_replace_lane(input, lane_idx4(lane.0), value),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::F64x2ReplaceLane`].
fn Executor::execute_f64x2_replace_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  let value = self.fetch_register()
  let input = self.get_stack_slot_as_v128(input)
  let value = self.get_stack_slot_as_f64(value)
  self.set_stack_slot_as_v128(
    result,
    @wasmi_core.f64x2_replace_lane(input, lane_idx2(lane.0), value),
  )
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::I8x16ExtractLaneS`].
fn Executor::i8x16_extract_lane_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_i32(
    result,
    @wasmi_core.i8x16_extract_lane_s(input, lane_idx16(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16ExtractLaneU`].
fn Executor::i8x16_extract_lane_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_u32(
    result,
    @wasmi_core.i8x16_extract_lane_u(input, lane_idx16(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtractLaneS`].
fn Executor::i16x8_extract_lane_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_i32(
    result,
    @wasmi_core.i16x8_extract_lane_s(input, lane_idx8(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtractLaneU`].
fn Executor::i16x8_extract_lane_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_u32(
    result,
    @wasmi_core.i16x8_extract_lane_u(input, lane_idx8(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtractLane`].
fn Executor::i32x4_extract_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_i32(
    result,
    @wasmi_core.i32x4_extract_lane(input, lane_idx4(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4ExtractLane`].
fn Executor::f32x4_extract_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_f32(
    result,
    @wasmi_core.f32x4_extract_lane(input, lane_idx4(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ExtractLane`].
fn Executor::i64x2_extract_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_i64(
    result,
    @wasmi_core.i64x2_extract_lane(input, lane_idx2(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2ExtractLane`].
fn Executor::f64x2_extract_lane(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
  lane : @ir.ImmLaneIdx,
) -> Unit {
  // execute_extract_lane
  let input = self.get_stack_slot_as_v128(input)
  self.set_stack_slot_as_f64(
    result,
    @wasmi_core.f64x2_extract_lane(input, lane_idx2(lane.0)),
  )
  self.next_instr()
}

///|
/// Executes an [`Op::V128Load8Lane`] instruction.
fn Executor::execute_v128_load8_lane(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx16(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(3)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(v128)
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load8_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Load16Lane`] instruction.
fn Executor::execute_v128_load16_lane(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx8(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(3)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(v128)
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load16_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Load32Lane`] instruction.
fn Executor::execute_v128_load32_lane(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx4(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(3)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(v128)
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load32_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Load64Lane`] instruction.
fn Executor::execute_v128_load64_lane(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=ptr, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx2(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(3)
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(v128)
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load64_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load64_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Load8LaneAt`] instruction.
fn Executor::execute_v128_load8_lane_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_at_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx16(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(2)
  let v128 = self.get_stack_slot_as_v128(v128)
  let address = address.to_u64()
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load8_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load8_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load16LaneAt`] instruction.
fn Executor::execute_v128_load16_lane_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_at_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx8(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(2)
  let v128 = self.get_stack_slot_as_v128(v128)
  let address = address.to_u64()
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load16_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load16_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load32LaneAt`] instruction.
fn Executor::execute_v128_load32_lane_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_at_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx4(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(2)
  let v128 = self.get_stack_slot_as_v128(v128)
  let address = address.to_u64()
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load32_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load32_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Load64LaneAt`] instruction.
fn Executor::execute_v128_load64_lane_at(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_load_lane_at_impl
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=v128, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let lane = lane_idx2(imm.to_i32() & 0xFF)
  let memory = self.fetch_optional_memory(2)
  let v128 = self.get_stack_slot_as_v128(v128)
  let address = address.to_u64()
  let loaded = try {
    if memory.is_default() {
      @wasmi_core.v128_load64_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_load64_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.set_stack_slot_as_v128(result, loaded)
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Store8Lane`] instruction.
fn Executor::execute_v128_store8_lane(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_store_lane
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx16(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(value)
  try {
    if memory.is_default() {
      @wasmi_core.v128_store8_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store8_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Store16Lane`] instruction.
fn Executor::execute_v128_store16_lane(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_store_lane
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx8(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(value)
  try {
    if memory.is_default() {
      @wasmi_core.v128_store16_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store16_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Store32Lane`] instruction.
fn Executor::execute_v128_store32_lane(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_store_lane
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx4(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(value)
  try {
    if memory.is_default() {
      @wasmi_core.v128_store32_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store32_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Store64Lane`] instruction.
fn Executor::execute_v128_store64_lane(
  self : Executor,
  store : StoreInner,
  ptr : @ir.Slot,
  offset_lo : @ir.Offset64Lo,
) -> Unit raise WasmiError {
  // execute_v128_store_lane
  guard self.instrs.unsafe_get(self.ip + 1) is SlotAndImm32(slot=value, imm~) else {
    abort("expected an `Op::SlotAndImm32`")
  }
  let offset_hi = @ir.Offset64Hi(imm.to_u32())
  guard self.instrs.unsafe_get(self.ip + 2) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx2(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let offset = @ir.Offset64::combine(offset_hi, offset_lo).to_u64()
  let ptr = self.get_stack_slot_as_u64(ptr)
  let v128 = self.get_stack_slot_as_v128(value)
  try {
    if memory.is_default() {
      @wasmi_core.v128_store64_lane(
        self.cache.memory_data,
        self.cache.memory_len,
        ptr,
        offset,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store64_lane(
        memory.data(),
        memory.data_size(),
        ptr,
        offset,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(3)
}

///|
/// Executes an [`Op::V128Store8LaneOffset8`] instruction.
fn Executor::execute_v128_store8_lane_offset8(
  self : Executor,
  ptr : @ir.Slot,
  value : @ir.Slot,
  offset : @ir.Offset8,
  lane : @ir.ImmLaneIdx,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_offset8
  let ptr = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  let v128 = self.get_stack_slot_as_v128(value)
  @wasmi_core.v128_store8_lane(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset,
    v128,
    lane_idx16(lane.0),
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::V128Store16LaneOffset8`] instruction.
fn Executor::execute_v128_store16_lane_offset8(
  self : Executor,
  ptr : @ir.Slot,
  value : @ir.Slot,
  offset : @ir.Offset8,
  lane : @ir.ImmLaneIdx,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_offset8
  let ptr = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  let v128 = self.get_stack_slot_as_v128(value)
  @wasmi_core.v128_store16_lane(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset,
    v128,
    lane_idx8(lane.0),
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::V128Store32LaneOffset8`] instruction.
fn Executor::execute_v128_store32_lane_offset8(
  self : Executor,
  ptr : @ir.Slot,
  value : @ir.Slot,
  offset : @ir.Offset8,
  lane : @ir.ImmLaneIdx,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_offset8
  let ptr = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  let v128 = self.get_stack_slot_as_v128(value)
  @wasmi_core.v128_store32_lane(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset,
    v128,
    lane_idx4(lane.0),
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::V128Store64LaneOffset8`] instruction.
fn Executor::execute_v128_store64_lane_offset8(
  self : Executor,
  ptr : @ir.Slot,
  value : @ir.Slot,
  offset : @ir.Offset8,
  lane : @ir.ImmLaneIdx,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_offset8
  let ptr = self.get_stack_slot_as_u64(ptr)
  let offset = offset.to_u64()
  let v128 = self.get_stack_slot_as_v128(value)
  @wasmi_core.v128_store64_lane(
    self.cache.memory_data,
    self.cache.memory_len,
    ptr,
    offset,
    v128,
    lane_idx2(lane.0),
  ) catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::V128Store8LaneAt`] instruction.
fn Executor::execute_v128_store8_lane_at(
  self : Executor,
  store : StoreInner,
  value : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_at
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx16(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let v128 = self.get_stack_slot_as_v128(value)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.v128_store8_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store8_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Store16LaneAt`] instruction.
fn Executor::execute_v128_store16_lane_at(
  self : Executor,
  store : StoreInner,
  value : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_at
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx8(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let v128 = self.get_stack_slot_as_v128(value)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.v128_store16_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store16_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Store32LaneAt`] instruction.
fn Executor::execute_v128_store32_lane_at(
  self : Executor,
  store : StoreInner,
  value : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_at
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx4(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let v128 = self.get_stack_slot_as_v128(value)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.v128_store32_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store32_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

///|
/// Executes an [`Op::V128Store64LaneAt`] instruction.
fn Executor::execute_v128_store64_lane_at(
  self : Executor,
  store : StoreInner,
  value : @ir.Slot,
  address : @ir.Address32,
) -> Unit raise WasmiError {
  // execute_v128_store_lane_at
  guard self.instrs.unsafe_get(self.ip + 1) is Imm16AndImm32(imm16~, imm32~) else {
    abort("expected an `Op::Imm16AndImm32`")
  }
  let lane = lane_idx2(imm16.to_u16() & 0xFF)
  let memory = @ir.Memory::Memory(imm32.to_i32())
  let v128 = self.get_stack_slot_as_v128(value)
  let address = address.to_u64()
  try {
    if memory.is_default() {
      @wasmi_core.v128_store64_lane_at(
        self.cache.memory_data,
        self.cache.memory_len,
        address,
        v128,
        lane,
      )
    } else {
      let memory = self.fetch_non_default_memory(memory, store)
      @wasmi_core.v128_store64_lane_at(
        memory.data(),
        memory.data_size(),
        address,
        v128,
        lane,
      )
    }
  } catch {
    e => raise WasmiError::TrapCode(e)
  }
  self.next_instr_at(2)
}

// ---------------------------------------------------------------------------
// Macro-generated executors (`impl_unary_executors`, `impl_binary_executors`,
// `impl_simd_shift_executors`).

///|
/// Executes an [`Op::V128AnyTrue`].
fn Executor::execute_v128_any_true(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.v128_any_true(value)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16AllTrue`].
fn Executor::execute_i8x16_all_true(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i8x16_all_true(value)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Bitmask`].
fn Executor::execute_i8x16_bitmask(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i8x16_bitmask(value)
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8AllTrue`].
fn Executor::execute_i16x8_all_true(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_all_true(value)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Bitmask`].
fn Executor::execute_i16x8_bitmask(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_bitmask(value)
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4AllTrue`].
fn Executor::execute_i32x4_all_true(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_all_true(value)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Bitmask`].
fn Executor::execute_i32x4_bitmask(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_bitmask(value)
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2AllTrue`].
fn Executor::execute_i64x2_all_true(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_all_true(value)
  self.set_stack_slot_as_bool(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Bitmask`].
fn Executor::execute_i64x2_bitmask(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_bitmask(value)
  self.set_stack_slot_as_u32(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Neg`].
fn Executor::execute_i8x16_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i8x16_neg(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Neg`].
fn Executor::execute_i16x8_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_neg(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Neg`].
fn Executor::execute_i32x4_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_neg(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Neg`].
fn Executor::execute_i64x2_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_neg(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Neg`].
fn Executor::execute_f32x4_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_neg(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Neg`].
fn Executor::execute_f64x2_neg(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_neg(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Abs`].
fn Executor::execute_i8x16_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i8x16_abs(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Abs`].
fn Executor::execute_i16x8_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_abs(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Abs`].
fn Executor::execute_i32x4_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_abs(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Abs`].
fn Executor::execute_i64x2_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_abs(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Abs`].
fn Executor::execute_f32x4_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_abs(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Abs`].
fn Executor::execute_f64x2_abs(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_abs(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Splat`].
fn Executor::execute_i8x16_splat(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i8x16_splat(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Splat`].
fn Executor::execute_i16x8_splat(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i16x8_splat(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Splat`].
fn Executor::execute_i32x4_splat(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i32(input)
  let value = @wasmi_core.i32x4_splat(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Splat`].
fn Executor::execute_i64x2_splat(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_i64(input)
  let value = @wasmi_core.i64x2_splat(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Splat`].
fn Executor::execute_f32x4_splat(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f32(input)
  let value = @wasmi_core.f32x4_splat(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Splat`].
fn Executor::execute_f64x2_splat(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_f64(input)
  let value = @wasmi_core.f64x2_splat(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtaddPairwiseI8x16S`].
fn Executor::execute_i16x8_extadd_pairwise_i8x16_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_extadd_pairwise_i8x16_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtaddPairwiseI8x16U`].
fn Executor::execute_i16x8_extadd_pairwise_i8x16_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_extadd_pairwise_i8x16_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtaddPairwiseI16x8S`].
fn Executor::execute_i32x4_extadd_pairwise_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_extadd_pairwise_i16x8_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtaddPairwiseI16x8U`].
fn Executor::execute_i32x4_extadd_pairwise_i16x8_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_extadd_pairwise_i16x8_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Ceil`].
fn Executor::execute_f32x4_ceil(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_ceil(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Floor`].
fn Executor::execute_f32x4_floor(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_floor(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Trunc`].
fn Executor::execute_f32x4_trunc(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_trunc(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Nearest`].
fn Executor::execute_f32x4_nearest(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_nearest(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Sqrt`].
fn Executor::execute_f32x4_sqrt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_sqrt(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Ceil`].
fn Executor::execute_f64x2_ceil(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_ceil(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Floor`].
fn Executor::execute_f64x2_floor(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_floor(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Trunc`].
fn Executor::execute_f64x2_trunc(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_trunc(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Nearest`].
fn Executor::execute_f64x2_nearest(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_nearest(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Sqrt`].
fn Executor::execute_f64x2_sqrt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_sqrt(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Not`].
fn Executor::execute_v128_not(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.v128_not(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Popcnt`].
fn Executor::execute_i8x16_popcnt(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i8x16_popcnt(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i16x8_extend_low_i8x16_s`].
fn Executor::execute_i16x8_extend_low_i8x16_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_extend_low_i8x16_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i16x8_extend_high_i8x16_s`].
fn Executor::execute_i16x8_extend_high_i8x16_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_extend_high_i8x16_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i16x8_extend_low_i8x16_u`].
fn Executor::execute_i16x8_extend_low_i8x16_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_extend_low_i8x16_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i16x8_extend_high_i8x16_u`].
fn Executor::execute_i16x8_extend_high_i8x16_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i16x8_extend_high_i8x16_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i32x4_extend_low_i16x8_s`].
fn Executor::execute_i32x4_extend_low_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_extend_low_i16x8_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i32x4_extend_high_i16x8_s`].
fn Executor::execute_i32x4_extend_high_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_extend_high_i16x8_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i32x4_extend_low_i16x8_u`].
fn Executor::execute_i32x4_extend_low_i16x8_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_extend_low_i16x8_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i32x4_extend_high_i16x8_u`].
fn Executor::execute_i32x4_extend_high_i16x8_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_extend_high_i16x8_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i64x2_extend_low_i32x4_s`].
fn Executor::execute_i64x2_extend_low_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_extend_low_i32x4_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i64x2_extend_high_i32x4_s`].
fn Executor::execute_i64x2_extend_high_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_extend_high_i32x4_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i64x2_extend_low_i32x4_u`].
fn Executor::execute_i64x2_extend_low_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_extend_low_i32x4_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::i64x2_extend_high_i32x4_u`].
fn Executor::execute_i64x2_extend_high_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i64x2_extend_high_i32x4_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4TruncSatF32x4S`].
fn Executor::execute_i32x4_trunc_sat_f32x4_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_trunc_sat_f32x4_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4TruncSatF32x4U`].
fn Executor::execute_i32x4_trunc_sat_f32x4_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_trunc_sat_f32x4_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4ConvertI32x4S`].
fn Executor::execute_f32x4_convert_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_convert_i32x4_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4ConvertI32x4U`].
fn Executor::execute_f32x4_convert_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_convert_i32x4_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4TruncSatF64x2SZero`].
fn Executor::execute_i32x4_trunc_sat_f64x2_s_zero(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_trunc_sat_f64x2_s_zero(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4TruncSatF64x2UZero`].
fn Executor::execute_i32x4_trunc_sat_f64x2_u_zero(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.i32x4_trunc_sat_f64x2_u_zero(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2ConvertLowI32x4S`].
fn Executor::execute_f64x2_convert_low_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_convert_low_i32x4_s(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2ConvertLowI32x4U`].
fn Executor::execute_f64x2_convert_low_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_convert_low_i32x4_u(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4DemoteF64x2Zero`].
fn Executor::execute_f32x4_demote_f64x2_zero(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f32x4_demote_f64x2_zero(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2PromoteLowF32x4`].
fn Executor::execute_f64x2_promote_low_f32x4(
  self : Executor,
  result : @ir.Slot,
  input : @ir.Slot,
) -> Unit {
  let value = self.get_stack_slot_as_v128(input)
  let value = @wasmi_core.f64x2_promote_low_f32x4(value)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Swizzle`].
fn Executor::execute_i8x16_swizzle(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_swizzle(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Q15MulrSatS`].
fn Executor::execute_i16x8_q15mulr_sat_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_q15mulr_sat_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4DotI16x8S`].
fn Executor::execute_i32x4_dot_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_dot_i16x8_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8RelaxedDotI8x16I7x16S`].
fn Executor::execute_i16x8_relaxed_dot_i8x16_i7x16_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_relaxed_dot_i8x16_i7x16_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtmulLowI8x16S`].
fn Executor::execute_i16x8_extmul_low_i8x16_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_extmul_low_i8x16_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtmulHighI8x16S`].
fn Executor::execute_i16x8_extmul_high_i8x16_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_extmul_high_i8x16_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtmulLowI8x16U`].
fn Executor::execute_i16x8_extmul_low_i8x16_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_extmul_low_i8x16_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ExtmulHighI8x16U`].
fn Executor::execute_i16x8_extmul_high_i8x16_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_extmul_high_i8x16_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtmulLowI16x8S`].
fn Executor::execute_i32x4_extmul_low_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_extmul_low_i16x8_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtmulHighI16x8S`].
fn Executor::execute_i32x4_extmul_high_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_extmul_high_i16x8_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtmulLowI16x8U`].
fn Executor::execute_i32x4_extmul_low_i16x8_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_extmul_low_i16x8_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ExtmulHighI16x8U`].
fn Executor::execute_i32x4_extmul_high_i16x8_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_extmul_high_i16x8_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ExtmulLowI32x4S`].
fn Executor::execute_i64x2_extmul_low_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_extmul_low_i32x4_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ExtmulHighI32x4S`].
fn Executor::execute_i64x2_extmul_high_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_extmul_high_i32x4_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ExtmulLowI32x4U`].
fn Executor::execute_i64x2_extmul_low_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_extmul_low_i32x4_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ExtmulHighI32x4U`].
fn Executor::execute_i64x2_extmul_high_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_extmul_high_i32x4_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Add`].
fn Executor::execute_i32x4_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_add(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Sub`].
fn Executor::execute_i32x4_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_sub(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Mul`].
fn Executor::execute_i32x4_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_mul(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Add`].
fn Executor::execute_i64x2_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_add(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Sub`].
fn Executor::execute_i64x2_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_sub(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Mul`].
fn Executor::execute_i64x2_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_mul(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Eq`].
fn Executor::execute_i8x16_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_eq(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Ne`].
fn Executor::execute_i8x16_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_ne(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16LtS`].
fn Executor::execute_i8x16_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_lt_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16LtU`].
fn Executor::execute_i8x16_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_lt_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16LeS`].
fn Executor::execute_i8x16_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_le_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16LeU`].
fn Executor::execute_i8x16_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_le_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Eq`].
fn Executor::execute_i16x8_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_eq(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Ne`].
fn Executor::execute_i16x8_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_ne(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8LtS`].
fn Executor::execute_i16x8_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_lt_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8LtU`].
fn Executor::execute_i16x8_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_lt_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8LeS`].
fn Executor::execute_i16x8_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_le_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8LeU`].
fn Executor::execute_i16x8_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_le_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Eq`].
fn Executor::execute_i32x4_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_eq(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Ne`].
fn Executor::execute_i32x4_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_ne(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4LtS`].
fn Executor::execute_i32x4_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_lt_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4LtU`].
fn Executor::execute_i32x4_lt_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_lt_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4LeS`].
fn Executor::execute_i32x4_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_le_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4LeU`].
fn Executor::execute_i32x4_le_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_le_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Eq`].
fn Executor::execute_i64x2_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_eq(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Ne`].
fn Executor::execute_i64x2_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_ne(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2LtS`].
fn Executor::execute_i64x2_lt_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_lt_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2LeS`].
fn Executor::execute_i64x2_le_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i64x2_le_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Eq`].
fn Executor::execute_f32x4_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_eq(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Ne`].
fn Executor::execute_f32x4_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_ne(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Lt`].
fn Executor::execute_f32x4_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_lt(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Le`].
fn Executor::execute_f32x4_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_le(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Eq`].
fn Executor::execute_f64x2_eq(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_eq(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Ne`].
fn Executor::execute_f64x2_ne(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_ne(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Lt`].
fn Executor::execute_f64x2_lt(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_lt(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Le`].
fn Executor::execute_f64x2_le(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_le(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16MinS`].
fn Executor::execute_i8x16_min_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_min_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16MinU`].
fn Executor::execute_i8x16_min_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_min_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16MaxS`].
fn Executor::execute_i8x16_max_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_max_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16MaxU`].
fn Executor::execute_i8x16_max_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_max_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16AvgrU`].
fn Executor::execute_i8x16_avgr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_avgr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8MinS`].
fn Executor::execute_i16x8_min_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_min_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8MinU`].
fn Executor::execute_i16x8_min_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_min_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8MaxS`].
fn Executor::execute_i16x8_max_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_max_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8MaxU`].
fn Executor::execute_i16x8_max_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_max_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8AvgrU`].
fn Executor::execute_i16x8_avgr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_avgr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4MinS`].
fn Executor::execute_i32x4_min_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_min_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4MinU`].
fn Executor::execute_i32x4_min_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_min_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4MaxS`].
fn Executor::execute_i32x4_max_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_max_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4MaxU`].
fn Executor::execute_i32x4_max_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i32x4_max_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Shl`].
fn Executor::execute_i8x16_shl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i8x16_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16ShrS`].
fn Executor::execute_i8x16_shr_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i8x16_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16ShrU`].
fn Executor::execute_i8x16_shr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i8x16_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Shl`].
fn Executor::execute_i16x8_shl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i16x8_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ShrS`].
fn Executor::execute_i16x8_shr_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i16x8_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ShrU`].
fn Executor::execute_i16x8_shr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i16x8_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4Shl`].
fn Executor::execute_i32x4_shl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32x4_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ShrS`].
fn Executor::execute_i32x4_shr_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32x4_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ShrU`].
fn Executor::execute_i32x4_shr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i32x4_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2Shl`].
fn Executor::execute_i64x2_shl(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i64x2_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ShrS`].
fn Executor::execute_i64x2_shr_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i64x2_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ShrU`].
fn Executor::execute_i64x2_shr_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  let value = @wasmi_core.i64x2_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Add`].
fn Executor::execute_i8x16_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_add(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16AddSatS`].
fn Executor::execute_i8x16_add_sat_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_add_sat_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16AddSatU`].
fn Executor::execute_i8x16_add_sat_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_add_sat_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16Sub`].
fn Executor::execute_i8x16_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_sub(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16SubSatS`].
fn Executor::execute_i8x16_sub_sat_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_sub_sat_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16SubSatU`].
fn Executor::execute_i8x16_sub_sat_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_sub_sat_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Add`].
fn Executor::execute_i16x8_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_add(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8AddSatS`].
fn Executor::execute_i16x8_add_sat_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_add_sat_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8AddSatU`].
fn Executor::execute_i16x8_add_sat_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_add_sat_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Sub`].
fn Executor::execute_i16x8_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_sub(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8SubSatS`].
fn Executor::execute_i16x8_sub_sat_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_sub_sat_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8SubSatU`].
fn Executor::execute_i16x8_sub_sat_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_sub_sat_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8Sub`].
fn Executor::execute_i16x8_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_mul(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128And`].
fn Executor::execute_v128_and(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.v128_and(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Andnot`].
fn Executor::execute_v128_andnot(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.v128_andnot(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Or`].
fn Executor::execute_v128_or(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.v128_or(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::V128Xor`].
fn Executor::execute_v128_xor(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.v128_xor(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Add`].
fn Executor::execute_f32x4_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_add(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Sub`].
fn Executor::execute_f32x4_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_sub(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Mul`].
fn Executor::execute_f32x4_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_mul(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Div`].
fn Executor::execute_f32x4_div(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_div(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Min`].
fn Executor::execute_f32x4_min(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_min(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Max`].
fn Executor::execute_f32x4_max(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_max(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Pmin`].
fn Executor::execute_f32x4_pmin(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_pmin(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F32x4Pmax`].
fn Executor::execute_f32x4_pmax(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f32x4_pmax(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Add`].
fn Executor::execute_f64x2_add(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_add(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Sub`].
fn Executor::execute_f64x2_sub(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_sub(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Mul`].
fn Executor::execute_f64x2_mul(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_mul(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Div`].
fn Executor::execute_f64x2_div(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_div(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Min`].
fn Executor::execute_f64x2_min(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_min(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Max`].
fn Executor::execute_f64x2_max(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_max(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Pmin`].
fn Executor::execute_f64x2_pmin(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_pmin(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::F64x2Pmax`].
fn Executor::execute_f64x2_pmax(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.f64x2_pmax(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16NarrowI16x8S`].
fn Executor::execute_i8x16_narrow_i16x8_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_narrow_i16x8_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16NarrowI16x8U`].
fn Executor::execute_i8x16_narrow_i16x8_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i8x16_narrow_i16x8_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8NarrowI32x4S`].
fn Executor::execute_i16x8_narrow_i32x4_s(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_narrow_i32x4_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8NarrowI32x4U`].
fn Executor::execute_i16x8_narrow_i32x4_u(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = self.get_stack_slot_as_v128(rhs)
  let value = @wasmi_core.i16x8_narrow_i32x4_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16ShlBy`].
fn Executor::execute_i8x16_shl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i8x16_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16ShrSBy`].
fn Executor::execute_i8x16_shr_s_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i8x16_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I8x16ShrUBy`].
fn Executor::execute_i8x16_shr_u_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i8x16_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ShlBy`].
fn Executor::execute_i16x8_shl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i16x8_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ShrSBy`].
fn Executor::execute_i16x8_shr_s_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i16x8_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I16x8ShrUBy`].
fn Executor::execute_i16x8_shr_u_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i16x8_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ShlBy`].
fn Executor::execute_i32x4_shl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i32x4_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ShrSBy`].
fn Executor::execute_i32x4_shr_s_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i32x4_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I32x4ShrUBy`].
fn Executor::execute_i32x4_shr_u_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i32x4_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ShlBy`].
fn Executor::execute_i64x2_shl_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i64x2_shl(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ShrSBy`].
fn Executor::execute_i64x2_shr_s_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i64x2_shr_s(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}

///|
/// Executes an [`Op::I64x2ShrUBy`].
fn Executor::execute_i64x2_shr_u_by(
  self : Executor,
  result : @ir.Slot,
  lhs : @ir.Slot,
  rhs : @ir.ShiftAmount,
) -> Unit {
  let lhs = self.get_stack_slot_as_v128(lhs)
  let rhs = rhs.to_u32()
  let value = @wasmi_core.i64x2_shr_u(lhs, rhs)
  self.set_stack_slot_as_v128(result, value)
  self.next_instr()
}
