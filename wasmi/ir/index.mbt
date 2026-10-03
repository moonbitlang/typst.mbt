// Port of wasmi_ir 1.0.9 `index.rs`: index types of Wasmi instructions.

///|
/// A Wasmi stack slot (register) index (upstream `i16`).
///
/// Negative indices refer to function local constant values.
pub(all) struct Slot(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm function index (upstream `u32`).
pub(all) struct Func(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm function type index (upstream `u32`).
pub(all) struct FuncType(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasmi internal function index (upstream `u32`).
pub(all) struct InternalFunc(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm global variable index (upstream `u32`).
pub(all) struct Global(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm linear memory index (upstream `u32`).
pub(all) struct Memory(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm table index (upstream `u32`).
pub(all) struct Table(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm data segment index (upstream `u32`).
pub(all) struct Data(Int) derive(Eq, Compare, Hash, Debug)

///|
/// A Wasm element segment index (upstream `u32`).
pub(all) struct Elem(Int) derive(Eq, Compare, Hash, Debug)

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
  ((value & 0xFFFF) << 16) >> 16
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
