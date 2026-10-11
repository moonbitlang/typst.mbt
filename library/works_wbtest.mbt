// The works of a bibliography as a kept result (`Works::generate`, an
// entry of `memoize`): what they hand out, and the one thing their entry
// does that the other entries of `memoize` do not, which is to track the
// route instead of having it in the key. That an entry is found and when
// it is rejected is tested with whole documents
// (`typst/state_outside_wbtest.mbt`).

///|
test "memoize: a call that tracks its route is found on every route, unless it asked one" {
  memo_test_begin()
  defer memo_test_end()
  let store : MemoStore[Int, Int] = MemoStore::new()
  let mut runs = 0
  let call = (depth : Int, tag : Int, body : (Engine) -> Unit) => {
    let engine = { ..memo_engine(), route: memo_route(depth), }
    let key = memo_fingerprint(state => state.write_usize(tag))
    memoize(
      store,
      engine,
      key,
      tag,
      value => value,
      engine => {
        runs += 1
        body(engine)
        tag
      },
      tracks_route=true,
    )
  }
  // Nothing asked: one result for every depth.
  for depth in [1, 5, 2, 60] {
    assert_eq(call(depth, 1, _ => ()), 1)
  }
  assert_eq(runs, 1)
  // A depth check: what the answer would be on another route is not in
  // the entry, so there is none.
  for depth in [1, 1, 5] {
    call(depth, 2, engine => engine.route.check_within(64) |> ignore) |> ignore
  }
  assert_eq(runs, 4)
  // `Route::contains`, as an import asks it.
  for _ in 0..<2 {
    call(1, 3, _ => note_route_query(memo_file("a.typ"))) |> ignore
  }
  assert_eq(runs, 6)
  // A memoized call inside that is a result of its depth only.
  for _ in 0..<2 {
    call(1, 4, _ => note_route_shift(0, 0)) |> ignore
  }
  assert_eq(runs, 8)
  // The bookkeeping is back where it was.
  assert_eq(route_shift_scopes.val, 0)
  assert_eq(route_query_scopes.val, 0)
}

///|
test "memoize: what is asked of a route inside a tracking call is the caller's too" {
  memo_test_begin()
  defer memo_test_end()
  let store : MemoStore[Int, Int] = MemoStore::new()
  let inner = (engine : Engine, tag : Int, body : (Engine) -> Unit) => {
    let key = memo_fingerprint(state => state.write_usize(tag))
    memoize(
      store,
      engine,
      key,
      tag,
      value => value,
      engine => {
        body(engine)
        tag
      },
      tracks_route=true,
    )
    |> ignore
  }
  let mut runs = 0
  let outer = (
    func : Func,
    depth : Int,
    body : (Engine) -> Unit raise SourceError,
  ) => {
    let engine = { ..memo_engine(), route: memo_route(depth), }
    let closure : ClosureBody = (_, _, engine, _, _) => {
      runs += 1
      body(engine)
      None
    }
    memo_call(func, engine, Context::none(), [], closure) |> ignore
  }
  // A closure call around an entry that asked nothing is not bound to its
  // depth, whether the entry was computed in it or found (an entry with
  // the route in its key binds it: "a result that is only that of one
  // depth" in `memo_closure_wbtest.mbt`).
  let quiet = (engine : Engine) => inner(engine, 1, _ => ())
  let f = memo_test_func(31)
  let g = memo_test_func(32)
  for depth in [3, 4, 2] {
    outer(f, depth, quiet)
  }
  assert_eq(runs, 1)
  for depth in [5, 3] {
    outer(g, depth, quiet)
  }
  assert_eq(runs, 2)
  // One that asked binds it as the check itself does: the call is only
  // found where the check answers the same.
  let checking = (engine : Engine) => {
    inner(engine, 2, engine => engine.route.check_within(10) |> ignore)
  }
  let h = memo_test_func(33)
  let before = runs
  for depth in [3, 4, 10, 11, 12, 3] {
    outer(h, depth, checking)
  }
  assert_eq(runs, before + 2)
}

///|
test "works: the errors they keep are copies for whoever catches them" {
  // Upstream `Works::citation` clones the result and `Works::bibliography`
  // the errors (`.cloned()`, `.map_err(Clone::clone)`). A diagnostic is an
  // object here, and `trace` adds tracepoints to the errors it catches: a
  // citation that fails is raised again by every layout of every iteration
  // from the same works.
  let span = @syntax.Span::detached()
  let cited = Location::new(hash128("citation"))
  let listed = Location::new(hash128("bibliography"))
  let works : Works = {
    bibliographies: Map([
      (listed, Err([SourceDiagnostic::error_at(span, "unsuitable")])),
    ]),
    groups: Map([(cited, Err([SourceDiagnostic::error_at(span, "no key")]))]),
  }
  let caught = (f : () -> Unit raise SourceError) => {
    try f() catch {
      SourceError(errors) => {
        let seen = errors.map(error => {
          "\{error.message}: \{error.trace.length()} tracepoints, \{error.hints.length()} hints"
        })
        // What a caller does with an error it catches.
        for error in errors {
          error.trace.push({ v: Tracepoint::Call(Some("f")), span, })
          error.hint("a hint")
        }
        errors.push(SourceDiagnostic::error_at(span, "another"))
        seen.join("; ")
      }
    } noraise {
      _ => "no error"
    }
  }
  for _ in 0..<3 {
    inspect(
      caught(() => works.citation(cited, span) |> ignore),
      content="no key: 0 tracepoints, 0 hints",
    )
    inspect(
      caught(() => works.bibliography(listed, span) |> ignore),
      content="unsuitable: 0 tracepoints, 0 hints",
    )
  }
}
