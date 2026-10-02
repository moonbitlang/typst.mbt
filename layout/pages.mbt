// Port of `typst-layout/src/pages/mod.rs` (pending).

///|
/// Layout content into a document.
///
/// This first performs root-level realization and then lays out the
/// resulting elements. In contrast to `layout_fragment`, this does not take
/// regions since the regions are defined by the page configuration in the
/// content and style chain.
///
/// TODO(pages): the page layout is not ported yet (P4 work unit G).
pub fn layout_document(
  engine : @library.Engine,
  content : @library.Content,
  styles : @library.StyleChain,
) -> PagedDocument raise @library.SourceError {
  ignore(engine)
  ignore(styles)
  @library.bail_at(content.span(), "layout is not yet ported")
}
