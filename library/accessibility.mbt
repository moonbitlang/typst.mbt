// Port of the castable value types of `typst-library/src/model/accessibility.rs`
// (`ArtifactKind`).

///|
/// The type of artifact.
pub(all) enum ArtifactKind {
  /// Repeats on the top of each page.
  Header
  /// Repeats at the bottom of each page.
  Footer
  /// Text or graphics in the back- or foreground of all pages.
  Watermark
  /// Page numbers.
  PageNumber
  /// Line or paragraph numbers.
  LineNumber
  /// Placeholders for areas in which there was content in another rendition
  /// of the document which has since been removed.
  Redaction
  /// Bates numbering.
  Bates
  /// Not part of the document, but rather the page it is printed on.
  Page
  /// Artifacts arising from paginating the document not covered by other
  /// artifact types.
  PaginationOther
  /// Purely cosmetric content or typographical flourishes not contributing to
  /// the document's content.
  Layout
  /// Background of a page or a graphical element.
  Background
  /// Other artifacts.
  Other
} derive(Eq, Hash, Debug)

///|
pub impl Default for ArtifactKind with fn default() {
  Other
}

///|
let artifact_kind_names : Array[String] = [
  "header", "footer", "watermark", "page-number", "line-number", "redaction", "bates",
  "page", "pagination-other", "layout", "background", "other",
]

///|
let artifact_kind_values : Array[ArtifactKind] = [
  Header,
  Footer,
  Watermark,
  PageNumber,
  LineNumber,
  Redaction,
  Bates,
  Page,
  PaginationOther,
  Layout,
  Background,
  Other,
]

///|
pub impl Reflect for ArtifactKind with fn input() {
  str_names_input(artifact_kind_names)
}

///|
pub impl Reflect for ArtifactKind with fn output() {
  ArtifactKind::input()
}

///|
pub impl Reflect for ArtifactKind with fn castable(v) {
  str_names_find(artifact_kind_names, v) is Some(_)
}

///|
pub impl IntoValue for ArtifactKind with fn into_value(self) {
  for i, kind in artifact_kind_values {
    if kind == self {
      return Str(artifact_kind_names[i])
    }
  }
  None
}

///|
pub impl FromValue for ArtifactKind with fn from_value(v) {
  match str_names_find(artifact_kind_names, v) {
    Some(i) => artifact_kind_values[i]
    None => raise HintedError(ArtifactKind::input().error(v))
  }
}

///|
fn artifact_elem_kind_default() -> Value {
  ArtifactKind::default().into_value()
}
