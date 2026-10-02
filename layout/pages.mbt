// Port of `typst-layout/src/pages/mod.rs`.
//
// Layout of content into a [PagedDocument].
//
// Upstream memoizes `layout_document_impl` and lays out page runs in
// parallel; here everything is computed sequentially, in the same order.

///|
/// Layout content into a document.
///
/// This first performs root-level realization and then lays out the
/// resulting elements. In contrast to [layout_fragment], this does not take
/// regions since the regions are defined by the page configuration in the
/// content and style chain.
pub fn layout_document(
  engine : @library.Engine,
  content : @library.Content,
  styles : @library.StyleChain,
) -> PagedDocument raise @library.SourceError {
  layout_document_common(engine, content, @library.Locator::root(), styles)
}

///|
/// Layout content into a document, as part of a bundle compilation process.
pub fn layout_document_for_bundle(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
) -> PagedDocument raise @library.SourceError {
  let link = @library.LocatorLink::new(locator)
  layout_document_common(engine, content, @library.Locator::link(link), styles)
}

///|
/// The shared, unmemoized implementation of `layout_document` and
/// `layout_document_for_bundle`.
fn layout_document_common(
  engine : @library.Engine,
  content : @library.Content,
  locator : @library.Locator,
  styles : @library.StyleChain,
) -> PagedDocument raise @library.SourceError {
  let locator = locator.split()
  let engine = engine.with_route(
    @library.Route::extend(engine.route).unnested(),
  )

  // Mark the external styles as "outside" so that they are valid at the page
  // level.
  let styles = @library.StyleChain::new(styles.to_map().outside())
  let info = @library.DocumentInfo::new()
  info.populate(styles)
  info.populate_locale(styles)
  let options = @library.DocumentFormatOptions::new(
    formats=engine.library.formats,
  )
  options.populate(styles, @syntax.Span::detached())
  let children = (engine.library.routines.realize)(
    Document(info~, options~),
    engine,
    locator,
    content,
    styles,
  )
  let pages = layout_pages(engine, children, locator, styles)
  PagedDocument::new(pages, info, options)
}

///|
/// Layouts the document's pages.
fn layout_pages(
  engine : @library.Engine,
  children : Array[@library.Pair],
  locator : @library.SplitLocator,
  styles : @library.StyleChain,
) -> Array[Page] raise @library.SourceError {
  // Slice up the children into logical parts.
  let items = collect_pages(children, locator, styles)

  // Layout the page runs (in parallel upstream).
  let runs : Array[
    Result[Array[LayoutedPage], Array[@library.SourceDiagnostic]],
  ] = []
  for item in items {
    guard item is Run(children, initial, locator) else { continue }
    let result = try
      layout_page_run(engine, children, locator.relayout(), initial)
    catch {
      @library.SourceError(errors) => Err(errors)
    } noraise {
      layouted => Ok(layouted)
    }
    runs.push(result)
  }
  let pages = []
  let tags = []
  let counter = @library.ManualPageCounter::new()

  // Collect and finalize the runs, handling things like page parity and tags
  // between pages.
  let mut run_index = 0
  for item in items {
    match item {
      Run(_, _, _) => {
        let layouted = match runs[run_index] {
          Ok(layouted) => layouted
          Err(errors) => raise @library.SourceError(errors)
        }
        run_index += 1
        for layouted in layouted {
          let page = finalize_page(engine, counter, tags, layouted)
          pages.push(page)
        }
      }
      Parity(parity, initial, locator) => {
        if !parity.matches(pages.length()) {
          continue
        }
        let layouted = layout_blank_page(engine, locator.relayout(), initial)
        let page = finalize_page(engine, counter, tags, layouted)
        pages.push(page)
      }
      Tags(items) =>
        for pair in items {
          if @library.TagElem::of(pair.0) is Some(elem) {
            tags.push(elem.tag())
          }
        }
    }
  }

  // Add the remaining tags to the very end of the last page.
  if !tags.is_empty() {
    let last = pages[pages.length() - 1]
    let pos = @library.Point::with_y(last.frame.height())
    last.frame.push_multiple(tags.iter().map(tag => (pos, Tag(tag))))
  }
  pages
}
