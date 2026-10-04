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
test "memo: lossy fingerprints are detected and inputs compared exactly" {
  let plain = TextElem::packed("x")
  let elem = plain.elem()
  // Two gradients whose reprs (and thus fingerprints) agree.
  let a = Content::from_fields(elem, [Some(test_gradient(0.5000000001))])
  let b = Content::from_fields(elem, [Some(test_gradient(0.5000000002))])
  assert_eq(hash128(a), hash128(b))
  assert_false(content_memo_equal(a, b))
  assert_true(content_memo_equal(a, a))

  // Lossiness is detected, also through cached data hashes and nesting.
  assert_false(fingerprint_lossy_in(() => SipHasher128::new().write(plain)))
  for _ in 0..<2 {
    assert_true(fingerprint_lossy_in(() => SipHasher128::new().write(a)))
  }
  let outer = Content::from_fields(elem, [Some(Content(a))])
  for _ in 0..<2 {
    assert_true(fingerprint_lossy_in(() => SipHasher128::new().write(outer)))
  }
  // The flag of an enclosing computation is kept.
  let mut inner_lossy = false
  let outer_lossy = fingerprint_lossy_in(() => {
    inner_lossy = fingerprint_lossy_in(() => SipHasher128::new().write(a))
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
