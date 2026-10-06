// Port of the parts of `moxcms::matrix` used by the ICC transforms.

///|
/// Holds CIE XYZ representation (single precision).
pub(all) struct Xyz {
  x : Float
  y : Float
  z : Float
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Xyz with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Xyz with @debug.Debug::{to_repr}

///|
pub fn Xyz::new(x : Float, y : Float, z : Float) -> Xyz {
  { x, y, z, }
}

///|
pub fn Xyz::to_xyzd(self : Xyz) -> Xyzd {
  { x: self.x.to_double(), y: self.y.to_double(), z: self.z.to_double(), }
}

///|
/// Holds CIE XYZ representation (double precision).
pub(all) struct Xyzd {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Xyzd with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Xyzd with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Xyzd with Default::{default}

///|
pub fn Xyzd::new(x : Double, y : Double, z : Double) -> Xyzd {
  { x, y, z, }
}

///|
/// 3-component double vector (`Vector3d`).
pub(all) struct Vector3d {
  v0 : Double
  v1 : Double
  v2 : Double
} derive(Eq, Debug, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector3d with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector3d with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector3d with Default::{default}

///|
/// 3-component float vector (`Vector3f`).
pub(all) struct Vector3f {
  v0 : Float
  v1 : Float
  v2 : Float
} derive(Eq, Debug, Default)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector3f with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector3f with @debug.Debug::{to_repr}

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Vector3f with Default::{default}

///|
fn Vector3d::cast(self : Vector3d) -> Vector3f {
  {
    v0: Float::from_double(self.v0),
    v1: Float::from_double(self.v1),
    v2: Float::from_double(self.v2),
  }
}

///|
/// Row-major 3x3 double matrix (`Matrix3d`): `v[3 * row + col]`.
pub(all) struct Matrix3d {
  v : FixedArray[Double]
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Matrix3d with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Matrix3d with @debug.Debug::{to_repr}

///|
/// Row-major 3x3 float matrix (`Matrix3f`): `v[3 * row + col]`.
pub(all) struct Matrix3f {
  v : FixedArray[Float]
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Matrix3f with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Matrix3f with @debug.Debug::{to_repr}

///|
pub fn Matrix3d::identity() -> Matrix3d {
  { v: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], }
}

///|
pub fn Matrix3f::identity() -> Matrix3f {
  { v: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], }
}

///|
fn Matrix3d::at(self : Matrix3d, row : Int, col : Int) -> Double {
  self.v[3 * row + col]
}

///|
fn Matrix3f::at(self : Matrix3f, row : Int, col : Int) -> Float {
  self.v[3 * row + col]
}

///|
fn Matrix3d::test_equality(self : Matrix3d, other : Matrix3d) -> Bool {
  let tolerance = 0.001
  for i in 0..<9 {
    if (self.v[i] - other.v[i]).abs() > tolerance {
      return false
    }
  }
  true
}

///|
fn Matrix3f::test_equality(self : Matrix3f, other : Matrix3f) -> Bool {
  let tolerance : Float = 0.001
  for i in 0..<9 {
    if (self.v[i] - other.v[i]).abs() > tolerance {
      return false
    }
  }
  true
}

///|
fn Matrix3d::determinant(self : Matrix3d) -> Double? {
  let v = (r : Int, c : Int) => self.at(r, c)
  let a0 = v(0, 0) * v(1, 1) * v(2, 2)
  let a1 = v(0, 1) * v(1, 2) * v(2, 0)
  let a2 = v(0, 2) * v(1, 0) * v(2, 1)
  let s0 = v(0, 2) * v(1, 1) * v(2, 0)
  let s1 = v(0, 1) * v(1, 0) * v(2, 2)
  let s2 = v(0, 0) * v(1, 2) * v(2, 1)
  let j = a0 + a1 + a2 - s0 - s1 - s2
  if j == 0.0 {
    return None
  }
  Some(j)
}

///|
fn Matrix3d::inverse(self : Matrix3d) -> Matrix3d {
  match self.determinant() {
    None => Matrix3d::identity()
    Some(determinant) => {
      let det = 1.0 / determinant
      let a = self.at(0, 0)
      let b = self.at(0, 1)
      let c = self.at(0, 2)
      let d = self.at(1, 0)
      let e = self.at(1, 1)
      let f = self.at(1, 2)
      let g = self.at(2, 0)
      let h = self.at(2, 1)
      let i = self.at(2, 2)
      {
        v: [
          (e * i - f * h) * det,
          (c * h - b * i) * det,
          (b * f - c * e) * det,
          (f * g - d * i) * det,
          (a * i - c * g) * det,
          (c * d - a * f) * det,
          (d * h - e * g) * det,
          (b * g - a * h) * det,
          (a * e - b * d) * det,
        ],
      }
    }
  }
}

///|
fn Matrix3d::mat_mul(self : Matrix3d, other : Matrix3d) -> Matrix3d {
  let v = FixedArray::make(9, 0.0)
  for i in 0..<3 {
    for j in 0..<3 {
      v[3 * i + j] = mlaf_d(
        mlaf_d(self.at(i, 0) * other.at(0, j), self.at(i, 1), other.at(1, j)),
        self.at(i, 2),
        other.at(2, j),
      )
    }
  }
  { v, }
}

///|
fn Matrix3d::to_f32(self : Matrix3d) -> Matrix3f {
  { v: self.v.map(Float::from_double), }
}
