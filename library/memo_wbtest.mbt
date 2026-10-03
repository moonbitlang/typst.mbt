///|
fn test_gradient(blue : Int) -> Value {
  Gradient(
    Linear({
      stops: [
        (color_black, Ratio::new(0.0)),
        (Color::from_u8(0, 0, blue, 255), Ratio::one()),
      ],
      angle: Angle::zero(),
      space: Process(Srgb),
      relative: Auto,
      anti_alias: true,
    }),
  )
}

///|
test "memo keys refuse lossy fingerprints" {
  // Plain content and styles give keys.
  let plain = TextElem::packed("x")
  let styles = StyleChain::empty().chain(
    Styles::from_array([TextElem::set_fallback(false)]),
  )
  assert_true(
    memo_fingerprint(state => {
      state.write(plain)
      state.write_u128(styles.memo_hash())
    })
    is Some(_),
  )

  // Gradients are fingerprinted through their repr: content holding one
  // gives no key, also when its (cached) data hash is reused.
  let elem = plain.elem()
  let with_gradient = Content::from_fields(elem, [Some(test_gradient(255))])
  for _ in 0..<2 {
    assert_true(memo_fingerprint(state => state.write(with_gradient)) is None)
  }
  // Nested in other content.
  let outer = Content::from_fields(elem, [Some(Content(with_gradient))])
  for _ in 0..<2 {
    assert_true(memo_fingerprint(state => state.write(outer)) is None)
  }

  // A style chain with a gradient in an outer link (its hash is cached per
  // link, the lossiness too).
  let lossy_styles = StyleChain::empty()
    .chain(
      Styles::from_array([
        Property(Property::new(text_elem(), text_elem_fill, test_gradient(254))),
      ]),
    )
    .chain(Styles::from_array([TextElem::set_fallback(false)]))
  for _ in 0..<2 {
    assert_true(
      memo_fingerprint(state => state.write_u128(lossy_styles.memo_hash()))
      is None,
    )
  }

  // The flag of an enclosing computation is kept.
  let mut inner_lossy = false
  let outer_lossy = fingerprint_lossy_in(() => {
    inner_lossy = fingerprint_lossy_in(() => {
      SipHasher128::new().write(with_gradient)
    })
    SipHasher128::new().write(plain)
  })
  assert_true(inner_lossy)
  assert_true(outer_lossy)
}
