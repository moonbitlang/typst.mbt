// Port of `tiny-skia-path` 0.12.0 `src/f32x4_t.rs`.

///|
priv struct F32x4(Float, Float, Float, Float) derive(Eq)

///|
fn F32x4::default() -> F32x4 {
  F32x4(0.0, 0.0, 0.0, 0.0)
}

///|
fn F32x4::max(self : F32x4, rhs : F32x4) -> F32x4 {
  F32x4(
    fmax(self.0, rhs.0),
    fmax(self.1, rhs.1),
    fmax(self.2, rhs.2),
    fmax(self.3, rhs.3),
  )
}

///|
fn F32x4::min(self : F32x4, rhs : F32x4) -> F32x4 {
  F32x4(
    fmin(self.0, rhs.0),
    fmin(self.1, rhs.1),
    fmin(self.2, rhs.2),
    fmin(self.3, rhs.3),
  )
}

// (`Add`, `Sub`, `AddAssign` are unused by the crate and omitted.)

///|
impl Mul for F32x4 with fn mul(self, rhs) {
  F32x4(self.0 * rhs.0, self.1 * rhs.1, self.2 * rhs.2, self.3 * rhs.3)
}
