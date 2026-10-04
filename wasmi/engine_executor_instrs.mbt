// Port of wasmi 1.0.9 `engine/executor/instrs.rs` (the dispatch loop) and
// `engine/executor/instrs/utils.rs`.
//
// The executor methods of the `instrs/*.rs` modules live in
// `engine_executor_instrs_<module>.mbt`. Their macro-generated executors are
// expanded with upstream's generic helpers (`execute_unary`,
// `execute_binary`, `execute_load_extend`, ...) inlined, so that every
// executed instruction is a direct call of the `@wasmi_core` operation.
//
// The `wide-arithmetic` proposal (`instrs/wide_arithmetic.rs`) is disabled
// for Typst: its instructions are never produced by the translator and abort.

///|
/// Tells if execution loop shall continue or break (return) to the
/// execution's caller.
priv enum ControlFlow {
  Continue
  Break
}

///|
/// Executes compiled function instructions until execution returns from the root function.
///
/// # Errors
///
/// If the execution encounters a trap.
fn execute_instrs(
  store : StoreInner,
  stack : Stack,
  code_map : CodeMap,
) -> Unit raise WasmiError {
  let instance = stack.calls.instance_expect()
  let cache = CachedInstance::new(store, instance)
  let executor = Executor::new(stack, code_map, cache)
  // Note: upstream updates the instruction pointer of the top-most frame
  //       when running out of fuel (for resumption); fuel metering and
  //       resumable calls are not ported.
  executor.execute(store)
}

///|
/// An execution context for executing a Wasmi function frame.
priv struct Executor {
  /// The base offset of the current frame on the value stack (upstream
  /// `FrameSlots`): `Slot(i)` is the cell `sp + i`.
  mut sp : Int
  /// The index of the currently executed instruction in `instrs`.
  mut ip : Int
  /// The instructions of the currently executed function.
  mut instrs : FixedArray[@ir.Op]
  /// The low 64 bits of the value stack cells (cached from `stack.values`).
  mut lo : FixedArray[UInt64]
  /// The high 64 bits of the value stack cells (cached from `stack.values`).
  mut hi : FixedArray[UInt64]
  /// The cached instance and instance related data.
  cache : CachedInstance
  /// The value and call stacks.
  stack : Stack
  /// The static resources of an [`Engine`].
  code_map : CodeMap
  /// Scratch [`CallFrame`] for the callee of a call (copied into the call
  /// stack's frame pool when pushed).
  callee : CallFrame
  /// Scratch [`FrameParams`] for the callee of a call.
  params : FrameParams
  /// The `index` operand fetched by `pull_call_indirect_params{,_imm16}`.
  mut call_indirect_index : UInt64
}

///|
/// Creates a new [`Executor`] for executing a Wasmi function frame.
fn Executor::new(
  stack : Stack,
  code_map : CodeMap,
  cache : CachedInstance,
) -> Executor {
  guard stack.calls.peek() is Some(frame) else {
    abort("must have call frame on the call stack")
  }
  // Safety: We are using the frame's own base offset as input because it is
  //         guaranteed by the Wasm validation and translation phase to be
  //         valid for all register indices used by the associated function body.
  let sp = frame.base_offset()
  let ip = frame.ip
  {
    sp,
    ip,
    instrs: frame.instrs,
    lo: stack.values.lo,
    hi: stack.values.hi,
    cache,
    stack,
    code_map,
    callee: CallFrame::new([], 0, 0, 0, @ir.SlotSpan::new(@ir.Slot::Slot(0))),
    params: FrameParams::new(),
    call_indirect_index: 0,
  }
}

///|
/// Executes the function frame until it returns or traps.
fn Executor::execute(
  self : Executor,
  store : StoreInner,
) -> Unit raise WasmiError {
  while true {
    match self.instrs.unsafe_get(self.ip) {
      Trap(trap_code~) => self.execute_trap(trap_code)
      ConsumeFuel(block_fuel~) => self.execute_consume_fuel(store, block_fuel)
      Return => if self.execute_return(store) is Break { return }
      ReturnSlot(value~) =>
        if self.execute_return_reg(store, value) is Break {
          return
        }
      ReturnSlot2(values~) =>
        if self.execute_return_reg2(store, values) is Break {
          return
        }
      ReturnSlot3(values~) =>
        if self.execute_return_reg3(store, values) is Break {
          return
        }
      ReturnImm32(value~) =>
        if self.execute_return_imm32(store, value) is Break {
          return
        }
      ReturnI64Imm32(value~) =>
        if self.execute_return_i64imm32(store, value) is Break {
          return
        }
      ReturnF64Imm32(value~) =>
        if self.execute_return_f64imm32(store, value) is Break {
          return
        }
      ReturnSpan(values~) =>
        if self.execute_return_span(store, values) is Break {
          return
        }
      ReturnMany(values~) =>
        if self.execute_return_many(store, values) is Break {
          return
        }
      Branch(offset~) => self.execute_branch(offset)
      BranchTable0(index~, len_targets~) =>
        self.execute_branch_table_0(index, len_targets)
      BranchTableSpan(index~, len_targets~) =>
        self.execute_branch_table_span(index, len_targets)
      BranchCmpFallback(lhs~, rhs~, params~) =>
        self.execute_branch_cmp_fallback(lhs, rhs, params)
      BranchI32And(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_and(lhs, rhs, offset)
      BranchI32AndImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_and_imm16(lhs, rhs, offset)
      BranchI32Or(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_or(lhs, rhs, offset)
      BranchI32OrImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_or_imm16(lhs, rhs, offset)
      BranchI32Nand(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_nand(lhs, rhs, offset)
      BranchI32NandImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_nand_imm16(lhs, rhs, offset)
      BranchI32Nor(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_nor(lhs, rhs, offset)
      BranchI32NorImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_nor_imm16(lhs, rhs, offset)
      BranchI32Eq(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_eq(lhs, rhs, offset)
      BranchI32EqImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_eq_imm16(lhs, rhs, offset)
      BranchI32Ne(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_ne(lhs, rhs, offset)
      BranchI32NeImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_ne_imm16(lhs, rhs, offset)
      BranchI32LtS(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_lt_s(lhs, rhs, offset)
      BranchI32LtSImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_lt_s_imm16_lhs(lhs, rhs, offset)
      BranchI32LtSImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_lt_s_imm16_rhs(lhs, rhs, offset)
      BranchI32LtU(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_lt_u(lhs, rhs, offset)
      BranchI32LtUImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_lt_u_imm16_lhs(lhs, rhs, offset)
      BranchI32LtUImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_lt_u_imm16_rhs(lhs, rhs, offset)
      BranchI32LeS(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_le_s(lhs, rhs, offset)
      BranchI32LeSImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_le_s_imm16_lhs(lhs, rhs, offset)
      BranchI32LeSImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_le_s_imm16_rhs(lhs, rhs, offset)
      BranchI32LeU(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_le_u(lhs, rhs, offset)
      BranchI32LeUImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_le_u_imm16_lhs(lhs, rhs, offset)
      BranchI32LeUImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i32_le_u_imm16_rhs(lhs, rhs, offset)
      BranchI64And(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_and(lhs, rhs, offset)
      BranchI64AndImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_and_imm16(lhs, rhs, offset)
      BranchI64Or(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_or(lhs, rhs, offset)
      BranchI64OrImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_or_imm16(lhs, rhs, offset)
      BranchI64Nand(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_nand(lhs, rhs, offset)
      BranchI64NandImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_nand_imm16(lhs, rhs, offset)
      BranchI64Nor(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_nor(lhs, rhs, offset)
      BranchI64NorImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_nor_imm16(lhs, rhs, offset)
      BranchI64Eq(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_eq(lhs, rhs, offset)
      BranchI64EqImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_eq_imm16(lhs, rhs, offset)
      BranchI64Ne(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_ne(lhs, rhs, offset)
      BranchI64NeImm16(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_ne_imm16(lhs, rhs, offset)
      BranchI64LtS(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_lt_s(lhs, rhs, offset)
      BranchI64LtSImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_lt_s_imm16_lhs(lhs, rhs, offset)
      BranchI64LtSImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_lt_s_imm16_rhs(lhs, rhs, offset)
      BranchI64LtU(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_lt_u(lhs, rhs, offset)
      BranchI64LtUImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_lt_u_imm16_lhs(lhs, rhs, offset)
      BranchI64LtUImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_lt_u_imm16_rhs(lhs, rhs, offset)
      BranchI64LeS(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_le_s(lhs, rhs, offset)
      BranchI64LeSImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_le_s_imm16_lhs(lhs, rhs, offset)
      BranchI64LeSImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_le_s_imm16_rhs(lhs, rhs, offset)
      BranchI64LeU(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_le_u(lhs, rhs, offset)
      BranchI64LeUImm16Lhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_le_u_imm16_lhs(lhs, rhs, offset)
      BranchI64LeUImm16Rhs(lhs~, rhs~, offset~) =>
        self.execute_branch_i64_le_u_imm16_rhs(lhs, rhs, offset)
      BranchF32Eq(lhs~, rhs~, offset~) =>
        self.execute_branch_f32_eq(lhs, rhs, offset)
      BranchF32Ne(lhs~, rhs~, offset~) =>
        self.execute_branch_f32_ne(lhs, rhs, offset)
      BranchF32Lt(lhs~, rhs~, offset~) =>
        self.execute_branch_f32_lt(lhs, rhs, offset)
      BranchF32Le(lhs~, rhs~, offset~) =>
        self.execute_branch_f32_le(lhs, rhs, offset)
      BranchF32NotLt(lhs~, rhs~, offset~) =>
        self.execute_branch_f32_not_lt(lhs, rhs, offset)
      BranchF32NotLe(lhs~, rhs~, offset~) =>
        self.execute_branch_f32_not_le(lhs, rhs, offset)
      BranchF64Eq(lhs~, rhs~, offset~) =>
        self.execute_branch_f64_eq(lhs, rhs, offset)
      BranchF64Ne(lhs~, rhs~, offset~) =>
        self.execute_branch_f64_ne(lhs, rhs, offset)
      BranchF64Lt(lhs~, rhs~, offset~) =>
        self.execute_branch_f64_lt(lhs, rhs, offset)
      BranchF64Le(lhs~, rhs~, offset~) =>
        self.execute_branch_f64_le(lhs, rhs, offset)
      BranchF64NotLt(lhs~, rhs~, offset~) =>
        self.execute_branch_f64_not_lt(lhs, rhs, offset)
      BranchF64NotLe(lhs~, rhs~, offset~) =>
        self.execute_branch_f64_not_le(lhs, rhs, offset)
      Copy(result~, value~) => self.execute_copy(result, value)
      Copy2(results~, values~) => self.execute_copy_2(results, values)
      CopyImm32(result~, value~) => self.execute_copy_imm32(result, value)
      CopyI64Imm32(result~, value~) => self.execute_copy_i64imm32(result, value)
      CopyF64Imm32(result~, value~) => self.execute_copy_f64imm32(result, value)
      CopySpan(results~, values~, len~) =>
        self.execute_copy_span(results, values, len)
      CopyMany(results~, values~) => self.execute_copy_many(results, values)
      ReturnCallInternal0(func~) =>
        self.execute_return_call_internal_0(
          store,
          EngineFunc::from_internal(func),
        )
      ReturnCallInternal(func~) =>
        self.execute_return_call_internal(
          store,
          EngineFunc::from_internal(func),
        )
      ReturnCallImported0(func~) =>
        if self.execute_return_call_imported_0(store, func) is Break {
          return
        }
      ReturnCallImported(func~) =>
        if self.execute_return_call_imported(store, func) is Break {
          return
        }
      ReturnCallIndirect0(func_type~) =>
        if self.execute_return_call_indirect_0(store, func_type) is Break {
          return
        }
      ReturnCallIndirect0Imm16(func_type~) =>
        if self.execute_return_call_indirect_0_imm16(store, func_type) is Break {
          return
        }
      ReturnCallIndirect(func_type~) =>
        if self.execute_return_call_indirect(store, func_type) is Break {
          return
        }
      ReturnCallIndirectImm16(func_type~) =>
        if self.execute_return_call_indirect_imm16(store, func_type) is Break {
          return
        }
      CallInternal0(results~, func~) =>
        self.execute_call_internal_0(
          store,
          results,
          EngineFunc::from_internal(func),
        )
      CallInternal(results~, func~) =>
        self.execute_call_internal(
          store,
          results,
          EngineFunc::from_internal(func),
        )
      CallImported0(results~, func~) =>
        self.execute_call_imported_0(store, results, func)
      CallImported(results~, func~) =>
        self.execute_call_imported(store, results, func)
      CallIndirect0(results~, func_type~) =>
        self.execute_call_indirect_0(store, results, func_type)
      CallIndirect0Imm16(results~, func_type~) =>
        self.execute_call_indirect_0_imm16(store, results, func_type)
      CallIndirect(results~, func_type~) =>
        self.execute_call_indirect(store, results, func_type)
      CallIndirectImm16(results~, func_type~) =>
        self.execute_call_indirect_imm16(store, results, func_type)
      SelectI32Eq(result~, lhs~, rhs~) =>
        self.execute_select_i32_eq(result, lhs, rhs)
      SelectI32EqImm16(result~, lhs~, rhs~) =>
        self.execute_select_i32_eq_imm16(result, lhs, rhs)
      SelectI32LtS(result~, lhs~, rhs~) =>
        self.execute_select_i32_lt_s(result, lhs, rhs)
      SelectI32LtSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i32_lt_s_imm16_rhs(result, lhs, rhs)
      SelectI32LtU(result~, lhs~, rhs~) =>
        self.execute_select_i32_lt_u(result, lhs, rhs)
      SelectI32LtUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i32_lt_u_imm16_rhs(result, lhs, rhs)
      SelectI32LeS(result~, lhs~, rhs~) =>
        self.execute_select_i32_le_s(result, lhs, rhs)
      SelectI32LeSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i32_le_s_imm16_rhs(result, lhs, rhs)
      SelectI32LeU(result~, lhs~, rhs~) =>
        self.execute_select_i32_le_u(result, lhs, rhs)
      SelectI32LeUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i32_le_u_imm16_rhs(result, lhs, rhs)
      SelectI32And(result~, lhs~, rhs~) =>
        self.execute_select_i32_and(result, lhs, rhs)
      SelectI32AndImm16(result~, lhs~, rhs~) =>
        self.execute_select_i32_and_imm16(result, lhs, rhs)
      SelectI32Or(result~, lhs~, rhs~) =>
        self.execute_select_i32_or(result, lhs, rhs)
      SelectI32OrImm16(result~, lhs~, rhs~) =>
        self.execute_select_i32_or_imm16(result, lhs, rhs)
      SelectI64Eq(result~, lhs~, rhs~) =>
        self.execute_select_i64_eq(result, lhs, rhs)
      SelectI64EqImm16(result~, lhs~, rhs~) =>
        self.execute_select_i64_eq_imm16(result, lhs, rhs)
      SelectI64LtS(result~, lhs~, rhs~) =>
        self.execute_select_i64_lt_s(result, lhs, rhs)
      SelectI64LtSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i64_lt_s_imm16_rhs(result, lhs, rhs)
      SelectI64LtU(result~, lhs~, rhs~) =>
        self.execute_select_i64_lt_u(result, lhs, rhs)
      SelectI64LtUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i64_lt_u_imm16_rhs(result, lhs, rhs)
      SelectI64LeS(result~, lhs~, rhs~) =>
        self.execute_select_i64_le_s(result, lhs, rhs)
      SelectI64LeSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i64_le_s_imm16_rhs(result, lhs, rhs)
      SelectI64LeU(result~, lhs~, rhs~) =>
        self.execute_select_i64_le_u(result, lhs, rhs)
      SelectI64LeUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_select_i64_le_u_imm16_rhs(result, lhs, rhs)
      SelectI64And(result~, lhs~, rhs~) =>
        self.execute_select_i64_and(result, lhs, rhs)
      SelectI64AndImm16(result~, lhs~, rhs~) =>
        self.execute_select_i64_and_imm16(result, lhs, rhs)
      SelectI64Or(result~, lhs~, rhs~) =>
        self.execute_select_i64_or(result, lhs, rhs)
      SelectI64OrImm16(result~, lhs~, rhs~) =>
        self.execute_select_i64_or_imm16(result, lhs, rhs)
      SelectF32Eq(result~, lhs~, rhs~) =>
        self.execute_select_f32_eq(result, lhs, rhs)
      SelectF32Lt(result~, lhs~, rhs~) =>
        self.execute_select_f32_lt(result, lhs, rhs)
      SelectF32Le(result~, lhs~, rhs~) =>
        self.execute_select_f32_le(result, lhs, rhs)
      SelectF64Eq(result~, lhs~, rhs~) =>
        self.execute_select_f64_eq(result, lhs, rhs)
      SelectF64Lt(result~, lhs~, rhs~) =>
        self.execute_select_f64_lt(result, lhs, rhs)
      SelectF64Le(result~, lhs~, rhs~) =>
        self.execute_select_f64_le(result, lhs, rhs)
      RefFunc(result~, func~) => self.execute_ref_func(store, result, func)
      GlobalGet(result~, global~) =>
        self.execute_global_get(store, result, global)
      GlobalSet(global~, input~) =>
        self.execute_global_set(store, global, input)
      GlobalSetI32Imm16(global~, input~) =>
        self.execute_global_set_i32imm16(store, global, input)
      GlobalSetI64Imm16(global~, input~) =>
        self.execute_global_set_i64imm16(store, global, input)
      Load32(result~, offset_lo~) =>
        self.execute_load32(store, result, offset_lo)
      Load32At(result~, address~) =>
        self.execute_load32_at(store, result, address)
      Load32Offset16(result~, ptr~, offset~) =>
        self.execute_load32_offset16(result, ptr, offset)
      Load64(result~, offset_lo~) =>
        self.execute_load64(store, result, offset_lo)
      Load64At(result~, address~) =>
        self.execute_load64_at(store, result, address)
      Load64Offset16(result~, ptr~, offset~) =>
        self.execute_load64_offset16(result, ptr, offset)
      I32Load8s(result~, offset_lo~) =>
        self.execute_i32_load8_s(store, result, offset_lo)
      I32Load8sAt(result~, address~) =>
        self.execute_i32_load8_s_at(store, result, address)
      I32Load8sOffset16(result~, ptr~, offset~) =>
        self.execute_i32_load8_s_offset16(result, ptr, offset)
      I32Load8u(result~, offset_lo~) =>
        self.execute_i32_load8_u(store, result, offset_lo)
      I32Load8uAt(result~, address~) =>
        self.execute_i32_load8_u_at(store, result, address)
      I32Load8uOffset16(result~, ptr~, offset~) =>
        self.execute_i32_load8_u_offset16(result, ptr, offset)
      I32Load16s(result~, offset_lo~) =>
        self.execute_i32_load16_s(store, result, offset_lo)
      I32Load16sAt(result~, address~) =>
        self.execute_i32_load16_s_at(store, result, address)
      I32Load16sOffset16(result~, ptr~, offset~) =>
        self.execute_i32_load16_s_offset16(result, ptr, offset)
      I32Load16u(result~, offset_lo~) =>
        self.execute_i32_load16_u(store, result, offset_lo)
      I32Load16uAt(result~, address~) =>
        self.execute_i32_load16_u_at(store, result, address)
      I32Load16uOffset16(result~, ptr~, offset~) =>
        self.execute_i32_load16_u_offset16(result, ptr, offset)
      I64Load8s(result~, offset_lo~) =>
        self.execute_i64_load8_s(store, result, offset_lo)
      I64Load8sAt(result~, address~) =>
        self.execute_i64_load8_s_at(store, result, address)
      I64Load8sOffset16(result~, ptr~, offset~) =>
        self.execute_i64_load8_s_offset16(result, ptr, offset)
      I64Load8u(result~, offset_lo~) =>
        self.execute_i64_load8_u(store, result, offset_lo)
      I64Load8uAt(result~, address~) =>
        self.execute_i64_load8_u_at(store, result, address)
      I64Load8uOffset16(result~, ptr~, offset~) =>
        self.execute_i64_load8_u_offset16(result, ptr, offset)
      I64Load16s(result~, offset_lo~) =>
        self.execute_i64_load16_s(store, result, offset_lo)
      I64Load16sAt(result~, address~) =>
        self.execute_i64_load16_s_at(store, result, address)
      I64Load16sOffset16(result~, ptr~, offset~) =>
        self.execute_i64_load16_s_offset16(result, ptr, offset)
      I64Load16u(result~, offset_lo~) =>
        self.execute_i64_load16_u(store, result, offset_lo)
      I64Load16uAt(result~, address~) =>
        self.execute_i64_load16_u_at(store, result, address)
      I64Load16uOffset16(result~, ptr~, offset~) =>
        self.execute_i64_load16_u_offset16(result, ptr, offset)
      I64Load32s(result~, offset_lo~) =>
        self.execute_i64_load32_s(store, result, offset_lo)
      I64Load32sAt(result~, address~) =>
        self.execute_i64_load32_s_at(store, result, address)
      I64Load32sOffset16(result~, ptr~, offset~) =>
        self.execute_i64_load32_s_offset16(result, ptr, offset)
      I64Load32u(result~, offset_lo~) =>
        self.execute_i64_load32_u(store, result, offset_lo)
      I64Load32uAt(result~, address~) =>
        self.execute_i64_load32_u_at(store, result, address)
      I64Load32uOffset16(result~, ptr~, offset~) =>
        self.execute_i64_load32_u_offset16(result, ptr, offset)
      Store32(ptr~, offset_lo~) => self.execute_store32(store, ptr, offset_lo)
      Store32Offset16(ptr~, offset~, value~) =>
        self.execute_store32_offset16(ptr, offset, value)
      Store32At(address~, value~) =>
        self.execute_store32_at(store, address, value)
      Store64(ptr~, offset_lo~) => self.execute_store64(store, ptr, offset_lo)
      Store64Offset16(ptr~, offset~, value~) =>
        self.execute_store64_offset16(ptr, offset, value)
      Store64At(address~, value~) =>
        self.execute_store64_at(store, address, value)
      I32StoreImm16(ptr~, offset_lo~) =>
        self.execute_i32_store_imm16(store, ptr, offset_lo)
      I32StoreOffset16Imm16(ptr~, offset~, value~) =>
        self.execute_i32_store_offset16_imm16(ptr, offset, value)
      I32StoreAtImm16(address~, value~) =>
        self.execute_i32_store_at_imm16(store, address, value)
      I32Store8(ptr~, offset_lo~) =>
        self.execute_i32_store8(store, ptr, offset_lo)
      I32Store8Imm(ptr~, offset_lo~) =>
        self.execute_i32_store8_imm(store, ptr, offset_lo)
      I32Store8Offset16(ptr~, offset~, value~) =>
        self.execute_i32_store8_offset16(ptr, offset, value)
      I32Store8Offset16Imm(ptr~, offset~, value~) =>
        self.execute_i32_store8_offset16_imm(ptr, offset, value)
      I32Store8At(address~, value~) =>
        self.execute_i32_store8_at(store, address, value)
      I32Store8AtImm(address~, value~) =>
        self.execute_i32_store8_at_imm(store, address, value)
      I32Store16(ptr~, offset_lo~) =>
        self.execute_i32_store16(store, ptr, offset_lo)
      I32Store16Imm(ptr~, offset_lo~) =>
        self.execute_i32_store16_imm(store, ptr, offset_lo)
      I32Store16Offset16(ptr~, offset~, value~) =>
        self.execute_i32_store16_offset16(ptr, offset, value)
      I32Store16Offset16Imm(ptr~, offset~, value~) =>
        self.execute_i32_store16_offset16_imm(ptr, offset, value)
      I32Store16At(address~, value~) =>
        self.execute_i32_store16_at(store, address, value)
      I32Store16AtImm(address~, value~) =>
        self.execute_i32_store16_at_imm(store, address, value)
      I64StoreImm16(ptr~, offset_lo~) =>
        self.execute_i64_store_imm16(store, ptr, offset_lo)
      I64StoreOffset16Imm16(ptr~, offset~, value~) =>
        self.execute_i64_store_offset16_imm16(ptr, offset, value)
      I64StoreAtImm16(address~, value~) =>
        self.execute_i64_store_at_imm16(store, address, value)
      I64Store8(ptr~, offset_lo~) =>
        self.execute_i64_store8(store, ptr, offset_lo)
      I64Store8Imm(ptr~, offset_lo~) =>
        self.execute_i64_store8_imm(store, ptr, offset_lo)
      I64Store8Offset16(ptr~, offset~, value~) =>
        self.execute_i64_store8_offset16(ptr, offset, value)
      I64Store8Offset16Imm(ptr~, offset~, value~) =>
        self.execute_i64_store8_offset16_imm(ptr, offset, value)
      I64Store8At(address~, value~) =>
        self.execute_i64_store8_at(store, address, value)
      I64Store8AtImm(address~, value~) =>
        self.execute_i64_store8_at_imm(store, address, value)
      I64Store16(ptr~, offset_lo~) =>
        self.execute_i64_store16(store, ptr, offset_lo)
      I64Store16Imm(ptr~, offset_lo~) =>
        self.execute_i64_store16_imm(store, ptr, offset_lo)
      I64Store16Offset16(ptr~, offset~, value~) =>
        self.execute_i64_store16_offset16(ptr, offset, value)
      I64Store16Offset16Imm(ptr~, offset~, value~) =>
        self.execute_i64_store16_offset16_imm(ptr, offset, value)
      I64Store16At(address~, value~) =>
        self.execute_i64_store16_at(store, address, value)
      I64Store16AtImm(address~, value~) =>
        self.execute_i64_store16_at_imm(store, address, value)
      I64Store32(ptr~, offset_lo~) =>
        self.execute_i64_store32(store, ptr, offset_lo)
      I64Store32Imm16(ptr~, offset_lo~) =>
        self.execute_i64_store32_imm16(store, ptr, offset_lo)
      I64Store32Offset16(ptr~, offset~, value~) =>
        self.execute_i64_store32_offset16(ptr, offset, value)
      I64Store32Offset16Imm16(ptr~, offset~, value~) =>
        self.execute_i64_store32_offset16_imm16(ptr, offset, value)
      I64Store32At(address~, value~) =>
        self.execute_i64_store32_at(store, address, value)
      I64Store32AtImm16(address~, value~) =>
        self.execute_i64_store32_at_imm16(store, address, value)
      I32Eq(result~, lhs~, rhs~) => self.execute_i32_eq(result, lhs, rhs)
      I32EqImm16(result~, lhs~, rhs~) =>
        self.execute_i32_eq_imm16(result, lhs, rhs)
      I32Ne(result~, lhs~, rhs~) => self.execute_i32_ne(result, lhs, rhs)
      I32NeImm16(result~, lhs~, rhs~) =>
        self.execute_i32_ne_imm16(result, lhs, rhs)
      I32LtS(result~, lhs~, rhs~) => self.execute_i32_lt_s(result, lhs, rhs)
      I32LtSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_lt_s_imm16_lhs(result, lhs, rhs)
      I32LtSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_lt_s_imm16_rhs(result, lhs, rhs)
      I32LtU(result~, lhs~, rhs~) => self.execute_i32_lt_u(result, lhs, rhs)
      I32LtUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_lt_u_imm16_lhs(result, lhs, rhs)
      I32LtUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_lt_u_imm16_rhs(result, lhs, rhs)
      I32LeS(result~, lhs~, rhs~) => self.execute_i32_le_s(result, lhs, rhs)
      I32LeSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_le_s_imm16_lhs(result, lhs, rhs)
      I32LeSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_le_s_imm16_rhs(result, lhs, rhs)
      I32LeU(result~, lhs~, rhs~) => self.execute_i32_le_u(result, lhs, rhs)
      I32LeUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_le_u_imm16_lhs(result, lhs, rhs)
      I32LeUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_le_u_imm16_rhs(result, lhs, rhs)
      I64Eq(result~, lhs~, rhs~) => self.execute_i64_eq(result, lhs, rhs)
      I64EqImm16(result~, lhs~, rhs~) =>
        self.execute_i64_eq_imm16(result, lhs, rhs)
      I64Ne(result~, lhs~, rhs~) => self.execute_i64_ne(result, lhs, rhs)
      I64NeImm16(result~, lhs~, rhs~) =>
        self.execute_i64_ne_imm16(result, lhs, rhs)
      I64LtS(result~, lhs~, rhs~) => self.execute_i64_lt_s(result, lhs, rhs)
      I64LtSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_lt_s_imm16_lhs(result, lhs, rhs)
      I64LtSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_lt_s_imm16_rhs(result, lhs, rhs)
      I64LtU(result~, lhs~, rhs~) => self.execute_i64_lt_u(result, lhs, rhs)
      I64LtUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_lt_u_imm16_lhs(result, lhs, rhs)
      I64LtUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_lt_u_imm16_rhs(result, lhs, rhs)
      I64LeS(result~, lhs~, rhs~) => self.execute_i64_le_s(result, lhs, rhs)
      I64LeSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_le_s_imm16_lhs(result, lhs, rhs)
      I64LeSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_le_s_imm16_rhs(result, lhs, rhs)
      I64LeU(result~, lhs~, rhs~) => self.execute_i64_le_u(result, lhs, rhs)
      I64LeUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_le_u_imm16_lhs(result, lhs, rhs)
      I64LeUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_le_u_imm16_rhs(result, lhs, rhs)
      F32Eq(result~, lhs~, rhs~) => self.execute_f32_eq(result, lhs, rhs)
      F32Ne(result~, lhs~, rhs~) => self.execute_f32_ne(result, lhs, rhs)
      F32Lt(result~, lhs~, rhs~) => self.execute_f32_lt(result, lhs, rhs)
      F32Le(result~, lhs~, rhs~) => self.execute_f32_le(result, lhs, rhs)
      F32NotLt(result~, lhs~, rhs~) => self.execute_f32_not_lt(result, lhs, rhs)
      F32NotLe(result~, lhs~, rhs~) => self.execute_f32_not_le(result, lhs, rhs)
      F64Eq(result~, lhs~, rhs~) => self.execute_f64_eq(result, lhs, rhs)
      F64Ne(result~, lhs~, rhs~) => self.execute_f64_ne(result, lhs, rhs)
      F64Lt(result~, lhs~, rhs~) => self.execute_f64_lt(result, lhs, rhs)
      F64Le(result~, lhs~, rhs~) => self.execute_f64_le(result, lhs, rhs)
      F64NotLt(result~, lhs~, rhs~) => self.execute_f64_not_lt(result, lhs, rhs)
      F64NotLe(result~, lhs~, rhs~) => self.execute_f64_not_le(result, lhs, rhs)
      I32Clz(result~, input~) => self.execute_i32_clz(result, input)
      I32Ctz(result~, input~) => self.execute_i32_ctz(result, input)
      I32Popcnt(result~, input~) => self.execute_i32_popcnt(result, input)
      I32Add(result~, lhs~, rhs~) => self.execute_i32_add(result, lhs, rhs)
      I32AddImm16(result~, lhs~, rhs~) =>
        self.execute_i32_add_imm16(result, lhs, rhs)
      I32Sub(result~, lhs~, rhs~) => self.execute_i32_sub(result, lhs, rhs)
      I32SubImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_sub_imm16_lhs(result, lhs, rhs)
      I32Mul(result~, lhs~, rhs~) => self.execute_i32_mul(result, lhs, rhs)
      I32MulImm16(result~, lhs~, rhs~) =>
        self.execute_i32_mul_imm16(result, lhs, rhs)
      I32DivS(result~, lhs~, rhs~) => self.execute_i32_div_s(result, lhs, rhs)
      I32DivSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_div_s_imm16_rhs(result, lhs, rhs)
      I32DivSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_div_s_imm16_lhs(result, lhs, rhs)
      I32DivU(result~, lhs~, rhs~) => self.execute_i32_div_u(result, lhs, rhs)
      I32DivUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_div_u_imm16_rhs(result, lhs, rhs)
      I32DivUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_div_u_imm16_lhs(result, lhs, rhs)
      I32RemS(result~, lhs~, rhs~) => self.execute_i32_rem_s(result, lhs, rhs)
      I32RemSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_rem_s_imm16_rhs(result, lhs, rhs)
      I32RemSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_rem_s_imm16_lhs(result, lhs, rhs)
      I32RemU(result~, lhs~, rhs~) => self.execute_i32_rem_u(result, lhs, rhs)
      I32RemUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i32_rem_u_imm16_rhs(result, lhs, rhs)
      I32RemUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i32_rem_u_imm16_lhs(result, lhs, rhs)
      I32BitAnd(result~, lhs~, rhs~) =>
        self.execute_i32_bitand(result, lhs, rhs)
      I32BitAndImm16(result~, lhs~, rhs~) =>
        self.execute_i32_bitand_imm16(result, lhs, rhs)
      I32BitOr(result~, lhs~, rhs~) => self.execute_i32_bitor(result, lhs, rhs)
      I32BitOrImm16(result~, lhs~, rhs~) =>
        self.execute_i32_bitor_imm16(result, lhs, rhs)
      I32BitXor(result~, lhs~, rhs~) =>
        self.execute_i32_bitxor(result, lhs, rhs)
      I32BitXorImm16(result~, lhs~, rhs~) =>
        self.execute_i32_bitxor_imm16(result, lhs, rhs)
      I32And(result~, lhs~, rhs~) => self.execute_i32_and(result, lhs, rhs)
      I32AndImm16(result~, lhs~, rhs~) =>
        self.execute_i32_and_imm16(result, lhs, rhs)
      I32Or(result~, lhs~, rhs~) => self.execute_i32_or(result, lhs, rhs)
      I32OrImm16(result~, lhs~, rhs~) =>
        self.execute_i32_or_imm16(result, lhs, rhs)
      I32Nand(result~, lhs~, rhs~) => self.execute_i32_nand(result, lhs, rhs)
      I32NandImm16(result~, lhs~, rhs~) =>
        self.execute_i32_nand_imm16(result, lhs, rhs)
      I32Nor(result~, lhs~, rhs~) => self.execute_i32_nor(result, lhs, rhs)
      I32NorImm16(result~, lhs~, rhs~) =>
        self.execute_i32_nor_imm16(result, lhs, rhs)
      I32Shl(result~, lhs~, rhs~) => self.execute_i32_shl(result, lhs, rhs)
      I32ShlBy(result~, lhs~, rhs~) => self.execute_i32_shl_by(result, lhs, rhs)
      I32ShlImm16(result~, lhs~, rhs~) =>
        self.execute_i32_shl_imm16(result, lhs, rhs)
      I32ShrU(result~, lhs~, rhs~) => self.execute_i32_shr_u(result, lhs, rhs)
      I32ShrUBy(result~, lhs~, rhs~) =>
        self.execute_i32_shr_u_by(result, lhs, rhs)
      I32ShrUImm16(result~, lhs~, rhs~) =>
        self.execute_i32_shr_u_imm16(result, lhs, rhs)
      I32ShrS(result~, lhs~, rhs~) => self.execute_i32_shr_s(result, lhs, rhs)
      I32ShrSBy(result~, lhs~, rhs~) =>
        self.execute_i32_shr_s_by(result, lhs, rhs)
      I32ShrSImm16(result~, lhs~, rhs~) =>
        self.execute_i32_shr_s_imm16(result, lhs, rhs)
      I32Rotl(result~, lhs~, rhs~) => self.execute_i32_rotl(result, lhs, rhs)
      I32RotlBy(result~, lhs~, rhs~) =>
        self.execute_i32_rotl_by(result, lhs, rhs)
      I32RotlImm16(result~, lhs~, rhs~) =>
        self.execute_i32_rotl_imm16(result, lhs, rhs)
      I32Rotr(result~, lhs~, rhs~) => self.execute_i32_rotr(result, lhs, rhs)
      I32RotrBy(result~, lhs~, rhs~) =>
        self.execute_i32_rotr_by(result, lhs, rhs)
      I32RotrImm16(result~, lhs~, rhs~) =>
        self.execute_i32_rotr_imm16(result, lhs, rhs)
      I64Clz(result~, input~) => self.execute_i64_clz(result, input)
      I64Ctz(result~, input~) => self.execute_i64_ctz(result, input)
      I64Popcnt(result~, input~) => self.execute_i64_popcnt(result, input)
      I64Add(result~, lhs~, rhs~) => self.execute_i64_add(result, lhs, rhs)
      I64AddImm16(result~, lhs~, rhs~) =>
        self.execute_i64_add_imm16(result, lhs, rhs)
      I64Sub(result~, lhs~, rhs~) => self.execute_i64_sub(result, lhs, rhs)
      I64SubImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_sub_imm16_lhs(result, lhs, rhs)
      I64Mul(result~, lhs~, rhs~) => self.execute_i64_mul(result, lhs, rhs)
      I64MulImm16(result~, lhs~, rhs~) =>
        self.execute_i64_mul_imm16(result, lhs, rhs)
      I64DivS(result~, lhs~, rhs~) => self.execute_i64_div_s(result, lhs, rhs)
      I64DivSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_div_s_imm16_rhs(result, lhs, rhs)
      I64DivSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_div_s_imm16_lhs(result, lhs, rhs)
      I64DivU(result~, lhs~, rhs~) => self.execute_i64_div_u(result, lhs, rhs)
      I64DivUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_div_u_imm16_rhs(result, lhs, rhs)
      I64DivUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_div_u_imm16_lhs(result, lhs, rhs)
      I64RemS(result~, lhs~, rhs~) => self.execute_i64_rem_s(result, lhs, rhs)
      I64RemSImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_rem_s_imm16_rhs(result, lhs, rhs)
      I64RemSImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_rem_s_imm16_lhs(result, lhs, rhs)
      I64RemU(result~, lhs~, rhs~) => self.execute_i64_rem_u(result, lhs, rhs)
      I64RemUImm16Rhs(result~, lhs~, rhs~) =>
        self.execute_i64_rem_u_imm16_rhs(result, lhs, rhs)
      I64RemUImm16Lhs(result~, lhs~, rhs~) =>
        self.execute_i64_rem_u_imm16_lhs(result, lhs, rhs)
      I64BitAnd(result~, lhs~, rhs~) =>
        self.execute_i64_bitand(result, lhs, rhs)
      I64BitAndImm16(result~, lhs~, rhs~) =>
        self.execute_i64_bitand_imm16(result, lhs, rhs)
      I64BitOr(result~, lhs~, rhs~) => self.execute_i64_bitor(result, lhs, rhs)
      I64BitOrImm16(result~, lhs~, rhs~) =>
        self.execute_i64_bitor_imm16(result, lhs, rhs)
      I64BitXor(result~, lhs~, rhs~) =>
        self.execute_i64_bitxor(result, lhs, rhs)
      I64BitXorImm16(result~, lhs~, rhs~) =>
        self.execute_i64_bitxor_imm16(result, lhs, rhs)
      I64And(result~, lhs~, rhs~) => self.execute_i64_and(result, lhs, rhs)
      I64AndImm16(result~, lhs~, rhs~) =>
        self.execute_i64_and_imm16(result, lhs, rhs)
      I64Or(result~, lhs~, rhs~) => self.execute_i64_or(result, lhs, rhs)
      I64OrImm16(result~, lhs~, rhs~) =>
        self.execute_i64_or_imm16(result, lhs, rhs)
      I64Nand(result~, lhs~, rhs~) => self.execute_i64_nand(result, lhs, rhs)
      I64NandImm16(result~, lhs~, rhs~) =>
        self.execute_i64_nand_imm16(result, lhs, rhs)
      I64Nor(result~, lhs~, rhs~) => self.execute_i64_nor(result, lhs, rhs)
      I64NorImm16(result~, lhs~, rhs~) =>
        self.execute_i64_nor_imm16(result, lhs, rhs)
      I64Shl(result~, lhs~, rhs~) => self.execute_i64_shl(result, lhs, rhs)
      I64ShlBy(result~, lhs~, rhs~) => self.execute_i64_shl_by(result, lhs, rhs)
      I64ShlImm16(result~, lhs~, rhs~) =>
        self.execute_i64_shl_imm16(result, lhs, rhs)
      I64ShrU(result~, lhs~, rhs~) => self.execute_i64_shr_u(result, lhs, rhs)
      I64ShrUBy(result~, lhs~, rhs~) =>
        self.execute_i64_shr_u_by(result, lhs, rhs)
      I64ShrUImm16(result~, lhs~, rhs~) =>
        self.execute_i64_shr_u_imm16(result, lhs, rhs)
      I64ShrS(result~, lhs~, rhs~) => self.execute_i64_shr_s(result, lhs, rhs)
      I64ShrSBy(result~, lhs~, rhs~) =>
        self.execute_i64_shr_s_by(result, lhs, rhs)
      I64ShrSImm16(result~, lhs~, rhs~) =>
        self.execute_i64_shr_s_imm16(result, lhs, rhs)
      I64Rotl(result~, lhs~, rhs~) => self.execute_i64_rotl(result, lhs, rhs)
      I64RotlBy(result~, lhs~, rhs~) =>
        self.execute_i64_rotl_by(result, lhs, rhs)
      I64RotlImm16(result~, lhs~, rhs~) =>
        self.execute_i64_rotl_imm16(result, lhs, rhs)
      I64Rotr(result~, lhs~, rhs~) => self.execute_i64_rotr(result, lhs, rhs)
      I64RotrBy(result~, lhs~, rhs~) =>
        self.execute_i64_rotr_by(result, lhs, rhs)
      I64RotrImm16(result~, lhs~, rhs~) =>
        self.execute_i64_rotr_imm16(result, lhs, rhs)
      I64Add128(..) => abort("the Wasm `wide-arithmetic` proposal is disabled")
      I64Sub128(..) => abort("the Wasm `wide-arithmetic` proposal is disabled")
      I64MulWideS(..) =>
        abort("the Wasm `wide-arithmetic` proposal is disabled")
      I64MulWideU(..) =>
        abort("the Wasm `wide-arithmetic` proposal is disabled")
      I32WrapI64(result~, input~) => self.execute_i32_wrap_i64(result, input)
      I32Extend8S(result~, input~) => self.execute_i32_extend8_s(result, input)
      I32Extend16S(result~, input~) =>
        self.execute_i32_extend16_s(result, input)
      I64Extend8S(result~, input~) => self.execute_i64_extend8_s(result, input)
      I64Extend16S(result~, input~) =>
        self.execute_i64_extend16_s(result, input)
      I64Extend32S(result~, input~) =>
        self.execute_i64_extend32_s(result, input)
      F32Abs(result~, input~) => self.execute_f32_abs(result, input)
      F32Neg(result~, input~) => self.execute_f32_neg(result, input)
      F32Ceil(result~, input~) => self.execute_f32_ceil(result, input)
      F32Floor(result~, input~) => self.execute_f32_floor(result, input)
      F32Trunc(result~, input~) => self.execute_f32_trunc(result, input)
      F32Nearest(result~, input~) => self.execute_f32_nearest(result, input)
      F32Sqrt(result~, input~) => self.execute_f32_sqrt(result, input)
      F32Add(result~, lhs~, rhs~) => self.execute_f32_add(result, lhs, rhs)
      F32Sub(result~, lhs~, rhs~) => self.execute_f32_sub(result, lhs, rhs)
      F32Mul(result~, lhs~, rhs~) => self.execute_f32_mul(result, lhs, rhs)
      F32Div(result~, lhs~, rhs~) => self.execute_f32_div(result, lhs, rhs)
      F32Min(result~, lhs~, rhs~) => self.execute_f32_min(result, lhs, rhs)
      F32Max(result~, lhs~, rhs~) => self.execute_f32_max(result, lhs, rhs)
      F32Copysign(result~, lhs~, rhs~) =>
        self.execute_f32_copysign(result, lhs, rhs)
      F32CopysignImm(result~, lhs~, rhs~) =>
        self.execute_f32_copysign_imm(result, lhs, rhs)
      F64Abs(result~, input~) => self.execute_f64_abs(result, input)
      F64Neg(result~, input~) => self.execute_f64_neg(result, input)
      F64Ceil(result~, input~) => self.execute_f64_ceil(result, input)
      F64Floor(result~, input~) => self.execute_f64_floor(result, input)
      F64Trunc(result~, input~) => self.execute_f64_trunc(result, input)
      F64Nearest(result~, input~) => self.execute_f64_nearest(result, input)
      F64Sqrt(result~, input~) => self.execute_f64_sqrt(result, input)
      F64Add(result~, lhs~, rhs~) => self.execute_f64_add(result, lhs, rhs)
      F64Sub(result~, lhs~, rhs~) => self.execute_f64_sub(result, lhs, rhs)
      F64Mul(result~, lhs~, rhs~) => self.execute_f64_mul(result, lhs, rhs)
      F64Div(result~, lhs~, rhs~) => self.execute_f64_div(result, lhs, rhs)
      F64Min(result~, lhs~, rhs~) => self.execute_f64_min(result, lhs, rhs)
      F64Max(result~, lhs~, rhs~) => self.execute_f64_max(result, lhs, rhs)
      F64Copysign(result~, lhs~, rhs~) =>
        self.execute_f64_copysign(result, lhs, rhs)
      F64CopysignImm(result~, lhs~, rhs~) =>
        self.execute_f64_copysign_imm(result, lhs, rhs)
      I32TruncF32S(result~, input~) =>
        self.execute_i32_trunc_f32_s(result, input)
      I32TruncF32U(result~, input~) =>
        self.execute_i32_trunc_f32_u(result, input)
      I32TruncF64S(result~, input~) =>
        self.execute_i32_trunc_f64_s(result, input)
      I32TruncF64U(result~, input~) =>
        self.execute_i32_trunc_f64_u(result, input)
      I64TruncF32S(result~, input~) =>
        self.execute_i64_trunc_f32_s(result, input)
      I64TruncF32U(result~, input~) =>
        self.execute_i64_trunc_f32_u(result, input)
      I64TruncF64S(result~, input~) =>
        self.execute_i64_trunc_f64_s(result, input)
      I64TruncF64U(result~, input~) =>
        self.execute_i64_trunc_f64_u(result, input)
      I32TruncSatF32S(result~, input~) =>
        self.execute_i32_trunc_sat_f32_s(result, input)
      I32TruncSatF32U(result~, input~) =>
        self.execute_i32_trunc_sat_f32_u(result, input)
      I32TruncSatF64S(result~, input~) =>
        self.execute_i32_trunc_sat_f64_s(result, input)
      I32TruncSatF64U(result~, input~) =>
        self.execute_i32_trunc_sat_f64_u(result, input)
      I64TruncSatF32S(result~, input~) =>
        self.execute_i64_trunc_sat_f32_s(result, input)
      I64TruncSatF32U(result~, input~) =>
        self.execute_i64_trunc_sat_f32_u(result, input)
      I64TruncSatF64S(result~, input~) =>
        self.execute_i64_trunc_sat_f64_s(result, input)
      I64TruncSatF64U(result~, input~) =>
        self.execute_i64_trunc_sat_f64_u(result, input)
      F32DemoteF64(result~, input~) =>
        self.execute_f32_demote_f64(result, input)
      F64PromoteF32(result~, input~) =>
        self.execute_f64_promote_f32(result, input)
      F32ConvertI32S(result~, input~) =>
        self.execute_f32_convert_i32_s(result, input)
      F32ConvertI32U(result~, input~) =>
        self.execute_f32_convert_i32_u(result, input)
      F32ConvertI64S(result~, input~) =>
        self.execute_f32_convert_i64_s(result, input)
      F32ConvertI64U(result~, input~) =>
        self.execute_f32_convert_i64_u(result, input)
      F64ConvertI32S(result~, input~) =>
        self.execute_f64_convert_i32_s(result, input)
      F64ConvertI32U(result~, input~) =>
        self.execute_f64_convert_i32_u(result, input)
      F64ConvertI64S(result~, input~) =>
        self.execute_f64_convert_i64_s(result, input)
      F64ConvertI64U(result~, input~) =>
        self.execute_f64_convert_i64_u(result, input)
      TableGet(result~, index~) => self.execute_table_get(store, result, index)
      TableGetImm(result~, index~) =>
        self.execute_table_get_imm(store, result, index)
      TableSize(result~, table~) =>
        self.execute_table_size(store, result, table)
      TableSet(index~, value~) => self.execute_table_set(store, index, value)
      TableSetAt(index~, value~) =>
        self.execute_table_set_at(store, index, value)
      TableCopy(dst~, src~, len~) =>
        self.execute_table_copy(store, dst, src, len)
      TableInit(dst~, src~, len~) =>
        self.execute_table_init(store, dst, src, len)
      TableFill(dst~, len~, value~) =>
        self.execute_table_fill(store, dst, len, value)
      TableGrow(result~, delta~, value~) =>
        self.execute_table_grow(store, result, delta, value)
      ElemDrop(index~) => self.execute_element_drop(store, index)
      DataDrop(index~) => self.execute_data_drop(store, index)
      MemorySize(result~, memory~) =>
        self.execute_memory_size(store, result, memory)
      MemoryGrow(result~, delta~) =>
        self.execute_memory_grow(store, result, delta)
      MemoryCopy(dst~, src~, len~) =>
        self.execute_memory_copy(store, dst, src, len)
      MemoryFill(dst~, value~, len~) =>
        self.execute_memory_fill(store, dst, value, len)
      MemoryFillImm(dst~, value~, len~) =>
        self.execute_memory_fill_imm(store, dst, value, len)
      MemoryInit(dst~, src~, len~) =>
        self.execute_memory_init(store, dst, src, len)
      TableIndex(..)
      | MemoryIndex(..)
      | DataIndex(..)
      | ElemIndex(..)
      | Const32(..)
      | I64Const32(..)
      | F64Const32(..)
      | BranchTableTarget(..)
      | Slot(..)
      | Slot2(..)
      | Slot3(..)
      | SlotAndImm32(..)
      | Imm16AndImm32(..)
      | SlotSpan(..)
      | SlotList(..)
      | CallIndirectParams(..)
      | CallIndirectParamsImm16(..) => self.invalid_instruction_word()
      I8x16Splat(result~, value~) => self.execute_i8x16_splat(result, value)
      I16x8Splat(result~, value~) => self.execute_i16x8_splat(result, value)
      I32x4Splat(result~, value~) => self.execute_i32x4_splat(result, value)
      I64x2Splat(result~, value~) => self.execute_i64x2_splat(result, value)
      F32x4Splat(result~, value~) => self.execute_f32x4_splat(result, value)
      F64x2Splat(result~, value~) => self.execute_f64x2_splat(result, value)
      I8x16ExtractLaneS(result~, value~, lane~) =>
        self.i8x16_extract_lane_s(result, value, lane)
      I8x16ExtractLaneU(result~, value~, lane~) =>
        self.i8x16_extract_lane_u(result, value, lane)
      I16x8ExtractLaneS(result~, value~, lane~) =>
        self.i16x8_extract_lane_s(result, value, lane)
      I16x8ExtractLaneU(result~, value~, lane~) =>
        self.i16x8_extract_lane_u(result, value, lane)
      I32x4ExtractLane(result~, value~, lane~) =>
        self.i32x4_extract_lane(result, value, lane)
      I64x2ExtractLane(result~, value~, lane~) =>
        self.i64x2_extract_lane(result, value, lane)
      F32x4ExtractLane(result~, value~, lane~) =>
        self.f32x4_extract_lane(result, value, lane)
      F64x2ExtractLane(result~, value~, lane~) =>
        self.f64x2_extract_lane(result, value, lane)
      I8x16ReplaceLane(result~, input~, lane~) =>
        self.execute_i8x16_replace_lane(result, input, lane)
      I8x16ReplaceLaneImm(result~, input~, lane~, value~) =>
        self.execute_i8x16_replace_lane_imm(result, input, lane, value)
      I16x8ReplaceLane(result~, input~, lane~) =>
        self.execute_i16x8_replace_lane(result, input, lane)
      I16x8ReplaceLaneImm(result~, input~, lane~) =>
        self.execute_i16x8_replace_lane_imm(result, input, lane)
      I32x4ReplaceLane(result~, input~, lane~) =>
        self.execute_i32x4_replace_lane(result, input, lane)
      I32x4ReplaceLaneImm(result~, input~, lane~) =>
        self.execute_i32x4_replace_lane_imm(result, input, lane)
      I64x2ReplaceLane(result~, input~, lane~) =>
        self.execute_i64x2_replace_lane(result, input, lane)
      I64x2ReplaceLaneImm32(result~, input~, lane~) =>
        self.execute_i64x2_replace_lane_imm32(result, input, lane)
      F32x4ReplaceLane(result~, input~, lane~) =>
        self.execute_f32x4_replace_lane(result, input, lane)
      F32x4ReplaceLaneImm(result~, input~, lane~) =>
        self.execute_f32x4_replace_lane_imm(result, input, lane)
      F64x2ReplaceLane(result~, input~, lane~) =>
        self.execute_f64x2_replace_lane(result, input, lane)
      F64x2ReplaceLaneImm32(result~, input~, lane~) =>
        self.execute_f64x2_replace_lane_imm32(result, input, lane)
      I8x16Shuffle(result~, lhs~, rhs~) =>
        self.execute_i8x16_shuffle(result, lhs, rhs)
      I8x16Swizzle(result~, input~, selector~) =>
        self.execute_i8x16_swizzle(result, input, selector)
      I8x16Add(result~, lhs~, rhs~) => self.execute_i8x16_add(result, lhs, rhs)
      I16x8Add(result~, lhs~, rhs~) => self.execute_i16x8_add(result, lhs, rhs)
      I32x4Add(result~, lhs~, rhs~) => self.execute_i32x4_add(result, lhs, rhs)
      I64x2Add(result~, lhs~, rhs~) => self.execute_i64x2_add(result, lhs, rhs)
      I8x16Sub(result~, lhs~, rhs~) => self.execute_i8x16_sub(result, lhs, rhs)
      I16x8Sub(result~, lhs~, rhs~) => self.execute_i16x8_sub(result, lhs, rhs)
      I32x4Sub(result~, lhs~, rhs~) => self.execute_i32x4_sub(result, lhs, rhs)
      I64x2Sub(result~, lhs~, rhs~) => self.execute_i64x2_sub(result, lhs, rhs)
      I16x8Mul(result~, lhs~, rhs~) => self.execute_i16x8_mul(result, lhs, rhs)
      I32x4Mul(result~, lhs~, rhs~) => self.execute_i32x4_mul(result, lhs, rhs)
      I64x2Mul(result~, lhs~, rhs~) => self.execute_i64x2_mul(result, lhs, rhs)
      I32x4DotI16x8S(result~, lhs~, rhs~) =>
        self.execute_i32x4_dot_i16x8_s(result, lhs, rhs)
      I8x16Neg(result~, input~) => self.execute_i8x16_neg(result, input)
      I16x8Neg(result~, input~) => self.execute_i16x8_neg(result, input)
      I32x4Neg(result~, input~) => self.execute_i32x4_neg(result, input)
      I64x2Neg(result~, input~) => self.execute_i64x2_neg(result, input)
      I16x8ExtmulLowI8x16S(result~, lhs~, rhs~) =>
        self.execute_i16x8_extmul_low_i8x16_s(result, lhs, rhs)
      I16x8ExtmulHighI8x16S(result~, lhs~, rhs~) =>
        self.execute_i16x8_extmul_high_i8x16_s(result, lhs, rhs)
      I16x8ExtmulLowI8x16U(result~, lhs~, rhs~) =>
        self.execute_i16x8_extmul_low_i8x16_u(result, lhs, rhs)
      I16x8ExtmulHighI8x16U(result~, lhs~, rhs~) =>
        self.execute_i16x8_extmul_high_i8x16_u(result, lhs, rhs)
      I32x4ExtmulLowI16x8S(result~, lhs~, rhs~) =>
        self.execute_i32x4_extmul_low_i16x8_s(result, lhs, rhs)
      I32x4ExtmulHighI16x8S(result~, lhs~, rhs~) =>
        self.execute_i32x4_extmul_high_i16x8_s(result, lhs, rhs)
      I32x4ExtmulLowI16x8U(result~, lhs~, rhs~) =>
        self.execute_i32x4_extmul_low_i16x8_u(result, lhs, rhs)
      I32x4ExtmulHighI16x8U(result~, lhs~, rhs~) =>
        self.execute_i32x4_extmul_high_i16x8_u(result, lhs, rhs)
      I64x2ExtmulLowI32x4S(result~, lhs~, rhs~) =>
        self.execute_i64x2_extmul_low_i32x4_s(result, lhs, rhs)
      I64x2ExtmulHighI32x4S(result~, lhs~, rhs~) =>
        self.execute_i64x2_extmul_high_i32x4_s(result, lhs, rhs)
      I64x2ExtmulLowI32x4U(result~, lhs~, rhs~) =>
        self.execute_i64x2_extmul_low_i32x4_u(result, lhs, rhs)
      I64x2ExtmulHighI32x4U(result~, lhs~, rhs~) =>
        self.execute_i64x2_extmul_high_i32x4_u(result, lhs, rhs)
      I16x8ExtaddPairwiseI8x16S(result~, input~) =>
        self.execute_i16x8_extadd_pairwise_i8x16_s(result, input)
      I16x8ExtaddPairwiseI8x16U(result~, input~) =>
        self.execute_i16x8_extadd_pairwise_i8x16_u(result, input)
      I32x4ExtaddPairwiseI16x8S(result~, input~) =>
        self.execute_i32x4_extadd_pairwise_i16x8_s(result, input)
      I32x4ExtaddPairwiseI16x8U(result~, input~) =>
        self.execute_i32x4_extadd_pairwise_i16x8_u(result, input)
      I8x16AddSatS(result~, lhs~, rhs~) =>
        self.execute_i8x16_add_sat_s(result, lhs, rhs)
      I8x16AddSatU(result~, lhs~, rhs~) =>
        self.execute_i8x16_add_sat_u(result, lhs, rhs)
      I16x8AddSatS(result~, lhs~, rhs~) =>
        self.execute_i16x8_add_sat_s(result, lhs, rhs)
      I16x8AddSatU(result~, lhs~, rhs~) =>
        self.execute_i16x8_add_sat_u(result, lhs, rhs)
      I8x16SubSatS(result~, lhs~, rhs~) =>
        self.execute_i8x16_sub_sat_s(result, lhs, rhs)
      I8x16SubSatU(result~, lhs~, rhs~) =>
        self.execute_i8x16_sub_sat_u(result, lhs, rhs)
      I16x8SubSatS(result~, lhs~, rhs~) =>
        self.execute_i16x8_sub_sat_s(result, lhs, rhs)
      I16x8SubSatU(result~, lhs~, rhs~) =>
        self.execute_i16x8_sub_sat_u(result, lhs, rhs)
      I16x8Q15MulrSatS(result~, lhs~, rhs~) =>
        self.execute_i16x8_q15mulr_sat_s(result, lhs, rhs)
      I8x16MinS(result~, lhs~, rhs~) =>
        self.execute_i8x16_min_s(result, lhs, rhs)
      I8x16MinU(result~, lhs~, rhs~) =>
        self.execute_i8x16_min_u(result, lhs, rhs)
      I16x8MinS(result~, lhs~, rhs~) =>
        self.execute_i16x8_min_s(result, lhs, rhs)
      I16x8MinU(result~, lhs~, rhs~) =>
        self.execute_i16x8_min_u(result, lhs, rhs)
      I32x4MinS(result~, lhs~, rhs~) =>
        self.execute_i32x4_min_s(result, lhs, rhs)
      I32x4MinU(result~, lhs~, rhs~) =>
        self.execute_i32x4_min_u(result, lhs, rhs)
      I8x16MaxS(result~, lhs~, rhs~) =>
        self.execute_i8x16_max_s(result, lhs, rhs)
      I8x16MaxU(result~, lhs~, rhs~) =>
        self.execute_i8x16_max_u(result, lhs, rhs)
      I16x8MaxS(result~, lhs~, rhs~) =>
        self.execute_i16x8_max_s(result, lhs, rhs)
      I16x8MaxU(result~, lhs~, rhs~) =>
        self.execute_i16x8_max_u(result, lhs, rhs)
      I32x4MaxS(result~, lhs~, rhs~) =>
        self.execute_i32x4_max_s(result, lhs, rhs)
      I32x4MaxU(result~, lhs~, rhs~) =>
        self.execute_i32x4_max_u(result, lhs, rhs)
      I8x16AvgrU(result~, lhs~, rhs~) =>
        self.execute_i8x16_avgr_u(result, lhs, rhs)
      I16x8AvgrU(result~, lhs~, rhs~) =>
        self.execute_i16x8_avgr_u(result, lhs, rhs)
      I8x16Abs(result~, input~) => self.execute_i8x16_abs(result, input)
      I16x8Abs(result~, input~) => self.execute_i16x8_abs(result, input)
      I32x4Abs(result~, input~) => self.execute_i32x4_abs(result, input)
      I64x2Abs(result~, input~) => self.execute_i64x2_abs(result, input)
      I8x16Shl(result~, lhs~, rhs~) => self.execute_i8x16_shl(result, lhs, rhs)
      I8x16ShlBy(result~, lhs~, rhs~) =>
        self.execute_i8x16_shl_by(result, lhs, rhs)
      I16x8Shl(result~, lhs~, rhs~) => self.execute_i16x8_shl(result, lhs, rhs)
      I16x8ShlBy(result~, lhs~, rhs~) =>
        self.execute_i16x8_shl_by(result, lhs, rhs)
      I32x4Shl(result~, lhs~, rhs~) => self.execute_i32x4_shl(result, lhs, rhs)
      I32x4ShlBy(result~, lhs~, rhs~) =>
        self.execute_i32x4_shl_by(result, lhs, rhs)
      I64x2Shl(result~, lhs~, rhs~) => self.execute_i64x2_shl(result, lhs, rhs)
      I64x2ShlBy(result~, lhs~, rhs~) =>
        self.execute_i64x2_shl_by(result, lhs, rhs)
      I8x16ShrS(result~, lhs~, rhs~) =>
        self.execute_i8x16_shr_s(result, lhs, rhs)
      I8x16ShrSBy(result~, lhs~, rhs~) =>
        self.execute_i8x16_shr_s_by(result, lhs, rhs)
      I8x16ShrU(result~, lhs~, rhs~) =>
        self.execute_i8x16_shr_u(result, lhs, rhs)
      I8x16ShrUBy(result~, lhs~, rhs~) =>
        self.execute_i8x16_shr_u_by(result, lhs, rhs)
      I16x8ShrS(result~, lhs~, rhs~) =>
        self.execute_i16x8_shr_s(result, lhs, rhs)
      I16x8ShrSBy(result~, lhs~, rhs~) =>
        self.execute_i16x8_shr_s_by(result, lhs, rhs)
      I16x8ShrU(result~, lhs~, rhs~) =>
        self.execute_i16x8_shr_u(result, lhs, rhs)
      I16x8ShrUBy(result~, lhs~, rhs~) =>
        self.execute_i16x8_shr_u_by(result, lhs, rhs)
      I32x4ShrS(result~, lhs~, rhs~) =>
        self.execute_i32x4_shr_s(result, lhs, rhs)
      I32x4ShrSBy(result~, lhs~, rhs~) =>
        self.execute_i32x4_shr_s_by(result, lhs, rhs)
      I32x4ShrU(result~, lhs~, rhs~) =>
        self.execute_i32x4_shr_u(result, lhs, rhs)
      I32x4ShrUBy(result~, lhs~, rhs~) =>
        self.execute_i32x4_shr_u_by(result, lhs, rhs)
      I64x2ShrS(result~, lhs~, rhs~) =>
        self.execute_i64x2_shr_s(result, lhs, rhs)
      I64x2ShrSBy(result~, lhs~, rhs~) =>
        self.execute_i64x2_shr_s_by(result, lhs, rhs)
      I64x2ShrU(result~, lhs~, rhs~) =>
        self.execute_i64x2_shr_u(result, lhs, rhs)
      I64x2ShrUBy(result~, lhs~, rhs~) =>
        self.execute_i64x2_shr_u_by(result, lhs, rhs)
      V128And(result~, lhs~, rhs~) => self.execute_v128_and(result, lhs, rhs)
      V128Or(result~, lhs~, rhs~) => self.execute_v128_or(result, lhs, rhs)
      V128Xor(result~, lhs~, rhs~) => self.execute_v128_xor(result, lhs, rhs)
      V128Andnot(result~, lhs~, rhs~) =>
        self.execute_v128_andnot(result, lhs, rhs)
      V128Not(result~, input~) => self.execute_v128_not(result, input)
      V128Bitselect(result~, lhs~, rhs~) =>
        self.execute_v128_bitselect(result, lhs, rhs)
      I8x16Popcnt(result~, input~) => self.execute_i8x16_popcnt(result, input)
      V128AnyTrue(result~, input~) => self.execute_v128_any_true(result, input)
      I8x16AllTrue(result~, input~) =>
        self.execute_i8x16_all_true(result, input)
      I16x8AllTrue(result~, input~) =>
        self.execute_i16x8_all_true(result, input)
      I32x4AllTrue(result~, input~) =>
        self.execute_i32x4_all_true(result, input)
      I64x2AllTrue(result~, input~) =>
        self.execute_i64x2_all_true(result, input)
      I8x16Bitmask(result~, input~) => self.execute_i8x16_bitmask(result, input)
      I16x8Bitmask(result~, input~) => self.execute_i16x8_bitmask(result, input)
      I32x4Bitmask(result~, input~) => self.execute_i32x4_bitmask(result, input)
      I64x2Bitmask(result~, input~) => self.execute_i64x2_bitmask(result, input)
      I8x16Eq(result~, lhs~, rhs~) => self.execute_i8x16_eq(result, lhs, rhs)
      I16x8Eq(result~, lhs~, rhs~) => self.execute_i16x8_eq(result, lhs, rhs)
      I32x4Eq(result~, lhs~, rhs~) => self.execute_i32x4_eq(result, lhs, rhs)
      I64x2Eq(result~, lhs~, rhs~) => self.execute_i64x2_eq(result, lhs, rhs)
      F32x4Eq(result~, lhs~, rhs~) => self.execute_f32x4_eq(result, lhs, rhs)
      F64x2Eq(result~, lhs~, rhs~) => self.execute_f64x2_eq(result, lhs, rhs)
      I8x16Ne(result~, lhs~, rhs~) => self.execute_i8x16_ne(result, lhs, rhs)
      I16x8Ne(result~, lhs~, rhs~) => self.execute_i16x8_ne(result, lhs, rhs)
      I32x4Ne(result~, lhs~, rhs~) => self.execute_i32x4_ne(result, lhs, rhs)
      I64x2Ne(result~, lhs~, rhs~) => self.execute_i64x2_ne(result, lhs, rhs)
      F32x4Ne(result~, lhs~, rhs~) => self.execute_f32x4_ne(result, lhs, rhs)
      F64x2Ne(result~, lhs~, rhs~) => self.execute_f64x2_ne(result, lhs, rhs)
      I8x16LtS(result~, lhs~, rhs~) => self.execute_i8x16_lt_s(result, lhs, rhs)
      I8x16LtU(result~, lhs~, rhs~) => self.execute_i8x16_lt_u(result, lhs, rhs)
      I16x8LtS(result~, lhs~, rhs~) => self.execute_i16x8_lt_s(result, lhs, rhs)
      I16x8LtU(result~, lhs~, rhs~) => self.execute_i16x8_lt_u(result, lhs, rhs)
      I32x4LtS(result~, lhs~, rhs~) => self.execute_i32x4_lt_s(result, lhs, rhs)
      I32x4LtU(result~, lhs~, rhs~) => self.execute_i32x4_lt_u(result, lhs, rhs)
      I64x2LtS(result~, lhs~, rhs~) => self.execute_i64x2_lt_s(result, lhs, rhs)
      F32x4Lt(result~, lhs~, rhs~) => self.execute_f32x4_lt(result, lhs, rhs)
      F64x2Lt(result~, lhs~, rhs~) => self.execute_f64x2_lt(result, lhs, rhs)
      I8x16LeS(result~, lhs~, rhs~) => self.execute_i8x16_le_s(result, lhs, rhs)
      I8x16LeU(result~, lhs~, rhs~) => self.execute_i8x16_le_u(result, lhs, rhs)
      I16x8LeS(result~, lhs~, rhs~) => self.execute_i16x8_le_s(result, lhs, rhs)
      I16x8LeU(result~, lhs~, rhs~) => self.execute_i16x8_le_u(result, lhs, rhs)
      I32x4LeS(result~, lhs~, rhs~) => self.execute_i32x4_le_s(result, lhs, rhs)
      I32x4LeU(result~, lhs~, rhs~) => self.execute_i32x4_le_u(result, lhs, rhs)
      I64x2LeS(result~, lhs~, rhs~) => self.execute_i64x2_le_s(result, lhs, rhs)
      F32x4Le(result~, lhs~, rhs~) => self.execute_f32x4_le(result, lhs, rhs)
      F64x2Le(result~, lhs~, rhs~) => self.execute_f64x2_le(result, lhs, rhs)
      F32x4Neg(result~, input~) => self.execute_f32x4_neg(result, input)
      F64x2Neg(result~, input~) => self.execute_f64x2_neg(result, input)
      F32x4Abs(result~, input~) => self.execute_f32x4_abs(result, input)
      F64x2Abs(result~, input~) => self.execute_f64x2_abs(result, input)
      F32x4Min(result~, lhs~, rhs~) => self.execute_f32x4_min(result, lhs, rhs)
      F64x2Min(result~, lhs~, rhs~) => self.execute_f64x2_min(result, lhs, rhs)
      F32x4Max(result~, lhs~, rhs~) => self.execute_f32x4_max(result, lhs, rhs)
      F64x2Max(result~, lhs~, rhs~) => self.execute_f64x2_max(result, lhs, rhs)
      F32x4Pmin(result~, lhs~, rhs~) =>
        self.execute_f32x4_pmin(result, lhs, rhs)
      F64x2Pmin(result~, lhs~, rhs~) =>
        self.execute_f64x2_pmin(result, lhs, rhs)
      F32x4Pmax(result~, lhs~, rhs~) =>
        self.execute_f32x4_pmax(result, lhs, rhs)
      F64x2Pmax(result~, lhs~, rhs~) =>
        self.execute_f64x2_pmax(result, lhs, rhs)
      F32x4Add(result~, lhs~, rhs~) => self.execute_f32x4_add(result, lhs, rhs)
      F64x2Add(result~, lhs~, rhs~) => self.execute_f64x2_add(result, lhs, rhs)
      F32x4Sub(result~, lhs~, rhs~) => self.execute_f32x4_sub(result, lhs, rhs)
      F64x2Sub(result~, lhs~, rhs~) => self.execute_f64x2_sub(result, lhs, rhs)
      F32x4Div(result~, lhs~, rhs~) => self.execute_f32x4_div(result, lhs, rhs)
      F64x2Div(result~, lhs~, rhs~) => self.execute_f64x2_div(result, lhs, rhs)
      F32x4Mul(result~, lhs~, rhs~) => self.execute_f32x4_mul(result, lhs, rhs)
      F64x2Mul(result~, lhs~, rhs~) => self.execute_f64x2_mul(result, lhs, rhs)
      F32x4Sqrt(result~, input~) => self.execute_f32x4_sqrt(result, input)
      F64x2Sqrt(result~, input~) => self.execute_f64x2_sqrt(result, input)
      F32x4Ceil(result~, input~) => self.execute_f32x4_ceil(result, input)
      F64x2Ceil(result~, input~) => self.execute_f64x2_ceil(result, input)
      F32x4Floor(result~, input~) => self.execute_f32x4_floor(result, input)
      F64x2Floor(result~, input~) => self.execute_f64x2_floor(result, input)
      F32x4Trunc(result~, input~) => self.execute_f32x4_trunc(result, input)
      F64x2Trunc(result~, input~) => self.execute_f64x2_trunc(result, input)
      F32x4Nearest(result~, input~) => self.execute_f32x4_nearest(result, input)
      F64x2Nearest(result~, input~) => self.execute_f64x2_nearest(result, input)
      F32x4ConvertI32x4S(result~, input~) =>
        self.execute_f32x4_convert_i32x4_s(result, input)
      F32x4ConvertI32x4U(result~, input~) =>
        self.execute_f32x4_convert_i32x4_u(result, input)
      F64x2ConvertLowI32x4S(result~, input~) =>
        self.execute_f64x2_convert_low_i32x4_s(result, input)
      F64x2ConvertLowI32x4U(result~, input~) =>
        self.execute_f64x2_convert_low_i32x4_u(result, input)
      I32x4TruncSatF32x4S(result~, input~) =>
        self.execute_i32x4_trunc_sat_f32x4_s(result, input)
      I32x4TruncSatF32x4U(result~, input~) =>
        self.execute_i32x4_trunc_sat_f32x4_u(result, input)
      I32x4TruncSatF64x2SZero(result~, input~) =>
        self.execute_i32x4_trunc_sat_f64x2_s_zero(result, input)
      I32x4TruncSatF64x2UZero(result~, input~) =>
        self.execute_i32x4_trunc_sat_f64x2_u_zero(result, input)
      F32x4DemoteF64x2Zero(result~, input~) =>
        self.execute_f32x4_demote_f64x2_zero(result, input)
      F64x2PromoteLowF32x4(result~, input~) =>
        self.execute_f64x2_promote_low_f32x4(result, input)
      I8x16NarrowI16x8S(result~, lhs~, rhs~) =>
        self.execute_i8x16_narrow_i16x8_s(result, lhs, rhs)
      I8x16NarrowI16x8U(result~, lhs~, rhs~) =>
        self.execute_i8x16_narrow_i16x8_u(result, lhs, rhs)
      I16x8NarrowI32x4S(result~, lhs~, rhs~) =>
        self.execute_i16x8_narrow_i32x4_s(result, lhs, rhs)
      I16x8NarrowI32x4U(result~, lhs~, rhs~) =>
        self.execute_i16x8_narrow_i32x4_u(result, lhs, rhs)
      I16x8ExtendLowI8x16S(result~, input~) =>
        self.execute_i16x8_extend_low_i8x16_s(result, input)
      I16x8ExtendHighI8x16S(result~, input~) =>
        self.execute_i16x8_extend_high_i8x16_s(result, input)
      I16x8ExtendLowI8x16U(result~, input~) =>
        self.execute_i16x8_extend_low_i8x16_u(result, input)
      I16x8ExtendHighI8x16U(result~, input~) =>
        self.execute_i16x8_extend_high_i8x16_u(result, input)
      I32x4ExtendLowI16x8S(result~, input~) =>
        self.execute_i32x4_extend_low_i16x8_s(result, input)
      I32x4ExtendHighI16x8S(result~, input~) =>
        self.execute_i32x4_extend_high_i16x8_s(result, input)
      I32x4ExtendLowI16x8U(result~, input~) =>
        self.execute_i32x4_extend_low_i16x8_u(result, input)
      I32x4ExtendHighI16x8U(result~, input~) =>
        self.execute_i32x4_extend_high_i16x8_u(result, input)
      I64x2ExtendLowI32x4S(result~, input~) =>
        self.execute_i64x2_extend_low_i32x4_s(result, input)
      I64x2ExtendHighI32x4S(result~, input~) =>
        self.execute_i64x2_extend_high_i32x4_s(result, input)
      I64x2ExtendLowI32x4U(result~, input~) =>
        self.execute_i64x2_extend_low_i32x4_u(result, input)
      I64x2ExtendHighI32x4U(result~, input~) =>
        self.execute_i64x2_extend_high_i32x4_u(result, input)
      V128Store(ptr~, offset_lo~) =>
        self.execute_v128_store(store, ptr, offset_lo)
      V128StoreOffset16(ptr~, value~, offset~) =>
        self.execute_v128_store_offset16(ptr, offset, value)
      V128StoreAt(value~, address~) =>
        self.execute_v128_store_at(store, address, value)
      V128Store8Lane(ptr~, offset_lo~) =>
        self.execute_v128_store8_lane(store, ptr, offset_lo)
      V128Store8LaneOffset8(ptr~, value~, offset~, lane~) =>
        self.execute_v128_store8_lane_offset8(ptr, value, offset, lane)
      V128Store8LaneAt(value~, address~) =>
        self.execute_v128_store8_lane_at(store, value, address)
      V128Store16Lane(ptr~, offset_lo~) =>
        self.execute_v128_store16_lane(store, ptr, offset_lo)
      V128Store16LaneOffset8(ptr~, value~, offset~, lane~) =>
        self.execute_v128_store16_lane_offset8(ptr, value, offset, lane)
      V128Store16LaneAt(value~, address~) =>
        self.execute_v128_store16_lane_at(store, value, address)
      V128Store32Lane(ptr~, offset_lo~) =>
        self.execute_v128_store32_lane(store, ptr, offset_lo)
      V128Store32LaneOffset8(ptr~, value~, offset~, lane~) =>
        self.execute_v128_store32_lane_offset8(ptr, value, offset, lane)
      V128Store32LaneAt(value~, address~) =>
        self.execute_v128_store32_lane_at(store, value, address)
      V128Store64Lane(ptr~, offset_lo~) =>
        self.execute_v128_store64_lane(store, ptr, offset_lo)
      V128Store64LaneOffset8(ptr~, value~, offset~, lane~) =>
        self.execute_v128_store64_lane_offset8(ptr, value, offset, lane)
      V128Store64LaneAt(value~, address~) =>
        self.execute_v128_store64_lane_at(store, value, address)
      V128Load(result~, offset_lo~) =>
        self.execute_v128_load(store, result, offset_lo)
      V128LoadAt(result~, address~) =>
        self.execute_v128_load_at(store, result, address)
      V128LoadOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load_offset16(result, ptr, offset)
      V128Load32Zero(result~, offset_lo~) =>
        self.execute_v128_load32_zero(store, result, offset_lo)
      V128Load32ZeroAt(result~, address~) =>
        self.execute_v128_load32_zero_at(store, result, address)
      V128Load32ZeroOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load32_zero_offset16(result, ptr, offset)
      V128Load64Zero(result~, offset_lo~) =>
        self.execute_v128_load64_zero(store, result, offset_lo)
      V128Load64ZeroAt(result~, address~) =>
        self.execute_v128_load64_zero_at(store, result, address)
      V128Load64ZeroOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load64_zero_offset16(result, ptr, offset)
      V128Load8Splat(result~, offset_lo~) =>
        self.execute_v128_load8_splat(store, result, offset_lo)
      V128Load8SplatAt(result~, address~) =>
        self.execute_v128_load8_splat_at(store, result, address)
      V128Load8SplatOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load8_splat_offset16(result, ptr, offset)
      V128Load16Splat(result~, offset_lo~) =>
        self.execute_v128_load16_splat(store, result, offset_lo)
      V128Load16SplatAt(result~, address~) =>
        self.execute_v128_load16_splat_at(store, result, address)
      V128Load16SplatOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load16_splat_offset16(result, ptr, offset)
      V128Load32Splat(result~, offset_lo~) =>
        self.execute_v128_load32_splat(store, result, offset_lo)
      V128Load32SplatAt(result~, address~) =>
        self.execute_v128_load32_splat_at(store, result, address)
      V128Load32SplatOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load32_splat_offset16(result, ptr, offset)
      V128Load64Splat(result~, offset_lo~) =>
        self.execute_v128_load64_splat(store, result, offset_lo)
      V128Load64SplatAt(result~, address~) =>
        self.execute_v128_load64_splat_at(store, result, address)
      V128Load64SplatOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load64_splat_offset16(result, ptr, offset)
      V128Load8x8S(result~, offset_lo~) =>
        self.execute_v128_load8x8_s(store, result, offset_lo)
      V128Load8x8SAt(result~, address~) =>
        self.execute_v128_load8x8_s_at(store, result, address)
      V128Load8x8SOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load8x8_s_offset16(result, ptr, offset)
      V128Load8x8U(result~, offset_lo~) =>
        self.execute_v128_load8x8_u(store, result, offset_lo)
      V128Load8x8UAt(result~, address~) =>
        self.execute_v128_load8x8_u_at(store, result, address)
      V128Load8x8UOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load8x8_u_offset16(result, ptr, offset)
      V128Load16x4S(result~, offset_lo~) =>
        self.execute_v128_load16x4_s(store, result, offset_lo)
      V128Load16x4SAt(result~, address~) =>
        self.execute_v128_load16x4_s_at(store, result, address)
      V128Load16x4SOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load16x4_s_offset16(result, ptr, offset)
      V128Load16x4U(result~, offset_lo~) =>
        self.execute_v128_load16x4_u(store, result, offset_lo)
      V128Load16x4UAt(result~, address~) =>
        self.execute_v128_load16x4_u_at(store, result, address)
      V128Load16x4UOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load16x4_u_offset16(result, ptr, offset)
      V128Load32x2S(result~, offset_lo~) =>
        self.execute_v128_load32x2_s(store, result, offset_lo)
      V128Load32x2SAt(result~, address~) =>
        self.execute_v128_load32x2_s_at(store, result, address)
      V128Load32x2SOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load32x2_s_offset16(result, ptr, offset)
      V128Load32x2U(result~, offset_lo~) =>
        self.execute_v128_load32x2_u(store, result, offset_lo)
      V128Load32x2UAt(result~, address~) =>
        self.execute_v128_load32x2_u_at(store, result, address)
      V128Load32x2UOffset16(result~, ptr~, offset~) =>
        self.execute_v128_load32x2_u_offset16(result, ptr, offset)
      V128Load8Lane(result~, offset_lo~) =>
        self.execute_v128_load8_lane(store, result, offset_lo)
      V128Load8LaneAt(result~, address~) =>
        self.execute_v128_load8_lane_at(store, result, address)
      V128Load16Lane(result~, offset_lo~) =>
        self.execute_v128_load16_lane(store, result, offset_lo)
      V128Load16LaneAt(result~, address~) =>
        self.execute_v128_load16_lane_at(store, result, address)
      V128Load32Lane(result~, offset_lo~) =>
        self.execute_v128_load32_lane(store, result, offset_lo)
      V128Load32LaneAt(result~, address~) =>
        self.execute_v128_load32_lane_at(store, result, address)
      V128Load64Lane(result~, offset_lo~) =>
        self.execute_v128_load64_lane(store, result, offset_lo)
      V128Load64LaneAt(result~, address~) =>
        self.execute_v128_load64_lane_at(store, result, address)
      I16x8RelaxedDotI8x16I7x16S(result~, lhs~, rhs~) =>
        self.execute_i16x8_relaxed_dot_i8x16_i7x16_s(result, lhs, rhs)
      I32x4RelaxedDotI8x16I7x16AddS(result~, lhs~, rhs~) =>
        self.execute_i32x4_relaxed_dot_i8x16_i7x16_add_s(result, lhs, rhs)
      F32x4RelaxedMadd(result~, a~, b~) =>
        self.execute_f32x4_relaxed_madd(result, a, b)
      F32x4RelaxedNmadd(result~, a~, b~) =>
        self.execute_f32x4_relaxed_nmadd(result, a, b)
      F64x2RelaxedMadd(result~, a~, b~) =>
        self.execute_f64x2_relaxed_madd(result, a, b)
      F64x2RelaxedNmadd(result~, a~, b~) =>
        self.execute_f64x2_relaxed_nmadd(result, a, b)
    }
  }
}

// ---------------------------------------------------------------------------
// get_entity!

///|
/// Returns the [`Func`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`Func`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_func(self : Executor, index : @ir.Func) -> Func {
  match self.cache.get_func(index) {
    Some(entity) => entity
    None =>
      abort("missing Func at index \{index.0} for the currently used instance")
  }
}

///|
/// Returns the [`DedupFuncType`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`DedupFuncType`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_func_type_dedup(
  self : Executor,
  index : @ir.FuncType,
) -> DedupFuncType {
  match self.cache.get_func_type_dedup(index) {
    Some(entity) => entity
    None =>
      abort(
        "missing DedupFuncType at index \{index.0} for the currently used instance",
      )
  }
}

///|
/// Returns the [`Memory`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`Memory`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_memory(self : Executor, index : @ir.Memory) -> Memory {
  match self.cache.get_memory(index) {
    Some(entity) => entity
    None =>
      abort(
        "missing Memory at index \{index.0} for the currently used instance",
      )
  }
}

///|
/// Returns the [`Table`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`Table`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_table(self : Executor, index : @ir.Table) -> Table {
  match self.cache.get_table(index) {
    Some(entity) => entity
    None =>
      abort("missing Table at index \{index.0} for the currently used instance")
  }
}

///|
/// Returns the [`Global`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`Global`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_global(self : Executor, index : @ir.Global) -> Global {
  match self.cache.get_global(index) {
    Some(entity) => entity
    None =>
      abort(
        "missing Global at index \{index.0} for the currently used instance",
      )
  }
}

///|
/// Returns the [`DataSegment`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`DataSegment`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_data_segment(self : Executor, index : @ir.Data) -> DataSegment {
  match self.cache.get_data_segment(index) {
    Some(entity) => entity
    None =>
      abort(
        "missing DataSegment at index \{index.0} for the currently used instance",
      )
  }
}

///|
/// Returns the [`ElementSegment`] at `index` for the currently used [`Instance`].
///
/// # Panics
///
/// - If there is no [`ElementSegment`] at `index` for the currently used [`Instance`] in `store`.
fn Executor::get_element_segment(
  self : Executor,
  index : @ir.Elem,
) -> ElementSegment {
  match self.cache.get_element_segment(index) {
    Some(entity) => entity
    None =>
      abort(
        "missing ElementSegment at index \{index.0} for the currently used instance",
      )
  }
}

// ---------------------------------------------------------------------------
// Stack slot accessors (upstream `get_stack_slot`, `get_stack_slot_as::<T>`,
// `set_stack_slot`, `set_stack_slot_as::<T>`: `ReadAs`/`WriteAs` per type).
//
// Like upstream's `WriteAs` the typed setters only write the low 64 bits of
// the cell (keeping the high bits); `set_stack_slot` writes the whole cell.

///|
/// Returns the [`Slot`] value.
fn Executor::get_stack_slot(
  self : Executor,
  slot : @ir.Slot,
) -> @wasmi_core.UntypedVal {
  let i = self.sp + slot.0
  @wasmi_core.UntypedVal::from_v128(
    @wasmi_core.V128::from_lo_hi(self.lo.unsafe_get(i), self.hi.unsafe_get(i)),
  )
}

///|
/// Sets the [`Slot`] value to `value`.
fn Executor::set_stack_slot(
  self : Executor,
  slot : @ir.Slot,
  value : @wasmi_core.UntypedVal,
) -> Unit {
  let i = self.sp + slot.0
  self.lo.unsafe_set(i, value.to_bits64())
  self.hi.unsafe_set(i, value.hi64())
}

///|
/// Returns the [`Slot`] value as `i32`.
fn Executor::get_stack_slot_as_i32(self : Executor, slot : @ir.Slot) -> Int {
  self.lo.unsafe_get(self.sp + slot.0).to_int()
}

///|
/// Returns the [`Slot`] value as `u32`.
fn Executor::get_stack_slot_as_u32(self : Executor, slot : @ir.Slot) -> UInt {
  self.lo.unsafe_get(self.sp + slot.0).to_uint()
}

///|
/// Returns the [`Slot`] value as `i64`.
fn Executor::get_stack_slot_as_i64(self : Executor, slot : @ir.Slot) -> Int64 {
  self.lo.unsafe_get(self.sp + slot.0).reinterpret_as_int64()
}

///|
/// Returns the [`Slot`] value as `u64`.
fn Executor::get_stack_slot_as_u64(self : Executor, slot : @ir.Slot) -> UInt64 {
  self.lo.unsafe_get(self.sp + slot.0)
}

///|
/// Returns the [`Slot`] value as `f32`.
fn Executor::get_stack_slot_as_f32(self : Executor, slot : @ir.Slot) -> Float {
  Float::reinterpret_from_uint(self.lo.unsafe_get(self.sp + slot.0).to_uint())
}

///|
/// Returns the [`Slot`] value as `f64`.
fn Executor::get_stack_slot_as_f64(self : Executor, slot : @ir.Slot) -> Double {
  self.lo.unsafe_get(self.sp + slot.0).reinterpret_as_double()
}

///|
/// Returns the [`Slot`] value as `V128`.
fn Executor::get_stack_slot_as_v128(
  self : Executor,
  slot : @ir.Slot,
) -> @wasmi_core.V128 {
  let i = self.sp + slot.0
  @wasmi_core.V128::from_lo_hi(self.lo.unsafe_get(i), self.hi.unsafe_get(i))
}

///|
/// Sets the [`Slot`] value to the `i32` `value`.
fn Executor::set_stack_slot_as_i32(
  self : Executor,
  slot : @ir.Slot,
  value : Int,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, value.reinterpret_as_uint().to_uint64())
}

///|
/// Sets the [`Slot`] value to the `u32` `value`.
fn Executor::set_stack_slot_as_u32(
  self : Executor,
  slot : @ir.Slot,
  value : UInt,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, value.to_uint64())
}

///|
/// Sets the [`Slot`] value to the `i64` `value`.
fn Executor::set_stack_slot_as_i64(
  self : Executor,
  slot : @ir.Slot,
  value : Int64,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, value.reinterpret_as_uint64())
}

///|
/// Sets the [`Slot`] value to the `u64` `value`.
fn Executor::set_stack_slot_as_u64(
  self : Executor,
  slot : @ir.Slot,
  value : UInt64,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, value)
}

///|
/// Sets the [`Slot`] value to the `f32` `value`.
fn Executor::set_stack_slot_as_f32(
  self : Executor,
  slot : @ir.Slot,
  value : Float,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, value.reinterpret_as_uint().to_uint64())
}

///|
/// Sets the [`Slot`] value to the `f64` `value`.
fn Executor::set_stack_slot_as_f64(
  self : Executor,
  slot : @ir.Slot,
  value : Double,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, value.reinterpret_as_uint64())
}

///|
/// Sets the [`Slot`] value to the `bool` `value`.
fn Executor::set_stack_slot_as_bool(
  self : Executor,
  slot : @ir.Slot,
  value : Bool,
) -> Unit {
  self.lo.unsafe_set(self.sp + slot.0, if value { 1 } else { 0 })
}

///|
/// Sets the [`Slot`] value to the `V128` `value`.
fn Executor::set_stack_slot_as_v128(
  self : Executor,
  slot : @ir.Slot,
  value : @wasmi_core.V128,
) -> Unit {
  let i = self.sp + slot.0
  self.lo.unsafe_set(i, value.lo())
  self.hi.unsafe_set(i, value.hi())
}

///|
/// Re-fetches the cached value stack cell arrays.
///
/// # Note
///
/// Replaces upstream's `on_resize` callbacks: must be called after every
/// operation that may grow (and thus reallocate) the value stack.
fn Executor::sync_cells(self : Executor) -> Unit {
  self.lo = self.stack.values.lo
  self.hi = self.stack.values.hi
}

///|
/// Shifts the instruction pointer to the next instruction.
fn Executor::next_instr(self : Executor) -> Unit {
  self.next_instr_at(1)
}

///|
/// Shifts the instruction pointer to the next instruction.
///
/// Has a parameter `skip` to denote how many instruction words
/// to skip to reach the next actual instruction.
///
/// # Note
///
/// This is used by Wasmi instructions that have a fixed
/// encoding size of two instruction words such as [`Op::Branch`].
fn Executor::next_instr_at(self : Executor, skip : Int) -> Unit {
  self.ip = self.ip + skip
}

///|
/// Initializes the [`Executor`] state for the [`CallFrame`].
///
/// # Note
///
/// The initialization of the [`Executor`] allows for efficient execution.
fn Executor::init_call_frame(self : Executor, frame : CallFrame) -> Unit {
  self.sp = frame.base_offset()
  self.ip = frame.ip
  self.instrs = frame.instrs
  self.sync_cells()
}

///|
/// Returns the optional `memory` parameter for a `load_at` [`Op`].
///
/// # Note
///
/// - Returns the default [`index::Memory`] if the parameter is missing.
/// - Bumps `self.ip` if a [`Op::MemoryIndex`] parameter was found.
fn Executor::fetch_optional_memory(self : Executor, delta : Int) -> @ir.Memory {
  match self.instrs.unsafe_get(self.ip + delta) {
    MemoryIndex(index~) => {
      self.ip = self.ip + 1
      index
    }
    _ => @ir.Memory::Memory(0)
  }
}

///|
/// Fetches the given non-default `memory` (upstream
/// `fetch_non_default_memory_bytes{,_mut}` returning its bytes).
fn Executor::fetch_non_default_memory(
  self : Executor,
  memory : @ir.Memory,
  store : StoreInner,
) -> @wasmi_core.Memory {
  let memory = self.get_memory(memory)
  store.resolve_memory(memory)
}

///|
/// Used for all [`Op`] words that are not meant for execution.
///
/// # Note
///
/// This includes [`Op`] variants such as [`Op::TableIndex`]
/// that primarily carry parameters for actually executable [`Op`].
fn Executor::invalid_instruction_word(self : Executor) -> Unit {
  // Safety: Wasmi translation guarantees that branches are never taken to instruction parameters directly.
  abort("expected instruction but found instruction parameter at \{self.ip}")
}

///|
/// Executes a Wasm `unreachable` instruction.
fn Executor::execute_trap(
  _self : Executor,
  trap_code : @wasmi_core.TrapCode,
) -> Unit raise WasmiError {
  raise WasmiError::TrapCode(trap_code)
}

///|
/// Executes an [`Op::ConsumeFuel`].
fn Executor::execute_consume_fuel(
  self : Executor,
  store : StoreInner,
  block_fuel : @ir.BlockFuel,
) -> Unit raise WasmiError {
  // We do not have to check if fuel metering is enabled since
  // [`Op::ConsumeFuel`] are only generated if fuel metering
  // is enabled to begin with.
  let _ = store.fuel().consume_fuel_unchecked(block_fuel.to_u64()) catch {
      e => raise WasmiError::Fuel(e)
    }
  self.next_instr()
}

///|
/// Executes an [`Op::RefFunc`].
fn Executor::execute_ref_func(
  self : Executor,
  store : StoreInner,
  result : @ir.Slot,
  func_index : @ir.Func,
) -> Unit {
  let func = self.get_func(func_index)
  let funcref = store.funcref_to_untyped(Some(func))
  self.set_stack_slot(result, funcref)
  self.next_instr()
}

// ---------------------------------------------------------------------------
// UntypedValueExt / UntypedValueCmpExt

///|
/// Executes a logical `i32.and` instruction.
fn i32_and(x : Int, y : Int) -> Bool {
  @wasmi_core.i32_bitand(x, y) != 0
}

///|
/// Executes a logical `i32.or` instruction.
fn i32_or(x : Int, y : Int) -> Bool {
  @wasmi_core.i32_bitor(x, y) != 0
}

///|
/// Executes a fused `i32.and` + `i32.eqz` instruction.
fn i32_nand(x : Int, y : Int) -> Bool {
  !i32_and(x, y)
}

///|
/// Executes a fused `i32.or` + `i32.eqz` instruction.
fn i32_nor(x : Int, y : Int) -> Bool {
  !i32_or(x, y)
}

///|
/// Executes a logical `i64.and` instruction.
fn i64_and(x : Int64, y : Int64) -> Bool {
  @wasmi_core.i64_bitand(x, y) != 0
}

///|
/// Executes a logical `i64.or` instruction.
fn i64_or(x : Int64, y : Int64) -> Bool {
  @wasmi_core.i64_bitor(x, y) != 0
}

///|
/// Executes a fused `i64.and` + `i64.eqz` instruction.
fn i64_nand(x : Int64, y : Int64) -> Bool {
  !i64_and(x, y)
}

///|
/// Executes a fused `i64.or` + `i64.eqz` instruction.
fn i64_nor(x : Int64, y : Int64) -> Bool {
  !i64_or(x, y)
}

///|
fn f32_not_le(x : Float, y : Float) -> Bool {
  !@wasmi_core.f32_le(x, y)
}

///|
fn f32_not_lt(x : Float, y : Float) -> Bool {
  !@wasmi_core.f32_lt(x, y)
}

///|
fn f64_not_le(x : Double, y : Double) -> Bool {
  !@wasmi_core.f64_le(x, y)
}

///|
fn f64_not_lt(x : Double, y : Double) -> Bool {
  !@wasmi_core.f64_lt(x, y)
}
