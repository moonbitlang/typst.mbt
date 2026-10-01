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
let citation_form_casts : Array[(String, CitationForm, String)] = [
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
    citation_form_casts.map(entry => CastInfo::Value(Str(entry.0), entry.2)),
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
  for entry in citation_form_casts {
    if entry.1 == self {
      return Str(entry.0)
    }
  }
  None
}

///|
pub impl FromValue for CitationForm with fn from_value(v) {
  if v is Str(s) {
    for entry in citation_form_casts {
      if entry.0 == s {
        return entry.1
      }
    }
  }
  raise HintedError(CitationForm::input().error(v))
}
