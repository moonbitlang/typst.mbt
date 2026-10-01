// TEMPORARY stubs for the routines and the HTML document whose ports are in
// progress in other packages (`realize`, `html` semantics, layout). Each
// stub is replaced by the real implementation as it lands; delete this file
// once all of them are gone.

///|
/// TEMPORARY: replaced by `@realize.realize`.
fn stub_realize(
  _kind : @library.RealizationKind,
  _engine : @library.Engine,
  _locator : @library.SplitLocator,
  content : @library.Content,
  _styles : @library.StyleChain,
) -> Array[@library.Pair] raise @library.SourceError {
  @library.bail_at(content.span(), "realization is not yet ported")
}

///|
/// TODO(driver): replaced by `@layout.layout_frame` once layout is ported.
fn stub_layout_frame(
  _engine : @library.Engine,
  content : @library.Content,
  _locator : @library.Locator,
  _styles : @library.StyleChain,
  _region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  @library.bail_at(content.span(), "layout is not yet ported")
}

///|
/// TEMPORARY: replaced by `@html.html_mathml_body`.
fn stub_html_mathml_body(
  _content : @library.Content,
  _styles : @library.StyleChain,
) -> @library.Content?? {
  None
}

///|
/// TEMPORARY: replaced by `@html.html_span_filled`.
fn stub_html_span_filled(
  content : @library.Content,
  _color : @library.Color,
) -> @library.Content {
  content
}

///|
/// TEMPORARY: replaced by `@html.HtmlDocument` (and its `Output` impl in the
/// `html` package).
pub struct HtmlDocument {
  priv root : @html.HtmlElement
  priv introspector : @library.Introspector
}

///|
pub impl @library.Output for HtmlDocument with fn introspector(self) {
  self.introspector
}

///|
pub impl @library.Output for HtmlDocument with fn target() {
  Html
}

///|
pub impl @library.Output for HtmlDocument with fn create(
  engine,
  content,
  styles,
) {
  // TEMPORARY: `@html.html_document(engine, content, styles)`.
  ignore(engine)
  ignore(styles)
  @library.bail_at(content.span(), "html export is not yet ported")
}

///|
/// TEMPORARY: replaced by `@html.html(document, options)`.
pub fn html(
  document : HtmlDocument,
  pretty~ : Bool,
) -> String raise @library.SourceError {
  @html.html_encode(document.root, pretty~)
}
