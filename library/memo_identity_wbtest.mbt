// What the flags of a key mean for its entry (`MemoKey` in `memo.mbt`;
// `docs/incremental-design.md`, section 5.4): an entry whose key holds a
// host closure ends with its compilation, in every store, and a host
// closure is compared as the object it is also where a closure captured it.
//
// The stores are emptied when a compilation starts, so that nothing here
// can go wrong yet. The tests keep them: they start the next compilation
// as `with_layout_memo` does and tell the stores that they are its own,
// which is what a store that outlives its compilation will be (step 5 of
// slice 1 of the design).

///|
/// The next compilation, with the entries of the closure store and of the
/// layout store kept.
fn memo_test_next_compilation() -> Unit {
  memo_counter.val += 1
  memo_generation.val = memo_counter.val
  closure_store.generation = memo_generation.val
  layout_store.generation = memo_generation.val
}

///|
fn memo_test_host(key : String, answer : Int64) -> HostFunc {
  HostFunc::new(hash128(key), (_, _, _) => Int(answer))
}

///|
test "identity: a closure call with a host closure in its key ends with its compilation" {
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let host = memo_test_host("h", 1)
  let mut runs = 0
  let body : ClosureBody = (_, _, _, _, args) => {
    runs += 1
    args.expect("value")
  }
  let f = memo_test_func(1)
  let call = (value : Value) => {
    memo_call(f, engine, Context::none(), [value], body) |> ignore
  }
  // As an argument, in an array, and captured by a closure that is the
  // argument: found in the compilation that made them.
  let captured = test_closure(@syntax.parse_code("x"), Func(Func::host(host)))
  let values = [
    Value::Func(Func::host(host)),
    Array(Arr::from_array([Func(Func::host(host))])),
    captured,
  ]
  for value in values {
    call(value)
    call(value)
  }
  assert_eq(runs, 3)
  // A call without one, for comparison.
  call(Int(7))
  call(Int(7))
  assert_eq(runs, 4)
  // The next compilation finds what any compilation may find, and none of
  // the calls with the host closure, although it asks with the same
  // objects.
  memo_test_next_compilation()
  call(Int(7))
  assert_eq(runs, 4)
  for value in values {
    call(value)
  }
  assert_eq(runs, 7)
  // They are its own now.
  for value in values {
    call(value)
  }
  assert_eq(runs, 7)
  // The same for the context of a call: styles that hold a host closure,
  // which the call asked for.
  let recipe : Style = Recipe({
    selector: None,
    transform: Func(Func::host(host)),
    span: @syntax.Span::detached(),
    outside: false,
  })
  let styles = StyleChain::empty().chain(Styles::from_array([recipe]))
  let plain = StyleChain::empty().chain(
    Styles::from_array([
      TextElem::set_size(TextSize(Length::from_abs(Abs::pt(8.0)))),
    ]),
  )
  let mut asked = 0
  let body : ClosureBody = (_, _, _, context, _) => {
    asked += 1
    context.try_styles() |> ignore
    None
  }
  let g = memo_test_func(2)
  let at = (styles : StyleChain) => {
    memo_call(g, engine, Context::new(styles~), [], body) |> ignore
  }
  for chain in [styles, plain] {
    at(chain)
    at(chain)
  }
  assert_eq(asked, 2)
  memo_test_next_compilation()
  at(plain)
  assert_eq(asked, 2)
  at(styles)
  assert_eq(asked, 3)
}

///|
test "identity: a layout with a host closure in its key ends with its compilation" {
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let host = memo_test_host("h", 1)
  let elem = TextElem::packed("x").elem()
  let with_host = Content::from_fields(elem, [Some(Func(Func::host(host)))])
  let without = Content::from_fields(elem, [Some(Int(1))])
  let styles = StyleChain::empty()
  let mut runs = 0
  let layout = (content : Content) => {
    let key = memo_fingerprint(state => {
      state.write_str("layout")
      state.write(content)
    })
    memoized_layout(engine, key, content, styles, None, _ => {
      runs += 1
      Fragment([Frame::soft(Axes::new(Abs::pt(1.0), Abs::pt(1.0)))])
    })
    |> ignore
  }
  for content in [with_host, without] {
    layout(content)
    layout(content)
  }
  assert_eq(runs, 2)
  memo_test_next_compilation()
  layout(without)
  assert_eq(runs, 2)
  layout(with_host)
  assert_eq(runs, 3)
  layout(with_host)
  assert_eq(runs, 3)
}

///|
test "identity: highlighted raw text under styles with a host closure ends with its compilation" {
  raw_test_reset()
  let host = memo_test_host("h", 1)
  let recipe : Style = Recipe({
    selector: None,
    transform: Func(Func::host(host)),
    span: @syntax.Span::detached(),
    outside: false,
  })
  let styles = StyleChain::empty().chain(Styles::from_array([recipe]))
  let elem = RawElem::new(Text("let x = 1;")).with_lang(Some("rust"))
  // Outside of a compilation such a result is kept for nobody.
  let engine = memo_engine()
  elem.highlight(engine, styles) |> ignore
  assert_eq(raw_highlight_cache.length(), 0)
  elem.highlight(engine, StyleChain::empty()) |> ignore
  assert_eq(raw_highlight_cache.length(), 1)
  // In a compilation it is found by that compilation.
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let first = elem.highlight(engine, styles)
  assert_eq(raw_highlight_cache.length(), 2)
  assert_true(physical_equal(first[0].0, elem.highlight(engine, styles)[0].0))
  // And not by the next, which finds the result that has no host closure
  // in its key (these results are kept by content, with ages).
  let plain = elem.highlight(engine, StyleChain::empty())
  memo_test_next_compilation()
  assert_true(
    physical_equal(plain[0].0, elem.highlight(engine, StyleChain::empty())[0].0),
  )
  assert_false(physical_equal(first[0].0, elem.highlight(engine, styles)[0].0))
}

///|
/// A closure's hash has the key of a host closure it captured. An entry
/// does not take the key's word for which function that is: it compares
/// the objects, as it does for a host closure that is an argument itself.
test "identity: closures that captured two host closures with one key are two arguments" {
  let one = memo_test_host("same", 1)
  let other = memo_test_host("same", 2)
  let node = @syntax.parse_code("x")
  let getter = (host : HostFunc) => test_closure(node, Func(Func::host(host)))
  // Nested: a closure that captured a closure that captured it, in a
  // dictionary.
  let nested = (host : HostFunc) => {
    test_closure(node, Dict(Dict::from_pairs([("f", getter(host))])))
  }
  for make in [getter, nested] {
    let a = make(one)
    let b = make(other)
    // Typst's `==` is the hash's.
    assert_true(a == b)
    assert_eq(hash128(a), hash128(b))
    // Twice: the second time with the hashes and flags from their caches.
    for _ in 0..<2 {
      assert_false(values_memo_equal(a, b))
      assert_true(values_memo_equal(a, make(one)))
      assert_true(values_memo_equal(b, make(other)))
    }
  }
  // A module that holds one: by its hash, and by the host closures in it.
  let module_ = (host : HostFunc) => {
    let scope = Scope::new()
    scope.define_("f", Func(Func::host(host))) |> ignore
    Value::Module(Module::new("m", scope))
  }
  for _ in 0..<2 {
    assert_eq(hash128(module_(one)), hash128(module_(other)))
    assert_false(values_memo_equal(module_(one), module_(other)))
    assert_true(values_memo_equal(module_(one), module_(one)))
  }
  // Repeated calls at one call site, with warm caches: each getter is
  // answered with its own function.
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let mut runs = 0
  let body : ClosureBody = (_, closure, _, _, _) => {
    runs += 1
    descriptor_test_captured(closure)
  }
  let call = (host : HostFunc) => {
    guard getter(host) is Func(func) else { fail("not a function") }
    guard memo_call(func, engine, Context::none(), [], body)
      is Func({ inner: Host(found), .. }) else {
      fail("not a host closure")
    }
    found
  }
  for _ in 0..<3 {
    assert_true(physical_equal(call(one), one))
    assert_true(physical_equal(call(other), other))
  }
  assert_eq(runs, 2)
  // And as arguments of one function, inside a closure.
  let mut seen = 0
  let body : ClosureBody = (_, _, _, _, args) => {
    seen += 1
    args.expect("getter")
  }
  let f = memo_test_func(9)
  let pass = (host : HostFunc) => {
    guard memo_call(f, engine, Context::none(), [nested(host)], body)
      is Func({ inner: Closure(closure), .. }) &&
      descriptor_test_captured(closure) is Dict(dict) &&
      dict.map.get("f") is Some(Func({ inner: Closure(inner), .. })) &&
      descriptor_test_captured(inner) is Func({ inner: Host(found), .. }) else {
      fail("not the getter")
    }
    found
  }
  for _ in 0..<3 {
    assert_true(physical_equal(pass(one), one))
    assert_true(physical_equal(pass(other), other))
  }
  assert_eq(seen, 2)
}

///|
/// Two modules that hold the same (`Module::new` twice, as a host can) have
/// one fingerprint and are one argument, also where a closure captured
/// them: upstream's memoized calls take arguments by their hashes, and the
/// port follows. Only a host program can show this for modules that have
/// something in them (a document gets two modules with one hash from two
/// plugins without functions: `typst/oracle_wbtest.mbt`, "modules: ..").
test "identity: two modules with one fingerprint are one argument, as upstream's" {
  let module_ = () => {
    let scope = Scope::new()
    scope.define_("v", Int(1)) |> ignore
    Module::new("m", scope)
  }
  let a = module_()
  let b = module_()
  assert_false(a == b)
  assert_eq(hash128(Value::Module(a)), hash128(Value::Module(b)))
  let node = @syntax.parse_code("x")
  let getter = (m : Module) => {
    guard test_closure(node, Module(m)) is Func(func) else {
      abort("not a function")
    }
    func
  }
  assert_true(Value::Func(getter(a)) == Value::Func(getter(b)))
  assert_true(values_memo_equal(Module(a), Module(b)))
  memo_test_begin()
  defer memo_test_end()
  let engine = memo_engine()
  let mut runs = 0
  let body : ClosureBody = (_, closure, _, _, _) => {
    runs += 1
    descriptor_test_captured(closure)
  }
  let call = (m : Module) => {
    memo_call(getter(m), engine, Context::none(), [], body)
  }
  // The getter of `b` is answered with the module of the getter of `a`.
  assert_true(call(a) == Module(a))
  assert_true(call(b) == Module(a))
  assert_false(call(b) == Module(b))
  assert_eq(runs, 1)
}
