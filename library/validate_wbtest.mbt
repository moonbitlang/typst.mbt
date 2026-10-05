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

///|
/// A module `outer` whose scope binds `inner` to the given module.
fn test_outer_module(inner : Module) -> Value {
  let scope = Scope::new()
  scope.define("inner", Module(inner)) |> ignore
  Module(Module::new("outer", scope))
}

///|
/// A module `inner` binding `x` to the value.
fn test_inner_module(value : Value) -> Module {
  let scope = Scope::new()
  scope.define("x", value) |> ignore
  Module::new("inner", scope)
}

///|
test "validation: nested modules are flagged and compared by identity" {
  // The fingerprint of a module does not cover the contents of nested
  // modules: differences hidden there (here: a host closure) leave the
  // fingerprint equal, so the fingerprint must be flagged, or the exact
  // comparison would never run.
  let call : NativeFn = (_, _, _) => None
  let f = Value::Func(Func::host(HostFunc::new(hash128("f"), call)))
  let g = Value::Func(Func::host(HostFunc::new(hash128("g"), call)))
  let inner_f = test_inner_module(f)
  let inner_g = test_inner_module(g)
  let a = test_outer_module(inner_f)
  let b = test_outer_module(inner_g)
  assert_eq(hash128(a), hash128(b))
  let flags = fingerprint_flags_in(() => SipHasher128::new().write(a))
  assert_true((flags & fingerprint_lossy) != 0)
  assert_true((flags & fingerprint_identity) != 0)
  assert_false(values_validate_equal(a, b))
  // The same nested module in outer modules created anew.
  assert_true(values_validate_equal(a, test_outer_module(inner_f)))
  // Also when the outer module is captured by closures created anew.
  let node = @syntax.parse_code("x")
  assert_false(
    values_validate_equal(test_closure(node, a), test_closure(node, b)),
  )
  // A module without nested modules is fingerprinted completely.
  let plain = Value::Module(test_inner_module(Int(1)))
  assert_eq(fingerprint_flags_in(() => SipHasher128::new().write(plain)), 0)
  // In content, as a recorded query result would hold it.
  let elem = TextElem::packed("x").elem()
  let content_a = Content::from_fields(elem, [Some(a)])
  let content_b = Content::from_fields(elem, [Some(b)])
  assert_eq(hash128(content_a), hash128(content_b))
  assert_false(contents_validate_equal(Some(content_a), Some(content_b)))
}

///|
test "validation: modules that contain themselves terminate" {
  // A host can build a module whose scope binds the module itself.
  let cyclic = () => {
    let scope = Scope::new()
    let module_ = Module::new("m", scope)
    scope.define("me", Module(module_)) |> ignore
    scope.define("x", Int(1)) |> ignore
    module_
  }
  let a = cyclic()
  let b = cyclic()
  // The same graph validates; two separately built graphs are compared
  // without recursion into the nested (here: the same) modules.
  assert_true(values_validate_equal(Module(a), Module(a)))
  assert_false(values_validate_equal(Module(a), Module(b)))
  assert_eq(hash128(Value::Module(a)), hash128(Value::Module(b)))
}

///|
test "validation: resolved grids compare the strokes of explicit lines exactly" {
  let grid = (stop : Double) => {
    guard test_gradient(stop) is Gradient(gradient)
    let stroke : ResolvedStroke = {
      paint: Custom(Gradient(gradient)),
      thickness: Auto,
      cap: Auto,
      join: Auto,
      dash: Auto,
      miter_limit: Auto,
    }
    let line : Line = {
      index: 0,
      start: 0,
      end: None,
      stroke: Some(stroke),
      position: Before,
    }
    Value::Dyn(
      CellGrid(
        CellGrid::new_internal(
          Axes::new([], []),
          Axes::new([], []),
          [[line]],
          [],
          [],
          None,
          [],
        ),
      ),
    )
  }
  // Grids that differ only in the paint of an explicit line, by gradients
  // with equal fingerprints.
  let a = grid(0.5000000001)
  let b = grid(0.5000000002)
  assert_eq(hash128(a), hash128(b))
  assert_false(values_validate_equal(a, b))
  assert_true(values_validate_equal(a, grid(0.5000000001)))
}
