// Port of the castable value types of `typst-library/src/model/footnote.rs`
// (`FootnoteBody`, `Packed<FootnoteElem>`).

///|
/// The body of a footnote can be either some content or a label referencing
/// another footnote.
pub(all) enum FootnoteBody {
  Content(Content)
  Reference(Label)
} derive(Eq)

///|
pub impl Reflect for FootnoteBody with fn input() {
  Content::input().union_with(Type(Type::label()))
}

///|
pub impl Reflect for FootnoteBody with fn output() {
  FootnoteBody::input()
}

///|
pub impl Reflect for FootnoteBody with fn castable(v) {
  Content::castable(v) || v is Label(_)
}

///|
pub impl IntoValue for FootnoteBody with fn into_value(self) {
  match self {
    Content(v) => Content(v)
    Reference(v) => Label(v)
  }
}

///|
pub impl FromValue for FootnoteBody with fn from_value(v) {
  if Content::castable(v) {
    return Content(Content::from_value(v))
  }
  match v {
    Label(label) => Reference(label)
    v => raise HintedError(FootnoteBody::input().error(v))
  }
}

///|
/// A footnote (upstream `Packed<FootnoteElem>`).
pub(all) struct FootnoteElem(Content) derive(Eq)

///|
/// Creates a new footnote that the passed content as its body.
pub fn FootnoteElem::with_content(content : Content) -> FootnoteElem {
  FootnoteElem(
    Content::new(footnote_elem(), [(footnote_elem_body, Content(content))]),
  )
}

///|
pub impl Reflect for FootnoteElem with fn input() {
  Content::input()
}

///|
pub impl Reflect for FootnoteElem with fn output() {
  Content::output()
}

///|
pub impl Reflect for FootnoteElem with fn castable(v) {
  Content::castable(v)
}

///|
pub impl IntoValue for FootnoteElem with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for FootnoteElem with fn from_value(v) {
  // Upstream `Packed<T>::from_value` with `v.unpack::<Self>()
  // .unwrap_or_else(Self::with_content)`.
  let content : Content = FromValue::from_value(v)
  if content.is_(footnote_elem()) {
    return FootnoteElem(content)
  }
  let span = if v is Content(_) {
    content.span()
  } else {
    @syntax.Span::detached()
  }
  FootnoteElem(FootnoteElem::with_content(content).0.spanned(span))
}
