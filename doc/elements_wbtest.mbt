///|
/// A lowering context without layout, for tests.
fn test_lower() -> Lower {
  let world = DocWorld::in_memory()
  let session = Session::new(world)
  let session_world : SessionWorld = { session, }
  let engine : @library.Engine = {
    world: session_world,
    library: world.library,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  {
    session,
    engine,
    context: @library.Context::none(),
    keys: [],
    pieces: Option::None,
  }
}

///|
test "every generated constructor stores the element of its Typst path" {
  // The specification of `scripts/docgen.py` pairs each EDSL type with a
  // qualified Typst path and an element handle. Resolve the path like
  // `Call` does and check that it denotes that element: element names are
  // not unique (`table.cell`, `grid.cell`), handles are.
  let lower = test_lower()
  let seen : Array[@library.Element] = []
  for entry in generated_elements() {
    let (name, path, elem) = entry
    let value = lower.global(path, @syntax.Span::detached())
    let func : @library.Func = value.cast()
    guard func.to_element() is Some(found) else {
      fail("\{name}: `\{path}` is not an element function")
    }
    if found != elem {
      fail("\{name}: `\{path}` is another element than the constructor's")
    }
    if seen.contains(elem) {
      fail("\{name}: the element of `\{path}` has two constructors")
    }
    seen.push(elem)
  }
  assert_true(seen.length() >= 60)
}

///|
/// A call site, for tests.
#callsite(autofill(loc, args_loc))
fn test_site(kind : String, loc~ : SourceLoc, args_loc~ : ArgsLoc) -> Site {
  Site::new(kind, loc, args_loc)
}

///|
test "the origin registry is append-only and deduplicates by call site and keys" {
  let registry = Registry::new()
  let a = test_site("A")
  let first = registry.entry(a, [])
  let span = registry.span(first)
  let line_count = () => {
    registry.listing.to_string().split("\n").filter(l => !l.is_empty()).count()
  }
  assert_eq(line_count(), 1)
  // The same site again: the same entry and span, no new line.
  assert_eq(registry.entry(a, []), first)
  assert_eq(line_count(), 1)
  // The same site under a key: another origin, appended; the first span
  // is unchanged.
  let keyed = registry.entry(a, ["row-1"])
  assert_true(keyed != first)
  assert_eq(registry.entry(a, ["row-1"]), keyed)
  assert_eq(line_count(), 2)
  assert_true(registry.span(first) == span)
  // Spans are ranges of the listing; an argument's span lies inside its
  // entry's line.
  let frozen = registry.freeze()
  guard frozen.resolve(span) is Some(origin) else { fail("no origin") }
  inspect(origin.kind, content="A")
  inspect(origin.keys.join("/"), content="")
  guard frozen.resolve(registry.span(keyed)) is Some(origin) else {
    fail("no origin")
  }
  inspect(origin.keys.join("/"), content="row-1")
  // Key paths are distinguished structurally, whatever the keys contain.
  let nested = registry.entry(a, ["x", "y"])
  for joined in ["x\u{1}y", "x\u{0}1:y", "x/y", "xy"] {
    let single = registry.entry(a, [joined])
    assert_true(single != nested)
    guard frozen_keys(registry, single) is [key] else { fail("one key") }
    assert_eq(key, joined)
  }
  assert_eq(frozen_keys(registry, nested).length(), 2)
}

///|
/// The keys of an entry as a report resolves them.
fn frozen_keys(registry : Registry, entry : Int) -> Array[String] raise {
  guard registry.freeze().resolve(registry.span(entry)) is Some(origin) else {
    fail("no origin")
  }
  origin.keys
}
