// Memoized closure calls (`memoized_closure`): what a result depends on.
// The bodies here are host functions standing in for `eval_closure_impl`,
// so that each test controls exactly what the "closure" asks of its tracked
// arguments (context, route, introspector, sink).

///|
/// The body of a test call.
type ClosureBody = (Func, Closure, Engine, Context, Args) -> Value raise SourceError

///|
/// A closure whose hash depends on `tag`.
fn memo_test_func(tag : Int) -> Func {
  guard test_closure(@syntax.parse_code("x"), Int(tag.to_int64())) is Func(func) else {
    abort("not a function")
  }
  func
}

///|
/// Call `func` through the memoization.
fn memo_call(
  func : Func,
  engine : Engine,
  context : Context,
  values : Array[Value],
  body : ClosureBody,
) -> Value raise SourceError {
  guard func.inner is Closure(closure) else { abort("not a closure") }
  let args = Args::new(func.span, values)
  memoized_closure(func, closure, engine, context, args, body)
}

///|
/// A route that is `depth` deep.
fn memo_route(depth : Int) -> Route {
  let mut route = Route::root()
  for _ in 0..<depth {
    route = Route::extend_(route)
  }
  route
}

///|
fn memo_file(path : String) -> @syntax.FileId {
  @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new(path) catch {
      _ => abort("invalid path")
    },
  ).intern()
}

///|
/// The world of the engines of a test: one, since results are only kept
/// for a world that is in a scope.
let memo_test_world : Ref[TrackedWorld?] = { val: None, }

///|
/// Start a compilation's memoization for the rest of a test: its stores
/// and the scope of the world of [memo_engine].
fn memo_test_begin() -> Unit {
  memo_counter.val += 1
  memo_generation.val = memo_counter.val
  let world = wb_engine(Introspector::empty()).world
  world.open()
  memo_test_world.val = Some(world)
}

///|
fn memo_test_end() -> Unit {
  memo_generation.val = 0
  if memo_test_world.val is Some(world) {
    world.close()
    memo_test_world.val = None
  }
}

///|
fn memo_engine(
  introspector? : Introspector = Introspector::new(FixedBackend([])),
) -> Engine {
  let engine = wb_engine(introspector)
  match memo_test_world.val {
    Some(world) => { ..engine, world, }
    None => engine
  }
}

///|
test "closure memo: equal functions and arguments are one call" {
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let context = Context::none()
  let mut runs = 0
  let body : ClosureBody = (_, _, _, _, args) => {
    runs += 1
    // The call consumes its arguments.
    let values : Array[Value] = args.all()
    args.finish()
    Array(Arr::from_array(values))
  }
  let f = memo_test_func(1)
  let first = memo_call(f, engine, context, [Int(1), Str("a")], body)
  let again = memo_call(f, engine, context, [Int(1), Str("a")], body)
  assert_eq(runs, 1)
  assert_true(first == again)
  // Results are values: the containers are shared.
  guard first is Array(arr) else { fail("not an array") }
  assert_true(arr.shared)
  // Arguments are compared by their bits and types, not by `==`.
  for
    values in [
      [Value::Int(1), Str("b")],
      [Float(1.0), Str("a")],
      [Int(1)],
      [Int(1), Str("a"), None],
    ] {
    let before = runs
    memo_call(f, engine, context, values, body) |> ignore
    assert_eq(runs, before + 1)
    memo_call(f, engine, context, values, body) |> ignore
    assert_eq(runs, before + 1)
  }
  let before = runs
  for value in [Value::Float(0.0), Float(-0.0), Int(0)] {
    memo_call(f, engine, context, [value], body) |> ignore
  }
  assert_eq(runs, before + 3)
  // Another closure, and the same closure with another span.
  let before = runs
  memo_call(memo_test_func(2), engine, context, [Int(1), Str("a")], body)
  |> ignore
  assert_eq(runs, before + 1)
  let spanned = f.spanned(@syntax.Span::from_range(memo_file("s.typ"), 1, 2))
  memo_call(spanned, engine, context, [Int(1), Str("a")], body) |> ignore
  assert_eq(runs, before + 2)
  // An equal closure that is another object is the same function.
  memo_call(memo_test_func(2), engine, context, [Int(1), Str("a")], body)
  |> ignore
  assert_eq(runs, before + 2)
  // The arguments of a call that is in the cache are consumed like those of
  // a call that runs: a caller that passed its own arguments on finishes
  // them afterwards.
  let args = Args::new(f.span, [Int(1), Str("a")])
  guard f.inner is Closure(closure) else { fail("not a closure") }
  memoized_closure(f, closure, engine, context, args, body) |> ignore
  assert_eq(runs, before + 2)
  assert_eq(args.items.length(), 0)
  args.finish()
  // And the cached call still has them.
  let args = Args::new(f.span, [Int(1), Str("a")])
  let again = memoized_closure(f, closure, engine, context, args, body)
  assert_true(again == first)
  assert_eq(runs, before + 2)
}

///|
test "closure memo: a result depends on the traced span" {
  memo_test_begin()
  defer memo_test_end()
  let span = @syntax.Span::from_range(memo_file("t.typ"), 1, 2)
  let other = @syntax.Span::from_range(memo_file("t.typ"), 3, 4)
  let mut runs = 0
  // Traces its value if anything is traced, like a `Vm` whose span is
  // inspected.
  let body : ClosureBody = (_, _, engine, _, _) => {
    runs += 1
    if engine.traced.0 is Some(_) {
      engine.sink.value(Int(7), None)
    }
    Int(7)
  }
  let f = memo_test_func(1)
  let values = (traced : Traced) => {
    let engine = { ..memo_engine(), traced, }
    memo_call(f, engine, Context::none(), [], body) |> ignore
    engine.sink.values().length()
  }
  // An evaluated string runs without tracing; the document's own call
  // then still traces, and the other way round.
  assert_eq(values(Traced::new()), 0)
  assert_eq(values(Traced::new(traced=span)), 1)
  assert_eq(values(Traced::new()), 0)
  assert_eq(values(Traced::new(traced=span)), 1)
  assert_eq(runs, 2)
  assert_eq(values(Traced::new(traced=other)), 1)
  assert_eq(runs, 3)
}

///|
test "closure memo: off outside of a compilation and when disabled" {
  let engine = memo_engine()
  let mut runs = 0
  let body : ClosureBody = (_, _, _, _, _) => {
    runs += 1
    None
  }
  let f = memo_test_func(1)
  memo_call(f, engine, Context::none(), [], body) |> ignore
  memo_call(f, engine, Context::none(), [], body) |> ignore
  assert_eq(runs, 2)
  set_layout_memo_enabled(false)
  {
    defer set_layout_memo_enabled(true)
    engine.world.scoped(() => {
      with_layout_memo(() => {
        memo_call(f, engine, Context::none(), [], body) |> ignore
        memo_call(f, engine, Context::none(), [], body) |> ignore
      })
    })
  }
  assert_eq(runs, 4)
  // Not for a world that is in no scope.
  with_layout_memo(() => {
    memo_call(f, engine, Context::none(), [], body) |> ignore
    memo_call(f, engine, Context::none(), [], body) |> ignore
  })
  assert_eq(runs, 6)
  // Each compilation has its own results.
  engine.world.scoped(() => {
    with_layout_memo(() => {
      memo_call(f, engine, Context::none(), [], body) |> ignore
      memo_call(f, engine, Context::none(), [], body) |> ignore
    })
  })
  assert_eq(runs, 7)
  engine.world.scoped(() => {
    with_layout_memo(() => memo_call(f, engine, Context::none(), [], body))
  })
  |> ignore
  assert_eq(runs, 8)
}

///|
test "closure memo: errors are not kept" {
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let mut runs = 0
  let body : ClosureBody = (_, _, _, _, _) => {
    runs += 1
    if runs == 1 {
      bail_at(@syntax.Span::detached(), "first")
    }
    Int(7)
  }
  let f = memo_test_func(1)
  let failed = try memo_call(f, engine, Context::none(), [], body) catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(failed)
  assert_true(memo_call(f, engine, Context::none(), [], body) == Int(7))
  assert_true(memo_call(f, engine, Context::none(), [], body) == Int(7))
  assert_eq(runs, 2)
}

///|
test "closure memo: a result depends on what the call asked of its context" {
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let l1 = Location::new(hash128("one"))
  let l2 = Location::new(hash128("two"))
  let s1 = StyleChain::empty().chain(
    Styles::from_array([TextElem::set_fallback(false)]),
  )
  let s2 = StyleChain::empty().chain(
    Styles::from_array([TextElem::set_fallback(true)]),
  )
  // The same styles as `s1`, as another chain.
  let s1b = StyleChain::empty().chain(
    Styles::from_array([TextElem::set_fallback(false)]),
  )
  let contexts = [
    Context::none(),
    Context::new(location=l1, styles=s1),
    Context::new(location=l2, styles=s1),
    Context::new(location=l1, styles=s2),
    Context::new(location=l1, styles=s1b),
    Context::new(styles=s1),
    Context::new(location=l1),
  ]
  let mut runs = 0
  // The number of calls that are computed when `body` is called in every
  // context twice.
  let computed = (tag : Int, body : ClosureBody) => {
    let f = memo_test_func(tag)
    let before = runs
    for _ in 0..<2 {
      for context in contexts {
        memo_call(f, engine, context, [], body) |> ignore
      }
    }
    runs - before
  }
  // Nothing asked: one call.
  assert_eq(
    computed(1, (_, _, _, _, _) => {
      runs += 1
      None
    }),
    1,
  )
  // The location: none, `l1` and `l2`.
  assert_eq(
    computed(2, (_, _, _, context, _) => {
      runs += 1
      match context.try_location() {
        Some(location) => Dyn(Location(location))
        None => None
      }
    }),
    3,
  )
  // The styles: none, `s1` (also as `s1b`) and `s2`.
  assert_eq(
    computed(3, (_, _, _, context, _) => {
      runs += 1
      Bool(context.try_styles() is Some(_))
    }),
    3,
  )
  // Both: every context but the copy of the second one.
  assert_eq(
    computed(4, (_, _, _, context, _) => {
      runs += 1
      context.try_location() |> ignore
      context.try_styles() |> ignore
      None
    }),
    6,
  )
  // `introspect` only depends on whether there is any context.
  assert_eq(
    computed(5, (_, _, _, context, _) => {
      runs += 1
      Bool(
        try context.introspect() catch {
          _ => false
        } noraise {
          _ => true
        },
      )
    }),
    2,
  )
  // The raising accessors are tracked like the others.
  assert_eq(
    computed(6, (_, _, _, context, _) => {
      runs += 1
      try context.location() catch {
        _ => None
      } noraise {
        location => Dyn(Location(location))
      }
    }),
    3,
  )
  // What a call inside the call asks, the call asks: computed, and
  // reused.
  let inner = memo_test_func(70)
  let inner_body : ClosureBody = (_, _, _, context, _) => {
    match context.try_location() {
      Some(location) => Dyn(Location(location))
      None => None
    }
  }
  assert_eq(
    computed(7, (_, _, engine, context, _) => {
      runs += 1
      memo_call(inner, engine, context, [], inner_body)
    }),
    3,
  )
  assert_eq(
    computed(8, (_, _, engine, context, _) => {
      runs += 1
      // In the cache for every context by now.
      memo_call(inner, engine, context, [], inner_body)
    }),
    3,
  )
  // A call with a context of its own asks nothing of the caller's.
  assert_eq(
    computed(9, (_, _, engine, _, _) => {
      runs += 1
      memo_call(inner, engine, Context::new(location=l2), [], inner_body)
    }),
    1,
  )
}

///|
test "closure memo: what is asked of the context can grow" {
  memo_test_begin()
  defer memo_test_end()
  let l1 = Location::new(hash128("one"))
  let l2 = Location::new(hash128("two"))
  let c1 = Context::new(location=l1)
  let c2 = Context::new(location=l2)
  let elem = TextElem::packed("x")
  let empty = memo_engine()
  let full = memo_engine(introspector=Introspector::new(FixedBackend([elem])))
  let mut runs = 0
  // Asks for the location only if the document has labelled elements.
  let body : ClosureBody = (_, _, engine, context, _) => {
    runs += 1
    if engine.introspector.query_labelled().is_empty() {
      None
    } else {
      match context.try_location() {
        Some(location) => Dyn(Location(location))
        None => None
      }
    }
  }
  let f = memo_test_func(1)
  assert_true(memo_call(f, empty, c1, [], body) is None)
  assert_true(memo_call(f, empty, c2, [], body) is None)
  assert_eq(runs, 1)
  // The read of the introspector gives another result: computed, and now
  // the location matters.
  assert_true(memo_call(f, full, c1, [], body) == Dyn(Location(l1)))
  assert_true(memo_call(f, full, c2, [], body) == Dyn(Location(l2)))
  assert_true(memo_call(f, full, c1, [], body) == Dyn(Location(l1)))
  assert_eq(runs, 3)
  // Back on the empty document the result is computed per location.
  assert_true(memo_call(f, empty, c1, [], body) is None)
  assert_true(memo_call(f, empty, c2, [], body) is None)
  assert_true(memo_call(f, empty, c1, [], body) is None)
  assert_eq(runs, 5)
}

///|
test "closure memo: a result depends on the answers of the depth checks" {
  memo_test_begin()
  defer memo_test_end()
  let mut runs = 0
  // Enters `levels` nested calls and checks the call depth in the last.
  let nest = (engine : Engine, levels : Int) => {
    let mut route = engine.route
    for _ in 0..<levels {
      route = Route::extend_(route)
    }
    try route.check_call_depth() catch {
      _ => false
    } noraise {
      _ => true
    }
  }
  let body : ClosureBody = (_, _, engine, _, args) => {
    runs += 1
    let levels : Int64 = args.expect("levels")
    Bool(nest(engine, levels.to_int()))
  }
  let at = (depth : Int) => { ..memo_engine(), route: memo_route(depth), }
  let call = (f : Func, depth : Int, levels : Int) => {
    memo_call(f, at(depth), Context::none(), [Int(levels.to_int64())], body)
  }
  let f = memo_test_func(1)
  // Ten levels: within the limit up to a depth of 70.
  assert_true(call(f, 0, 10) == Bool(true))
  assert_eq(runs, 1)
  for depth in [1, 5, 40, 69, 70] {
    assert_true(call(f, depth, 10) == Bool(true))
  }
  assert_eq(runs, 1)
  assert_true(call(f, 71, 10) == Bool(false))
  assert_eq(runs, 2)
  // The failed check holds for every deeper route, not for a shallower
  // one.
  for depth in [72, 75, 200] {
    assert_true(call(f, depth, 10) == Bool(false))
  }
  assert_eq(runs, 2)
  assert_true(call(f, 70, 10) == Bool(true))
  assert_true(call(f, 3, 10) == Bool(true))
  assert_eq(runs, 2)
  // Computed deep first: the answer is that of the shallower routes too,
  // up to the first one that fails.
  let g = memo_test_func(2)
  assert_true(call(g, 60, 10) == Bool(true))
  assert_true(call(g, 0, 10) == Bool(true))
  assert_true(call(g, 70, 10) == Bool(true))
  assert_eq(runs, 3)
  assert_true(call(g, 71, 10) == Bool(false))
  assert_eq(runs, 4)
  // Computed where the check fails first: that is not the answer of a
  // route where it succeeds.
  let k = memo_test_func(7)
  let before = runs
  assert_true(call(k, 75, 10) == Bool(false))
  assert_true(call(k, 90, 10) == Bool(false))
  assert_true(call(k, 71, 10) == Bool(false))
  assert_eq(runs, before + 1)
  assert_true(call(k, 70, 10) == Bool(true))
  assert_true(call(k, 3, 10) == Bool(true))
  assert_eq(runs, before + 2)
  // The checks of the calls inside a call are the call's: computed and
  // reused.
  let inner = memo_test_func(3)
  let outer_body : ClosureBody = (_, _, engine, context, _) => {
    runs += 1
    let engine = { ..engine, route: Route::extend_(engine.route), }
    memo_call(inner, engine, context, [Int(10)], body)
  }
  let outer = (tag : Int, depth : Int) => {
    memo_call(memo_test_func(tag), at(depth), Context::none(), [], outer_body)
  }
  // The inner call is computed at depth 1.
  let before = runs
  assert_true(outer(4, 0) == Bool(true))
  assert_eq(runs, before + 2)
  assert_true(outer(4, 69) == Bool(true))
  assert_eq(runs, before + 2)
  // 70 + 1 + 10 is one too many: the outer and the inner call run.
  assert_true(outer(4, 70) == Bool(false))
  assert_eq(runs, before + 4)
  // Another outer function finds the inner calls in the cache and is
  // still only valid where they are.
  let before = runs
  assert_true(outer(5, 30) == Bool(true))
  assert_eq(runs, before + 1)
  assert_true(outer(5, 69) == Bool(true))
  assert_eq(runs, before + 1)
  assert_true(outer(5, 70) == Bool(false))
  assert_eq(runs, before + 2)
  assert_true(outer(5, 90) == Bool(false))
  assert_true(outer(5, 0) == Bool(true))
  assert_eq(runs, before + 2)
  // A result that is only that of one depth (a reused layout).
  let pinned : ClosureBody = (_, _, _, _, _) => {
    runs += 1
    note_route_shift(0, 0)
    None
  }
  let h = memo_test_func(6)
  let before = runs
  for depth in [3, 3, 4, 4, 3, 2] {
    memo_call(h, at(depth), Context::none(), [], pinned) |> ignore
  }
  assert_eq(runs, before + 3)
}

///|
test "closure memo: a result depends on the answers of the route for files" {
  memo_test_begin()
  defer memo_test_end()
  let a = memo_file("a.typ")
  let b = memo_file("b.typ")
  let c = memo_file("c.typ")
  let mut runs = 0
  // Asks the route for `a`, like an import does.
  let body : ClosureBody = (_, _, engine, _, _) => {
    runs += 1
    note_route_query(a)
    Bool(engine.route.contains(a))
  }
  let on = (ids : Array[@syntax.FileId]) => {
    let mut route = Route::root()
    for id in ids {
      route = Route::extend_(route).with_id(id)
    }
    { ..memo_engine(), route: route.unnested(), }
  }
  let call = (f : Func, ids : Array[@syntax.FileId], body : ClosureBody) => {
    memo_call(f, on(ids), Context::none(), [], body)
  }
  let f = memo_test_func(1)
  assert_true(call(f, [], body) == Bool(false))
  assert_true(call(f, [b], body) == Bool(false))
  assert_true(call(f, [b, c], body) == Bool(false))
  assert_eq(runs, 1)
  assert_true(call(f, [a], body) == Bool(true))
  assert_true(call(f, [b, a, c], body) == Bool(true))
  assert_eq(runs, 2)
  assert_true(call(f, [c], body) == Bool(false))
  assert_eq(runs, 2)
  // The queries of the calls inside a call are the call's: computed and
  // reused.
  let outer_body : ClosureBody = (_, _, engine, context, _) => {
    runs += 1
    memo_call(f, engine, context, [], body)
  }
  for tag in [2, 3] {
    let g = memo_test_func(tag)
    let before = runs
    assert_true(call(g, [b], outer_body) == Bool(false))
    assert_true(call(g, [c], outer_body) == Bool(false))
    assert_eq(runs, before + 1)
    assert_true(call(g, [c, a], outer_body) == Bool(true))
    assert_true(call(g, [a], outer_body) == Bool(true))
    assert_eq(runs, before + 2)
  }
  // No collection is left open.
  assert_eq(route_query_scopes.val, 0)
  assert_eq(route_query_log.length(), 0)
  assert_eq(route_shift_scopes.val, 0)
}

///|
test "closure memo: sink effects and introspector reads are the caller's" {
  memo_test_begin()
  defer memo_test_end()
  let elem = TextElem::packed("x")
  let warning = SourceDiagnostic::warning(
    @syntax.DiagSpan::detached(),
    "careful",
  )
  let mut runs = 0
  let body : ClosureBody = (_, _, engine, _, _) => {
    runs += 1
    engine.sink.warn(warning)
    Int(engine.introspector.query_labelled().length().to_int64())
  }
  let f = memo_test_func(1)
  let run = (backend : FixedBackend) => {
    let recorder = IntrospectionRecorder::new()
    let engine = memo_engine(
      introspector=Introspector::new(backend).track_with(recorder),
    )
    let value = memo_call(f, engine, Context::none(), [], body)
    (value, engine.sink.warnings().length(), recorder.len())
  }
  let one = FixedBackend([elem])
  let (value, warnings, reads) = run(one)
  assert_true(value == Int(1))
  assert_eq((warnings, reads), (1, 1))
  // Reused: on the same introspector, and on one with the same answers.
  for backend in [one, FixedBackend([elem])] {
    let (value, warnings, reads) = run(backend)
    assert_true(value == Int(1))
    assert_eq((warnings, reads), (1, 1))
  }
  assert_eq(runs, 1)
  // Another answer: computed.
  let (value, warnings, reads) = run(FixedBackend([elem, elem]))
  assert_true(value == Int(2))
  assert_eq((warnings, reads), (1, 1))
  assert_eq(runs, 2)
  // Also when the call fails.
  let failing : ClosureBody = (_, _, engine, _, _) => {
    engine.sink.warn(warning)
    engine.introspector.query_labelled() |> ignore
    bail_at(@syntax.Span::detached(), "failed")
  }
  let recorder = IntrospectionRecorder::new()
  let engine = memo_engine(
    introspector=Introspector::new(one).track_with(recorder),
  )
  let failed = try
    memo_call(memo_test_func(2), engine, Context::none(), [], failing)
  catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(failed)
  assert_eq((engine.sink.warnings().length(), recorder.len()), (1, 1))
  assert_eq(route_query_scopes.val, 0)
  assert_eq(route_shift_scopes.val, 0)
}
