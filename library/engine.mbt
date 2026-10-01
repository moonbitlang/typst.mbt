// Port of `typst-library/src/engine.rs`, `routines.rs` and the `World` /
// `Library` parts of `lib.rs`.

///|
/// An error that occurred while trying to load a file.
pub(all) suberror FileError {
  /// A file was not found at this path.
  NotFound(String)
  /// A file could not be accessed.
  AccessDenied
  /// A directory was found, but a file was expected.
  IsDirectory
  /// The file is not a Typst source file, but should have been.
  NotSource
  /// The file was not valid UTF-8, but should have been.
  InvalidUtf8
  /// The package the file is part of could not be loaded.
  Package(String)
  /// Another error.
  Other(String?)
} derive(Eq, Hash, Debug)

///|
pub impl Show for FileError with fn output(self, logger) {
  logger.write_string(
    match self {
      NotFound(path) => "file not found (searched at \{path})"
      AccessDenied => "failed to load file (access denied)"
      IsDirectory => "failed to load file (is a directory)"
      NotSource => "not a typst source file"
      InvalidUtf8 => "file is not valid utf-8"
      Package(error) => error
      Other(Some(err)) => "failed to load file (\{err})"
      Other(None) => "failed to load file"
    },
  )
}

///|
/// The environment in which typesetting occurs.
pub(open) trait World {
  /// The standard library.
  fn library(Self) -> Library
  /// Get the file id of the main source file.
  fn main(Self) -> @syntax.FileId
  /// Try to access the specified source file.
  fn source(Self, @syntax.FileId) -> @syntax.Source raise FileError
  /// Try to access the specified file.
  fn file(Self, @syntax.FileId) -> Bytes raise FileError
  /// Get the current date (with an optional UTC offset in hours).
  fn today(Self, Int64?) -> Datetime?
  /// Resolve a path relative to a file into a file id.
  fn resolve_path(Self, @syntax.FileId?, String) -> @syntax.FileId raise HintedError
}

///|
/// Map a span to a byte range in its file (upstream `WorldExt::range`).
pub fn world_range(world : &World, span : @syntax.DiagSpan) -> (Int, Int)? {
  match span.get() {
    Detached => None
    Number(id~, num~, sub_range~) =>
      world.source(id).range(num, sub_range) catch {
        _ => None
      }
    Range(start~, end~, ..) => Some((start, end))
  }
}

///|
/// Definition of Typst's standard library.
pub struct Library {
  /// The function pointers into the compiler.
  routines : Routines
  /// The module that contains the definitions that are available everywhere.
  global : Module
  /// The module that contains the definitions available in math mode.
  math : Module
  /// The default style properties (for page size, font selection, and
  /// everything else configurable via set and show rules).
  styles : Styles
  /// The standard library as a value. Used to provide the `std` module.
  std : Binding
  /// In-development features that were enabled.
  mut features : Features
}

///|
/// Defines implementation of various Typst compiler routines as a table of
/// function pointers (upstream `Routines`).
pub struct Routines {
  /// Evaluates a string as code/markup/math.
  eval_string : (
    Engine,
    Context,
    String,
    @syntax.Span,
    @syntax.SyntaxMode,
    Scope,
  ) -> Value raise SourceError
  /// Calls a closure.
  eval_closure : (Func, Closure, Engine, Context, Args) -> Value raise SourceError
}

///|
/// Holds all data needed during compilation.
pub struct Engine {
  /// The compilation environment.
  world : &World
  /// The standard library.
  library : Library
  /// Provides access to information about the document.
  introspector : Introspector
  /// May hold a span that is currently under inspection.
  traced : Traced
  /// A pure sink for warnings, delayed errors, and spans under inspection.
  sink : Sink
  /// The route the engine took during compilation.
  route : Route
}

///|
pub fn Engine::routines(self : Engine) -> Routines {
  self.library.routines
}

///|
/// Handles a result without immediately terminating execution. Instead, it
/// produces a delayed error that is only promoted to a fatal one if it
/// remains by the end of the introspection loop.
pub fn[T] Engine::delay(
  self : Engine,
  f : () -> T raise SourceError,
  default : T,
) -> T {
  f() catch {
    SourceError(errors) => {
      self.sink.delayed_errors(errors)
      default
    }
  }
}

///|
/// A binding guard that emits deprecation warnings at `span`.
pub fn Engine::binding_guard(
  self : Engine,
  span : @syntax.Span,
) -> BindingGuard {
  {
    features: self.library.features,
    emit: message => self.sink.warn(message.into_warning_at(span)),
  }
}

///|
/// A clone of the engine with a fresh route level (for nested evaluation).
pub fn Engine::with_route(self : Engine, route : Route) -> Engine {
  { ..self, route, }
}

///|
/// May hold a span that is currently under inspection.
pub struct Traced(@syntax.Span?)

///|
pub fn Traced::new(traced? : @syntax.Span) -> Traced {
  Traced(traced)
}

///|
/// Returns the traced span _if_ it is part of the given source file.
pub fn Traced::get(self : Traced, id : @syntax.FileId) -> @syntax.Span? {
  match self.0 {
    Some(span) if span.id() == Some(id) => Some(span)
    _ => None
  }
}

///|
/// A push-only sink for delayed errors, warnings, and traced values.
pub struct Sink {
  /// Delayed errors: Those are errors that we can ignore until the last
  /// iteration.
  delayed : Array[SourceDiagnostic]
  /// Warnings emitted during iteration.
  warnings : Array[SourceDiagnostic]
  /// Hashes of all warning's spans and messages for warning deduplication.
  warnings_set : @hashset.HashSet[(@syntax.DiagSpan, String)]
  /// A sequence of traced values for a span.
  values : Array[(Value, Styles?)]
}

///|
/// The maximum number of traced values.
pub let sink_max_values : Int = 10

///|
pub fn Sink::new() -> Sink {
  { delayed: [], warnings: [], warnings_set: @hashset.HashSet([]), values: [], }
}

///|
/// Get the stored delayed errors.
pub fn Sink::take_delayed(self : Sink) -> Array[SourceDiagnostic] {
  let out = self.delayed.copy()
  self.delayed.clear()
  out
}

///|
/// Push delayed errors.
pub fn Sink::delayed_errors(
  self : Sink,
  errors : Array[SourceDiagnostic],
) -> Unit {
  self.delayed.append(errors)
}

///|
/// Add a warning (deduplicated by span and message).
pub fn Sink::warn(self : Sink, warning : SourceDiagnostic) -> Unit {
  if self.warnings_set.add_and_check((warning.span, warning.message)) {
    self.warnings.push(warning)
  }
}

///|
/// Trace a value and optionally styles for the traced value.
pub fn Sink::value(self : Sink, value : Value, styles : Styles?) -> Unit {
  if self.values.length() < sink_max_values {
    self.values.push((value, styles))
  }
}

///|
/// The route the engine took during compilation. This is used to detect
/// cyclic imports and excessive nesting.
pub struct Route {
  /// The parent route segment, if present.
  priv outer : Route?
  /// This is set if this route segment was inserted through the start of a
  /// module evaluation.
  priv id : @syntax.FileId?
  /// This is set whenever we enter a function, nested layout, or are applying
  /// a show rule.
  priv mut len : Int
}

///|
/// Create a new, empty route.
pub fn Route::root() -> Route {
  { outer: None, id: None, len: 0, }
}

///|
/// Extend the route with another segment with a default length of 1.
pub fn Route::extend(outer : Route) -> Route {
  { outer: Some(outer), id: None, len: 1, }
}

///|
/// Attach a file id to the route segment.
pub fn Route::with_id(self : Route, id : @syntax.FileId) -> Route {
  { ..self, id: Some(id), }
}

///|
/// Set the length of the route segment to zero.
pub fn Route::unnested(self : Route) -> Route {
  { ..self, len: 0, }
}

///|
/// Increase the nesting depth for this route segment.
pub fn Route::increase(self : Route) -> Unit {
  self.len += 1
}

///|
/// Decrease the nesting depth for this route segment.
pub fn Route::decrease(self : Route) -> Unit {
  self.len -= 1
}

///|
/// Whether the given id is part of the route.
pub fn Route::contains(self : Route, id : @syntax.FileId) -> Bool {
  self.id == Some(id) ||
  (match self.outer {
    Some(outer) => outer.contains(id)
    None => false
  })
}

///|
/// Whether the route's depth is less than or equal to the given depth.
pub fn Route::within(self : Route, depth : Int) -> Bool {
  if depth < self.len {
    return false
  }
  match self.outer {
    Some(outer) => outer.within(depth - self.len)
    None => true
  }
}

///|
pub let max_show_rule_depth : Int = 64

///|
pub let max_layout_depth : Int = 72

///|
pub let max_html_depth : Int = 72

///|
pub let max_call_depth : Int = 80

///|
/// Ensures that we are within the maximum show rule depth.
pub fn Route::check_show_depth(self : Route) -> Unit raise HintedError {
  if !self.within(max_show_rule_depth) {
    bail_hinted("maximum show rule depth exceeded", [
      "maybe a show rule matches its own output", "maybe there are too deeply nested elements",
    ])
  }
}

///|
/// Ensures that we are within the maximum layout depth.
pub fn Route::check_layout_depth(self : Route) -> Unit raise HintedError {
  if !self.within(max_layout_depth) {
    bail_hinted("maximum layout depth exceeded", [
      "try to reduce the amount of nesting in your layout",
    ])
  }
}

///|
/// Ensures that we are within the maximum function call depth.
pub fn Route::check_call_depth(self : Route) -> Unit raise HintedError {
  if !self.within(max_call_depth) {
    bail("maximum function call depth exceeded")
  }
}

///|
/// Data that is contextually made available to code (upstream `Context`).
pub struct Context {
  /// The location in the document.
  location : Location?
  /// The active styles.
  styles : StyleChain?
}

///|
pub fn Context::new(location? : Location, styles? : StyleChain) -> Context {
  { location, styles, }
}

///|
/// An empty context.
pub fn Context::none() -> Context {
  { location: None, styles: None, }
}

///|
/// Try to extract the location.
pub fn Context::location(self : Context) -> Location raise HintedError {
  match self.location {
    Some(l) => l
    None => raise HintedError(context_required())
  }
}

///|
/// Try to extract the styles.
pub fn Context::get_styles(self : Context) -> StyleChain raise HintedError {
  match self.styles {
    Some(s) => s
    None => raise HintedError(context_required())
  }
}

///|
/// Guard access to the introspector by requiring at least some piece of
/// context.
pub fn Context::introspect(self : Context) -> Unit raise HintedError {
  if self.location is None && self.styles is None {
    raise HintedError(context_required())
  }
}

///|
fn context_required() -> HintedString {
  HintedString::new("can only be used when context is known")
  .with_hint("try wrapping this in a `context` expression")
  .with_hint(
    "the `context` expression should wrap everything that depends on this function",
  )
}

///|
/// Identifies an element in the document (placeholder; see
/// introspection/location.rs).
pub(all) struct Location(UInt64) derive(Eq, Hash, Compare)

///|
/// Queries elements and their details (placeholder; see
/// introspection/introspector.rs).
pub struct Introspector {
  priv dummy : Unit
}

///|
pub fn Introspector::empty() -> Introspector {
  { dummy: (), }
}
