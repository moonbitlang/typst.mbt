// Port of `wasmi_core/src/typed.rs`.
//
// The `Typed` trait (`T::TY`) and the `From<T> for TypedVal` /
// `From<TypedVal> for T` impls become per-type constructors and accessors.

///|
/// An [`UntypedVal`] with its assumed [`ValType`].
///
/// # Note
///
/// We explicitly do not make use of the existing [`Val`]
/// abstraction since [`Val`] is optimized towards being a
/// user facing type whereas [`TypedVal`] is focusing on
/// performance and efficiency in computations.
pub struct TypedVal {
  /// The type of the value.
  ty : ValType
  /// The underlying raw value.
  value : UntypedVal
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TypedVal with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TypedVal with @debug.Debug::{to_repr}

///|
/// Create a new [`TypedVal`].
pub fn TypedVal::new(ty : ValType, value : UntypedVal) -> TypedVal {
  { ty, value, }
}

///|
/// Returns the [`ValType`] of the [`TypedVal`].
pub fn TypedVal::ty(self : TypedVal) -> ValType {
  self.ty
}

///|
/// Returns the [`UntypedVal`] of the [`TypedVal`].
pub fn TypedVal::untyped(self : TypedVal) -> UntypedVal {
  self.value
}

///|
/// `From<bool>` (`ValType::I32`).
pub fn TypedVal::from_bool(value : Bool) -> TypedVal {
  TypedVal::new(I32, UntypedVal::from_bool(value))
}

///|
/// `From<i32>` (`ValType::I32`).
pub fn TypedVal::from_i32(value : Int) -> TypedVal {
  TypedVal::new(I32, UntypedVal::from_i32(value))
}

///|
/// `From<u32>` (`ValType::I32`).
pub fn TypedVal::from_u32(value : UInt) -> TypedVal {
  TypedVal::new(I32, UntypedVal::from_u32(value))
}

///|
/// `From<i64>` (`ValType::I64`).
pub fn TypedVal::from_i64(value : Int64) -> TypedVal {
  TypedVal::new(I64, UntypedVal::from_i64(value))
}

///|
/// `From<u64>` (`ValType::I64`).
pub fn TypedVal::from_u64(value : UInt64) -> TypedVal {
  TypedVal::new(I64, UntypedVal::from_u64(value))
}

///|
/// `From<f32>` (`ValType::F32`).
pub fn TypedVal::from_f32(value : Float) -> TypedVal {
  TypedVal::new(F32, UntypedVal::from_f32(value))
}

///|
/// `From<f64>` (`ValType::F64`).
pub fn TypedVal::from_f64(value : Double) -> TypedVal {
  TypedVal::new(F64, UntypedVal::from_f64(value))
}

///|
/// `From<V128>` (`ValType::V128`).
pub fn TypedVal::from_v128(value : V128Value) -> TypedVal {
  TypedVal::new(V128, UntypedVal::from_v128(value))
}

///|
/// `From<TypedVal> for bool`
pub fn TypedVal::to_bool(self : TypedVal) -> Bool {
  self.value.read_bool()
}

///|
/// `From<TypedVal> for i32`
pub fn TypedVal::to_i32(self : TypedVal) -> Int {
  self.value.read_i32()
}

///|
/// `From<TypedVal> for u32`
pub fn TypedVal::to_u32(self : TypedVal) -> UInt {
  self.value.read_u32()
}

///|
/// `From<TypedVal> for i64`
pub fn TypedVal::to_i64(self : TypedVal) -> Int64 {
  self.value.read_i64()
}

///|
/// `From<TypedVal> for u64`
pub fn TypedVal::to_u64(self : TypedVal) -> UInt64 {
  self.value.read_u64()
}

///|
/// `From<TypedVal> for f32`
pub fn TypedVal::to_f32(self : TypedVal) -> Float {
  self.value.read_f32()
}

///|
/// `From<TypedVal> for f64`
pub fn TypedVal::to_f64(self : TypedVal) -> Double {
  self.value.read_f64()
}

///|
/// `From<TypedVal> for V128`
pub fn TypedVal::to_v128(self : TypedVal) -> V128Value {
  self.value.read_v128()
}
