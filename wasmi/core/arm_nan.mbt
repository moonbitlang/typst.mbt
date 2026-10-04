// NaN propagation as performed by the AArch64 FPU (FPCR.DN = 0), on which
// the upstream oracle runs.
//
// Upstream computes float arithmetic with the host's instructions, so the
// payload of a NaN result is hardware-defined. To be bit-exact on every
// MoonBit backend (and independent of the C compiler's operand order), the
// arithmetic helpers below compute the result natively and, only if it is a
// NaN, replace it with the NaN that `FPProcessNaNs` of the Arm architecture
// produces:
//
// - the first signaling NaN operand, quieted, else
// - the first quiet NaN operand, else
// - the default NaN (positive, quiet, zero payload) for invalid operations.

///|
let f32_default_nan_bits : UInt = 0x7FC0_0000

///|
let f64_default_nan_bits : UInt64 = 0x7FF8_0000_0000_0000

///|
fn f32_is_nan_bits(bits : UInt) -> Bool {
  (bits & 0x7FFF_FFFF) > 0x7F80_0000
}

///|
fn f32_is_snan_bits(bits : UInt) -> Bool {
  f32_is_nan_bits(bits) && (bits & 0x0040_0000) == 0
}

///|
fn f64_is_nan_bits(bits : UInt64) -> Bool {
  (bits & 0x7FFF_FFFF_FFFF_FFFF) > 0x7FF0_0000_0000_0000
}

///|
fn f64_is_snan_bits(bits : UInt64) -> Bool {
  f64_is_nan_bits(bits) && (bits & 0x0008_0000_0000_0000) == 0
}

///|
/// Returns the quiet version of the NaN `x`.
fn f32_quiet(x : Float) -> Float {
  Float::reinterpret_from_uint(x.reinterpret_as_uint() | 0x0040_0000)
}

///|
/// Returns the quiet version of the NaN `x`.
fn f64_quiet(x : Double) -> Double {
  (x.reinterpret_as_uint64() | 0x0008_0000_0000_0000).reinterpret_as_double()
}

///|
/// `FPProcessNaNs` for a binary operation whose result is a NaN.
fn f32_nan2(a : Float, b : Float) -> Float {
  let ab = a.reinterpret_as_uint()
  let bb = b.reinterpret_as_uint()
  if f32_is_snan_bits(ab) {
    Float::reinterpret_from_uint(ab | 0x0040_0000)
  } else if f32_is_snan_bits(bb) {
    Float::reinterpret_from_uint(bb | 0x0040_0000)
  } else if f32_is_nan_bits(ab) {
    a
  } else if f32_is_nan_bits(bb) {
    b
  } else {
    Float::reinterpret_from_uint(f32_default_nan_bits)
  }
}

///|
/// `FPProcessNaNs` for a binary operation whose result is a NaN.
fn f64_nan2(a : Double, b : Double) -> Double {
  let ab = a.reinterpret_as_uint64()
  let bb = b.reinterpret_as_uint64()
  if f64_is_snan_bits(ab) {
    (ab | 0x0008_0000_0000_0000).reinterpret_as_double()
  } else if f64_is_snan_bits(bb) {
    (bb | 0x0008_0000_0000_0000).reinterpret_as_double()
  } else if f64_is_nan_bits(ab) {
    a
  } else if f64_is_nan_bits(bb) {
    b
  } else {
    f64_default_nan_bits.reinterpret_as_double()
  }
}

///|
/// `FPMulAdd(addend, op1, op2)` NaN handling (`fmadd d, op1, op2, addend`)
/// for a fused multiply-add whose result is a NaN.
fn f32_nan_mul_add(op1 : Float, op2 : Float, addend : Float) -> Float {
  let a = addend.reinterpret_as_uint()
  let x = op1.reinterpret_as_uint()
  let y = op2.reinterpret_as_uint()
  let inf_times_zero = (
      (x & 0x7FFF_FFFF) == 0x7F80_0000 && (y & 0x7FFF_FFFF) == 0
    ) ||
    ((x & 0x7FFF_FFFF) == 0 && (y & 0x7FFF_FFFF) == 0x7F80_0000)
  if f32_is_snan_bits(a) {
    Float::reinterpret_from_uint(a | 0x0040_0000)
  } else if f32_is_snan_bits(x) {
    Float::reinterpret_from_uint(x | 0x0040_0000)
  } else if f32_is_snan_bits(y) {
    Float::reinterpret_from_uint(y | 0x0040_0000)
  } else if f32_is_nan_bits(a) {
    if inf_times_zero {
      Float::reinterpret_from_uint(f32_default_nan_bits)
    } else {
      addend
    }
  } else if f32_is_nan_bits(x) {
    op1
  } else if f32_is_nan_bits(y) {
    op2
  } else {
    Float::reinterpret_from_uint(f32_default_nan_bits)
  }
}

///|
/// `FPMulAdd(addend, op1, op2)` NaN handling (`fmadd d, op1, op2, addend`)
/// for a fused multiply-add whose result is a NaN.
fn f64_nan_mul_add(op1 : Double, op2 : Double, addend : Double) -> Double {
  let a = addend.reinterpret_as_uint64()
  let x = op1.reinterpret_as_uint64()
  let y = op2.reinterpret_as_uint64()
  let abs_mask = 0x7FFF_FFFF_FFFF_FFFFUL
  let inf = 0x7FF0_0000_0000_0000UL
  let inf_times_zero = ((x & abs_mask) == inf && (y & abs_mask) == 0) ||
    ((x & abs_mask) == 0 && (y & abs_mask) == inf)
  if f64_is_snan_bits(a) {
    (a | 0x0008_0000_0000_0000).reinterpret_as_double()
  } else if f64_is_snan_bits(x) {
    (x | 0x0008_0000_0000_0000).reinterpret_as_double()
  } else if f64_is_snan_bits(y) {
    (y | 0x0008_0000_0000_0000).reinterpret_as_double()
  } else if f64_is_nan_bits(a) {
    if inf_times_zero {
      f64_default_nan_bits.reinterpret_as_double()
    } else {
      addend
    }
  } else if f64_is_nan_bits(x) {
    op1
  } else if f64_is_nan_bits(y) {
    op2
  } else {
    f64_default_nan_bits.reinterpret_as_double()
  }
}

///|
/// Hardware `lhs + rhs`.
fn f32_hw_add(lhs : Float, rhs : Float) -> Float {
  let r = lhs + rhs
  if r != r {
    f32_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Hardware `lhs + rhs`.
fn f64_hw_add(lhs : Double, rhs : Double) -> Double {
  let r = lhs + rhs
  if r != r {
    f64_nan2(lhs, rhs)
  } else {
    r
  }
}

///|
/// Hardware `-x` (flips the sign bit, also of NaNs).
fn f32_hw_neg(x : Float) -> Float {
  Float::reinterpret_from_uint(x.reinterpret_as_uint() ^ 0x8000_0000)
}

///|
/// Hardware `-x` (flips the sign bit, also of NaNs).
fn f64_hw_neg(x : Double) -> Double {
  (x.reinterpret_as_uint64() ^ 0x8000_0000_0000_0000).reinterpret_as_double()
}
