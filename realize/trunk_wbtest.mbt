///|
test "trunk over three chains" {
  let base = StyleChain::empty()
  let a = base.chain(Styles::from_array([Revocation(1)]))
  let b = a.chain(Styles::from_array([Revocation(2)]))
  let c = a.chain(Styles::from_array([Revocation(3)]))
  let d = a.chain(Styles::from_array([Revocation(4)]))
  let t = StyleChain::trunk([b, c, d].iter()).unwrap()
  assert_true(t == a)
  let t2 = StyleChain::trunk([b, b, b].iter()).unwrap()
  assert_true(t2 == b)
  let t3 = StyleChain::trunk([b, b, c].iter()).unwrap()
  assert_true(t3 == a)
  let t4 = StyleChain::trunk([b, c].iter()).unwrap()
  assert_true(t4 == a)
  let t5 = StyleChain::trunk([b, b, b, c].iter()).unwrap()
  assert_true(t5 == a)
}
