// Port of `wasmi_core/src/value.rs`.
//
// The `TryTruncateInto`, `TruncateSaturateInto`, `SignExtendFrom`, `Integer`
// and `Float` traits are flattened into the concrete per-type functions of
// `wasm.mbt` (their only users); the `WasmFloatExt` (`no_std`, `libm`)
// implementations live in `libm.mbt`.

///|
/// Type of a value.
///
/// See [`Val`] for details.
pub(all) enum ValType {
  /// 32-bit signed or unsigned integer.
  I32
  /// 64-bit signed or unsigned integer.
  I64
  /// 32-bit IEEE 754-2008 floating point number.
  F32
  /// 64-bit IEEE 754-2008 floating point number.
  F64
  /// A 128-bit Wasm `simd` proposal vector.
  V128
  /// A nullable function reference.
  FuncRef
  /// A nullable external reference.
  ExternRef
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValType with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValType with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValType with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ValType with @debug.Debug::{to_repr}

///|
/// Rust's `Debug` of [ValType] (the variant name).
pub impl Show for ValType with fn output(self, logger) {
  logger.write_string(
    match self {
      I32 => "I32"
      I64 => "I64"
      F32 => "F32"
      F64 => "F64"
      V128 => "V128"
      FuncRef => "FuncRef"
      ExternRef => "ExternRef"
    },
  )
}

///|
pub extend ValType with Show::{to_string, output}

///|
/// Returns `true` if [`ValType`] is a Wasm numeric type.
///
/// This is `true` for [`ValType::I32`], [`ValType::I64`],
/// [`ValType::F32`] and [`ValType::F64`].
pub fn ValType::is_num(self : ValType) -> Bool {
  self is (I32 | I64 | F32 | F64)
}

///|
/// Returns `true` if [`ValType`] is a Wasm reference type.
///
/// This is `true` for [`ValType::FuncRef`] and [`ValType::ExternRef`].
pub fn ValType::is_ref(self : ValType) -> Bool {
  self is (ExternRef | FuncRef)
}

///|
/// The Wasm `simd` proposal's `v128` type (upstream `V128`, a reserved type
/// name in MoonBit).
///
/// Upstream stores the 16 little-endian bytes of a `u128`; here the value is
/// split into its low and high 64 bits (`lo` holds bytes 0..8 = lanes with
/// the lowest indices).
#valtype
pub struct V128Value {
  lo : UInt64
  hi : UInt64
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend V128Value with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend V128Value with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend V128Value with @debug.Debug::{to_repr}

///|
/// Creates a [`V128Value`] from the low and high 64 bits of its `u128` value
/// (upstream `V128::from(u128)`).
pub fn V128Value::from_lo_hi(lo : UInt64, hi : UInt64) -> V128Value {
  { lo, hi, }
}

///|
/// Returns the low 64 bits of the `u128` value of `self`.
pub fn V128Value::lo(self : V128Value) -> UInt64 {
  self.lo
}

///|
/// Returns the high 64 bits of the `u128` value of `self`.
pub fn V128Value::hi(self : V128Value) -> UInt64 {
  self.hi
}

///|
/// Creates a [`V128Value`] from its 16 little-endian bytes.
pub fn V128Value::from_le_bytes(bytes : ArrayView[Byte]) -> V128Value {
  let mut lo = 0UL
  let mut hi = 0UL
  for i in 0..<8 {
    lo = lo | (bytes[i].to_uint64() << (8 * i))
    hi = hi | (bytes[i + 8].to_uint64() << (8 * i))
  }
  { lo, hi, }
}

///|
/// Returns the 16 little-endian bytes of `self`.
pub fn V128Value::to_le_bytes(self : V128Value) -> FixedArray[Byte] {
  FixedArray::makei(16, i => {
    let w = if i < 8 { self.lo } else { self.hi }
    (w >> (8 * (i & 7))).to_byte()
  })
}
