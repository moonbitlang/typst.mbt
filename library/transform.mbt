// Port of the castable value types of `typst-library/src/layout/transform.rs`
// (`ScaleAmount`) and the `ScaleElem` field defaults.

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
