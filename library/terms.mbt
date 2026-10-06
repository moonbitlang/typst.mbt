// Port of the castable value types of `typst-library/src/model/terms.rs`
// (`TermItem`) and the `TermsElem` field defaults.

///|
/// A term list item (upstream `Packed<TermItem>`).
pub(all) struct TermItem(Content) derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TermItem with Eq::{not_equal, equal}

///|
pub impl Reflect for TermItem with fn input() {
  Content::input()
}

///|
pub impl Reflect for TermItem with fn output() {
  Content::output()
}

///|
pub impl Reflect for TermItem with fn castable(v) {
  Content::castable(v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TermItem with Reflect::{output, input, castable}

///|
pub impl IntoValue for TermItem with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TermItem with IntoValue::{into_value}

///|
pub impl FromValue for TermItem with fn from_value(v) {
  let content : Content = FromValue::from_value(v)
  if content.is_(term_item_elem()) {
    return TermItem(content)
  }
  bail("expected term item or array")
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend TermItem with FromValue::{from_value}

///|
fn terms_elem_separator_default() -> Value {
  Content(
    Content::new(h_elem(), [
      (h_elem_amount, Length(Length::from_em(Em::new(0.6)))),
    ]).with_field(h_elem_weak, Bool(true)),
  )
}
