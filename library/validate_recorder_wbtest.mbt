// Tests of `IntrospectionRecorder::validate` with recorded results whose
// fingerprints hide differences (see `validate_wbtest.mbt`).

///|
/// An introspector backend whose labelled elements are fixed.
priv struct FixedBackend(Array[Content])

///|
impl IntrospectorBackend for FixedBackend with fn query(_, _) {
  []
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
test "validation: recorded queries see differences that fingerprints hide" {
  let elem = TextElem::packed("x").elem()
  let content = (value : Value) => Content::from_fields(elem, [Some(value)])
  // Plain results: validated by fingerprint, as before.
  assert_true(recorded_query_validates([content(Int(1))], [content(Int(1))]))
  assert_false(recorded_query_validates([content(Int(1))], [content(Int(2))]))
  // Gradients with equal fingerprints.
  let g1 = content(test_gradient(0.5000000001))
  let g2 = content(test_gradient(0.5000000002))
  assert_eq(hash128(g1), hash128(g2))
  assert_true(recorded_query_validates([g1], [g1]))
  assert_false(recorded_query_validates([g1], [g2]))
  // Differences hidden inside nested modules.
  let call : NativeFn = (_, _, _) => None
  let f = Value::Func(Func::host(HostFunc::new(hash128("f"), call)))
  let g = Value::Func(Func::host(HostFunc::new(hash128("g"), call)))
  let inner_f = test_inner_module(f)
  let m1 = content(test_outer_module(inner_f))
  let m2 = content(test_outer_module(test_inner_module(g)))
  assert_eq(hash128(m1), hash128(m2))
  assert_false(recorded_query_validates([m1], [m2]))
  assert_true(
    recorded_query_validates([m1], [content(test_outer_module(inner_f))]),
  )
  // Host closures: the same function converges, another one does not, also
  // with the same key.
  let host = HostFunc::new(hash128("h"), call)
  let h1 = content(Func(Func::host(host)))
  let h2 = content(Func(Func::host(HostFunc::new(hash128("h"), call))))
  assert_eq(hash128(h1), hash128(h2))
  assert_true(recorded_query_validates([h1], [content(Func(Func::host(host)))]))
  assert_false(recorded_query_validates([h1], [h2]))
  // Closures created anew with equal captures converge.
  let node = @syntax.parse_code("x")
  assert_true(
    recorded_query_validates([content(test_closure(node, Int(1)))], [
      content(test_closure(node, Int(1))),
    ]),
  )
  assert_false(
    recorded_query_validates(
      [content(test_closure(node, test_gradient(0.5000000001)))],
      [content(test_closure(node, test_gradient(0.5000000002)))],
    ),
  )
}
