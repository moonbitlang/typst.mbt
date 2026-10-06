// The twins of `@kit.Canvas` on input that the element and its items
// reject (`kit_wbtest.mbt` says why): the Typst functions and the items
// are given the same wrong numbers and have to say the same.

///|
/// The message of the first error of the Typst source `call` after the
/// definitions of the functions; `""` if it compiles.
fn canvas_error(call : String) -> String {
  first_error(Document([Markup(canvas_typ + call)]))
}

///|
test "canvas: the functions reject what the element and its items reject, in their words" {
  let nan = 0.0 / 0.0
  let inf = 1.0 / 0.0
  let to : Array[@kit.Segment] = [LineTo((9.0, 9.0))]
  // The call of the function, and the element or the item with the same
  // arguments.
  let cases : Array[(String, String, &@doc.IntoContent)] = [
    (
      "a width that is not a number",
      "#canvas(float.nan, 20)",
      @kit.Canvas(nan, 20.0, []),
    ),
    ("a negative width", "#canvas(-1, 20)", @kit.Canvas(-1.0, 20.0, [])),
    (
      "a height without an end",
      "#canvas(20, float.inf)",
      @kit.Canvas(20.0, inf, []),
    ),
    ("a negative height", "#canvas(20, -0.5)", @kit.Canvas(20.0, -0.5, [])),
    (
      "a point of `place`",
      "#canvas-place((float.nan, 0))[x]",
      @kit.Canvas::place((nan, 0.0), "x"),
    ),
    (
      "the start of a line",
      "#canvas-line((0, float.inf), (1, 1))",
      @kit.Canvas::line((0.0, inf), (1.0, 1.0)),
    ),
    (
      "the end of a line",
      "#canvas-line((0, 0), (float.nan, 1))",
      @kit.Canvas::line((0.0, 0.0), (nan, 1.0)),
    ),
    (
      "the corner of a rectangle",
      "#canvas-rect((0, float.nan), 1, 1)",
      @kit.Canvas::rect((0.0, nan), 1.0, 1.0),
    ),
    (
      "the width of a rectangle",
      "#canvas-rect((0, 0), float.nan, 1)",
      @kit.Canvas::rect((0.0, 0.0), nan, 1.0),
    ),
    (
      "the height of a rectangle",
      "#canvas-rect((0, 0), 1, -float.inf)",
      @kit.Canvas::rect((0.0, 0.0), 1.0, -inf),
    ),
    (
      "the centre of a circle",
      "#canvas-circle((float.nan, 0), 1)",
      @kit.Canvas::circle((nan, 0.0), 1.0),
    ),
    (
      "the radius of a circle",
      "#canvas-circle((0, 0), float.inf)",
      @kit.Canvas::circle((0.0, 0.0), inf),
    ),
    (
      "the start of a curve",
      "#canvas-curve((float.nan, 0), ((\"line\", (9, 9)),))",
      @kit.Canvas::curve((nan, 0.0), to),
    ),
    (
      "a control point of a curve",
      "#canvas-curve((0, 0), ((\"quad\", (1, float.nan), (9, 9)),))",
      @kit.Canvas::curve((0.0, 0.0), [QuadTo((1.0, nan), (9.0, 9.0))]),
    ),
    (
      "the start of an arrow",
      "#canvas-arrow((0, float.inf), ((\"line\", (9, 9)),))",
      @kit.Canvas::arrow((0.0, inf), to),
    ),
    (
      "a point of an arrow",
      "#canvas-arrow((0, 0), ((\"cubic\", (1, 1), (2, 2), (float.nan, 9)),))",
      @kit.Canvas::arrow((0.0, 0.0), [
        CubicTo((1.0, 1.0), (2.0, 2.0), (nan, 9.0)),
      ]),
    ),
    (
      "an arrow without a segment",
      "#canvas-arrow((0, 0), ())",
      @kit.Canvas::arrow((0.0, 0.0), []),
    ),
    (
      "an arrow to where it starts",
      "#canvas-arrow((3, 4), ((\"line\", (3, 4)),))",
      @kit.Canvas::arrow((3.0, 4.0), [LineTo((3.0, 4.0))]),
    ),
    (
      "an arrow whose last curve is a point",
      "#canvas-arrow((0, 0), ((\"line\", (3, 4)), (\"cubic\", (3, 4), (3, 4), (3, 4))))",
      @kit.Canvas::arrow((0.0, 0.0), [
        LineTo((3.0, 4.0)),
        CubicTo((3.0, 4.0), (3.0, 4.0), (3.0, 4.0)),
      ]),
    ),
    (
      "a negative head",
      "#canvas-arrow((0, 0), ((\"line\", (9, 9)),), head: -1)",
      @kit.Canvas::arrow((0.0, 0.0), to, head=-1.0),
    ),
    (
      "a head that is not a number",
      "#canvas-arrow((0, 0), ((\"line\", (9, 9)),), head: float.nan)",
      @kit.Canvas::arrow((0.0, 0.0), to, head=nan),
    ),
  ]
  let messages : Array[String] = []
  for entry in cases {
    let (name, call, element) = entry
    let message = first_error(Document([element]))
    assert_true(message != "")
    // (Typst's `assert` puts its own words before the message.)
    assert_eq(canvas_error(call), "assertion failed: " + message)
    messages.push("\{name}: \{message}")
  }
  inspect(
    messages.join("\n"),
    content=(
      #|a width that is not a number: the `width` of a `Canvas` must be a finite number of points that is not negative
      #|a negative width: the `width` of a `Canvas` must be a finite number of points that is not negative
      #|a height without an end: the `height` of a `Canvas` must be a finite number of points that is not negative
      #|a negative height: the `height` of a `Canvas` must be a finite number of points that is not negative
      #|a point of `place`: the coordinates of `Canvas::place` must be finite numbers of points
      #|the start of a line: the coordinates of `Canvas::line` must be finite numbers of points
      #|the end of a line: the coordinates of `Canvas::line` must be finite numbers of points
      #|the corner of a rectangle: the coordinates of `Canvas::rect` must be finite numbers of points
      #|the width of a rectangle: the sizes of `Canvas::rect` must be finite numbers of points
      #|the height of a rectangle: the sizes of `Canvas::rect` must be finite numbers of points
      #|the centre of a circle: the coordinates of `Canvas::circle` must be finite numbers of points
      #|the radius of a circle: the sizes of `Canvas::circle` must be finite numbers of points
      #|the start of a curve: the coordinates of `Canvas::curve` must be finite numbers of points
      #|a control point of a curve: the coordinates of `Canvas::curve` must be finite numbers of points
      #|the start of an arrow: the coordinates of `Canvas::arrow` must be finite numbers of points
      #|a point of an arrow: the coordinates of `Canvas::arrow` must be finite numbers of points
      #|an arrow without a segment: `Canvas::arrow` needs a segment: a path from `start` to where the arrow points
      #|an arrow to where it starts: the last segment of `Canvas::arrow` ends where it starts: the arrow has no direction
      #|an arrow whose last curve is a point: the last segment of `Canvas::arrow` ends where it starts: the arrow has no direction
      #|a negative head: the `head` of `Canvas::arrow` must be a finite number of points that is not negative
      #|a head that is not a number: the `head` of `Canvas::arrow` must be a finite number of points that is not negative
    ),
  )
  // And both take what is at the edge of that: a canvas without a size, a
  // head without one, a curve whose last control point is its end.
  let fits = "#canvas(0, 0, canvas-arrow((0, 0), ((\"line\", (9, 9)),), head: 0), canvas-arrow((0, 0), ((\"cubic\", (5, 0), (9, 9), (9, 9)),)))"
  assert_eq(canvas_error(fits), "")
  assert_eq(
    first_error(
      Document([
        @kit.Canvas(0.0, 0.0, [
          @kit.Canvas::arrow((0.0, 0.0), to, head=0.0),
          @kit.Canvas::arrow((0.0, 0.0), [
            CubicTo((5.0, 0.0), (9.0, 9.0), (9.0, 9.0)),
          ]),
        ]),
      ]),
    ),
    "",
  )
}
