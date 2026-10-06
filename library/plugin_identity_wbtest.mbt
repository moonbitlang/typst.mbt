// Modules compare by identity. The modules of plugins without functions
// have nothing else to tell them apart (`ModuleInner.identified`).

///|
/// A plugin that exports its memory (of `pages` pages) and no function:
/// `(module (memory (export "memory") <pages>))`.
fn plugin_test_memory_only(pages : Int) -> Bytes {
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
/// (upstream's hashes too), so the fingerprints are marked, like those of
/// host closures: memoization does not take one module for the other.
test "plugin modules without functions are told apart by identity only" {
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
  for _ in 0..<2 {
    assert_eq(flags(Module(a)), fingerprint_identity)
    assert_eq(flags(Module(a.with_name("p"))), fingerprint_identity)
    assert_eq(
      flags(
        Array(Arr::from_array([Dict(Dict::from_pairs([("m", Module(b))]))])),
      ),
      fingerprint_identity,
    )
    assert_eq(flags(closure(a)), fingerprint_identity)
  }
  // A plugin with functions: the module's fingerprint carries the plugin.
  let grow = plugin_test_load(plugin_test_unhex(grow_plugin_hex))
  assert_true(grow.scope().length() > 0)
  assert_eq(flags(Module(grow)), 0)
  assert_eq(flags(closure(grow)), 0)
  assert_false(hash128(Value::Module(grow)) == hash128(Value::Module(a)))
  // Memoized inputs compare modules by identity.
  assert_false(values_memo_equal(Module(a), Module(b)))
  assert_true(values_memo_equal(Module(a), Module(a)))
  // A frame whose tags hold such a module is not reused.
  assert_false(frame_cacheable(plugin_test_frame(Module(a))))
  assert_false(frame_cacheable(plugin_test_frame(closure(b))))
  assert_true(frame_cacheable(plugin_test_frame(Module(grow))))
  assert_true(frame_cacheable(plugin_test_frame(closure(grow))))
  // A recorded read whose result holds one is not validated on another
  // introspector.
  let elem = TextElem::packed("x").elem()
  let lossy = (value : Value) => {
    let recorder = IntrospectionRecorder::new()
    Introspector::new(FixedBackend([Content::from_fields(elem, [Some(value)])]))
    .track_with(recorder)
    .query_labelled()
    |> ignore
    recorder.lossy
  }
  assert_true(lossy(Module(a)))
  assert_true(lossy(closure(a)))
  assert_false(lossy(Module(grow)))
  assert_false(lossy(closure(grow)))
  // A memoized closure call with one is not the call with the other
  // (upstream's is: it compares the hashes of the arguments).
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
  assert_true(call(b) == Bool(false))
  assert_true(call(a) == Bool(true))
  assert_true(call(b) == Bool(false))
  assert_eq(runs, 2)
}
