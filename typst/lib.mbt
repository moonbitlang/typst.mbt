// Port of `typst/src/lib.rs`.
//
// The compiler for the _Typst_ markup language.
//
// # Steps
// - **Parsing:**
//   The compiler first transforms a plain string into an iterator of tokens.
//   This token stream is parsed into a syntax tree. The tree itself is
//   untyped, but the AST module provides a typed layer over it.
// - **Evaluation:**
//   The next step is to evaluate the markup. This produces a module,
//   consisting of a scope of values that were exported by the code and
//   content, a hierarchical, styled representation of what was written in
//   the source file. The elements of the content tree are well structured and
//   order-independent and thus much better suited for further processing than
//   the raw markup.
// - **Layouting:**
//   Next, the content is laid out into a `PagedDocument` containing one frame
//   per page with items at fixed positions.
// - **Exporting:**
//   These frames can finally be exported into an output format (currently PDF,
//   PNG, SVG, and HTML).
//
// Upstream's comemo-based constraint validation is replaced by the recorded
// introspector reads of `@library.IntrospectionRecorder` (see
// docs/p3-plan.md, section 1).

///|
/// Compiles sources into an output.
///
/// Supported outputs are
/// - the `PagedDocument` (defined in `layout`)
/// - the `HtmlDocument` (defined in `html`)
///
/// Returns the compilation output alongside warnings, if any. The contained
/// result is
/// - `Ok(output)` if there were no fatal errors.
/// - `Err(errors)` if there were fatal errors.
pub fn[T : @library.Output] compile(
  world : &@library.World,
) -> @library.Warned[Result[T, Array[@library.SourceDiagnostic]]] {
  let sink = @library.Sink::new()
  let output = try compile_impl(world, @library.Traced::new(), sink) catch {
    @library.SourceError(errors) => Err(deduplicate(errors))
  } noraise {
    output => Ok(output)
  }
  { output, warnings: sink.warnings(), }
}

///|
/// Compiles sources and returns all values and styles observed at the given
/// `span` during compilation.
pub fn[T : @library.Output] trace(
  world : &@library.World,
  span : @syntax.Span,
) -> Array[(@library.Value, @library.Styles?)] {
  let sink = @library.Sink::new()
  let traced = @library.Traced::new(traced=span)
  let _ : T = compile_impl(world, traced, sink) catch {
    _ => return sink.values()
  }
  sink.values()
}

///|
/// The internal implementation of `compile` with a bit lower-level interface
/// that is also used by `trace`.
fn[T : @library.Output] compile_impl(
  world : &@library.World,
  traced : @library.Traced,
  sink : @library.Sink,
) -> T raise @library.SourceError {
  compile_with(world, traced, sink, library => {
    // Fetch the main source file once.
    let main = world.main()
    let main = world.source(main) catch {
      err =>
        raise @library.SourceError(hint_invalid_main_file(world, err, main))
    }

    // First evaluate the main source file into a module.
    @eval.eval_source(
      world,
      library,
      traced,
      sink,
      @library.Route::root(),
      main,
    ).content()
  })
}

///|
/// `compile_impl` with the evaluation step as a parameter (not upstream):
/// `evaluate` receives the world's library and produces the content that is
/// laid out. Everything else is the compiler's, in upstream's order: the
/// target feature checks, the library and target styles, the evaluation,
/// the memoization lifetime, the relayout loop with tracked introspection,
/// the convergence warnings and the promotion of delayed errors. Used by
/// hosts that build content without a Typst main file (the `doc` package).
pub fn[T : @library.Output] compile_with(
  world : &@library.World,
  traced : @library.Traced,
  sink : @library.Sink,
  evaluate : (@library.Library) -> @library.Content raise @library.SourceError,
) -> T raise @library.SourceError {
  let library = world.library()
  match T::target() {
    Paged => ()
    Html => warn_or_error_for_html(library.features, sink)
    Bundle => warn_or_error_for_bundle(library.features, sink)
  }
  let base = @library.StyleChain::new(library.styles)
  let target = @library.Styles::from_array([
    @library.TargetElem::set_target(T::target()),
  ])
  let styles = base.chain(target)
  let empty_introspector = @library.Introspector::empty()

  // First produce the content (the Typst path evaluates the main source
  // file into a module).
  let content = evaluate(library)
  // Layout results are memoized across the iterations (upstream: comemo;
  // see `library/memo.mbt`).
  let document = @library.with_layout_memo(() => {
    let history : Array[T] = []
    let mut document : T? = None

    // Relayout until all introspections stabilize.
    // If that doesn't happen within five attempts, we give up.
    while true {
      let introspector = match history.last() {
        Some(doc) => doc.introspector()
        None => empty_introspector
      }
      let constraint = @library.IntrospectionRecorder::new()
      let subsink = @library.Sink::new()
      let engine : @library.Engine = {
        library,
        world,
        introspector: introspector.track_with(constraint),
        traced,
        sink: subsink,
        route: @library.Route::root(),
      }
      let doc = T::create(engine, content, styles)
      document = Some(doc)
      if constraint.validate(doc.introspector()) {
        sink.extend_from_sink(subsink)
        break
      }
      if history.length() == @library.max_iters - 1 {
        let introspectors = [empty_introspector]
        for i in 1..<@library.max_iters {
          introspectors.push(history[i - 1].introspector())
        }
        introspectors.push(doc.introspector())
        let warnings = @library.analyze(
          world,
          introspectors,
          subsink.introspections(),
        )
        sink.extend_from_sink(subsink)
        for warning in warnings {
          sink.warn(warning)
        }
        break
      }
      history.push(doc)
    }
    document.unwrap()
  })

  // Promote delayed errors.
  let delayed = sink.take_delayed()
  if !delayed.is_empty() {
    raise @library.SourceError(delayed)
  }
  document
}

///|
/// Deduplicate diagnostics.
pub fn deduplicate(
  diags : Array[@library.SourceDiagnostic],
) -> Array[@library.SourceDiagnostic] {
  let unique : @hashset.HashSet[(@syntax.DiagSpan, String)] = @hashset.HashSet([])
  diags.filter(diag => unique.add_and_check((diag.span, diag.message)))
}

///|
/// Adds useful hints when the main source file couldn't be read
/// and returns the final diagnostic.
fn hint_invalid_main_file(
  world : &@library.World,
  file_error : @library.FileError,
  input : @syntax.FileId,
) -> Array[@library.SourceDiagnostic] {
  let is_utf8_error = file_error is InvalidUtf8
  let diagnostic = @library.SourceDiagnostic::error(
    @syntax.DiagSpan::detached(),
    file_error.to_string(),
  )

  // Attempt to provide helpful hints for UTF-8 errors. Perhaps the user
  // mistyped the filename. For example, they could have written "file.pdf"
  // instead of "file.typ".
  if is_utf8_error {
    match input.vpath().extension() {
      // No hints if the file is already a .typ file. The file is indeed
      // just invalid.
      Some("typ") => return [diagnostic]
      Some(ext) =>
        diagnostic.hint(
          "a file with the `.\{ext}` extension is not usually a Typst file",
        )
      None =>
        diagnostic.hint(
          "a file without an extension is not usually a Typst file",
        )
    }
    let typ = input.get().map(p => p.with_extension("typ")).intern()
    let exists = try world.source(typ) catch {
      _ => false
    } noraise {
      _ => true
    }
    if exists {
      diagnostic.hint("check if you meant to use the `.typ` extension instead")
    }
  }
  [diagnostic]
}

///|
/// HTML export will warn or error depending on whether the feature flag is
/// enabled.
fn warn_or_error_for_html(
  features : @library.Features,
  sink : @library.Sink,
) -> Unit raise @library.SourceError {
  let issue = "https://github.com/typst/typst/issues/5512"
  if features.is_enabled(Html) {
    sink.warn(
      @library.SourceDiagnostic::warning(
        @syntax.DiagSpan::detached(),
        "html export is under active development and incomplete",
      ).with_hints([
        "its behaviour may change at any time",
        "do not rely on this feature for production use cases",
        "see \{issue} for more information",
      ]),
    )
  } else {
    raise @library.SourceError([
      @library.SourceDiagnostic::error(
        @syntax.DiagSpan::detached(),
        "html export is only available when `--features html` is passed",
      ).with_hints([
        "html export is under active development and incomplete",
        "see \{issue} for more information",
      ]),
    ])
  }
}

///|
/// Bundle export will warn or error depending on whether the feature flag is
/// enabled.
fn warn_or_error_for_bundle(
  features : @library.Features,
  sink : @library.Sink,
) -> Unit raise @library.SourceError {
  if features.is_enabled(Bundle) {
    sink.warn(
      @library.SourceDiagnostic::warning(
        @syntax.DiagSpan::detached(),
        "bundle export is experimental",
      ).with_hints([
        "its behaviour may change at any time", "do not rely on this feature for production use cases",
      ]),
    )
  } else {
    raise @library.SourceError([
      @library.SourceDiagnostic::error(
        @syntax.DiagSpan::detached(),
        "bundle export is only available when `--features bundle` is passed",
      ).with_hint("bundle export is experimental"),
    ])
  }
}

///|
/// Creates the default library (upstream `LibraryExt::new`).
///
/// Requires passing in all formats that should be registered, see
/// [library_builder].
pub fn library(formats : Array[@library.Format]) -> @library.Library {
  library_builder(formats).build()
}

///|
/// Creates a builder for configuring a library (upstream
/// `LibraryExt::builder`).
///
/// Requires passing in all formats that should be registered.
pub fn library_builder(
  formats : Array[@library.Format],
) -> @library.LibraryBuilder {
  @library.Library::builder(routines, formats)
}

///|
/// Defines implementation of various Typst compiler routines as a table of
/// function pointers.
///
/// This is essentially dynamic linking and done to allow for package
/// splitting.
pub let routines : @library.Routines = {
  rules: () => {
    let rules = @library.NativeRuleMap::new()
    @layout.register(rules)
    @html.register(rules)
    rules
  },
  eval_string: @eval.routines_eval_string(),
  eval_closure: @eval.routines_eval_closure(),
  realize: @realize.realize,
  layout_frame: @layout.layout_frame,
  html_mathml_body: @html.html_mathml_body,
  html_span_filled: @html.html_span_filled,
}
