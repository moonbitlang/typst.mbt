// Port of `typst-library/src/layout/angle.rs`.

///|
/// An angle describing a rotation.
pub(all) struct Angle(Scalar) derive(Default, Eq, Compare, Hash)

///|
#deprecated("call as `Default::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Angle with Default::{default}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Angle with Eq::{not_equal, equal}

///|
pub extend Angle with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Angle with Hash::{hash, hash_combine}

///|
/// Different units of angular measurement.
pub(all) enum AngleUnit {
  Rad
  Deg
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AngleUnit with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AngleUnit with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AngleUnit with @debug.Debug::{to_repr}

///|
fn AngleUnit::raw_scale(self : AngleUnit) -> Double {
  match self {
    Rad => 1.0
    Deg => @math.PI / 180.0
  }
}

///|
/// A quadrant of the Cartesian plane.
pub(all) enum Quadrant {
  First
  Second
  Third
  Fourth
} derive(Eq, Hash, Debug, Compare)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Quadrant with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Quadrant with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Quadrant with @debug.Debug::{to_repr}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Quadrant with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
pub fn Angle::zero() -> Angle {
  Angle(Scalar(0.0))
}

///|
pub fn Angle::raw(raw : Double) -> Angle {
  Angle(Scalar::new(raw))
}

///|
pub fn Angle::with_unit(val : Double, unit : AngleUnit) -> Angle {
  Angle(Scalar::new(val * unit.raw_scale()))
}

///|
pub fn Angle::rad(rad : Double) -> Angle {
  Angle::with_unit(rad, Rad)
}

///|
pub fn Angle::deg(deg : Double) -> Angle {
  Angle::with_unit(deg, Deg)
}

///|
/// Create an angle from a ratio of a full turn.
pub fn Angle::from_ratio(r : Ratio) -> Angle {
  Angle::rad(r.get() * 2.0 * @math.PI)
}

///|
pub fn Angle::to_raw(self : Angle) -> Double {
  self.0.0
}

///|
pub fn Angle::to_unit(self : Angle, unit : AngleUnit) -> Double {
  self.to_raw() / unit.raw_scale()
}

///|
/// Converts this angle to radians.
pub fn Angle::to_rad(self : Angle) -> Double {
  self.to_unit(Rad)
}

///|
/// Converts this angle to degrees.
pub fn Angle::to_deg(self : Angle) -> Double {
  self.to_unit(Deg)
}

///|
/// Converts this angle to radians (`angle.rad`).
fn impl_angle_to_rad(self_ : Angle) -> Double {
  self_.to_rad()
}

///|
/// Converts this angle to degrees (`angle.deg`).
fn impl_angle_to_deg(self_ : Angle) -> Double {
  self_.to_deg()
}

///|
/// The angle normalized to `[0, 2π)`.
pub fn Angle::normalized(self : Angle) -> Angle {
  Angle::rad(rem_euclid(self.to_rad(), 2.0 * @math.PI))
}

///|
pub fn Angle::abs(self : Angle) -> Angle {
  Angle::raw(self.to_raw().abs())
}

///|
/// (Upstream uses the `libm` crate, see `libm_trig.mbt`.)
pub fn Angle::sin(self : Angle) -> Double {
  libm_sin(self.to_rad())
}

///|
/// (Upstream uses the `libm` crate, see `libm_trig.mbt`.)
pub fn Angle::cos(self : Angle) -> Double {
  libm_cos(self.to_rad())
}

///|
pub fn Angle::tan(self : Angle) -> Double {
  libm_tan(self.to_rad())
}

///|
pub fn Angle::asin(x : Double) -> Angle {
  Angle::rad(libm_asin(x))
}

///|
pub fn Angle::acos(x : Double) -> Angle {
  Angle::rad(libm_acos(x))
}

///|
pub fn Angle::atan(x : Double) -> Angle {
  Angle::rad(libm_atan(x))
}

///|
pub fn Angle::atan2(y : Double, x : Double) -> Angle {
  Angle::rad(libm_atan2(y, x))
}

///|
/// Get the quadrant of the Cartesian plane that this angle lies in.
pub fn Angle::quadrant(self : Angle) -> Quadrant {
  let angle = rem_euclid(self.to_deg(), 360.0)
  if angle <= 90.0 {
    First
  } else if angle <= 180.0 {
    Second
  } else if angle <= 270.0 {
    Third
  } else {
    Fourth
  }
}

///|
pub fn Angle::repr(self : Angle) -> String {
  format_float_with_unit(self.to_deg(), "deg")
}
