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
/// Raises a number to an integer power.
pub fn Scalar::powi(self : Scalar, b : Int) -> Scalar {
  // Ported from https://github.com/llvm/llvm-project/blob/0ee439b/compiler-rt/lib/builtins/powidf2.c
  // Copyright: The LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
  let mut a = self.get()
  let mut b = b
  let recip = b < 0
  let mut r = 1.0
  while true {
    if (b & 1) != 0 {
      r *= a
    }
    b /= 2
    if b == 0 {
      break
    }
    a *= a
  }
  if recip {
    r = 1.0 / r
  }
  Scalar::new(r)
}

///|
pub impl Eq for Scalar with fn equal(self, other) {
  self.0 == other.0
}

///|
pub impl Compare for Scalar with fn compare(self, other) {
  self.0.compare(other.0)
}

///|
pub impl Hash for Scalar with fn hash_combine(self, hasher) {
  // `0.0 == -0.0` must hash equally only if bits are equal upstream: upstream
  // hashes `to_bits`, so we do the same.
  hasher.combine_uint64(self.0.reinterpret_as_uint64())
}

///|
pub impl Add for Scalar with fn add(self, other) {
  Scalar::new(self.0 + other.0)
}

///|
pub impl Sub for Scalar with fn sub(self, other) {
  Scalar::new(self.0 - other.0)
}

///|
pub impl Mul for Scalar with fn mul(self, other) {
  Scalar::new(self.0 * other.0)
}

///|
pub impl Div for Scalar with fn div(self, other) {
  Scalar::new(self.0 / other.0)
}

///|
pub impl Neg for Scalar with fn neg(self) {
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
  fn zero() -> Self
  fn is_finite(Self) -> Bool
  fn scale(Self, Double) -> Self
  fn div_scale(Self, Double) -> Self
}

///|
pub fn[T : Numeric] is_zero(x : T) -> Bool {
  x == T::zero()
}

// The `Scalar` cast (upstream `foundations/float.rs`).

///|
pub impl Reflect for Scalar with fn input() {
  input_of((Ty::new() : Ty[Double]))
}

///|
pub impl Reflect for Scalar with fn output() {
  output_of((Ty::new() : Ty[Double]))
}

///|
pub impl Reflect for Scalar with fn castable(v) {
  castable_of((Ty::new() : Ty[Double]), v)
}

///|
pub impl IntoValue for Scalar with fn into_value(self) {
  Float(self.get())
}

///|
pub extend Scalar with IntoValue::{into_value}

///|
pub impl FromValue for Scalar with fn from_value(v) {
  Scalar::new(FromValue::from_value(v))
}

///|
/// The default of `PngFormat::ppi` (`typst-render/src/format.rs`).
fn png_format_elem_ppi_default() -> Value {
  Scalar::new(144.0).into_value()
}
