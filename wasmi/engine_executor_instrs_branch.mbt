// Port of wasmi 1.0.9 `engine/executor/instrs/branch.rs`.

///|
/// Branches and adjusts the value stack.
///
/// # Note
///
/// Offsets the instruction pointer using the given [`BranchOffset`].
fn Executor::branch_to(self : Executor, offset : @ir.BranchOffset) -> Unit {
  self.ip = self.ip + offset.to_i32()
}

///|
/// Branches and adjusts the value stack.
///
/// # Note
///
/// Offsets the instruction pointer using the given [`BranchOffset16`].
fn Executor::branch_to16(self : Executor, offset : @ir.BranchOffset16) -> Unit {
  self.ip = self.ip + offset.to_i16()
}

///|
/// Executes an [`Op::Branch`].
fn Executor::execute_branch(self : Executor, offset : @ir.BranchOffset) -> Unit {
  self.branch_to(offset)
}

///|
/// Fetches the branch table index value and normalizes it to clamp between `0..len_targets`.
fn Executor::fetch_branch_table_offset(
  self : Executor,
  index : @ir.Slot,
  len_targets : Int,
) -> Int {
  let index : UInt = self.get_stack_slot_as_u32(index)
  // The index of the default target which is the last target of the slice.
  let max_index = len_targets.reinterpret_as_uint() - 1
  // A normalized index will always yield a target without panicking.
  let normalized = if index < max_index { index } else { max_index }
  normalized.reinterpret_as_int() + 1
}

///|
/// Executes an [`Op::BranchTable0`].
fn Executor::execute_branch_table_0(
  self : Executor,
  index : @ir.Slot,
  len_targets : Int,
) -> Unit {
  let offset = self.fetch_branch_table_offset(index, len_targets)
  self.ip = self.ip + offset
}

///|
/// Executes an [`Op::BranchTableSpan`].
fn Executor::execute_branch_table_span(
  self : Executor,
  index : @ir.Slot,
  len_targets : Int,
) -> Unit {
  let offset = self.fetch_branch_table_offset(index, len_targets)
  self.ip = self.ip + 1
  // Safety: Wasmi translation guarantees that `Op::SlotSpan` follows.
  guard self.instrs.unsafe_get(self.ip) is SlotSpan(span=values) else {
    abort("expected `Op::SlotSpan`")
  }
  let len = values.len()
  let values = values.span()
  self.ip = self.ip + offset
  match self.instrs.unsafe_get(self.ip) {
    // Note: we explicitly do _not_ handle branch table returns here for technical reasons.
    //       They are executed as the next conventional instruction in the pipeline, no special treatment required.
    BranchTableTarget(results~, offset~) => {
      self.execute_copy_span_impl(results, values, len)
      self.execute_branch(offset)
    }
    // Safety: Wasmi translator guarantees that one of the above `Op` variants exists.
    _ => abort("expected target for `Op::BranchTableSpan`")
  }
}

// ---------------------------------------------------------------------------
// cmp_eq / cmp_ne / cmp_lt / cmp_le (the float variants use the
// `@wasmi_core` comparisons).

///|
fn cmp_eq_i32(a : Int, b : Int) -> Bool {
  a == b
}

///|
fn cmp_ne_i32(a : Int, b : Int) -> Bool {
  a != b
}

///|
fn cmp_lt_i32(a : Int, b : Int) -> Bool {
  a < b
}

///|
fn cmp_le_i32(a : Int, b : Int) -> Bool {
  a <= b
}

///|
fn cmp_lt_u32(a : UInt, b : UInt) -> Bool {
  a < b
}

///|
fn cmp_le_u32(a : UInt, b : UInt) -> Bool {
  a <= b
}

///|
fn cmp_eq_i64(a : Int64, b : Int64) -> Bool {
  a == b
}

///|
fn cmp_ne_i64(a : Int64, b : Int64) -> Bool {
  a != b
}

///|
fn cmp_lt_i64(a : Int64, b : Int64) -> Bool {
  a < b
}

///|
fn cmp_le_i64(a : Int64, b : Int64) -> Bool {
  a <= b
}

///|
fn cmp_lt_u64(a : UInt64, b : UInt64) -> Bool {
  a < b
}

///|
fn cmp_le_u64(a : UInt64, b : UInt64) -> Bool {
  a <= b
}

///|
/// Executes a generic fused compare and branch instruction with raw inputs
/// (upstream `execute_branch_binop` with a 32-bit [`BranchOffset`]).
fn Executor::execute_branch_binop_result(
  self : Executor,
  taken : Bool,
  offset : @ir.BranchOffset,
) -> Unit {
  if taken {
    return self.branch_to(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchCmpFallback`].
fn Executor::execute_branch_cmp_fallback(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  params : @ir.Slot,
) -> Unit {
  let params : UInt64 = self.get_stack_slot_as_u64(params)
  guard @ir.ComparatorAndOffset::from_u64(params) is Some(params) else {
    abort("encountered invalidaly encoded ComparatorOffsetParam: \{params}")
  }
  let offset = params.offset
  let taken = match params.cmp {
    I32Eq =>
      cmp_eq_i32(
        self.get_stack_slot_as_i32(lhs),
        self.get_stack_slot_as_i32(rhs),
      )
    I32Ne =>
      cmp_ne_i32(
        self.get_stack_slot_as_i32(lhs),
        self.get_stack_slot_as_i32(rhs),
      )
    I32LtS =>
      cmp_lt_i32(
        self.get_stack_slot_as_i32(lhs),
        self.get_stack_slot_as_i32(rhs),
      )
    I32LtU =>
      cmp_lt_u32(
        self.get_stack_slot_as_u32(lhs),
        self.get_stack_slot_as_u32(rhs),
      )
    I32LeS =>
      cmp_le_i32(
        self.get_stack_slot_as_i32(lhs),
        self.get_stack_slot_as_i32(rhs),
      )
    I32LeU =>
      cmp_le_u32(
        self.get_stack_slot_as_u32(lhs),
        self.get_stack_slot_as_u32(rhs),
      )
    I32And =>
      i32_and(self.get_stack_slot_as_i32(lhs), self.get_stack_slot_as_i32(rhs))
    I32Or =>
      i32_or(self.get_stack_slot_as_i32(lhs), self.get_stack_slot_as_i32(rhs))
    I32Nand =>
      i32_nand(self.get_stack_slot_as_i32(lhs), self.get_stack_slot_as_i32(rhs))
    I32Nor =>
      i32_nor(self.get_stack_slot_as_i32(lhs), self.get_stack_slot_as_i32(rhs))
    I64Eq =>
      cmp_eq_i64(
        self.get_stack_slot_as_i64(lhs),
        self.get_stack_slot_as_i64(rhs),
      )
    I64Ne =>
      cmp_ne_i64(
        self.get_stack_slot_as_i64(lhs),
        self.get_stack_slot_as_i64(rhs),
      )
    I64LtS =>
      cmp_lt_i64(
        self.get_stack_slot_as_i64(lhs),
        self.get_stack_slot_as_i64(rhs),
      )
    I64LtU =>
      cmp_lt_u64(
        self.get_stack_slot_as_u64(lhs),
        self.get_stack_slot_as_u64(rhs),
      )
    I64LeS =>
      cmp_le_i64(
        self.get_stack_slot_as_i64(lhs),
        self.get_stack_slot_as_i64(rhs),
      )
    I64LeU =>
      cmp_le_u64(
        self.get_stack_slot_as_u64(lhs),
        self.get_stack_slot_as_u64(rhs),
      )
    I64And =>
      i64_and(self.get_stack_slot_as_i64(lhs), self.get_stack_slot_as_i64(rhs))
    I64Or =>
      i64_or(self.get_stack_slot_as_i64(lhs), self.get_stack_slot_as_i64(rhs))
    I64Nand =>
      i64_nand(self.get_stack_slot_as_i64(lhs), self.get_stack_slot_as_i64(rhs))
    I64Nor =>
      i64_nor(self.get_stack_slot_as_i64(lhs), self.get_stack_slot_as_i64(rhs))
    F32Eq =>
      @wasmi_core.f32_eq(
        self.get_stack_slot_as_f32(lhs),
        self.get_stack_slot_as_f32(rhs),
      )
    F32Ne =>
      @wasmi_core.f32_ne(
        self.get_stack_slot_as_f32(lhs),
        self.get_stack_slot_as_f32(rhs),
      )
    F32Lt =>
      @wasmi_core.f32_lt(
        self.get_stack_slot_as_f32(lhs),
        self.get_stack_slot_as_f32(rhs),
      )
    F32Le =>
      @wasmi_core.f32_le(
        self.get_stack_slot_as_f32(lhs),
        self.get_stack_slot_as_f32(rhs),
      )
    F32NotLt =>
      f32_not_lt(
        self.get_stack_slot_as_f32(lhs),
        self.get_stack_slot_as_f32(rhs),
      )
    F32NotLe =>
      f32_not_le(
        self.get_stack_slot_as_f32(lhs),
        self.get_stack_slot_as_f32(rhs),
      )
    F64Eq =>
      @wasmi_core.f64_eq(
        self.get_stack_slot_as_f64(lhs),
        self.get_stack_slot_as_f64(rhs),
      )
    F64Ne =>
      @wasmi_core.f64_ne(
        self.get_stack_slot_as_f64(lhs),
        self.get_stack_slot_as_f64(rhs),
      )
    F64Lt =>
      @wasmi_core.f64_lt(
        self.get_stack_slot_as_f64(lhs),
        self.get_stack_slot_as_f64(rhs),
      )
    F64Le =>
      @wasmi_core.f64_le(
        self.get_stack_slot_as_f64(lhs),
        self.get_stack_slot_as_f64(rhs),
      )
    F64NotLt =>
      f64_not_lt(
        self.get_stack_slot_as_f64(lhs),
        self.get_stack_slot_as_f64(rhs),
      )
    F64NotLe =>
      f64_not_le(
        self.get_stack_slot_as_f64(lhs),
        self.get_stack_slot_as_f64(rhs),
      )
  }
  self.execute_branch_binop_result(taken, offset)
}

// ---------------------------------------------------------------------------
// Macro-generated executors (`impl_execute_branch_binop{,_imm16_rhs,_imm16_lhs}`).

///|
/// Executes an [`Op::BranchI32And`].
fn Executor::execute_branch_i32_and(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if i32_and(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32Or`].
fn Executor::execute_branch_i32_or(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if i32_or(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32Nand`].
fn Executor::execute_branch_i32_nand(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if i32_nand(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32Nor`].
fn Executor::execute_branch_i32_nor(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if i32_nor(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32Eq`].
fn Executor::execute_branch_i32_eq(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if cmp_eq_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32Ne`].
fn Executor::execute_branch_i32_ne(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if cmp_ne_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LtS`].
fn Executor::execute_branch_i32_lt_s(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if cmp_lt_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LtU`].
fn Executor::execute_branch_i32_lt_u(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  if cmp_lt_u32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LeS`].
fn Executor::execute_branch_i32_le_s(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = self.get_stack_slot_as_i32(rhs)
  if cmp_le_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LeU`].
fn Executor::execute_branch_i32_le_u(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = self.get_stack_slot_as_u32(rhs)
  if cmp_le_u32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64And`].
fn Executor::execute_branch_i64_and(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if i64_and(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64Or`].
fn Executor::execute_branch_i64_or(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if i64_or(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64Nand`].
fn Executor::execute_branch_i64_nand(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if i64_nand(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64Nor`].
fn Executor::execute_branch_i64_nor(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if i64_nor(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64Eq`].
fn Executor::execute_branch_i64_eq(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if cmp_eq_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64Ne`].
fn Executor::execute_branch_i64_ne(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if cmp_ne_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LtS`].
fn Executor::execute_branch_i64_lt_s(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if cmp_lt_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LtU`].
fn Executor::execute_branch_i64_lt_u(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  if cmp_lt_u64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LeS`].
fn Executor::execute_branch_i64_le_s(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = self.get_stack_slot_as_i64(rhs)
  if cmp_le_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LeU`].
fn Executor::execute_branch_i64_le_u(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = self.get_stack_slot_as_u64(rhs)
  if cmp_le_u64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF32Eq`].
fn Executor::execute_branch_f32_eq(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  if @wasmi_core.f32_eq(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF32Ne`].
fn Executor::execute_branch_f32_ne(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  if @wasmi_core.f32_ne(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF32Lt`].
fn Executor::execute_branch_f32_lt(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  if @wasmi_core.f32_lt(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF32Le`].
fn Executor::execute_branch_f32_le(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  if @wasmi_core.f32_le(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF32NotLt`].
fn Executor::execute_branch_f32_not_lt(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  if f32_not_lt(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF32NotLe`].
fn Executor::execute_branch_f32_not_le(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f32(lhs)
  let rhs = self.get_stack_slot_as_f32(rhs)
  if f32_not_le(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF64Eq`].
fn Executor::execute_branch_f64_eq(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  if @wasmi_core.f64_eq(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF64Ne`].
fn Executor::execute_branch_f64_ne(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  if @wasmi_core.f64_ne(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF64Lt`].
fn Executor::execute_branch_f64_lt(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  if @wasmi_core.f64_lt(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF64Le`].
fn Executor::execute_branch_f64_le(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  if @wasmi_core.f64_le(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF64NotLt`].
fn Executor::execute_branch_f64_not_lt(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  if f64_not_lt(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchF64NotLe`].
fn Executor::execute_branch_f64_not_le(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_f64(lhs)
  let rhs = self.get_stack_slot_as_f64(rhs)
  if f64_not_le(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32AndImm16`].
fn Executor::execute_branch_i32_and_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if i32_and(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32OrImm16`].
fn Executor::execute_branch_i32_or_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if i32_or(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32NandImm16`].
fn Executor::execute_branch_i32_nand_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if i32_nand(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32NorImm16`].
fn Executor::execute_branch_i32_nor_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if i32_nor(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32EqImm16`].
fn Executor::execute_branch_i32_eq_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if cmp_eq_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32NeImm16`].
fn Executor::execute_branch_i32_ne_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if cmp_ne_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LtSImm16Rhs`].
fn Executor::execute_branch_i32_lt_s_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if cmp_lt_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LtUImm16Rhs`].
fn Executor::execute_branch_i32_lt_u_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = rhs.to_u32()
  if cmp_lt_u32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LeSImm16Rhs`].
fn Executor::execute_branch_i32_le_s_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i32(lhs)
  let rhs = rhs.to_i32()
  if cmp_le_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LeUImm16Rhs`].
fn Executor::execute_branch_i32_le_u_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u32(lhs)
  let rhs = rhs.to_u32()
  if cmp_le_u32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64AndImm16`].
fn Executor::execute_branch_i64_and_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if i64_and(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64OrImm16`].
fn Executor::execute_branch_i64_or_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if i64_or(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64NandImm16`].
fn Executor::execute_branch_i64_nand_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if i64_nand(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64NorImm16`].
fn Executor::execute_branch_i64_nor_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if i64_nor(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64EqImm16`].
fn Executor::execute_branch_i64_eq_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if cmp_eq_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64NeImm16`].
fn Executor::execute_branch_i64_ne_imm16(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if cmp_ne_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LtSImm16Rhs`].
fn Executor::execute_branch_i64_lt_s_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if cmp_lt_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LtUImm16Rhs`].
fn Executor::execute_branch_i64_lt_u_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = rhs.to_u64()
  if cmp_lt_u64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LeSImm16Rhs`].
fn Executor::execute_branch_i64_le_s_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_i64(lhs)
  let rhs = rhs.to_i64()
  if cmp_le_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LeUImm16Rhs`].
fn Executor::execute_branch_i64_le_u_imm16_rhs(
  self : Executor,
  lhs : @ir.Slot,
  rhs : @ir.Const16,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = self.get_stack_slot_as_u64(lhs)
  let rhs = rhs.to_u64()
  if cmp_le_u64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LtSImm16Lhs`].
fn Executor::execute_branch_i32_lt_s_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  if cmp_lt_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LtUImm16Lhs`].
fn Executor::execute_branch_i32_lt_u_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_u32()
  let rhs = self.get_stack_slot_as_u32(rhs)
  if cmp_lt_u32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LeSImm16Lhs`].
fn Executor::execute_branch_i32_le_s_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_i32()
  let rhs = self.get_stack_slot_as_i32(rhs)
  if cmp_le_i32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI32LeUImm16Lhs`].
fn Executor::execute_branch_i32_le_u_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_u32()
  let rhs = self.get_stack_slot_as_u32(rhs)
  if cmp_le_u32(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LtSImm16Lhs`].
fn Executor::execute_branch_i64_lt_s_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  if cmp_lt_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LtUImm16Lhs`].
fn Executor::execute_branch_i64_lt_u_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_u64()
  let rhs = self.get_stack_slot_as_u64(rhs)
  if cmp_lt_u64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LeSImm16Lhs`].
fn Executor::execute_branch_i64_le_s_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_i64()
  let rhs = self.get_stack_slot_as_i64(rhs)
  if cmp_le_i64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}

///|
/// Executes an [`Op::BranchI64LeUImm16Lhs`].
fn Executor::execute_branch_i64_le_u_imm16_lhs(
  self : Executor,
  lhs : @ir.Const16,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset16,
) -> Unit {
  let lhs = lhs.to_u64()
  let rhs = self.get_stack_slot_as_u64(rhs)
  if cmp_le_u64(lhs, rhs) {
    return self.branch_to16(offset)
  }
  self.next_instr()
}
