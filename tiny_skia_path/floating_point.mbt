// Port of `tiny-skia-path` 0.12.0 `src/floating_point.rs`.
//
// `FiniteF32`, `NonZeroPositiveF32` and `NormalizedF32` come from
// `strict_num.mbt`. The `SaturateCast`/`SaturateRound` traits on `i32` are
// plain functions (`i32_saturate_from`, `i32_saturate_floor`, ...).

///|
let float_pi : Float = Float::reinterpret_from_uint(0x40490FDB) // 3.14159265

///|
let max_i32_fits_in_f32 : Float = 2147483520.0

///|
let min_i32_fits_in_f32 : Float = -2147483520.0

///|
/// `i32::saturate_from(f32)`: return the closest integer for the given float.
///
/// Returns MAX_I32_FITS_IN_F32 for NaN.
pub fn i32_saturate_from(x : Float) -> Int {
  let x = if x < max_i32_fits_in_f32 { x } else { max_i32_fits_in_f32 }
  let x = if x > min_i32_fits_in_f32 { x } else { min_i32_fits_in_f32 }
  f32_as_i32(x)
}

///|
/// `i32::saturate_from(f64)`: return the closest integer for the given double.
///
/// Returns i32::MAX for NaN.
pub fn i32_saturate_from_f64(x : Double) -> Int {
  let x = if x < 2147483647.0 { x } else { 2147483647.0 }
  let x = if x > -2147483648.0 { x } else { -2147483648.0 }
  f64_as_i32(x)
}

///|
pub fn i32_saturate_floor(x : Float) -> Int {
  i32_saturate_from(x.floor())
}

///|
pub fn i32_saturate_ceil(x : Float) -> Int {
  i32_saturate_from(x.ceil())
}

///|
pub fn i32_saturate_round(x : Float) -> Int {
  i32_saturate_from(x.floor() + 0.5)
}

///|
/// Return the float as a 2s compliment int. Just to be used to compare floats
/// to each other or against positive float-bit-constants (like 0). This does
/// not return the int equivalent of the float, just something cheaper for
/// compares-only.
fn f32_as_2s_compliment(x : Float) -> Int {
  sign_bit_to_2s_compliment(x.reinterpret_as_int())
}

///|
/// Convert a sign-bit int (i.e. float interpreted as int) into a 2s compliement
/// int. This also converts -0 (0x80000000) to 0. Doing this to a float allows
/// it to be compared using normal C operators (<, <=, etc.)
fn sign_bit_to_2s_compliment(x : Int) -> Int {
  if x < 0 {
    -(x & 0x7FFFFFFF)
  } else {
    x
  }
}

///|
/// An immutable `f32` that is larger than 0 but less then 1.
pub struct NormalizedF32Exclusive(FiniteF32) derive (
  Debug,
  Default,
  Eq,
  Compare,
  Hash,
)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedF32Exclusive with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedF32Exclusive with Default::{default}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedF32Exclusive with Eq::{not_equal, equal}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedF32Exclusive with Compare::{
  op_lt,
  op_le,
  op_ge,
  compare,
  op_gt,
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend NormalizedF32Exclusive with Hash::{hash, hash_combine}

///|
/// A predefined 0.5 value.
pub fn NormalizedF32Exclusive::half() -> NormalizedF32Exclusive {
  NormalizedF32Exclusive(FiniteF32(0.5))
}

///|
/// Just a random, valid number.
pub fn NormalizedF32Exclusive::any() -> NormalizedF32Exclusive {
  NormalizedF32Exclusive::half()
}

///|
/// Creates a `NormalizedF32Exclusive`.
pub fn NormalizedF32Exclusive::new(n : Float) -> NormalizedF32Exclusive? {
  if n > 0.0 && n < 1.0 {
    // `n` is guarantee to be finite after the bounds check.
    match FiniteF32::new(n) {
      Some(f) => Some(NormalizedF32Exclusive(f))
      None => None
    }
  } else {
    None
  }
}

///|
/// Creates a `NormalizedF32Exclusive` clamping the given value.
///
/// Returns zero in case of NaN or infinity.
pub fn NormalizedF32Exclusive::new_bounded(n : Float) -> NormalizedF32Exclusive {
  let eps = Float::reinterpret_from_uint(0x34000000) // f32::EPSILON
  let n = bound(n, eps, 1.0 - eps)
  // `n` is guarantee to be finite after clamping.
  NormalizedF32Exclusive(FiniteF32(n))
}

///|
/// Returns the value as a primitive type.
pub fn NormalizedF32Exclusive::get(self : NormalizedF32Exclusive) -> Float {
  self.0.get()
}

///|
/// Returns the value as a `NormalizedF32`.
pub fn NormalizedF32Exclusive::to_normalized(
  self : NormalizedF32Exclusive,
) -> NormalizedF32 {
  // NormalizedF32 is (0,1), while NormalizedF32 is [0,1], so it will always fit.
  NormalizedF32::new_unchecked(self.0.get())
}
