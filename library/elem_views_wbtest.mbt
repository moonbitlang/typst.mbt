///|
test "typed element views" {
  let h = HeadingElem::new(TextElem::packed("Intro"))
  inspect(h.body().repr(), content="[Intro]")
  // Settable field: default, style and local value.
  let empty = StyleChain::empty()
  inspect(h.depth(empty).get(), content="1")
  let styles = StyleChain::new(
    Styles::from_array([HeadingElem::set_depth(NonZeroUSize(3L))]),
  )
  inspect(h.depth(styles).get(), content="3")
  inspect(HeadingElem::depth_in(styles).get(), content="3")
  inspect(h.depth_local() is None, content="true")
  let h2 = h.with_depth(NonZeroUSize(2L))
  inspect(h2.depth(styles).get(), content="2")
  inspect(h2.pack().repr(), content="heading(depth: 2, body: [Intro])")
  inspect(HeadingElem::of(h2.pack()) is Some(_), content="true")
  inspect(HeadingElem::of(TextElem::packed("x")) is Some(_), content="false")
}
