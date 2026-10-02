// The parts of `strict-num` 0.1.1 and `float-cmp` that usvg uses:
// `NormalizedF32` (usvg's `Opacity`/`StopOffset`), `PositiveF32`,
// `NonZeroPositiveF32` and `ApproxEqUlps`.

///|
/// An immutable, finite `f32` in a 0..=1 range (`strict_num::NormalizedF32`).
pub struct NormalizedF32(Float) derive(Eq)

///|
/// An alias to `NormalizedF32`.
pub type Opacity = NormalizedF32

///|
/// An alias to `NormalizedF32`.
pub type StopOffset = NormalizedF32

///|
/// A `NormalizedF32` value initialized with zero.
pub fn NormalizedF32::zero() -> NormalizedF32 {
  NormalizedF32(0.0)
}

///|
/// A `NormalizedF32` value initialized with one.
pub fn NormalizedF32::one() -> NormalizedF32 {
  NormalizedF32(1.0)
}

///|
/// Creates a `NormalizedF32` if the given value is in a 0..=1 range.
pub fn NormalizedF32::new(n : Float) -> NormalizedF32? {
  if is_finite_f32(n) && n >= 0.0 && n <= 1.0 {
    Some(NormalizedF32(n))
  } else {
    None
  }
}

///|
/// Creates a `NormalizedF32` clamping the given value to a 0..=1 range.
///
/// Returns zero in case of NaN or infinity.
pub fn NormalizedF32::new_clamped(n : Float) -> NormalizedF32 {
  if is_finite_f32(n) {
    NormalizedF32((1.0 : Float).min(n).max(0.0))
  } else {
    NormalizedF32::zero()
  }
}

///|
/// Creates a `NormalizedF32` by dividing the given value by 255.
pub fn NormalizedF32::new_u8(n : Int) -> NormalizedF32 {
  NormalizedF32(Float::from_int(n) / 255.0)
}

///|
/// Returns the value as a primitive type.
pub fn NormalizedF32::get(self : NormalizedF32) -> Float {
  self.0
}

///|
/// Returns the value as a `u8`.
pub fn NormalizedF32::to_u8(self : NormalizedF32) -> Int {
  f32_as_u8(self.0 * 255.0 + 0.5)
}

///|
pub impl Mul for NormalizedF32 with mul(self, rhs) {
  NormalizedF32::new_clamped(self.0 * rhs.0)
}

///|
/// An immutable, finite `f32` that is known to be >= 0.
pub struct PositiveF32(Float) derive(Eq)

///|
pub fn PositiveF32::zero() -> PositiveF32 {
  PositiveF32(0.0)
}

///|
/// Creates a new `PositiveF32` if the given value is >= 0.
pub fn PositiveF32::new(n : Float) -> PositiveF32? {
  if is_finite_f32(n) && n >= 0.0 {
    Some(PositiveF32(n))
  } else {
    None
  }
}

///|
pub fn PositiveF32::get(self : PositiveF32) -> Float {
  self.0
}

///|
/// An immutable, finite `f32` that is known to be > 0.
pub struct NonZeroPositiveF32(Float) derive(Eq)

///|
/// Creates a new `NonZeroPositiveF32` if the given value is > 0.
pub fn NonZeroPositiveF32::new(n : Float) -> NonZeroPositiveF32? {
  if is_finite_f32(n) && n > 0.0 {
    Some(NonZeroPositiveF32(n))
  } else {
    None
  }
}

///|
pub fn NonZeroPositiveF32::get(self : NonZeroPositiveF32) -> Float {
  self.0
}

///|
/// An alias to `NonZeroPositiveF32`.
pub type StrokeWidth = NonZeroPositiveF32

///|
fn is_finite_f32(n : Float) -> Bool {
  !n.is_nan() && !n.is_inf()
}

///|
fn is_finite_f64(n : Double) -> Bool {
  !n.is_nan() && !n.is_inf()
}

///|
/// `float_cmp::ApproxEqUlps` for `f32`.
fn approx_eq_ulps(a : Float, b : Float, ulps : Int) -> Bool {
  // -0 and +0 are drastically far in ulps terms, so
  // we need a special case for that.
  if a == b {
    return true
  }
  // Handle differing signs as a special case, even if
  // they are very close, most of the time they aren't equal.
  if is_sign_positive_f32(a) != is_sign_positive_f32(b) {
    return false
  }
  let diff = a.reinterpret_as_int() - b.reinterpret_as_int()
  diff >= -ulps && diff <= ulps
}

///|
fn approx_ne_ulps(a : Float, b : Float, ulps : Int) -> Bool {
  !approx_eq_ulps(a, b, ulps)
}

///|
/// `float_cmp::ApproxEqUlps` for `f64`.
fn approx_eq_ulps_f64(a : Double, b : Double, ulps : Int64) -> Bool {
  if a == b {
    return true
  }
  if is_sign_positive_f64(a) != is_sign_positive_f64(b) {
    return false
  }
  let diff = a.reinterpret_as_int64() - b.reinterpret_as_int64()
  diff >= -ulps && diff <= ulps
}

///|
fn approx_zero_ulps(a : Float, ulps : Int) -> Bool {
  approx_eq_ulps(a, 0.0, ulps)
}

///|
fn is_sign_positive_f32(a : Float) -> Bool {
  a.reinterpret_as_uint() >> 31 == 0
}

///|
fn is_sign_negative_f32(a : Float) -> Bool {
  !is_sign_positive_f32(a)
}

///|
fn is_sign_positive_f64(a : Double) -> Bool {
  a.reinterpret_as_uint64() >> 63 == 0
}

///|
fn is_sign_negative_f64(a : Double) -> Bool {
  !is_sign_positive_f64(a)
}

///|
/// Checks that the current number is > 0 (`IsValidLength`).
fn is_valid_length(n : Float) -> Bool {
  n > 0.0 && is_finite_f32(n)
}

///|
/// Rust's saturating `f32 as u8` cast.
fn f32_as_u8(n : Float) -> Int {
  if n.is_nan() {
    0
  } else if n <= 0.0 {
    0
  } else if n >= 255.0 {
    255
  } else {
    n.to_int()
  }
}

///|
/// `f32_bound` from usvg's `parser/mod.rs`.
fn f32_bound(min : Float, val : Float, max : Float) -> Float {
  if val > max {
    max
  } else if val < min {
    min
  } else {
    val
  }
}

///|
/// Rust's `f32::powi` (LLVM's `__powisf2`).
fn powi_f32(a : Float, b : Int) -> Float {
  let recip = b < 0
  let mut r : Float = 1.0
  let mut a = a
  let mut b = b
  while true {
    if (b & 1) != 0 {
      r = r * a
    }
    b = b / 2
    if b == 0 {
      break
    }
    a = a * a
  }
  if recip {
    1.0 / r
  } else {
    r
  }
}

///|
/// Rust's `f32::to_degrees`.
fn to_degrees_f32(x : Float) -> Float {
  x * Float::reinterpret_from_uint(0x42652EE1U)
}

///|
/// Rust's `f32::to_radians`.
fn to_radians_f32(x : Float) -> Float {
  // `consts::PI / 180.0` in `f32`.
  x * Float::reinterpret_from_uint(0x3C8EFA35U)
}

///|
/// Rust's `f32 % f32` (`fmodf`; exact, so computing it in `f64` is
/// equivalent).
fn rem_f32(a : Float, b : Float) -> Float {
  (a.to_double() % b.to_double()).to_float()
}
