// Compiling and exporting (docs/edsl-design.md, section 14).

///|
/// A document: a sequence of content and rules.
pub struct Document {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Document::Document(
  children : Array[&IntoContent],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Document {
  {
    content: Content::of(
      NSeq(snapshot(children), Site::new("Document", loc, args_loc)),
    ),
  }
}

///|
pub impl IntoContent for Document with fn into_content(self) {
  self.content
}

///|
/// Whether a diagnostic is an error or a warning.
pub(all) enum Severity {
  Error
  Warning
} derive(Eq)

///|
/// A point of a diagnostic's trace: what was being done, and where.
pub struct TracePoint {
  description : String
  origin : Origin?
}

///|
/// A hint of a diagnostic.
pub struct Hint {
  message : String
  origin : Origin?
}

///|
/// An error or warning of a compilation or export, with its location in
/// the EDSL program resolved.
pub struct Diagnostic {
  severity : Severity
  message : String
  hints : Array[Hint]
  /// Where the problem is: the constructor call (and argument).
  origin : Origin?
  trace : Array[TracePoint]
  /// The engine's diagnostic. Its spans refer to the virtual files of the
  /// report's [Origins].
  raw : @library.SourceDiagnostic
}

///|
/// The diagnostic as text: the message, its location, hints and trace.
pub fn Diagnostic::render(self : Diagnostic) -> String {
  let out = StringBuilder()
  out.write_string(
    match self.severity {
      Error => "error: "
      Warning => "warning: "
    },
  )
  out.write_string(self.message)
  if self.origin is Some(origin) {
    out.write_string("\n  at ")
    out.write_string(origin.describe())
  }
  for hint in self.hints {
    out.write_string("\n  hint: ")
    out.write_string(hint.message)
    if hint.origin is Some(origin) {
      out.write_string(" (")
      out.write_string(origin.position())
      out.write_string(")")
    }
  }
  for point in self.trace {
    out.write_string("\n  ")
    out.write_string(point.description)
    if point.origin is Some(origin) {
      out.write_string(" at ")
      out.write_string(origin.describe())
    }
  }
  out.to_string()
}

///|
fn Origins::diagnostic(
  self : Origins,
  raw : @library.SourceDiagnostic,
) -> Diagnostic {
  {
    severity: match raw.severity {
      Error => Error
      Warning => Warning
    },
    message: raw.message,
    hints: raw.hints.map(hint => {
      message: hint.v,
      origin: self.resolve_range(hint.span),
    }),
    origin: self.resolve_range(raw.span),
    trace: raw.trace.map(point => {
      description: point.v.to_string(),
      origin: self.resolve(point.span),
    }),
    raw,
  }
}

///|
fn Origins::diagnostics(
  self : Origins,
  raw : Array[@library.SourceDiagnostic],
) -> Array[Diagnostic] {
  raw.map(d => self.diagnostic(d))
}

///|
/// Raised by `unwrap` on a failed report.
pub suberror DocError {
  DocError(Array[Diagnostic])
}

///|
pub impl @builtin.Show for DocError with fn output(self, logger) {
  let DocError(errors) = self
  logger.write_string(errors.map(e => e.render()).join("\n"))
}

///|
/// The result of a compilation: the output or the errors, the warnings,
/// and the origins all diagnostics and spans refer to. The origins are an
/// immutable snapshot owned by the report, on success and on failure.
pub struct CompileReport[T] {
  priv output : T?
  /// The errors (empty iff there is an output).
  errors : Array[Diagnostic]
  warnings : Array[Diagnostic]
  origins : Origins
}

///|
/// The compiled output, if the compilation succeeded.
pub fn[T] CompileReport::output(self : CompileReport[T]) -> T? {
  self.output
}

///|
/// The compiled output; raises the errors otherwise.
pub fn[T] CompileReport::unwrap(self : CompileReport[T]) -> T raise DocError {
  match self.output {
    Some(output) => output
    None => raise DocError(self.errors)
  }
}

///|
/// The result of an export: like [CompileReport], with the warnings of the
/// compilation followed by those of the export.
pub struct ExportReport[T] {
  priv output : T?
  errors : Array[Diagnostic]
  warnings : Array[Diagnostic]
  origins : Origins
}

///|
pub fn[T] ExportReport::output(self : ExportReport[T]) -> T? {
  self.output
}

///|
pub fn[T] ExportReport::unwrap(self : ExportReport[T]) -> T raise DocError {
  match self.output {
    Some(output) => output
    None => raise DocError(self.errors)
  }
}

///|
/// Compile to any output of the engine.
pub fn[T : @library.Output] Document::compile(
  self : Document,
  world : &@library.World,
) -> CompileReport[T] {
  let session = Session::new(world)
  let session_world : SessionWorld = { session, }
  let sink = @library.Sink::new()
  let traced = @library.Traced::new()
  let result : Result[T, Array[@library.SourceDiagnostic]] = try
    @typst.compile_with(session_world, traced, sink, library => {
      // Initial lowering runs in the evaluator's environment
      // (`eval_source`): no introspector, no context.
      let engine : @library.Engine = {
        world: session_world,
        library,
        introspector: @library.Introspector::empty(),
        traced,
        sink,
        route: @library.Route::extend(@library.Route::root()).with_id(
          origins_file,
        ),
      }
      let lower : Lower = {
        session,
        engine,
        context: @library.Context::none(),
        keys: [],
      }
      lower.content(self.content, @syntax.Span::detached())
    })
  catch {
    @library.SourceError(errors) => Err(@typst.deduplicate(errors))
  } noraise {
    output => Ok(output)
  }
  let origins = session.registry.freeze()
  let warnings = origins.diagnostics(@typst.deduplicate(sink.warnings()))
  match result {
    Ok(output) => { output: Some(output), errors: [], warnings, origins, }
    Err(errors) =>
      { output: None, errors: origins.diagnostics(errors), warnings, origins, }
  }
}

///|
/// Compile to a paged document (for PDF, SVG and PNG export).
pub fn Document::compile_paged(
  self : Document,
  world : &@library.World,
) -> CompileReport[@layout.PagedDocument] {
  self.compile(world)
}

///|
/// An export report for a failed compilation.
fn[T, U] CompileReport::failed(self : CompileReport[T]) -> ExportReport[U] {
  {
    output: None,
    errors: self.errors,
    warnings: self.warnings,
    origins: self.origins,
  }
}

///|
/// Export to PDF. Explicit options override the document's settings.
pub fn CompileReport::pdf(
  self : CompileReport[@layout.PagedDocument],
  options? : @pdf.PdfOptions = @pdf.PdfOptions::default(),
) -> ExportReport[Bytes] {
  guard self.output is Some(document) else { return self.failed() }
  let warned = @pdf.pdf(document, options)
  let warnings = self.warnings.copy()
  warnings.append(self.origins.diagnostics(warned.warnings))
  match warned.output {
    Ok(bytes) =>
      { output: Some(bytes), errors: [], warnings, origins: self.origins, }
    Err(errors) =>
      {
        output: None,
        errors: self.origins.diagnostics(errors),
        warnings,
        origins: self.origins,
      }
  }
}

///|
/// Export every page to SVG.
pub fn CompileReport::svg_pages(
  self : CompileReport[@layout.PagedDocument],
  options? : @svg.SvgOptions = @svg.SvgOptions::default(),
) -> ExportReport[Array[String]] {
  guard self.output is Some(document) else { return self.failed() }
  let options = options.resolve(@svg.SvgFormatOptions::get(document.options()))
  let pages = document.pages().map(page => @svg.svg(page, options))
  {
    output: Some(pages),
    errors: [],
    warnings: self.warnings,
    origins: self.origins,
  }
}

///|
/// Export every page to PNG.
pub fn CompileReport::png_pages(
  self : CompileReport[@layout.PagedDocument],
  ppi? : Double,
) -> ExportReport[Array[Bytes]] {
  guard self.output is Some(document) else { return self.failed() }
  let options : @render.RenderOptions = {
    render_bleed: false,
    format: { ppi, },
  }
  let options = options.resolve(
    @render.PngFormatOptions::get(document.options()),
  )
  let pages : Array[Bytes] = []
  for page in document.pages() {
    let pixmap = @render.render(page, options) catch {
      @render.RenderPanic(message) => {
        let error = @library.SourceDiagnostic::error(
          @syntax.DiagSpan::detached(),
          message,
        )
        return {
          output: None,
          errors: [self.origins.diagnostic(error)],
          warnings: self.warnings,
          origins: self.origins,
        }
      }
    }
    pages.push(pixmap.encode_png())
  }
  {
    output: Some(pages),
    errors: [],
    warnings: self.warnings,
    origins: self.origins,
  }
}
