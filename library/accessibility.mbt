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
let artifact_kind_names : ReadOnlyArray[String] = [
  "header", "footer", "watermark", "page-number", "line-number", "redaction", "bates",
  "page", "pagination-other", "layout", "background", "other",
]

///|
let artifact_kind_values : ReadOnlyArray[ArtifactKind] = [
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
  for i, kind in artifact_kind_values[:] {
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

///|
/// The kind of a `PdfMarkerTag`.
pub(all) enum PdfMarkerTagKind {
  /// `TOC`.
  OutlineBody
  /// `L` bibliography list.
  Bibliography(Bool)
  /// `LBody` wrapping `BibEntry`.
  BibEntry
  /// `Lbl` (marker) of the list item.
  ListItemLabel
  /// `LBody` of the list item.
  ListItemBody
  /// `Lbl` of the term item.
  TermsItemLabel
  /// `LBody` the term item including the label.
  TermsItemBody
  /// A generic `Lbl`.
  Label
} derive(Eq, Hash, Debug)

// Upstream `PdfMarkerTagKind` has no cast: it is only stored in the internal
// `PdfMarkerTag::kind` field. Its value form here is the kebab-case variant
// name (with `numbered` for `Bibliography`: `("bibliography", numbered)`).

///|
let pdf_marker_tag_kind_names : ReadOnlyArray[(String, PdfMarkerTagKind)] = [
  ("outline-body", OutlineBody),
  ("bib-entry", BibEntry),
  ("list-item-label", ListItemLabel),
  ("list-item-body", ListItemBody),
  ("terms-item-label", TermsItemLabel),
  ("terms-item-body", TermsItemBody),
  ("label", Label),
]

///|
pub impl Reflect for PdfMarkerTagKind with fn input() {
  CastInfo::Type(Type::str()).union_with(Type(Type::array()))
}

///|
pub impl Reflect for PdfMarkerTagKind with fn output() {
  PdfMarkerTagKind::input()
}

///|
pub impl Reflect for PdfMarkerTagKind with fn castable(v) {
  v is (Str(_) | Array(_))
}

///|
pub impl IntoValue for PdfMarkerTagKind with fn into_value(self) {
  match self {
    Bibliography(numbered) =>
      Array(Arr::from_array([Str("bibliography"), Bool(numbered)]))
    kind => {
      for entry in pdf_marker_tag_kind_names[:] {
        if entry.1 == kind {
          return Str(entry.0)
        }
      }
      None
    }
  }
}

///|
pub impl FromValue for PdfMarkerTagKind with fn from_value(v) {
  match v {
    Str(s) =>
      for entry in pdf_marker_tag_kind_names[:] {
        if entry.0 == s {
          return entry.1
        }
      }
    Array(arr) =>
      if arr.iter().collect() is [Str("bibliography"), Bool(numbered)] {
        return Bibliography(numbered)
      }
    _ => ()
  }
  raise HintedError(PdfMarkerTagKind::input().error(v))
}

///|
/// Wrap content in a `PdfMarkerTag` of the given kind (upstream's
/// `PdfMarkerTag::<Kind>(body)` constructors).
pub fn pdf_marker_tag(kind : PdfMarkerTagKind, body : Content) -> Content {
  let span = body.span()
  Content::new(pdf_marker_tag_elem(), [
    (pdf_marker_tag_elem_kind, kind.into_value()),
    (pdf_marker_tag_elem_body, Content(body)),
  ]).spanned(span)
}
