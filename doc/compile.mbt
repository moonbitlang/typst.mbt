// Compiling and exporting (docs/edsl-design.md, section 14).

///|
/// A document: a sequence of content and rules.
pub struct Document {
  priv content : Content
  /// The directory of the document, relative to the project root.
  priv dir : String
}

///|
#callsite(autofill(loc, args_loc))
/// `dir` is the directory of the document, relative to the project root
/// (default: the root): relative paths in its arguments and in its
/// `Markup` fragments resolve against it, as they would in a Typst file in
/// that directory.
pub fn Document::Document(
  children : Array[&IntoContent],
  dir? : String = "",
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Document {
  {
    content: Content::of(
      NSeq(snapshot(children), Site::new("Document", loc, args_loc)),
    ),
    dir,
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
/// A range of a project or package file: a Typst source imported by
/// `Markup`, or a data file.
pub struct FileLocation {
  /// The path within the project or package, without a leading slash.
  path : String
  /// The package (`@namespace/name:version`), for package files.
  package_spec : String?
  /// The byte range in the file, if it could be resolved.
  range : (Int, Int)?
  /// One-based line and column of the start (0 if unknown).
  line : Int
  column : Int
}

///|
/// Where a diagnostic points.
pub(all) enum Location {
  /// A constructor call of the EDSL program (and possibly an argument or a
  /// range of a `Markup`/`Equation` source string).
  Edsl(Origin)
  /// A range of a file of the world.
  File(FileLocation)
}

///|
/// The location as text.
pub fn Location::describe(self : Location) -> String {
  match self {
    Edsl(origin) => origin.describe()
    File(file) => {
      let name = match file.package_spec {
        Some(spec) => "\{spec}/\{file.path}"
        None => file.path
      }
      if file.line > 0 {
        "\{name}:\{file.line}:\{file.column}"
      } else {
        name
      }
    }
  }
}

///|
/// A point of a diagnostic's trace: what was being done, and where.
pub struct TracePoint {
  description : String
  location : Location?
}

///|
/// A hint of a diagnostic.
pub struct Hint {
  message : String
  location : Location?
}

///|
/// An error or warning of a compilation or export, with its locations
/// resolved when the report was built (they do not depend on a world or on
/// file ids afterwards).
pub struct Diagnostic {
  severity : Severity
  message : String
  hints : Array[Hint]
  /// Where the problem is.
  location : Location?
  trace : Array[TracePoint]
  /// The engine's diagnostic. Its spans refer to files of the world and to
  /// the virtual files of the report's [Origins].
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
  if self.location is Some(location) {
    out.write_string("\n  at ")
    out.write_string(location.describe())
  }
  for hint in self.hints {
    out.write_string("\n  hint: ")
    out.write_string(hint.message)
    if hint.location is Some(location) {
      out.write_string(" (")
      out.write_string(location.describe())
      out.write_string(")")
    }
  }
  for point in self.trace {
    out.write_string("\n  ")
    out.write_string(point.description)
    if point.location is Some(location) {
      out.write_string(" at ")
      out.write_string(location.describe())
    }
  }
  out.to_string()
}

///|
/// Resolves diagnostic spans while the world is available.
priv struct Resolver {
  origins : Origins
  world : &@library.World
}

///|
/// The location of a span: an origin for spans of the session's virtual
/// files, a file range for spans of the world's files.
fn Resolver::locate(self : Resolver, span : @syntax.DiagSpan) -> Location? {
  if self.origins.resolve_range(span) is Some(origin) {
    return Some(Edsl(origin))
  }
  guard span.id() is Some(id) else { return None }
  let package_spec = match id.root() {
    Project => Option::None
    Package(spec) => Some("@\{spec.namespace_}/\{spec.name}:\{spec.version}")
  }
  let path = id.vpath().get_without_slash()
  // The byte range: numbered spans through the parsed source, raw ranges
  // (data files) directly.
  let mut range : (Int, Int)? = None
  let mut lines : @syntax.Lines? = None
  match span.get() {
    Number(num~, sub_range~, ..) =>
      try self.world.source(id) catch {
        _ => ()
      } noraise {
        source => {
          range = source.range(num, sub_range)
          lines = Some(source.lines())
        }
      }
    Range(start~, end~, ..) => {
      range = Some((start, end))
      try self.world.file(id) catch {
        _ => ()
      } noraise {
        bytes =>
          try @utf8.decode(bytes) catch {
            _ => ()
          } noraise {
            text => lines = Some(@syntax.Lines::new(text))
          }
      }
    }
    Detached => ()
  }
  let (line, column) = match (range, lines) {
    (Some((start, _)), Some(lines)) =>
      match lines.byte_to_line_column(start) {
        Some((line, column)) => (line + 1, column + 1)
        None => (0, 0)
      }
    _ => (0, 0)
  }
  Some(File({ path, package_spec, range, line, column, }))
}

///|
fn Resolver::diagnostic(
  self : Resolver,
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
      location: self.locate(hint.span),
    }),
    location: self.locate(raw.span),
    trace: raw.trace.map(point => {
      description: point.v.to_string(),
      location: self.locate(@syntax.DiagSpan::from_span(point.span)),
    }),
    raw,
  }
}

///|
fn Resolver::diagnostics(
  self : Resolver,
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
  /// Resolves the diagnostics of exports started from this report.
  priv resolver : Resolver
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
/// Initial lowering: runs in the evaluator's environment (`eval_source`),
/// without an introspector and without context.
fn Document::lower_initial(
  self : Document,
  session : Session,
  world : SessionWorld,
  library : @library.Library,
  traced : @library.Traced,
  sink : @library.Sink,
) -> @library.Content raise @library.SourceError {
  let engine : @library.Engine = {
    world,
    library,
    introspector: @library.Introspector::empty(),
    traced,
    sink,
    route: @library.Route::extend_(@library.Route::root()).with_id(
      session.registry.origins,
    ),
  }
  let lower : Lowering = {
    session,
    engine,
    context: @library.Context::none(),
    keys: [],
    pieces: Option::None,
  }
  lower.check_text(self.dir, @syntax.Span::detached())
  if virtual_file(self.dir, "<edsl-origins>") is Option::None {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        @syntax.Span::detached(),
        "the document's directory is not a path inside the project: \{self.dir}",
      ),
    ])
  }
  lower.content(self.content, @syntax.Span::detached())
}

///|
/// Build the report of a session.
fn[T] Session::report(
  self : Session,
  result : Result[T, Array[@library.SourceDiagnostic]],
  sink : @library.Sink,
) -> CompileReport[T] {
  let origins = self.registry.freeze()
  let resolver : Resolver = { origins, world: self.base, }
  let warnings = resolver.diagnostics(@typst.deduplicate(sink.warnings()))
  match result {
    Ok(output) =>
      { output: Some(output), errors: [], warnings, origins, resolver, }
    Err(errors) =>
      {
        output: None,
        errors: resolver.diagnostics(errors),
        warnings,
        origins,
        resolver,
      }
  }
}

///|
/// Compile to any output of the engine.
pub fn[T : @library.Output] Document::compile(
  self : Document,
  world : &@library.World,
) -> CompileReport[T] {
  let session = Session::new(world, dir=self.dir)
  let session_world : SessionWorld = { session, }
  let sink = @library.Sink::new()
  let traced = @library.Traced::new()
  let evaluate = library => {
    self.lower_initial(session, session_world, library, traced, sink)
  }
  let result : Result[T, Array[@library.SourceDiagnostic]] = try
    @typst.compile_with(session_world, traced, sink, evaluate)
  catch {
    @library.SourceError(errors) => Err(@typst.deduplicate(errors))
  } noraise {
    output => Ok(output)
  }
  session.report(result, sink)
}

///|
/// Lower the document to engine content without laying it out: what the
/// compiler would lay out. For tests and tools; callbacks in the content
/// stay bound to this lowering's origins.
pub fn Document::lower(
  self : Document,
  world : &@library.World,
) -> CompileReport[@library.Content] {
  let session = Session::new(world, dir=self.dir)
  let session_world : SessionWorld = { session, }
  let sink = @library.Sink::new()
  let traced = @library.Traced::new()
  let result : Result[@library.Content, Array[@library.SourceDiagnostic]] = try
    self.lower_initial(
      session,
      session_world,
      session_world.session.base.library(),
      traced,
      sink,
    )
  catch {
    @library.SourceError(errors) => Err(@typst.deduplicate(errors))
  } noraise {
    output => Ok(output)
  }
  session.report(result, sink)
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
  warnings.append(self.resolver.diagnostics(warned.warnings))
  match warned.output {
    Ok(bytes) =>
      { output: Some(bytes), errors: [], warnings, origins: self.origins, }
    Err(errors) =>
      {
        output: None,
        errors: self.resolver.diagnostics(errors),
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
          errors: [self.resolver.diagnostic(error)],
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
