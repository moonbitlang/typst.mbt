// Port of `typst-html/src/document.rs` and of `HtmlDocument` (upstream in
// `dom.rs`).
//
// Upstream memoizes `html_document_impl` with comemo; here it is always
// computed.

///|
/// Produce an HTML document from content.
///
/// This first performs root-level realization and then turns the resulting
/// elements into HTML.
pub fn html_document(
  engine : @library.Engine,
  content : @library.Content,
  styles : @library.StyleChain,
) -> HtmlDocument raise @library.SourceError {
  let document = html_document_common(
    engine,
    content,
    @library.Locator::root(),
    styles,
  )

  // Assigns HTML fragment IDs to linked-to elements.
  let targets = document.introspector().link_targets()
  let anchors = create_link_anchors(document, targets)
  document.introspector().set_anchors(anchors)
  document
}

///|
/// Produce an HTML document from content, as part of a bundle compilation
/// process.
pub fn html_document_for_bundle(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
) -> HtmlDocument raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  html_document_common(engine, content, @library.Locator::link(link), styles)
}

///|
/// The shared implementation of `html_document` and
/// `html_document_for_bundle`.
fn html_document_common(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
) -> HtmlDocument raise @library.SourceError {
  let locator = locator.split()
  let engine = engine.with_route(
    @library.Route::extend(engine.route).unnested(),
  )

  // Create this upfront to make it as stable as possible.
  let footnote_locator = locator.next(())

  // Mark the external styles as "outside" so that they are valid at the
  // document level.
  let styles = @library.StyleChain::new(styles.to_map().outside())
  let info = @library.DocumentInfo::new()
  info.populate(styles)
  info.populate_locale(styles)
  let options = @library.DocumentFormatOptions::new()
  options.populate(styles, @syntax.Span::detached())
  let children = (engine.library.routines.realize)(
    Document(info~, options~),
    engine,
    locator,
    content,
    styles,
  )
  let nodes = convert_to_nodes(engine, locator, children, Block, Normal)
  let output = finalize_dom(
    engine,
    nodes,
    info,
    footnote_locator,
    @library.StyleChain::new(@library.Styles::root(children, styles)),
  )

  // Since `finalize_dom` might have inserted more DOM nodes that have styles,
  // the styles must be resolved last.
  resolve_inline_styles(output.root())
  let has_equations = !engine
    .introspect(
      @library.query_introspection(
        @library.equation_elem().select(),
        @syntax.Span::detached(),
      ),
    )
    .is_empty()
  if has_equations {
    let root = output.root()
    let mut head = None
    for node in root.children {
      if node is Element(elem) && elem.tag == @library.tag_head {
        head = Some(elem)
        break
      }
    }

    // TODO: this becomes an error when html fragments are supported
    guard head is Some(head) else {
      abort("head to be present in document output")
    }
    head.children.push(
      Element(
        HtmlElement::new(@library.tag_style).with_children([
          Text(equation_css_styles, @syntax.Span::detached()),
        ]),
      ),
    )
  }
  HtmlDocument::new(output, info, options)
}

///|
/// The introspectible output of HTML compilation.
pub struct HtmlOutput {
  priv nodes : Array[HtmlNode]
  priv root_index : Int
}

///|
/// All nodes.
pub fn HtmlOutput::nodes(self : HtmlOutput) -> ArrayView[HtmlNode] {
  self.nodes
}

///|
/// The root node.
pub fn HtmlOutput::root(self : HtmlOutput) -> HtmlElement {
  match self.nodes[self.root_index] {
    Element(root) => root
    _ => abort("expected HTML element")
  }
}

///|
/// The document's root HTML element, in its containing node wrapper.
pub fn HtmlOutput::root_node(self : HtmlOutput) -> HtmlNode {
  self.nodes[self.root_index]
}

///|
/// Wrap the user generated HTML in `<html>`, `<body>` or both if needed.
///
/// Returns a vector containing outer introspection tags and the HTML root
/// element. A direct reference to the root element is also returned.
fn finalize_dom(
  engine : @library.Engine,
  nodes : Array[HtmlNode],
  info : @library.DocumentInfo,
  footnote_locator : @library.Locator,
  footnote_styles : @library.StyleChain,
) -> HtmlOutput raise @library.SourceError {
  let count = nodes.iter().filter(node => !(node is Tag(_))).count()
  let mut needs_body = true
  for idx, node in nodes {
    guard node is Element(elem) else { continue }
    let tag = elem.tag
    if tag == @library.tag_html && count == 1 {
      footnotes_unsupported_with_custom_dom(engine)
      return { nodes, root_index: idx, }
    } else if tag == @library.tag_body && count == 1 {
      footnotes_unsupported_with_custom_dom(engine)
      needs_body = false
    } else if tag == @library.tag_html || tag == @library.tag_body {
      @library.bail_at(
        elem.span,
        "`\{elem.tag}` element must be the only element in the document",
      )
    }
  }
  let body = if needs_body {
    let body = HtmlElement::new(@library.tag_body).with_children(nodes)
    let footnotes = html_block_fragment(
      engine,
      @library.FootnoteContainer::new().pack(),
      footnote_locator,
      footnote_styles,
      Normal,
    )
    body.children.append(footnotes)
    [Element(body)]
  } else {
    nodes
  }
  let locale = match info.locale {
    Custom(locale) => locale
    Auto => @library.Locale::default()
  }
  let html = HtmlElement::new(@library.tag_html).with_attr(
    @library.attr_lang,
    locale.rfc_3066(),
  )
  let head = head_element(info)
  html.children.push(Element(head))
  html.children.append(body)
  { nodes: [Element(html)], root_index: 0, }
}

///|
/// Generate a `<head>` element.
fn head_element(info : @library.DocumentInfo) -> HtmlElement {
  let children = []
  children.push(
    Element(
      HtmlElement::new(@library.tag_meta).with_attr(
        @library.attr_charset, "utf-8",
      ),
    ),
  )
  children.push(
    Element(
      HtmlElement::new(@library.tag_meta)
      .with_attr(@library.attr_name, "viewport")
      .with_attr(@library.attr_content, "width=device-width, initial-scale=1"),
    ),
  )
  if info.title is Some(title) {
    children.push(
      Element(
        HtmlElement::new(@library.tag_title).with_children([
          Text(title, @syntax.Span::detached()),
        ]),
      ),
    )
  }
  if info.description is Some(description) {
    children.push(
      Element(
        HtmlElement::new(@library.tag_meta)
        .with_attr(@library.attr_name, "description")
        .with_attr(@library.attr_content, description),
      ),
    )
  }
  for author in info.author {
    children.push(
      Element(
        HtmlElement::new(@library.tag_meta)
        .with_attr(@library.attr_name, "author")
        .with_attr(@library.attr_content, author),
      ),
    )
  }
  if !info.keywords.is_empty() {
    children.push(
      Element(
        HtmlElement::new(@library.tag_meta)
        .with_attr(@library.attr_name, "keywords")
        .with_attr(@library.attr_content, info.keywords.join(", ")),
      ),
    )
  }
  HtmlElement::new(@library.tag_head).with_children(children)
}

///|
/// Fails with an error if there are footnotes.
fn footnotes_unsupported_with_custom_dom(
  engine : @library.Engine,
) -> Unit raise @library.SourceError {
  let markers = engine.introspect(
    @library.query_introspection(
      @library.footnote_marker_elem().select(),
      @syntax.Span::detached(),
    ),
  )
  if markers.is_empty() {
    return
  }
  raise @library.SourceError(
    markers.map(marker => {
      @library.SourceDiagnostic::error_at(
        marker.span(),
        "footnotes are not currently supported in combination with a custom `<html>` or `<body>` element",
      ).with_hint(
        "you can still use footnotes with a custom footnote show rule",
      )
    }),
  )
}

///|
/// An HTML document.
///
/// Unlike the `PagedDocument`, this does not implement `Hash` because the
/// HTML introspector is neither hashable nor guaranteed to be 100% derived
/// from the output (due to the presence of `root_mut` which is used for
/// cross-linking).
pub struct HtmlDocument {
  priv output : HtmlOutput
  priv info : @library.DocumentInfo
  priv options : @library.DocumentFormatOptions
  priv introspector : HtmlIntrospector
}

///|
/// Creates a new HTML document from its parts.
///
/// Internally builds the introspector.
pub fn HtmlDocument::new(
  output : HtmlOutput,
  info : @library.DocumentInfo,
  options : @library.DocumentFormatOptions,
) -> HtmlDocument {
  let introspector = HtmlIntrospector::new(output.nodes())
  { output, info, options, introspector, }
}

///|
/// The document's root HTML element.
pub fn HtmlDocument::root(self : HtmlDocument) -> HtmlElement {
  self.output.root()
}

///|
/// The document's root HTML element, mutably.
///
/// Technically, mutating the root can mess up the introspector. This should
/// be fixed at some point (<https://github.com/typst/typst/issues/7951>).
pub fn HtmlDocument::root_mut(self : HtmlDocument) -> HtmlElement {
  self.output.root()
}

///|
/// The document's root HTML element, in its containing node wrapper.
pub fn HtmlDocument::root_node(self : HtmlDocument) -> HtmlNode {
  self.output.root_node()
}

///|
/// Details about the document.
pub fn HtmlDocument::info(self : HtmlDocument) -> @library.DocumentInfo {
  self.info
}

///|
/// The format options set by the document.
pub fn HtmlDocument::options(
  self : HtmlDocument,
) -> @library.DocumentFormatOptions {
  self.options
}

///|
/// Provides the ability to execute queries on the document.
pub fn HtmlDocument::introspector(self : HtmlDocument) -> HtmlIntrospector {
  self.introspector
}

///|
pub impl @library.Output for HtmlDocument with fn introspector(self) {
  @library.Introspector::new(self.introspector)
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
  html_document(engine, content, styles)
}
