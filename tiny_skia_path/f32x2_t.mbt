// Port of `tiny-skia-path` 0.12.0 `src/f32x2_t.rs`.

///|
/// A pair of f32 numbers (`f32x2`).
///
/// Mainly for internal use. Do not rely on it!
pub(all) struct F32x2(Float, Float) derive(Eq, Debug, Default)

///|
/// Creates a new pair.
pub fn F32x2::new(a : Float, b : Float) -> F32x2 {
  F32x2(a, b)
}

///|
/// Creates a new pair from a single value.
pub fn F32x2::splat(x : Float) -> F32x2 {
  F32x2(x, x)
}

///|
/// Returns an absolute value.
pub fn F32x2::abs(self : F32x2) -> F32x2 {
  F32x2(self.0.abs(), self.1.abs())
}

///|
/// Returns a minimum value.
pub fn F32x2::min(self : F32x2, other : F32x2) -> F32x2 {
  F32x2(pmin(self.0, other.0), pmin(self.1, other.1))
}

///|
/// Returns a maximum value.
pub fn F32x2::max(self : F32x2, other : F32x2) -> F32x2 {
  F32x2(pmax(self.0, other.0), pmax(self.1, other.1))
}

///|
/// Returns a maximum of both values.
pub fn F32x2::max_component(self : F32x2) -> Float {
  pmax(self.0, self.1)
}

///|
/// Returns the first value.
pub fn F32x2::x(self : F32x2) -> Float {
  self.0
}

///|
/// Returns the second value.
pub fn F32x2::y(self : F32x2) -> Float {
  self.1
}

///|
pub impl Add for F32x2 with fn add(self, other) {
  F32x2(self.0 + other.0, self.1 + other.1)
}

///|
pub impl Sub for F32x2 with fn sub(self, other) {
  F32x2(self.0 - other.0, self.1 - other.1)
}

///|
pub impl Mul for F32x2 with fn mul(self, other) {
  F32x2(self.0 * other.0, self.1 * other.1)
}

///|
pub impl Div for F32x2 with fn div(self, other) {
  F32x2(self.0 / other.0, self.1 / other.1)
}

// A faster and more forgiving f32 min/max implementation.
//
// Unlike std one, we do not care about NaN.

///|
fn pmax(a : Float, b : Float) -> Float {
  if a < b {
    b
  } else {
    a
  }
}

///|
fn pmin(a : Float, b : Float) -> Float {
  if b < a {
    b
  } else {
    a
  }
}
