// Port of wasmi 1.0.9 `engine/translator/func/instrs.rs`.

///|
/// A function computing the fuel costs of an instruction.
pub type FuelCostsFn = (@wasmi_core.FuelCostsProvider) -> UInt64

///|
/// Upstream `FuelCostsProvider::base`.
pub fn fuel_base(costs : @wasmi_core.FuelCostsProvider) -> UInt64 {
  costs.base()
}

///|
/// Encodes Wasmi bytecode instructions to an [`Op`] stream.
pub(all) struct InstrEncoder {
  /// Already encoded [`Op`] words.
  priv instrs : Array[@ir.Op]
  /// The fuel costs of instructions.
  ///
  /// This is `Some` if fuel metering is enabled, otherwise `None`.
  priv fuel_costs : @wasmi_core.FuelCostsProvider?
  /// The last pushed non-parameter [`Op`].
  priv mut last_instr : Instr?
}

///|
/// Creates a new [`InstrEncoder`].
pub fn InstrEncoder::new(engine : EngineWeak) -> InstrEncoder {
  let config = engine.config()
  let fuel_costs = if config.get_consume_fuel() {
    Some(config.fuel_costs())
  } else {
    None
  }
  { instrs: [], fuel_costs, last_instr: None, }
}

///|
/// Returns the next [`Instr`].
pub fn InstrEncoder::next_instr(self : InstrEncoder) -> Instr {
  Instr::from_usize(self.instrs.length())
}

///|
/// Pushes an [`Op::ConsumeFuel`] instruction to `self`.
///
/// # Note
///
/// The pushes [`Op::ConsumeFuel`] is initialized with base fuel costs.
pub fn InstrEncoder::push_consume_fuel_instr(
  self : InstrEncoder,
) -> Instr? raise WasmiError {
  guard self.fuel_costs is Some(fuel_costs) else { return None }
  let base_costs = fuel_costs.base()
  if base_costs > 0xFFFF_FFFFUL {
    abort("out of  bounds base fuel costs: \{base_costs}")
  }
  let instr = self.push_instr_impl(
    @ir.Op::consume_fuel(@ir.BlockFuel::from_u32(base_costs.to_uint())),
  )
  Some(instr)
}

///|
/// Pushes a non-parameter [`Op`] to the [`InstrEncoder`].
///
/// Returns an [`Instr`] that refers to the pushed [`Op`].
pub fn InstrEncoder::push_instr(
  self : InstrEncoder,
  instruction : @ir.Op,
  consume_fuel : Instr?,
  f : FuelCostsFn,
) -> Instr raise WasmiError {
  self.bump_fuel_consumption(consume_fuel, f)
  self.push_instr_impl(instruction)
}

///|
/// Pushes a non-parameter [`Op`] to the [`InstrEncoder`].
fn InstrEncoder::push_instr_impl(
  self : InstrEncoder,
  instruction : @ir.Op,
) -> Instr raise WasmiError {
  let instr = self.next_instr()
  self.instrs.push(instruction)
  self.last_instr = Some(instr)
  instr
}

///|
/// Replaces `instr` with `new_instr` in `self`.
///
/// - Returns `Ok(true)` if replacement was successful.
/// - Returns `Ok(false)` if replacement was unsuccessful.
pub fn InstrEncoder::try_replace_instr(
  self : InstrEncoder,
  instr : Instr,
  new_instr : @ir.Op,
) -> Bool raise WasmiError {
  guard self.last_instr is Some(last_instr) else { return false }
  if instr != last_instr {
    return false
  }
  self.instrs[instr.into_usize()] = new_instr
  true
}

///|
/// Tries to replace the result of the last instruction with `new_result` if possible.
///
/// # Note
///
/// - `old_result`:
///   just required for additional safety to check if the last instruction
///   really is the source of the `local.set` or `local.tee`.
/// - `new_result`:
///   the new result which shall replace the `old_result`.
pub fn InstrEncoder::try_replace_result(
  self : InstrEncoder,
  new_result : @ir.Slot,
  old_result : @ir.Slot,
  layout : StackLayout,
  module : ModuleHeader,
) -> Bool raise WasmiError {
  if !(layout.stack_space(new_result) is Local) {
    // Case: cannot replace result if `new_result` isn't a local.
    return false
  }
  guard self.last_instr is Some(last_instr) else {
    // Case: cannot replace result without last instruction.
    return false
  }
  guard relink_result(self.get(last_instr), module, new_result, old_result)
    is Some(relinked) else {
    // Case: it was impossible to relink the result of `last_instr.
    return false
  }
  self.instrs[last_instr.into_usize()] = relinked
  true
}

///|
/// Tries to fuse a compare instruction with a Wasm `select` instruction.
///
/// # Returns
///
/// - Returns `Some` if fusion was successful.
/// - Returns `None` if fusion could not be applied.
pub fn InstrEncoder::try_fuse_select(
  self : InstrEncoder,
  ty : @wasmi_core.ValType,
  select_condition : @ir.Slot,
  layout : StackLayout,
  stack : TranslatorStack,
) -> Bool? raise WasmiError {
  guard self.last_instr is Some(last_instr) else {
    // If there is no last instruction there is no comparison instruction to negate.
    return None
  }
  let last_instruction = self.get(last_instr)
  guard compare_result(last_instruction) is Some(last_result) else {
    // All negatable instructions have a single result register.
    return None
  }
  if layout.stack_space(last_result) is Local {
    // The instruction stores its result into a local variable which
    // is an observable side effect which we are not allowed to mutate.
    return None
  }
  if last_result != select_condition {
    // The result of the last instruction and the select's `condition`
    // are not equal thus indicating that we cannot fuse the instructions.
    return None
  }
  guard try_into_cmp_select_instr(last_instruction, fn() raise WasmiError {
      let select_result = stack.push_temp(ty, Some(last_instr))
      layout.temp_to_reg(select_result)
    })
    is Applied(fused~, swap_operands~) else {
    return None
  }
  self.instrs[last_instr.into_usize()] = fused
  Some(swap_operands)
}

///|
/// Pushes an [`Op`] parameter to the [`InstrEncoder`].
///
/// The parameter is associated to the last pushed [`Op`].
pub fn InstrEncoder::push_param(
  self : InstrEncoder,
  instruction : @ir.Op,
) -> Unit {
  self.instrs.push(instruction)
}

///|
/// Returns a shared reference to the [`Op`] associated to [`Instr`].
pub fn InstrEncoder::get(self : InstrEncoder, instr : Instr) -> @ir.Op {
  self.instrs[instr.into_usize()]
}

///|
/// Replaces the [`Op`] associated to [`Instr`] (upstream `get_mut`).
pub fn InstrEncoder::set(
  self : InstrEncoder,
  instr : Instr,
  op : @ir.Op,
) -> Unit {
  self.instrs[instr.into_usize()] = op
}

///|
/// Resets the [`Instr`] last created via [`InstrEncoder::push_instr`].
///
/// # Note
///
/// The `last_instr` information is used for an optimization with `local.set`
/// and `local.tee` translation to replace the result [`Slot`] of the
/// last created [`Op`] instead of creating another copy [`Op`].
///
/// Whenever ending a control block during Wasm translation the `last_instr`
/// information needs to be reset so that a `local.set` or `local.tee` does
/// not invalidly optimize across control flow boundaries.
pub fn InstrEncoder::reset_last_instr(self : InstrEncoder) -> Unit {
  self.last_instr = None
}

///|
/// Updates the branch offset of `instr` to `offset`.
///
/// # Errors
///
/// If the branch offset could not be updated for `instr`.
pub fn InstrEncoder::update_branch_offset(
  self : InstrEncoder,
  instr : Instr,
  offset : @ir.BranchOffset,
  layout : StackLayout,
) -> Unit raise WasmiError {
  let updated = update_branch_offset(self.get(instr), layout, offset)
  self.instrs[instr.into_usize()] = updated
}

///|
/// Bumps consumed fuel for [`Op::ConsumeFuel`] of `instr` by `delta`.
///
/// # Errors
///
/// If consumed fuel is out of bounds after this operation.
pub fn InstrEncoder::bump_fuel_consumption(
  self : InstrEncoder,
  consume_fuel : Instr?,
  f : FuelCostsFn,
) -> Unit raise WasmiError {
  let (fuel_costs, consume_fuel) = match (self.fuel_costs, consume_fuel) {
    (None, None) => return
    (Some(fuel_costs), Some(consume_fuel)) => (fuel_costs, consume_fuel)
    _ => abort("fuel metering state mismatch")
  }
  let fuel_consumed = f(fuel_costs)
  match self.get(consume_fuel) {
    ConsumeFuel(block_fuel~) => {
      let block_fuel = block_fuel.bump_by(fuel_consumed) catch {
        e => raise WasmiError::from_ir(e)
      }
      self.instrs[consume_fuel.into_usize()] = ConsumeFuel(block_fuel~)
    }
    instr => abort("expected `Op::ConsumeFuel` but found: \{instr.name()}")
  }
}

///|
/// Encodes the [`Operand`]s as a list of [`Slot`] parameters.
pub fn InstrEncoder::encode_register_list(
  self : InstrEncoder,
  operands : ArrayView[Operand],
  layout : StackLayout,
) -> Unit raise WasmiError {
  let mut remaining = operands
  let instr = while true {
    match remaining {
      [] => return
      [v0] => {
        let v0 = layout.operand_to_reg(v0)
        break @ir.Op::slot(v0)
      }
      [v0, v1] => {
        let v0 = layout.operand_to_reg(v0)
        let v1 = layout.operand_to_reg(v1)
        break @ir.Op::slot2([v0, v1])
      }
      [v0, v1, v2] => {
        let v0 = layout.operand_to_reg(v0)
        let v1 = layout.operand_to_reg(v1)
        let v2 = layout.operand_to_reg(v2)
        break @ir.Op::slot3([v0, v1, v2])
      }
      [v0, v1, v2, .. rest] => {
        let v0 = layout.operand_to_reg(v0)
        let v1 = layout.operand_to_reg(v1)
        let v2 = layout.operand_to_reg(v2)
        let instr = @ir.Op::slot_list([v0, v1, v2])
        self.push_param(instr)
        remaining = rest
      }
    }
  } nobreak {
    abort("unreachable")
  }
  self.push_param(instr)
}

///|
/// Returns the encoded instructions (upstream `drain`).
pub fn InstrEncoder::drain(self : InstrEncoder) -> FixedArray[@ir.Op] {
  let out = FixedArray::from_array(self.instrs)
  self.instrs.clear()
  out
}

///|
/// Returns the last instruction of the [`InstrEncoder`] if any.
pub fn InstrEncoder::last_instr(self : InstrEncoder) -> Instr? {
  self.last_instr
}
