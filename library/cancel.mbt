// Port of the types of `typst-library/src/math/cancel.rs` (`CancelAngle`)
// and the `CancelElem` field defaults. The element is generated.

///|
fn cancel_elem_length_default() -> Value {
  Relative(Rel::new(Ratio::one(), Length::from_em(Em::new(0.3))))
}

///|
fn cancel_elem_stroke_default() -> Value {
  // Default stroke has 0.05em for better visuals.
  Dyn(
    Stroke({
      ..Stroke::default(),
      thickness: Custom(Length::from_em(Em::new(0.05))),
    }),
  )
}

///|
/// Defines the cancel line.
pub(all) enum CancelAngle {
  Angle(Angle)
  Func(Func)
} derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CancelAngle with Eq::{not_equal, equal}

///|
pub impl Reflect for CancelAngle with fn input() {
  CastInfo::Type(Type::angle()).union_with(Type(Type::func()))
}

///|
pub impl Reflect for CancelAngle with fn output() {
  CastInfo::Type(Type::angle()).union_with(Type(Type::func()))
}

///|
pub impl Reflect for CancelAngle with fn castable(v) {
  castable_of((Ty::new() : Ty[Angle]), v) ||
  castable_of((Ty::new() : Ty[Func]), v)
}

///|
pub extend CancelAngle with Reflect::{output, input, castable}

///|
pub impl IntoValue for CancelAngle with fn into_value(self) {
  match self {
    Angle(v) => IntoValue::into_value(v)
    Func(v) => IntoValue::into_value(v)
  }
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CancelAngle with IntoValue::{into_value}

///|
pub impl FromValue for CancelAngle with fn from_value(v) {
  if castable_of((Ty::new() : Ty[Angle]), v) {
    Angle(v.cast())
  } else if castable_of((Ty::new() : Ty[Func]), v) {
    Func(v.cast())
  } else {
    raise HintedError(CancelAngle::input().error(v))
  }
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CancelAngle with FromValue::{from_value}
