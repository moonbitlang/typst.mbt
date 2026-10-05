// Tests of the exact validation of recorded introspector reads
// (`values_validate_equal`, see `IntrospectionRecorder::validate`) and of
// host closures.

///|
/// A closure over `node` capturing `x = value`.
fn test_closure(node : @syntax.SyntaxNode, value : Value) -> Value {
  let captured = Scope::new()
  captured.define("x", value) |> ignore
  Func(
    Func::closure({
      node: Context(node),
      defaults: [],
      captured,
      num_pos_params: 0,
    }),
  )
}

///|
test "validation: closures are compared by code and captures, not by fingerprint" {
  let node = @syntax.parse_code("x")
  // Created anew with equal captures: equal for validation, though not the
  // same closure (and thus unequal as memo input).
  let a = test_closure(node, test_gradient(0.25))
  let b = test_closure(node, test_gradient(0.25))
  assert_false(a == b)
  assert_false(values_memo_equal(a, b))
  assert_true(values_validate_equal(a, b))

  // Two gradients with equal fingerprints as captures: the closures'
  // fingerprints agree, validation tells them apart.
  let c = test_closure(node, test_gradient(0.5000000001))
  let d = test_closure(node, test_gradient(0.5000000002))
  assert_eq(hash128(c), hash128(d))
  assert_false(values_validate_equal(c, d))

  // Also through nesting: a closure capturing a closure, inside content.
  let outer_c = test_closure(node, c)
  let outer_d = test_closure(node, d)
  assert_eq(hash128(outer_c), hash128(outer_d))
  assert_false(values_validate_equal(outer_c, outer_d))
  let elem = TextElem::packed("x").elem()
  let content_c = Value::Content(Content::from_fields(elem, [Some(outer_c)]))
  let content_d = Value::Content(Content::from_fields(elem, [Some(outer_d)]))
  assert_false(values_validate_equal(content_c, content_d))
  assert_true(values_validate_equal(content_c, content_c))

  // Different code.
  let other = test_closure(@syntax.parse_code("y"), test_gradient(0.25))
  assert_false(values_validate_equal(a, other))
}

///|
test "validation: host closures are compared by identity" {
  let call : NativeFn = (_, _, _) => None
  let key = hash128("key")
  let f = HostFunc::new(key, call)
  let g = HostFunc::new(key, call)
  let a = Value::Func(Func::host(f))
  // The same host function, also when captured by closures created anew.
  assert_true(values_validate_equal(a, Value::Func(Func::host(f))))
  let node = @syntax.parse_code("x")
  assert_true(
    values_validate_equal(test_closure(node, a), test_closure(node, a)),
  )
  // Another host function with the same key and thus the same fingerprint.
  let b = Value::Func(Func::host(g))
  assert_eq(hash128(a), hash128(b))
  assert_false(a == b)
  assert_false(values_validate_equal(a, b))
  assert_false(
    values_validate_equal(test_closure(node, a), test_closure(node, b)),
  )
  // The fingerprint is identity-bearing, like a closure's.
  let flags = fingerprint_flags_in(() => SipHasher128::new().write(a))
  assert_true((flags & fingerprint_identity) != 0)
  assert_eq(Func::host(f).repr(), "(..) => ..")
}

///|
test "validation: a recorded read with a lossy result is validated exactly" {
  let elem = TextElem::packed("x").elem()
  let content = (stop : Double) => {
    Content::from_fields(elem, [Some(test_gradient(stop))])
  }
  // The recorded result and an equal recomputation validate.
  assert_true(contents_validate_equal(Some(content(0.25)), Some(content(0.25))))
  // Results with equal fingerprints but different data do not.
  let a = content(0.5000000001)
  let b = content(0.5000000002)
  assert_eq(hash128(a), hash128(b))
  assert_false(contents_validate_equal(Some(a), Some(b)))
  assert_false(content_arrays_validate_equal([a], [b]))
  assert_true(content_arrays_validate_equal([a, b], [a, b]))
  assert_false(contents_validate_equal(Some(a), None))
}
