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
fn quote_elem_depth_default() -> Value {
  Depth::default().into_value()
}

///|
fn quote_elem_depth_fold(inner : Value, outer : Value) -> Value {
  fold_of((Ty::new() : Ty[Depth]))(inner, outer)
}
