// TEMPORARY stubs for the parts of `typst-layout` that are ported by other
// work units: math layout (`math/*`, unit I). Their signatures follow
// upstream so that the real ports can replace them one by one; delete each
// stub (and finally this file) when its port lands.

///|
/// Layout a block-level equation (in a flow) (upstream
/// `math::layout_equation_block`).
///
/// TODO(math): replaced by the math layout port (unit I).
pub fn layout_equation_block(
  elem : @library.EquationElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  regions : @library.Regions,
) -> @library.Fragment raise @library.SourceError {
  ignore((engine, locator, styles, regions))
  @library.bail_at(elem.pack().span(), "math layout is not yet ported")
}

///|
/// Layout an inline equation (in a paragraph) (upstream
/// `math::layout_equation_inline`).
///
/// TODO(math): replaced by the math layout port (unit I).
pub fn layout_equation_inline(
  elem : @library.EquationElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.Axes[@library.Abs],
) -> Array[@library.InlineItem] raise @library.SourceError {
  ignore((engine, locator, styles, region))
  @library.bail_at(elem.pack().span(), "math layout is not yet ported")
}
