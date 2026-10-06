// Port of the castable value types of `typst-library/src/model/enum.rs`
// (`EnumItem`) and the `EnumElem` field hooks. `Numbering` is ported with
// the introspection/numbering module.

///|
/// An enumeration item (upstream `Packed<EnumItem>`).
pub(all) struct EnumItem(Content) derive(Eq)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EnumItem with Eq::{not_equal, equal}

///|
/// Create a new enum item with the given body.
pub fn EnumItem::new(body : Content) -> EnumItem {
  EnumItem(
    Content::new(enum_item_elem(), [(enum_item_elem_body, Content(body))]),
  )
}

///|
pub impl Reflect for EnumItem with fn input() {
  Content::input()
}

///|
pub impl Reflect for EnumItem with fn output() {
  Content::output()
}

///|
pub impl Reflect for EnumItem with fn castable(v) {
  Content::castable(v)
}

///|
#deprecated("call as `Reflect::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EnumItem with Reflect::{output, input, castable}

///|
pub impl IntoValue for EnumItem with fn into_value(self) {
  Content(self.0)
}

///|
#deprecated("call as `IntoValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EnumItem with IntoValue::{into_value}

///|
pub impl FromValue for EnumItem with fn from_value(v) {
  // Upstream `Packed<T>::from_value` with `v.unpack::<Self>()
  // .unwrap_or_else(Self::new)`.
  let content : Content = FromValue::from_value(v)
  if content.is_(enum_item_elem()) {
    return EnumItem(content)
  }
  let span = if v is Content(_) {
    content.span()
  } else {
    @syntax.Span::detached()
  }
  EnumItem(EnumItem::new(content).0.spanned(span))
}

///|
#deprecated("call as `FromValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend EnumItem with FromValue::{from_value}

///|
fn enum_elem_number_align_default() -> Value {
  Dyn(Alignment(H(End)))
}

///|
/// Upstream `Fold for SmallVec`: the outer values extended by the inner ones.
fn enum_elem_parents_fold(inner : Value, outer : Value) -> Value {
  match (inner, outer) {
    (Array(inner), Array(outer)) =>
      Array(Arr::from_array(outer.items.copy() + inner.items))
    _ => inner
  }
}
