// Port of `strict-num` 0.1.1 `src/lib.rs` (the bounded float types used by
// tiny-skia-path and usvg), plus the `ApproxEqUlps` implementation of
// `float-cmp` 0.9.0 (`src/ulps.rs`, `src/ulps_eq.rs`) that strict-num
// re-exports.
//
// Rust associated constants (`ZERO`, `ONE`) are static functions
// (`zero()`, `one()`); `unsafe fn new_unchecked` is a plain function.

///|
/// An immutable, finite `f32`.
pub struct FiniteF32(Float) derive(Debug, Default)

///|
pub fn FiniteF32::new(n : Float) -> FiniteF32? {
  if is_finite(n) {
    Some(FiniteF32(n))
  } else {
    None
  }
}

///|
/// Creates a new `FiniteF32` without checking the value.
pub fn FiniteF32::new_unchecked(n : Float) -> FiniteF32 {
  FiniteF32(n)
}

///|
pub fn FiniteF32::get(self : FiniteF32) -> Float {
  self.0
}

///|
pub impl Eq for FiniteF32 with fn equal(self, other) {
  self.0 == other.0
}

///|
pub impl Compare for FiniteF32 with fn compare(self, other) {
  if self.0 < other.0 {
    -1
  } else if self.0 > other.0 {
    1
  } else {
    0
  }
}

///|
pub impl Hash for FiniteF32 with fn hash_combine(self, hasher) {
  hasher.combine_uint(self.0.reinterpret_as_uint())
}

///|
/// An immutable, finite `f64`.
pub struct FiniteF64(Double) derive(Debug, Default)

///|
pub fn FiniteF64::new(n : Double) -> FiniteF64? {
  if is_finite_f64(n) {
    Some(FiniteF64(n))
  } else {
    None
  }
}

///|
pub fn FiniteF64::new_unchecked(n : Double) -> FiniteF64 {
  FiniteF64(n)
}

///|
pub fn FiniteF64::get(self : FiniteF64) -> Double {
  self.0
}

///|
pub impl Eq for FiniteF64 with fn equal(self, other) {
  self.0 == other.0
}

///|
pub impl Compare for FiniteF64 with fn compare(self, other) {
  if self.0 < other.0 {
    -1
  } else if self.0 > other.0 {
    1
  } else {
    0
  }
}

///|
pub impl Hash for FiniteF64 with fn hash_combine(self, hasher) {
  hasher.combine_uint64(self.0.reinterpret_as_uint64())
}

///|
/// An immutable, finite `f32` that is known to be >= 0.
pub struct PositiveF32(FiniteF32) derive(Debug, Default, Eq, Compare, Hash)

///|
pub fn PositiveF32::zero() -> PositiveF32 {
  PositiveF32(FiniteF32(0.0))
}

///|
pub fn PositiveF32::new(n : Float) -> PositiveF32? {
  if is_finite(n) && n >= 0.0 {
    Some(PositiveF32(FiniteF32(n)))
  } else {
    None
  }
}

///|
pub fn PositiveF32::new_unchecked(n : Float) -> PositiveF32 {
  PositiveF32(FiniteF32(n))
}

///|
pub fn PositiveF32::get(self : PositiveF32) -> Float {
  self.0.get()
}

///|
pub fn PositiveF32::get_finite(self : PositiveF32) -> FiniteF32 {
  self.0
}

///|
/// An immutable, finite `f64` that is known to be >= 0.
pub struct PositiveF64(FiniteF64) derive(Debug, Default, Eq, Compare, Hash)

///|
pub fn PositiveF64::zero() -> PositiveF64 {
  PositiveF64(FiniteF64(0.0))
}

///|
pub fn PositiveF64::new(n : Double) -> PositiveF64? {
  if is_finite_f64(n) && n >= 0.0 {
    Some(PositiveF64(FiniteF64(n)))
  } else {
    None
  }
}

///|
pub fn PositiveF64::new_unchecked(n : Double) -> PositiveF64 {
  PositiveF64(FiniteF64(n))
}

///|
pub fn PositiveF64::get(self : PositiveF64) -> Double {
  self.0.get()
}

///|
pub fn PositiveF64::get_finite(self : PositiveF64) -> FiniteF64 {
  self.0
}

///|
/// An immutable, finite `f32` that is known to be > 0.
pub struct NonZeroPositiveF32(FiniteF32) derive(Debug, Eq, Compare, Hash)

///|
pub fn NonZeroPositiveF32::new(n : Float) -> NonZeroPositiveF32? {
  if is_finite(n) && n > 0.0 {
    Some(NonZeroPositiveF32(FiniteF32(n)))
  } else {
    None
  }
}

///|
pub fn NonZeroPositiveF32::new_unchecked(n : Float) -> NonZeroPositiveF32 {
  NonZeroPositiveF32(FiniteF32(n))
}

///|
pub fn NonZeroPositiveF32::get(self : NonZeroPositiveF32) -> Float {
  self.0.get()
}

///|
pub fn NonZeroPositiveF32::get_finite(self : NonZeroPositiveF32) -> FiniteF32 {
  self.0
}

///|
/// An immutable, finite `f64` that is known to be > 0.
pub struct NonZeroPositiveF64(FiniteF64) derive(Debug, Eq, Compare, Hash)

///|
pub fn NonZeroPositiveF64::new(n : Double) -> NonZeroPositiveF64? {
  if is_finite_f64(n) && n > 0.0 {
    Some(NonZeroPositiveF64(FiniteF64(n)))
  } else {
    None
  }
}

///|
pub fn NonZeroPositiveF64::new_unchecked(n : Double) -> NonZeroPositiveF64 {
  NonZeroPositiveF64(FiniteF64(n))
}

///|
pub fn NonZeroPositiveF64::get(self : NonZeroPositiveF64) -> Double {
  self.0.get()
}

///|
pub fn NonZeroPositiveF64::get_finite(self : NonZeroPositiveF64) -> FiniteF64 {
  self.0
}

///|
/// An immutable, finite `f32` in a 0..=1 range.
pub struct NormalizedF32(FiniteF32) derive(Debug, Eq, Compare, Hash)

///|
pub fn NormalizedF32::zero() -> NormalizedF32 {
  NormalizedF32(FiniteF32(0.0))
}

///|
pub fn NormalizedF32::one() -> NormalizedF32 {
  NormalizedF32(FiniteF32(1.0))
}

///|
pub fn NormalizedF32::new(n : Float) -> NormalizedF32? {
  if is_finite(n) && n >= 0.0 && n <= 1.0 {
    Some(NormalizedF32(FiniteF32(n)))
  } else {
    None
  }
}

///|
pub fn NormalizedF32::new_unchecked(n : Float) -> NormalizedF32 {
  NormalizedF32(FiniteF32(n))
}

///|
/// Creates a `NormalizedF32` clamping the given value to a 0..=1 range.
///
/// Returns zero in case of NaN or infinity.
pub fn NormalizedF32::new_clamped(n : Float) -> NormalizedF32 {
  if is_finite(n) {
    NormalizedF32(FiniteF32(clamp_f32(0.0, n, 1.0)))
  } else {
    NormalizedF32::zero()
  }
}

///|
/// Converts a `u8` value into a `NormalizedF32`.
pub fn NormalizedF32::new_u8(n : Byte) -> NormalizedF32 {
  NormalizedF32(FiniteF32(Float::from_int(n.to_int()) / 255.0))
}

///|
/// Converts a `u16` value into a `NormalizedF32`.
pub fn NormalizedF32::new_u16(n : UInt16) -> NormalizedF32 {
  NormalizedF32(FiniteF32(Float::from_int(n.to_int()) / 65535.0))
}

///|
pub fn NormalizedF32::get(self : NormalizedF32) -> Float {
  self.0.get()
}

///|
pub fn NormalizedF32::get_finite(self : NormalizedF32) -> FiniteF32 {
  self.0
}

///|
/// Returns the value as a `u8`.
pub fn NormalizedF32::to_u8(self : NormalizedF32) -> Byte {
  let v = self.0.0 * 255.0 + 0.5
  f32_as_u32(v).reinterpret_as_int().min(255).to_byte()
}

///|
/// Returns the value as a `u16`.
pub fn NormalizedF32::to_u16(self : NormalizedF32) -> UInt16 {
  let v = self.0.0 * 65535.0 + 0.5
  f32_as_u32(v).reinterpret_as_int().min(65535).to_uint16()
}

///|
pub impl Mul for NormalizedF32 with fn mul(self, rhs) {
  NormalizedF32::new_clamped(self.0.0 * rhs.0.0)
}

///|
/// An immutable, finite `f64` in a 0..=1 range.
pub struct NormalizedF64(FiniteF64) derive(Debug, Eq, Compare, Hash)

///|
pub fn NormalizedF64::zero() -> NormalizedF64 {
  NormalizedF64(FiniteF64(0.0))
}

///|
pub fn NormalizedF64::one() -> NormalizedF64 {
  NormalizedF64(FiniteF64(1.0))
}

///|
pub fn NormalizedF64::new(n : Double) -> NormalizedF64? {
  if n >= 0.0 && n <= 1.0 {
    Some(NormalizedF64(FiniteF64(n)))
  } else {
    None
  }
}

///|
pub fn NormalizedF64::new_unchecked(n : Double) -> NormalizedF64 {
  NormalizedF64(FiniteF64(n))
}

///|
pub fn NormalizedF64::new_clamped(n : Double) -> NormalizedF64 {
  if is_finite_f64(n) {
    NormalizedF64(FiniteF64(clamp_f64(0.0, n, 1.0)))
  } else {
    NormalizedF64::zero()
  }
}

///|
pub fn NormalizedF64::get(self : NormalizedF64) -> Double {
  self.0.get()
}

///|
pub fn NormalizedF64::get_finite(self : NormalizedF64) -> FiniteF64 {
  self.0
}

///|
pub impl Mul for NormalizedF64 with fn mul(self, rhs) {
  NormalizedF64::new_clamped(self.0.0 * rhs.0.0)
}

///|
fn clamp_f32(min : Float, val : Float, max : Float) -> Float {
  fmax(fmin(max, val), min)
}

///|
fn clamp_f64(min : Double, val : Double, max : Double) -> Double {
  fmax_f64(fmin_f64(max, val), min)
}

///|
fn fmin_f64(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a < b {
    a
  } else if b < a {
    b
  } else if a.reinterpret_as_int64() < 0L {
    a
  } else {
    b
  }
}

///|
fn fmax_f64(a : Double, b : Double) -> Double {
  if a.is_nan() {
    b
  } else if b.is_nan() {
    a
  } else if a > b {
    a
  } else if b > a {
    b
  } else if a.reinterpret_as_int64() < 0L {
    b
  } else {
    a
  }
}

// float-cmp 0.9.0: `ApproxEqUlps`.

///|
/// `f32::approx_eq_ulps` of `float-cmp`.
///
/// Tests `a` and `b` to be approximately equal within `ulps` ULPs. Differing
/// signs are always unequal, and zeroes are only equal to zeroes.
pub fn approx_eq_ulps(a : Float, b : Float, ulps : Int) -> Bool {
  // -0 and +0 are drastically far in ulps terms, so
  // we need a special case for that.
  if a == b {
    return true
  }

  // Handle differing signs as a special case, even if
  // they are very close, most people consider them
  // unequal.
  if (a.reinterpret_as_int() >= 0) != (b.reinterpret_as_int() >= 0) {
    return false
  }
  let diff = a.reinterpret_as_int() - b.reinterpret_as_int() // wrapping
  diff >= -ulps && diff <= ulps
}

///|
/// `f64::approx_eq_ulps` of `float-cmp`.
pub fn approx_eq_ulps_f64(a : Double, b : Double, ulps : Int64) -> Bool {
  if a == b {
    return true
  }
  if (a.reinterpret_as_int64() >= 0L) != (b.reinterpret_as_int64() >= 0L) {
    return false
  }
  let diff = a.reinterpret_as_int64() - b.reinterpret_as_int64() // wrapping
  diff >= -ulps && diff <= ulps
}

///|
pub fn FiniteF32::approx_eq_ulps(
  self : FiniteF32,
  other : FiniteF32,
  ulps : Int,
) -> Bool {
  approx_eq_ulps(self.0, other.0, ulps)
}

///|
pub fn PositiveF32::approx_eq_ulps(
  self : PositiveF32,
  other : PositiveF32,
  ulps : Int,
) -> Bool {
  approx_eq_ulps(self.get(), other.get(), ulps)
}

///|
pub fn NonZeroPositiveF32::approx_eq_ulps(
  self : NonZeroPositiveF32,
  other : NonZeroPositiveF32,
  ulps : Int,
) -> Bool {
  approx_eq_ulps(self.get(), other.get(), ulps)
}

///|
pub fn NormalizedF32::approx_eq_ulps(
  self : NormalizedF32,
  other : NormalizedF32,
  ulps : Int,
) -> Bool {
  approx_eq_ulps(self.get(), other.get(), ulps)
}

///|
pub fn FiniteF64::approx_eq_ulps(
  self : FiniteF64,
  other : FiniteF64,
  ulps : Int64,
) -> Bool {
  approx_eq_ulps_f64(self.0, other.0, ulps)
}

///|
pub fn PositiveF64::approx_eq_ulps(
  self : PositiveF64,
  other : PositiveF64,
  ulps : Int64,
) -> Bool {
  approx_eq_ulps_f64(self.get(), other.get(), ulps)
}

///|
pub fn NonZeroPositiveF64::approx_eq_ulps(
  self : NonZeroPositiveF64,
  other : NonZeroPositiveF64,
  ulps : Int64,
) -> Bool {
  approx_eq_ulps_f64(self.get(), other.get(), ulps)
}

///|
pub fn NormalizedF64::approx_eq_ulps(
  self : NormalizedF64,
  other : NormalizedF64,
  ulps : Int64,
) -> Bool {
  approx_eq_ulps_f64(self.get(), other.get(), ulps)
}
