// Port of `wasmi_core/src/wasm.rs`: execution helpers for Wasm or Wasmi
// instructions.
//
// Types: `i32` -> `Int`, `u32` -> `UInt`, `i64` -> `Int64`, `u64` ->
// `UInt64`, `f32` -> `Float`, `f64` -> `Double`. `Result<T, TrapCode>` ->
// `T raise TrapCode`. Memory slices are `(memory, memory_len)` pairs (see
// `memory_access.mbt`).

// Wasm Integer Instructions

///|
/// Execute the `i32_add` Wasm instruction.
pub fn i32_add(lhs : Int, rhs : Int) -> Int {
  lhs + rhs
}

///|
/// Execute the `i64_add` Wasm instruction.
pub fn i64_add(lhs : Int64, rhs : Int64) -> Int64 {
  lhs + rhs
}

///|
/// Execute the `i32_sub` Wasm instruction.
pub fn i32_sub(lhs : Int, rhs : Int) -> Int {
  lhs - rhs
}

///|
/// Execute the `i64_sub` Wasm instruction.
pub fn i64_sub(lhs : Int64, rhs : Int64) -> Int64 {
  lhs - rhs
}

///|
/// Execute the `i32_mul` Wasm instruction.
pub fn i32_mul(lhs : Int, rhs : Int) -> Int {
  lhs * rhs
}

///|
/// Execute the `i64_mul` Wasm instruction.
pub fn i64_mul(lhs : Int64, rhs : Int64) -> Int64 {
  lhs * rhs
}

///|
/// Execute the `i32_bitand` Wasm instruction.
pub fn i32_bitand(lhs : Int, rhs : Int) -> Int {
  lhs & rhs
}

///|
/// Execute the `i64_bitand` Wasm instruction.
pub fn i64_bitand(lhs : Int64, rhs : Int64) -> Int64 {
  lhs & rhs
}

///|
/// Execute the `i32_bitor` Wasm instruction.
pub fn i32_bitor(lhs : Int, rhs : Int) -> Int {
  lhs | rhs
}

///|
/// Execute the `i64_bitor` Wasm instruction.
pub fn i64_bitor(lhs : Int64, rhs : Int64) -> Int64 {
  lhs | rhs
}

///|
/// Execute the `i32_bitxor` Wasm instruction.
pub fn i32_bitxor(lhs : Int, rhs : Int) -> Int {
  lhs ^ rhs
}

///|
/// Execute the `i64_bitxor` Wasm instruction.
pub fn i64_bitxor(lhs : Int64, rhs : Int64) -> Int64 {
  lhs ^ rhs
}

///|
/// Execute the `i32_shl` Wasm instruction.
pub fn i32_shl(lhs : Int, rhs : Int) -> Int {
  lhs << (rhs & 31)
}

///|
/// Execute the `i64_shl` Wasm instruction.
pub fn i64_shl(lhs : Int64, rhs : Int64) -> Int64 {
  lhs << (rhs.to_int() & 63)
}

///|
/// Execute the `i32_shr_s` Wasm instruction.
pub fn i32_shr_s(lhs : Int, rhs : Int) -> Int {
  lhs >> (rhs & 31)
}

///|
/// Execute the `i64_shr_s` Wasm instruction.
pub fn i64_shr_s(lhs : Int64, rhs : Int64) -> Int64 {
  lhs >> (rhs.to_int() & 63)
}

///|
/// Execute the `i32_shr_u` Wasm instruction.
pub fn i32_shr_u(lhs : Int, rhs : Int) -> Int {
  (lhs.reinterpret_as_uint() >> (rhs & 31)).reinterpret_as_int()
}

///|
/// Execute the `i64_shr_u` Wasm instruction.
pub fn i64_shr_u(lhs : Int64, rhs : Int64) -> Int64 {
  (lhs.reinterpret_as_uint64() >> (rhs.to_int() & 63)).reinterpret_as_int64()
}

///|
/// Execute the `i32_rotl` Wasm instruction.
pub fn i32_rotl(lhs : Int, rhs : Int) -> Int {
  let n = rhs & 31
  if n == 0 {
    return lhs
  }
  let x = lhs.reinterpret_as_uint()
  ((x << n) | (x >> (32 - n))).reinterpret_as_int()
}

///|
/// Execute the `i64_rotl` Wasm instruction.
pub fn i64_rotl(lhs : Int64, rhs : Int64) -> Int64 {
  let n = rhs.to_int() & 63
  if n == 0 {
    return lhs
  }
  let x = lhs.reinterpret_as_uint64()
  ((x << n) | (x >> (64 - n))).reinterpret_as_int64()
}

///|
/// Execute the `i32_rotr` Wasm instruction.
pub fn i32_rotr(lhs : Int, rhs : Int) -> Int {
  let n = rhs & 31
  if n == 0 {
    return lhs
  }
  let x = lhs.reinterpret_as_uint()
  ((x >> n) | (x << (32 - n))).reinterpret_as_int()
}

///|
/// Execute the `i64_rotr` Wasm instruction.
pub fn i64_rotr(lhs : Int64, rhs : Int64) -> Int64 {
  let n = rhs.to_int() & 63
  if n == 0 {
    return lhs
  }
  let x = lhs.reinterpret_as_uint64()
  ((x >> n) | (x << (64 - n))).reinterpret_as_int64()
}

// Wasm Integer Division and Remainder Instructions

///|
/// Execute the fallible `i32_div_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
/// - [`TrapCode::IntegerOverflow`]: if `lhs` is [`i32::MIN`] and `rhs` is `-1`.
pub fn i32_div_s(lhs : Int, rhs : Int) -> Int raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  if lhs == -2147483648 && rhs == -1 {
    raise IntegerOverflow
  }
  lhs / rhs
}

///|
/// Execute the fallible `i64_div_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
/// - [`TrapCode::IntegerOverflow`]: if `lhs` is [`i32::MIN`] and `rhs` is `-1`.
pub fn i64_div_s(lhs : Int64, rhs : Int64) -> Int64 raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  if lhs == -9223372036854775808L && rhs == -1 {
    raise IntegerOverflow
  }
  lhs / rhs
}

///|
/// Execute the fallible `i32_div_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
pub fn i32_div_u(lhs : UInt, rhs : UInt) -> UInt raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  lhs / rhs
}

///|
/// Execute the fallible `i64_div_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
pub fn i64_div_u(lhs : UInt64, rhs : UInt64) -> UInt64 raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  lhs / rhs
}

///|
/// Execute the fallible `i32_rem_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
pub fn i32_rem_s(lhs : Int, rhs : Int) -> Int raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  // `wrapping_rem`
  if rhs == -1 {
    return 0
  }
  lhs % rhs
}

///|
/// Execute the fallible `i64_rem_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
pub fn i64_rem_s(lhs : Int64, rhs : Int64) -> Int64 raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  // `wrapping_rem`
  if rhs == -1 {
    return 0
  }
  lhs % rhs
}

///|
/// Execute the fallible `i32_rem_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
pub fn i32_rem_u(lhs : UInt, rhs : UInt) -> UInt raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  lhs % rhs
}

///|
/// Execute the fallible `i64_rem_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::IntegerDivisionByZero`]: if `rhs` is zero.
pub fn i64_rem_u(lhs : UInt64, rhs : UInt64) -> UInt64 raise TrapCode {
  if rhs == 0 {
    raise IntegerDivisionByZero
  }
  lhs % rhs
}

// Wasm Unary Instructions

///|
/// Execute the `i32_clz` Wasm instruction.
pub fn i32_clz(value : Int) -> Int {
  value.clz()
}

///|
/// Execute the `i64_clz` Wasm instruction.
pub fn i64_clz(value : Int64) -> Int64 {
  value.clz().to_int64()
}

///|
/// Execute the `i32_ctz` Wasm instruction.
pub fn i32_ctz(value : Int) -> Int {
  value.ctz()
}

///|
/// Execute the `i64_ctz` Wasm instruction.
pub fn i64_ctz(value : Int64) -> Int64 {
  value.ctz().to_int64()
}

///|
/// Execute the `i32_popcnt` Wasm instruction.
pub fn i32_popcnt(value : Int) -> Int {
  value.popcnt()
}

///|
/// Execute the `i64_popcnt` Wasm instruction.
pub fn i64_popcnt(value : Int64) -> Int64 {
  value.popcnt().to_int64()
}

///|
/// Execute the `i32_eqz` Wasm instruction.
pub fn i32_eqz(value : Int) -> Bool {
  value == 0
}

///|
/// Execute the `i64_eqz` Wasm instruction.
pub fn i64_eqz(value : Int64) -> Bool {
  value == 0
}

// Wasm Comparison Instructions

///|
/// Execute the `i32_eq` Wasm instruction.
pub fn i32_eq(lhs : Int, rhs : Int) -> Bool {
  lhs == rhs
}

///|
/// Execute the `i64_eq` Wasm instruction.
pub fn i64_eq(lhs : Int64, rhs : Int64) -> Bool {
  lhs == rhs
}

///|
/// Execute the `f32_eq` Wasm instruction.
pub fn f32_eq(lhs : Float, rhs : Float) -> Bool {
  lhs == rhs
}

///|
/// Execute the `f64_eq` Wasm instruction.
pub fn f64_eq(lhs : Double, rhs : Double) -> Bool {
  lhs == rhs
}

///|
/// Execute the `i32_ne` Wasm instruction.
pub fn i32_ne(lhs : Int, rhs : Int) -> Bool {
  lhs != rhs
}

///|
/// Execute the `i64_ne` Wasm instruction.
pub fn i64_ne(lhs : Int64, rhs : Int64) -> Bool {
  lhs != rhs
}

///|
/// Execute the `f32_ne` Wasm instruction.
pub fn f32_ne(lhs : Float, rhs : Float) -> Bool {
  lhs != rhs
}

///|
/// Execute the `f64_ne` Wasm instruction.
pub fn f64_ne(lhs : Double, rhs : Double) -> Bool {
  lhs != rhs
}

///|
/// Execute the `i32_lt_s` Wasm instruction.
pub fn i32_lt_s(lhs : Int, rhs : Int) -> Bool {
  lhs < rhs
}

///|
/// Execute the `i64_lt_s` Wasm instruction.
pub fn i64_lt_s(lhs : Int64, rhs : Int64) -> Bool {
  lhs < rhs
}

///|
/// Execute the `i32_lt_u` Wasm instruction.
pub fn i32_lt_u(lhs : UInt, rhs : UInt) -> Bool {
  lhs < rhs
}

///|
/// Execute the `i64_lt_u` Wasm instruction.
pub fn i64_lt_u(lhs : UInt64, rhs : UInt64) -> Bool {
  lhs < rhs
}

///|
/// Execute the `f32_lt` Wasm instruction.
pub fn f32_lt(lhs : Float, rhs : Float) -> Bool {
  lhs < rhs
}

///|
/// Execute the `f64_lt` Wasm instruction.
pub fn f64_lt(lhs : Double, rhs : Double) -> Bool {
  lhs < rhs
}

///|
/// Execute the `i32_le_s` Wasm instruction.
pub fn i32_le_s(lhs : Int, rhs : Int) -> Bool {
  lhs <= rhs
}

///|
/// Execute the `i64_le_s` Wasm instruction.
pub fn i64_le_s(lhs : Int64, rhs : Int64) -> Bool {
  lhs <= rhs
}

///|
/// Execute the `i32_le_u` Wasm instruction.
pub fn i32_le_u(lhs : UInt, rhs : UInt) -> Bool {
  lhs <= rhs
}

///|
/// Execute the `i64_le_u` Wasm instruction.
pub fn i64_le_u(lhs : UInt64, rhs : UInt64) -> Bool {
  lhs <= rhs
}

///|
/// Execute the `f32_le` Wasm instruction.
pub fn f32_le(lhs : Float, rhs : Float) -> Bool {
  lhs <= rhs
}

///|
/// Execute the `f64_le` Wasm instruction.
pub fn f64_le(lhs : Double, rhs : Double) -> Bool {
  lhs <= rhs
}

///|
/// Execute the `i32_gt_s` Wasm instruction.
pub fn i32_gt_s(lhs : Int, rhs : Int) -> Bool {
  lhs > rhs
}

///|
/// Execute the `i64_gt_s` Wasm instruction.
pub fn i64_gt_s(lhs : Int64, rhs : Int64) -> Bool {
  lhs > rhs
}

///|
/// Execute the `i32_gt_u` Wasm instruction.
pub fn i32_gt_u(lhs : UInt, rhs : UInt) -> Bool {
  lhs > rhs
}

///|
/// Execute the `i64_gt_u` Wasm instruction.
pub fn i64_gt_u(lhs : UInt64, rhs : UInt64) -> Bool {
  lhs > rhs
}

///|
/// Execute the `f32_gt` Wasm instruction.
pub fn f32_gt(lhs : Float, rhs : Float) -> Bool {
  lhs > rhs
}

///|
/// Execute the `f64_gt` Wasm instruction.
pub fn f64_gt(lhs : Double, rhs : Double) -> Bool {
  lhs > rhs
}

///|
/// Execute the `i32_ge_s` Wasm instruction.
pub fn i32_ge_s(lhs : Int, rhs : Int) -> Bool {
  lhs >= rhs
}

///|
/// Execute the `i64_ge_s` Wasm instruction.
pub fn i64_ge_s(lhs : Int64, rhs : Int64) -> Bool {
  lhs >= rhs
}

///|
/// Execute the `i32_ge_u` Wasm instruction.
pub fn i32_ge_u(lhs : UInt, rhs : UInt) -> Bool {
  lhs >= rhs
}

///|
/// Execute the `i64_ge_u` Wasm instruction.
pub fn i64_ge_u(lhs : UInt64, rhs : UInt64) -> Bool {
  lhs >= rhs
}

///|
/// Execute the `f32_ge` Wasm instruction.
pub fn f32_ge(lhs : Float, rhs : Float) -> Bool {
  lhs >= rhs
}

///|
/// Execute the `f64_ge` Wasm instruction.
pub fn f64_ge(lhs : Double, rhs : Double) -> Bool {
  lhs >= rhs
}

// Wasm Float Instructions

///|
/// Execute the `f32_abs` Wasm instruction.
pub fn f32_abs(value : Float) -> Float {
  libm_fabsf(value)
}

///|
/// Execute the `f64_abs` Wasm instruction.
pub fn f64_abs(value : Double) -> Double {
  libm_fabs(value)
}

///|
/// Execute the `f32_neg` Wasm instruction.
pub fn f32_neg(value : Float) -> Float {
  f32_hw_neg(value)
}

///|
/// Execute the `f64_neg` Wasm instruction.
pub fn f64_neg(value : Double) -> Double {
  f64_hw_neg(value)
}

///|
/// Execute the `f32_ceil` Wasm instruction.
pub fn f32_ceil(value : Float) -> Float {
  libm_ceilf(value)
}

///|
/// Execute the `f64_ceil` Wasm instruction.
pub fn f64_ceil(value : Double) -> Double {
  libm_ceil(value)
}

///|
/// Execute the `f32_floor` Wasm instruction.
pub fn f32_floor(value : Float) -> Float {
  libm_floorf(value)
}

///|
/// Execute the `f64_floor` Wasm instruction.
pub fn f64_floor(value : Double) -> Double {
  libm_floor(value)
}

///|
/// Execute the `f32_trunc` Wasm instruction.
pub fn f32_trunc(value : Float) -> Float {
  libm_truncf(value)
}

///|
/// Execute the `f64_trunc` Wasm instruction.
pub fn f64_trunc(value : Double) -> Double {
  libm_trunc(value)
}

///|
/// Execute the `f32_nearest` Wasm instruction.
pub fn f32_nearest(value : Float) -> Float {
  libm_nearestf(value)
}

///|
/// Execute the `f64_nearest` Wasm instruction.
pub fn f64_nearest(value : Double) -> Double {
  libm_nearest(value)
}

///|
/// Execute the `f32_sqrt` Wasm instruction.
pub fn f32_sqrt(value : Float) -> Float {
  libm_sqrtf(value)
}

///|
/// Execute the `f64_sqrt` Wasm instruction.
pub fn f64_sqrt(value : Double) -> Double {
  libm_sqrt(value)
}

///|
/// Execute the `f32_add` Wasm instruction.
pub fn f32_add(lhs : Float, rhs : Float) -> Float {
  f32_hw_add(lhs, rhs)
}

///|
/// Execute the `f64_add` Wasm instruction.
pub fn f64_add(lhs : Double, rhs : Double) -> Double {
  f64_hw_add(lhs, rhs)
}

///|
/// Execute the `f32_sub` Wasm instruction.
pub fn f32_sub(lhs : Float, rhs : Float) -> Float {
  let r = lhs - rhs
  if r != r {
    f32_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Execute the `f64_sub` Wasm instruction.
pub fn f64_sub(lhs : Double, rhs : Double) -> Double {
  let r = lhs - rhs
  if r != r {
    f64_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Execute the `f32_mul` Wasm instruction.
pub fn f32_mul(lhs : Float, rhs : Float) -> Float {
  let r = lhs * rhs
  if r != r {
    f32_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Execute the `f64_mul` Wasm instruction.
pub fn f64_mul(lhs : Double, rhs : Double) -> Double {
  let r = lhs * rhs
  if r != r {
    f64_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Execute the `f32_div` Wasm instruction.
pub fn f32_div(lhs : Float, rhs : Float) -> Float {
  let r = lhs / rhs
  if r != r {
    f32_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Execute the `f64_div` Wasm instruction.
pub fn f64_div(lhs : Double, rhs : Double) -> Double {
  let r = lhs / rhs
  if r != r {
    f64_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Execute the `f32_min` Wasm instruction.
pub fn f32_min(lhs : Float, rhs : Float) -> Float {
  // Note: equal to the unstable `f32::minimum` method.
  if lhs < rhs {
    lhs
  } else if rhs < lhs {
    rhs
  } else if lhs == rhs {
    if lhs.reinterpret_as_uint() >> 31 != 0 &&
      rhs.reinterpret_as_uint() >> 31 == 0 {
      lhs
    } else {
      rhs
    }
  } else {
    // At least one input is NaN. Use `+` to perform NaN propagation and quieting.
    f32_hw_add(lhs, rhs)
  }
}

///|
/// Execute the `f64_min` Wasm instruction.
pub fn f64_min(lhs : Double, rhs : Double) -> Double {
  // Note: equal to the unstable `f64::minimum` method.
  if lhs < rhs {
    lhs
  } else if rhs < lhs {
    rhs
  } else if lhs == rhs {
    if lhs.reinterpret_as_uint64() >> 63 != 0 &&
      rhs.reinterpret_as_uint64() >> 63 == 0 {
      lhs
    } else {
      rhs
    }
  } else {
    // At least one input is NaN. Use `+` to perform NaN propagation and quieting.
    f64_hw_add(lhs, rhs)
  }
}

///|
/// Execute the `f32_max` Wasm instruction.
pub fn f32_max(lhs : Float, rhs : Float) -> Float {
  // Note: equal to the unstable `f32::maximum` method.
  if lhs > rhs {
    lhs
  } else if rhs > lhs {
    rhs
  } else if lhs == rhs {
    if lhs.reinterpret_as_uint() >> 31 == 0 &&
      rhs.reinterpret_as_uint() >> 31 != 0 {
      lhs
    } else {
      rhs
    }
  } else {
    // At least one input is NaN. Use `+` to perform NaN propagation and quieting.
    f32_hw_add(lhs, rhs)
  }
}

///|
/// Execute the `f64_max` Wasm instruction.
pub fn f64_max(lhs : Double, rhs : Double) -> Double {
  // Note: equal to the unstable `f64::maximum` method.
  if lhs > rhs {
    lhs
  } else if rhs > lhs {
    rhs
  } else if lhs == rhs {
    if lhs.reinterpret_as_uint64() >> 63 == 0 &&
      rhs.reinterpret_as_uint64() >> 63 != 0 {
      lhs
    } else {
      rhs
    }
  } else {
    // At least one input is NaN. Use `+` to perform NaN propagation and quieting.
    f64_hw_add(lhs, rhs)
  }
}

///|
/// Execute the `f32_copysign` Wasm instruction.
pub fn f32_copysign(lhs : Float, rhs : Float) -> Float {
  libm_copysignf(lhs, rhs)
}

///|
/// Execute the `f64_copysign` Wasm instruction.
pub fn f64_copysign(lhs : Double, rhs : Double) -> Double {
  libm_copysign(lhs, rhs)
}

// Wasm Conversion Routines

///|
/// Execute the `i32_wrap_i64` Wasm instruction.
pub fn i32_wrap_i64(value : Int64) -> Int {
  value.to_int()
}

///|
/// Execute the `i64_extend_i32_s` Wasm instruction.
pub fn i64_extend_i32_s(value : Int) -> Int64 {
  value.to_int64()
}

///|
/// Execute the `i64_extend_i32_u` Wasm instruction.
pub fn i64_extend_i32_u(value : UInt) -> UInt64 {
  value.to_uint64()
}

///|
/// Execute the `f32_demote_f64` Wasm instruction.
pub fn f32_demote_f64(value : Double) -> Float {
  if value != value {
    // `fcvt`: quiet the NaN, keep its sign and the upper payload bits.
    let bits = value.reinterpret_as_uint64()
    let sign = (bits >> 32).to_uint() & 0x8000_0000
    let payload = (bits >> 29).to_uint() & 0x003F_FFFF
    return Float::reinterpret_from_uint(sign | 0x7FC0_0000 | payload)
  }
  Float::from_double(value)
}

///|
/// Execute the `f64_promote_f32` Wasm instruction.
pub fn f64_promote_f32(value : Float) -> Double {
  if value != value {
    // `fcvt`: quiet the NaN, keep its sign and payload.
    let bits = value.reinterpret_as_uint()
    let sign = (bits & 0x8000_0000).to_uint64() << 32
    let payload = (bits & 0x003F_FFFF).to_uint64() << 29
    return (sign | 0x7FF8_0000_0000_0000 | payload).reinterpret_as_double()
  }
  value.to_double()
}

///|
/// Truncates the finite `value` with `-1 < value < 2^64` to an `u64`.
fn f64_to_u64_in_range(value : Double) -> UInt64 {
  if value >= 9223372036854775808.0 {
    (value - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
    0x8000_0000_0000_0000
  } else {
    value.to_int64().reinterpret_as_uint64()
  }
}

///|
/// Execute the `i32_trunc_f32_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `i32` value
pub fn i32_trunc_f32_s(value : Float) -> Int raise TrapCode {
  i32_trunc_f64_s(value.to_double())
}

///|
/// Execute the `i64_trunc_f32_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `i64` value
pub fn i64_trunc_f32_s(value : Float) -> Int64 raise TrapCode {
  if value != value {
    raise BadConversionToInteger
  }
  let v = value.to_double()
  if v <= -9223373136366403584.0 || v >= 9223372036854775808.0 {
    raise IntegerOverflow
  }
  v.to_int64()
}

///|
/// Execute the `i32_trunc_f32_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `u32` value
pub fn i32_trunc_f32_u(value : Float) -> UInt raise TrapCode {
  i32_trunc_f64_u(value.to_double())
}

///|
/// Execute the `i64_trunc_f32_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `u64` value
pub fn i64_trunc_f32_u(value : Float) -> UInt64 raise TrapCode {
  i64_trunc_f64_u(value.to_double())
}

///|
/// Execute the `i32_trunc_f64_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `i32` value
pub fn i32_trunc_f64_s(value : Double) -> Int raise TrapCode {
  if value != value {
    raise BadConversionToInteger
  }
  // Note: the `f32` bounds (-2147483904, 2147483648) are equivalent for `f32`
  // inputs since no `f32` lies strictly between -2147483904 and -2147483649.
  if value <= -2147483649.0 || value >= 2147483648.0 {
    raise IntegerOverflow
  }
  value.to_int()
}

///|
/// Execute the `i64_trunc_f64_s` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `i64` value
pub fn i64_trunc_f64_s(value : Double) -> Int64 raise TrapCode {
  if value != value {
    raise BadConversionToInteger
  }
  if value <= -9223372036854777856.0 || value >= 9223372036854775808.0 {
    raise IntegerOverflow
  }
  value.to_int64()
}

///|
/// Execute the `i32_trunc_f64_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `u32` value
pub fn i32_trunc_f64_u(value : Double) -> UInt raise TrapCode {
  if value != value {
    raise BadConversionToInteger
  }
  if value <= -1.0 || value >= 4294967296.0 {
    raise IntegerOverflow
  }
  value.to_int64().reinterpret_as_uint64().to_uint()
}

///|
/// Execute the `i64_trunc_f64_u` Wasm instruction.
///
/// # Errors
///
/// - [`TrapCode::BadConversionToInteger`]: if `value` is NaN
/// - [`TrapCode::IntegerOverflow`]: if `value` exceeds the bounds of an `u64` value
pub fn i64_trunc_f64_u(value : Double) -> UInt64 raise TrapCode {
  if value != value {
    raise BadConversionToInteger
  }
  if value <= -1.0 || value >= 18446744073709551616.0 {
    raise IntegerOverflow
  }
  f64_to_u64_in_range(value)
}

///|
/// Execute the `f32_convert_i32_s` Wasm instruction.
pub fn f32_convert_i32_s(value : Int) -> Float {
  Float::from_int(value)
}

///|
/// Execute the `f32_convert_i32_u` Wasm instruction.
pub fn f32_convert_i32_u(value : UInt) -> Float {
  Float::from_uint(value)
}

///|
/// Execute the `f32_convert_i64_s` Wasm instruction.
pub fn f32_convert_i64_s(value : Int64) -> Float {
  Float::from_int64(value)
}

///|
/// Execute the `f32_convert_i64_u` Wasm instruction.
pub fn f32_convert_i64_u(value : UInt64) -> Float {
  Float::from_uint64(value)
}

///|
/// Execute the `f64_convert_i32_s` Wasm instruction.
pub fn f64_convert_i32_s(value : Int) -> Double {
  value.to_double()
}

///|
/// Execute the `f64_convert_i32_u` Wasm instruction.
pub fn f64_convert_i32_u(value : UInt) -> Double {
  value.to_double()
}

///|
/// Execute the `f64_convert_i64_s` Wasm instruction.
pub fn f64_convert_i64_s(value : Int64) -> Double {
  value.to_double()
}

///|
/// Execute the `f64_convert_i64_u` Wasm instruction.
pub fn f64_convert_i64_u(value : UInt64) -> Double {
  value.to_double()
}

// Wasm `sign-extension` proposal

///|
/// Execute the `i32_extend8_s` Wasm instruction.
pub fn i32_extend8_s(value : Int) -> Int {
  value << 24 >> 24
}

///|
/// Execute the `i32_extend16_s` Wasm instruction.
pub fn i32_extend16_s(value : Int) -> Int {
  value << 16 >> 16
}

///|
/// Execute the `i64_extend8_s` Wasm instruction.
pub fn i64_extend8_s(value : Int64) -> Int64 {
  value << 56 >> 56
}

///|
/// Execute the `i64_extend16_s` Wasm instruction.
pub fn i64_extend16_s(value : Int64) -> Int64 {
  value << 48 >> 48
}

///|
/// Execute the `i64_extend32_s` Wasm instruction.
pub fn i64_extend32_s(value : Int64) -> Int64 {
  value << 32 >> 32
}

// Wasm `saturating-float-to-int` proposal

///|
/// Execute the `i32_trunc_sat_f32_s` Wasm instruction.
pub fn i32_trunc_sat_f32_s(value : Float) -> Int {
  i32_trunc_sat_f64_s(value.to_double())
}

///|
/// Execute the `i32_trunc_sat_f32_u` Wasm instruction.
pub fn i32_trunc_sat_f32_u(value : Float) -> UInt {
  i32_trunc_sat_f64_u(value.to_double())
}

///|
/// Execute the `i32_trunc_sat_f64_s` Wasm instruction.
pub fn i32_trunc_sat_f64_s(value : Double) -> Int {
  if value != value {
    0
  } else if value >= 2147483647.0 {
    2147483647
  } else if value <= -2147483648.0 {
    -2147483648
  } else {
    value.to_int()
  }
}

///|
/// Execute the `i32_trunc_sat_f64_u` Wasm instruction.
pub fn i32_trunc_sat_f64_u(value : Double) -> UInt {
  if value != value {
    0
  } else if value >= 4294967295.0 {
    4294967295
  } else if value <= 0.0 {
    0
  } else {
    value.to_int64().reinterpret_as_uint64().to_uint()
  }
}

///|
/// Execute the `i64_trunc_sat_f32_s` Wasm instruction.
pub fn i64_trunc_sat_f32_s(value : Float) -> Int64 {
  i64_trunc_sat_f64_s(value.to_double())
}

///|
/// Execute the `i64_trunc_sat_f32_u` Wasm instruction.
pub fn i64_trunc_sat_f32_u(value : Float) -> UInt64 {
  i64_trunc_sat_f64_u(value.to_double())
}

///|
/// Execute the `i64_trunc_sat_f64_s` Wasm instruction.
pub fn i64_trunc_sat_f64_s(value : Double) -> Int64 {
  if value != value {
    0
  } else if value >= 9223372036854775808.0 {
    9223372036854775807
  } else if value <= -9223372036854775808.0 {
    -9223372036854775808
  } else {
    value.to_int64()
  }
}

///|
/// Execute the `i64_trunc_sat_f64_u` Wasm instruction.
pub fn i64_trunc_sat_f64_u(value : Double) -> UInt64 {
  if value != value {
    0
  } else if value >= 18446744073709551616.0 {
    0xFFFF_FFFF_FFFF_FFFF
  } else if value <= 0.0 {
    0
  } else {
    f64_to_u64_in_range(value)
  }
}

///|
/// Execute the `i32_reinterpret_f32` Wasm instruction.
pub fn i32_reinterpret_f32(value : Float) -> Int {
  value.reinterpret_as_int()
}

///|
/// Execute the `i64_reinterpret_f64` Wasm instruction.
pub fn i64_reinterpret_f64(value : Double) -> Int64 {
  value.reinterpret_as_int64()
}

///|
/// Execute the `f32_reinterpret_i32` Wasm instruction.
pub fn f32_reinterpret_i32(value : Int) -> Float {
  Float::reinterpret_from_int(value)
}

///|
/// Execute the `f64_reinterpret_i64` Wasm instruction.
pub fn f64_reinterpret_i64(value : Int64) -> Double {
  value.reinterpret_as_double()
}

// Loads

///|
/// Executes a Wasmi `i32_load8_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i32_load8_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int raise TrapCode {
  i32_load8_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i32_load8_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i32_load8_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int raise TrapCode {
  i32_extend8_s(load_u8_at(memory, memory_len, address).to_int())
}

///|
/// Executes a Wasmi `i32_load8_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i32_load8_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int raise TrapCode {
  i32_load8_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i32_load8_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i32_load8_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int raise TrapCode {
  load_u8_at(memory, memory_len, address).to_int()
}

///|
/// Executes a Wasmi `i32_load16_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i32_load16_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int raise TrapCode {
  i32_load16_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i32_load16_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i32_load16_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int raise TrapCode {
  i32_extend16_s(load_u16_at(memory, memory_len, address))
}

///|
/// Executes a Wasmi `i32_load16_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i32_load16_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int raise TrapCode {
  i32_load16_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i32_load16_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i32_load16_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int raise TrapCode {
  load_u16_at(memory, memory_len, address)
}

///|
/// Executes a Wasmi `i64_load8_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i64_load8_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int64 raise TrapCode {
  i64_load8_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i64_load8_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i64_load8_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int64 raise TrapCode {
  i32_extend8_s(load_u8_at(memory, memory_len, address).to_int()).to_int64()
}

///|
/// Executes a Wasmi `i64_load8_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i64_load8_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int64 raise TrapCode {
  i64_load8_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i64_load8_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i64_load8_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int64 raise TrapCode {
  load_u8_at(memory, memory_len, address).to_int64()
}

///|
/// Executes a Wasmi `i64_load16_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i64_load16_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int64 raise TrapCode {
  i64_load16_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i64_load16_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i64_load16_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int64 raise TrapCode {
  i32_extend16_s(load_u16_at(memory, memory_len, address)).to_int64()
}

///|
/// Executes a Wasmi `i64_load16_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i64_load16_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int64 raise TrapCode {
  i64_load16_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i64_load16_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i64_load16_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int64 raise TrapCode {
  load_u16_at(memory, memory_len, address).to_int64()
}

///|
/// Executes a Wasmi `i64_load32_s` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i64_load32_s(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int64 raise TrapCode {
  i64_load32_s_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i64_load32_s_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i64_load32_s_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int64 raise TrapCode {
  load_u32_at(memory, memory_len, address).reinterpret_as_int().to_int64()
}

///|
/// Executes a Wasmi `i64_load32_u` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn i64_load32_u(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> Int64 raise TrapCode {
  i64_load32_u_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `i64_load32_u_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn i64_load32_u_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> Int64 raise TrapCode {
  load_u32_at(memory, memory_len, address).to_uint64().reinterpret_as_int64()
}

///|
/// Executes a Wasmi `load32` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn load32(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> UInt raise TrapCode {
  load_u32_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `load32_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn load32_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> UInt raise TrapCode {
  load_u32_at(memory, memory_len, address)
}

///|
/// Executes a Wasmi `load64` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` loads out of bounds from `memory`.
pub fn load64(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
) -> UInt64 raise TrapCode {
  load_u64_at(memory, memory_len, effective_address(ptr, offset))
}

///|
/// Executes a Wasmi `load64_at` instruction.
///
/// # Errors
///
/// If `address` loads out of bounds from `memory`.
pub fn load64_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
) -> UInt64 raise TrapCode {
  load_u64_at(memory, memory_len, address)
}

// Stores

///|
/// Executes a Wasmi `i32_store8` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn i32_store8(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : Int,
) -> Unit raise TrapCode {
  store_u8_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value.to_byte(),
  )
}

///|
/// Executes a Wasmi `i32_store8_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn i32_store8_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Int,
) -> Unit raise TrapCode {
  store_u8_at(memory, memory_len, address, value.to_byte())
}

///|
/// Executes a Wasmi `i32_store16` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn i32_store16(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : Int,
) -> Unit raise TrapCode {
  store_u16_at(memory, memory_len, effective_address(ptr, offset), value)
}

///|
/// Executes a Wasmi `i32_store16_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn i32_store16_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Int,
) -> Unit raise TrapCode {
  store_u16_at(memory, memory_len, address, value)
}

///|
/// Executes a Wasmi `i64_store8` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn i64_store8(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : Int64,
) -> Unit raise TrapCode {
  store_u8_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value.to_byte(),
  )
}

///|
/// Executes a Wasmi `i64_store8_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn i64_store8_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Int64,
) -> Unit raise TrapCode {
  store_u8_at(memory, memory_len, address, value.to_byte())
}

///|
/// Executes a Wasmi `i64_store16` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn i64_store16(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : Int64,
) -> Unit raise TrapCode {
  store_u16_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value.to_int(),
  )
}

///|
/// Executes a Wasmi `i64_store16_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn i64_store16_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Int64,
) -> Unit raise TrapCode {
  store_u16_at(memory, memory_len, address, value.to_int())
}

///|
/// Executes a Wasmi `i64_store32` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn i64_store32(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : Int64,
) -> Unit raise TrapCode {
  store_u32_at(
    memory,
    memory_len,
    effective_address(ptr, offset),
    value.to_int().reinterpret_as_uint(),
  )
}

///|
/// Executes a Wasmi `i64_store32_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn i64_store32_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : Int64,
) -> Unit raise TrapCode {
  store_u32_at(
    memory,
    memory_len,
    address,
    value.to_int().reinterpret_as_uint(),
  )
}

///|
/// Executes a Wasmi `store32` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn store32(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : UInt,
) -> Unit raise TrapCode {
  store_u32_at(memory, memory_len, effective_address(ptr, offset), value)
}

///|
/// Executes a Wasmi `store32_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn store32_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : UInt,
) -> Unit raise TrapCode {
  store_u32_at(memory, memory_len, address, value)
}

///|
/// Executes a Wasmi `store64` instruction.
///
/// # Errors
///
/// - If `ptr + offset` overflows.
/// - If `ptr + offset` stores out of bounds from `memory`.
pub fn store64(
  memory : FixedArray[Byte],
  memory_len : Int,
  ptr : UInt64,
  offset : UInt64,
  value : UInt64,
) -> Unit raise TrapCode {
  store_u64_at(memory, memory_len, effective_address(ptr, offset), value)
}

///|
/// Executes a Wasmi `store64_at` instruction.
///
/// # Errors
///
/// If `address` stores out of bounds from `memory`.
pub fn store64_at(
  memory : FixedArray[Byte],
  memory_len : Int,
  address : UInt64,
  value : UInt64,
) -> Unit raise TrapCode {
  store_u64_at(memory, memory_len, address, value)
}

// Wasm `wide-arithmetic` proposal

///|
/// Execute an `i64.add128` Wasm instruction.
///
/// Returns a pair of `(lo, hi)` 64-bit values representing the 128-bit result.
///
/// # Note
///
/// This instruction is part of the Wasm `wide-arithmetic` proposal.
pub fn i64_add128(
  lhs_lo : Int64,
  lhs_hi : Int64,
  rhs_lo : Int64,
  rhs_hi : Int64,
) -> (Int64, Int64) {
  let lo = lhs_lo.reinterpret_as_uint64() + rhs_lo.reinterpret_as_uint64()
  let carry : Int64 = if lo < lhs_lo.reinterpret_as_uint64() { 1 } else { 0 }
  (lo.reinterpret_as_int64(), lhs_hi + rhs_hi + carry)
}

///|
/// Execute an `i64.sub128` Wasm instruction.
///
/// Returns a pair of `(lo, hi)` 64-bit values representing the 128-bit result.
///
/// # Note
///
/// This instruction is part of the Wasm `wide-arithmetic` proposal.
pub fn i64_sub128(
  lhs_lo : Int64,
  lhs_hi : Int64,
  rhs_lo : Int64,
  rhs_hi : Int64,
) -> (Int64, Int64) {
  let a = lhs_lo.reinterpret_as_uint64()
  let b = rhs_lo.reinterpret_as_uint64()
  let borrow : Int64 = if a < b { 1 } else { 0 }
  ((a - b).reinterpret_as_int64(), lhs_hi - rhs_hi - borrow)
}

///|
/// Execute an `i64.mul_wide_s` Wasm instruction.
///
/// Returns a pair of `(lo, hi)` 64-bit values representing the 128-bit result.
///
/// # Note
///
/// This instruction is part of the Wasm `wide-arithmetic` proposal.
pub fn i64_mul_wide_s(lhs : Int64, rhs : Int64) -> (Int64, Int64) {
  let (lo, hi) = widen_mul(
    lhs.reinterpret_as_uint64(),
    rhs.reinterpret_as_uint64(),
  )
  // Signed correction of the unsigned product.
  let mut hi = hi
  if lhs < 0 {
    hi = hi - rhs.reinterpret_as_uint64()
  }
  if rhs < 0 {
    hi = hi - lhs.reinterpret_as_uint64()
  }
  (lo.reinterpret_as_int64(), hi.reinterpret_as_int64())
}

///|
/// Execute an `i64.mul_wide_s` Wasm instruction.
///
/// Returns a pair of `(lo, hi)` 64-bit values representing the 128-bit result.
///
/// # Note
///
/// This instruction is part of the Wasm `wide-arithmetic` proposal.
pub fn i64_mul_wide_u(lhs : Int64, rhs : Int64) -> (Int64, Int64) {
  let (lo, hi) = widen_mul(
    lhs.reinterpret_as_uint64(),
    rhs.reinterpret_as_uint64(),
  )
  (lo.reinterpret_as_int64(), hi.reinterpret_as_int64())
}
