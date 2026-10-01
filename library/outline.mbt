// Port of the castable value types of `typst-library/src/model/outline.rs`
// (`OutlineIndent`) and the `OutlineEntry` field defaults.

///|
/// Defines how an outline is indented.
pub(all) enum OutlineIndent {
  /// Indents by the specified length per level.
  Rel(Rel[Length])
  /// Resolve the indent for a specific level through the given function.
  Func(Func)
} derive(Eq)

///|
pub impl Reflect for OutlineIndent with fn input() {
  CastInfo::Type(Type::relative()).union_with(Type(Type::func()))
}

///|
pub impl Reflect for OutlineIndent with fn output() {
  OutlineIndent::input()
}

///|
pub impl Reflect for OutlineIndent with fn castable(v) {
  v is (Relative(_) | Length(_) | Ratio(_)) || Func::castable(v)
}

///|
pub impl IntoValue for OutlineIndent with fn into_value(self) {
  match self {
    Rel(v) => Relative(v)
    Func(v) => Func(v)
  }
}

///|
pub impl FromValue for OutlineIndent with fn from_value(v) {
  match v {
    Relative(_) | Length(_) | Ratio(_) => Rel(FromValue::from_value(v))
    v if Func::castable(v) => Func(Func::from_value(v))
    v => raise HintedError(OutlineIndent::input().error(v))
  }
}

///|
/// Upstream `Some(RepeatElem::new(TextElem::packed("."))
/// .with_gap(Em::new(0.15).into()).pack())`.
fn outline_entry_elem_fill_default() -> Value {
  Content(
    Content::new(repeat_elem(), [
      (repeat_elem_body, Content(TextElem::packed("."))),
    ]).with_field(repeat_elem_gap, Length(Length::from_em(Em::new(0.15)))),
  )
}
