// Port of wasmi_ir 1.0.9 `immeditate.rs`.
//
// Upstream's `Const16<T>`/`Const32<T>` carry the logical type `T` as a phantom
// type parameter; here the type is implied by the instruction field (see the
// comments in `op_gen.mbt`'s source, for_each_op.rs) and the accessors are
// named after the conversion (`to_i32`, `to_u64`, ...).

///|
/// A typed 16-bit encoded constant value (the raw 16 bits).
pub(all) struct Const16(Int) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Const16 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Const16 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Const16 with @debug.Debug::{to_repr}

///|
/// A typed 32-bit encoded constant value (the raw 32 bits).
pub(all) struct Const32(Int) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Const32 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Const32 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Const32 with @debug.Debug::{to_repr}

///|
/// A 16-bit constant value of any type (the raw 16 bits).
pub(all) struct AnyConst16(Int) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnyConst16 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnyConst16 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnyConst16 with @debug.Debug::{to_repr}

///|
/// A 32-bit constant value of any type (the raw 32 bits).
pub(all) struct AnyConst32(Int) derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnyConst32 with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnyConst32 with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AnyConst32 with @debug.Debug::{to_repr}

// ---------------------------------------------------------------------------
// AnyConst16

///|
/// Upstream `From<i16> for AnyConst16`.
pub fn AnyConst16::from_i16(value : Int) -> AnyConst16 {
  AnyConst16(value & 0xFFFF)
}

///|
/// Upstream `From<u16> for AnyConst16`.
pub fn AnyConst16::from_u16(value : Int) -> AnyConst16 {
  AnyConst16(value & 0xFFFF)
}

///|
/// Upstream `From<i8> for AnyConst16`.
pub fn AnyConst16::from_i8(value : Int) -> AnyConst16 {
  AnyConst16(value & 0xFF)
}

///|
/// Upstream `TryFrom<i32> for AnyConst16` (via `i16`).
pub fn AnyConst16::try_from_i32(value : Int) -> AnyConst16? {
  if value >= -32768 && value <= 32767 {
    Some(AnyConst16(value & 0xFFFF))
  } else {
    None
  }
}

///|
/// Upstream `TryFrom<u32> for AnyConst16` (via `u16`).
pub fn AnyConst16::try_from_u32(value : UInt) -> AnyConst16? {
  if value <= 0xFFFFU {
    Some(AnyConst16(value.reinterpret_as_int()))
  } else {
    None
  }
}

///|
/// Upstream `TryFrom<i64> for AnyConst16` (via `i16`).
pub fn AnyConst16::try_from_i64(value : Int64) -> AnyConst16? {
  if value >= -32768L && value <= 32767L {
    Some(AnyConst16(value.to_int() & 0xFFFF))
  } else {
    None
  }
}

///|
/// Upstream `TryFrom<u64> for AnyConst16` (via `u16`).
pub fn AnyConst16::try_from_u64(value : UInt64) -> AnyConst16? {
  if value <= 0xFFFFUL {
    Some(AnyConst16(value.to_int()))
  } else {
    None
  }
}

///|
/// Upstream `From<AnyConst16> for i8`.
pub fn AnyConst16::to_i8(self : AnyConst16) -> Int {
  (self.0 & 0xFF) << 24 >> 24
}

///|
/// Upstream `From<AnyConst16> for i16`.
pub fn AnyConst16::to_i16(self : AnyConst16) -> Int {
  (self.0 & 0xFFFF) << 16 >> 16
}

///|
/// Upstream `From<AnyConst16> for u16`.
pub fn AnyConst16::to_u16(self : AnyConst16) -> Int {
  self.0 & 0xFFFF
}

///|
/// Upstream `From<AnyConst16> for i32` (sign extension).
pub fn AnyConst16::to_i32(self : AnyConst16) -> Int {
  self.to_i16()
}

///|
/// Upstream `From<AnyConst16> for u32` (zero extension).
pub fn AnyConst16::to_u32(self : AnyConst16) -> UInt {
  self.to_u16().reinterpret_as_uint()
}

///|
/// Upstream `From<AnyConst16> for i64` (sign extension).
pub fn AnyConst16::to_i64(self : AnyConst16) -> Int64 {
  self.to_i16().to_int64()
}

///|
/// Upstream `From<AnyConst16> for u64` (zero extension).
pub fn AnyConst16::to_u64(self : AnyConst16) -> UInt64 {
  self.to_u16().to_uint64()
}

// ---------------------------------------------------------------------------
// Const16<T>

///|
/// Upstream `Const16<T>::is_zero`.
pub fn Const16::is_zero(self : Const16) -> Bool {
  self.0 == 0
}

///|
/// Upstream `Const16<u64>::cast(Const16<u32>)`.
pub fn Const16::cast(self : Const16) -> Const16 {
  self
}

///|
/// Upstream `From<i16> for Const16<i32>`/`Const16<i64>`.
pub fn Const16::from_i16(value : Int) -> Const16 {
  Const16(value & 0xFFFF)
}

///|
/// Upstream `From<u16> for Const16<u32>`/`Const16<u64>`.
pub fn Const16::from_u16(value : Int) -> Const16 {
  Const16(value & 0xFFFF)
}

///|
/// Upstream `TryFrom<i32> for Const16<i32>` (also `NonZero<i32>`).
pub fn Const16::try_from_i32(value : Int) -> Const16? {
  match AnyConst16::try_from_i32(value) {
    Some(c) => Some(Const16(c.0))
    None => None
  }
}

///|
/// Upstream `TryFrom<u32> for Const16<u32>` (also `NonZero<u32>`).
pub fn Const16::try_from_u32(value : UInt) -> Const16? {
  match AnyConst16::try_from_u32(value) {
    Some(c) => Some(Const16(c.0))
    None => None
  }
}

///|
/// Upstream `TryFrom<i64> for Const16<i64>` (also `NonZero<i64>`).
pub fn Const16::try_from_i64(value : Int64) -> Const16? {
  match AnyConst16::try_from_i64(value) {
    Some(c) => Some(Const16(c.0))
    None => None
  }
}

///|
/// Upstream `TryFrom<u64> for Const16<u64>` (also `NonZero<u64>`).
pub fn Const16::try_from_u64(value : UInt64) -> Const16? {
  match AnyConst16::try_from_u64(value) {
    Some(c) => Some(Const16(c.0))
    None => None
  }
}

///|
/// Upstream `From<Const16<i32>> for i32`.
pub fn Const16::to_i32(self : Const16) -> Int {
  (self.0 & 0xFFFF) << 16 >> 16
}

///|
/// Upstream `From<Const16<u32>> for u32`.
pub fn Const16::to_u32(self : Const16) -> UInt {
  (self.0 & 0xFFFF).reinterpret_as_uint()
}

///|
/// Upstream `From<Const16<i64>> for i64`.
pub fn Const16::to_i64(self : Const16) -> Int64 {
  self.to_i32().to_int64()
}

///|
/// Upstream `From<Const16<u64>> for u64`.
pub fn Const16::to_u64(self : Const16) -> UInt64 {
  (self.0 & 0xFFFF).to_uint64()
}

// ---------------------------------------------------------------------------
// AnyConst32 / Const32<T>

///|
/// Upstream `From<i32> for AnyConst32` (also `u32`, `i16`, ... bit casts).
pub fn AnyConst32::from_i32(value : Int) -> AnyConst32 {
  AnyConst32(value)
}

///|
/// Upstream `From<u32> for AnyConst32`.
pub fn AnyConst32::from_u32(value : UInt) -> AnyConst32 {
  AnyConst32(value.reinterpret_as_int())
}

///|
/// Upstream `From<bool> for AnyConst32`.
pub fn AnyConst32::from_bool(value : Bool) -> AnyConst32 {
  AnyConst32(if value { 1 } else { 0 })
}

///|
/// Upstream `From<f32> for AnyConst32`.
pub fn AnyConst32::from_f32(value : Float) -> AnyConst32 {
  AnyConst32(value.reinterpret_as_int())
}

///|
/// Upstream `From<f32> for AnyConst32` with the f32 given by its bits.
pub fn AnyConst32::from_f32_bits(bits : UInt) -> AnyConst32 {
  AnyConst32(bits.reinterpret_as_int())
}

///|
/// Upstream `TryFrom<u64> for AnyConst32`.
pub fn AnyConst32::try_from_u64(value : UInt64) -> AnyConst32? {
  if value <= 0xFFFF_FFFFUL {
    Some(AnyConst32(value.to_int()))
  } else {
    None
  }
}

///|
/// Upstream `TryFrom<i64> for AnyConst32`.
pub fn AnyConst32::try_from_i64(value : Int64) -> AnyConst32? {
  if value >= -2147483648L && value <= 2147483647L {
    Some(AnyConst32(value.to_int()))
  } else {
    None
  }
}

///|
/// Upstream `TryFrom<f64> for AnyConst32`: succeeds if the `f64` value is
/// losslessly representable as `f32` (bit-wise roundtrip).
pub fn AnyConst32::try_from_f64_bits(bits : UInt64) -> AnyConst32? {
  let value = bits.reinterpret_as_double()
  let truncated = Float::from_double(value)
  if bits != truncated.to_double().reinterpret_as_uint64() {
    return None
  }
  Some(AnyConst32(truncated.reinterpret_as_int()))
}

///|
/// Upstream `From<AnyConst32> for i32`.
pub fn AnyConst32::to_i32(self : AnyConst32) -> Int {
  self.0
}

///|
/// Upstream `From<AnyConst32> for u32`.
pub fn AnyConst32::to_u32(self : AnyConst32) -> UInt {
  self.0.reinterpret_as_uint()
}

///|
/// Upstream `From<AnyConst32> for i64` (sign extension of the `i32`).
pub fn AnyConst32::to_i64(self : AnyConst32) -> Int64 {
  self.0.to_int64()
}

///|
/// Upstream `From<AnyConst32> for u64` (zero extension of the `u32`).
pub fn AnyConst32::to_u64(self : AnyConst32) -> UInt64 {
  self.0.reinterpret_as_uint().to_uint64()
}

///|
/// Upstream `From<AnyConst32> for f32` (as bits).
pub fn AnyConst32::to_f32_bits(self : AnyConst32) -> UInt {
  self.0.reinterpret_as_uint()
}

///|
/// Upstream `From<AnyConst32> for f64` (the `f32` widened; as bits).
pub fn AnyConst32::to_f64_bits(self : AnyConst32) -> UInt64 {
  Float::reinterpret_from_int(self.0).to_double().reinterpret_as_uint64()
}

///|
/// Upstream `Const32<u64>::cast(Const32<u32>)`.
pub fn Const32::cast(self : Const32) -> Const32 {
  self
}

///|
/// Upstream `From<i32> for Const32<i32>` / `Const32<i64>`.
pub fn Const32::from_i32(value : Int) -> Const32 {
  Const32(value)
}

///|
/// Upstream `From<u32> for Const32<u32>` / `Const32<u64>`.
pub fn Const32::from_u32(value : UInt) -> Const32 {
  Const32(value.reinterpret_as_int())
}

///|
/// Upstream `From<f32> for Const32<f32>` / `Const32<f64>` (given as bits).
pub fn Const32::from_f32_bits(bits : UInt) -> Const32 {
  Const32(bits.reinterpret_as_int())
}

///|
/// Upstream `TryFrom<i64> for Const32<i64>`.
pub fn Const32::try_from_i64(value : Int64) -> Const32? {
  match AnyConst32::try_from_i64(value) {
    Some(c) => Some(Const32(c.0))
    None => None
  }
}

///|
/// Upstream `TryFrom<u64> for Const32<u64>`.
pub fn Const32::try_from_u64(value : UInt64) -> Const32? {
  match AnyConst32::try_from_u64(value) {
    Some(c) => Some(Const32(c.0))
    None => None
  }
}

///|
/// Upstream `TryFrom<f64> for Const32<f64>` (given as bits).
pub fn Const32::try_from_f64_bits(bits : UInt64) -> Const32? {
  match AnyConst32::try_from_f64_bits(bits) {
    Some(c) => Some(Const32(c.0))
    None => None
  }
}

///|
/// Upstream `From<Const32<i32>> for i32`.
pub fn Const32::to_i32(self : Const32) -> Int {
  self.0
}

///|
/// Upstream `From<Const32<u32>> for u32`.
pub fn Const32::to_u32(self : Const32) -> UInt {
  self.0.reinterpret_as_uint()
}

///|
/// Upstream `From<Const32<i64>> for i64`.
pub fn Const32::to_i64(self : Const32) -> Int64 {
  self.0.to_int64()
}

///|
/// Upstream `From<Const32<u64>> for u64`.
pub fn Const32::to_u64(self : Const32) -> UInt64 {
  self.0.reinterpret_as_uint().to_uint64()
}

///|
/// Upstream `From<Const32<f32>> for f32` (as bits).
pub fn Const32::to_f32_bits(self : Const32) -> UInt {
  self.0.reinterpret_as_uint()
}

///|
/// Upstream `From<Const32<f64>> for f64` (as bits).
pub fn Const32::to_f64_bits(self : Const32) -> UInt64 {
  Float::reinterpret_from_int(self.0).to_double().reinterpret_as_uint64()
}
