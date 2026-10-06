// Host closures (`HostFunc`) and the validation of recorded introspector
// reads whose results hold them (`IntrospectionRecorder::validate`).

///|
/// An introspector backend whose labelled elements are fixed.
priv struct FixedBackend(Array[Content])

///|
impl IntrospectorBackend for FixedBackend with fn query(self, selector) {
  // Like `ElementIntrospector::query`, which caches by the selector's
  // fingerprint.
  hash128(selector) |> ignore
  self.0
}

///|
impl IntrospectorBackend for FixedBackend with fn query_first(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn query_unique(_, _) {
  bail("selector does not match any element")
}

///|
impl IntrospectorBackend for FixedBackend with fn query_label(_, _) {
  bail("no label")
}

///|
impl IntrospectorBackend for FixedBackend with fn query_labelled(self) {
  self.0
}

///|
impl IntrospectorBackend for FixedBackend with fn query_count_before(_, _, _) {
  0
}

///|
impl IntrospectorBackend for FixedBackend with fn label_count(_, _) {
  0
}

///|
impl IntrospectorBackend for FixedBackend with fn locator(_, _, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn pages(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn page(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn position(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn page_numbering(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn page_supplement(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn anchor(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn document(_, _) {
  None
}

///|
impl IntrospectorBackend for FixedBackend with fn path(_, _) {
  None
}

///|
/// Record `query_labelled` on an introspector with the elements `before`
/// and validate the read against one with the elements `after`.
fn recorded_query_validates(
  before : Array[Content],
  after : Array[Content],
) -> Bool {
  let recorder = IntrospectionRecorder::new()
  let tracked = Introspector::new(FixedBackend(before)).track_with(recorder)
  tracked.query_labelled() |> ignore
  recorder.validate(Introspector::new(FixedBackend(after)))
}

///|
/// A closure over `node` capturing `x = value`.
fn test_closure(node : @syntax.SyntaxNode, value : Value) -> Value {
  let captured = Scope::new()
  captured.define_("x", value) |> ignore
  Func(
    Func::closure({
      node: Context(node),
      defaults: [],
      captured,
      num_pos_params: 0,
      hash: LazyFingerprint::new(),
      node_hash: LazyFingerprint::new(),
    }),
  )
}

///|
test "host closures compare by identity and fingerprint by key" {
  let call : NativeFn = (_, _, _) => None
  let f = HostFunc::new(hash128("f"), call)
  let g = HostFunc::new(hash128("g"), call)
  let same_key = HostFunc::new(hash128("f"), call)
  // Equality is identity.
  assert_true(Func::host(f) == Func::host(f))
  assert_false(Func::host(f) == Func::host(g))
  assert_false(Func::host(f) == Func::host(same_key))
  // The fingerprint is the key.
  assert_false(hash128(Func::host(f)) == hash128(Func::host(g)))
  assert_eq(hash128(Func::host(f)), hash128(Func::host(same_key)))
  // It is identity-bearing and marks host closures; a closure's is neither
  // (closures with equal hashes are equal).
  let flags = fingerprint_flags_in(() => {
    SipHasher128::new().write(Func::host(f))
  })
  assert_true((flags & fingerprint_identity) != 0)
  assert_true((flags & fingerprint_host) != 0)
  let closure_flags = fingerprint_flags_in(() => {
    SipHasher128::new().write(test_closure(@syntax.parse_code("x"), Int(1)))
  })
  assert_eq(closure_flags, 0)
  assert_true(
    test_closure(@syntax.parse_code("x"), Int(1)) ==
    test_closure(@syntax.parse_code("x"), Int(1)),
  )
  assert_false(
    test_closure(@syntax.parse_code("x"), Int(1)) ==
    test_closure(@syntax.parse_code("x"), Int(2)),
  )
  // Like an anonymous closure, it has no name and the same repr.
  assert_eq(Func::host(f).repr(), "(..) => ..")
  assert_true(Func::host(f).name() is None)
}

///|
test "a fingerprint computation can collect the host closures it visits" {
  let call : NativeFn = (_, _, _) => None
  let f = HostFunc::new(hash128("f"), call)
  let g = HostFunc::new(hash128("g"), call)
  let elem = TextElem::packed("x").elem()
  let content = (value : Value) => Content::from_fields(elem, [Some(value)])
  let node = @syntax.parse_code("x")
  // In content, arrays, and the captures of a closure; in order.
  let value = content(
    Array(
      Arr::from_array([
        Func(Func::host(f)),
        Int(1),
        test_closure(node, Func(Func::host(g))),
        Content(content(Func(Func::host(f)))),
      ]),
    ),
  )
  let collect = () => fingerprint_hosts_in(() => hash128(value) |> ignore)
  let hosts = collect()
  assert_eq(hosts.length(), 3)
  assert_true(physical_equal(hosts[0], f))
  assert_true(physical_equal(hosts[1], g))
  assert_true(physical_equal(hosts[2], f))
  // Also when the fingerprints of the content are cached.
  assert_eq(collect().length(), 3)
  // Content without host closures is not visited again (and yields none).
  let plain = content(Int(1))
  hash128(plain) |> ignore
  assert_eq(fingerprint_hosts_in(() => hash128(plain) |> ignore).length(), 0)
  // Collecting does not change the fingerprint.
  let before = hash128(value)
  let mut during = u128_zero
  fingerprint_hosts_in(() => during = hash128(value)) |> ignore
  assert_eq(before, during)
}

///|
test "validation: recorded results are validated by fingerprint and host identity" {
  let elem = TextElem::packed("x").elem()
  let content = (value : Value) => Content::from_fields(elem, [Some(value)])
  // Plain results: validated by fingerprint, as before.
  assert_true(recorded_query_validates([content(Int(1))], [content(Int(1))]))
  assert_false(recorded_query_validates([content(Int(1))], [content(Int(2))]))
  // Host closures: the same closure in a result created anew validates.
  let call : NativeFn = (_, _, _) => None
  let host = HostFunc::new(hash128("h"), call)
  let h1 = content(Func(Func::host(host)))
  assert_true(recorded_query_validates([h1], [content(Func(Func::host(host)))]))
  // Another closure does not, also with the same key and thus the same
  // fingerprint.
  let other = content(Func(Func::host(HostFunc::new(hash128("o"), call))))
  assert_false(recorded_query_validates([h1], [other]))
  let h2 = content(Func(Func::host(HostFunc::new(hash128("h"), call))))
  assert_eq(hash128(h1), hash128(h2))
  assert_false(recorded_query_validates([h1], [h2]))
  // Nested: in an array, and captured by closures created anew.
  let node = @syntax.parse_code("x")
  let nested = (h : HostFunc) => {
    content(
      Array(Arr::from_array([test_closure(node, Func(Func::host(h))), Int(1)])),
    )
  }
  assert_true(recorded_query_validates([nested(host)], [nested(host)]))
  assert_false(
    recorded_query_validates([nested(host)], [
      nested(HostFunc::new(hash128("h"), call)),
    ]),
  )
  // Closures created anew with equal captures converge, as before (they
  // are validated by their structural fingerprint).
  assert_true(
    recorded_query_validates([content(test_closure(node, Int(1)))], [
      content(test_closure(node, Int(1))),
    ]),
  )
}

///|
test "validation: host closures fingerprinted while a read is replayed are not collected" {
  // A query for the elements whose field is a host closure: the selector
  // holds the closure, and so does the result. Recording collects the
  // closures of the result; the replay fingerprints the selector first.
  let call : NativeFn = (_, _, _) => None
  let host = HostFunc::new(hash128("h"), call)
  let elem = TextElem::packed("x").elem()
  let content = () => {
    Content::from_fields(elem, [Some(Value::Func(Func::host(host)))])
  }
  let selector = Selector::Elem(elem, Some([(0, Func(Func::host(host)))]))
  let validates = (before : Array[Content], after : Array[Content]) => {
    let recorder = IntrospectionRecorder::new()
    let tracked = Introspector::new(FixedBackend(before)).track_with(recorder)
    tracked.query(selector) |> ignore
    recorder.validate(Introspector::new(FixedBackend(after)))
  }
  assert_true(validates([content()], [content()]))
  assert_true(validates([content(), content()], [content(), content()]))
  // Another closure with the same key still does not validate.
  let other = Content::from_fields(elem, [
    Some(Value::Func(Func::host(HostFunc::new(hash128("h"), call)))),
  ])
  assert_false(validates([content()], [other]))
  // An armed collector does not outlive the validation.
  assert_true(fingerprint_output_hosts.val is None)
}
