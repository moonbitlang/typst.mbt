// Port of wasmi 1.0.9 `engine/translator/func/layout/{mod,consts}.rs`.

///|
/// The layout of the stack frame of a function.
pub(all) struct StackLayout {
  /// The number of locals registered to the function.
  priv mut len_locals : Int
  /// All function local constants.
  priv consts : ConstRegistry
}

///|
pub fn StackLayout::new() -> StackLayout {
  { len_locals: 0, consts: ConstRegistry::new(), }
}

///|
pub fn StackLayout::reset(self : StackLayout) -> Unit {
  self.len_locals = 0
  self.consts.reset()
}

///|
/// Register `amount` local variables.
// Cannot fail; keeps upstream's `Result<(), Error>`
// (wasmi 1.0.9 translator/func/layout/mod.rs:37).
#warnings("-unused_error_type")
pub fn StackLayout::register_locals(
  self : StackLayout,
  amount : Int,
) -> Unit raise WasmiError {
  self.len_locals += amount
}

///|
/// Returns the [`StackSpace`] of the [`Slot`].
pub fn StackLayout::stack_space(
  self : StackLayout,
  slot : @ir.Slot,
) -> StackSpace {
  let index = slot.0
  if index < 0 {
    return StackSpace::Const
  }
  if index < self.len_locals {
    return StackSpace::Local
  }
  StackSpace::Temp
}

///|
/// Converts the `operand` into the associated [`Slot`].
pub fn StackLayout::operand_to_reg(
  self : StackLayout,
  operand : Operand,
) -> @ir.Slot raise WasmiError {
  match operand {
    Local(operand) => self.local_to_reg(operand.local_index())
    Temp(operand) => self.temp_to_reg(operand.operand_index())
    Immediate(operand) => self.const_to_reg(operand.val().untyped())
  }
}

///|
/// Converts the local `index` into the associated [`Slot`].
pub fn StackLayout::local_to_reg(
  _self : StackLayout,
  index : LocalIdx,
) -> @ir.Slot raise WasmiError {
  if index.0 > 0x7FFFU {
    raise WasmiError::from_translation(TranslationError::AllocatedTooManySlots)
  }
  @ir.Slot(index.0.reinterpret_as_int())
}

///|
/// Converts the temporary operand `index` into the associated [`Slot`].
pub fn StackLayout::temp_to_reg(
  self : StackLayout,
  index : OperandIdx,
) -> @ir.Slot raise WasmiError {
  let index = index.0 + self.len_locals
  if index > 0x7FFF {
    raise WasmiError::from_translation(TranslationError::AllocatedTooManySlots)
  }
  @ir.Slot(index)
}

///|
/// Allocates a function local constant `value` and returns its [`Slot`].
pub fn StackLayout::const_to_reg(
  self : StackLayout,
  value : @wasmi_core.UntypedVal,
) -> @ir.Slot raise WasmiError {
  self.consts.alloc(value)
}

///|
/// Returns an iterator yielding all function local constants in the order
/// of their frame slots (upstream `ConstRegistryIter`).
pub fn StackLayout::consts(self : StackLayout) -> Array[@wasmi_core.UntypedVal] {
  self.consts.iter()
}

///|
/// Returns the number of function local constants.
pub fn StackLayout::len_consts(self : StackLayout) -> Int {
  self.consts.idx2const.length()
}

///|
pub impl AllocConst for StackLayout with fn alloc_const(self, value) {
  self.const_to_reg(value)
}

///|
/// The [`StackSpace`] of a [`Slot`].
pub(all) enum StackSpace {
  /// Stack slot referring to a local variable.
  Local
  /// Stack slot referring to a function local constant value.
  Const
  /// Stack slot referring to a temporary stack operand.
  Temp
} derive(Eq, Debug)

///|
/// A pool of deduplicated function local constant values.
///
/// - Those constant values are identified by their associated [`Slot`].
/// - All constant values are also deduplicated so that no duplicates
///   are stored in a [`ConstRegistry`]. This also means that deciding if two
///   [`Slot`] values refer to the equal constant values can be efficiently
///   done by comparing the [`Slot`] indices without evaluating the constant
///   values.
priv struct ConstRegistry {
  /// Mapping from constant [`UntypedVal`] values to [`Slot`] indices.
  const2idx : Map[(UInt64, UInt64), @ir.Slot]
  /// Mapping from [`Slot`] indices to constant [`UntypedVal`] values.
  idx2const : Array[@wasmi_core.UntypedVal]
  /// The [`Slot`] index for the next allocated function local constant value.
  mut next_idx : Int
}

///|
fn ConstRegistry::new() -> ConstRegistry {
  { const2idx: {}, idx2const: [], next_idx: ConstRegistry::first_index(), }
}

///|
fn ConstRegistry::reset(self : ConstRegistry) -> Unit {
  self.const2idx.clear()
  self.idx2const.clear()
  self.next_idx = ConstRegistry::first_index()
}

///|
/// The maximum index for [`Slot`] referring to function local constant values.
///
/// # Note
///
/// The maximum index is also the one to be assigned to the first allocated
/// function local constant value as indices are assigned in reverse order.
fn ConstRegistry::first_index() -> Int {
  -1
}

///|
/// The minimum index for [`Slot`] referring to function local constant values.
///
/// # Note
///
/// This index is not assignable to a function local constant value and acts
/// as a sentinel value to indicate that all available indices have been assigned.
fn ConstRegistry::last_index() -> Int {
  -32768
}

///|
/// Allocates a new constant `value` on the [`ConstRegistry`] and returns its identifier.
///
/// # Note
///
/// If the constant `value` already exists in this [`ConstRegistry`] no new value is
/// allocated and the identifier of the existing constant `value` returned instead.
///
/// # Errors
///
/// If too many constant values have been allocated for this [`ConstRegistry`].
fn ConstRegistry::alloc(
  self : ConstRegistry,
  value : @wasmi_core.UntypedVal,
) -> @ir.Slot raise WasmiError {
  if self.next_idx == ConstRegistry::last_index() {
    raise WasmiError::from_translation(
      TranslationError::TooManyFuncLocalConstValues,
    )
  }
  let key = (value.lo64, value.hi64)
  match self.const2idx.get(key) {
    Some(slot) => slot
    None => {
      let register = @ir.Slot::Slot(self.next_idx)
      self.next_idx -= 1
      self.const2idx.set(key, register)
      self.idx2const.push(value)
      register
    }
  }
}

///|
/// Returns the constants in reverse allocation order.
///
/// # Note
///
/// We need to revert the iteration since we allocate new function local
/// constants in reverse order of their absolute vector indices in the
/// function call frame during execution.
fn ConstRegistry::iter(self : ConstRegistry) -> Array[@wasmi_core.UntypedVal] {
  let out = []
  for i = self.idx2const.length() - 1; i >= 0; i = i - 1 {
    out.push(self.idx2const[i])
  }
  out
}
