// Port of `wasmi_core/src/table/ty.rs`.

///|
/// A Wasm table descriptor.
pub struct TableType {
  /// The type of values stored in the [`Table`].
  priv element : ValType
  /// The minimum number of elements the [`Table`] must have.
  priv min : UInt64
  /// The optional maximum number of elements the [`Table`] can have.
  ///
  /// If this is `None` then the [`Table`] is not limited in size.
  priv max : UInt64?
  /// The index type used by the [`Table`].
  priv index_ty : IndexType
} derive(Eq, Hash, Debug)

///|
/// Creates a new [`TableType`].
///
/// # Panics
///
/// If `min` is greater than `max`.
pub fn TableType::new(element : ValType, min : UInt, max : UInt?) -> TableType {
  TableType::new_impl(
    element,
    IndexType::I32,
    min.to_uint64(),
    max.map(UInt::to_uint64),
  )
}

///|
/// Creates a new [`TableType`] with a 64-bit index type.
///
/// # Note
///
/// 64-bit tables are part of the [Wasm `memory64` proposal].
///
/// [Wasm `memory64` proposal]: https://github.com/WebAssembly/memory64
///
/// # Panics
///
/// If `min` is greater than `max`.
pub fn TableType::new64(
  element : ValType,
  min : UInt64,
  max : UInt64?,
) -> TableType {
  TableType::new_impl(element, IndexType::I64, min, max)
}

///|
/// Convenience constructor to create a new [`TableType`].
fn TableType::new_impl(
  element : ValType,
  index_ty : IndexType,
  min : UInt64,
  max : UInt64?,
) -> TableType {
  let absolute_max = index_ty.max_size()
  if !(@bigint.BigInt::from_uint64(min) <= absolute_max) {
    abort("assertion failed: u128::from(min) <= absolute_max")
  }
  if max is Some(max) {
    if !(min <= max && @bigint.BigInt::from_uint64(max) <= absolute_max) {
      abort("assertion failed: min <= max && u128::from(max) <= absolute_max")
    }
  }
  { element, min, max, index_ty, }
}

///|
/// Returns `true` if this is a 64-bit [`TableType`].
///
/// 64-bit memories are part of the Wasm `memory64` proposal.
pub fn TableType::is_64(self : TableType) -> Bool {
  self.index_ty.is_64()
}

///|
/// Returns the [`IndexType`] used by the [`TableType`].
pub fn TableType::index_ty(self : TableType) -> IndexType {
  self.index_ty
}

///|
/// Returns the [`ValType`] of elements stored in the table.
pub fn TableType::element(self : TableType) -> ValType {
  self.element
}

///|
/// Returns minimum number of elements the table must have.
pub fn TableType::minimum(self : TableType) -> UInt64 {
  self.min
}

///|
/// The optional maximum number of elements the table can have.
///
/// If this returns `None` then the table is not limited in size.
pub fn TableType::maximum(self : TableType) -> UInt64? {
  self.max
}

///|
/// Returns `Ok` if the element type of `self` matches `ty`.
///
/// # Errors
///
/// Returns a [`TableError::ElementTypeMismatch`] otherwise.
fn TableType::ensure_element_type_matches(
  self : TableType,
  ty : ValType,
) -> Unit raise TableError {
  if self.element() != ty {
    raise ElementTypeMismatch
  }
}

///|
/// Returns `true` if the [`TableType`] is a subtype of the `other` [`TableType`].
///
/// # Note
///
/// This implements the [subtyping rules] according to the WebAssembly spec.
///
/// [import subtyping]:
/// https://webassembly.github.io/spec/core/valid/types.html#import-subtyping
pub fn TableType::is_subtype_of(self : TableType, other : TableType) -> Bool {
  if self.is_64() != other.is_64() {
    return false
  }
  if self.element() != other.element() {
    return false
  }
  if self.minimum() < other.minimum() {
    return false
  }
  match (self.maximum(), other.maximum()) {
    (_, None) => true
    (Some(max), Some(other_max)) => max <= other_max
    _ => false
  }
}
