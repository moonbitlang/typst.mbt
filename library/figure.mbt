// Port of the castable value types of `typst-library/src/model/figure.rs`
// (`FigureKind`, `FigureCaption`).

///|
/// The `kind` parameter of a figure.
pub(all) enum FigureKind {
  /// The kind is an element function.
  Elem(Element)
  /// The kind is a name.
  Name(String)
} derive(Eq)

///|
pub impl Reflect for FigureKind with fn input() {
  Element::input().union_with(Type(Type::str()))
}

///|
pub impl Reflect for FigureKind with fn output() {
  FigureKind::input()
}

///|
pub impl Reflect for FigureKind with fn castable(v) {
  Element::castable(v) || str_castable(v)
}

///|
pub impl IntoValue for FigureKind with fn into_value(self) {
  match self {
    Elem(v) => v.into_value()
    Name(v) => Str(v)
  }
}

///|
pub impl FromValue for FigureKind with fn from_value(v) {
  if Element::castable(v) {
    return Elem(Element::from_value(v))
  }
  if str_castable(v) {
    return Name(FromValue::from_value(v))
  }
  raise HintedError(FigureKind::input().error(v))
}

///|
/// The caption of a figure (upstream `Packed<FigureCaption>`).
pub(all) struct FigureCaption(Content) derive(Eq)

///|
/// Create a new figure caption with the given body.
pub fn FigureCaption::new(body : Content) -> FigureCaption {
  FigureCaption(
    Content::new(figure_caption_elem(), [
      (figure_caption_elem_body, Content(body)),
    ]),
  )
}

///|
pub impl Reflect for FigureCaption with fn input() {
  Content::input()
}

///|
pub impl Reflect for FigureCaption with fn output() {
  Content::output()
}

///|
pub impl Reflect for FigureCaption with fn castable(v) {
  Content::castable(v)
}

///|
pub impl IntoValue for FigureCaption with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for FigureCaption with fn from_value(v) {
  // Upstream `Packed<T>::from_value` with `v.unpack::<Self>()
  // .unwrap_or_else(Self::new)`.
  let content : Content = FromValue::from_value(v)
  if content.is_(figure_caption_elem()) {
    return FigureCaption(content)
  }
  let span = if v is Content(_) {
    content.span()
  } else {
    @syntax.Span::detached()
  }
  FigureCaption(FigureCaption::new(content).0.spanned(span))
}
