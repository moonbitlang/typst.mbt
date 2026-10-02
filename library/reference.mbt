// Port of the castable value types of `typst-library/src/model/reference.rs`
// (`Supplement`, `RefForm`).

///|
/// Additional content for a reference.
pub(all) enum Supplement {
  Content(Content)
  Func(Func)
} derive(Eq)

///|
pub impl Reflect for Supplement with fn input() {
  Content::input().union_with(Type(Type::func()))
}

///|
pub impl Reflect for Supplement with fn output() {
  Supplement::input()
}

///|
pub impl Reflect for Supplement with fn castable(v) {
  Content::castable(v) || Func::castable(v)
}

///|
pub impl IntoValue for Supplement with fn into_value(self) {
  match self {
    Content(v) => Content(v)
    Func(v) => Func(v)
  }
}

///|
pub impl FromValue for Supplement with fn from_value(v) {
  if Content::castable(v) {
    return Content(Content::from_value(v))
  }
  if Func::castable(v) {
    return Func(Func::from_value(v))
  }
  raise HintedError(Supplement::input().error(v))
}

///|
/// Tries to resolve the supplement into its content.
pub fn Supplement::resolve(
  self : Supplement,
  engine : Engine,
  styles : StyleChain,
  args : ArrayView[Value],
) -> Content raise SourceError {
  match self {
    Content(content) => content
    Func(func) =>
      func.call_values(engine, Context::new(styles~), args).display()
  }
}

///|
/// The form of the reference.
pub(all) enum RefForm {
  /// Produces a textual reference to a label.
  Normal
  /// Produces a page reference to a label.
  Page
} derive(Eq, Hash, Debug)

///|
pub impl Default for RefForm with fn default() {
  Normal
}

///|
let ref_form_names : Array[String] = ["normal", "page"]

///|
pub impl Reflect for RefForm with fn input() {
  str_names_input(ref_form_names)
}

///|
pub impl Reflect for RefForm with fn output() {
  RefForm::input()
}

///|
pub impl Reflect for RefForm with fn castable(v) {
  str_names_find(ref_form_names, v) is Some(_)
}

///|
pub impl IntoValue for RefForm with fn into_value(self) {
  match self {
    Normal => Str("normal")
    Page => Str("page")
  }
}

///|
pub impl FromValue for RefForm with fn from_value(v) {
  match str_names_find(ref_form_names, v) {
    Some(0) => Normal
    Some(_) => Page
    None => raise HintedError(RefForm::input().error(v))
  }
}

///|
fn ref_elem_form_default() -> Value {
  RefForm::default().into_value()
}

///|
/// Upstream `Synthesize for Packed<RefElem>`.
fn ref_elem_synthesize(
  engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  let span = content.span()
  let elem = RefElem(content)
  let citation = to_citation(elem, engine, styles)
  let elem = elem.with_citation(Some(citation)).with_element(None)
  if !BibliographyElem::has(engine, elem.target(), span) &&
    engine.introspect(query_label_introspection(elem.target(), span))
    is Ok(found) {
    return elem.with_element(Some(found)).pack()
  }
  elem.pack()
}

///|
/// Turn a reference into a citation.
fn to_citation(
  reference : RefElem,
  engine : Engine,
  styles : StyleChain,
) -> CiteElem raise SourceError {
  let elem = CiteElem::new(reference.target()).with_supplement(
    match reference.supplement(styles) {
      Custom(Some(Content(content))) => Some(content)
      _ => None
    },
  )
  CiteElem(cite_elem_synthesize(engine, elem.pack(), styles))
}
