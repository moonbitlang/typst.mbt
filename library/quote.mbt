// Port of the castable value types of `typst-library/src/model/quote.rs`
// (`Attribution`) and the `QuoteElem` field hooks.

///|
/// Attribution for a quote.
pub(all) enum Attribution {
  Content(Content)
  Label(Label)
} derive(Eq)

///|
pub impl Reflect for Attribution with fn input() {
  Content::input().union_with(Type(Type::label()))
}

///|
pub impl Reflect for Attribution with fn output() {
  Attribution::input()
}

///|
pub impl Reflect for Attribution with fn castable(v) {
  Content::castable(v) || v is Label(_)
}

///|
pub impl IntoValue for Attribution with fn into_value(self) {
  match self {
    Content(content) => Content(content)
    Label(label) => Label(label)
  }
}

///|
pub impl FromValue for Attribution with fn from_value(v) {
  if Content::castable(v) {
    return Content(Content::from_value(v))
  }
  match v {
    Label(label) => Label(label)
    v => raise HintedError(Attribution::input().error(v))
  }
}

///|
/// Realize as an em dash followed by text or a citation.
pub fn Attribution::realize(self : Attribution, span : @syntax.Span) -> Content {
  Content::sequence([
    TextElem::packed("—"),
    SpaceElem::shared(),
    match self {
      Content(content) => content
      Label(label) =>
        CiteElem::new(label)
        .with_form(Some(CitationForm::Prose))
        .pack()
        .spanned(span)
    },
  ])
}

///|
/// Wraps the body in language-dependent quotes, alternating between double
/// and single quotes with the nesting depth.
pub fn QuoteElem::quoted(body : Content, styles : StyleChain) -> Content {
  let quotes = SmartQuotes::get_in(styles)

  // Alternate between single and double quotes.
  let Depth(depth) = QuoteElem::depth_in(styles)
  let double = depth % 2 == 0
  Content::sequence([
    TextElem::packed(quotes.open(double)),
    body,
    TextElem::packed(quotes.close(double)),
  ]).styled(QuoteElem::set_depth(Depth(1)))
}

///|
fn quote_elem_depth_default() -> Value {
  Depth::default().into_value()
}

///|
fn quote_elem_depth_fold(inner : Value, outer : Value) -> Value {
  fold_of((Ty::new() : Ty[Depth]))(inner, outer)
}
