// Port of `typst-bundle/src/export.rs`.
//
// PDF export (`typst-pdf`) and PNG export (`typst-render`) are not part of
// this module's dependencies yet; they are plugged in through the
// [BundleOptions] hooks `pdf` and `png` (see [PdfExport] and [PngExport]).
// Without a hook, exporting such a document fails with an error.

///|
/// A raw mapping from paths to bytes (in bundle order).
pub type VirtualFs = Map[@syntax.VirtualPath, @library.BytesValue]

///|
/// Exports a paged document to PDF as part of a bundle (upstream
/// `typst_pdf::pdf_in_bundle(doc, &options.pdf, anchors, link_resolver)`,
/// with the PDF options bound).
pub type PdfExport = (
  @layout.PagedDocument,
  Array[(@library.Location, String)],
  @library.LateLinkResolver,
) -> @library.Warned[Result[Bytes, Array[@library.SourceDiagnostic]]]

///|
/// Renders the single page of a paged document to PNG (upstream
/// `typst_render::render(&doc.pages()[0], &options.png.resolve(..))
/// .encode_png()`, with the render options bound).
pub type PngExport = (@layout.PagedDocument) -> Bytes raise @library.SourceError

///|
/// Settings for bundle export.
pub(all) struct BundleOptions {
  /// Options for exporting HTML documents.
  html : @html.HtmlOptions
  /// Exports PDF documents (upstream: `pdf: PdfOptions`, passed to
  /// `typst_pdf::pdf_in_bundle`).
  pdf : PdfExport?
  /// Exports PNG documents (upstream: `png: RenderOptions`, passed to
  /// `typst_render`).
  png : PngExport?
  /// Options for exporting SVG documents.
  svg : @svg.SvgOptions
}

///|
pub impl Default for BundleOptions with fn default() {
  { html: Default::default(), pdf: None, png: None, svg: Default::default(), }
}

///|
/// Exports a bundle into a raw virtual file system (upstream `export`, a
/// reserved word in MoonBit).
pub fn export_bundle(
  bundle : Bundle,
  options : BundleOptions,
) -> @library.Warned[Result[VirtualFs, Array[@library.SourceDiagnostic]]] {
  // Upstream: `collect_combined_warned_result` over all files.
  let warnings = []
  let errors = []
  let fs : VirtualFs = Map([])
  for path, file in bundle.files {
    let data : @library.Warned[
      Result[@library.BytesValue, Array[@library.SourceDiagnostic]],
    ] = match file {
      Document(doc) => {
        let link_resolver = @library.LateLinkResolver::new(
          Some(path),
          bundle.introspector,
        )
        export_document(doc, options, link_resolver)
      }
      Asset(bytes) => { output: Ok(bytes), warnings: [], }
    }
    warnings.append(data.warnings)
    match data.output {
      Ok(data) => fs[path] = data
      Err(errs) => errors.append(errs)
    }
  }
  let output = if errors.is_empty() { Ok(fs) } else { Err(errors) }
  { output, warnings, }
}

///|
/// Converts a `SourceResult` into a `Warned` without warnings.
fn[T] unwarned(
  f : () -> T raise @library.SourceError,
) -> @library.Warned[Result[T, Array[@library.SourceDiagnostic]]] {
  let output = try f() catch {
    @library.SourceError(errors) => Err(errors)
  } noraise {
    v => Ok(v)
  }
  { output, warnings: [], }
}

///|
/// Exports a single document.
fn export_document(
  doc : BundleDocument,
  options : BundleOptions,
  link_resolver : @library.LateLinkResolver,
) -> @library.Warned[
  Result[@library.BytesValue, Array[@library.SourceDiagnostic]],
] {
  match doc {
    Paged(doc, extras) =>
      match extras.format {
        Pdf => export_pdf(doc, options.pdf, extras.anchors, link_resolver)
        Png => unwarned(() => export_png(doc, options.png))
        Svg =>
          unwarned(() => {
            export_svg(doc, options.svg, extras.anchors, link_resolver)
          })
      }
    Html(doc) => {
      let options = options.html.resolve(
        @library.HtmlFormatOptions::get(doc.options()),
      )
      unwarned(() => export_html(doc.root(), options, link_resolver))
    }
  }
}

///|
/// Exports a PDF document.
fn export_pdf(
  doc : @layout.PagedDocument,
  exporter : PdfExport?,
  anchors : Array[(@library.Location, String)],
  link_resolver : @library.LateLinkResolver,
) -> @library.Warned[
  Result[@library.BytesValue, Array[@library.SourceDiagnostic]],
] {
  guard exporter is Some(exporter) else {
    return unwarned(() => {
      @library.bail_at(
        @syntax.Span::detached(),
        "PDF export is not available in this build",
      )
    })
  }
  let { output, warnings, } = exporter(doc, anchors, link_resolver)
  { output: output.map(@library.BytesValue::new), warnings, }
}

///|
/// Exports a PNG document.
fn export_png(
  doc : @layout.PagedDocument,
  exporter : PngExport?,
) -> @library.BytesValue raise @library.SourceError {
  guard exporter is Some(exporter) else {
    @library.bail_at(
      @syntax.Span::detached(),
      "PNG export is not available in this build",
    )
  }
  @library.BytesValue::new(exporter(doc))
}

///|
/// Exports an SVG document.
fn export_svg(
  doc : @layout.PagedDocument,
  options : @svg.SvgOptions,
  anchors : Array[(@library.Location, String)],
  link_resolver : @library.LateLinkResolver,
) -> @library.BytesValue {
  let anchors = anchors.filter_map(pair => {
    let (loc, name) = pair
    // We only support a single page at the moment and all anchor location
    // should point into it, so it's safe to extract just the point using the
    // document's introspector.
    doc.paged_introspector().position(loc).map(pos => (pos.point, name))
  })
  let options = options.resolve(@svg.SvgFormatOptions::get(doc.options()))
  @library.BytesValue::from_string(
    @svg.svg_in_bundle(doc.pages()[0], options, anchors[:], link_resolver),
  )
}

///|
/// Exports an HTML document.
///
/// This function takes the root element rather than the document because it
/// doesn't need the metadata or introspector (upstream memoizes it).
fn export_html(
  root : @html.HtmlElement,
  options : @html.CompleteHtmlOptions,
  link_resolver : @library.LateLinkResolver,
) -> @library.BytesValue raise @library.SourceError {
  @library.BytesValue::from_string(
    @html.html_in_bundle(root, options, link_resolver),
  )
}
