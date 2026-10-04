// Port of the castable value types of `typst-library/src/model/list.rs`
// (`ListItem`, `ListMarker`) and the `ListElem` field hooks.

///|
/// A bullet list item (upstream `Packed<ListItem>`).
pub(all) struct ListItem(Content) derive(Eq)

///|
/// Create a new list item with the given body.
pub fn ListItem::new(body : Content) -> ListItem {
  ListItem(
    Content::new(list_item_elem(), [(list_item_elem_body, Content(body))]),
  )
}

///|
pub impl Reflect for ListItem with fn input() {
  Content::input()
}

///|
pub impl Reflect for ListItem with fn output() {
  Content::output()
}

///|
pub impl Reflect for ListItem with fn castable(v) {
  Content::castable(v)
}

///|
pub impl IntoValue for ListItem with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for ListItem with fn from_value(v) {
  // Upstream `Packed<T>::from_value` with `v.unpack::<Self>()
  // .unwrap_or_else(Self::new)`.
  let content : Content = FromValue::from_value(v)
  if content.is_(list_item_elem()) {
    return ListItem(content)
  }
  let span = if v is Content(_) {
    content.span()
  } else {
    @syntax.Span::detached()
  }
  ListItem(ListItem::new(content).0.spanned(span))
}

///|
/// A list's marker.
pub(all) enum ListMarker {
  Content(Array[Content])
  Func(Func)
} derive(Eq)

///|
pub impl Reflect for ListMarker with fn input() {
  Content::input()
  .union_with(Type(Type::array()))
  .union_with(Type(Type::func()))
}

///|
pub impl Reflect for ListMarker with fn output() {
  ListMarker::input()
}

///|
pub impl Reflect for ListMarker with fn castable(v) {
  Content::castable(v) || v is Array(_) || Func::castable(v)
}

///|
pub impl IntoValue for ListMarker with fn into_value(self) {
  match self {
    Content(vec) =>
      if vec.length() == 1 {
        Content(vec[0])
      } else {
        IntoValue::into_value(vec)
      }
    Func(func) => Func(func)
  }
}

///|
pub impl FromValue for ListMarker with fn from_value(v) {
  if Content::castable(v) {
    return Content([Content::from_value(v)])
  }
  match v {
    Array(array) => {
      if array.items.is_empty() {
        bail("array must contain at least one marker")
      }
      Content(array.items.map(v => v.display()))
    }
    v if Func::castable(v) => Func(Func::from_value(v))
    v => raise HintedError(ListMarker::input().error(v))
  }
}

///|
fn list_elem_marker_default() -> Value {
  ListMarker::Content([
    TextElem::packed("\u{2022}"),
    TextElem::packed("\u{2023}"),
    TextElem::packed("\u{2013}"),
  ]).into_value()
}

///|
fn list_elem_marker_align_default() -> Value {
  Dyn(Alignment(H(End)))
}

///|
fn list_elem_depth_default() -> Value {
  Depth::default().into_value()
}

///|
fn list_elem_depth_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[Depth]), inner, outer)
}
