// Port of `wasmi_core/src/float.rs`.

///|
/// A 32-bit `f32` type.
pub struct F32(UInt)

///|
/// Creates a float from its underlying bits.
pub fn F32::from_bits(other : UInt) -> F32 {
  F32(other)
}

///|
/// Returns the underlying bits of the float.
pub fn F32::to_bits(self : F32) -> UInt {
  self.0
}

///|
/// Creates a float from the respective primitive float type.
pub fn F32::from_float(float : Float) -> F32 {
  F32(float.reinterpret_as_uint())
}

///|
/// Returns the respective primitive float type.
pub fn F32::to_float(self : F32) -> Float {
  Float::reinterpret_from_uint(self.0)
}

///|
pub impl Eq for F32 with fn equal(self, other) {
  self.to_float() == other.to_float()
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend F32 with Eq::{not_equal, equal}

///|
/// `PartialOrd::partial_cmp`: `None` if either value is NaN.
pub fn F32::partial_cmp(self : F32, other : F32) -> Int? {
  let a = self.to_float()
  let b = other.to_float()
  if a < b {
    Some(-1)
  } else if a > b {
    Some(1)
  } else if a == b {
    Some(0)
  } else {
    None
  }
}

///|
/// Rust's `Display` of [F32].
pub impl Show for F32 with fn output(self, logger) {
  if self.to_float().is_nan() {
    logger.write_string("nan:0x\{upper_hex(self.0.to_uint64())}")
    return
  }
  logger.write_string(rust_display_f32(self.to_float()))
}

///|
pub extend F32 with Show::{to_string, output}

///|
/// Rust's `Debug` of [F32].
pub impl Debug for F32 with fn to_repr(self) {
  if self.to_float().is_nan() {
    return Repr::literal("nan:0x\{upper_hex(self.0.to_uint64())}")
  }
  Repr::literal(rust_debug_f32(self.to_float()))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend F32 with @debug.Debug::{to_repr}

///|
/// A 64-bit `f64` type.
pub struct F64(UInt64)

///|
/// Creates a float from its underlying bits.
pub fn F64::from_bits(other : UInt64) -> F64 {
  F64(other)
}

///|
/// Returns the underlying bits of the float.
pub fn F64::to_bits(self : F64) -> UInt64 {
  self.0
}

///|
/// Creates a float from the respective primitive float type.
pub fn F64::from_float(float : Double) -> F64 {
  F64(float.reinterpret_as_uint64())
}

///|
/// Returns the respective primitive float type.
pub fn F64::to_float(self : F64) -> Double {
  self.0.reinterpret_as_double()
}

///|
pub impl Eq for F64 with fn equal(self, other) {
  self.to_float() == other.to_float()
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend F64 with Eq::{not_equal, equal}

///|
/// `PartialOrd::partial_cmp`: `None` if either value is NaN.
pub fn F64::partial_cmp(self : F64, other : F64) -> Int? {
  let a = self.to_float()
  let b = other.to_float()
  if a < b {
    Some(-1)
  } else if a > b {
    Some(1)
  } else if a == b {
    Some(0)
  } else {
    None
  }
}

///|
/// Rust's `Display` of [F64].
pub impl Show for F64 with fn output(self, logger) {
  if self.to_float().is_nan() {
    logger.write_string("nan:0x\{upper_hex(self.0)}")
    return
  }
  logger.write_string(rust_display_f64(self.to_float()))
}

///|
pub extend F64 with Show::{to_string, output}

///|
/// Rust's `Debug` of [F64].
pub impl Debug for F64 with fn to_repr(self) {
  if self.to_float().is_nan() {
    return Repr::literal("nan:0x\{upper_hex(self.0)}")
  }
  Repr::literal(rust_debug_f64(self.to_float()))
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend F64 with @debug.Debug::{to_repr}

///|
/// Rust's `{:X}` of an unsigned integer.
fn upper_hex(v : UInt64) -> String {
  v.to_string(radix=16).to_upper()
}
