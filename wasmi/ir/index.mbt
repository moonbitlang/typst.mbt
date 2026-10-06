// Port of wasmi_ir 1.0.9 `index.rs`: index types of Wasmi instructions.

///|
/// A Wasmi stack slot (register) index (upstream `i16`).
///
/// Negative indices refer to function local constant values.
pub(all) struct Slot(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Slot with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Slot with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Slot with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Slot with @debug.Debug::{to_repr}

///|
/// A Wasm function index (upstream `u32`).
pub(all) struct Func(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Func with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Func with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Func with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Func with @debug.Debug::{to_repr}

///|
/// A Wasm function type index (upstream `u32`).
pub(all) struct FuncType(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncType with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FuncType with @debug.Debug::{to_repr}

///|
/// A Wasmi internal function index (upstream `u32`).
pub(all) struct InternalFunc(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InternalFunc with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InternalFunc with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InternalFunc with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend InternalFunc with @debug.Debug::{to_repr}

///|
/// A Wasm global variable index (upstream `u32`).
pub(all) struct Global(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Global with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Global with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Global with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Global with @debug.Debug::{to_repr}

///|
/// A Wasm linear memory index (upstream `u32`).
pub(all) struct Memory(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Memory with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Memory with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Memory with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Memory with @debug.Debug::{to_repr}

///|
/// A Wasm table index (upstream `u32`).
pub(all) struct Table(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Table with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Table with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Table with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Table with @debug.Debug::{to_repr}

///|
/// A Wasm data segment index (upstream `u32`).
pub(all) struct Data(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Data with @debug.Debug::{to_repr}

///|
/// A Wasm element segment index (upstream `u32`).
pub(all) struct Elem(Int) derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Elem with @debug.Debug::{to_repr}

///|
/// Returns `true` if `self` refers to the default linear memory which always is
/// at index 0.
pub fn Memory::is_default(self : Memory) -> Bool {
  self.0 == 0
}

///|
/// Upstream `TryFrom<u32> for Slot`.
pub fn Slot::try_from_u32(local_index : UInt) -> Slot raise IrError {
  if local_index > 0x7FFFU {
    raise IrError::StackSlotOutOfBounds
  }
  Slot(local_index.reinterpret_as_int())
}

///|
/// Wrapping `i16` addition (upstream `i16::wrapping_add_unsigned`).
fn wrap_i16(value : Int) -> Int {
  (value & 0xFFFF) << 16 >> 16
}

///|
/// Returns the n-th next [`Slot`] from `self` with continuous index.
///
/// # Note
///
/// - Calling this with `n == 0` just returns `self`.
/// - This has wrapping semantics with respect to the underlying index.
pub fn Slot::next_n(self : Slot, n : Int) -> Slot {
  Slot(wrap_i16(self.0 + n))
}

///|
/// Returns the n-th previous [`Slot`] from `self` with continuous index.
///
/// # Note
///
/// - Calling this with `n == 0` just returns `self`.
/// - This has wrapping semantics with respect to the underlying index.
pub fn Slot::prev_n(self : Slot, n : Int) -> Slot {
  Slot(wrap_i16(self.0 - n))
}

///|
/// Returns the [`Slot`] with the next contiguous index.
pub fn Slot::next(self : Slot) -> Slot {
  self.next_n(1)
}

///|
/// Returns the [`Slot`] with the previous contiguous index.
pub fn Slot::prev(self : Slot) -> Slot {
  self.prev_n(1)
}

///|
/// Returns `true` if this [`Slot`] refers to a function local constant value.
pub fn Slot::is_const(self : Slot) -> Bool {
  self.0 < 0
}
