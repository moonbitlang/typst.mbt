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
  let store : MemoStore[Int32, Int32] = MemoStore::new()
  let mut runs = 0
  let call = (depth : Int32, tag : Int32, body : (Engine) -> Unit) => {
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
  // What is asked of a route of its own is asked of nobody's (the math of
  // a bibliography entry is evaluated from the root of a new route).
  for depth in [1, 7] {
    call(depth, 5, _ => {
      with_own_route(() => {
        memo_route(3).check_within(64) |> ignore
        note_route_query(memo_file("a.typ"))
      }) catch {
        _ => ()
      }
    })
    |> ignore
  }
  assert_eq(runs, 9)
  // The bookkeeping is back where it was.
  assert_eq(route_shift_scopes.val, 0)
  assert_eq(route_query_scopes.val, 0)
}

///|
test "memoize: an entry that tracks its route, and the depth bounds of a module evaluation" {
  // The two things that note what is asked of routes besides closure
  // calls: an entry of `memoize` that tracks its route (the works of a
  // bibliography) and the evaluation of a source file, which keeps the
  // bounds of its depth checks ([RouteShifts], `eval/import.mbt`). Both
  // save and reset the same state and hand what they noted to whoever is
  // around them. Each inside the other, computed and found.
  memo_test_begin()
  defer memo_test_end()
  let store : MemoStore[Int32, Int32] = MemoStore::new()
  let mut runs = 0
  let call = (tag : Int32, body : (Engine) -> Unit) => {
    let engine = { ..memo_engine(), route: memo_route(3), }
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
    |> ignore
  }
  // The bounds of an evaluation that checks the depth of its route (three
  // deep, at most ten allowed: seven more are the same answer).
  let checking = () => {
    let outer = route_shifts_begin()
    memo_route(3).check_within(10) |> ignore
    route_shifts_end(outer)
  }
  let bounded = checking()
  assert_true(bounded.allows(7) && !bounded.allows(8))
  // An evaluation around an entry that asked nothing has no bounds from
  // it, whether the entry is computed in it or found.
  let outer = route_shifts_begin()
  call(1, _ => ())
  call(1, _ => ())
  let around = route_shifts_end(outer)
  assert_eq(runs, 1)
  assert_true(around.allows(-1000) && around.allows(1000))
  // Around a call that asked: the bounds are the evaluation's too.
  let outer = route_shifts_begin()
  call(2, engine => engine.route.check_within(10) |> ignore)
  let around = route_shifts_end(outer)
  assert_true(around.allows(7) && !around.allows(8))
  // An evaluation inside the call that checked a depth: the call asked.
  let before = runs
  for _ in 0..<2 {
    call(3, _ => checking() |> ignore)
  }
  assert_eq(runs, before + 2)
  // An evaluation that is found inside the call notes its bounds as if it
  // had run: with bounds the call asked, without it did not.
  let before = runs
  for _ in 0..<2 {
    call(4, _ => bounded.note_reused(0))
  }
  assert_eq(runs, before + 2)
  let unbounded = route_shifts_end(route_shifts_begin())
  let before = runs
  for _ in 0..<2 {
    call(5, _ => unbounded.note_reused(4))
  }
  assert_eq(runs, before + 1)
  // The files it asked its route for are questions too.
  let before = runs
  for _ in 0..<2 {
    call(6, _ => note_route_queries([memo_file("a.typ")]))
  }
  assert_eq(runs, before + 2)
  // An evaluation on a route of its own inside the call (an import in a
  // string that is evaluated from a root route) is nobody's question.
  let before = runs
  for _ in 0..<2 {
    call(7, _ => {
      with_own_route(() => {
        let queries = route_queries_begin()
        note_route_query(memo_file("a.typ"))
        checking() |> ignore
        route_queries_end(queries) |> ignore
      }) catch {
        _ => ()
      }
    })
  }
  assert_eq(runs, before + 1)
  // A closure call without bounds that is found deeper than it was
  // computed notes "no bounds" moved by the difference: no question
  // either.
  let func = memo_test_func(41)
  let quiet : ClosureBody = (_, _, _, _, _) => None
  let closure_at = (depth : Int32) => {
    let engine = { ..memo_engine(), route: memo_route(depth), }
    let value = memo_call(func, engine, Context::none(), [], quiet) catch {
      _ => None
    }
    ignore(value)
  }
  closure_at(1)
  let before = runs
  for _ in 0..<2 {
    call(8, _ => closure_at(6))
  }
  assert_eq(runs, before + 1)
  assert_eq(route_shift_scopes.val, 0)
  assert_eq(route_query_scopes.val, 0)
}

///|
test "memoize: a route of its own leaves what the calls around it collected" {
  let a = memo_file("a.typ")
  let b = memo_file("b.typ")
  let c = memo_file("c.typ")
  let outer = route_queries_begin()
  note_route_query(a)
  let inside = with_own_route(() => {
    note_route_query(b)
    // A call in there that collects, and is the only one that does: it
    // empties the log when it ends.
    let inner = route_queries_begin()
    note_route_query(c)
    route_queries_end(inner)
  })
  assert_true(inside == [c])
  note_route_query(a)
  assert_true(route_queries_end(outer) == [a])
  assert_eq(route_query_scopes.val, 0)
}

///|
test "memoize: what is asked of a route inside a tracking call is the caller's too" {
  memo_test_begin()
  defer memo_test_end()
  let store : MemoStore[Int32, Int32] = MemoStore::new()
  let inner = (engine : Engine, tag : Int32, body : (Engine) -> Unit) => {
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
    depth : Int32,
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

///|
test "svg: an image is its data, its fonts, what they were chosen for and the data of the images it links" {
  let data : Bytes = b"<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>"
  let image = (links : Array[U128], selections : Array[Int32]) => {
    let svg = SvgImage::new(data) catch { _ => abort("an SVG") }
    Image::plain(Svg({ ..svg, links, selections, }))
  }
  let a = hash128("a")
  let b = hash128("b")
  // Upstream's identity for an image that links nothing and has no text.
  assert_true(image([], []) == image([], []))
  assert_eq(hash128(image([], [])), hash128(image([], [])))
  assert_true(image([a], [0, -1]) == image([a], [0, -1]))
  assert_eq(hash128(image([a], [0, -1])), hash128(image([a], [0, -1])))
  // The linked data, its number and its order; the answers of the font
  // resolver, their number and their order (with real fonts:
  // `doc/svg_identity_test.mbt`).
  let all = [
    image([], []),
    image([a], []),
    image([b], []),
    image([a, b], []),
    image([b, a], []),
    image([], [0]),
    image([], [-1]),
    image([], [0, 1]),
    image([], [1, 0]),
    image([a], [0]),
  ]
  for i in 0..<all.length() {
    for j in 0..<all.length() {
      if i != j {
        assert_true(all[i] != all[j])
        assert_true(hash128(all[i]) != hash128(all[j]))
        assert_true(Hash::hash(all[i]) != Hash::hash(all[j]))
      }
    }
  }
}
