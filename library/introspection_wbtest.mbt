// Unit tests for the introspection core: hashing, locators, the element
// introspector, read recording and convergence analysis.

///|
/// A minimal world for engines in tests.
priv struct WbWorld {
  library : Library
}

///|
impl World for WbWorld with fn library(self) {
  self.library
}

///|
impl World for WbWorld with fn main(_) {
  @syntax.Source::detached("").id()
}

///|
impl World for WbWorld with fn source(_, _) {
  raise FileError::AccessDenied
}

///|
impl World for WbWorld with fn file(_, _) {
  raise FileError::AccessDenied
}

///|
impl World for WbWorld with fn today(_, _) {
  None
}

///|
let wb_library_cell : Ref[Library?] = Ref(None)

///|
fn wb_library() -> Library {
  match wb_library_cell.val {
    Some(lib) => lib
    None => {
      let routines = Routines::new(eval_string=(_, _, _, _, _, _) => None, eval_closure=(
        _,
        _,
        _,
        _,
        _,
      ) => None)
      let lib = Library::builder(routines, []).build()
      wb_library_cell.val = Some(lib)
      lib
    }
  }
}

///|
fn wb_engine(introspector : Introspector) -> Engine {
  let library = wb_library()
  let world : WbWorld = { library, }
  {
    world: TrackedWorld::new(world),
    library,
    introspector,
    traced: Traced::new(),
    sink: Sink::new(),
    route: Route::root(),
  }
}

///|
/// A target-specific introspector over an element introspector.
priv struct WbIntrospector(ElementIntrospector[Unit])

///|
impl IntrospectorBackend for WbIntrospector with fn query(self, s) {
  self.0.query(s)
}

///|
impl IntrospectorBackend for WbIntrospector with fn query_first(self, s) {
  self.0.query_first(s)
}

///|
impl IntrospectorBackend for WbIntrospector with fn query_unique(self, s) {
  self.0.query_unique(s)
}

///|
impl IntrospectorBackend for WbIntrospector with fn query_label(self, l) {
  self.0.query_label(l)
}

///|
impl IntrospectorBackend for WbIntrospector with fn query_labelled(self) {
  self.0.query_labelled()
}

///|
impl IntrospectorBackend for WbIntrospector with fn query_count_before(
  self,
  s,
  l,
) {
  self.0.query_count_before(s, l)
}

///|
impl IntrospectorBackend for WbIntrospector with fn label_count(self, l) {
  self.0.label_count(l)
}

///|
impl IntrospectorBackend for WbIntrospector with fn locator(self, k, b) {
  self.0.locator(k, b)
}

///|
impl IntrospectorBackend for WbIntrospector with fn pages(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn page(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn position(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn page_numbering(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn page_supplement(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn anchor(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn document(_, _) {
  None
}

///|
impl IntrospectorBackend for WbIntrospector with fn path(_, _) {
  None
}

///|
fn wb_introspector(elems : ElementIntrospector[Unit]) -> Introspector {
  Introspector::new(WbIntrospector(elems) as &IntrospectorBackend)
}

///|
fn loc(n : UInt64) -> Location {
  Location::new(U128::from_u64(n))
}

///|
/// A located metadata element with the value `n`.
fn meta(n : Int, label? : String) -> Content {
  let c = MetadataElem::new(Int(n.to_int64()))
    .pack()
    .located(loc(n.to_uint64()))
  match label {
    Some(l) => c.labelled(Label(l))
    None => c
  }
}

///|
let introspectable : TagFlags = { introspectable: true, tagged: false, }

///|
/// Discover an element with its children (nested between start and end
/// tags).
fn discover(
  builder : ElementIntrospectorBuilder[Unit],
  elem : Content,
  children : Array[Content],
) -> Unit {
  builder.discover_tag(Start(elem, introspectable), ())
  for child in children {
    discover(builder, child, [])
  }
  builder.discover_tag(
    End(elem.location().unwrap(), U128::from_u64(1000), introspectable),
    (),
  )
}

///|
fn values(list : Array[Content]) -> Array[Int64] {
  list.map(c => {
    match MetadataElem::of(c) {
      Some(m) =>
        match m.value() {
          Int(n) => n
          _ => -1L
        }
      None => -1L
    }
  })
}

///|
fn ignore_error(f : () -> Content raise HintedError) -> Unit {
  try f() catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
fn opt_list(c : Content?) -> Array[Content] {
  match c {
    Some(c) => [c]
    None => []
  }
}

///|
/// Document: 1 [2, 3] 4<a> [5<b>] 6<b>
fn sample() -> ElementIntrospector[Unit] {
  let builder = ElementIntrospectorBuilder::new()
  discover(builder, meta(1), [meta(2), meta(3)])
  discover(builder, meta(4, label="a"), [meta(5, label="b")])
  discover(builder, meta(6, label="b"), [])
  builder.finalize()
}

///|
test "hash128 matches upstream SipHash-1-3" {
  inspect(hash128(()), content="0xb91c5ed031fb33032134935d61d9b40d")
  inspect(
    hash128((u128_zero, 0, u128_zero)),
    content="0x9c096e071bb6d63ff4dc66da55b1c5e2",
  )
  inspect(
    hash128((U128::from_u64(5), 3)),
    content="0x54041333c00c5e2a9aa1ac1500dcbdf7",
  )
  inspect(hash128("hello"), content="0x6a4e45bf82c2c7d663e88709613557cd")
  inspect(hash128((1UL, 2UL)), content="0xd53c89d777fafa33b3650b0bf1042e50")
  let state = SipHasher128::new()
  state.write_u8(b'\x07')
  state.write_u64(0x123456789abcdef0UL)
  inspect(state.finish128(), content="0x45fc5b1b4cdf7de362a61151ebdcd391")
  inspect(
    hash128(({ hi: 0x0123456789abcdefUL, lo: 0xfedcba9876543210UL, }, 42)),
    content="0x73d29b72e573cb900b842b3c55892441",
  )
  // `Location::variant` hashes `(u128, usize)` like upstream.
  inspect(
    loc(5).variant(3).hash(),
    content="0x54041333c00c5e2a9aa1ac1500dcbdf7",
  )
}

///|
test "fingerprint distinctions" {
  // Unlike Typst equality, `0` and `0.0` differ.
  assert_true(hash128(Value::Int(0L)) != hash128(Value::Float(0.0)))
  assert_true(hash128(Value::Float(0.0)) != hash128(Value::Float(-0.0)))
  assert_true(hash128(Value::Str("a")) != hash128(Value::Label(Label("a"))))
  let arr = (items : Array[Value]) => Value::Array(Arr::from_array(items))
  assert_true(
    hash128(arr([Int(1L), Int(2L)])) != hash128(arr([Int(2L), Int(1L)])),
  )
  assert_eq(hash128(arr([Int(1L), Int(2L)])), hash128(arr([Int(1L), Int(2L)])))
  // Content hashes include the span, label, location and lifecycle.
  let base = MetadataElem::new(Int(1L)).pack()
  assert_eq(hash128(base), hash128(MetadataElem::new(Int(1L)).pack()))
  assert_true(hash128(base) != hash128(MetadataElem::new(Float(1.0)).pack()))
  assert_true(hash128(base) != hash128(base.spanned(@syntax.Span(1234UL))))
  assert_true(hash128(base) != hash128(base.located(loc(1))))
  assert_true(hash128(base.located(loc(1))) != hash128(base.located(loc(2))))
  assert_true(hash128(base) != hash128(base.labelled(Label("x"))))
  assert_true(hash128(base) != hash128(base.mark_prepared()))
  assert_eq(
    hash128(base.guarded(2).guarded(1)),
    hash128(base.guarded(1).guarded(2)),
  )
  // Styles.
  let styles = Styles::new()
  styles.set(heading_elem(), heading_elem_offset, Int(1L))
  let other = Styles::new()
  other.set(heading_elem(), heading_elem_offset, Int(2L))
  assert_true(hash128(Value::Styles(styles)) != hash128(Value::Styles(other)))
  // Tags.
  let start = Tag::Start(base.located(loc(1)), introspectable)
  assert_true(
    hash128(start) !=
    hash128(
      Tag::Start(base.located(loc(1)), { introspectable: false, tagged: true, }),
    ),
  )
  assert_true(
    hash128(Tag::End(loc(1), u128_zero, introspectable)) !=
    hash128(Tag::End(loc(1), U128::from_u64(1), introspectable)),
  )
}

///|
test "locator determinism and disambiguation" {
  let resolve = (l : Locator) => {
    match l.resolve() {
      Hash(h) => h
      Measure(_, _) => abort("unexpected measurement")
    }
  }
  let split = Locator::root().split()
  let a1 = resolve(split.next(@syntax.Span(7UL)))
  let a2 = resolve(split.next(@syntax.Span(7UL)))
  let b1 = resolve(split.next(@syntax.Span(8UL)))
  // Same keys are disambiguated, different keys differ.
  assert_true(a1 != a2)
  assert_true(a1 != b1)
  // Replaying the same sequence from a fresh root is deterministic.
  let again = Locator::root().split()
  assert_eq(resolve(again.next(@syntax.Span(7UL))), a1)
  assert_eq(resolve(again.next(@syntax.Span(7UL))), a2)
  // Disambiguators are per key: a new key starts at zero.
  let other = Locator::root().split()
  assert_eq(resolve(other.next(@syntax.Span(8UL))), b1)
  // The sublocal hash is `hash128((key, disambiguator, local))`.
  assert_eq(a1, hash128((hash128(@syntax.Span(7UL)), 0, u128_zero)))
  // Relayout keeps the hash; nested splits incorporate the parent.
  let parent = again.next(())
  assert_eq(resolve(parent.relayout()), resolve(parent))
  let child = resolve(parent.split().next(()))
  assert_true(child != resolve(parent))
  // Synthesized locators start from a location.
  assert_eq(resolve(Locator::synthesize(loc(42))), loc(42).hash())
  // Linked locators combine the local hash with the resolved outer one.
  let outer = Locator::root().split().next(1)
  let link = LocatorLink::new(outer)
  let linked = Locator::link(link).split().next(2)
  let local_hash = linked.local_hash
  assert_eq(resolve(linked), hash128((local_hash, resolve(outer))))
  // Locations from a split locator.
  let engine = wb_engine(Introspector::empty())
  let s1 = Locator::root().split()
  let s2 = Locator::root().split()
  let key = U128::from_u64(99)
  assert_eq(
    s1.next_location(engine, key, @syntax.Span::detached()),
    s2.next_location(engine, key, @syntax.Span::detached()),
  )
  assert_true(
    s1.next_location(engine, key, @syntax.Span::detached()) !=
    s1.next_location(engine, key, @syntax.Span::detached()),
  )
}

///|
test "locator measurement" {
  // Elements 1..3 all end with key 1000 (see `discover`).
  let intro = wb_introspector(sample())
  let engine = wb_engine(intro)
  let link = LocatorLink::measure(loc(4), @syntax.Span::detached())
  let split = Locator::link(link).split()
  // The closest element with the key after the base: element 4 itself.
  let found = split.next_location(
    engine,
    U128::from_u64(1000),
    @syntax.Span::detached(),
  )
  assert_eq(found, loc(4))
  // An unknown key falls back to the base location.
  let fallback = split.next_location(
    engine,
    U128::from_u64(1),
    @syntax.Span::detached(),
  )
  assert_eq(fallback, loc(4))
  // Both were recorded as introspections.
  assert_eq(engine.sink.introspections().length(), 2)
}

///|
test "element introspector queries" {
  let elems = sample()
  let metadata = metadata_elem().select()
  @debug.debug_inspect(
    values(elems.query(metadata)),
    content="[1, 2, 3, 4, 5, 6]",
  )
  @debug.debug_inspect(values(elems.query(Location(loc(5)))), content="[5]")
  @debug.debug_inspect(values(elems.query(Location(loc(77)))), content="[]")
  @debug.debug_inspect(values(elems.query(Label(Label("b")))), content="[5, 6]")
  @debug.debug_inspect(values(elems.query_labelled()), content="[4, 5, 6]")
  // `or` is ordered by document position and deduplicated.
  @debug.debug_inspect(
    values(
      elems.query(Or([Label(Label("b")), Location(loc(2)), Location(loc(5))])),
    ),
    content="[2, 5, 6]",
  )
  @debug.debug_inspect(
    values(elems.query(And([metadata, Label(Label("b"))]))),
    content="[5, 6]",
  )
  @debug.debug_inspect(
    values(
      elems.query(
        Before(selector=metadata, end=Location(loc(4)), inclusive=true),
      ),
    ),
    content="[1, 2, 3, 4]",
  )
  @debug.debug_inspect(
    values(
      elems.query(
        Before(selector=metadata, end=Location(loc(4)), inclusive=false),
      ),
    ),
    content="[1, 2, 3]",
  )
  @debug.debug_inspect(
    values(
      elems.query(
        After(selector=metadata, start=Location(loc(4)), inclusive=true),
      ),
    ),
    content="[4, 5, 6]",
  )
  @debug.debug_inspect(
    values(
      elems.query(
        After(selector=metadata, start=Location(loc(4)), inclusive=false),
      ),
    ),
    content="[5, 6]",
  )
  // Descendants via start/end tags.
  @debug.debug_inspect(
    values(elems.query(Within(selector=metadata, ancestor=Location(loc(1))))),
    content="[2, 3]",
  )
  @debug.debug_inspect(
    values(
      elems.query(
        Within(
          selector=metadata,
          ancestor=Or([Location(loc(1)), Location(loc(4))]),
        ),
      ),
    ),
    content="[2, 3, 5]",
  )
  @debug.debug_inspect(
    values(elems.query(Within(selector=metadata, ancestor=Location(loc(6))))),
    content="[]",
  )
  @debug.debug_inspect(
    values(opt_list(elems.query_first(metadata))),
    content="[1]",
  )
  @debug.debug_inspect(
    values(opt_list(elems.query_first(Label(Label("b"))))),
    content="[5]",
  )
  inspect(elems.query_count_before(metadata, loc(4)), content="4")
  inspect(elems.query_count_before(metadata, loc(77)), content="6")
  inspect(elems.label_count(Label("b")), content="2")
  inspect(elems.label_count(Label("c")), content="0")
  // Unique queries and their errors.
  @debug.debug_inspect(
    values([elems.query_unique(Label(Label("a")))]),
    content="[4]",
  )
  let err = (f : () -> Content raise HintedError) => {
    try f() catch {
      HintedError(e) => e.message
    } noraise {
      _ => "ok"
    }
  }
  inspect(
    err(() => elems.query_unique(metadata)),
    content="selector matches multiple elements",
  )
  inspect(
    err(() => elems.query_unique(Label(Label("b")))),
    content="label `<b>` occurs multiple times in the document",
  )
  inspect(
    err(() => elems.query_unique(Label(Label("c")))),
    content="label `<c>` does not exist in the document",
  )
  inspect(
    err(() => elems.query_unique(Location(loc(77)))),
    content="element does not exist in the document",
  )
  inspect(
    err(() => elems.query_unique(heading_elem().select())),
    content="selector does not match any element",
  )
  @debug.debug_inspect(elems.range_of(loc(1)), content="Some((0, 3))")
  @debug.debug_inspect(elems.range_of(loc(4)), content="Some((3, 5))")
  // The closest element with the key after the base.
  @debug.debug_inspect(
    elems.locator(U128::from_u64(1000), loc(3)).map(l => l == loc(3)),
    content="Some(true)",
  )
  @debug.debug_inspect(elems.locator(U128::from_u64(1), loc(3)), content="None")
}

///|
test "element introspector insertions and duplicates" {
  let builder = ElementIntrospectorBuilder::new()
  discover(builder, meta(1), [])
  // Elements discovered within an insertion are ordered after their parent.
  builder.start_insertion()
  discover(builder, meta(9), [])
  builder.end_insertion(loc(1))
  discover(builder, meta(2), [])
  // A duplicate start tag of the same location is ignored.
  builder.discover_tag(Start(meta(2), introspectable), ())
  // Non-introspectable tags are ignored.
  builder.discover_tag(
    Start(meta(3), { introspectable: false, tagged: true, }),
    (),
  )
  let elems = builder.finalize()
  @debug.debug_inspect(values(elems.all()), content="[1, 9, 2]")

  // Rebuilding from an existing introspector keeps the order and ranges.
  let rebuilt = ElementIntrospectorBuilder::new()
  rebuilt.discover_elements(sample(), _ => ())
  let rebuilt = rebuilt.finalize()
  @debug.debug_inspect(values(rebuilt.all()), content="[1, 2, 3, 4, 5, 6]")
  @debug.debug_inspect(rebuilt.range_of(loc(1)), content="Some((0, 3))")
  @debug.debug_inspect(rebuilt.range_of(loc(4)), content="Some((3, 5))")
  @debug.debug_inspect(
    values(
      rebuilt.query(
        Within(selector=metadata_elem().select(), ancestor=Location(loc(4))),
      ),
    ),
    content="[5]",
  )
}

///|
test "empty introspector" {
  let intro = Introspector::empty()
  inspect(intro.query(metadata_elem().select()).length(), content="0")
  let err = (f : () -> Content raise HintedError) => {
    try f() catch {
      HintedError(e) => e.message
    } noraise {
      _ => "ok"
    }
  }
  inspect(
    err(() => intro.query_unique(metadata_elem().select())),
    content="selector does not match any element",
  )
  inspect(
    err(() => intro.query_label(Label("x"))),
    content="label `<x>` does not exist in the document",
  )
}

///|
test "recorded reads validate against the next introspector" {
  let recorder = IntrospectionRecorder::new()
  let first = wb_introspector(sample()).track_with(recorder)
  let metadata = metadata_elem().select()
  ignore(first.query(metadata))
  ignore(first.query(metadata))
  ignore(first.query_count_before(metadata, loc(4)))
  ignore(first.query_label(Label("a")))
  ignore_error(() => first.query_label(Label("missing")))
  ignore(first.page(loc(1)))
  // Identical calls are recorded once.
  inspect(recorder.len(), content="5")
  // An identical document validates.
  assert_true(recorder.validate(wb_introspector(sample())))
  // A document with an extra element does not.
  let builder = ElementIntrospectorBuilder::new()
  discover(builder, meta(1), [meta(2), meta(3)])
  discover(builder, meta(4, label="a"), [meta(5, label="b")])
  discover(builder, meta(6, label="b"), [])
  discover(builder, meta(7), [])
  assert_false(recorder.validate(wb_introspector(builder.finalize())))
  // Error results are part of the recording.
  let errors = IntrospectionRecorder::new()
  ignore_error(() => {
    Introspector::empty().track_with(errors).query_label(Label("a"))
  })
  assert_true(errors.validate(Introspector::empty()))
  assert_false(errors.validate(wb_introspector(sample())))
  // Without a recorder, nothing is recorded.
  let untracked = IntrospectionRecorder::new()
  ignore(wb_introspector(sample()).query(metadata))
  inspect(untracked.len(), content="0")
}

///|
test "convergence analysis" {
  let world : WbWorld = { library: wb_library(), }
  let metadata = metadata_elem().select()
  let span = @syntax.Span::detached()
  let doc = (n : Int) => {
    let builder = ElementIntrospectorBuilder::new()
    for i in 1..<=n {
      discover(builder, meta(i), [])
    }
    wb_introspector(builder.finalize())
  }

  // Converged: the last two introspectors agree.
  let engine = wb_engine(doc(1))
  ignore(engine.introspect(query_introspection(metadata, span)))
  let converged = analyze(
    TrackedWorld::new(world),
    engine.library,
    [Introspector::empty(), doc(1), doc(2), doc(3), doc(3), doc(3)],
    engine.sink.introspections(),
  )
  inspect(converged.length(), content="0")

  // Not converged: the number of elements keeps changing.
  let diags = analyze(
    TrackedWorld::new(world),
    engine.library,
    [Introspector::empty(), doc(1), doc(2), doc(3), doc(4), doc(5)],
    engine.sink.introspections(),
  )
  @debug.debug_inspect(
    diags.map(d => [d.message] + d.hints.map(h => h.v)),
    content=(
      #|[
      #|  [
      #|    "document did not converge within five attempts",
      #|    "see 1 additional warning for more details",
      #|    "see https://typst.app/help/convergence for help",
      #|  ],
      #|  [
      #|    "number of metadata elements did not stabilize",
      #|    "the following numbers of elements were observed:\n- run 1: 0\n- run 2: 1\n- run 3: 2\n- run 4: 3\n- run 5: 4\n- final: 5",
      #|  ],
      #|]
    ),
  )

  // State values that change between `0` and `0.0` do not converge.
  let st = State::new("s", Int(0L))
  let engine = wb_engine(Introspector::empty())
  ignore(engine.introspect(state_final_introspection(st, span)))
  inspect(
    analyze(
      TrackedWorld::new(world),
      engine.library,
      [Introspector::empty(), doc(1), doc(1), doc(1), doc(1), doc(1)],
      engine.sink.introspections(),
    ).length(),
    content="0",
  )
  let history = History::from_entries([
    (Introspector::empty(), Value::Int(0L)),
    (Introspector::empty(), Value::Int(0L)),
    (Introspector::empty(), Value::Int(0L)),
    (Introspector::empty(), Value::Int(0L)),
    (Introspector::empty(), Value::Int(0L)),
    (Introspector::empty(), Value::Float(0.0)),
  ])
  assert_false(history.converged())
}

///|
test "native rule map" {
  let rules = NativeRuleMap::new()
  inspect(rules.len(), content="20")
  let content = MetadataElem::new(Int(1L)).pack()
  assert_true(rules.get(Html, content) is Some(_))
  assert_true(
    rules.get(Paged, HeadingElem::new(Content::empty()).pack()) is None,
  )
  let doc = DocumentElem::new(
    BundlePath::from_value(Str("a.html")),
    Content::empty(),
  )
  assert_true(rules.get(Bundle, doc.pack()) is None)
  assert_true(rules.get(Html, doc.pack()) is Some(_))
  rules.register(Html, (elem : HeadingElem, _, _) => elem.body())
  inspect(rules.len(), content="21")
  let heading = HeadingElem::new(TextElem::packed("hi")).pack()
  let rule = rules.get(Html, heading).unwrap()
  let engine = wb_engine(Introspector::empty())
  inspect(
    rule.apply(heading, engine, StyleChain::empty()).repr(),
    content=(
      #|[hi]
    ),
  )
  rules.replace(Html, (_ : HeadingElem, _, _) => Content::empty())
  inspect(rules.len(), content="21")
}

///|
test "panic duplicate native rule" {
  let rules = NativeRuleMap::new()
  rules.register(Html, (_ : MetadataElem, _, _) => Content::empty())
}

///|
test "panic replacing missing native rule" {
  let rules = NativeRuleMap::new()
  rules.replace(Html, (_ : HeadingElem, _, _) => Content::empty())
}

///|
test "tags and targets" {
  let c = meta(3)
  let tag = Tag::Start(c, introspectable)
  assert_eq(tag.location(), loc(3))
  let packed = TagElem::packed(tag)
  assert_true(packed.is_prepared())
  assert_true(TagElem::of(packed).unwrap().tag() == tag)
  inspect(
    Tag::End(loc(3), u128_zero, introspectable).to_string(),
    content="End(Location(3))",
  )
  // Targets in styles.
  let styles = StyleChain::empty()
  inspect(TargetElem::target_in(styles), content="Paged")
  let html = styles.chain(Styles::from_array([TargetElem::set_target(Html)]))
  inspect(TargetElem::target_in(html), content="Html")
}
