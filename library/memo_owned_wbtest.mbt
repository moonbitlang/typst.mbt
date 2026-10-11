// What a store keeps and what it hands out are different objects wherever
// the type can be written to (`docs/incremental-design.md`, section 5.4,
// "Mutable results"). Each test here does what a caller, or a host, can do
// to what it was given, and asks the store again.

///|
/// What a host can do to the sink of an engine it made: a hint and a
/// tracepoint for every diagnostic, the styles of every traced value
/// emptied.
fn owned_test_scribble(sink : Sink) -> Unit {
  let span = @syntax.Span::detached()
  for diagnostic in [..sink.warnings, ..sink.delayed] {
    diagnostic.hint("a hint of the host's")
    diagnostic.trace.push({ v: Tracepoint::Call(Some("host")), span, })
  }
  for value in sink.values {
    if value.1 is Some(styles) {
      styles.unset()
    }
  }
}

///|
/// What the sink of a call of [owned_test_effects] holds.
fn owned_test_sink(sink : Sink) -> String {
  let out = []
  for diagnostic in [..sink.warnings, ..sink.delayed] {
    out.push(
      "\{diagnostic.message}: \{diagnostic.hints.length()} hints, \{diagnostic.trace.length()} tracepoints",
    )
  }
  for value in sink.values {
    let styles = match value.1 {
      Some(styles) => styles.iter().count()
      None => -1
    }
    let shared = value.0 is Array(array) && array.shared
    out.push("a value with \{styles} styles, shared: \{shared}")
  }
  out.join("; ")
}

///|
/// A warning, a delayed error and a traced array with its styles.
fn owned_test_effects(engine : Engine) -> Unit {
  let span = @syntax.DiagSpan::detached()
  engine.sink.warn(SourceDiagnostic::warning(span, "careful"))
  engine.sink.delayed_error(SourceDiagnostic::error(span, "later"))
  let styles = Styles::from_array([
    TextElem::set_size(TextSize(Length::from_abs(Abs::pt(8.0)))),
  ])
  engine.sink.value(Array(Arr::from_array([Int(1)])), Some(styles))
}

///|
let owned_test_expected : String = "careful: 0 hints, 0 tracepoints; later: 0 hints, 0 tracepoints; a value with 1 styles, shared: true"

///|
/// Mutation check 18 of the design, for the sinks: with the kept sink
/// replayed as it is, every caller after the first sees what the first did
/// to its diagnostics.
test "owned: the sink of a kept closure call is not shared with the sinks it is replayed into" {
  memo_test_begin()
  defer memo_test_end()
  let mut runs = 0
  let body : ClosureBody = (_, _, engine, _, _) => {
    runs += 1
    owned_test_effects(engine)
    None
  }
  let f = memo_test_func(1)
  for _ in 0..<3 {
    let engine = memo_engine()
    memo_call(f, engine, Context::none(), [], body) |> ignore
    // The first caller's sink has the call's own objects, the later ones
    // copies of what the entry keeps: all as the call made them.
    inspect(
      owned_test_sink(engine.sink).replace(
        old="shared: false",
        new="shared: true",
      ),
      content=owned_test_expected,
    )
    owned_test_scribble(engine.sink)
  }
  assert_eq(runs, 1)
  // What a replay hands out is marked as shared (the entry has it too).
  let engine = memo_engine()
  memo_call(f, engine, Context::none(), [], body) |> ignore
  inspect(owned_test_sink(engine.sink), content=owned_test_expected)
}

///|
test "owned: the sink of a kept layout is not shared with the sinks it is replayed into" {
  memo_test_begin()
  defer memo_test_end()
  let content = TextElem::packed("x")
  let styles = StyleChain::empty()
  let key = memo_fingerprint(state => state.write_str("owned layout"))
  let mut runs = 0
  for _ in 0..<3 {
    let engine = memo_engine()
    memoized_layout(engine, key, content, styles, None, engine => {
      runs += 1
      owned_test_effects(engine)
      Fragment([Frame::soft(Axes::new(Abs::pt(1.0), Abs::pt(1.0)))])
    })
    |> ignore
    inspect(
      owned_test_sink(engine.sink).replace(
        old="shared: false",
        new="shared: true",
      ),
      content=owned_test_expected,
    )
    owned_test_scribble(engine.sink)
  }
  assert_eq(runs, 1)
}

///|
test "owned: a call without effects keeps no sink" {
  memo_test_begin()
  defer memo_test_end()
  let content = TextElem::packed("x")
  let key = memo_fingerprint(state => state.write_str("owned plain"))
  let engine = memo_engine()
  memoized_layout(engine, key, content, StyleChain::empty(), None, _ => {
    Fragment([Frame::soft(Axes::new(Abs::pt(1.0), Abs::pt(1.0)))])
  })
  |> ignore
  let mut entries = 0
  for _, list in layout_store.entries {
    for entry in list {
      entries += 1
      assert_true(entry.sink is None)
    }
  }
  assert_eq(entries, 1)
}

///|
/// A value of the type `arguments` is an object that reading consumes
/// (`Args::eat`, `named`, `finish`: the way native code takes arguments),
/// and it has no mark that makes a writer copy it. A store keeps a copy
/// and hands out copies ([kept_value]).
test "owned: arguments that a kept call returned or traced are copies" {
  memo_test_begin()
  defer memo_test_end()
  let mut runs = 0
  // `all(..args) = args`, tracing what it returns.
  let body : ClosureBody = (func, _, engine, _, args) => {
    runs += 1
    let rest = Args::new(func.span, args.all())
    args.finish()
    engine.sink.value(Args(rest.copy()), None)
    Args(rest)
  }
  let f = memo_test_func(1)
  for _ in 0..<3 {
    let engine = memo_engine()
    let result = memo_call(f, engine, Context::none(), [Int(1), Str("a")], body)
    guard result is Args(returned) else { fail("not arguments") }
    assert_eq(returned.items.length(), 2)
    guard engine.sink.values is [(Args(traced), _)] else {
      fail("no traced arguments")
    }
    assert_eq(traced.items.length(), 2)
    // What a native function does with arguments it is given.
    returned.eat_spanned() |> ignore
    traced.eat_spanned() |> ignore
    assert_eq(returned.items.length(), 1)
  }
  assert_eq(runs, 1)
}

///|
test "owned: the entries of a rendered bibliography are the caller's" {
  let listed = Location::new(hash128("bibliography"))
  let entry : RenderedEntry = {
    prefix: None,
    body: TextElem::packed("An entry"),
    backlink: Location::new(hash128("entry")),
  }
  let works : Works = {
    bibliographies: Map([
      (listed, Ok({ entries: [entry], hanging_indent: true, })),
    ]),
    groups: Map([]),
  }
  let span = @syntax.Span::detached()
  for _ in 0..<3 {
    let rendered = works.bibliography(listed, span)
    assert_eq(rendered.entries.length(), 1)
    assert_true(rendered.hanging_indent)
    // What a show rule of a host can do with what it got.
    rendered.entries.clear()
  }
}

///|
test "owned: an error that a plugin cache keeps is raised as a copy" {
  plugin_call_cache.clear()
  plugin_module_cache.clear()
  let hints = (f : () -> Unit raise HintedError) => {
    try f() catch {
      HintedError(error) => {
        let seen = error.hints.length()
        // What a caller can do with an error it caught.
        error.hint("a hint of the caller's")
        "\{error.message}: \{seen} hints"
      }
    } noraise {
      _ => "no error"
    }
  }
  // A module that does not load.
  let broken = Bytes::from_array([b'\x00', b'\x61', b'\x73', b'\x6d'])
  let mut first = ""
  for i in 0..<3 {
    let said = hints(() => Plugin::module_(broken) |> ignore)
    assert_true(said.has_suffix(": 0 hints"))
    if i == 0 {
      first = said
    }
    assert_eq(said, first)
  }
  // A call that fails: a function that takes no argument, given one.
  let module_ = plugin_test_load(plugin_test_unhex(grow_plugin_hex))
  guard module_.scope().get("grow") is Some(binding) &&
    binding.value is Func(func) &&
    func.to_plugin() is Some(grow) else {
    fail("no plugin function")
  }
  for _ in 0..<3 {
    inspect(
      hints(() => grow.call([b"x"]) |> ignore),
      content="plugin function takes 0 arguments, but 1 was given: 0 hints",
    )
    inspect(
      hints(() => grow.transition([b"x"]) |> ignore),
      content="plugin function takes 0 arguments, but 1 was given: 0 hints",
    )
  }
}

///|
test "owned: an entry knows its introspector by a number, not by the object" {
  let backend = FixedBackend([TextElem::packed("x")])
  let one = Introspector::new(backend)
  // Recording and not recording are the same introspector.
  let recorder = IntrospectionRecorder::new()
  assert_eq(one.track_with(recorder).serial(), one.serial())
  assert_eq(one.track_with(recorder).untracked().serial(), one.serial())
  // Every introspector that is made is another one, also of one backend.
  let other = Introspector::new(backend)
  assert_false(one.serial() == other.serial())
  // The empty ones answer the same and are one.
  assert_eq(Introspector::empty().serial(), 0)
  assert_false(one.serial() == 0)
  // A call whose read returned a host closure is only found for the
  // introspector it was computed with (its reads prove nothing on
  // another): by the number.
  memo_test_begin()
  defer memo_test_end()
  let host = HostFunc::new(hash128("h"), (_, _, _) => None)
  let elem = TextElem::packed("x").elem()
  let holder = Content::from_fields(elem, [Some(Func(Func::host(host)))])
  let hosted = Introspector::new(FixedBackend([holder]))
  let again = Introspector::new(FixedBackend([holder]))
  let mut runs = 0
  let body : ClosureBody = (_, _, engine, _, _) => {
    runs += 1
    Int(engine.introspector.query_labelled().length().to_int64())
  }
  let f = memo_test_func(1)
  let call = (introspector : Introspector) => {
    let engine = memo_engine(
      introspector=introspector.track_with(IntrospectionRecorder::new()),
    )
    memo_call(f, engine, Context::none(), [], body) |> ignore
  }
  call(hosted)
  call(hosted)
  assert_eq(runs, 1)
  call(again)
  assert_eq(runs, 2)
  // The entry holds no introspector: only numbers.
  let mut entries = 0
  for _, list in closure_store.entries {
    for entry in list {
      entries += 1
      assert_true(
        entry.introspector == hosted.serial() ||
        entry.introspector == again.serial(),
      )
    }
  }
  assert_eq(entries, 2)
}

///|
test "owned: a query hands out a view of what the introspector keeps" {
  let elems = sample()
  let selector : Selector = Label(Label("b"))
  let first = elems.query(selector)
  @debug.debug_inspect(values(first), content="[5, 6]")
  // A caller cannot write to what it got. What it can do is copy, and the
  // copy is its own.
  let copy = first.to_owned()
  copy.clear()
  @debug.debug_inspect(values(elems.query(selector)), content="[5, 6]")
  // A selector that is answered with another query's result hands out the
  // same elements: there is no end to cut them at.
  let before = elems.query(
    Before(selector~, end=Selector::Location(loc(77)), inclusive=true),
  )
  @debug.debug_inspect(values(before), content="[5, 6]")
  @debug.debug_inspect(values(elems.query(selector)), content="[5, 6]")
}
