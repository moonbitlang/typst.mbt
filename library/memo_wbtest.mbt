///|
fn test_gradient(stop : Double) -> Value {
  Gradient(
    Linear({
      stops: [(color_black, Ratio::new(stop)), (color_black, Ratio::one())],
      angle: Angle::zero(),
      space: Process(Srgb),
      relative: Auto,
      anti_alias: true,
    }),
  )
}

///|
/// A value whose fingerprint does not capture its data (only its parity).
priv struct LossyValue(Int)

///|
impl Fingerprint for LossyValue with fn fingerprint(self, state) {
  state.write_discriminant(self.0 % 2)
  mark_fingerprint_lossy()
}

///|
test "memo: fingerprint flags are detected and inputs compared exactly" {
  let plain = TextElem::packed("x")
  let elem = plain.elem()
  // Two gradients whose reprs agree: their fingerprints are exact (upstream
  // hashes the stops), and so is the comparison of memoized inputs.
  let a = Content::from_fields(elem, [Some(test_gradient(0.5000000001))])
  let b = Content::from_fields(elem, [Some(test_gradient(0.5000000002))])
  assert_eq(
    test_gradient(0.5000000001).repr(),
    test_gradient(0.5000000002).repr(),
  )
  assert_false(hash128(a) == hash128(b))
  assert_false(content_memo_equal(a, b))
  assert_true(content_memo_equal(a, a))
  assert_eq(fingerprint_flags_in(() => SipHasher128::new().write(a)), 0)

  // A fingerprint that marks itself lossy is detected, also through nesting.
  assert_false(fingerprint_lossy_in(() => SipHasher128::new().write(plain)))
  assert_true(
    fingerprint_lossy_in(() => SipHasher128::new().write(LossyValue(1))),
  )
  assert_true(
    fingerprint_lossy_in(() => SipHasher128::new().write([Some(LossyValue(1))])),
  )
  let has_identity = (content : Content) => {
    let flags = fingerprint_flags_in(() => SipHasher128::new().write(content))
    (flags & fingerprint_identity) != 0
  }
  // Flags are kept through cached data hashes and nesting (a host closure
  // compares by identity), also when a closure captured the value.
  let call : NativeFn = (_, _, _) => None
  let host = Value::Func(Func::host(HostFunc::new(hash128("memo"), call)))
  let closure = Content::from_fields(elem, [
    Some(test_closure(@syntax.parse_code("x"), host)),
  ])
  assert_false(
    has_identity(
      Content::from_fields(elem, [
        Some(test_closure(@syntax.parse_code("x"), Int(1))),
      ]),
    ),
  )
  assert_false(has_identity(plain))
  for _ in 0..<2 {
    assert_true(has_identity(closure))
  }
  let outer = Content::from_fields(elem, [Some(Content(closure))])
  for _ in 0..<2 {
    assert_true(has_identity(outer))
  }
  // The flag of an enclosing computation is kept.
  let mut inner_lossy = false
  let outer_lossy = fingerprint_lossy_in(() => {
    inner_lossy = fingerprint_lossy_in(() => {
      SipHasher128::new().write(LossyValue(1))
    })
    SipHasher128::new().write(plain)
  })
  assert_true(inner_lossy)
  assert_true(outer_lossy)

  // Style chains are compared link by link, with exact values.
  let chain = (v : Value) => {
    StyleChain::empty()
    .chain(
      Styles::from_array([
        Property(Property::new(text_elem(), text_elem_fill, v)),
      ]),
    )
    .chain(Styles::from_array([TextElem::set_fallback(false)]))
  }
  assert_true(
    chain_memo_equal(chain(test_gradient(0.25)), chain(test_gradient(0.25))),
  )
  assert_false(
    chain_memo_equal(
      chain(test_gradient(0.5000000001)),
      chain(test_gradient(0.5000000002)),
    ),
  )
}
