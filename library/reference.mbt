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
pub extend Supplement with Reflect::{output, input, castable}

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
pub extend RefForm with Default::{default}

///|
let ref_form_names : ReadOnlyArray[String] = ["normal", "page"]

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
pub extend RefForm with Reflect::{output, input, castable}

///|
pub impl IntoValue for RefForm with fn into_value(self) {
  match self {
    Normal => Str("normal")
    Page => Str("page")
  }
}

///|
pub extend RefForm with IntoValue::{into_value}

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

///|
/// Realize as a linked, textual reference.
pub fn RefElem::realize(
  self : RefElem,
  engine : Engine,
  styles : StyleChain,
) -> Content raise SourceError {
  let span = self.0.span()
  let elem = engine.introspect(query_label_introspection(self.target(), span))
  let form = self.form(styles)
  if form == Page {
    let elem = match elem {
      Ok(elem) => elem
      Err(err) => raise SourceError([err.into_error_at(span)])
    }
    let loc = elem.location().unwrap()
    let numbering = match
      engine.introspect(page_numbering_introspection(loc, span)) {
      Some(numbering) => numbering
      None =>
        bail_at(span, "cannot reference without page numbering", hints=[
          "you can enable page numbering with `#set page(numbering: \"1\")`",
        ])
    }
    let supplement = engine.introspect(page_supplement_introspection(loc, span))
    return realize_reference(
      self,
      engine,
      styles,
      Counter::new(Page),
      numbering,
      supplement,
      elem,
    )
  }
  // RefForm::Normal

  if BibliographyElem::has(engine, self.target(), span) {
    if elem is Ok(elem) {
      bail_at(
        span,
        "label `\{self.target().repr()}` occurs both in the document and a bibliography",
        hints=[
          "change either the \{elem.elem().name()}'s label or the bibliography key to resolve the ambiguity",
        ],
      )
    }
    return to_citation(self, engine, styles).pack().spanned(span)
  }
  let elem = match elem {
    Ok(elem) => elem
    Err(err) => raise SourceError([err.into_error_at(span)])
  }
  if FootnoteElem::of(elem) is Some(footnote) {
    return footnote.into_ref(self.target()).pack().spanned(span)
  }
  // Every referenceable element (`dyn Refable`) is also outlinable.
  let refable = match OutlinableElem::of(elem) {
    Some(refable) => refable
    None =>
      if elem.elem().can("Figurable") {
        bail_at(
          span,
          "cannot reference \{elem.elem().name()} directly, try putting it into a figure",
        )
      } else {
        bail_at(span, "cannot reference \{elem.elem().name()}")
      }
  }
  let numbering = match refable.numbering() {
    Some(numbering) => numbering
    None => {
      let name = elem.elem().name()
      let set_name = if elem.elem() == equation_elem() {
        "math.equation"
      } else {
        name
      }
      bail_at(span, "cannot reference \{name} without numbering", hints=[
        "you can enable \{name} numbering with `#set \{set_name}(numbering: \"1.\")`",
      ])
    }
  }
  realize_reference(
    self,
    engine,
    styles,
    refable.counter(),
    numbering,
    refable.supplement(),
    elem,
  )
}

///|
/// Show a reference.
fn realize_reference(
  reference : RefElem,
  engine : Engine,
  styles : StyleChain,
  counter : Counter,
  numbering : Numbering,
  supplement : Content,
  elem : Content,
) -> Content raise SourceError {
  let span = reference.0.span()
  let loc = elem.location().unwrap()
  let numbers = counter.display_at(
    engine,
    loc,
    styles,
    numbering.trimmed(),
    span,
  )
  let supplement = match reference.supplement(styles) {
    Auto => supplement
    Custom(None) => Content::empty()
    Custom(Some(supplement)) =>
      supplement.resolve(engine, styles, [Content(elem)])
  }
  let alt = {
    let supplement = supplement.plain_text()
    let numbering = numbers.plain_text()
    "\{supplement} \{numbering}"
  }
  let mut content = numbers
  if !supplement.is_empty() {
    content = supplement.add(TextElem::packed("\u{a0}")).add(content)
  }
  content = content.spanned(span)
  DirectLinkElem::new(loc, content, Some(alt)).pack().spanned(span)
}
