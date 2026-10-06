// Port of `typst-library/src/engine.rs`, `routines.rs` and the `World` /
// `Library` parts of `lib.rs`.

///|
/// An error that occurred while trying to load a file (upstream
/// `diag::FileError`).
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
  /// A virtual Typst path could not be realized into a real path on the
  /// current platform.
  Realize(@syntax.RealizeError)
  /// The package the file is part of could not be loaded.
  Package(PackageError)
  /// Another error.
  ///
  /// The optional string can give more details, if available.
  Other(String?)
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileError with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileError with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FileError with @debug.Debug::{to_repr}

///|
pub impl Show for FileError with fn output(self, logger) {
  match self {
    NotFound(path) =>
      logger.write_string("file not found (searched at \{path})")
    AccessDenied => logger.write_string("failed to load file (access denied)")
    IsDirectory => logger.write_string("failed to load file (is a directory)")
    NotSource => logger.write_string("not a Typst source file")
    InvalidUtf8 => logger.write_string("file is not valid UTF-8")
    Realize(err) => logger.write_string("failed to load file (\{err})")
    Package(err) => Show::output(err, logger)
    Other(Some(err)) => logger.write_string("failed to load file (\{err})")
    Other(None) => logger.write_string("failed to load file")
  }
}

///|
pub extend FileError with Show::{to_string, output}

///|
/// An error that occurred while trying to load a package (upstream
/// `diag::PackageError`).
///
/// Some variants have an optional string can give more details, if available.
pub(all) suberror PackageError {
  /// The specified package does not exist.
  NotFound(@syntax.PackageSpec)
  /// The specified package was found, but the version does not exist.
  VersionNotFound(@syntax.PackageSpec, @syntax.PackageVersion)
  /// Failed to retrieve the package through the network.
  NetworkFailed(String?)
  /// The package archive was malformed.
  MalformedArchive(String?)
  /// Another error.
  Other(String?)
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PackageError with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PackageError with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PackageError with @debug.Debug::{to_repr}

///|
pub impl Show for PackageError with fn output(self, logger) {
  logger.write_string(
    match self {
      NotFound(spec) => "package not found (searched for \{spec})"
      VersionNotFound(spec, latest) =>
        "package found, but version \{spec.version} does not exist (latest is \{latest})"
      NetworkFailed(Some(err)) => "failed to download package (\{err})"
      NetworkFailed(None) => "failed to download package"
      MalformedArchive(Some(err)) => "failed to decompress package (\{err})"
      MalformedArchive(None) =>
        "failed to decompress package (archive malformed)"
      Other(Some(err)) => "failed to load package (\{err})"
      Other(None) => "failed to load package"
    },
  )
}

///|
pub extend PackageError with Show::{to_string, output}

///|
/// The environment in which typesetting occurs.
pub(open) trait World {
  /// The standard library.
  fn library(Self) -> Library
  /// Get the file id of the main source file.
  fn main(Self) -> @syntax.FileId
  /// Try to access the specified file location as a source file.
  fn source(Self, @syntax.FileId) -> @syntax.Source raise FileError
  /// Try to access the specified file.
  ///
  /// For file locations for which [`source`](Self::source) succeeds, this
  /// should also succeed.
  fn file(Self, @syntax.FileId) -> Bytes raise FileError
  /// Metadata about all known fonts.
  fn book(Self) -> FontBook = _
  /// Try to access the font with the given index in the font book.
  fn font(Self, Int) -> Font? = _
  /// Get the current date.
  ///
  /// If no offset is specified, the local date should be chosen. Otherwise,
  /// the UTC date should be chosen with the corresponding offset.
  ///
  /// If this function returns `None`, Typst's `datetime` function will
  /// return an error.
  fn today(Self, Duration?) -> Datetime?
}

///|
/// Worlds without fonts have an empty font book.
impl World with fn book(_) {
  FontBook::new()
}

///|
impl World with fn font(_, _) {
  None
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
pub(all) struct Library {
  /// The function pointers into the compiler.
  routines : Routines
  /// The module that contains the definitions that are available everywhere.
  global : Module
  /// The module that contains the definitions available in math mode.
  math : Module
  /// The default style properties (for page size, font selection, and
  /// everything else configurable via set and show rules).
  styles : Styles
  /// The built-in show rules.
  rules : NativeRuleMap
  /// The standard library as a value. Used to provide the `std` module.
  std : Binding
  /// In-development features that were enabled.
  mut features : Features
  /// Registered export formats.
  formats : Array[Format]
}

///|
/// Holds all data needed during compilation.
pub(all) struct Engine {
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
/// Performs an introspection on the introspector and returns its result.
///
/// As a side effect, the introspection is stored in the sink. If the
/// document does not converge, the recorded introspections are used to
/// determine the cause of non-convergence.
pub fn[T : Fingerprint] Engine::introspect(
  self : Engine,
  introspection : Introspect[T],
) -> T {
  let output = (introspection.introspect)(self, self.introspector)
  self.sink.introspection(Introspection::new(introspection))
  output
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
pub(all) struct Traced(@syntax.Span?)

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
/// A push-only sink for recorded introspections, delayed errors, warnings,
/// and traced values.
pub(all) struct Sink {
  /// Introspections that were performed during compilation.
  introspections : Array[Introspection]
  /// Delayed errors: Those are errors that we can ignore until the last
  /// iteration. For instance, show rules may throw during earlier iterations
  /// because the introspector is not yet ready. We first ignore that and
  /// proceed with empty content and only if the error remains by the end of
  /// the last iteration, we promote it.
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
  {
    introspections: [],
    delayed: [],
    warnings: [],
    warnings_set: @hashset.HashSet([]),
    values: [],
  }
}

///|
/// Get the introspections.
pub fn Sink::introspections(self : Sink) -> ArrayView[Introspection] {
  self.introspections
}

///|
/// Get the stored warnings.
pub fn Sink::warnings(self : Sink) -> Array[SourceDiagnostic] {
  self.warnings.copy()
}

///|
/// Get the values for the traced span.
pub fn Sink::values(self : Sink) -> Array[(Value, Styles?)] {
  self.values.copy()
}

///|
/// Whether nothing was pushed into the sink (not upstream; see `memo.mbt`).
pub fn Sink::is_empty(self : Sink) -> Bool {
  self.introspections.is_empty() &&
  self.delayed.is_empty() &&
  self.warnings.is_empty() &&
  self.values.is_empty()
}

///|
/// Extend from another sink.
pub fn Sink::extend_from_sink(self : Sink, other : Sink) -> Unit {
  self.extend_parts(
    other.introspections,
    other.delayed,
    other.warnings,
    other.values,
  )
}

///|
/// Trace an introspection.
pub fn Sink::introspection(self : Sink, introspection : Introspection) -> Unit {
  self.introspections.push(introspection)
}

///|
/// Add a delayed error.
pub fn Sink::delayed_error(self : Sink, error : SourceDiagnostic) -> Unit {
  self.delayed.push(error)
}

///|
/// Extend from parts of another sink.
fn Sink::extend_parts(
  self : Sink,
  introspections : Array[Introspection],
  delayed : Array[SourceDiagnostic],
  warnings : Array[SourceDiagnostic],
  values : Array[(Value, Styles?)],
) -> Unit {
  self.introspections.append(introspections)
  self.delayed.append(delayed)
  for warning in warnings {
    self.warn(warning)
  }
  for value in values {
    if self.values.length() >= sink_max_values {
      break
    }
    self.values.push(value)
  }
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
pub fn Route::extend_(outer : Route) -> Route {
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
/// A fingerprint of the whole route: the length and file id of every segment
/// (not upstream: part of the memoization key of layout functions; see
/// `memo.mbt`).
pub fn Route::memo_hash(self : Route) -> U128 {
  let state = SipHasher128::new()
  let mut route = self
  while true {
    state.write_usize(route.len)
    match route.id {
      Some(id) => {
        state.write_discriminant(1)
        state.write_u32(id.into_raw().to_uint())
      }
      None => state.write_discriminant(0)
    }
    match route.outer {
      Some(outer) => route = outer
      None => break
    }
  }
  state.finish128()
}

///|
/// The depth of the route: the sum of the lengths of its segments (not
/// upstream; see `route_shift_lo`). Lengths are not negative, so
/// `self.within(depth)` is `self.depth() <= depth`.
pub fn Route::depth(self : Route) -> Int {
  let mut route = self
  let mut depth = 0
  while true {
    depth += route.len
    match route.outer {
      Some(outer) => route = outer
      None => break
    }
  }
  depth
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
/// How much shallower (`route_shift_lo`, at most zero) and deeper
/// (`route_shift_hi`, at least zero) the route of the memoized closure call
/// in progress could be without changing the answer of a depth check made
/// since that call started (not upstream; comemo tracks `Route::within` and
/// reuses a result if the answers are the same; see `memoized_closure` in
/// `memo.mbt`). The answer of `within(depth)` on a route of depth `d` is
/// `d <= depth`: it stays true while the route is at most `depth - d`
/// deeper, and false while it is more than that (a negative number) deeper.
let route_shift_lo : Ref[Int] = { val: route_shift_min, }

///|
let route_shift_hi : Ref[Int] = { val: route_shift_max, }

///|
/// The number of memoized closure calls in progress.
let route_shift_scopes : Ref[Int] = { val: 0, }

///|
/// No bound (far outside the depths that routes can have).
let route_shift_min : Int = -1000000

///|
let route_shift_max : Int = 1000000

///|
/// Narrow the bounds of the call in progress: something in it is only what
/// it was for a change of the depth in `lo..=hi`.
fn note_route_shift(lo : Int, hi : Int) -> Unit {
  if route_shift_scopes.val > 0 {
    if lo > route_shift_lo.val {
      route_shift_lo.val = lo
    }
    if hi < route_shift_hi.val {
      route_shift_hi.val = hi
    }
  }
}

///|
/// [Route::within] for the checks below, noted for memoization.
fn Route::check_within(self : Route, depth : Int) -> Bool {
  let within = self.within(depth)
  if route_shift_scopes.val > 0 {
    let slack = depth - self.depth()
    if within {
      note_route_shift(route_shift_min, slack)
    } else {
      note_route_shift(slack + 1, route_shift_max)
    }
  }
  within
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
  if !self.check_within(max_show_rule_depth) {
    bail_hinted("maximum show rule depth exceeded", [
      "maybe a show rule matches its own output", "maybe there are too deeply nested elements",
    ])
  }
}

///|
/// Ensures that we are within the maximum layout depth.
pub fn Route::check_layout_depth(self : Route) -> Unit raise HintedError {
  if !self.check_within(max_layout_depth) {
    bail_hinted("maximum layout depth exceeded", [
      "try to reduce the amount of nesting in your layout",
    ])
  }
}

///|
/// Ensures that we are within the maximum HTML depth.
pub fn Route::check_html_depth(self : Route) -> Unit raise HintedError {
  if !self.check_within(max_html_depth) {
    bail_hinted("maximum HTML depth exceeded", [
      "try to reduce the amount of nesting of your HTML",
    ])
  }
}

///|
/// Ensures that we are within the maximum function call depth.
pub fn Route::check_call_depth(self : Route) -> Unit raise HintedError {
  if !self.check_within(max_call_depth) {
    bail("maximum function call depth exceeded")
  }
}

///|
/// Data that is contextually made available to code (upstream `Context`).
///
/// Upstream hands it to functions as a `Tracked<Context>`, which only has
/// the three methods below, and memoized functions depend on what they
/// asked of it. Here the context notes what was asked of it (`reads`, not
/// upstream; see `memoized_closure` in `memo.mbt`), so the fields are only
/// read through the methods.
pub struct Context {
  /// The location in the document.
  priv location : Location?
  /// The active styles.
  priv styles : StyleChain?
  /// What was asked of the context since a memoized closure call last
  /// cleared it: [context_read_location], [context_read_styles],
  /// [context_read_introspect].
  priv mut reads : Int
}

///|
/// See [Context]: the location was read.
let context_read_location : Int = 1

///|
/// See [Context]: the styles were read.
let context_read_styles : Int = 2

///|
/// See [Context]: [Context::introspect] was called (which only depends on
/// whether there is any context).
let context_read_introspect : Int = 4

///|
pub fn Context::new(location? : Location, styles? : StyleChain) -> Context {
  { location, styles, reads: 0, }
}

///|
/// An empty context.
pub fn Context::none() -> Context {
  { location: None, styles: None, reads: 0, }
}

///|
/// Try to extract the location.
pub fn Context::location(self : Context) -> Location raise HintedError {
  self.reads = self.reads | context_read_location
  match self.location {
    Some(l) => l
    None => raise HintedError(context_required())
  }
}

///|
/// Try to extract the styles.
pub fn Context::get_styles(self : Context) -> StyleChain raise HintedError {
  self.reads = self.reads | context_read_styles
  match self.styles {
    Some(s) => s
    None => raise HintedError(context_required())
  }
}

///|
/// The location, if there is one (upstream `context.location().ok()`).
pub fn Context::try_location(self : Context) -> Location? {
  self.reads = self.reads | context_read_location
  self.location
}

///|
/// The styles, if there are any (upstream `context.styles().ok()`).
pub fn Context::try_styles(self : Context) -> StyleChain? {
  self.reads = self.reads | context_read_styles
  self.styles
}

///|
/// Guard access to the introspector by requiring at least some piece of
/// context.
pub fn Context::introspect(self : Context) -> Unit raise HintedError {
  self.reads = self.reads | context_read_introspect
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
