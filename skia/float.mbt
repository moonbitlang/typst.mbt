// Helpers of `tiny-skia-path/src/scalar.rs` and `floating_point.rs`
// (the `Scalar` trait and friends, crate-private upstream), plus the
// Rust `f32` primitives (`min`, `max`, `as` casts, ...) with their exact
// semantics.
//
// The `strict_num` wrappers (`FiniteF32`, `NormalizedF32`,
// `NormalizedF32Exclusive`, `NonZeroPositiveF32`) are plain `Float`s here;
// their constructors are ported as functions returning `Float?`.

///|
pub let scalar_max : Float = 3.402823466e+38

///|
pub let scalar_nearly_zero : Float = 1.0 / 4096.0

///|
pub let scalar_root_2_over_2 : Float = 0.707106781

///|
pub let float_pi : Float = 3.14159265

///|
/// `f32::EPSILON`.
pub let f32_epsilon : Float = Float::reinterpret_from_uint(0x34000000)

///|
/// `f32::MAX`.
pub let f32_max : Float = Float::reinterpret_from_uint(0x7f7fffff)

///|
/// `f32::INFINITY`.
pub let f32_infinity : Float = Float::reinterpret_from_uint(0x7f800000)

///|
/// `f32::NEG_INFINITY`.
pub let f32_neg_infinity : Float = Float::reinterpret_from_uint(0xff800000)

///|
/// `f32::NAN`.
pub let f32_nan : Float = Float::reinterpret_from_uint(0x7fc00000)

///|
/// `f32::is_finite`.
pub fn is_finite(x : Float) -> Bool {
  x - x == 0
}

///|
/// `f64::is_finite`.
pub fn is_finite_f64(x : Double) -> Bool {
  x - x == 0
}

///|
/// Whether the sign bit is set.
pub fn is_sign_negative(x : Float) -> Bool {
  x.reinterpret_as_int() < 0
}

///|
/// Rust's `f32::min` (IEEE minNum, `fminnm` on aarch64): NaN operands are
/// ignored, `-0.0 < +0.0`.
pub fn fmin(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if is_sign_negative(a) {
    a
  } else {
    b
  }
}

///|
/// Rust's `f32::max` (IEEE maxNum, `fmaxnm` on aarch64).
pub fn fmax(a : Float, b : Float) -> Float {
  if a != a {
    b
  } else if b != b {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if is_sign_negative(a) {
    b
  } else {
    a
  }
}

///|
/// Rust's `f64::min`.
pub fn dmin(a : Double, b : Double) -> Double {
  if a != a {
    b
  } else if b != b {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_int64() < 0 {
    a
  } else {
    b
  }
}

///|
/// Rust's `f64::max`.
pub fn dmax(a : Double, b : Double) -> Double {
  if a != a {
    b
  } else if b != b {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_int64() < 0 {
    b
  } else {
    a
  }
}

///|
/// `f32::abs`.
pub fn fabs(x : Float) -> Float {
  Float::reinterpret_from_uint(x.reinterpret_as_uint() & 0x7fffffff)
}

///|
/// `f32::signum`: `1.0` for positive values (incl. `+0.0`), `-1.0` for
/// negative values (incl. `-0.0`), NaN for NaN.
pub fn signum(x : Float) -> Float {
  if x != x {
    x
  } else if is_sign_negative(x) {
    -1.0
  } else {
    1.0
  }
}

///|
/// `x as i32` (saturating, NaN maps to 0).
pub fn f32_to_i32(x : Float) -> Int {
  x.to_int()
}

///|
/// `x as u32` (saturating, NaN maps to 0).
pub fn f32_to_u32(x : Float) -> UInt {
  x.to_double().to_uint()
}

///|
/// `x as f32` for an `i32`.
pub fn i32_to_f32(x : Int) -> Float {
  Float::from_int(x)
}

///|
/// `x as f32` for a `u32`.
pub fn u32_to_f32(x : UInt) -> Float {
  Float::from_uint(x)
}

///|
/// `f32::to_radians`.
pub fn to_radians(x : Float) -> Float {
  // Rust: `self * (consts::PI / 180.0f32)`.
  let value : Float = 3.14159265358979323846
  x * (value / 180.0)
}

///|
/// `f32::rem_euclid`.
pub fn rem_euclid(x : Float, rhs : Float) -> Float {
  let r = fmodf(x, rhs)
  if r < 0 {
    r + fabs(rhs)
  } else {
    r
  }
}

// Scalar extension methods (`Scalar` trait).

///|
pub fn half(x : Float) -> Float {
  x * 0.5
}

///|
pub fn ave(x : Float, other : Float) -> Float {
  (x + other) * 0.5
}

///|
pub fn sqr(x : Float) -> Float {
  x * x
}

///|
pub fn invert(x : Float) -> Float {
  1.0 / x
}

///|
/// A non-panicking clamp. Works just like SkTPin, returning `max` for NaN/inf.
pub fn bound(x : Float, min : Float, max : Float) -> Float {
  fmax(fmin(max, x), min)
}

///|
pub fn is_nearly_equal(x : Float, other : Float) -> Bool {
  fabs(x - other) <= scalar_nearly_zero
}

///|
pub fn is_nearly_equal_within_tolerance(
  x : Float,
  other : Float,
  tolerance : Float,
) -> Bool {
  fabs(x - other) <= tolerance
}

///|
pub fn is_nearly_zero(x : Float) -> Bool {
  is_nearly_zero_within_tolerance(x, scalar_nearly_zero)
}

///|
pub fn is_nearly_zero_within_tolerance(x : Float, tolerance : Float) -> Bool {
  fabs(x) <= tolerance
}

///|
/// From SkPathOpsTypes.
pub fn almost_dequal_ulps(x : Float, other : Float) -> Bool {
  let ulps_epsilon = 16
  let a_bits = f32_as_2s_compliment(x)
  let b_bits = f32_as_2s_compliment(other)
  // Find the difference in ULPs.
  a_bits < b_bits + ulps_epsilon && b_bits < a_bits + ulps_epsilon
}

// floating_point.rs

///|
let max_i32_fits_in_f32 : Float = 2147483520.0

///|
let min_i32_fits_in_f32 : Float = -2147483520.0

///|
/// `i32::saturate_from(f32)`: returns the closest integer for the given
/// float. Returns MAX_I32_FITS_IN_F32 for NaN.
pub fn i32_saturate_from(x : Float) -> Int {
  let x = if x < max_i32_fits_in_f32 { x } else { max_i32_fits_in_f32 }
  let x = if x > min_i32_fits_in_f32 { x } else { min_i32_fits_in_f32 }
  f32_to_i32(x)
}

///|
/// `i32::saturate_from(f64)`. Returns i32::MAX for NaN.
pub fn i32_saturate_from_f64(x : Double) -> Int {
  let x = if x < 2147483647.0 { x } else { 2147483647.0 }
  let x = if x > -2147483648.0 { x } else { -2147483648.0 }
  x.to_int()
}

///|
pub fn i32_saturate_floor(x : Float) -> Int {
  i32_saturate_from(floorf(x))
}

///|
pub fn i32_saturate_ceil(x : Float) -> Int {
  i32_saturate_from(ceilf(x))
}

///|
pub fn i32_saturate_round(x : Float) -> Int {
  i32_saturate_from(floorf(x) + 0.5)
}

///|
/// Return the float as a 2s compliment int. Just to be used to compare floats
/// to each other or against positive float-bit-constants (like 0).
pub fn f32_as_2s_compliment(x : Float) -> Int {
  sign_bit_to_2s_compliment(x.reinterpret_as_int())
}

///|
fn sign_bit_to_2s_compliment(x : Int) -> Int {
  if x < 0 {
    -(x & 0x7FFFFFFF)
  } else {
    x
  }
}

///|
/// `i32::saturating_add`.
pub fn i32_saturating_add(a : Int, b : Int) -> Int {
  let r = a.to_int64() + b.to_int64()
  if r > 2147483647L {
    2147483647
  } else if r < -2147483648L {
    -2147483648
  } else {
    r.to_int()
  }
}

///|
/// `i32::saturating_sub`.
pub fn i32_saturating_sub(a : Int, b : Int) -> Int {
  let r = a.to_int64() - b.to_int64()
  if r > 2147483647L {
    2147483647
  } else if r < -2147483648L {
    -2147483648
  } else {
    r.to_int()
  }
}

///|
/// `FiniteF32::new`.
pub fn finite_f32(n : Float) -> Float? {
  if is_finite(n) {
    Some(n)
  } else {
    None
  }
}

///|
/// `NormalizedF32::new`: `Some` if `0 <= n <= 1`.
pub fn normalized_f32(n : Float) -> Float? {
  if n >= 0.0 && n <= 1.0 {
    Some(n)
  } else {
    None
  }
}

///|
/// `NormalizedF32::new_clamped`. Returns zero for NaN or infinity.
pub fn normalized_f32_clamped(n : Float) -> Float {
  if is_finite(n) {
    fmax(fmin(1.0, n), 0.0)
  } else {
    0.0
  }
}

///|
/// `NormalizedF32Exclusive::new`: `Some` if `0 < n < 1`.
pub fn normalized_f32_exclusive(n : Float) -> Float? {
  if n > 0.0 && n < 1.0 {
    Some(n)
  } else {
    None
  }
}

///|
/// `NormalizedF32Exclusive::new_bounded`.
pub fn normalized_f32_exclusive_bounded(n : Float) -> Float {
  bound(n, f32_epsilon, 1.0 - f32_epsilon)
}

///|
/// `NormalizedF32Exclusive::HALF` / `ANY`.
pub let normalized_f32_exclusive_half : Float = 0.5

///|
/// `NonZeroPositiveF32::new`: `Some` if `n > 0` and finite.
pub fn non_zero_positive_f32(n : Float) -> Float? {
  if n > 0.0 && is_finite(n) {
    Some(n)
  } else {
    None
  }
}
