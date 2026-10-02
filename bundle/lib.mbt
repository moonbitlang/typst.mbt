// Port of `typst-bundle/src/lib.rs`: multi-file output for Typst.
//
// The format element (`BundleFormat`), `AssetElem`, `AssetData` and the
// bundle-specific native rules of `typst-bundle/src/format.rs` live in the
// `library` package (`library/bundle_format.mbt`, `bundle_format()` in
// `library/format.mbt`) because the library's default format list and
// generated element descriptors need them.
//
// Upstream memoizes `bundle_impl` and compiles the documents in parallel;
// here everything is computed sequentially, in the same order (diagnostics
// are merged in order like `Engine::parallelize` does).

///|
/// A collection of files resulting from compilation.
///
/// In the `bundle` target, Typst can emit multiple documents and assets from a
/// single Typst project.
///
/// The `Bundle` is the output of compilation and is to the `bundle` output
/// format what the `PagedDocument` is to `pdf`, `png`, and `svg` outputs.
pub struct Bundle {
  /// The files in the bundle (in insertion order).
  files : Map[@syntax.VirtualPath, BundleFile]
  /// An introspector for the whole bundle.
  ///
  /// The whole bundle is subject to one large introspection loop (as opposed
  /// to each document iterating separately). They can introspect each other
  /// and all contribute to this one introspector.
  bundle_introspector : BundleIntrospector
  /// The type-erased facade over `bundle_introspector`.
  priv introspector : @library.Introspector
}

///|
pub impl @library.Output for Bundle with fn introspector(self) {
  self.introspector
}

///|
pub impl @library.Output for Bundle with fn target() {
  Bundle
}

///|
pub impl @library.Output for Bundle with fn create(engine, content, styles) {
  bundle(engine, content, styles)
}

///|
/// A single file in the bundle.
pub(all) enum BundleFile {
  /// A document in one of the supported output formats, resulting from a
  /// `document` element.
  Document(BundleDocument)
  /// Raw file data, resulting from an `asset` element.
  Asset(@library.BytesValue)
}

///|
/// A document in one of the supported output formats, resulting from a
/// `document` element.
pub(all) enum BundleDocument {
  /// A document in one of the paged formats.
  Paged(@layout.PagedDocument, PagedExtras)
  /// A document in the HTML format.
  Html(@html.HtmlDocument)
}

///|
/// Details about the document (upstream `Document::info`).
pub fn BundleDocument::info(self : BundleDocument) -> @library.DocumentInfo {
  match self {
    Paged(doc, _) => doc.info()
    Html(doc) => doc.info()
  }
}

///|
/// The format options set by the document (upstream `Document::options`).
pub fn BundleDocument::options(
  self : BundleDocument,
) -> @library.DocumentFormatOptions {
  match self {
    Paged(doc, _) => doc.options()
    Html(doc) => doc.options()
  }
}

///|
/// Extra data relevant for exporting a paged document in a bundle.
pub(all) struct PagedExtras {
  /// The format to export in.
  format : @library.PagedFormat
  /// Named anchors that should be exported, so that cross-document links can
  /// jump to a precise location.
  ///
  /// Not all export targets support this (e.g. PNG), in which case it can
  /// simply be ignored.
  mut anchors : Array[(@library.Location, String)]
}

///|
/// Produces a bundle from content.
///
/// This first performs root-level bundle realization and then compiles the
/// individual documents.
pub fn bundle(
  engine : @library.Engine,
  content : @library.Content,
  styles : @library.StyleChain,
) -> Bundle raise @library.SourceError {
  bundle_impl(engine, content, styles)
}

///|
/// The internal implementation of `bundle`.
fn bundle_impl(
  engine : @library.Engine,
  content : @library.Content,
  styles : @library.StyleChain,
) -> Bundle raise @library.SourceError {
  let locator = @library.Locator::root().split()
  let engine = engine.with_route(
    @library.Route::extend(engine.route).unnested(),
  )

  // Mark the external styles as "outside" so that they are valid at the page
  // level.
  let styles = @library.StyleChain::new(styles.to_map().outside())
  let children = (engine.library.routines.realize)(
    Bundle,
    engine,
    locator,
    content,
    styles,
  )
  let children = collect(children, engine, locator)

  // Upstream processes the children with `engine.parallelize` and
  // `collect_combined_result`: all errors are collected.
  let items : Array[Item] = []
  let errors : Array[@library.SourceDiagnostic] = []
  for child in children {
    match child {
      Tag(tag) => items.push(Tag(tag))
      Asset(asset) =>
        items.push(
          Asset(
            asset.path().into_inner(),
            asset.data().0,
            asset.pack().location().unwrap(),
          ),
        )
      Document(document, styles, locator) =>
        try compile_document(engine, document, styles, locator) catch {
          @library.SourceError(errs) => errors.append(errs)
        } noraise {
          doc =>
            items.push(
              Document(
                document.path().into_inner(),
                doc,
                document.pack().location().unwrap(),
              ),
            )
        }
    }
  }
  if !errors.is_empty() {
    raise @library.SourceError(errors)
  }
  let introspector = BundleIntrospector::new(items)
  let targets = introspector.link_targets()
  let anchors = create_link_anchors(items, targets)
  introspector.set_anchors(anchors)
  let files : Map[@syntax.VirtualPath, BundleFile] = Map([])
  for item in items {
    match item {
      Tag(_) => ()
      Asset(path, bytes, _) => files[path] = Asset(bytes)
      Document(path, doc, _) => files[path] = Document(doc)
    }
  }
  {
    files,
    bundle_introspector: introspector,
    introspector: @library.Introspector::new(introspector),
  }
}

///|
/// Something that can result from bundle realization.
priv enum Child {
  Tag(@library.Tag)
  Asset(@library.AssetElem)
  Document(@library.DocumentElem, @library.StyleChain, @library.Locator)
}

///|
/// The processed version of a [Child].
priv enum Item {
  Tag(@library.Tag)
  Asset(@syntax.VirtualPath, @library.BytesValue, @library.Location)
  Document(@syntax.VirtualPath, BundleDocument, @library.Location)
}

///|
/// Collects all documents and assets in the bundle.
fn collect(
  children : Array[@library.Pair],
  engine : @library.Engine,
  locator : @library.SplitLocator,
) -> Array[Child] raise @library.SourceError {
  let items = []
  let errors = []
  let seen : Map[@syntax.VirtualPath, @syntax.Span] = Map([])
  for pair in children {
    let (elem, styles) = pair
    let path = if @library.TagElem::of(elem) is Some(tag) {
      items.push(Child::Tag(tag.tag()))
      continue
    } else if @library.AssetElem::of(elem) is Some(asset) {
      items.push(Asset(asset))
      asset.path().into_inner()
    } else if @library.DocumentElem::of(elem) is Some(document) {
      items.push(Document(document, styles, locator.next(elem.span())))
      document.path().into_inner()
    } else {
      errors.push(
        @library.SourceDiagnostic::error_at(
          elem.span(),
          "\{elem.func().name()} is not allowed at the top-level in bundle export",
        ).with_hint("try wrapping the content in a `document` instead"),
      )
      continue
    }
    match seen.get(path) {
      None => seen[path] = elem.span()
      Some(prev) => {
        let diag = @library.SourceDiagnostic::error_at(
          elem.span(),
          "path `\{path.get_without_slash()}` occurs multiple times in the bundle",
        ).with_hint("\{elem.func().name()} paths must be unique in the bundle")
        diag.spanned_hint(
          "path is already in use here",
          @syntax.DiagSpan::from_span(prev),
        )
        engine.sink.delayed_error(diag)
      }
    }
  }
  if !errors.is_empty() {
    raise @library.SourceError(errors)
  }
  items
}

///|
/// Compiles a single document.
fn compile_document(
  engine : @library.Engine,
  document : @library.DocumentElem,
  styles : @library.StyleChain,
  locator : @library.Locator,
) -> BundleDocument raise @library.SourceError {
  let span = document.pack().span()
  let format = @library.at(span, () => document.determine_format(styles))
  let target = @library.Styles::from_array([
    @library.TargetElem::set_target(format.target()),
  ])
  let styles = styles.chain(target)
  match format {
    Paged(format) => {
      let doc = @layout.layout_document_for_bundle(
        engine,
        document.body(),
        locator,
        styles,
      )
      let num_pages = doc.pages().length()
      if num_pages != 1 && format is (Png | Svg) {
        engine.sink.delayed_error(
          @library.SourceDiagnostic::error_at(
            span, "expected document to have a single page",
          ).with_hints([
            "the document resulted in \{num_pages} pages",
            "documents exported to an image format only support a single page",
          ]),
        )
      }
      Paged(doc, { format, anchors: [], })
    }
    Html => {
      if !engine.library.features.is_enabled(Html) {
        @library.bail_at(
          span,
          "html export is only available when the `html` feature is enabled",
          hints=[
            "html export is under active development and incomplete", "to enable both bundle and html export, pass `--features bundle,html`",
          ],
        )
      }
      let doc = @html.html_document_for_bundle(
        engine,
        document.body(),
        locator,
        styles,
      )
      Html(doc)
    }
  }
}
