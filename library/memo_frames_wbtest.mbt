// What the store of layouts keeps is not what a caller has ([memoize],
// `copy`): the frames of a result are kept as copy-on-write clones and
// handed out as clones, so whoever gets them may do to them what the
// engine does to frames (`frame.mbt`: move them into other frames, resize
// and translate them, hide or empty them). The blocks of a flow are laid
// out through this store since slice 2 of `docs/incremental-design.md`;
// their callers clone once more (`CachedCell` in `layout/flow_collect.mbt`),
// so the rule is tested here, at the store.

///|
/// A frame with a shape and a group that holds another shape.
fn frames_test_frame() -> Frame {
  let size = Axes::new(Abs::pt(20.0), Abs::pt(10.0))
  let inner = Frame::hard(size)
  inner.push(
    Point::new(Abs::pt(1.0), Abs::pt(2.0)),
    Shape(
      Geometry::Rect(size).filled(Solid(color_black)),
      @syntax.Span::detached(),
    ),
  )
  let frame = Frame::soft(size)
  frame.push(
    Point::zero(),
    Shape(
      Geometry::Rect(size).filled(Solid(color_white)),
      @syntax.Span::detached(),
    ),
  )
  frame.push(
    Point::new(Abs::pt(3.0), Abs::pt(4.0)),
    Group(GroupItem::new(inner)),
  )
  frame
}

///|
/// Everything a caller does to a frame it was handed.
fn frames_test_scribble(frame : Frame) -> Unit {
  frame.translate(Point::new(Abs::pt(7.0), Abs::pt(9.0)))
  frame.set_size(Axes::new(Abs::pt(1.0), Abs::pt(1.0)))
  frame.set_baseline(Abs::pt(1.0))
  frame.push(
    Point::zero(),
    Shape(
      Geometry::Rect(Axes::new(Abs::pt(1.0), Abs::pt(1.0))).filled(
        Solid(color_black),
      ),
      @syntax.Span::detached(),
    ),
  )
  frame.hide()
  frame.clear()
}

///|
test "owned: the frames of a kept layout are not the caller's" {
  memo_test_begin()
  defer memo_test_end()
  let content = TextElem::packed("x")
  let styles = StyleChain::empty()
  let key = memo_fingerprint(state => state.write_str("owned frames"))
  let expected = hash128(frames_test_frame())
  let mut runs = 0
  for _ in 0..<4 {
    let engine = memo_engine()
    let fragment = memoized_layout(engine, key, content, styles, None, _ => {
      runs += 1
      Fragment([frames_test_frame(), frames_test_frame()])
    })
    // What is handed out is the layout as it was made, whatever the callers
    // before did to what they were handed: the one that computed it (the
    // store keeps a copy) and those that found it (each gets a copy).
    let frames = fragment.into_frames()
    assert_eq(frames.length(), 2)
    for frame in frames {
      assert_eq(hash128(frame), expected)
      frames_test_scribble(frame)
      assert_false(hash128(frame) == expected)
    }
  }
  assert_eq(runs, 1)
}
