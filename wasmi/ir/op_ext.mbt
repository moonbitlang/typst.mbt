// Port of the hand-written `impl Op` helpers of wasmi_ir 1.0.9 `enum.rs`.

///|
/// Creates a new [`Op::ReturnSlot2`] for the given [`Slot`] indices.
pub fn Op::return_reg2_ext(reg0 : Slot, reg1 : Slot) -> Op {
  Op::return_reg2([reg0, reg1])
}

///|
/// Creates a new [`Op::ReturnSlot3`] for the given [`Slot`] indices.
pub fn Op::return_reg3_ext(reg0 : Slot, reg1 : Slot, reg2 : Slot) -> Op {
  Op::return_reg3([reg0, reg1, reg2])
}

///|
/// Creates a new [`Op::ReturnMany`] for the given [`Slot`] indices.
pub fn Op::return_many_ext(reg0 : Slot, reg1 : Slot, reg2 : Slot) -> Op {
  Op::return_many([reg0, reg1, reg2])
}

///|
/// Creates a new [`Op::Copy2`].
pub fn Op::copy2_ext(results : SlotSpan, value0 : Slot, value1 : Slot) -> Op {
  let span = FixedSlotSpan::new(results, 2) catch {
    _ =>
      abort(
        "encountered invalid `results` `SlotSpan` for `Copy2`: \{results.0.0}",
      )
  }
  Op::copy2(span, [value0, value1])
}

///|
/// Creates a new [`Op::CopyMany`].
pub fn Op::copy_many_ext(results : SlotSpan, head0 : Slot, head1 : Slot) -> Op {
  Op::copy_many(results, [head0, head1])
}

///|
/// Creates a new [`Op::Slot2`] instruction parameter.
pub fn Op::slot2_ext(reg0 : Slot, reg1 : Slot) -> Op {
  Op::slot2([reg0, reg1])
}

///|
/// Creates a new [`Op::Slot3`] instruction parameter.
pub fn Op::slot3_ext(reg0 : Slot, reg1 : Slot, reg2 : Slot) -> Op {
  Op::slot3([reg0, reg1, reg2])
}

///|
/// Creates a new [`Op::SlotList`] instruction parameter.
pub fn Op::slot_list_ext(reg0 : Slot, reg1 : Slot, reg2 : Slot) -> Op {
  Op::slot_list([reg0, reg1, reg2])
}

///|
/// Creates a new [`Op::SlotAndImm32`] from the given `slot` and `offset_hi`.
pub fn Op::slot_and_offset_hi(slot : Slot, offset_hi : Offset64Hi) -> Op {
  Op::slot_and_imm32(slot, AnyConst32::from_u32(offset_hi.0))
}

///|
/// Returns `Some` [`Slot`] and [`Offset64Hi`] if encoded properly.
pub fn Op::filter_register_and_offset_hi(self : Op) -> (Slot, Offset64Hi)? {
  if self is SlotAndImm32(slot~, imm~) {
    return Some((slot, Offset64Hi(imm.to_u32())))
  }
  None
}

///|
/// Creates a new [`Op::SlotAndImm32`] from the given `slot` and `lane` index.
pub fn Op::slot_and_lane(slot : Slot, lane : Int) -> Op {
  Op::slot_and_imm32(slot, AnyConst32::from_i32(lane))
}

///|
/// Returns `Some` [`Slot`] and a `lane` index if encoded properly.
pub fn Op::filter_register_and_lane(self : Op) -> (Slot, Int)? {
  if self is SlotAndImm32(slot~, imm~) {
    let lane_index = imm.to_i32() & 0xFF
    return Some((slot, lane_index))
  }
  None
}

///|
/// Creates a new [`Op::Imm16AndImm32`] from the given `value` and `offset_hi`.
pub fn Op::imm16_and_offset_hi(value : AnyConst16, offset_hi : Offset64Hi) -> Op {
  Op::imm16_and_imm32(value, AnyConst32::from_u32(offset_hi.0))
}

///|
/// Returns `Some` [`AnyConst16`] and [`Offset64Hi`] if encoded properly.
pub fn Op::filter_imm16_and_offset_hi(self : Op) -> (AnyConst16, Offset64Hi)? {
  if self is Imm16AndImm32(imm16~, imm32~) {
    return Some((imm16, Offset64Hi(imm32.to_u32())))
  }
  None
}

///|
/// Creates a new [`Op::Imm16AndImm32`] from the given `lane` and `memory` index.
pub fn Op::lane_and_memory_index(value : Int, memory : Memory) -> Op {
  Op::imm16_and_imm32(AnyConst16::from_u16(value), AnyConst32::from_i32(memory.0))
}

///|
/// Returns `Some` lane and [`Memory`] index if encoded properly.
pub fn Op::filter_lane_and_memory(self : Op) -> (Int, Memory)? {
  if self is Imm16AndImm32(imm16~, imm32~) {
    let lane = imm16.to_u16() & 0xFF
    return Some((lane, Memory(imm32.to_i32())))
  }
  None
}
