// Port of wasmi 1.0.9 `engine/translator/func/mod.rs` (part 1: translator
// state, copies, returns, block ends, `local.set`, branches).

///|
/// Type concerned with translating from Wasm bytecode to Wasmi bytecode.
pub(all) struct FuncTranslator {
  /// The reference to the Wasm module function under construction.
  priv func : FuncIdx
  /// The engine for which the function is compiled.
  ///
  /// # Note
  ///
  /// Technically this is not needed since the information is redundant given via
  /// the `module` field. However, this acts like a faster access since `module`
  /// only holds a weak reference to the engine.
  priv engine : EngineWeak
  /// The immutable Wasm module resources.
  priv module_ : ModuleHeader
  /// This represents the reachability of the currently translated code.
  ///
  /// - `true`: The currently translated code is reachable.
  /// - `false`: The currently translated code is unreachable and can be skipped.
  ///
  /// # Note
  ///
  /// Visiting the Wasm `Else` or `End` control flow operator resets
  /// reachability to `true` again.
  priv mut reachable : Bool
  /// Wasm value and control stack.
  priv stack : TranslatorStack
  /// Types of local variables and function parameters.
  priv locals : LocalsRegistry
  /// Wasm layout to map stack slots to Wasmi registers.
  priv layout : StackLayout
  /// Registers and pins labels and tracks their users.
  priv labels : LabelRegistry
  /// Constructs and encodes function instructions.
  priv instrs : InstrEncoder
  /// Temporary buffer for operands.
  priv operands : Array[Operand]
  /// Temporary buffer for immediate values.
  priv immediates : Array[@wasmi_core.TypedVal]
}

///|
/// Creates a new [`FuncTranslator`].
pub fn FuncTranslator::new(
  func : FuncIdx,
  module_ : ModuleHeader,
) -> FuncTranslator raise WasmiError {
  let engine = module_.engine_upgrade()
  let translator : FuncTranslator = {
    func,
    engine,
    module_,
    reachable: true,
    stack: TranslatorStack::new(engine),
    locals: LocalsRegistry::new(),
    layout: StackLayout::new(),
    labels: LabelRegistry::new(),
    instrs: InstrEncoder::new(engine),
    operands: [],
    immediates: [],
  }
  translator.init_func_body_block()
  translator.init_func_params()
  translator
}

///|
/// Upstream `WasmTranslator::translate_locals`.
pub fn FuncTranslator::translate_locals(
  self : FuncTranslator,
  amount : UInt,
  value_type : @wasmparser.ValType,
) -> Unit raise WasmiError {
  let ty = WasmiValueType::from_wasmparser(value_type)
  self.register_locals(amount.reinterpret_as_int(), ty)
}

///|
/// Upstream `WasmTranslator::finish`: finalizes the translation and returns
/// the compiled function.
pub fn FuncTranslator::finish(
  self : FuncTranslator,
) -> CompiledFuncEntity raise WasmiError {
  // Note: `update_branch_offsets` might change `frame_size` so we need to compute it prior.
  //
  // Context:
  // This only happens if the function has so many instructions that some conditional branch
  // operators need to be encoded as their fallbacks which requires to allocate more function
  // local constant values, thus increasing the size of the function frame.
  self.update_branch_offsets()
  guard self.frame_size() is Some(frame_size) else {
    raise WasmiError::from_translation(TranslationError::AllocatedTooManySlots)
  }
  CompiledFuncEntity::new(frame_size, self.instrs.drain(), self.layout.consts())
}

///|
/// Initializes the function body enclosing control block.
fn FuncTranslator::init_func_body_block(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  let func_ty = self.module_.get_type_of_func(self.func)
  let block_ty = BlockType::func_type(func_ty)
  let end_label = self.labels.new_label()
  let consume_fuel = self.instrs.push_consume_fuel_instr()
  self.stack.push_func_block(block_ty, end_label, consume_fuel)
}

///|
/// Initializes the function's parameters.
fn FuncTranslator::init_func_params(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  for ty in self.func_type().params() {
    self.register_locals(1, ty)
  }
}

///|
/// Registers an `amount` of local variables of common type `ty`.
fn FuncTranslator::register_locals(
  self : FuncTranslator,
  amount : Int,
  ty : @wasmi_core.ValType,
) -> Unit raise WasmiError {
  self.locals.register(amount, ty)
  self.stack.register_locals(amount)
  self.layout.register_locals(amount)
}

///|
/// Returns the frame size of the to-be-compiled function.
///
/// Returns `None` if the frame size is out of bounds.
fn FuncTranslator::frame_size(self : FuncTranslator) -> Int? {
  let frame_size = self.stack.max_height() +
    self.locals.len() +
    self.layout.len_consts()
  if frame_size > 0xFFFF {
    None
  } else {
    Some(frame_size)
  }
}

///|
/// Updates the branch offsets of all branch instructions inplace.
///
/// # Panics
///
/// If this is used before all branching labels have been pinned.
fn FuncTranslator::update_branch_offsets(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  for user_offset in self.labels.resolved_users() {
    let (user, offset) = user_offset
    let offset = match offset {
      Ok(o) => o
      Err(e) => raise e
    }
    self.instrs.update_branch_offset(user, offset, self.layout)
  }
}

///|
/// Returns the [`FuncType`] of the function that is currently translated.
fn FuncTranslator::func_type(self : FuncTranslator) -> @wasmi_core.FuncType {
  self.resolve_func_type(self.func)
}

///|
/// Resolves the [`FuncType`] of the given [`FuncIdx`].
fn FuncTranslator::resolve_func_type(
  self : FuncTranslator,
  func_index : FuncIdx,
) -> @wasmi_core.FuncType {
  let dedup_func_type = self.module_.get_type_of_func(func_index)
  self.engine.resolve_func_type(dedup_func_type)
}

///|
/// Resolves the [`FuncType`] at the given Wasm module `type_index`.
fn FuncTranslator::resolve_type(
  self : FuncTranslator,
  type_index : UInt,
) -> @wasmi_core.FuncType {
  let dedup_func_type = self.module_.get_func_type(
    FuncTypeIdx(type_index.reinterpret_as_int()),
  )
  self.engine.resolve_func_type(dedup_func_type)
}

///|
/// Returns the [`SlotSpan`] of a call instruction before popping its parameters.
fn FuncTranslator::call_regspan(
  self : FuncTranslator,
  len_params : Int,
) -> @ir.SlotSpan raise WasmiError {
  let height = self.stack.height()
  let start = height - len_params
  if start < 0 {
    abort("operand stack underflow while evaluating call `SlotSpan`")
  }
  let start = self.layout.temp_to_reg(OperandIdx(start))
  @ir.SlotSpan::new(start)
}

///|
/// Push `results` as [`TempOperand`] onto the [`Stack`] tagged to `instr`.
///
/// Returns the [`SlotSpan`] identifying the pushed operands if any.
fn FuncTranslator::push_results(
  self : FuncTranslator,
  instr : Instr,
  results : ArrayView[@wasmi_core.ValType],
) -> @ir.SlotSpan? raise WasmiError {
  guard results is [first, .. rest] else { return None }
  let first = self.stack.push_temp(first, Some(instr))
  for result in rest {
    self.stack.push_temp(result, Some(instr)) |> ignore
  }
  let start = self.layout.temp_to_reg(first)
  Some(@ir.SlotSpan::new(start))
}

///|
/// Moves the top-most `len` operands to temporary stack slots.
///
/// # Note
///
/// This pops the top-most `len` operands from the stack and pushes them back
/// as temporary operands, while encoding the necessary copy instructions.
fn FuncTranslator::move_operands_to_temp(
  self : FuncTranslator,
  len : Int,
  consume_fuel : Instr?,
) -> Unit raise WasmiError {
  for n in 0..<len {
    let operand = self.stack.operand_to_temp(n)
    self.copy_operand_to_temp(operand, consume_fuel)
  }
}

///|
/// Copies the `len` branch parameters of the control frame `target`
/// to its results.
fn FuncTranslator::copy_branch_params(
  self : FuncTranslator,
  target : FrameBase,
  consume_fuel_instr : Instr?,
) -> Unit raise WasmiError {
  let len_branch_params = target.len_branch_params(self.engine)
  guard self.frame_results(target) is Some(branch_results) else { return }
  self.encode_copies(branch_results, len_branch_params, consume_fuel_instr)
}

///|
/// Pushes the results of the control `frame` onto the [`Stack`].
///
/// # Note
///
/// - Before pushing the results, the [`Stack`] is truncated to the `frame`'s height.
/// - Not all control frames have temporary results, e.g. Wasm `loop`s, Wasm `if`s
///   with a compile-time known branch or Wasm `block`s that are never branched to,
///   do not require to call this function.
fn FuncTranslator::push_frame_results(
  self : FuncTranslator,
  frame : FrameBase,
) -> Unit raise WasmiError {
  let height = frame.height()
  self.stack.trunc(height)
  let func_ty = frame.ty().func_type_of(self.engine)
  for result in func_ty.results() {
    self.stack.push_temp(result, None) |> ignore
  }
}

///|
/// Encodes the copies of the top-most `len_values` operands to `results`.
fn FuncTranslator::encode_copies(
  self : FuncTranslator,
  results : @ir.SlotSpan,
  len_values : Int,
  consume_fuel_instr : Instr?,
) -> Unit raise WasmiError {
  match len_values {
    0 => ()
    1 => {
      let result = results.head()
      let value = self.stack.peek(0)
      self.encode_copy(result, value, consume_fuel_instr) |> ignore
    }
    2 => {
      let (val0, val1) = self.stack.peek2()
      self.encode_copy2(results, val0, val1, consume_fuel_instr)
    }
    _ => self.encode_copy_many(results, len_values, consume_fuel_instr)
  }
}

///|
/// Encodes a single copy instruction from `value` to `result`.
///
/// Returns the encoded [`Instr`] if any; `None` for no-op copies.
fn FuncTranslator::encode_copy(
  self : FuncTranslator,
  result : @ir.Slot,
  value : Operand,
  consume_fuel_instr : Instr?,
) -> Instr? raise WasmiError {
  guard FuncTranslator::make_copy_instr(result, value, self.layout)
    is Some(copy_instr) else {
    // Case: no-op copy instruction
    return None
  }
  if self.try_merge_copies(copy_instr) is Some(fused_copy) {
    // Case: successfully merged the copy instruction with its succeeding one.
    return Some(fused_copy)
  }
  let instr = self.instrs.push_instr(copy_instr, consume_fuel_instr, fuel_base)
  Some(instr)
}

///|
/// Tries to merge `copy_instr` with the last encoded copy instruction.
fn FuncTranslator::try_merge_copies(
  self : FuncTranslator,
  copy_instr : @ir.Op,
) -> Instr? raise WasmiError {
  guard copy_instr is Copy(result~, value~) else {
    // Case: `copy_instr` is not fusable.
    return None
  }
  guard self.instrs.last_instr() is Some(last_instr) else {
    // Case: no `last_instr` to fuse with.
    return None
  }
  let last_copy = self.instrs.get(last_instr)
  let fused_copy = match last_copy {
    Copy(_) => FuncTranslator::try_merge_copy_instr(last_copy, result, value)
    Copy2(_) => FuncTranslator::try_merge_copy2_instr(last_copy, result, value)
    CopySpan(_) =>
      FuncTranslator::try_merge_copy_span_instr(last_copy, result, value)
    _ => return None
  }
  if fused_copy is Some(fused_copy) {
    let success = self.instrs.try_replace_instr(last_instr, fused_copy)
    // Upstream: `debug_assert!(success)`; `last_instr` is the encoder's
    // last instruction, which `try_replace_instr` always replaces.
    guard! success
    return Some(last_instr)
  }
  None
}

///|
/// Tries to merge `last_copy` with `copy result <- value`.
fn FuncTranslator::try_merge_copy_instr(
  last_copy : @ir.Op,
  result : @ir.Slot,
  value : @ir.Slot,
) -> @ir.Op? {
  guard last_copy is Copy(result=last_result, value=last_value) else {
    // Case: `last_copy` does not refer to a mergable copy instruction.
    return None
  }
  // Try to fuse to a `copy2` instruction.
  if value == last_result {
    // Case: cannot merge since the succeeding copy overwrites the result of `copy_instr`
    return None
  }
  if result == last_result.next() {
    // Case: we can append `copy_instrs`.
    return Some(
      @ir.Op::copy2_ext(@ir.SlotSpan::new(last_result), last_value, value),
    )
  }
  if result == last_result.prev() {
    // Case: we can prepend `copy_instr`.
    return Some(@ir.Op::copy2_ext(@ir.SlotSpan::new(result), value, last_value))
  }
  None
}

///|
/// Tries to merge a `copy2` instruction with `copy result <- value`.
fn FuncTranslator::try_merge_copy2_instr(
  last_copy : @ir.Op,
  result : @ir.Slot,
  value : @ir.Slot,
) -> @ir.Op? {
  guard last_copy is Copy2(results~, values~) else {
    // Case: `last_copy` does not refer to a mergable copy instruction.
    return None
  }
  // Try to fuse to a `copy_span` instruction.
  let (last_result0, last_result1) = results.to_array()
  let last_value0 = values[0]
  let last_value1 = values[1]
  if last_value0.next() != last_value1 {
    // Case: last `copy2` instruction itself is not convertible to a `copy_span`.
    return None
  }
  if result == last_result1.next() && value == last_value1.next() {
    // Case: we can append `copy_instr`.
    if value == last_result0 || value == last_result1 {
      // Case: cannot merge since `value` is overwritten by `last_copy`.
      return None
    }
    let results = @ir.SlotSpan::new(last_result0)
    let values = @ir.SlotSpan::new(last_value0)
    let len = 3
    return Some(@ir.Op::copy_span(results, values, len))
  }
  // Note: must not prepend copy when fusing since this may break the copy order
  //       which breaks semantic equivalence. So only appending copies is allowed.
  None
}

///|
/// Tries to merge a `copy_span` instruction with `copy result <- value`.
fn FuncTranslator::try_merge_copy_span_instr(
  last_copy : @ir.Op,
  result : @ir.Slot,
  value : @ir.Slot,
) -> @ir.Op? {
  guard last_copy is CopySpan(results~, values~, len~) else {
    // Case: `last_copy` does not refer to a mergable copy instruction.
    return None
  }
  let last_result0 = results.head()
  let last_value0 = values.head()
  // Try to fuse to a larger `copy_span` instruction.
  if result == last_result0.next_n(len) && value == last_value0.next_n(len) {
    // Case: we can append `copy_instr`.
    let new_len = len + 1
    if @ir.SlotSpan::has_overlapping_copies(results, values, new_len) {
      // Case: cannot merge since resulting `copy_span` has overlapping copies.
      return None
    }
    return Some(@ir.Op::copy_span(results, values, new_len))
  }
  // Note: must not prepend copy when fusing since this may break the copy order
  //       which breaks semantic equivalence. So only appending copies is allowed.
  None
}

///|
/// Returns the copy instruction to copy the given `operand` to `result`.
///
/// Returns `None` if the resulting copy instruction is a no-op.
fn FuncTranslator::make_copy_instr(
  result : @ir.Slot,
  value : Operand,
  layout : StackLayout,
) -> @ir.Op? raise WasmiError {
  let instr = match value {
    Temp(value) => {
      let value = layout.temp_to_reg(value.operand_index())
      if result == value {
        // Case: no-op copy
        return None
      }
      @ir.Op::copy(result, value)
    }
    Local(value) => {
      let value = layout.local_to_reg(value.local_index())
      if result == value {
        // Case: no-op copy
        return None
      }
      @ir.Op::copy(result, value)
    }
    Immediate(value) =>
      FuncTranslator::make_copy_imm_instr(result, value.val(), layout)
  }
  Some(instr)
}

///|
/// Returns the copy instruction to copy the given immediate `value`.
fn FuncTranslator::make_copy_imm_instr(
  result : @ir.Slot,
  value : @wasmi_core.TypedVal,
  layout : StackLayout,
) -> @ir.Op raise WasmiError {
  match value.ty() {
    I32 => @ir.Op::copy_imm32(result, @ir.AnyConst32::from_i32(value.to_i32()))
    I64 => {
      let v = value.to_i64()
      match @ir.Const32::try_from_i64(v) {
        Some(c) => @ir.Op::copy_i64imm32(result, c)
        None => {
          let value = layout.const_to_reg(value.untyped())
          @ir.Op::copy(result, value)
        }
      }
    }
    F32 =>
      @ir.Op::copy_imm32(
        result,
        @ir.AnyConst32::from_f32_bits(typed_f32_bits(value)),
      )
    F64 =>
      match @ir.Const32::try_from_f64_bits(typed_f64_bits(value)) {
        Some(c) => @ir.Op::copy_f64imm32(result, c)
        None => {
          let value = layout.const_to_reg(value.untyped())
          @ir.Op::copy(result, value)
        }
      }
    V128 | FuncRef | ExternRef => {
      let value = layout.const_to_reg(value.untyped())
      @ir.Op::copy(result, value)
    }
  }
}

///|
/// Encodes a copy instruction for the top-most `len_values` on the stack to `results`.
///
/// # Note
///
/// - This does _not_ pop values from the stack or manipulate the stack otherwise.
/// - This might allocate new function local constant values if necessary.
/// - This does _not_ encode a copy if the copy is a no-op.
fn FuncTranslator::encode_copy2(
  self : FuncTranslator,
  results : @ir.SlotSpan,
  val0 : Operand,
  val1 : Operand,
  consume_fuel_instr : Instr?,
) -> Unit raise WasmiError {
  let val0 = self.layout.operand_to_reg(val0)
  let val1 = self.layout.operand_to_reg(val1)
  let result0 = results.head()
  let result1 = result0.next()
  if result0 == val0 && result1 == val1 {
    // Case: no-op copy instruction
    return
  }
  self.instrs.push_instr(
    @ir.Op::copy2_ext(results, val0, val1),
    consume_fuel_instr,
    fuel_base,
  )
  |> ignore
}

///|
/// Encodes a `copy_span` instruction.
fn FuncTranslator::encode_copy_span(
  self : FuncTranslator,
  results : @ir.SlotSpan,
  values : @ir.SlotSpan,
  len : Int,
  consume_fuel_instr : Instr?,
) -> Unit raise WasmiError {
  if results == values {
    // Case: results and values are equal and therefore the copy is a no-op
    return
  }
  self.instrs.push_instr(
    @ir.Op::copy_span(results, values, len),
    consume_fuel_instr,
    fn(costs) { costs.fuel_for_copying_values(len.to_uint64()) },
  )
  |> ignore
}

///|
/// Encodes a copy of the top-most `len` operands to `results`.
fn FuncTranslator::encode_copy_many(
  self : FuncTranslator,
  results : @ir.SlotSpan,
  len : Int,
  consume_fuel_instr : Instr?,
) -> Unit raise WasmiError {
  self.peek_operands_into_buffer(len)
  let values = self.operands[:]
  let (results, values) = FuncTranslator::copy_many_strip_noop_start(
    results,
    values,
    self.layout,
  )
  let values = FuncTranslator::copy_many_strip_noop_end(
    results,
    values,
    self.layout,
  )
  match values {
    [] => ()
    [val0] => {
      let result = results.head()
      self.encode_copy(result, val0, consume_fuel_instr) |> ignore
    }
    [val0, val1] => self.encode_copy2(results, val0, val1, consume_fuel_instr)
    [val0, val1, .. rest] => {
      if FuncTranslator::try_form_regspan_of(values, self.layout)
        is Some(values) {
        return self.encode_copy_span(results, values, len, consume_fuel_instr)
      }
      let val0 = self.layout.operand_to_reg(val0)
      let val1 = self.layout.operand_to_reg(val1)
      self.instrs.push_instr(
        @ir.Op::copy_many_ext(results, val0, val1),
        consume_fuel_instr,
        fn(costs) { costs.fuel_for_copying_values(len.to_uint64()) },
      )
      |> ignore
      self.instrs.encode_register_list(rest, self.layout)
    }
  }
}

///|
/// Returns the [`Slot`] of an operand that is not an immediate, or `None`.
fn operand_slot_no_imm(
  value : Operand,
  layout : StackLayout,
) -> @ir.Slot? raise WasmiError {
  match value {
    Local(value) => Some(layout.local_to_reg(value.local_index()))
    Temp(value) => Some(layout.temp_to_reg(value.operand_index()))
    Immediate(_) => None
  }
}

///|
/// Strips no-op copies from the start of the `values`.
fn FuncTranslator::copy_many_strip_noop_start(
  results : @ir.SlotSpan,
  values : ArrayView[Operand],
  layout : StackLayout,
) -> (@ir.SlotSpan, ArrayView[Operand]) raise WasmiError {
  let mut result = results.head()
  let mut values = values
  while values is [value, .. rest] {
    guard operand_slot_no_imm(value, layout) is Some(value) else {
      // Immediate values will never yield no-op copies.
      break
    }
    if result != value {
      // Can no longer strip no-op copies from the start.
      break
    }
    result = result.next()
    values = rest
  }
  (@ir.SlotSpan::new(result), values)
}

///|
/// Strips no-op copies from the end of the `values`.
fn FuncTranslator::copy_many_strip_noop_end(
  results : @ir.SlotSpan,
  values : ArrayView[Operand],
  layout : StackLayout,
) -> ArrayView[Operand] raise WasmiError {
  let len = values.length()
  let mut result = results.head().next_n(len)
  let mut values = values
  while values is [.. rest, value] {
    guard operand_slot_no_imm(value, layout) is Some(value) else {
      // Immediate values will never yield no-op copies.
      break
    }
    result = result.prev()
    if result != value {
      // Can no longer strip no-op copies from the end.
      break
    }
    values = rest
  }
  values
}

///|
/// Returns the results [`SlotSpan`] of the `frame` if any.
fn FuncTranslator::frame_results(
  self : FuncTranslator,
  frame : FrameBase,
) -> @ir.SlotSpan? raise WasmiError {
  FuncTranslator::frame_results_impl(frame, self.engine, self.layout)
}

///|
/// Returns the results [`SlotSpan`] of the `frame` if any.
fn FuncTranslator::frame_results_impl(
  frame : FrameBase,
  engine : EngineWeak,
  layout : StackLayout,
) -> @ir.SlotSpan? raise WasmiError {
  if frame.len_branch_params(engine) == 0 {
    return None
  }
  let height = frame.height()
  let start = layout.temp_to_reg(OperandIdx(height))
  let span = @ir.SlotSpan::new(start)
  Some(span)
}

///|
/// Returns `true` if the [`ControlFrame`] at `depth` requires copying for its branch parameters.
///
/// # Note
///
/// Some instructions can be encoded in a more efficient way if no branch parameter copies are required.
fn FuncTranslator::requires_branch_param_copies(
  self : FuncTranslator,
  depth : Int,
) -> Bool {
  let frame = self.stack.peek_control(depth).base()
  let len_branch_params = frame.len_branch_params(self.engine)
  let frame_height = frame.height()
  let height_matches = frame_height == self.stack.height() - len_branch_params
  let mut only_temps = true
  for depth in 0..<len_branch_params {
    if !self.stack.peek(depth).is_temp() {
      only_temps = false
      break
    }
  }
  let can_avoid_copies = height_matches && only_temps
  !can_avoid_copies
}

///|
/// Pins the `label` to the next [`Instr`].
fn FuncTranslator::pin_label(self : FuncTranslator, label : LabelRef) -> Unit {
  self.labels.pin_label(label, self.instrs.next_instr()) catch {
    err => abort("failed to pin label to next instruction: \{err}")
  }
}

///|
/// Convert the [`Operand`] at `depth` into an [`Operand::Temp`] by copying if necessary.
///
/// # Note
///
/// Does nothing if the [`Operand`] is already an [`Operand::Temp`].
fn FuncTranslator::copy_operand_to_temp(
  self : FuncTranslator,
  operand : Operand,
  consume_fuel : Instr?,
) -> Unit raise WasmiError {
  let result = self.layout.temp_to_reg(operand.index())
  self.encode_copy(result, operand, consume_fuel) |> ignore
}

///|
/// Returns the [`Slot`] of the `operand`, copying immediates into a temporary
/// slot if they cannot be encoded as function local constants.
fn FuncTranslator::immediate_to_reg(
  self : FuncTranslator,
  operand : Operand,
) -> @ir.Slot raise WasmiError {
  match operand {
    Local(operand) => self.layout.local_to_reg(operand.local_index())
    Temp(operand) => self.layout.temp_to_reg(operand.operand_index())
    Immediate(operand) => {
      let value = operand.val()
      let result = self.layout.temp_to_reg(operand.operand_index())
      match FuncTranslator::make_copy_imm_instr(result, value, self.layout) {
        Copy(value~, ..) =>
          // Case: not possible to craft a `copy` instruction
          //       with an inline immediate, so we can return
          //       the allocated function local constant [`Slot`]
          //       instead.
          value
        copy_instr => {
          let consume_fuel = self.stack.consume_fuel_instr()
          self.instrs.push_instr(copy_instr, consume_fuel, fuel_base) |> ignore
          result
        }
      }
    }
  }
}

///|
/// Pushes the `instr` to the function with the associated `fuel_costs`.
fn FuncTranslator::preserve_all_locals(
  self : FuncTranslator,
) -> Unit raise WasmiError {
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  for local_ in self.stack.preserve_all_locals() {
    let result = self.layout.temp_to_reg(local_.index())
    guard FuncTranslator::make_copy_instr(result, local_, self.layout)
      is Some(copy_instr) else {
      abort("`result` and `local` refer to different stack spaces")
    }
    self.instrs.push_instr(copy_instr, consume_fuel_instr, fuel_base) |> ignore
  }
}

///|
/// Pushes the `instr` to the function with the associated `fuel_costs`.
fn FuncTranslator::push_instr(
  self : FuncTranslator,
  instr : @ir.Op,
  fuel_costs : FuelCostsFn,
) -> Instr raise WasmiError {
  let consume_fuel = self.stack.consume_fuel_instr()
  self.instrs.push_instr(instr, consume_fuel, fuel_costs)
}

///|
/// Pushes a new temporary result of type `result_ty` and an instruction
/// creating it (via `make_instr`).
fn FuncTranslator::push_instr_with_result(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  make_instr : (@ir.Slot) -> @ir.Op raise WasmiError,
  fuel_costs : FuelCostsFn,
) -> Unit raise WasmiError {
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  let expected_iidx = self.instrs.next_instr()
  let result = self.layout.temp_to_reg(
    self.stack.push_temp(result_ty, Some(expected_iidx)),
  )
  let actual_iidx = self.instrs.push_instr(
    make_instr(result),
    consume_fuel_instr,
    fuel_costs,
  )
  // Upstream: `assert_eq!(expected_iidx, actual_iidx)`.
  guard! expected_iidx == actual_iidx
}

///|
/// Encodes a generic binary instruction with result.
fn FuncTranslator::push_binary_instr_with_result(
  self : FuncTranslator,
  result_ty : @wasmi_core.ValType,
  lhs : Operand,
  rhs : Operand,
  make_instr : (@ir.Slot, @ir.Slot, @ir.Slot) -> @ir.Op,
  fuel_costs : FuelCostsFn,
) -> Unit raise WasmiError {
  let lhs = self.layout.operand_to_reg(lhs)
  let rhs = self.layout.operand_to_reg(rhs)
  self.push_instr_with_result(
    result_ty,
    fn(result) { make_instr(result, lhs, rhs) },
    fuel_costs,
  )
}

///|
/// Pushes an instruction parameter `param` to the list of instructions.
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/mod.rs:1057).
#warnings("-unused_error_type")
fn FuncTranslator::push_param(
  self : FuncTranslator,
  param : @ir.Op,
) -> Unit raise WasmiError {
  self.instrs.push_param(param)
}

///|
/// Copies the `br_table` targets (and the default target, last) into `buffer`.
// Cannot fail: the targets upstream re-reads (`target?`) are already parsed
// (wasmi 1.0.9 translator/func/mod.rs:1069).
#warnings("-unused_error_type")
fn FuncTranslator::copy_targets_from_br_table(
  table : @wasmparser.BrTable,
  buffer : Array[@wasmi_core.TypedVal],
) -> Unit raise WasmiError {
  let default_target = table.default()
  buffer.clear()
  for target in table.targets() {
    buffer.push(@wasmi_core.TypedVal::from_u32(target))
  }
  buffer.push(@wasmi_core.TypedVal::from_u32(default_target))
}

///|
/// Encodes a Wasm `br_table` that does not copy branching values.
fn FuncTranslator::encode_br_table_0(
  self : FuncTranslator,
  table : @wasmparser.BrTable,
  index : @ir.Slot,
) -> Unit raise WasmiError {
  self.push_instr(
    @ir.Op::branch_table_0(index, table.len().reinterpret_as_int() + 1),
    fuel_base,
  )
  |> ignore
  // Encode the `br_table` targets:
  let targets = self.immediates
  for target in targets {
    let depth = target.to_u32().reinterpret_as_int()
    let frame = self.stack.peek_control_mut(depth).control_frame()
    let offset = self.labels.try_resolve_label(
      frame.label(),
      self.instrs.next_instr(),
    )
    self.instrs.push_param(@ir.Op::branch(offset))
    frame.branch_to()
  }
}

///|
/// Encodes a Wasm `br_table` that has to copy `len_values` branching values.
fn FuncTranslator::encode_br_table_n(
  self : FuncTranslator,
  table : @wasmparser.BrTable,
  index : @ir.Slot,
  len_values : Int,
) -> Unit raise WasmiError {
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  let values = self.try_form_regspan_or_move(len_values, consume_fuel_instr)
  self.push_instr(
    @ir.Op::branch_table_span(index, table.len().reinterpret_as_int() + 1),
    fuel_base,
  )
  |> ignore
  self.push_param(
    @ir.Op::slot_span(@ir.BoundedSlotSpan::new(values, len_values)),
  )
  // Encode the `br_table` targets:
  let targets = self.immediates
  for target in targets {
    let depth = target.to_u32().reinterpret_as_int()
    let frame = self.stack.peek_control_mut(depth).control_frame()
    guard FuncTranslator::frame_results_impl(frame, self.engine, self.layout)
      is Some(results) else {
      abort("must have frame results since `br_table` requires to copy values")
    }
    let offset = self.labels.try_resolve_label(
      frame.label(),
      self.instrs.next_instr(),
    )
    self.instrs.push_param(@ir.Op::branch_table_target(results, offset))
    frame.branch_to()
  }
}

///|
/// Encodes a generic return instruction.
fn FuncTranslator::encode_return(
  self : FuncTranslator,
  consume_fuel : Instr?,
) -> Instr raise WasmiError {
  let len_results = self.func_type().len_results()
  let instr = match len_results {
    0 => @ir.Op::return_()
    1 =>
      match self.stack.peek(0) {
        Local(operand) => {
          let value = self.layout.local_to_reg(operand.local_index())
          @ir.Op::return_reg(value)
        }
        Temp(operand) => {
          let value = self.layout.temp_to_reg(operand.operand_index())
          @ir.Op::return_reg(value)
        }
        Immediate(operand) => {
          let val = operand.val()
          match operand.ty() {
            I32 => @ir.Op::return_imm32(@ir.AnyConst32::from_i32(val.to_i32()))
            I64 =>
              match @ir.Const32::try_from_i64(val.to_i64()) {
                Some(value) => @ir.Op::return_i64imm32(value)
                None => {
                  let value = self.layout.const_to_reg(val.untyped())
                  @ir.Op::return_reg(value)
                }
              }
            F32 =>
              @ir.Op::return_imm32(
                @ir.AnyConst32::from_f32_bits(typed_f32_bits(val)),
              )
            F64 =>
              match @ir.Const32::try_from_f64_bits(typed_f64_bits(val)) {
                Some(value) => @ir.Op::return_f64imm32(value)
                None => {
                  let value = self.layout.const_to_reg(val.untyped())
                  @ir.Op::return_reg(value)
                }
              }
            V128 | FuncRef | ExternRef => {
              let value = self.layout.const_to_reg(val.untyped())
              @ir.Op::return_reg(value)
            }
          }
        }
      }
    2 => {
      let (v0, v1) = self.stack.peek2()
      let v0 = self.layout.operand_to_reg(v0)
      let v1 = self.layout.operand_to_reg(v1)
      @ir.Op::return_reg2_ext(v0, v1)
    }
    3 => {
      let (v0, v1, v2) = self.stack.peek3()
      let v0 = self.layout.operand_to_reg(v0)
      let v1 = self.layout.operand_to_reg(v1)
      let v2 = self.layout.operand_to_reg(v2)
      @ir.Op::return_reg3_ext(v0, v1, v2)
    }
    _ => return self.encode_return_many(len_results, consume_fuel)
  }
  self.instrs.push_instr(instr, consume_fuel, fuel_base)
}

///|
/// Peeks `len` operands from the stack and store them into `self.operands`.
fn FuncTranslator::peek_operands_into_buffer(
  self : FuncTranslator,
  len : Int,
) -> Unit {
  self.operands.clear()
  for operand in self.stack.peek_n(len) {
    self.operands.push(operand)
  }
}

///|
/// Encodes an [`Op::ReturnSpan`] or [`Op::ReturnMany`] instruction.
///
/// # Note
///
/// Both [`Op::ReturnSpan`] and [`Op::ReturnMany`] return 4 or more values.
fn FuncTranslator::encode_return_many(
  self : FuncTranslator,
  len : Int,
  consume_fuel_instr : Instr?,
) -> Instr raise WasmiError {
  self.peek_operands_into_buffer(len)
  if FuncTranslator::try_form_regspan_of(self.operands[:], self.layout)
    is Some(values) {
    let values = @ir.BoundedSlotSpan::new(values, len)
    return self.instrs.push_instr(
      @ir.Op::return_span(values),
      consume_fuel_instr,
      fuel_base,
    )
  }
  guard self.operands[:] is [v0, v1, v2, .. rest] else {
    abort("encode_return_many (pre-condition): len >= 4")
  }
  let v0 = self.layout.operand_to_reg(v0)
  let v1 = self.layout.operand_to_reg(v1)
  let v2 = self.layout.operand_to_reg(v2)
  let return_instr = self.instrs.push_instr(
    @ir.Op::return_many_ext(v0, v1, v2),
    consume_fuel_instr,
    fuel_base,
  )
  self.instrs.encode_register_list(rest, self.layout)
  return_instr
}

///|
/// Tries to form a [`SlotSpan`] from the top-most `len` operands on the [`Stack`].
///
/// Returns `None` if forming a [`SlotSpan`] was not possible.
fn FuncTranslator::try_form_regspan(
  self : FuncTranslator,
  len : Int,
) -> @ir.SlotSpan? raise WasmiError {
  FuncTranslator::try_form_regspan_of(self.stack.peek_n(len)[:], self.layout)
}

///|
/// Returns a [`SlotSpan`] if `values` form one.
fn FuncTranslator::try_form_regspan_of(
  values : ArrayView[Operand],
  layout : StackLayout,
) -> @ir.SlotSpan? raise WasmiError {
  guard values is [head, .. rest] else { return None }
  let mut head = match head {
    Local(start) => layout.local_to_reg(start.local_index())
    Temp(start) => layout.temp_to_reg(start.operand_index())
    Immediate(_) => return None
  }
  let start = head
  for value in rest {
    let cur = match value {
      Immediate(_) => return None
      Local(value) => layout.local_to_reg(value.local_index())
      Temp(value) => layout.temp_to_reg(value.operand_index())
    }
    if head != cur.prev() {
      return None
    }
    head = cur
  }
  Some(@ir.SlotSpan::new(start))
}

///|
/// Tries to form a [`SlotSpan`] from the top-most `len` operands on the [`Stack`]
/// or copy to temporaries.
///
/// Returns `None` if forming a [`SlotSpan`] was not possible.
fn FuncTranslator::try_form_regspan_or_move(
  self : FuncTranslator,
  len : Int,
  consume_fuel_instr : Instr?,
) -> @ir.SlotSpan raise WasmiError {
  if self.try_form_regspan(len) is Some(span) {
    return span
  }
  self.move_operands_to_temp(len, consume_fuel_instr)
  guard self.try_form_regspan(len) is Some(span) else {
    abort(
      "the top-most `len` operands are now temporaries thus `SlotSpan` forming should succeed",
    )
  }
  span
}

///|
/// Translates the end of a Wasm `block` control frame.
fn FuncTranslator::translate_end_block(
  self : FuncTranslator,
  frame : FrameBase,
) -> Unit raise WasmiError {
  let consume_fuel_instr = frame.consume_fuel_instr()
  if frame.is_branched_to() {
    if self.reachable {
      self.copy_branch_params(frame, consume_fuel_instr)
    }
    self.push_frame_results(frame)
  }
  self.labels.pin_label(frame.label(), self.instrs.next_instr()) catch {
    err => abort("failed to pin label: \{err}")
  }
  self.reachable = self.reachable || frame.is_branched_to()
  if self.reachable && self.stack.is_control_empty() {
    self.encode_return(consume_fuel_instr) |> ignore
  }
  if frame.is_branched_to() {
    // No need to reset `last_instr` if there was no branch to the end of a Wasm `block`.
    self.instrs.reset_last_instr()
  }
}

///|
/// Translates the end of a Wasm `loop` control frame.
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/mod.rs:1336).
#warnings("-unused_error_type")
fn FuncTranslator::translate_end_loop(
  _self : FuncTranslator,
  _frame : FrameBase,
) -> Unit raise WasmiError {
  // Nothing needs to be done since Wasm `loop` control frames always only have a single exit.
  //
  // Note: no need to reset `last_instr` since end of `loop` is not a control flow boundary.
}

///|
/// Translates the end of a Wasm `if` control frame.
fn FuncTranslator::translate_end_if(
  self : FuncTranslator,
  frame : IfControlFrame,
) -> Unit raise WasmiError {
  let is_end_of_then_reachable = self.reachable
  guard frame.reachability() is Both(else_label~) else {
    let is_end_reachable = match frame.reachability() {
      OnlyThen => self.reachable
      OnlyElse => true
      Both(_) => abort("unreachable")
    }
    return self.translate_end_if_or_else_only(frame.base, is_end_reachable)
  }
  let len_results = frame.base.ty().len_results(self.engine)
  let has_results = len_results >= 1
  if is_end_of_then_reachable && has_results {
    let consume_fuel_instr = frame.base.consume_fuel_instr()
    self.copy_branch_params(frame.base, consume_fuel_instr)
    let end_offset = self.labels.try_resolve_label(
      frame.base.label(),
      self.instrs.next_instr(),
    )
    self.instrs.push_instr(
      @ir.Op::branch(end_offset),
      consume_fuel_instr,
      fuel_base,
    )
    |> ignore
  }
  self.labels.try_pin_label(else_label, self.instrs.next_instr())
  self.stack.push_else_operands(frame)
  if has_results {
    // We haven't visited the `else` block and thus the `else`
    // providers are still on the auxiliary stack and need to
    // be popped. We use them to restore the stack to the state
    // when entering the `if` block so that we can properly copy
    // the `else` results to were they are expected.
    let consume_fuel_instr = self.instrs.push_consume_fuel_instr()
    self.copy_branch_params(frame.base, consume_fuel_instr)
  }
  self.push_frame_results(frame.base)
  self.labels.pin_label(frame.base.label(), self.instrs.next_instr()) catch {
    err => abort("\{err}")
  }
  self.reachable = true
  // Need to reset `last_instr` since end of `if` is a control flow boundary.
  self.instrs.reset_last_instr()
}

///|
/// Translates the end of a Wasm `else` control frame.
fn FuncTranslator::translate_end_else(
  self : FuncTranslator,
  frame : ElseControlFrame,
) -> Unit raise WasmiError {
  match frame.reachability() {
    OnlyThen(is_end_of_then_reachable~) =>
      return self.translate_end_if_or_else_only(
        frame.base,
        is_end_of_then_reachable,
      )
    OnlyElse =>
      return self.translate_end_if_or_else_only(frame.base, self.reachable)
    _ => ()
  }
  let end_of_then_reachable = frame.is_end_of_then_reachable()
  let end_of_else_reachable = self.reachable
  let reachable = match (end_of_then_reachable, end_of_else_reachable) {
    (false, false) => frame.base.is_branched_to()
    _ => true
  }
  if end_of_else_reachable {
    let consume_fuel_instr = frame.base.consume_fuel_instr()
    self.copy_branch_params(frame.base, consume_fuel_instr)
  }
  self.push_frame_results(frame.base)
  self.labels.pin_label(frame.base.label(), self.instrs.next_instr()) catch {
    err => abort("\{err}")
  }
  self.reachable = reachable
  // Need to reset `last_instr` since end of `else` is a control flow boundary.
  self.instrs.reset_last_instr()
}

///|
/// Translates the end of a Wasm `else` control frame where only one branch is known to be reachable.
fn FuncTranslator::translate_end_if_or_else_only(
  self : FuncTranslator,
  frame : FrameBase,
  end_is_reachable : Bool,
) -> Unit raise WasmiError {
  if frame.is_branched_to() {
    if end_is_reachable {
      let consume_fuel_instr = frame.consume_fuel_instr()
      self.copy_branch_params(frame, consume_fuel_instr)
    }
    self.push_frame_results(frame)
  }
  self.labels.pin_label(frame.label(), self.instrs.next_instr()) catch {
    err => abort("\{err}")
  }
  self.reachable = end_is_reachable || frame.is_branched_to()
  if frame.is_branched_to() {
    // No need to reset `last_instr` if there was no branch to the
    // end of a Wasm `if` where only `then` or `else` is reachable.
    self.instrs.reset_last_instr()
  }
}

///|
/// Translates the end of an unreachable Wasm control frame.
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/mod.rs:1453).
#warnings("-unused_error_type")
fn FuncTranslator::translate_end_unreachable(
  self : FuncTranslator,
  _frame : ControlFrameKind,
) -> Unit raise WasmiError {
  // We reset `last_instr` out of caution in case there is a control flow boundary.
  self.instrs.reset_last_instr()
}

///|
/// Translates a Wasm `local.set` or `local.tee`.
fn FuncTranslator::translate_local_set(
  self : FuncTranslator,
  local_index : UInt,
  push_result : Bool,
) -> Unit raise WasmiError {
  if !self.reachable {
    return
  }
  let input = self.stack.pop()
  let input_ty = input.ty()
  if input is Local(input) {
    if input.local_index().0 == local_index {
      // Case: `(local.set $n (local.get $n))` is a no-op so we can ignore it.
      //
      // Note: This does not require any preservation since it won't change
      //       the value of `local $n`.
      if push_result {
        // Need to push back input before we exit.
        self.stack.push_operand(Local(input)) |> ignore
      }
      return
    }
  }
  let local_idx = LocalIdx(local_index)
  let consume_fuel_instr = self.stack.consume_fuel_instr()
  for preserved in self.stack.preserve_locals(local_idx) {
    let result = self.layout.temp_to_reg(preserved)
    let value = self.layout.local_to_reg(local_idx)
    self.instrs.push_instr(
      @ir.Op::copy(result, value),
      consume_fuel_instr,
      fuel_base,
    )
    |> ignore
  }
  if push_result {
    match input {
      Immediate(input) => self.stack.push_immediate(input.val()) |> ignore
      _ => self.stack.push_local(local_idx, input_ty) |> ignore
    }
  }
  if self.try_replace_result(local_idx, input) {
    // Case: it was possible to replace the result of the previous
    //       instructions so no copy instruction is required.
    return
  }
  // At this point we need to encode a copy instruction.
  let result = self.layout.local_to_reg(local_idx)
  self.encode_copy(result, input, consume_fuel_instr) |> ignore
}

///|
/// Tries to replace the result of the previous instruction with `new_result` if possible.
///
/// Returns `Ok(true)` if replacement was successful and `Ok(false)` otherwise.
fn FuncTranslator::try_replace_result(
  self : FuncTranslator,
  new_result : LocalIdx,
  old_result : Operand,
) -> Bool raise WasmiError {
  let result = self.layout.local_to_reg(new_result)
  let old_result = match old_result {
    Immediate(_) =>
      // Case: cannot replace immediate value result.
      return false
    Local(_) =>
      // Case: cannot replace local with another local due to observable behavior.
      return false
    Temp(operand) => self.layout.temp_to_reg(operand.operand_index())
  }
  self.instrs.try_replace_result(result, old_result, self.layout, self.module_)
}

///|
/// Encodes an unconditional Wasm `branch` instruction.
fn FuncTranslator::encode_br(
  self : FuncTranslator,
  label : LabelRef,
) -> Instr raise WasmiError {
  let instr = self.instrs.next_instr()
  let offset = self.labels.try_resolve_label(label, instr)
  self.push_instr(@ir.Op::branch(offset), fuel_base)
}

///|
/// Encodes a `i32.eqz`+`br_if` or `if` conditional branch instruction.
fn FuncTranslator::encode_br_eqz(
  self : FuncTranslator,
  condition : Operand,
  label : LabelRef,
) -> Unit raise WasmiError {
  self.encode_br_if(condition, label, true)
}

///|
/// Encodes a `br_if` conditional branch instruction.
fn FuncTranslator::encode_br_nez(
  self : FuncTranslator,
  condition : Operand,
  label : LabelRef,
) -> Unit raise WasmiError {
  self.encode_br_if(condition, label, false)
}

///|
/// Encodes a generic return instruction.
fn FuncTranslator::encode_br_if(
  self : FuncTranslator,
  condition : Operand,
  label : LabelRef,
  branch_eqz : Bool,
) -> Unit raise WasmiError {
  if self.try_fuse_branch_cmp(condition, label, branch_eqz) {
    return
  }
  let condition = match condition {
    Local(condition) => self.layout.local_to_reg(condition.local_index())
    Temp(condition) => self.layout.temp_to_reg(condition.operand_index())
    Immediate(condition) => {
      let condition = condition.val().to_i32()
      let take_branch = if branch_eqz { condition == 0 } else { condition != 0 }
      if take_branch {
        self.encode_br(label) |> ignore
        self.reachable = false
        return
      } else {
        return
      }
    }
  }
  let instr = self.instrs.next_instr()
  let offset = self.labels.try_resolve_label(label, instr)
  let instr = match
    (try @ir.BranchOffset16::try_from(offset) catch {
      e => Err(e)
    } noraise {
      v => Ok(v)
    }) {
    Ok(offset) =>
      if branch_eqz {
        @ir.Op::branch_i32_eq_imm16(condition, @ir.Const16::from_i16(0), offset)
      } else {
        @ir.Op::branch_i32_ne_imm16(condition, @ir.Const16::from_i16(0), offset)
      }
    Err(_) => {
      let zero = self.layout.const_to_reg(@wasmi_core.UntypedVal::from_i32(0))
      let comparator : @ir.Comparator = if branch_eqz { I32Eq } else { I32Ne }
      self.make_branch_cmp_fallback(comparator, condition, zero, offset)
    }
  }
  self.push_instr(instr, fuel_base) |> ignore
}

///|
/// Create an [`Op::BranchCmpFallback`] instruction.
fn FuncTranslator::make_branch_cmp_fallback(
  self : FuncTranslator,
  cmp : @ir.Comparator,
  lhs : @ir.Slot,
  rhs : @ir.Slot,
  offset : @ir.BranchOffset,
) -> @ir.Op raise WasmiError {
  let params = self.layout.const_to_reg(
    @wasmi_core.UntypedVal::from_u64(
      @ir.ComparatorAndOffset::new(cmp, offset).as_u64(),
    ),
  )
  @ir.Op::branch_cmp_fallback(lhs, rhs, params)
}
