// Modules compare by identity (`==`), and memoized calls take them by
// their hash, as upstream's do. The modules of two plugins without
// functions have one hash: two modules to `==`, one argument to a memoized
// call. (Until the owner's decision of 2026-10-11, "exactly as upstream",
// the port kept them apart in memoized calls too.)

///|
/// A plugin that exports its memory (of `pages` pages) and no function:
/// `(module (memory (export "memory") <pages>))`.
fn plugin_test_memory_only(pages : Int32) -> Bytes {
  Bytes::from_array([
    b'\x00',
    b'\x61',
    b'\x73',
    b'\x6d',
    b'\x01',
    b'\x00',
    b'\x00',
    b'\x00',
    // The memory section: one memory without a maximum.
    b'\x05',
    b'\x03',
    b'\x01',
    b'\x00',
    pages.to_byte(),
    // The export section: "memory", a memory, index 0.
    b'\x07',
    b'\x0a',
    b'\x01',
    b'\x06',
    b'\x6d',
    b'\x65',
    b'\x6d',
    b'\x6f',
    b'\x72',
    b'\x79',
    b'\x02',
    b'\x00',
  ])
}

///|
fn plugin_test_load(bytes : Bytes) -> Module raise {
  Plugin::module_(bytes) catch {
    HintedError(e) => fail(e.message)
  }
}

///|
/// A frame with a tag whose element holds `value`.
fn plugin_test_frame(value : Value) -> Frame {
  let elem = TextElem::packed("x").elem()
  let frame = Frame::soft(Axes::new(Abs::pt(10.0), Abs::pt(10.0)))
  frame.push(
    Point::zero(),
    Tag(
      Start(Content::from_fields(elem, [Some(value)]), {
        introspectable: true,
        tagged: false,
      }),
    ),
  )
  frame
}

///|
/// The modules of two plugins without functions have equal fingerprints
/// (upstream's hashes too). `==` tells them apart, a memoized call does
/// not: what upstream does (`typst/oracle_wbtest.mbt`, "modules: ..", has
/// its answers for documents).
test "plugin modules without functions: two to `==`, one argument to a memoized call" {
  let a = plugin_test_load(plugin_test_memory_only(1))
  let b = plugin_test_load(plugin_test_memory_only(2))
  // One module per plugin content (upstream memoizes `Plugin::module`).
  assert_true(a == plugin_test_load(plugin_test_memory_only(1)))
  assert_false(a == b)
  assert_eq(a.scope().length(), 0)
  assert_eq(hash128(Value::Module(a)), hash128(Value::Module(b)))
  let flags = (value : Value) => {
    fingerprint_flags_in(() => SipHasher128::new().write(value))
  }
  let closure = (m : Module) => test_closure(@syntax.parse_code("x"), Module(m))
  // No flag: the fingerprint is all that memoization asks of a module.
  for _ in 0..<2 {
    assert_eq(flags(Module(a)), 0)
    assert_eq(flags(Module(a.with_name("p"))), 0)
    assert_eq(
      flags(
        Array(Arr::from_array([Dict(Dict::from_pairs([("m", Module(b))]))])),
      ),
      0,
    )
    assert_eq(flags(closure(a)), 0)
  }
  // Closures compare by their hash: two that captured one module each are
  // equal, upstream's too.
  assert_true(closure(a) == closure(b))
  // A plugin with functions: the module's fingerprint carries the plugin.
  let grow = plugin_test_load(plugin_test_unhex(grow_plugin_hex))
  assert_true(grow.scope().length() > 0)
  assert_eq(flags(Module(grow)), 0)
  assert_false(hash128(Value::Module(grow)) == hash128(Value::Module(a)))
  assert_false(closure(grow) == closure(a))
  // Memoized inputs compare modules by their hashes.
  assert_true(values_memo_equal(Module(a), Module(b)))
  assert_true(values_memo_equal(Module(a), Module(a)))
  assert_false(values_memo_equal(Module(a), Module(grow)))
  assert_false(values_memo_equal(Module(a), Module(a.with_name("p"))))
  // A frame whose tags hold a module is reused like any other.
  assert_true(frame_cacheable(plugin_test_frame(Module(a))))
  assert_true(frame_cacheable(plugin_test_frame(closure(b))))
  assert_true(frame_cacheable(plugin_test_frame(Module(grow))))
  // A recorded read whose result holds one is validated on another
  // introspector by its fingerprint.
  let elem = TextElem::packed("x").elem()
  let lossy = (value : Value) => {
    let recorder = IntrospectionRecorder::new()
    Introspector::new(FixedBackend([Content::from_fields(elem, [Some(value)])]))
    .track_with(recorder)
    .query_labelled()
    |> ignore
    recorder.lossy
  }
  assert_false(lossy(Module(a)))
  assert_false(lossy(closure(a)))
  assert_false(lossy(Module(grow)))
  // A memoized closure call with one is the call with the other: the
  // second is answered with the result of the first, which was computed
  // for the other module.
  memo_test_begin()
  defer memo_test_end()
  let mut runs = 0
  let body : ClosureBody = (_, _, _, _, args) => {
    runs += 1
    let m : Value = args.expect("module")
    Bool(m == Module(a))
  }
  let f = memo_test_func(41)
  let call = (m : Module) => {
    memo_call(f, memo_engine(), Context::none(), [Module(m)], body)
  }
  assert_true(call(a) == Bool(true))
  assert_true(call(b) == Bool(true))
  assert_eq(runs, 1)
  // And with a plugin that has functions it is another call.
  assert_true(call(grow) == Bool(false))
  assert_eq(runs, 2)
}

///|
/// A plugin's module is the same argument after the cache that made it was
/// dropped (`evict`): the fingerprint of a module with functions is that
/// of the plugin, its bytes and its transitions, whatever object holds
/// them. To `==` the new module is another one, as it is upstream once
/// comemo has dropped `Plugin::module`'s result.
test "a plugin's module after its cache was dropped: the same argument, another object" {
  let bytes = plugin_test_unhex(grow_plugin_hex)
  let before = plugin_test_load(bytes)
  assert_true(before == plugin_test_load(bytes))
  let grown = (m : Module) => {
    guard m.scope().get("grow") is Some(binding) &&
      binding.value is Func(func) &&
      func.to_plugin() is Some(plugin) else {
      fail("no plugin function")
    }
    plugin.transition([]) catch {
      HintedError(e) => fail(e.message)
    }
  }
  let before_grown = grown(before)
  assert_false(
    hash128(Value::Module(before)) == hash128(Value::Module(before_grown)),
  )
  // What `evict` does on its `max_age`-th call.
  plugin_call_cache.clear()
  plugin_transition_cache.clear()
  plugin_module_cache.clear()
  let after = plugin_test_load(bytes)
  assert_false(before == after)
  assert_eq(hash128(Value::Module(before)), hash128(Value::Module(after)))
  assert_true(values_memo_equal(Module(before), Module(after)))
  // A transition of the new module is the transition of the old one.
  let after_grown = grown(after)
  assert_false(before_grown == after_grown)
  assert_eq(
    hash128(Value::Module(before_grown)),
    hash128(Value::Module(after_grown)),
  )
  assert_true(values_memo_equal(Module(before_grown), Module(after_grown)))
  // A memoized call that was given the old module is found for the new.
  memo_test_begin()
  defer memo_test_end()
  let mut runs = 0
  let body : ClosureBody = (_, _, _, _, args) => {
    runs += 1
    args.expect("module")
  }
  let f = memo_test_func(42)
  let call = (m : Module) => {
    memo_call(f, memo_engine(), Context::none(), [Module(m)], body)
  }
  assert_true(call(before) == Module(before))
  assert_true(call(after) == Module(before))
  assert_eq(runs, 1)
}
