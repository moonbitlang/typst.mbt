// Port of `typst-library/src/layout/transform.rs`: the castable value types
// (`ScaleAmount`), the `ScaleElem` field defaults and `Transform`.

///|
/// To what size something shall be scaled.
pub(all) enum ScaleAmount {
  Ratio(Ratio)
  Length(Length)
} derive(Eq, Hash)

///|
pub impl Reflect for ScaleAmount with fn input() {
  CastInfo::Type(Type::ratio()).union_with(Type(Type::length()))
}

///|
pub impl Reflect for ScaleAmount with fn output() {
  ScaleAmount::input()
}

///|
pub impl Reflect for ScaleAmount with fn castable(v) {
  v is (Ratio(_) | Length(_))
}

///|
pub impl IntoValue for ScaleAmount with fn into_value(self) {
  match self {
    Ratio(ratio) => Ratio(ratio)
    Length(length) => Length(length)
  }
}

///|
pub impl FromValue for ScaleAmount with fn from_value(v) {
  match v {
    Ratio(ratio) => Ratio(ratio)
    Length(length) => Length(length)
    v => raise HintedError(ScaleAmount::input().error(v))
  }
}

///|
/// Upstream `Smart::Custom(ScaleAmount::Ratio(Ratio::one()))`.
fn scale_amount_one() -> Value {
  (Custom(Ratio(Ratio::one())) : Smart[ScaleAmount]).into_value()
}

///|
fn scale_elem_factor_default() -> Value {
  scale_amount_one()
}

///|
fn scale_elem_x_default() -> Value {
  scale_amount_one()
}

///|
fn scale_elem_y_default() -> Value {
  scale_amount_one()
}

///|
/// A scale-skew-translate transformation.
pub(all) struct Transform {
  sx : Ratio
  ky : Ratio
  kx : Ratio
  sy : Ratio
  tx : Abs
  ty : Abs
} derive(Eq, Hash)

///|
/// The identity transformation.
pub fn Transform::identity() -> Transform {
  {
    sx: Ratio::one(),
    ky: Ratio::zero(),
    kx: Ratio::zero(),
    sy: Ratio::one(),
    tx: Abs::zero(),
    ty: Abs::zero(),
  }
}

///|
pub impl Default for Transform with fn default() {
  Transform::identity()
}

///|
/// A translate transform.
pub fn Transform::translate(tx : Abs, ty : Abs) -> Transform {
  { ..Transform::identity(), tx, ty, }
}

///|
/// A scale transform.
pub fn Transform::scale(sx : Ratio, sy : Ratio) -> Transform {
  { ..Transform::identity(), sx, sy, }
}

///|
/// A scale transform at a specific position.
pub fn Transform::scale_at(
  sx : Ratio,
  sy : Ratio,
  px : Abs,
  py : Abs,
) -> Transform {
  Transform::translate(px, py)
  .pre_concat(Transform::scale(sx, sy))
  .pre_concat(Transform::translate(-px, -py))
}

///|
/// A rotate transform at a specific position.
pub fn Transform::rotate_at(angle : Angle, px : Abs, py : Abs) -> Transform {
  Transform::translate(px, py)
  .pre_concat(Transform::rotate(angle))
  .pre_concat(Transform::translate(-px, -py))
}

///|
/// A rotate transform.
pub fn Transform::rotate(angle : Angle) -> Transform {
  let cos = Ratio::new(angle.cos())
  let sin = Ratio::new(angle.sin())
  { ..Transform::default(), sx: cos, ky: sin, kx: -sin, sy: cos, }
}

///|
/// A skew transform.
pub fn Transform::skew(ax : Angle, ay : Angle) -> Transform {
  {
    ..Transform::identity(),
    kx: Ratio::new(ax.tan()),
    ky: Ratio::new(ay.tan()),
  }
}

///|
/// Whether this is the identity transformation.
pub fn Transform::is_identity(self : Transform) -> Bool {
  self == Transform::identity()
}

///|
/// Whether this transformation only scales along the X and Y axis.
pub fn Transform::is_only_scale(self : Transform) -> Bool {
  self.ky == Ratio::zero() &&
  self.kx == Ratio::zero() &&
  self.tx == Abs::zero() &&
  self.ty == Abs::zero()
}

///|
/// Whether this transformation only translates along the X and Y axis.
pub fn Transform::is_only_translate(self : Transform) -> Bool {
  self.sx == Ratio::one() &&
  self.sy == Ratio::one() &&
  self.ky == Ratio::zero() &&
  self.kx == Ratio::zero()
}

///|
/// Pre-concatenate another transformation.
pub fn Transform::pre_concat(self : Transform, prev : Transform) -> Transform {
  {
    sx: self.sx.mul_ratio(prev.sx) + self.kx.mul_ratio(prev.ky),
    ky: self.ky.mul_ratio(prev.sx) + self.sy.mul_ratio(prev.ky),
    kx: self.sx.mul_ratio(prev.kx) + self.kx.mul_ratio(prev.sy),
    sy: self.ky.mul_ratio(prev.kx) + self.sy.mul_ratio(prev.sy),
    tx: self.sx.of(prev.tx) + self.kx.of(prev.ty) + self.tx,
    ty: self.ky.of(prev.tx) + self.sy.of(prev.ty) + self.ty,
  }
}

///|
/// Post-concatenate another transformation.
pub fn Transform::post_concat(self : Transform, next : Transform) -> Transform {
  next.pre_concat(self)
}

///|
/// Inverts the transformation.
///
/// Returns `None` if the determinant of the matrix is zero.
pub fn Transform::invert(self : Transform) -> Transform? {
  // Allow the trivial case to be inlined.
  if self.is_identity() {
    return Some(self)
  }

  // Fast path for scale-translate-only transforms.
  if self.kx.is_zero() && self.ky.is_zero() {
    if self.sx.is_zero() || self.sy.is_zero() {
      return Some(Transform::translate(-self.tx, -self.ty))
    }
    let inv_x = 1.0 / self.sx.get()
    let inv_y = 1.0 / self.sy.get()
    return Some({
      sx: Ratio::new(inv_x),
      ky: Ratio::zero(),
      kx: Ratio::zero(),
      sy: Ratio::new(inv_y),
      tx: (-self.tx).times(inv_x),
      ty: (-self.ty).times(inv_y),
    })
  }
  let det = self.sx.mul_ratio(self.sy) - self.kx.mul_ratio(self.ky)
  if det.get().abs() < 1.0e-12 {
    return None
  }
  let inv_det = 1.0 / det.get()
  Some({
    sx: self.sy.times(inv_det),
    ky: (-self.ky).times(inv_det),
    kx: (-self.kx).times(inv_det),
    sy: self.sx.times(inv_det),
    tx: Abs::pt(
      (self.kx.get() * self.ty.to_pt() - self.sy.get() * self.tx.to_pt()) *
      inv_det,
    ),
    ty: Abs::pt(
      (self.ky.get() * self.tx.to_pt() - self.sx.get() * self.ty.to_pt()) *
      inv_det,
    ),
  })
}
