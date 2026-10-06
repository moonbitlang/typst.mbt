// Port of `wasmi_core/src/index_ty.rs`.

///|
/// The index type used for addressing memories and tables.
pub(all) enum IndexType {
  /// A 32-bit address type.
  I32
  /// A 64-bit address type.
  I64
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IndexType with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IndexType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend IndexType with @debug.Debug::{to_repr}

///|
/// Returns the [`ValType`] associated to `self`.
pub fn IndexType::ty(self : IndexType) -> ValType {
  match self {
    I32 => ValType::I32
    I64 => ValType::I64
  }
}

///|
/// Returns `true` if `self` is [`IndexType::I64`].
pub fn IndexType::is_64(self : IndexType) -> Bool {
  self is I64
}

///|
/// Returns the maximum size for Wasm memories and tables for `self`.
///
/// Upstream returns an `u128`.
pub fn IndexType::max_size(self : IndexType) -> @bigint.BigInt {
  match self {
    I32 => @bigint.BigInt::from_int(1) << 32
    I64 => @bigint.BigInt::from_int(1) << 64
  }
}

///|
/// Returns the minimum [`IndexType`] between `self` and `other`.
pub fn IndexType::min(self : IndexType, other : IndexType) -> IndexType {
  match (self, other) {
    (I64, I64) => I64
    _ => I32
  }
}
