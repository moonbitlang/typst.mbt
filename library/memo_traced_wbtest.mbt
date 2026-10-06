// Memoization and the traced span (IDE tracing): upstream tracks
// `Traced::get`, here the evaluations of source files collect the files
// whose code ran in them (`traced_file_log`), and the other memoized
// functions have the span in their keys. The helpers are those of
// `memo_closure_wbtest.mbt`.

///|
test "closure memo: the files asked of the traced span reach the evaluation around" {
  memo_test_begin()
  defer memo_test_end()
  let a = memo_file("ta.typ")
  let b = memo_file("tb.typ")
  let c = memo_file("tc.typ")
  let engine = memo_engine()
  let mut runs = 0
  // Code of `a` that calls code of `b`, like a `Vm` each.
  let body : ClosureBody = (_, _, _, _, _) => {
    runs += 1
    note_traced_file(a)
    note_traced_file(b)
    note_traced_file(b)
    note_traced_file(a)
    None
  }
  let f = memo_test_func(1)
  // Nothing collects: nothing is kept, and the call is reused.
  assert_false(traced_files_active())
  memo_call(f, engine, Context::none(), [], body) |> ignore
  memo_call(f, engine, Context::none(), [], body) |> ignore
  assert_eq(runs, 1)
  assert_eq(traced_file_log.val.length(), 0)
  // The evaluation of a source file collects. The call that was computed
  // outside of one has no files: it runs again, and then it is reused with
  // its files.
  let outer = traced_files_begin()
  note_traced_file(c)
  memo_call(f, engine, Context::none(), [], body) |> ignore
  assert_eq(runs, 2)
  // Once each, however often the calls inside noted them.
  assert_eq(traced_file_log.val.length(), 3)
  memo_call(f, engine, Context::none(), [], body) |> ignore
  memo_call(f, engine, Context::none(), [], body) |> ignore
  assert_eq(runs, 2)
  // An evaluated string has a traced span of its own: its files are not
  // those of the evaluation around it, and it reuses the call.
  let own = own_traced_begin()
  assert_false(traced_files_active())
  note_traced_file(memo_file("td.typ"))
  memo_call(f, engine, Context::none(), [], body) |> ignore
  own_traced_end(own)
  assert_eq(runs, 2)
  assert_true(traced_files_active())
  let files = traced_files_end(outer)
  assert_true(files == [c, a, b])
  assert_false(traced_files_active())
  assert_eq(traced_file_log.val.length(), 0)
  // The answers of two traced spans for these files.
  let in_file = (id : @syntax.FileId) => {
    Traced::new(traced=@syntax.Span::from_range(id, 1, 2))
  }
  let d = memo_file("td.typ")
  assert_true(traced_answers_equal(Traced::new(), in_file(d), files))
  assert_true(traced_answers_equal(in_file(d), Traced::new(), files))
  assert_false(traced_answers_equal(Traced::new(), in_file(a), files))
  assert_false(traced_answers_equal(in_file(b), Traced::new(), files))
  assert_true(traced_answers_equal(in_file(a), in_file(a), files))
  assert_false(
    traced_answers_equal(
      in_file(a),
      Traced::new(traced=@syntax.Span::from_range(a, 3, 4)),
      files,
    ),
  )
  assert_true(traced_answers_equal(in_file(a), in_file(b), []))
}

///|
test "memo: a layout result depends on the traced span" {
  memo_test_begin()
  defer memo_test_end()
  let span = @syntax.Span::from_range(memo_file("t.typ"), 1, 2)
  let content = TextElem::packed("x")
  let styles = StyleChain::empty()
  let key = hash128("layout")
  let mut runs = 0
  let layout = (traced : Traced) => {
    let engine = { ..memo_engine(), traced, }
    memoized_layout(engine, key, content, styles, None, engine => {
      runs += 1
      // What code in the layout traces, if anything is traced.
      if engine.traced.0 is Some(_) {
        engine.sink.value(Int(7), None)
      }
      Fragment([Frame::soft(Axes::new(Abs::pt(1.0), Abs::pt(1.0)))])
    })
    |> ignore
    engine.sink.values().length()
  }
  // An evaluated string lays out without tracing; the document's own
  // layout then still traces, and the other way round.
  assert_eq(layout(Traced::new()), 0)
  assert_eq(layout(Traced::new(traced=span)), 1)
  assert_eq(layout(Traced::new()), 0)
  assert_eq(layout(Traced::new(traced=span)), 1)
  assert_eq(runs, 2)
}
