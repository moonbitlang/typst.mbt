// TEMPORARY stubs for the routines whose ports are in progress in other
// packages (`realize`, layout). Each
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
