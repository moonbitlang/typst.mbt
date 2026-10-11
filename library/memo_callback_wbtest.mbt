// A layout callback as part of the key of a memoized layout
// (`BlockMultiCallback.typed` in `container.mbt`): upstream hashes the
// captured element and the function pointer; here a callback is its kind
// and its captured element, and a callback for plain content is not the
// callback that the show rule of that content's element makes.

///|
test "callbacks: a callback for plain content is not the one of its element's rule" {
  let fragment = Fragment::Fragment([
    Frame::soft(Axes::new(Abs::pt(1.0), Abs::pt(1.0))),
  ])
  let pad = PadElem::new(TextElem::packed("x"))
  let rule = () => {
    BlockElem::multi_layouter(pad, (_, _, _, _, _) => fragment).pack()
  }
  let host = () => {
    BlockElem::multi_layouter_content(pad.pack(), (_, _, _, _, _) => fragment).pack()
  }
  // Each is one block however often it is made.
  assert_eq(hash128(rule()), hash128(rule()))
  assert_true(content_memo_equal(rule(), rule()))
  assert_eq(hash128(host()), hash128(host()))
  assert_true(content_memo_equal(host(), host()))
  // The two capture the same element and are two blocks, to the key and to
  // the comparison of arguments (Typst's `==` compares the captured
  // content alone, like upstream's `PartialEq`).
  assert_true(rule() == host())
  assert_false(hash128(rule()) == hash128(host()))
  assert_false(content_memo_equal(rule(), host()))
  assert_false(content_memo_equal(host(), rule()))
}
