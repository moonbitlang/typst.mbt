// TEMPORARY stubs for the parts of `typst-layout` that are ported by other
// work units: inline layout (`inline/*`, unit F). Their signatures follow
// upstream so that the real ports can replace them one by one; delete each
// stub (and finally this file) when its port lands.

///|
/// Distinguishes between a few different kinds of paragraphs.
///
/// In the form `Option<ParSituation>`, `None` implies that we are creating
/// an inline layout that isn't a semantic paragraph.
/// (Upstream `inline::ParSituation`.)
pub(all) enum ParSituation {
  /// The paragraph is the first child in the flow (i.e. in the container or
  /// page run) or right after a column break. For such paragraphs, we may
  /// want to avoid applying first line indent (depending on configuration).
  First
  /// The paragraph follows another paragraph.
  Consecutive
  /// Any other kind of paragraph.
  Other
} derive(Eq, Hash, Debug)

///|
/// Layouts the paragraph (upstream `inline::layout_par`).
///
/// TODO(inline): replaced by the inline layout port (unit F).
pub fn layout_par(
  elem : @library.ParElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
  expand : Bool,
  situation : ParSituation,
) -> @library.Fragment raise @library.SourceError {
  ignore((engine, locator, styles, region, expand, situation))
  @library.bail_at(elem.pack().span(), "inline layout is not yet ported")
}

///|
/// Lays out realized content with inline layout (upstream
/// `inline::layout_inline`).
///
/// TODO(inline): replaced by the inline layout port (unit F).
pub fn layout_inline(
  engine : @library.Engine,
  children : ArrayView[@library.Pair],
  locator : @library.SplitLocator,
  shared : @library.StyleChain,
  region : @library.Axes[@library.Abs],
  expand : Bool,
) -> @library.Fragment raise @library.SourceError {
  ignore((engine, locator, shared, region, expand))
  let span = match children.get(0) {
    Some(pair) => pair.0.span()
    None => @syntax.Span::detached()
  }
  @library.bail_at(span, "inline layout is not yet ported")
}
