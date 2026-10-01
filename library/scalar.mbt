// Port of `typst_utils::Scalar` and `typst_utils::Numeric`.

///|
/// A 64-bit float that implements `Eq`, `Ord` and `Hash` (NaN becomes zero).
pub(all) struct Scalar(Double) derive(Default)

///|
pub fn Scalar::new(x : Double) -> Scalar {
  Scalar(if x.is_nan() { 0.0 } else { x })
}

///|
pub fn Scalar::get(self : Scalar) -> Double {
  self.0
}

///|
pub impl Eq for Scalar with equal(self, other) {
  self.0 == other.0
}

///|
pub impl Compare for Scalar with compare(self, other) {
  self.0.compare(other.0)
}

///|
pub impl Hash for Scalar with hash_combine(self, hasher) {
  // `0.0 == -0.0` must hash equally only if bits are equal upstream: upstream
  // hashes `to_bits`, so we do the same.
  hasher.combine_uint64(self.0.reinterpret_as_uint64())
}

///|
pub impl Add for Scalar with add(self, other) {
  Scalar::new(self.0 + other.0)
}

///|
pub impl Sub for Scalar with sub(self, other) {
  Scalar::new(self.0 - other.0)
}

///|
pub impl Mul for Scalar with mul(self, other) {
  Scalar::new(self.0 * other.0)
}

///|
pub impl Div for Scalar with div(self, other) {
  Scalar::new(self.0 / other.0)
}

///|
pub impl Neg for Scalar with neg(self) {
  Scalar::new(-self.0)
}

///|
/// Rust `f64 % f64` (truncated remainder, like C `fmod`).
pub fn rust_rem(a : Double, b : Double) -> Double {
  a % b
}

///|
/// Rust `f64::rem_euclid`.
pub fn rem_euclid(a : Double, b : Double) -> Double {
  let r = rust_rem(a, b)
  if r < 0.0 {
    r + b.abs()
  } else {
    r
  }
}

///|
/// Numeric types (upstream `typst_utils::Numeric`).
pub(open) trait Numeric: Add + Sub + Neg + Eq {
  zero() -> Self
  is_finite(Self) -> Bool
  scale(Self, Double) -> Self
  div_scale(Self, Double) -> Self
}

///|
pub fn[T : Numeric] is_zero(x : T) -> Bool {
  x == T::zero()
}
