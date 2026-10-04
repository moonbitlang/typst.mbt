// Port of the castable value types of `typst-library/src/model/document.rs`
// (`DocumentFormat`, `PagedFormat`) and `OneOrMultiple` (upstream
// `typst-library/src/foundations/array.rs`).

///|
/// Supported export formats for bundle documents.
pub(all) enum DocumentFormat {
  /// One of the page formats.
  Paged(PagedFormat)
  /// The document format of the web.
  Html
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for DocumentFormat with fn input() {
  PagedFormat::input().union_with(
    Value(Str("html"), "The document format of the web."),
  )
}

///|
pub impl Reflect for DocumentFormat with fn output() {
  DocumentFormat::input()
}

///|
pub impl Reflect for DocumentFormat with fn castable(v) {
  v is Str("html") || PagedFormat::castable(v)
}

///|
pub impl IntoValue for DocumentFormat with fn into_value(self) {
  match self {
    Paged(v) => v.into_value()
    Html => Str("html")
  }
}

///|
pub impl FromValue for DocumentFormat with fn from_value(v) {
  match v {
    Str("html") => Html
    v if PagedFormat::castable(v) => Paged(PagedFormat::from_value(v))
    v => raise HintedError(DocumentFormat::input().error(v))
  }
}

///|
/// The target that a document in this format is compiled for.
pub fn DocumentFormat::target(self : DocumentFormat) -> Target {
  match self {
    Paged(_) => Paged
    Html => Html
  }
}

///|
/// Tries to determine the document's format based on the format that was
/// explicitly defined, or else the extension of the document's path.
pub fn DocumentElem::determine_format(
  self : DocumentElem,
  styles : StyleChain,
) -> DocumentFormat raise HintedError {
  if self.format(styles) is Custom(format) {
    return format
  }
  match document_format_from_path(self.path().into_inner()) {
    Some(format) => format
    None =>
      bail_hinted("unknown document format", [
        "try specifying the `format` explicitly",
      ])
  }
}

///|
/// Derive the document format from the file extension of a path (upstream
/// `determine_format_from_path` in `model/document.rs`).
fn document_format_from_path(path : @syntax.VirtualPath) -> DocumentFormat? {
  match path.extension() {
    Some("pdf") => Some(Paged(Pdf))
    Some("svg") => Some(Paged(Svg))
    Some("png") => Some(Paged(Png))
    Some("html") => Some(Html)
    _ => None
  }
}

///|
/// Supported paged export formats for bundle documents.
pub(all) enum PagedFormat {
  /// High-fidelity document and graphics format, with focus on exact
  /// reproduction in print.
  Pdf
  /// Raster format for illustrations and transparent graphics.
  Png
  /// The vector graphics format of the web.
  Svg
} derive(Eq, Hash, Debug)

///|
let paged_format_names : ReadOnlyArray[String] = ["pdf", "png", "svg"]

///|
pub impl Reflect for PagedFormat with fn input() {
  str_names_input(paged_format_names)
}

///|
pub impl Reflect for PagedFormat with fn output() {
  PagedFormat::input()
}

///|
pub impl Reflect for PagedFormat with fn castable(v) {
  str_names_find(paged_format_names, v) is Some(_)
}

///|
pub impl IntoValue for PagedFormat with fn into_value(self) {
  match self {
    Pdf => Str("pdf")
    Png => Str("png")
    Svg => Str("svg")
  }
}

///|
pub impl FromValue for PagedFormat with fn from_value(v) {
  match str_names_find(paged_format_names, v) {
    Some(0) => Pdf
    Some(1) => Png
    Some(_) => Svg
    None => raise HintedError(PagedFormat::input().error(v))
  }
}

///|
/// One element, or multiple provided as an array.
pub(all) struct OneOrMultiple[T](Array[T]) derive(Eq, Hash)

///|
pub impl[T] Default for OneOrMultiple[T] with fn default() {
  OneOrMultiple([])
}

///|
pub impl[T] Fold for OneOrMultiple[T] with fn fold(self, outer) {
  OneOrMultiple(outer.0 + self.0)
}

///|
pub impl[T : Reflect] Reflect for OneOrMultiple[T] with fn input() {
  T::input().union_with(Type(Type::array()))
}

///|
pub impl[T : Reflect] Reflect for OneOrMultiple[T] with fn output() {
  T::output().union_with(Type(Type::array()))
}

///|
pub impl[T : Reflect] Reflect for OneOrMultiple[T] with fn castable(value) {
  value is Array(_) || T::castable(value)
}

///|
pub impl[T : IntoValue] IntoValue for OneOrMultiple[T] with fn into_value(self) {
  IntoValue::into_value(self.0)
}

///|
pub impl[T : FromValue] FromValue for OneOrMultiple[T] with fn from_value(value) {
  if T::castable(value) {
    return OneOrMultiple([T::from_value(value)])
  }
  match value {
    Array(array) => OneOrMultiple(array.items.map(v => T::from_value(v)))
    _ =>
      raise HintedError(T::input().union_with(Type(Type::array())).error(value))
  }
}

///|
/// Details about the document.
pub(all) struct DocumentInfo {
  /// The document's title.
  mut title : String?
  /// The document's author(s).
  mut author : Array[String]
  /// The document's description.
  mut description : String?
  /// The document's keywords.
  mut keywords : Array[String]
  /// The document's creation date.
  mut date : Smart[Datetime?]
  /// The document's language, set from the first top-level set rule, e.g.
  ///
  /// ```typc
  /// set text(lang: "...", region: "...")
  /// ```
  mut locale : Smart[Locale]
}

///|
/// Default document info.
pub fn DocumentInfo::new() -> DocumentInfo {
  {
    title: None,
    author: [],
    description: None,
    keywords: [],
    date: Auto,
    locale: Auto,
  }
}

///|
pub impl Default for DocumentInfo with fn default() {
  DocumentInfo::new()
}

///|
/// Populate this document info with details from the given styles.
///
/// Document set rules are a bit special, so we need to do this manually.
pub fn DocumentInfo::populate(self : DocumentInfo, styles : StyleChain) -> Unit {
  let elem = document_elem()
  if styles.has(elem, document_elem_title) {
    self.title = DocumentElem::title_in(styles).map(content => {
      content.plain_text()
    })
  }
  if styles.has(elem, document_elem_author) {
    self.author = DocumentElem::author_in(styles).0
  }
  if styles.has(elem, document_elem_description) {
    self.description = DocumentElem::description_in(styles).map(content => {
      content.plain_text()
    })
  }
  if styles.has(elem, document_elem_keywords) {
    self.keywords = DocumentElem::keywords_in(styles).0
  }
  if styles.has(elem, document_elem_date) {
    self.date = DocumentElem::date_in(styles)
  }
}

///|
/// Populate this document info with locale details from the given styles.
pub fn DocumentInfo::populate_locale(
  self : DocumentInfo,
  styles : StyleChain,
) -> Unit {
  if self.locale is Custom(_) {
    return
  }
  let mut locale : Locale? = None
  if styles.has(text_elem(), text_elem_lang) {
    let l = locale.unwrap_or_default()
    locale = Some({ ..l, lang: TextElem::lang_in(styles), })
  }
  if styles.has(text_elem(), text_elem_region) {
    let l = locale.unwrap_or_default()
    locale = Some({ ..l, region: TextElem::region_in(styles), })
  }
  self.locale = match locale {
    Some(l) => Custom(l)
    None => Auto
  }
}

///|
/// A copy of the document info.
pub fn DocumentInfo::copy(self : DocumentInfo) -> DocumentInfo {
  { ..self, author: self.author.copy(), keywords: self.keywords.copy(), }
}

///|
/// Upstream `ShowSet for Packed<DocumentElem>`.
fn document_elem_show_set(content : Content, _styles : StyleChain) -> Styles {
  // Here, we make explicit document properties contextually available.
  // This is mostly relevant for bundle export as document elements are
  // not directly supported in other targets.
  //
  // Making the properties available like this is inconsistent with normal
  // elements, but consistent with `page` and necessary to make the
  // `title` element work.
  //
  // Nonetheless, it's fairly hacky and the whole thing should probably be
  // revisited at some point. Also see
  // <https://github.com/typst/typst/issues/6721>.
  let styles = Styles::new()
  for
    id in [
      document_elem_format, document_elem_title, document_elem_author, document_elem_description,
      document_elem_keywords, document_elem_date,
    ] {
    // `copy_into`: copy the element's own value, if it is set.
    if content.field_raw(id) is Some(value) {
      styles.set(document_elem(), id, value)
    }
  }
  styles
}

///|
fn document_elem_author_default() -> Value {
  (OneOrMultiple::default() : OneOrMultiple[String]).into_value()
}

///|
fn document_elem_keywords_default() -> Value {
  (OneOrMultiple::default() : OneOrMultiple[String]).into_value()
}
