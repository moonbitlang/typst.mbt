// Port of the castable value types of `typst-library/src/model/terms.rs`
// (`TermItem`) and the `TermsElem` field defaults.

///|
/// A term list item (upstream `Packed<TermItem>`).
pub(all) struct TermItem(Content) derive(Eq)

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
pub impl IntoValue for TermItem with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for TermItem with fn from_value(v) {
  let content : Content = FromValue::from_value(v)
  if content.is_(term_item_elem()) {
    return TermItem(content)
  }
  bail("expected term item or array")
}

///|
fn terms_elem_separator_default() -> Value {
  Content(
    Content::new(h_elem(), [
      (h_elem_amount, Length(Length::from_em(Em::new(0.6)))),
    ]).with_field(h_elem_weak, Bool(true)),
  )
}
