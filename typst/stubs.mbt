// TEMPORARY stubs for the routines whose ports are in progress in other
// packages (layout). Each
// stub is replaced by the real implementation as it lands; delete this file
// once all of them are gone.

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
