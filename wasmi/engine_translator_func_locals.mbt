// Port of wasmi 1.0.9 `engine/translator/func/locals.rs` and
// `engine/translator/func/utils.rs`.

///|
/// A local variable index.
pub(all) struct LocalIdx(UInt) derive(Eq, Debug)

///|
/// A input parameter to a translation or construction routine.
pub(all) enum Input[T] {
  /// A [`Slot`] operand.
  Slot(@ir.Slot)
  /// A 16-bit encoded immediate value operand.
  Immediate(T)
}

///|
/// Stores definitions of locals.
pub(all) struct LocalsRegistry {
  /// The types of the first defined local variables.
  priv tys_first : Array[@wasmi_core.ValType]
  /// The types of the remaining defined local variables.
  priv tys_remaining : Array[LocalGroup]
  /// The total number of registered locals.
  priv mut len_locals : Int
}

///|
/// A local group of one or more locals sharing a common type.
priv struct LocalGroup {
  /// The local index of the first local in the group.
  max_index : UInt
  /// The shared type of the locals in the local group.
  ty : @wasmi_core.ValType
}

///|
pub fn LocalsRegistry::new() -> LocalsRegistry {
  { tys_first: [], tys_remaining: [], len_locals: 0 }
}

///|
/// Resets `self` for reuse.
pub fn LocalsRegistry::reset(self : LocalsRegistry) -> Unit {
  self.tys_first.clear()
  self.tys_remaining.clear()
  self.len_locals = 0
}

///|
/// Returns the number of registered local variables in `self`.
pub fn LocalsRegistry::len(self : LocalsRegistry) -> Int {
  self.len_locals
}

///|
/// The maximum number of local variables per function.
let local_variables_max : Int = 30_000

///|
/// The maximum number of local variables in the fast `tys_first` vector.
let first_tys_max : Int = 100

///|
/// Registers `amount` of locals of type `ty` for `self`.
///
/// # Errors
///
/// If too many local variables have been registered.
pub fn LocalsRegistry::register(
  self : LocalsRegistry,
  amount : Int,
  ty : @wasmi_core.ValType,
) -> Unit raise WasmiError {
  if amount == 0 {
    return
  }
  if self.len().to_int64() + amount.to_int64() > local_variables_max.to_int64() {
    raise WasmiError::from_translation(TranslationError::TooManyFunctionParams)
  }
  let vacant_first = (first_tys_max - self.tys_first.length()).max(0)
  let push_to_first = if vacant_first < amount { vacant_first } else { amount }
  for _ in 0..<push_to_first {
    self.tys_first.push(ty)
  }
  let remaining_amount = amount - push_to_first
  let remaining_index = (self.len() + amount - 1).reinterpret_as_uint()
  if remaining_amount > 0 {
    self.tys_remaining.push({ max_index: remaining_index, ty })
  }
  self.len_locals += amount
}

///|
/// Returns the type of the `index` if any.
///
/// Returns `None` if `index` does not refer to any local in `self`.
pub fn LocalsRegistry::ty(self : LocalsRegistry, index : LocalIdx) -> @wasmi_core.ValType {
  let index_sz = index.0.reinterpret_as_int()
  if index_sz >= 0 && index_sz < self.tys_first.length() {
    return self.tys_first[index_sz]
  }
  match self.ty_slow(index) {
    Some(ty) => ty
    None => abort("out of bounds local index: \{index.0}")
  }
}

///|
/// Returns the [`ValType`] of the local at `index` if any.
///
/// Slow path: binary search over the local groups.
fn LocalsRegistry::ty_slow(
  self : LocalsRegistry,
  index : LocalIdx,
) -> @wasmi_core.ValType? {
  if self.tys_remaining.is_empty() {
    return None
  }
  // Upstream: `binary_search_by_key(&index.0, LocalGroup::max_index)`.
  let mut lo = 0
  let mut hi = self.tys_remaining.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let key = self.tys_remaining[mid].max_index
    if key == index.0 {
      return Some(self.tys_remaining[mid].ty)
    } else if key < index.0 {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo == self.tys_remaining.length() {
    None
  } else {
    Some(self.tys_remaining[lo].ty)
  }
}
