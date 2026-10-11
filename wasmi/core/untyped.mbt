// Port of `wasmi_core/src/untyped.rs` (with the `simd` feature).
//
// The `ReadAs<T>` / `WriteAs<T>` / `From` impls become per-type functions:
// `read_as::<T>()` -> `read_<t>()`, `write_as::<T>(v)` -> `write_<t>(v)`
// (returning the updated value since [`UntypedVal`] is an immutable value
// type here) and `UntypedVal::from(v: T)` -> `UntypedVal::from_<t>(v)`.
// `i8`/`i16`/`u8`/`u16` values are carried as `Int`. The generic tuple
// `decode_slice` / `encode_slice` helpers are not ported (callers read and
// write the slots individually).

///|
/// An untyped value.
///
/// Provides a dense and simple interface to all functional Wasm operations.
#valtype
pub struct UntypedVal {
  /// The low 64-bits of an [`UntypedVal`].
  ///
  /// The low 64-bits are used to encode and decode all types that
  /// are convertible from and to an [`UntypedVal`] that fit into
  /// 64-bits such as `i32`, `i64`, `f32` and `f64`.
  lo64 : UInt64
  /// The high 64-bits of an [`UntypedVal`].
  ///
  /// This is only used to encode or decode types which do not fit
  /// into the lower 64-bits part such as Wasm's `V128` or `i128`.
  hi64 : UInt64
} derive(Eq, Compare, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UntypedVal with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UntypedVal with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UntypedVal with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UntypedVal with @debug.Debug::{to_repr}

///|
pub impl Default for UntypedVal with fn default() {
  { lo64: 0, hi64: 0, }
}

///|
/// Creates an [`UntypedVal`] from the given lower 64-bit bits.
///
/// This sets the high 64-bits to zero if any.
pub fn UntypedVal::from_bits64(lo64 : UInt64) -> UntypedVal {
  { lo64, hi64: 0, }
}

///|
/// Returns the underlying lower 64-bits of the [`UntypedVal`].
///
/// This ignores the high 64-bits of the [`UntypedVal`] if any.
pub fn UntypedVal::to_bits64(self : UntypedVal) -> UInt64 {
  self.lo64
}

///|
/// Returns the high 64-bits of the [`UntypedVal`].
pub fn UntypedVal::hi64(self : UntypedVal) -> UInt64 {
  self.hi64
}

///|
/// Writes the low 64-bit of the [`UntypedVal`] (keeping the high bits).
fn UntypedVal::write_lo64(self : UntypedVal, bits : UInt64) -> UntypedVal {
  { lo64: bits, hi64: self.hi64, }
}

// ReadAs

///|
/// `ReadAs<i8>` (sign-extended to `Int`).
pub fn UntypedVal::read_i8(self : UntypedVal) -> Int {
  self.lo64.to_int() << 24 >> 24
}

///|
/// `ReadAs<i16>` (sign-extended to `Int`).
pub fn UntypedVal::read_i16(self : UntypedVal) -> Int {
  self.lo64.to_int() << 16 >> 16
}

///|
/// `ReadAs<i32>`
pub fn UntypedVal::read_i32(self : UntypedVal) -> Int {
  self.lo64.to_int()
}

///|
/// `ReadAs<i64>`
pub fn UntypedVal::read_i64(self : UntypedVal) -> Int64 {
  self.lo64.reinterpret_as_int64()
}

///|
/// `ReadAs<u8>` (zero-extended to `Int`).
pub fn UntypedVal::read_u8(self : UntypedVal) -> Int {
  self.lo64.to_int() & 0xFF
}

///|
/// `ReadAs<u16>` (zero-extended to `Int`).
pub fn UntypedVal::read_u16(self : UntypedVal) -> Int {
  self.lo64.to_int() & 0xFFFF
}

///|
/// `ReadAs<u32>`
pub fn UntypedVal::read_u32(self : UntypedVal) -> UInt {
  self.lo64.to_uint()
}

///|
/// `ReadAs<u64>`
pub fn UntypedVal::read_u64(self : UntypedVal) -> UInt64 {
  self.lo64
}

///|
/// `ReadAs<f32>`
pub fn UntypedVal::read_f32(self : UntypedVal) -> Float {
  Float::reinterpret_from_uint(self.lo64.to_uint())
}

///|
/// `ReadAs<f64>`
pub fn UntypedVal::read_f64(self : UntypedVal) -> Double {
  self.lo64.reinterpret_as_double()
}

///|
/// `ReadAs<bool>`
pub fn UntypedVal::read_bool(self : UntypedVal) -> Bool {
  self.lo64 != 0
}

///|
/// `ReadAs<V128>`
pub fn UntypedVal::read_v128(self : UntypedVal) -> V128Value {
  { lo: self.lo64, hi: self.hi64, }
}

// WriteAs

///|
/// `WriteAs<i8>` (`value as u8 as u64`).
pub fn UntypedVal::write_i8(self : UntypedVal, value : Int) -> UntypedVal {
  self.write_lo64((value & 0xFF).to_uint64())
}

///|
/// `WriteAs<i16>` (`value as u16 as u64`).
pub fn UntypedVal::write_i16(self : UntypedVal, value : Int) -> UntypedVal {
  self.write_lo64((value & 0xFFFF).to_uint64())
}

///|
/// `WriteAs<i32>` (`value as u32 as u64`).
pub fn UntypedVal::write_i32(self : UntypedVal, value : Int) -> UntypedVal {
  self.write_lo64(value.reinterpret_as_uint().to_uint64())
}

///|
/// `WriteAs<i64>`
pub fn UntypedVal::write_i64(self : UntypedVal, value : Int64) -> UntypedVal {
  self.write_lo64(value.reinterpret_as_uint64())
}

///|
/// `WriteAs<u32>`
pub fn UntypedVal::write_u32(self : UntypedVal, value : UInt) -> UntypedVal {
  self.write_lo64(value.to_uint64())
}

///|
/// `WriteAs<u64>`
pub fn UntypedVal::write_u64(self : UntypedVal, value : UInt64) -> UntypedVal {
  self.write_lo64(value)
}

///|
/// `WriteAs<bool>`
pub fn UntypedVal::write_bool(self : UntypedVal, value : Bool) -> UntypedVal {
  self.write_lo64(if value { 1 } else { 0 })
}

///|
/// `WriteAs<f32>`
pub fn UntypedVal::write_f32(self : UntypedVal, value : Float) -> UntypedVal {
  self.write_lo64(value.reinterpret_as_uint().to_uint64())
}

///|
/// `WriteAs<f64>`
pub fn UntypedVal::write_f64(self : UntypedVal, value : Double) -> UntypedVal {
  self.write_lo64(value.reinterpret_as_uint64())
}

///|
/// `WriteAs<V128>`
pub fn UntypedVal::write_v128(
  _self : UntypedVal,
  value : V128Value,
) -> UntypedVal {
  UntypedVal::from_v128(value)
}

// From<T> for UntypedVal

///|
/// `From<u8>` / `From<u16>` / `From<u32>`
pub fn UntypedVal::from_u32(value : UInt) -> UntypedVal {
  UntypedVal::from_bits64(value.to_uint64())
}

///|
/// `From<u64>`
pub fn UntypedVal::from_u64(value : UInt64) -> UntypedVal {
  UntypedVal::from_bits64(value)
}

///|
/// `From<bool>`
pub fn UntypedVal::from_bool(value : Bool) -> UntypedVal {
  UntypedVal::from_bits64(if value { 1 } else { 0 })
}

///|
/// `From<i8>` (`u64::from(value as u8)`).
pub fn UntypedVal::from_i8(value : Int) -> UntypedVal {
  UntypedVal::from_bits64((value & 0xFF).to_uint64())
}

///|
/// `From<i16>` (`u64::from(value as u16)`).
pub fn UntypedVal::from_i16(value : Int) -> UntypedVal {
  UntypedVal::from_bits64((value & 0xFFFF).to_uint64())
}

///|
/// `From<i32>` (`u64::from(value as u32)`).
pub fn UntypedVal::from_i32(value : Int) -> UntypedVal {
  UntypedVal::from_bits64(value.reinterpret_as_uint().to_uint64())
}

///|
/// `From<i64>`
pub fn UntypedVal::from_i64(value : Int64) -> UntypedVal {
  UntypedVal::from_bits64(value.reinterpret_as_uint64())
}

///|
/// `From<f32>`
pub fn UntypedVal::from_f32(value : Float) -> UntypedVal {
  UntypedVal::from_bits64(value.reinterpret_as_uint().to_uint64())
}

///|
/// `From<f64>`
pub fn UntypedVal::from_f64(value : Double) -> UntypedVal {
  UntypedVal::from_bits64(value.reinterpret_as_uint64())
}

///|
/// `From<V128>`
pub fn UntypedVal::from_v128(value : V128Value) -> UntypedVal {
  { lo64: value.lo, hi64: value.hi, }
}

///|
/// An error that may occur upon encoding or decoding slices of [`UntypedVal`].
pub(all) suberror UntypedError {
  /// The [`UntypedVal`] slice length did not match `Self`.
  InvalidLen
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend UntypedError with @debug.Debug::{to_repr}

///|
/// Creates a new `InvalidLen` [`UntypedError`].
pub fn UntypedError::invalid_len() -> UntypedError {
  InvalidLen
}

///|
pub impl Show for UntypedError with fn output(self, logger) {
  match self {
    InvalidLen => logger.write_string("mismatched length of the untyped slice")
  }
}

///|
pub extend UntypedError with Show::{to_string, output}
