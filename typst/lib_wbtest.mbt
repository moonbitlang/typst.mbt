// Tests for the convergence loop of `compile` with synthetic outputs.

///|
/// A world with a single main source.
priv struct TestWorld {
  main : @syntax.Source
  library : @library.Library
}

///|
impl @library.World for TestWorld with fn library(self) {
  self.library
}

///|
impl @library.World for TestWorld with fn main(self) {
  self.main.id()
}

///|
impl @library.World for TestWorld with fn source(self, id) {
  guard id == self.main.id() else { raise @library.FileError::NotFound("?") }
  self.main
}

///|
impl @library.World for TestWorld with fn file(_, _) {
  raise @library.FileError::AccessDenied
}

///|
impl @library.World for TestWorld with fn today(_, _) {
  None
}

///|
fn test_world(text : String) -> TestWorld {
  { main: @syntax.Source::detached(text), library: library([]), }
}

///|
/// An introspector backend that knows `n` labelled elements.
priv struct CountBackend(Int)

///|
impl @library.IntrospectorBackend for CountBackend with fn query(_, _) {
  []
}

///|
impl @library.IntrospectorBackend for CountBackend with fn query_first(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn query_unique(_, _) {
  @library.bail("selector does not match any element")
}

///|
impl @library.IntrospectorBackend for CountBackend with fn query_label(_, _) {
  @library.bail("no label")
}

///|
impl @library.IntrospectorBackend for CountBackend with fn query_labelled(self) {
  Array::makei(self.0, _ => @library.TextElem::packed("x"))
}

///|
impl @library.IntrospectorBackend for CountBackend with fn query_count_before(
  _,
  _,
  _,
) {
  0
}

///|
impl @library.IntrospectorBackend for CountBackend with fn label_count(_, _) {
  0
}

///|
impl @library.IntrospectorBackend for CountBackend with fn locator(_, _, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn pages(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn page(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn position(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn page_numbering(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn page_supplement(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn anchor(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn document(_, _) {
  None
}

///|
impl @library.IntrospectorBackend for CountBackend with fn path(_, _) {
  None
}

///|
/// How many times a test output was created.
let creations : Ref[Int] = { val: 0, }

///|
/// Observes the number of labelled elements `seen` and produces a document
/// with `min(seen + 1, cap)` of them, so it converges after `cap + 1`
/// creations (or never, if that exceeds the iteration limit).
priv struct CountDoc {
  n : Int
}

///|
fn count_doc_create(engine : @library.Engine, cap : Int) -> CountDoc {
  creations.val += 1
  let seen = engine.introspector.query_labelled().length()
  { n: if seen + 1 < cap { seen + 1 } else { cap }, }
}

///|
/// Converges after three creations.
priv struct Capped(CountDoc)

///|
impl @library.Output for Capped with fn target() {
  Paged
}

///|
impl @library.Output for Capped with fn create(engine, _, _) {
  Capped(count_doc_create(engine, 2))
}

///|
impl @library.Output for Capped with fn introspector(self) {
  @library.Introspector::new(CountBackend(self.0.n))
}

///|
/// Never converges.
priv struct Growing(CountDoc)

///|
impl @library.Output for Growing with fn target() {
  Paged
}

///|
impl @library.Output for Growing with fn create(engine, _, _) {
  Growing(count_doc_create(engine, 100))
}

///|
impl @library.Output for Growing with fn introspector(self) {
  @library.Introspector::new(CountBackend(self.0.n))
}

///|
/// Produces a delayed error in every iteration.
priv struct Delaying(Unit)

///|
impl @library.Output for Delaying with fn target() {
  Paged
}

///|
impl @library.Output for Delaying with fn create(engine, content, _) {
  creations.val += 1
  engine.sink.delayed_error(
    @library.SourceDiagnostic::error_at(content.span(), "delayed"),
  )
  Delaying(())
}

///|
impl @library.Output for Delaying with fn introspector(_) {
  @library.Introspector::empty()
}

///|
/// Requires the HTML feature.
priv struct HtmlLike(Unit)

///|
impl @library.Output for HtmlLike with fn target() {
  Html
}

///|
impl @library.Output for HtmlLike with fn create(engine, _, styles) {
  ignore(engine)
  assert_true(@library.TargetElem::target_in(styles) == Html) catch {
    _ => abort("wrong target")
  }
  HtmlLike(())
}

///|
impl @library.Output for HtmlLike with fn introspector(_) {
  @library.Introspector::empty()
}

///|
test "compile converges once the introspector stabilizes" {
  creations.val = 0
  let warned : @library.Warned[Result[Capped, Array[@library.SourceDiagnostic]]] = compile(
    test_world("Hello"),
  )
  guard warned.output is Ok(Capped(doc)) else { fail("expected ok") }
  inspect(doc.n, content="2")
  inspect(creations.val, content="3")
  inspect(warned.warnings.length(), content="0")
}

///|
test "compile gives up after five iterations" {
  creations.val = 0
  let warned : @library.Warned[
    Result[Growing, Array[@library.SourceDiagnostic]],
  ] = compile(test_world("Hello"))
  guard warned.output is Ok(Growing(doc)) else { fail("expected ok") }
  inspect(doc.n, content="5")
  inspect(creations.val, content="5")
}

///|
test "compile promotes delayed errors of the final iteration only" {
  creations.val = 0
  let warned : @library.Warned[
    Result[Delaying, Array[@library.SourceDiagnostic]],
  ] = compile(test_world("Hello"))
  guard warned.output is Err(errors) else { fail("expected err") }
  inspect(creations.val, content="1")
  @debug.debug_inspect(
    errors.map(e => e.message),
    content=(
      #|["delayed"]
    ),
  )
}

///|
test "compile checks the html feature" {
  let world = test_world("Hello")
  let warned : @library.Warned[
    Result[HtmlLike, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  guard warned.output is Ok(_) else { fail("expected ok") }
  @debug.debug_inspect(
    warned.warnings.map(w => w.message),
    content=(
      #|["html export is under active development and incomplete"]
    ),
  )
  let world = {
    ..world,
    library: { ..world.library, features: @library.Features::none(), },
  }
  let warned : @library.Warned[
    Result[HtmlLike, Array[@library.SourceDiagnostic]],
  ] = compile(world)
  guard warned.output is Err(errors) else { fail("expected err") }
  @debug.debug_inspect(
    errors.map(e => e.message),
    content=(
      #|["html export is only available when `--features html` is passed"]
    ),
  )
}

///|
test "compile reports evaluation errors" {
  let warned : @library.Warned[Result[Capped, Array[@library.SourceDiagnostic]]] = compile(
    test_world("#nope #nope"),
  )
  guard warned.output is Err(errors) else { fail("expected err") }
  @debug.debug_inspect(
    errors.map(e => e.message),
    content=(
      #|["unknown variable `nope`"]
    ),
  )
}
