// Port of `typst-html/src/fragment.rs`.
//
// Upstream memoizes block fragments with comemo; here they are always
// computed (introspector reads are recorded by the engine's introspector).

///|
/// Produces HTML nodes from content contained in an HTML element that is
/// block-level by default.
pub fn html_block_fragment(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
  whitespace : Whitespace,
) -> Array[HtmlNode] raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  let locator = @library.Locator::link(link).split()
  let engine = engine.with_route(@library.Route::extend_(engine.route))
  @library.at(content.span(), () => engine.route.check_html_depth())
  let children = realize_fragment(engine, locator, content, styles)
  convert_to_nodes(engine, locator, children, Block, whitespace)
}

///|
/// Produces HTML nodes from content contained in an HTML element that is
/// inline-level by default.
///
/// The difference to block-level content is that inline-level content has
/// shared smartquoting state with surrounding inline-level content. This
/// requires mutable state, which is at odds with memoization. However, the
/// caching granularity would be unnecessarily high anyway if every single
/// fragment was cached, so this works out pretty well together.
pub fn html_inline_fragment(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.SplitLocator,
  quoter : @library.SmartQuoter,
  styles : @library.StyleChain,
  whitespace : Whitespace,
) -> Array[HtmlNode] raise @library.SourceError {
  engine.route.increase()
  @library.at(content.span(), () => engine.route.check_html_depth())
  let children = realize_fragment(engine, locator, content, styles)
  errdefer engine.route.decrease()
  let result = convert_to_nodes(
    engine,
    locator,
    children,
    Inline(quoter),
    whitespace,
  )
  engine.route.decrease()
  result
}

///|
/// Produces HTML nodes from content contained in a MathML element.
///
/// Uses math realization so that paragraph grouping doesn't occur.
pub fn html_math_fragment(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.SplitLocator,
  quoter : @library.SmartQuoter,
  styles : @library.StyleChain,
  whitespace : Whitespace,
) -> Array[HtmlNode] raise @library.SourceError {
  engine.route.increase()
  @library.at(content.span(), () => engine.route.check_html_depth())
  let children = (engine.library.routines.realize)(
    Math,
    engine,
    locator,
    content,
    styles,
  )
  errdefer engine.route.decrease()
  let result = convert_to_nodes(
    engine,
    locator,
    children,
    Inline(quoter),
    whitespace,
  )
  engine.route.decrease()
  result
}

///|
/// Realizes the body of an HTML fragment.
fn realize_fragment(
  engine : @library.Engine,
  locator : @library.SplitLocator,
  content : @library.Content,
  styles : @library.StyleChain,
) -> Array[@library.Pair] raise @library.SourceError {
  (engine.library.routines.realize)(
    // We ignore the `FragmentKind` because we handle both uniformly.
    Fragment(kind=Ref(@library.FragmentKind::Block)),
    engine,
    locator,
    content,
    styles,
  )
}
