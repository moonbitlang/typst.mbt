// Port of `tiny-skia-path` 0.12.0 `src/transform.rs`.

///|
/// An affine transformation matrix.
///
/// Unlike other types, doesn't guarantee to be valid. This is Skia quirk.
/// Meaning Transform(0, 0, 0, 0, 0, 0) is ok, while it's technically not.
/// Non-finite values are also not an error.
pub(all) struct Transform {
  sx : Float
  kx : Float
  ky : Float
  sy : Float
  tx : Float
  ty : Float
} derive(Eq, Debug)

///|
pub impl Default for Transform with fn default() {
  Transform::identity()
}

///|
/// Creates an identity transform.
pub fn Transform::identity() -> Transform {
  { sx: 1.0, kx: 0.0, ky: 0.0, sy: 1.0, tx: 0.0, ty: 0.0, }
}

///|
/// Creates a new `Transform`.
///
/// We are using column-major-column-vector matrix notation, therefore it's
/// ky-kx, not kx-ky.
pub fn Transform::from_row(
  sx : Float,
  ky : Float,
  kx : Float,
  sy : Float,
  tx : Float,
  ty : Float,
) -> Transform {
  { sx, ky, kx, sy, tx, ty, }
}

///|
/// Creates a new translating `Transform`.
pub fn Transform::from_translate(tx : Float, ty : Float) -> Transform {
  Transform::from_row(1.0, 0.0, 0.0, 1.0, tx, ty)
}

///|
/// Creates a new scaling `Transform`.
pub fn Transform::from_scale(sx : Float, sy : Float) -> Transform {
  Transform::from_row(sx, 0.0, 0.0, sy, 0.0, 0.0)
}

///|
/// Creates a new skewing `Transform`.
pub fn Transform::from_skew(kx : Float, ky : Float) -> Transform {
  Transform::from_row(1.0, ky, kx, 1.0, 0.0, 0.0)
}

///|
/// Creates a new rotating `Transform`.
///
/// `angle` in degrees.
pub fn Transform::from_rotate(angle : Float) -> Transform {
  // f32::to_radians: `self * (consts::PI / 180.0)`
  let v = angle * (float_pi / 180.0)
  // LLVM merges the adjacent `cos`/`sin` calls into one `sincosf`.
  let a = libm_sincosf_cos(v)
  let b = libm_sincosf_sin(v)
  let c = -b
  let d = a
  Transform::from_row(a, b, c, d, 0.0, 0.0)
}

///|
/// Creates a new rotating `Transform` at the specified position.
///
/// `angle` in degrees.
pub fn Transform::from_rotate_at(
  angle : Float,
  tx : Float,
  ty : Float,
) -> Transform {
  let mut ts = Transform::identity()
  ts = ts.pre_translate(tx, ty)
  ts = ts.pre_concat(Transform::from_rotate(angle))
  ts = ts.pre_translate(-tx, -ty)
  ts
}

///|
/// Converts `Rect` into a bounding box `Transform`.
pub fn Transform::from_bbox(bbox : NonZeroRect) -> Transform {
  Transform::from_row(bbox.width(), 0.0, 0.0, bbox.height(), bbox.x(), bbox.y())
}

///|
/// Checks that transform is finite.
pub fn Transform::is_finite(self : Transform) -> Bool {
  is_finite(self.sx) &&
  is_finite(self.ky) &&
  is_finite(self.kx) &&
  is_finite(self.sy) &&
  is_finite(self.tx) &&
  is_finite(self.ty)
}

///|
/// Checks that transform is finite and has non-zero scale.
pub fn Transform::is_valid(self : Transform) -> Bool {
  if self.is_finite() {
    let (sx, sy) = self.get_scale()
    let eps = Float::reinterpret_from_uint(0x34000000) // f32::EPSILON
    !(is_nearly_zero_within_tolerance(sx, eps) ||
    is_nearly_zero_within_tolerance(sy, eps))
  } else {
    false
  }
}

///|
/// Checks that transform is identity.
pub fn Transform::is_identity(self : Transform) -> Bool {
  self == Transform::identity()
}

///|
/// Checks that transform is scale-only.
pub fn Transform::is_scale(self : Transform) -> Bool {
  self.has_scale() && !self.has_skew() && !self.has_translate()
}

///|
/// Checks that transform is skew-only.
pub fn Transform::is_skew(self : Transform) -> Bool {
  !self.has_scale() && self.has_skew() && !self.has_translate()
}

///|
/// Checks that transform is translate-only.
pub fn Transform::is_translate(self : Transform) -> Bool {
  !self.has_scale() && !self.has_skew() && self.has_translate()
}

///|
/// Checks that transform contains only scale and translate.
pub fn Transform::is_scale_translate(self : Transform) -> Bool {
  (self.has_scale() || self.has_translate()) && !self.has_skew()
}

///|
/// Checks that transform contains a scale part.
pub fn Transform::has_scale(self : Transform) -> Bool {
  self.sx != 1.0 || self.sy != 1.0
}

///|
/// Checks that transform contains a skew part.
pub fn Transform::has_skew(self : Transform) -> Bool {
  self.kx != 0.0 || self.ky != 0.0
}

///|
/// Checks that transform contains a translate part.
pub fn Transform::has_translate(self : Transform) -> Bool {
  self.tx != 0.0 || self.ty != 0.0
}

///|
/// Returns transform's scale part.
pub fn Transform::get_scale(self : Transform) -> (Float, Float) {
  let x_scale = (self.sx * self.sx + self.kx * self.kx).sqrt()
  let y_scale = (self.ky * self.ky + self.sy * self.sy).sqrt()
  (x_scale, y_scale)
}

///|
/// Pre-scales the current transform.
pub fn Transform::pre_scale(
  self : Transform,
  sx : Float,
  sy : Float,
) -> Transform {
  self.pre_concat(Transform::from_scale(sx, sy))
}

///|
/// Post-scales the current transform.
pub fn Transform::post_scale(
  self : Transform,
  sx : Float,
  sy : Float,
) -> Transform {
  self.post_concat(Transform::from_scale(sx, sy))
}

///|
/// Pre-translates the current transform.
pub fn Transform::pre_translate(
  self : Transform,
  tx : Float,
  ty : Float,
) -> Transform {
  self.pre_concat(Transform::from_translate(tx, ty))
}

///|
/// Post-translates the current transform.
pub fn Transform::post_translate(
  self : Transform,
  tx : Float,
  ty : Float,
) -> Transform {
  self.post_concat(Transform::from_translate(tx, ty))
}

///|
/// Pre-rotates the current transform.
///
/// `angle` in degrees.
pub fn Transform::pre_rotate(self : Transform, angle : Float) -> Transform {
  self.pre_concat(Transform::from_rotate(angle))
}

///|
/// Post-rotates the current transform.
///
/// `angle` in degrees.
pub fn Transform::post_rotate(self : Transform, angle : Float) -> Transform {
  self.post_concat(Transform::from_rotate(angle))
}

///|
/// Pre-rotates the current transform by the specified position.
///
/// `angle` in degrees.
pub fn Transform::pre_rotate_at(
  self : Transform,
  angle : Float,
  tx : Float,
  ty : Float,
) -> Transform {
  self.pre_concat(Transform::from_rotate_at(angle, tx, ty))
}

///|
/// Post-rotates the current transform by the specified position.
///
/// `angle` in degrees.
pub fn Transform::post_rotate_at(
  self : Transform,
  angle : Float,
  tx : Float,
  ty : Float,
) -> Transform {
  self.post_concat(Transform::from_rotate_at(angle, tx, ty))
}

///|
/// Pre-concats the current transform.
pub fn Transform::pre_concat(self : Transform, other : Transform) -> Transform {
  concat(self, other)
}

///|
/// Post-concats the current transform.
pub fn Transform::post_concat(self : Transform, other : Transform) -> Transform {
  concat(other, self)
}

///|
fn Transform::from_sin_cos(sin : Float, cos : Float) -> Transform {
  Transform::from_row(cos, sin, -sin, cos, 0.0, 0.0)
}

///|
/// Transforms a point using the current transform.
///
/// Returns the mapped point (upstream maps `&mut Point` in place).
pub fn Transform::map_point(self : Transform, point : Point) -> Point {
  if self.is_identity() {
    // Do nothing.
    point
  } else if self.is_translate() {
    { x: point.x + self.tx, y: point.y + self.ty, }
  } else if self.is_scale_translate() {
    { x: point.x * self.sx + self.tx, y: point.y * self.sy + self.ty, }
  } else {
    let x = point.x * self.sx + point.y * self.kx + self.tx
    let y = point.x * self.ky + point.y * self.sy + self.ty
    { x, y, }
  }
}

///|
/// Transforms an array of points in-place using the current transform.
pub fn Transform::map_points(self : Transform, points : Array[Point]) -> Unit {
  if points.is_empty() {
    return
  }

  // TODO: simd

  if self.is_identity() {
    // Do nothing.
  } else if self.is_translate() {
    for i in 0..<points.length() {
      let p = points[i]
      points[i] = { x: p.x + self.tx, y: p.y + self.ty, }
    }
  } else if self.is_scale_translate() {
    for i in 0..<points.length() {
      let p = points[i]
      points[i] = { x: p.x * self.sx + self.tx, y: p.y * self.sy + self.ty, }
    }
  } else {
    for i in 0..<points.length() {
      let p = points[i]
      let x = p.x * self.sx + p.y * self.kx + self.tx
      let y = p.x * self.ky + p.y * self.sy + self.ty
      points[i] = { x, y, }
    }
  }
}

///|
/// Returns an inverted transform.
pub fn Transform::invert(self : Transform) -> Transform? {
  // Allow the trivial case to be inlined.
  if self.is_identity() {
    return Some(self)
  }
  invert_impl(self)
}

///|
fn invert_impl(ts : Transform) -> Transform? {
  if ts.is_scale_translate() {
    if ts.has_scale() {
      let inv_x = invert(ts.sx)
      let inv_y = invert(ts.sy)
      Some(
        Transform::from_row(
          inv_x,
          0.0,
          0.0,
          inv_y,
          -ts.tx * inv_x,
          -ts.ty * inv_y,
        ),
      )
    } else {
      // translate only
      Some(Transform::from_translate(-ts.tx, -ts.ty))
    }
  } else {
    guard inv_determinant(ts) is Some(inv_det) else { return None }
    let inv_ts = compute_inv(ts, inv_det)
    if inv_ts.is_finite() {
      Some(inv_ts)
    } else {
      None
    }
  }
}

///|
fn inv_determinant(ts : Transform) -> Double? {
  let det = dcross(
    ts.sx.to_double(),
    ts.sy.to_double(),
    ts.kx.to_double(),
    ts.ky.to_double(),
  )

  // Since the determinant is on the order of the cube of the matrix members,
  // compare to the cube of the default nearly-zero constant (although an
  // estimate of the condition number would be better if it wasn't so expensive).
  let tolerance = scalar_nearly_zero * scalar_nearly_zero * scalar_nearly_zero
  if is_nearly_zero_within_tolerance(Float::from_double(det), tolerance) {
    None
  } else {
    Some(1.0 / det)
  }
}

///|
fn compute_inv(ts : Transform, inv_det : Double) -> Transform {
  Transform::from_row(
    Float::from_double(ts.sy.to_double() * inv_det),
    Float::from_double((-ts.ky).to_double() * inv_det),
    Float::from_double((-ts.kx).to_double() * inv_det),
    Float::from_double(ts.sx.to_double() * inv_det),
    dcross_dscale(ts.kx, ts.ty, ts.sy, ts.tx, inv_det),
    dcross_dscale(ts.ky, ts.tx, ts.sx, ts.ty, inv_det),
  )
}

///|
fn dcross(a : Double, b : Double, c : Double, d : Double) -> Double {
  a * b - c * d
}

///|
fn dcross_dscale(
  a : Float,
  b : Float,
  c : Float,
  d : Float,
  scale : Double,
) -> Float {
  Float::from_double(
    dcross(a.to_double(), b.to_double(), c.to_double(), d.to_double()) * scale,
  )
}

///|
fn concat(a : Transform, b : Transform) -> Transform {
  if a.is_identity() {
    b
  } else if b.is_identity() {
    a
  } else if !a.has_skew() && !b.has_skew() {
    // just scale and translate
    Transform::from_row(
      a.sx * b.sx,
      0.0,
      0.0,
      a.sy * b.sy,
      a.sx * b.tx + a.tx,
      a.sy * b.ty + a.ty,
    )
  } else {
    Transform::from_row(
      mul_add_mul(a.sx, b.sx, a.kx, b.ky),
      mul_add_mul(a.ky, b.sx, a.sy, b.ky),
      mul_add_mul(a.sx, b.kx, a.kx, b.sy),
      mul_add_mul(a.ky, b.kx, a.sy, b.sy),
      mul_add_mul(a.sx, b.tx, a.kx, b.ty) + a.tx,
      mul_add_mul(a.ky, b.tx, a.sy, b.ty) + a.ty,
    )
  }
}

///|
fn mul_add_mul(a : Float, b : Float, c : Float, d : Float) -> Float {
  Float::from_double(
    a.to_double() * b.to_double() + c.to_double() * d.to_double(),
  )
}
