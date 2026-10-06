// Port of wasmi 1.0.9 `engine/translator/func/op.rs`.
//
// Upstream's `StoreWrapOperator` trait (implemented by uninhabited marker
// types) becomes a record of constructor functions.

///|
/// The kind of the value stored by a store operator (upstream `Value`,
/// `Wrapped` and `Param` associated types).
pub(all) enum StoreValueKind {
  /// `i32.store` (value `i32`, immediate `i16`).
  I32
  /// `i64.store` (value `i64`, immediate `i16`).
  I64
  /// `i32.store8` (value `i32` wrapped to `i8`, immediate `i8`).
  I32Wrap8
  /// `i32.store16` (value `i32` wrapped to `i16`, immediate `i16`).
  I32Wrap16
  /// `i64.store8` (value `i64` wrapped to `i8`, immediate `i8`).
  I64Wrap8
  /// `i64.store16` (value `i64` wrapped to `i16`, immediate `i16`).
  I64Wrap16
  /// `i64.store32` (value `i64` wrapped to `i32`, immediate `i16`).
  I64Wrap32
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend StoreValueKind with Eq::{not_equal, equal}

///|
/// Store operators with wrapping (upstream `StoreWrapOperator`).
pub(all) struct StoreWrapOperator {
  kind : StoreValueKind
  store : (@ir.Slot, @ir.Offset64Lo) -> @ir.Op
  store_imm : (@ir.Slot, @ir.Offset64Lo) -> @ir.Op
  store_offset16 : (@ir.Slot, @ir.Offset16, @ir.Slot) -> @ir.Op
  store_offset16_imm : (@ir.Slot, @ir.Offset16, Int) -> @ir.Op
  store_at : (@ir.Slot, @ir.Address32) -> @ir.Op
  store_at_imm : (Int, @ir.Address32) -> @ir.Op
}

///|
pub let i32_store_op : StoreWrapOperator = {
  kind: I32,
  store: @ir.Op::store32,
  store_imm: @ir.Op::i32_store_imm16,
  store_offset16: @ir.Op::store32_offset16,
  store_offset16_imm: fn(ptr, offset, value) {
    @ir.Op::i32_store_offset16_imm16(ptr, offset, @ir.Const16::from_i16(value))
  },
  store_at: @ir.Op::store32_at,
  store_at_imm: fn(value, address) {
    @ir.Op::i32_store_at_imm16(@ir.Const16::from_i16(value), address)
  },
}

///|
pub let i64_store_op : StoreWrapOperator = {
  kind: I64,
  store: @ir.Op::store64,
  store_imm: @ir.Op::i64_store_imm16,
  store_offset16: @ir.Op::store64_offset16,
  store_offset16_imm: fn(ptr, offset, value) {
    @ir.Op::i64_store_offset16_imm16(ptr, offset, @ir.Const16::from_i16(value))
  },
  store_at: @ir.Op::store64_at,
  store_at_imm: fn(value, address) {
    @ir.Op::i64_store_at_imm16(@ir.Const16::from_i16(value), address)
  },
}

///|
pub let i32_store8_op : StoreWrapOperator = {
  kind: I32Wrap8,
  store: @ir.Op::i32_store8,
  store_imm: @ir.Op::i32_store8_imm,
  store_offset16: @ir.Op::i32_store8_offset16,
  store_offset16_imm: @ir.Op::i32_store8_offset16_imm,
  store_at: @ir.Op::i32_store8_at,
  store_at_imm: @ir.Op::i32_store8_at_imm,
}

///|
pub let i32_store16_op : StoreWrapOperator = {
  kind: I32Wrap16,
  store: @ir.Op::i32_store16,
  store_imm: @ir.Op::i32_store16_imm,
  store_offset16: @ir.Op::i32_store16_offset16,
  store_offset16_imm: @ir.Op::i32_store16_offset16_imm,
  store_at: @ir.Op::i32_store16_at,
  store_at_imm: @ir.Op::i32_store16_at_imm,
}

///|
pub let i64_store8_op : StoreWrapOperator = {
  kind: I64Wrap8,
  store: @ir.Op::i64_store8,
  store_imm: @ir.Op::i64_store8_imm,
  store_offset16: @ir.Op::i64_store8_offset16,
  store_offset16_imm: @ir.Op::i64_store8_offset16_imm,
  store_at: @ir.Op::i64_store8_at,
  store_at_imm: @ir.Op::i64_store8_at_imm,
}

///|
pub let i64_store16_op : StoreWrapOperator = {
  kind: I64Wrap16,
  store: @ir.Op::i64_store16,
  store_imm: @ir.Op::i64_store16_imm,
  store_offset16: @ir.Op::i64_store16_offset16,
  store_offset16_imm: @ir.Op::i64_store16_offset16_imm,
  store_at: @ir.Op::i64_store16_at,
  store_at_imm: @ir.Op::i64_store16_at_imm,
}

///|
pub let i64_store32_op : StoreWrapOperator = {
  kind: I64Wrap32,
  store: @ir.Op::i64_store32,
  store_imm: @ir.Op::i64_store32_imm16,
  store_offset16: @ir.Op::i64_store32_offset16,
  store_offset16_imm: fn(ptr, offset, value) {
    @ir.Op::i64_store32_offset16_imm16(
      ptr,
      offset,
      @ir.Const16::from_i16(value),
    )
  },
  store_at: @ir.Op::i64_store32_at,
  store_at_imm: fn(value, address) {
    @ir.Op::i64_store32_at_imm16(@ir.Const16::from_i16(value), address)
  },
}
