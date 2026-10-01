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

///|
/// Retrieves the locale separator.
pub fn FigureElem::resolve_separator(
  self : FigureElem,
  styles : StyleChain,
) -> Content {
  match self.caption(styles) {
    Some(caption) => caption.resolve_separator(styles)
    None => FigureCaption::local_separator_in(styles)
  }
}

///|
/// Realizes the textual caption content.
pub fn FigureCaption::realize(
  self : FigureCaption,
  engine : Engine,
  styles : StyleChain,
) -> Content raise SourceError {
  let mut realized = self.body()
  if self.supplement() is Some(Some(supplement)) &&
    self.numbering() is Some(Some(numbering)) &&
    self.counter() is Some(Some(counter)) &&
    self.figure_location() is Some(Some(location)) {
    let numbers = counter.display_at(
      engine,
      location,
      styles,
      numbering,
      self.0.span(),
    )
    let mut supplement = supplement
    if !supplement.is_empty() {
      supplement = supplement.add(TextElem::packed("\u{a0}"))
    }
    realized = supplement
      .add(numbers)
      .add(self.resolve_separator(styles))
      .add(realized)
  }
  realized
}

///|
/// Retrieves the locale separator.
pub fn FigureCaption::resolve_separator(
  self : FigureCaption,
  styles : StyleChain,
) -> Content {
  match self.separator(styles) {
    Custom(separator) => separator
    Auto => FigureCaption::local_separator_in(styles)
  }
}

///|
/// Gets the default separator in the given language and (optionally)
/// region.
fn FigureCaption::local_separator_in(styles : StyleChain) -> Content {
  match FigureCaption::separator_in(styles) {
    Custom(separator) => separator
    Auto =>
      TextElem::packed(
        match TextElem::lang_in(styles).as_str() {
          "zh" => "\u{2003}"
          "fr" => ".\u{a0}– "
          "ru" => ". "
          _ => ": "
        },
      )
  }
}
