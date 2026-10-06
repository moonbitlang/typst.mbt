// The head of an arrow (`arrow_head`, `arriving_from`, `Segment::ending_at`
// of `canvas.mbt`) on numbers that no page has: `canvas_test.mbt` reads
// the heads of drawn arrows from the frames.

///|
/// Whether two numbers are equal but for the rounding of a few operations,
/// relative to their size.
fn near(a : Double, b : Double) -> Bool {
  let size = if a.abs() > b.abs() { a.abs() } else { b.abs() }
  (a - b).abs() <= 1.0e-12 * size
}

///|
test "arrow_head: a direction for every difference that is a number" {
  // A path that arrives in the direction (3, 4) / 5, by differences whose
  // squares are not numbers: too small, and too large. The head is as
  // long as the difference, so that its corners are numbers of that size:
  // the base is at the point that the path comes from, `size` across.
  for scale in [1.0, 1.0e-200, 1.0e200] {
    let tip = (3.0 * scale, 4.0 * scale)
    guard arrow_head((0.0, 0.0), tip, 5.0 * scale) is Some(head) else {
      fail("no head at the scale \{scale}")
    }
    assert_true(near(head.tip.0, tip.0) && near(head.tip.1, tip.1))
    // The corners: the origin, 2.5 to each side across (0.6, 0.8).
    assert_true(near(head.left.0, -2.0 * scale))
    assert_true(near(head.left.1, 1.5 * scale))
    assert_true(near(head.right.0, 2.0 * scale))
    assert_true(near(head.right.1, -1.5 * scale))
    // The path ends in the middle of the head.
    assert_true(near(head.end.0, 1.5 * scale))
    assert_true(near(head.end.1, 2.0 * scale))
  }
  // No direction: the same point, and two points whose difference is not
  // a number.
  assert_true(arrow_head((7.0, 7.0), (7.0, 7.0), 5.0) is None)
  assert_true(arrow_head((-1.0e308, 0.0), (1.0e308, 0.0), 5.0) is None)
  assert_true(arrow_head((0.0, 1.0e308), (0.0, -1.0e308), 5.0) is None)
}

///|
test "arriving_from: the last point of the last segment that is not its end" {
  let from = (segment : Segment) => {
    match arriving_from((1.0, 1.0), segment) {
      Some(point) => "\{point.0}, \{point.1}"
      None => "none"
    }
  }
  inspect(from(LineTo((5.0, 5.0))), content="1, 1")
  inspect(from(QuadTo((2.0, 3.0), (5.0, 5.0))), content="2, 3")
  inspect(from(QuadTo((5.0, 5.0), (5.0, 5.0))), content="1, 1")
  inspect(from(CubicTo((2.0, 3.0), (4.0, 4.0), (5.0, 5.0))), content="4, 4")
  inspect(from(CubicTo((2.0, 3.0), (5.0, 5.0), (5.0, 5.0))), content="2, 3")
  inspect(from(CubicTo((5.0, 5.0), (5.0, 5.0), (5.0, 5.0))), content="1, 1")
  inspect(from(LineTo((1.0, 1.0))), content="none")
  inspect(from(CubicTo((1.0, 1.0), (1.0, 1.0), (1.0, 1.0))), content="none")
}

///|
test "ending_at: the control points at the end move with it" {
  let moved = (segment : Segment) => {
    segment
    .ending_at((9.0, 9.0))
    .points()
    .map(point => "\{point.0}, \{point.1}")
    .join(" | ")
  }
  inspect(moved(LineTo((5.0, 5.0))), content="9, 9")
  inspect(moved(QuadTo((2.0, 3.0), (5.0, 5.0))), content="2, 3 | 9, 9")
  inspect(moved(QuadTo((5.0, 5.0), (5.0, 5.0))), content="9, 9 | 9, 9")
  inspect(
    moved(CubicTo((2.0, 3.0), (4.0, 4.0), (5.0, 5.0))),
    content="2, 3 | 4, 4 | 9, 9",
  )
  inspect(
    moved(CubicTo((2.0, 3.0), (5.0, 5.0), (5.0, 5.0))),
    content="2, 3 | 9, 9 | 9, 9",
  )
  inspect(
    moved(CubicTo((5.0, 5.0), (5.0, 5.0), (5.0, 5.0))),
    content="9, 9 | 9, 9 | 9, 9",
  )
  // (A first control point at the end with a second that is not: it is
  // where the curve leaves for, not where it arrives from, and stays.)
  inspect(
    moved(CubicTo((5.0, 5.0), (4.0, 4.0), (5.0, 5.0))),
    content="5, 5 | 4, 4 | 9, 9",
  )
}
