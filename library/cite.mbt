// Port of the castable types of `typst-library/src/model/cite.rs`
// (`CitationForm`). The elements are generated.

///|
fn cite_elem_form_default() -> Value {
  IntoValue::into_value(Some(CitationForm::Normal))
}

///|
/// The form of the citation.
pub(all) enum CitationForm {
  /// Display in the standard way for the active style.
  Normal
  /// Produces a citation that is suitable for inclusion in a sentence.
  Prose
  /// Mimics a bibliography entry, with full information about the cited work.
  Full
  /// Shows only the cited work's author(s).
  Author
  /// Shows only the cited work's year.
  Year
} derive(Eq, Hash, Debug)

///|
pub impl Default for CitationForm with fn default() {
  Normal
}

///|
let citation_form_casts : ReadOnlyArray[(String, CitationForm, String)] = [
  ("normal", Normal, "Display in the standard way for the active style."),
  (
    "prose",
    Prose,
    "Produces a citation that is suitable for inclusion in a sentence.",
  ),
  (
    "full",
    Full,
    "Mimics a bibliography entry, with full information about the cited work.",
  ),
  ("author", Author, "Shows only the cited work's author(s)."),
  ("year", Year, "Shows only the cited work's year."),
]

///|
pub impl Reflect for CitationForm with fn input() {
  Union(
    citation_form_casts[:].map(entry => CastInfo::Value(Str(entry.0), entry.2)),
  )
}

///|
pub impl Reflect for CitationForm with fn output() {
  CitationForm::input()
}

///|
pub impl Reflect for CitationForm with fn castable(v) {
  match v {
    Str(s) => citation_form_casts.iter().any(entry => entry.0 == s)
    _ => false
  }
}

///|
pub impl IntoValue for CitationForm with fn into_value(self) {
  for entry in citation_form_casts[:] {
    if entry.1 == self {
      return Str(entry.0)
    }
  }
  None
}

///|
pub impl FromValue for CitationForm with fn from_value(v) {
  if v is Str(s) {
    for entry in citation_form_casts[:] {
      if entry.0 == s {
        return entry.1
      }
    }
  }
  raise HintedError(CitationForm::input().error(v))
}

///|
/// Upstream `Synthesize for Packed<CiteElem>`.
// Cannot fail; a `Synthesize::synthesize` hook, `Ok(())` upstream
// (typst-library/src/model/cite.rs:120).
#warnings("-unused_error_type")
fn cite_elem_synthesize(
  _engine : Engine,
  content : Content,
  styles : StyleChain,
) -> Content raise SourceError {
  CiteElem(content)
  .with_lang(TextElem::lang_in(styles))
  .with_region(TextElem::region_in(styles))
  .pack()
}

///|
/// `Default::default()` of `Smart<Derived<CslSource, CslStyle>>`
/// (CiteElem.style).
fn cite_elem_style_default() -> Value {
  Auto
}

///|
/// `#[parse]` of `CiteElem::style`.
fn cite_elem_style_parse(
  engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let source : @syntax.Spanned[Smart[CslSource]]? = args.named_spanned("style")
  match source {
    Some({ v: Custom(source), span, }) => {
      let (source, _) = CslStyle::load(engine, { v: source, span, })
      Some(Smart::Custom(source).into_value())
    }
    Some({ v: Auto, .. }) => Some(Auto)
    None => None
  }
}

///|
/// Realizes the citation group (upstream `Packed<CiteGroup>::realize`).
pub fn CiteGroup::realize(
  self : CiteGroup,
  engine : Engine,
) -> Content raise SourceError {
  let loc = self.0.location().unwrap()
  let span = self.0.span()
  Works::generate(engine, span).citation(loc, span)
}
