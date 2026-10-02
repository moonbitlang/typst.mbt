// Port of `typst-eval/src/lib.rs`.

///|
/// Evaluate a source file and return the resulting module.
pub fn eval_source(
  world : &@library.World,
  library : @library.Library,
  traced : @library.Traced,
  sink : @library.Sink,
  route : @library.Route,
  source : @syntax.Source,
) -> @library.Module raise @library.SourceError {
  // Prevent cyclic evaluation.
  let id = source.id()
  if route.contains(id) {
    abort("Tried to cyclicly evaluate a source file")
  }

  // Prepare the engine.
  let engine : @library.Engine = {
    library,
    world,
    introspector: @library.Introspector::empty(),
    traced,
    sink,
    route: @library.Route::extend(route).with_id(id),
  }

  // Prepare VM.
  let context = @library.Context::none()
  let scopes = @library.Scopes::new(Some(library))
  let root = source.root()
  let vm = Vm::new(engine, context, scopes, root.span())

  // Check for well-formedness unless we are in trace mode.
  let (errors, warnings) = root.errors_and_warnings()
  for warning in warnings {
    vm.engine.sink.warn(@library.SourceDiagnostic::from_syntax(warning))
  }
  if !errors.is_empty() && vm.inspected is None {
    raise @library.SourceError(
      errors.map(@library.SourceDiagnostic::from_syntax),
    )
  }

  // Evaluate the module.
  let markup = @ast.Markup::from_untyped(root).unwrap()
  let output = eval_markup(vm, markup)

  // Handle control flow.
  if vm.flow is Some(flow) {
    @library.bail_diag(flow.forbidden())
  }

  // Assemble the module.
  let name = id.vpath().file_stem().unwrap_or("")
  @library.Module::new(name, vm.scopes.top)
  .with_content(output)
  .with_file_id(id)
}

///|
/// Evaluate a string as code and return the resulting value.
pub fn eval_string(
  engine : @library.Engine,
  context : @library.Context,
  string : String,
  span : @syntax.Span,
  mode : @syntax.SyntaxMode,
  scope : @library.Scope,
) -> @library.Value raise @library.SourceError {
  let root = match mode {
    Code => @syntax.parse_code(string)
    Markup => @syntax.parse(string)
    Math => @syntax.parse_math(string)
  }
  if !span.is_detached() {
    root.synthesize(span)
  }
  eval_root(engine, context, root, mode, scope)
}

///|
/// Evaluate a string as code with mapped spans (upstream `eval_string` with
/// `SpanMode::Mapped` and the identity mapper over the whole text): the
/// string is the content of the file `id`, so that diagnostics point into
/// it.
pub fn eval_string_mapped(
  engine : @library.Engine,
  context : @library.Context,
  string : String,
  id : @syntax.FileId,
  mode : @syntax.SyntaxMode,
  scope : @library.Scope,
) -> @library.Value raise @library.SourceError {
  let root = match mode {
    Code => @syntax.parse_code(string)
    Markup => @syntax.parse(string)
    Math => @syntax.parse_math(string)
  }
  root.synthesize_ranges(id)
  eval_root(engine, context, root, mode, scope)
}

///|
/// Evaluate a parsed string (the rest of `eval_string`).
fn eval_root(
  engine : @library.Engine,
  context : @library.Context,
  root : @syntax.SyntaxNode,
  mode : @syntax.SyntaxMode,
  scope : @library.Scope,
) -> @library.Value raise @library.SourceError {

  // Check for well-formedness.
  let (errors, warnings) = root.errors_and_warnings()
  for warning in warnings {
    engine.sink.warn(@library.SourceDiagnostic::from_syntax(warning))
  }
  if !errors.is_empty() {
    raise @library.SourceError(
      errors.map(@library.SourceDiagnostic::from_syntax),
    )
  }

  // Prepare the engine.
  let engine : @library.Engine = {
    ..engine,
    traced: @library.Traced::new(),
    route: @library.Route::root(),
  }

  // Prepare VM.
  let scopes = @library.Scopes::new(Some(engine.library))
  let vm = Vm::new(engine, context, scopes, root.span())
  vm.scopes.scopes.push(scope)

  // Evaluate the code.
  let output : @library.Value = match mode {
    Code => eval_code(vm, @ast.Code::from_untyped(root).unwrap())
    Markup => Content(eval_markup(vm, @ast.Markup::from_untyped(root).unwrap()))
    Math =>
      Content(
        @library.Content::new(@library.equation_elem(), [
          (
            @library.equation_elem_body,
            Content(eval_math(vm, @ast.Math::from_untyped(root).unwrap())),
          ),
        ])
        .with_field(@library.equation_elem_block, Bool(false))
        .spanned(root.span()),
      )
  }

  // Handle control flow.
  if vm.flow is Some(flow) {
    @library.bail_diag(flow.forbidden())
  }
  output
}

///|
/// The routines implemented by this package.
pub fn routines_eval_closure() -> (
  @library.Func,
  @library.Closure,
  @library.Engine,
  @library.Context,
  @library.Args,
) -> @library.Value raise @library.SourceError {
  eval_closure
}

///|
/// The `eval_string` routine.
pub fn routines_eval_string() -> (
  @library.Engine,
  @library.Context,
  String,
  @syntax.Span,
  @syntax.SyntaxMode,
  @library.Scope,
) -> @library.Value raise @library.SourceError {
  eval_string
}
