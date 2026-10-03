// Port of wasmi 1.0.9 `engine/translator/func/visit.rs`: the non-numeric
// `visit_*` methods (control flow, calls, variables, memory, tables and
// references). The numeric ones are in engine_translator_func_visit_num.mbt.

///|
/// Upstream `translate_unsupported_operator`.
pub fn FuncTranslator::translate_unsupported_operator(
  _self : FuncTranslator,
  name : String,
) -> Unit raise WasmiError {
  abort("tried to translate an unsupported Wasm operator: \{name}")
}

///|
fn FuncTranslator::visit_unreachable(self : FuncTranslator) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.translate_trap(UnreachableCodeReached)
}

///|
fn FuncTranslator::visit_nop(_self : FuncTranslator) -> Unit raise WasmiError {
  ()
}

///|
fn FuncTranslator::visit_block(
  self : FuncTranslator,
  block_ty : @wasmparser.BlockType,
) -> Unit raise WasmiError {
  if !self.reachable {
    self.stack.push_unreachable(Block)
    return
  }
  self.preserve_all_locals()
  let block_ty = BlockType::new(block_ty, self.module)
  let end_label = self.labels.new_label()
  self.stack.push_block(block_ty, end_label)
}

///|
fn FuncTranslator::visit_loop(
  self : FuncTranslator,
  block_ty : @wasmparser.BlockType,
) -> Unit raise WasmiError {
  if !self.reachable {
    self.stack.push_unreachable(Loop)
    return
  }
  self.preserve_all_locals()
  let block_ty = BlockType::new(block_ty, self.module)
  let len_params = block_ty.len_params(self.engine)
  let continue_label = self.labels.new_label()
  let consume_fuel = self.stack.consume_fuel_instr()
  self.move_operands_to_temp(len_params, consume_fuel)
  self.pin_label(continue_label)
  let consume_fuel = self.instrs.push_consume_fuel_instr()
  self.stack.push_loop(block_ty, continue_label, consume_fuel)
  // Need to reset `last_instr` because a loop header is a control flow boundary.
  self.instrs.reset_last_instr()
}

///|
fn FuncTranslator::visit_if(
  self : FuncTranslator,
  block_ty : @wasmparser.BlockType,
) -> Unit raise WasmiError {
  if !self.reachable {
    self.stack.push_unreachable(If)
    return
  }
  let end_label = self.labels.new_label()
  let condition = self.stack.pop()
  self.preserve_all_locals()
  let (reachability, consume_fuel_instr) = match condition {
    Immediate(operand) => {
      let condition = operand.val().to_i32()
      let reachability : IfReachability = if condition == 0 {
        self.reachable = false
        OnlyElse
      } else {
        OnlyThen
      }
      let consume_fuel_instr = self.stack.consume_fuel_instr()
      (reachability, consume_fuel_instr)
    }
    _ => {
      let else_label = self.labels.new_label()
      self.encode_br_eqz(condition, else_label)
      let reachability : IfReachability = Both(else_label~)
      let consume_fuel_instr = self.instrs.push_consume_fuel_instr()
      (reachability, consume_fuel_instr)
    }
  }
  let block_ty = BlockType::new(block_ty, self.module)
  self.stack.push_if(block_ty, end_label, reachability, consume_fuel_instr)
}

///|
fn FuncTranslator::visit_else(self : FuncTranslator) -> Unit raise WasmiError {
  let frame = match self.stack.pop_control() {
    If(frame) => frame
    Unreachable(If) => {
      self.stack.push_unreachable(Else)
      return
    }
    _ => abort("expected `if` control frame")
  }
  // After `then` block, before `else` block:
  // - Copy `if` branch parameters.
  // - Branch from end of `then` to end of `if`.
  let is_end_of_then_reachable = self.reachable
  if frame.reachability() is Both(else_label~) {
    if is_end_of_then_reachable {
      let consume_fuel_instr = frame.base.consume_fuel_instr()
      self.copy_branch_params(frame.base, consume_fuel_instr)
      frame.base.branch_to()
      self.encode_br(frame.base.label()) |> ignore
    }
    // Start of `else` block:
    self.labels.pin_label(else_label, self.instrs.next_instr()) catch {
      err => abort("\{err}")
    }
    self.instrs.reset_last_instr()
  }
  let consume_fuel_instr = self.instrs.push_consume_fuel_instr()
  self.reachable = frame.is_else_reachable()
  self.stack.push_else(frame, is_end_of_then_reachable, consume_fuel_instr)
}

///|
fn FuncTranslator::visit_end(self : FuncTranslator) -> Unit raise WasmiError {
  match self.stack.pop_control() {
    Block(frame) => self.translate_end_block(frame)
    Loop(frame) => self.translate_end_loop(frame)
    If(frame) => self.translate_end_if(frame)
    Else(frame) => self.translate_end_else(frame)
    Unreachable(frame) => self.translate_end_unreachable(frame)
  }
}

///|
fn FuncTranslator::visit_br(self : FuncTranslator, depth : UInt) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let depth = depth.reinterpret_as_int()
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  match self.stack.peek_control_mut(depth) {
    Return(_) => self.visit_return()
    Branch(frame) => {
      frame.branch_to()
      let label = frame.label()
      let len_params = frame.len_branch_params(self.engine)
      let branch_results = FuncTranslator::frame_results_impl(
        frame,
        self.engine,
        self.layout,
      )
      if branch_results is Some(branch_results) {
        self.encode_copies(branch_results, len_params, consume_fuel_instr)
      }
      self.encode_br(label) |> ignore
      self.reachable = false
    }
  }
}

///|
fn FuncTranslator::visit_br_if(self : FuncTranslator, depth : UInt) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let condition = self.stack.pop()
  if condition is Immediate(condition) {
    if condition.val().to_i32() != 0 {
      // Case (true): always takes the branch
      self.visit_br(depth)
    }
    return
  }
  let depth = depth.reinterpret_as_int()
  let frame = self.stack.peek_control_mut(depth).control_frame()
  frame.branch_to()
  let len_branch_params = frame.len_branch_params(self.engine)
  let branch_results = FuncTranslator::frame_results_impl(
    frame,
    self.engine,
    self.layout,
  )
  let label = frame.label()
  if len_branch_params == 0 {
    // Case: no branch values are required to be copied
    self.encode_br_nez(condition, label)
    return
  }
  if !self.requires_branch_param_copies(depth) {
    // Case: no branch values are required to be copied
    self.encode_br_nez(condition, label)
    return
  }
  // Case: fallback to copy branch parameters conditionally
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  let skip_label = self.labels.new_label()
  self.encode_br_eqz(condition, skip_label)
  if branch_results is Some(branch_results) {
    self.encode_copies(branch_results, len_branch_params, consume_fuel_instr)
  }
  self.encode_br(label) |> ignore
  self.labels.pin_label(skip_label, self.instrs.next_instr()) catch {
    err => abort("\{err}")
  }
}

///|
fn FuncTranslator::visit_br_table(
  self : FuncTranslator,
  table : @wasmparser.BrTable,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let index = self.stack.pop()
  let default_target = table.default()
  if table.is_empty() {
    // Case: the `br_table` only has a single target `t` which is equal to a `br t`.
    return self.visit_br(default_target)
  }
  if index is Immediate(index) {
    // Case: the `br_table` index is a constant value, therefore always taking the same branch.
    // Note: `usize::MAX` is used to fallback to the default target.
    let chosen_index = index.val().to_u32()
    let targets = table.targets()
    let chosen_target = if chosen_index < targets.length().reinterpret_as_uint() {
      targets[chosen_index.reinterpret_as_int()]
    } else {
      default_target
    }
    return self.visit_br(chosen_target)
  }
  FuncTranslator::copy_targets_from_br_table(table, self.immediates)
  let mut all_default = true
  for target in self.immediates {
    if target.to_u32() != default_target {
      all_default = false
      break
    }
  }
  if all_default {
    // Case: all targets are the same and thus the `br_table` is equal to a `br`.
    return self.visit_br(default_target)
  }
  // Note: The Wasm spec mandates that all `br_table` targets manipulate the
  //       Wasm value stack the same. This implies for Wasmi that all `br_table`
  //       targets have the same branch parameter arity.
  let default_target = default_target.reinterpret_as_int()
  let index = self.layout.operand_to_reg(index)
  let len_branch_params = self.stack
    .peek_control(default_target)
    .base()
    .len_branch_params(self.engine)
  match len_branch_params {
    0 => self.encode_br_table_0(table, index)
    n => self.encode_br_table_n(table, index, n)
  }
  self.reachable = false
}

///|
fn FuncTranslator::visit_return(self : FuncTranslator) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  self.encode_return(consume_fuel_instr) |> ignore
  let len_results = self.func_type().len_results()
  for _ in 0..<len_results {
    self.stack.pop() |> ignore
  }
  self.reachable = false
}

///|
/// Upstream `FuelCostsProvider::call`.
fn fuel_call(costs : @wasmi_core.FuelCostsProvider) -> UInt64 {
  costs.call()
}

///|
/// Upstream `FuelCostsProvider::instance`.
fn fuel_instance(costs : @wasmi_core.FuelCostsProvider) -> UInt64 {
  costs.instance()
}

///|
fn FuncTranslator::visit_call(
  self : FuncTranslator,
  function_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let func_idx = FuncIdx(function_index.reinterpret_as_int())
  let func_type = self.resolve_func_type(func_idx)
  let len_params = func_type.len_params()
  let results = self.call_regspan(len_params)
  let instr = match self.module.get_engine_func(func_idx) {
    Some(engine_func) =>
      // Case: We are calling an internal function and can optimize
      //       this case by using the special instruction for it.
      match len_params {
        0 => @ir.Op::call_internal_0(results, engine_func.to_internal())
        _ => @ir.Op::call_internal(results, engine_func.to_internal())
      }
    None =>
      // Case: We are calling an imported function and must use the
      //       general calling operator for it.
      match len_params {
        0 =>
          @ir.Op::call_imported_0(
            results,
            @ir.Func(function_index.reinterpret_as_int()),
          )
        _ =>
          @ir.Op::call_imported(
            results,
            @ir.Func(function_index.reinterpret_as_int()),
          )
      }
  }
  let call_instr = self.push_instr(instr, fuel_call)
  self.stack.pop_n(len_params, self.operands)
  self.instrs.encode_register_list(self.operands[:], self.layout)
  self.push_results(call_instr, func_type.results()) |> ignore
}

///|
fn FuncTranslator::visit_call_indirect(
  self : FuncTranslator,
  type_index : UInt,
  table_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let func_type = self.resolve_type(type_index)
  let index = self.stack.pop()
  let indirect_params = self.call_indirect_params(index, table_index)
  let len_params = func_type.len_params()
  let results = self.call_regspan(len_params)
  let type_index = @ir.FuncType(type_index.reinterpret_as_int())
  let instr = match (len_params, indirect_params) {
    (0, CallIndirectParams(_)) => @ir.Op::call_indirect_0(results, type_index)
    (0, CallIndirectParamsImm16(_)) =>
      @ir.Op::call_indirect_0_imm16(results, type_index)
    (_, CallIndirectParams(_)) => @ir.Op::call_indirect(results, type_index)
    (_, CallIndirectParamsImm16(_)) =>
      @ir.Op::call_indirect_imm16(results, type_index)
    _ => abort("unreachable")
  }
  let call_instr = self.push_instr(instr, fuel_call)
  self.push_param(indirect_params)
  self.stack.pop_n(len_params, self.operands)
  self.instrs.encode_register_list(self.operands[:], self.layout)
  self.push_results(call_instr, func_type.results()) |> ignore
}

///|
fn FuncTranslator::visit_drop(self : FuncTranslator) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.pop() |> ignore
}

///|
fn FuncTranslator::visit_select(self : FuncTranslator) -> Unit raise WasmiError {
  self.translate_select(None)
}

///|
fn FuncTranslator::visit_local_get(
  self : FuncTranslator,
  local_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let local_idx = LocalIdx(local_index)
  let ty = self.locals.ty(local_idx)
  self.stack.push_local(local_idx, ty) |> ignore
}

///|
fn FuncTranslator::visit_local_set(
  self : FuncTranslator,
  local_index : UInt,
) -> Unit raise WasmiError {
  self.translate_local_set(local_index, false)
}

///|
fn FuncTranslator::visit_local_tee(
  self : FuncTranslator,
  local_index : UInt,
) -> Unit raise WasmiError {
  self.translate_local_set(local_index, true)
}

///|
fn FuncTranslator::visit_global_get(
  self : FuncTranslator,
  global_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let global_idx = GlobalIdx(global_index.reinterpret_as_int())
  let (global_type, init_value) = self.module.get_global(global_idx)
  let content = global_type.content()
  if (global_type.mutability(), init_value) is (Const, Some(init_expr)) {
    if init_expr.eval_const() is Some(value) {
      // Case: access to immutable internally defined global variables
      //       can be replaced with their constant initialization value.
      self.stack.push_immediate(@wasmi_core.TypedVal::new(content, value))
      |> ignore
      return
    }
    if init_expr.funcref() is Some(func_index) {
      // Case: forward to `ref.func x` translation.
      self.visit_ref_func(func_index.0.reinterpret_as_uint())
      return
    }
  }
  // Case: The `global.get` instruction accesses a mutable or imported
  //       global variable and thus cannot be optimized away.
  let global_idx = @ir.Global(global_index.reinterpret_as_int())
  self.push_instr_with_result(
    content,
    fn(result) { @ir.Op::global_get(result, global_idx) },
    fuel_instance,
  )
}

///|
fn FuncTranslator::visit_global_set(
  self : FuncTranslator,
  global_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let global = @ir.Global(global_index.reinterpret_as_int())
  let input = match self.stack.pop() {
    Immediate(input) => input.val()
    input => {
      // Case: `global.set` with simple register input.
      let input = self.layout.operand_to_reg(input)
      self.push_instr(@ir.Op::global_set(input, global), fuel_instance) |> ignore
      return
    }
  }
  // Note: at this point we handle the different immediate `global.set` instructions.
  let (global_type, _init_value) = self.module.get_global(
    GlobalIdx(global_index.reinterpret_as_int()),
  )
  match global_type.content() {
    I32 =>
      if @ir.Const16::try_from_i32(input.to_i32()) is Some(value) {
        // Case: `global.set` with 16-bit encoded `i32` value.
        self.push_instr(@ir.Op::global_set_i32imm16(value, global), fuel_instance)
        |> ignore
        return
      }
    I64 =>
      if @ir.Const16::try_from_i64(input.to_i64()) is Some(value) {
        // Case: `global.set` with 16-bit encoded `i64` value.
        self.push_instr(@ir.Op::global_set_i64imm16(value, global), fuel_instance)
        |> ignore
        return
      }
    _ => ()
  }
  // Note: at this point we have to allocate a function local constant.
  let cref = self.layout.const_to_reg(input.untyped())
  self.push_instr(@ir.Op::global_set(cref, global), fuel_instance) |> ignore
}

///|
fn FuncTranslator::visit_i32_load(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I32,
    @ir.Op::load32,
    @ir.Op::load32_offset16,
    @ir.Op::load32_at,
  )
}

///|
fn FuncTranslator::visit_i64_load(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::load64,
    @ir.Op::load64_offset16,
    @ir.Op::load64_at,
  )
}

///|
fn FuncTranslator::visit_f32_load(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    F32,
    @ir.Op::load32,
    @ir.Op::load32_offset16,
    @ir.Op::load32_at,
  )
}

///|
fn FuncTranslator::visit_f64_load(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    F64,
    @ir.Op::load64,
    @ir.Op::load64_offset16,
    @ir.Op::load64_at,
  )
}

///|
fn FuncTranslator::visit_i32_load8_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I32,
    @ir.Op::i32_load8_s,
    @ir.Op::i32_load8_s_offset16,
    @ir.Op::i32_load8_s_at,
  )
}

///|
fn FuncTranslator::visit_i32_load8_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I32,
    @ir.Op::i32_load8_u,
    @ir.Op::i32_load8_u_offset16,
    @ir.Op::i32_load8_u_at,
  )
}

///|
fn FuncTranslator::visit_i32_load16_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I32,
    @ir.Op::i32_load16_s,
    @ir.Op::i32_load16_s_offset16,
    @ir.Op::i32_load16_s_at,
  )
}

///|
fn FuncTranslator::visit_i32_load16_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I32,
    @ir.Op::i32_load16_u,
    @ir.Op::i32_load16_u_offset16,
    @ir.Op::i32_load16_u_at,
  )
}

///|
fn FuncTranslator::visit_i64_load8_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::i64_load8_s,
    @ir.Op::i64_load8_s_offset16,
    @ir.Op::i64_load8_s_at,
  )
}

///|
fn FuncTranslator::visit_i64_load8_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::i64_load8_u,
    @ir.Op::i64_load8_u_offset16,
    @ir.Op::i64_load8_u_at,
  )
}

///|
fn FuncTranslator::visit_i64_load16_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::i64_load16_s,
    @ir.Op::i64_load16_s_offset16,
    @ir.Op::i64_load16_s_at,
  )
}

///|
fn FuncTranslator::visit_i64_load16_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::i64_load16_u,
    @ir.Op::i64_load16_u_offset16,
    @ir.Op::i64_load16_u_at,
  )
}

///|
fn FuncTranslator::visit_i64_load32_s(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::i64_load32_s,
    @ir.Op::i64_load32_s_offset16,
    @ir.Op::i64_load32_s_at,
  )
}

///|
fn FuncTranslator::visit_i64_load32_u(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_load(
    memarg,
    I64,
    @ir.Op::i64_load32_u,
    @ir.Op::i64_load32_u_offset16,
    @ir.Op::i64_load32_u_at,
  )
}

///|
fn FuncTranslator::visit_i32_store(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i32_store_op, memarg)
}

///|
fn FuncTranslator::visit_i64_store(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i64_store_op, memarg)
}

///|
fn FuncTranslator::visit_f32_store(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_store(
    memarg,
    @ir.Op::store32,
    @ir.Op::store32_offset16,
    @ir.Op::store32_at,
  )
}

///|
fn FuncTranslator::visit_f64_store(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_store(
    memarg,
    @ir.Op::store64,
    @ir.Op::store64_offset16,
    @ir.Op::store64_at,
  )
}

///|
fn FuncTranslator::visit_i32_store8(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i32_store8_op, memarg)
}

///|
fn FuncTranslator::visit_i32_store16(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i32_store16_op, memarg)
}

///|
fn FuncTranslator::visit_i64_store8(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i64_store8_op, memarg)
}

///|
fn FuncTranslator::visit_i64_store16(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i64_store16_op, memarg)
}

///|
fn FuncTranslator::visit_i64_store32(
  self : FuncTranslator,
  memarg : @wasmparser.MemArg,
) -> Unit raise WasmiError {
  self.translate_istore_wrap(i64_store32_op, memarg)
}

///|
fn FuncTranslator::visit_memory_size(
  self : FuncTranslator,
  mem : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let index_ty = self.module
    .get_type_of_memory(MemoryIdx(mem.reinterpret_as_int()))
    .index_ty()
    .ty()
  let memory = @ir.Memory(mem.reinterpret_as_int())
  self.push_instr_with_result(
    index_ty,
    fn(result) { @ir.Op::memory_size(result, memory) },
    fuel_instance,
  )
}

///|
fn FuncTranslator::visit_memory_grow(
  self : FuncTranslator,
  mem : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let index_ty = self.module
    .get_type_of_memory(MemoryIdx(mem.reinterpret_as_int()))
    .index_ty()
  let memory = @ir.Memory(mem.reinterpret_as_int())
  let delta = self.stack.pop()
  if delta is Immediate(delta) {
    let delta = delta.val()
    let delta = match index_ty {
      I32 => delta.to_u32().to_uint64()
      I64 => delta.to_u64()
    }
    if delta == 0 {
      // Case: growing by 0 pages.
      //
      // Since `memory.grow` returns the `memory.size` before the
      // operation a `memory.grow` with `delta` of 0 can be translated
      // as `memory.size` instruction instead.
      self.push_instr_with_result(
        index_ty.ty(),
        fn(result) { @ir.Op::memory_size(result, memory) },
        fuel_instance,
      )
      return
    }
  }
  // Case: fallback to generic `memory.grow` instruction
  let delta = self.immediate_to_reg(delta)
  self.push_instr_with_result(
    index_ty.ty(),
    fn(result) { @ir.Op::memory_grow(result, delta) },
    fuel_instance,
  )
  self.push_param(@ir.Op::memory_index(memory))
}

///|
fn FuncTranslator::visit_i32_const(
  self : FuncTranslator,
  value : Int,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.push_immediate(@wasmi_core.TypedVal::from_i32(value)) |> ignore
}

///|
fn FuncTranslator::visit_i64_const(
  self : FuncTranslator,
  value : Int64,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.push_immediate(@wasmi_core.TypedVal::from_i64(value)) |> ignore
}

///|
fn FuncTranslator::visit_f32_const(
  self : FuncTranslator,
  bits : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.push_immediate(
    @wasmi_core.TypedVal::new(F32, @wasmi_core.UntypedVal::from_u32(bits)),
  )
  |> ignore
}

///|
fn FuncTranslator::visit_f64_const(
  self : FuncTranslator,
  bits : UInt64,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.push_immediate(
    @wasmi_core.TypedVal::new(F64, @wasmi_core.UntypedVal::from_u64(bits)),
  )
  |> ignore
}

///|
fn FuncTranslator::visit_i32_eqz(self : FuncTranslator) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.push_immediate(@wasmi_core.TypedVal::from_i32(0)) |> ignore
  self.visit_i32_eq()
}

///|
fn FuncTranslator::visit_i64_eqz(self : FuncTranslator) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.stack.push_immediate(@wasmi_core.TypedVal::from_i64(0)) |> ignore
  self.visit_i64_eq()
}

///|
fn FuncTranslator::visit_memory_init(
  self : FuncTranslator,
  data_index : UInt,
  mem : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (dst, src, len) = self.stack.pop3()
  let dst = self.immediate_to_reg(dst)
  let src = self.immediate_to_reg(src)
  let len = self.immediate_to_reg(len)
  self.push_instr(@ir.Op::memory_init(dst, src, len), fuel_instance) |> ignore
  self.push_param(@ir.Op::memory_index(@ir.Memory(mem.reinterpret_as_int())))
  self.push_param(@ir.Op::data_index(@ir.Data(data_index.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_data_drop(
  self : FuncTranslator,
  data_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.push_instr(
    @ir.Op::data_drop(@ir.Data(data_index.reinterpret_as_int())),
    fuel_instance,
  )
  |> ignore
}

///|
fn FuncTranslator::visit_memory_copy(
  self : FuncTranslator,
  dst_mem : UInt,
  src_mem : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (dst, src, len) = self.stack.pop3()
  let dst = self.immediate_to_reg(dst)
  let src = self.immediate_to_reg(src)
  let len = self.immediate_to_reg(len)
  self.push_instr(@ir.Op::memory_copy(dst, src, len), fuel_instance) |> ignore
  self.push_param(@ir.Op::memory_index(@ir.Memory(dst_mem.reinterpret_as_int())))
  self.push_param(@ir.Op::memory_index(@ir.Memory(src_mem.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_memory_fill(
  self : FuncTranslator,
  mem : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (dst, value, len) = self.stack.pop3()
  let dst = self.immediate_to_reg(dst)
  let value : Input[Int] = self.make_input(value, fn(_, value) {
    let byte = value.to_u32().reinterpret_as_int() & 0xFF
    Immediate(byte)
  })
  let len = self.immediate_to_reg(len)
  let instr = match value {
    Slot(value) => @ir.Op::memory_fill(dst, value, len)
    Immediate(value) => @ir.Op::memory_fill_imm(dst, value, len)
  }
  self.push_instr(instr, fuel_instance) |> ignore
  self.push_param(@ir.Op::memory_index(@ir.Memory(mem.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_table_init(
  self : FuncTranslator,
  elem_index : UInt,
  table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (dst, src, len) = self.stack.pop3()
  let dst = self.immediate_to_reg(dst)
  let src = self.immediate_to_reg(src)
  let len = self.immediate_to_reg(len)
  self.push_instr(@ir.Op::table_init(dst, src, len), fuel_instance) |> ignore
  self.push_param(@ir.Op::table_index(@ir.Table(table.reinterpret_as_int())))
  self.push_param(@ir.Op::elem_index(@ir.Elem(elem_index.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_elem_drop(
  self : FuncTranslator,
  elem_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  self.push_instr(
    @ir.Op::elem_drop(@ir.Elem(elem_index.reinterpret_as_int())),
    fuel_instance,
  )
  |> ignore
}

///|
fn FuncTranslator::visit_table_copy(
  self : FuncTranslator,
  dst_table : UInt,
  src_table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (dst, src, len) = self.stack.pop3()
  let dst = self.immediate_to_reg(dst)
  let src = self.immediate_to_reg(src)
  let len = self.immediate_to_reg(len)
  self.push_instr(@ir.Op::table_copy(dst, src, len), fuel_instance) |> ignore
  self.push_param(@ir.Op::table_index(@ir.Table(dst_table.reinterpret_as_int())))
  self.push_param(@ir.Op::table_index(@ir.Table(src_table.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_typed_select(
  self : FuncTranslator,
  ty : @wasmparser.ValType,
) -> Unit raise WasmiError {
  let type_hint = WasmiValueType::from_wasmparser(ty)
  self.translate_select(Some(type_hint))
}

///|
fn FuncTranslator::visit_ref_null(
  self : FuncTranslator,
  ty : @wasmparser.HeapType,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let type_hint = WasmiValueType::from_heap_type(ty)
  let null = match type_hint {
    FuncRef | ExternRef =>
      @wasmi_core.TypedVal::new(type_hint, @wasmi_core.UntypedVal::from_u64(0))
    _ => abort("expected a Wasm `reftype`")
  }
  self.stack.push_immediate(null) |> ignore
}

///|
fn FuncTranslator::visit_ref_is_null(self : FuncTranslator) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  match self.stack.pop() {
    Local(input) => {
      // Note: `funcref` and `externref` both serialize to `UntypedValue`
      //       as `u64` so we can use `i64.eqz` translation for `ref.is_null`
      //       via reinterpretation of the value's type.
      self.stack.push_local(input.local_index(), I64) |> ignore
      self.visit_i64_eqz()
    }
    Temp(input) => {
      // Note: `funcref` and `externref` both serialize to `UntypedValue`
      //       as `u64` so we can use `i64.eqz` translation for `ref.is_null`
      //       via reinterpretation of the value's type.
      self.stack.push_temp(I64, input.instr()) |> ignore
      self.visit_i64_eqz()
    }
    Immediate(input) => {
      let untyped = input.val().untyped()
      let is_null = match input.ty() {
        FuncRef | ExternRef => untyped.to_bits64() == 0
        _ => abort("`ref.is_null`: encountered invalid input type")
      }
      self.stack.push_immediate(
        @wasmi_core.TypedVal::from_i32(if is_null { 1 } else { 0 }),
      )
      |> ignore
    }
  }
}

///|
fn FuncTranslator::visit_ref_func(
  self : FuncTranslator,
  function_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let func = @ir.Func(function_index.reinterpret_as_int())
  self.push_instr_with_result(
    FuncRef,
    fn(result) { @ir.Op::ref_func(result, func) },
    fuel_instance,
  )
}

///|
fn FuncTranslator::visit_table_fill(
  self : FuncTranslator,
  table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let (dst, value, len) = self.stack.pop3()
  let dst = self.immediate_to_reg(dst)
  let value = self.immediate_to_reg(value)
  let len = self.immediate_to_reg(len)
  self.push_instr(@ir.Op::table_fill(dst, len, value), fuel_instance) |> ignore
  self.push_param(@ir.Op::table_index(@ir.Table(table.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_table_get(
  self : FuncTranslator,
  table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let table_type = self.module.get_type_of_table(
    TableIdx(table.reinterpret_as_int()),
  )
  let index = self.stack.pop()
  let item_ty = table_type.element()
  let index_ty = table_type.index_ty()
  let index = self.make_index32(index, index_ty)
  self.push_instr_with_result(
    item_ty,
    fn(result) {
      match index {
        Slot(index) => @ir.Op::table_get(result, index)
        Immediate(index) => @ir.Op::table_get_imm(result, index)
      }
    },
    fuel_instance,
  )
  self.push_param(@ir.Op::table_index(@ir.Table(table.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_table_set(
  self : FuncTranslator,
  table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let table_type = self.module.get_type_of_table(
    TableIdx(table.reinterpret_as_int()),
  )
  let index_ty = table_type.index_ty()
  let (index, value) = self.stack.pop2()
  let index = self.make_index32(index, index_ty)
  let value = self.layout.operand_to_reg(value)
  let instr = match index {
    Slot(index) => @ir.Op::table_set(index, value)
    Immediate(index) => @ir.Op::table_set_at(value, index)
  }
  self.push_instr(instr, fuel_instance) |> ignore
  self.push_param(@ir.Op::table_index(@ir.Table(table.reinterpret_as_int())))
}

///|
fn FuncTranslator::visit_table_grow(
  self : FuncTranslator,
  table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let table_type = self.module.get_type_of_table(
    TableIdx(table.reinterpret_as_int()),
  )
  let index_ty = table_type.index_ty()
  let table_idx = @ir.Table(table.reinterpret_as_int())
  let (value, delta) = self.stack.pop2()
  if delta is Immediate(delta) {
    let delta = delta.val()
    let delta = match index_ty {
      I32 => delta.to_u32().to_uint64()
      I64 => delta.to_u64()
    }
    if delta == 0 {
      // Case: growing by 0 elements.
      //
      // Since `table.grow` returns the `table.size` before the
      // operation a `table.grow` with `delta` of 0 can be translated
      // as `table.size` instruction instead.
      self.push_instr_with_result(
        index_ty.ty(),
        fn(result) { @ir.Op::table_size(result, table_idx) },
        fuel_instance,
      )
      return
    }
  }
  let value = self.immediate_to_reg(value)
  let delta = self.immediate_to_reg(delta)
  self.push_instr_with_result(
    index_ty.ty(),
    fn(result) { @ir.Op::table_grow(result, delta, value) },
    fuel_instance,
  )
  self.push_param(@ir.Op::table_index(table_idx))
}

///|
fn FuncTranslator::visit_table_size(
  self : FuncTranslator,
  table : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let table_type = self.module.get_type_of_table(
    TableIdx(table.reinterpret_as_int()),
  )
  let index_ty = table_type.index_ty()
  let table_idx = @ir.Table(table.reinterpret_as_int())
  self.push_instr_with_result(
    index_ty.ty(),
    fn(result) { @ir.Op::table_size(result, table_idx) },
    fuel_instance,
  )
}

///|
fn FuncTranslator::visit_return_call(
  self : FuncTranslator,
  function_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let func_idx = FuncIdx(function_index.reinterpret_as_int())
  let func_type = self.resolve_func_type(func_idx)
  let len_params = func_type.len_params()
  let instr = match self.module.get_engine_func(func_idx) {
    Some(engine_func) =>
      // Case: We are calling an internal function and can optimize
      //       this case by using the special instruction for it.
      match len_params {
        0 => @ir.Op::return_call_internal_0(engine_func.to_internal())
        _ => @ir.Op::return_call_internal(engine_func.to_internal())
      }
    None => {
      // Case: We are calling an imported function and must use the
      //       general calling operator for it.
      let func = @ir.Func(function_index.reinterpret_as_int())
      match len_params {
        0 => @ir.Op::return_call_imported_0(func)
        _ => @ir.Op::return_call_imported(func)
      }
    }
  }
  self.push_instr(instr, fuel_call) |> ignore
  self.stack.pop_n(len_params, self.operands)
  self.instrs.encode_register_list(self.operands[:], self.layout)
  self.reachable = false
}

///|
fn FuncTranslator::visit_return_call_indirect(
  self : FuncTranslator,
  type_index : UInt,
  table_index : UInt,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let func_type = self.resolve_type(type_index)
  let index = self.stack.pop()
  let indirect_params = self.call_indirect_params(index, table_index)
  let len_params = func_type.len_params()
  let type_index = @ir.FuncType(type_index.reinterpret_as_int())
  let instr = match (len_params, indirect_params) {
    (0, CallIndirectParams(_)) => @ir.Op::return_call_indirect_0(type_index)
    (0, CallIndirectParamsImm16(_)) =>
      @ir.Op::return_call_indirect_0_imm16(type_index)
    (_, CallIndirectParams(_)) => @ir.Op::return_call_indirect(type_index)
    (_, CallIndirectParamsImm16(_)) =>
      @ir.Op::return_call_indirect_imm16(type_index)
    _ => abort("unreachable")
  }
  self.push_instr(instr, fuel_call) |> ignore
  self.push_param(indirect_params)
  self.stack.pop_n(len_params, self.operands)
  self.instrs.encode_register_list(self.operands[:], self.layout)
  self.reachable = false
}
