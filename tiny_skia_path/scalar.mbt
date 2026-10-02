// Port of `tiny-skia-path` 0.12.0 `src/scalar.rs`.
//
// The `Scalar` extension trait on `f32` is a set of package functions
// (MoonBit cannot add methods to `Float` here); the public `Scalar` trait
// exposes them as `Scalar::half(x)` etc.

///|
pub let scalar_max : Float = Float::reinterpret_from_uint(0x7F7FFFFF) // 3.402823466e+38

///|
pub let scalar_nearly_zero : Float = 1.0 / 4096.0 // 1.0 / (1 << 12)

///|
pub let scalar_root_2_over_2 : Float = Float::reinterpret_from_uint(0x3F3504F3) // 0.707106781

///|
/// Float number extension methods.
///
/// Mainly for internal use. Do not rely on it!
pub trait Scalar {
  fn half(Self) -> Self
  fn ave(Self, Self) -> Self
  fn sqr(Self) -> Self
  fn invert(Self) -> Self
  fn bound(Self, Self, Self) -> Self
  fn is_nearly_equal(Self, Self) -> Bool
  fn is_nearly_equal_within_tolerance(Self, Self, Self) -> Bool
  fn is_nearly_zero(Self) -> Bool
  fn is_nearly_zero_within_tolerance(Self, Self) -> Bool
  fn almost_dequal_ulps(Self, Self) -> Bool
}

///|
pub impl Scalar for Float with fn half(self) {
  half(self)
}

///|
pub impl Scalar for Float with fn ave(self, other) {
  ave(self, other)
}

///|
pub impl Scalar for Float with fn sqr(self) {
  sqr(self)
}

///|
pub impl Scalar for Float with fn invert(self) {
  invert(self)
}

///|
pub impl Scalar for Float with fn bound(self, min, max) {
  bound(self, min, max)
}

///|
pub impl Scalar for Float with fn is_nearly_equal(self, other) {
  is_nearly_equal(self, other)
}

///|
pub impl Scalar for Float with fn is_nearly_equal_within_tolerance(
  self,
  other,
  tolerance,
) {
  is_nearly_equal_within_tolerance(self, other, tolerance)
}

///|
pub impl Scalar for Float with fn is_nearly_zero(self) {
  is_nearly_zero(self)
}

///|
pub impl Scalar for Float with fn is_nearly_zero_within_tolerance(
  self,
  tolerance,
) {
  is_nearly_zero_within_tolerance(self, tolerance)
}

///|
pub impl Scalar for Float with fn almost_dequal_ulps(self, other) {
  almost_dequal_ulps(self, other)
}

///|
fn half(x : Float) -> Float {
  x * 0.5
}

///|
fn ave(x : Float, other : Float) -> Float {
  (x + other) * 0.5
}

///|
fn sqr(x : Float) -> Float {
  x * x
}

///|
fn invert(x : Float) -> Float {
  1.0 / x
}

///|
/// A non-panicking clamp. Works just like SkTPin, returning `max` for NaN/inf.
fn bound(x : Float, min : Float, max : Float) -> Float {
  fmax(fmin(max, x), min)
}

///|
fn is_nearly_equal(x : Float, other : Float) -> Bool {
  (x - other).abs() <= scalar_nearly_zero
}

///|
fn is_nearly_equal_within_tolerance(
  x : Float,
  other : Float,
  tolerance : Float,
) -> Bool {
  (x - other).abs() <= tolerance
}

///|
fn is_nearly_zero(x : Float) -> Bool {
  is_nearly_zero_within_tolerance(x, scalar_nearly_zero)
}

///|
fn is_nearly_zero_within_tolerance(x : Float, tolerance : Float) -> Bool {
  x.abs() <= tolerance
}

///|
/// From SkPathOpsTypes.
fn almost_dequal_ulps(x : Float, other : Float) -> Bool {
  let ulps_epsilon = 16
  let a_bits = f32_as_2s_compliment(x)
  let b_bits = f32_as_2s_compliment(other)
  // Find the difference in ULPs.
  a_bits < b_bits + ulps_epsilon && b_bits < a_bits + ulps_epsilon
}
