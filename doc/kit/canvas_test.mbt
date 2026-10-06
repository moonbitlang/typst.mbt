// `Canvas` (docs/edsl-ports.md, section 4; findings H6, S2a, M4 and T11):
// what it and its items expand to, where an anchored body is, the head of
// an arrow, what a canvas does at the end of a page, where it can be
// built, and the provenance of its items. The pairs with a Typst twin are
// in `doc/twins/kit.mbt`. The page is that of `cards_test.mbt`: 200pt by
// 120pt with 10pt margins and 10pt text. A canvas that is first on the
// page has its origin at (10, 10) of the page; `on_canvas` takes that off.

///|
using @doc {
  type Circle,
  type Curve,
  type CurveCubic,
  type CurveLine,
  type CurveMove,
  type CurveQuad,
  type Footnote,
  type Layout,
  type Line,
  type Linebreak,
  type Place,
  type Polygon,
  type Rect,
  type Scale,
  type SetCurve,
}

///|
/// A shape that is drawn: the points of its outline (for a
/// curve: its control points too), in points from the top left corner of
/// the page, its fill and its stroke as Typst prints them, and whether a
/// group around it clips.
priv struct Outline {
  points : Array[(Double, Double)]
  fill : String
  stroke : String
  dashed : Bool
  clipped : Bool
}

///|
fn collect_outlines(
  frame : @library.Frame,
  dx : Double,
  dy : Double,
  clipped : Bool,
  out : Array[Outline],
) -> Unit {
  for entry in frame.items() {
    let x = dx + entry.0.x.to_pt()
    let y = dy + entry.0.y.to_pt()
    match entry.1 {
      Group(group) =>
        collect_outlines(
          group.frame,
          x + group.transform.tx.to_pt(),
          y + group.transform.ty.to_pt(),
          clipped || group.clip is Some(_),
          out,
        )
      Shape(shape, _) => {
        let points : Array[(Double, Double)] = []
        let point = (p : @library.Point) => {
          points.push((x + p.x.to_pt(), y + p.y.to_pt()))
        }
        match shape.geometry {
          Rect(size) => {
            point(@library.Point::zero())
            point(@library.Point::new(size.x, size.y))
          }
          Line(to) => {
            point(@library.Point::zero())
            point(to)
          }
          Curve(curve) =>
            for item in curve.items() {
              match item {
                Move(p) | Line(p) => point(p)
                Cubic(p1, p2, p3) => {
                  point(p1)
                  point(p2)
                  point(p3)
                }
                Close => ()
              }
            }
        }
        out.push({
          points,
          fill: match shape.fill {
            Some(paint) => paint.repr()
            None => ""
          },
          stroke: match shape.stroke {
            Some(stroke) =>
              "\{pt(stroke.thickness.to_pt())} \{stroke.paint.repr()}"
            None => ""
          },
          dashed: match shape.stroke {
            Some(stroke) => stroke.dash is Some(_)
            None => false
          },
          clipped,
        })
      }
      _ => ()
    }
  }
}

///|
/// The shapes of a compiled document, in the order in which they are
/// drawn.
fn outlines(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> Array[Outline] raise {
  let out = []
  for page in report.unwrap().pages() {
    collect_outlines(page.frame, 0.0, 0.0, false, out)
  }
  out
}

///|
/// A point of the page as a point of a canvas that is first on the page.
fn on_canvas(point : (Double, Double)) -> (Double, Double) {
  (point.0 - 10.0, point.1 - 10.0)
}

///|
/// A number with two decimals.
fn hundredths(x : Double) -> String {
  @format.fixed(x, 2)
}

///|
/// Points, in the coordinates of the canvas.
fn points(all : Array[(Double, Double)]) -> String {
  all
  .map(p => {
    let (x, y) = on_canvas(p)
    "(\{hundredths(x)}, \{hundredths(y)})"
  })
  .join(" ")
}

///|
/// Whether two numbers are equal but for the rounding of a few operations.
fn close(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
/// A filled box of 20pt by 10pt: a body whose size is known.
fn slab() -> Rect {
  Rect(width=Pt(20), height=Pt(10), fill=Luma(200))
}

///|
/// The names of the anchors, for the listings.
let anchors_x : Array[(String, @kit.AnchorX, Double)] = [
  ("Left", Left, 0.0),
  ("Center", Center, 0.5),
  ("Right", Right, 1.0),
]

///|
let anchors_y : Array[(String, @kit.AnchorY, Double)] = [
  ("Top", Top, 0.0),
  ("Horizon", Horizon, 0.5),
  ("Bottom", Bottom, 1.0),
]

///|
test "canvas: an unbreakable block of its size around its items" {
  // The expansion. (`Keyed` does not change what is lowered.)
  assert_eq(
    lowered([@kit.Canvas(100.0, 60.0, ["plain", Emph("own")])]),
    lowered([
      Block(
        Seq(["plain", Emph("own")]),
        width=Pt(100),
        height=Pt(60),
        breakable=false,
      ),
    ]),
  )
  // `clip` is passed on; no items: the empty block.
  assert_eq(
    lowered([@kit.Canvas(100.0, 60.0, [], clip=true)]),
    lowered([
      Block(Seq([]), width=Pt(100), height=Pt(60), breakable=false, clip=true),
    ]),
  )
  // The items are the content that they expand to.
  assert_eq(
    lowered([
      @kit.Canvas(100.0, 60.0, [
        @kit.Canvas::line((0.0, 50.0), (100.0, 50.0)),
        @kit.Canvas::place((5.0, 5.0), "label"),
      ]),
    ]),
    lowered([
      Block(
        Seq([
          Place(
            Line(start=(Pt(0), Pt(50)), end_=(Pt(100), Pt(50))),
            alignment=Both(Left, Top),
          ),
          Place("label", alignment=Both(Left, Top), dx=Pt(5), dy=Pt(5)),
        ]),
        width=Pt(100),
        height=Pt(60),
        breakable=false,
      ),
    ]),
  )
  // It prints as its name around what it is made of.
  debug_inspect(
    @kit.Canvas(100.0, 60.0, [@kit.Canvas::place((5.0, 6.0), "label")]),
    content=(
      #|Canvas(
      #|  Block(
      #|    Seq(
      #|      [
      #|        Keyed(
      #|          "0",
      #|          Canvas::place(Place(add(left, top), "label", dx=5pt, dy=6pt)),
      #|        ),
      #|      ],
      #|    ),
      #|    width=100pt,
      #|    height=60pt,
      #|    breakable=false,
      #|  ),
      #|)
    ),
  )
}

///|
test "canvas items: what each expands to" {
  let pen = Stroke(paint=Blue, thickness=Pt(0.5))
  // `place`: the alignment that the anchor names, and the offset that
  // takes back the share of the container that the alignment added.
  assert_eq(
    lowered([@kit.Canvas::place((50.0, 30.0), "label")]),
    lowered([Place("label", alignment=Both(Left, Top), dx=Pt(50), dy=Pt(30))]),
  )
  assert_eq(
    lowered([
      @kit.Canvas::place((50.0, 30.0), "label", anchor=(Center, Horizon)),
    ]),
    lowered([
      Place(
        "label",
        alignment=Both(Center, Horizon),
        dx=Diff(Pt(50), Pct(50)),
        dy=Diff(Pt(30), Pct(50)),
      ),
    ]),
  )
  assert_eq(
    lowered([@kit.Canvas::place((50.0, 30.0), "label", anchor=(Right, Bottom))]),
    lowered([
      Place(
        "label",
        alignment=Both(Right, Bottom),
        dx=Diff(Pt(50), Pct(100)),
        dy=Diff(Pt(30), Pct(100)),
      ),
    ]),
  )
  // `line`: the points as they are given, placed at the origin.
  assert_eq(
    lowered([@kit.Canvas::line((1.5, 2.0), (30.0, 4.0), stroke=pen)]),
    lowered([
      Place(
        Line(start=(Pt(1.5), Pt(2)), end_=(Pt(30), Pt(4)), stroke=pen),
        alignment=Both(Left, Top),
      ),
    ]),
  )
  assert_eq(
    lowered([@kit.Canvas::line((1.5, 2.0), (30.0, 4.0))]),
    lowered([
      Place(
        Line(start=(Pt(1.5), Pt(2)), end_=(Pt(30), Pt(4))),
        alignment=Both(Left, Top),
      ),
    ]),
  )
  // `rect`: placed by its corner.
  assert_eq(
    lowered([
      @kit.Canvas::rect(
        (10.0, 20.0),
        30.0,
        12.0,
        fill=Red,
        stroke=Sides(all=pen),
        radius=round,
      ),
    ]),
    lowered([
      Place(
        Rect(
          width=Pt(30),
          height=Pt(12),
          fill=Red,
          stroke=Sides(all=pen),
          radius=round,
        ),
        alignment=Both(Left, Top),
        dx=Pt(10),
        dy=Pt(20),
      ),
    ]),
  )
  assert_eq(
    lowered([@kit.Canvas::rect((10.0, 20.0), 30.0, 12.0)]),
    lowered([
      Place(
        Rect(width=Pt(30), height=Pt(12)),
        alignment=Both(Left, Top),
        dx=Pt(10),
        dy=Pt(20),
      ),
    ]),
  )
  // `circle`: placed by the corner of the square around it.
  assert_eq(
    lowered([@kit.Canvas::circle((40.0, 30.0), 4.0, fill=Red, stroke=pen)]),
    lowered([
      Place(
        Circle(radius=Pt(4), fill=Red, stroke=pen),
        alignment=Both(Left, Top),
        dx=Pt(36),
        dy=Pt(26),
      ),
    ]),
  )
  // `curve`: the components of `Curve` that the segments name.
  assert_eq(
    lowered([
      @kit.Canvas::curve(
        (1.0, 2.0),
        [
          LineTo((3.0, 4.0)),
          QuadTo((5.0, 6.0), (7.0, 8.0)),
          CubicTo((9.0, 10.0), (11.0, 12.0), (13.0, 14.0)),
        ],
        fill=Red,
        stroke=pen,
      ),
    ]),
    lowered([
      Place(
        Curve(
          [
            CurveMove((Pt(1), Pt(2))),
            CurveLine((Pt(3), Pt(4))),
            CurveQuad((Pt(5), Pt(6)), (Pt(7), Pt(8))),
            CurveCubic((Pt(9), Pt(10)), (Pt(11), Pt(12)), (Pt(13), Pt(14))),
          ],
          fill=Red,
          stroke=pen,
        ),
        alignment=Both(Left, Top),
      ),
    ]),
  )
  // `arrow`: the curve, ending half the head before the tip, and the head
  // as a polygon in the paint of the stroke.
  assert_eq(
    lowered([
      @kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, 30.0))], stroke=pen),
    ]),
    lowered([
      Seq([
        Place(
          Curve(
            [CurveMove((Pt(10), Pt(30))), CurveLine((Pt(57.25), Pt(30)))],
            stroke=pen,
          ),
          alignment=Both(Left, Top),
        ),
        Place(
          Polygon(
            [(Pt(60), Pt(30)), (Pt(54.5), Pt(32.75)), (Pt(54.5), Pt(27.25))],
            fill=Blue,
          ),
          alignment=Both(Left, Top),
        ),
      ]),
    ]),
  )
  // Without a stroke: the curve's own, and a black head.
  assert_eq(
    lowered([@kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, 30.0))], head=4.0)]),
    lowered([
      Seq([
        Place(
          Curve([CurveMove((Pt(10), Pt(30))), CurveLine((Pt(58), Pt(30)))]),
          alignment=Both(Left, Top),
        ),
        Place(
          Polygon(
            [(Pt(60), Pt(30)), (Pt(56), Pt(32)), (Pt(56), Pt(28))],
            fill=Black,
          ),
          alignment=Both(Left, Top),
        ),
      ]),
    ]),
  )
  debug_inspect(
    @kit.Canvas::rect((10.0, 20.0), 30.0, 12.0, fill=Red),
    content=(
      #|Canvas::rect(
      #|  Place(
      #|    add(left, top),
      #|    Rect(width=30pt, height=12pt, fill=red),
      #|    dx=10pt,
      #|    dy=20pt,
      #|  ),
      #|)
    ),
  )
}

///|
test "canvas: the nine anchors put that side of the body at the point" {
  // A slab of 20pt by 10pt at (50, 30) of the canvas, by each anchor: its
  // corner is at `50 - 20 × side` and `30 - 10 × side`, the side being 0,
  // a half or 1.
  let lines : Array[String] = []
  for horizontal in anchors_x {
    for vertical in anchors_y {
      let report = compile([
        @kit.Canvas(100.0, 60.0, [
          @kit.Canvas::place(
            (50.0, 30.0),
            slab(),
            anchor=(horizontal.1, vertical.1),
          ),
        ]),
      ])
      assert_eq(errors(report) + warnings(report), "")
      let box = of_kind(drawn(report), "box")[0]
      let (x, y) = on_canvas((box.x, box.y))
      assert_true(close(x, 50.0 - 20.0 * horizontal.2))
      assert_true(close(y, 30.0 - 10.0 * vertical.2))
      lines.push(
        "\{horizontal.0}, \{vertical.0}: \{hundredths(x)}, \{hundredths(y)}",
      )
    }
  }
  inspect(
    lines.join("\n"),
    content=(
      #|Left, Top: 50.00, 30.00
      #|Left, Horizon: 50.00, 25.00
      #|Left, Bottom: 50.00, 20.00
      #|Center, Top: 40.00, 30.00
      #|Center, Horizon: 40.00, 25.00
      #|Center, Bottom: 40.00, 20.00
      #|Right, Top: 30.00, 30.00
      #|Right, Horizon: 30.00, 25.00
      #|Right, Bottom: 30.00, 20.00
    ),
  )
  // The same in a canvas of another size: the offsets do not depend on it.
  for size in [(100.0, 60.0), (37.0, 11.0), (180.0, 100.0)] {
    let report = compile([
      @kit.Canvas(size.0, size.1, [
        @kit.Canvas::place((50.0, 30.0), slab(), anchor=(Center, Horizon)),
        @kit.Canvas::place((50.0, 30.0), slab(), anchor=(Right, Bottom)),
      ]),
    ])
    let boxes = of_kind(drawn(report), "box")
    assert_true(
      close(boxes[0].x - 10.0, 40.0) && close(boxes[0].y - 10.0, 25.0),
    )
    assert_true(
      close(boxes[1].x - 10.0, 30.0) && close(boxes[1].y - 10.0, 20.0),
    )
  }
}

///|
test "canvas: a label by its anchors" {
  // A line of text is as high as its capitals (the default edges of text:
  // from the cap height to the baseline), so `Top` has its baseline that
  // far below the point, `Horizon` half of that, and `Bottom` on it.
  let at = (anchor : (@kit.AnchorX, @kit.AnchorY)) => {
    let report = compile([
      @kit.Canvas(100.0, 60.0, [
        @kit.Canvas::place((50.0, 30.0), "Tag", anchor~),
      ]),
    ])
    assert_eq(errors(report) + warnings(report), "")
    let run = of_kind(drawn(report), "text")[0]
    (run.x - 10.0, run.y - 10.0, run.w)
  }
  let (left, top, width) = at((Left, Top))
  inspect(
    "\{hundredths(left)} \{hundredths(top)} \{hundredths(width)}",
    content=(
      #|50.00 36.58 15.05
    ),
  )
  let capitals = top - 30.0
  let (center, horizon, _) = at((Center, Horizon))
  assert_true(close(center, 50.0 - width / 2.0))
  assert_true(close(horizon, 30.0 + capitals / 2.0))
  let (right, bottom, _) = at((Right, Bottom))
  assert_true(close(right, 50.0 - width))
  assert_true(close(bottom, 30.0))
  // The alignment is also that of the lines of the body: a label of two
  // lines that is anchored at its centre has its lines centred on the
  // point, and one that is anchored at its right ends there.
  let two = (anchor : (@kit.AnchorX, @kit.AnchorY)) => {
    let report = compile([
      @kit.Canvas(100.0, 60.0, [
        @kit.Canvas::place(
          (50.0, 30.0),
          Seq(["a long line", Linebreak(), "short"]),
          anchor~,
        ),
      ]),
    ])
    of_kind(drawn(report), "text")
  }
  for run in two((Center, Top)) {
    assert_true(close(run.x - 10.0 + run.w / 2.0, 50.0))
  }
  for run in two((Right, Top)) {
    assert_true(close(run.x - 10.0 + run.w, 50.0))
  }
  // The body is laid out in the size of the canvas: a text that is longer
  // than the canvas is wide is broken.
  let long = compile([
    @kit.Canvas(60.0, 60.0, [
      @kit.Canvas::place((0.0, 0.0), "one two three four five six"),
    ]),
  ])
  inspect(
    lines_of_text(long),
    content=(
      #|p1 10.0,16.6 "one two three "
      #|p1 10.0,29.7 "four five six"
    ),
  )
}

///|
test "canvas: the anchor `Baseline` puts the first baseline at the point" {
  // The baseline of a text run in the frames is where the engine draws
  // it. A body whose baseline is not its bottom: text with its descenders
  // in its box, a block with an inset, a body of two lines.
  let bodies : Array[(String, &IntoContent)] = [
    ("text", "Tag"),
    ("descender", Text("Tag", bottom_edge=Descender)),
    ("inset", Block("Tag", inset=Sides(all=Pt(5)))),
    ("two lines", Seq(["Tag", Linebreak(), "below"])),
    ("large", Text("Tag", size=Pt(20))),
  ]
  let lines : Array[String] = []
  for entry in bodies {
    let (name, body) = entry
    let baselines : Array[String] = []
    for anchor in ([Baseline, Bottom, Top] : Array[@kit.AnchorY]) {
      let report = compile([
        @kit.Canvas(100.0, 60.0, [
          @kit.Canvas::place((50.0, 30.0), body, anchor=(Center, anchor)),
        ]),
      ])
      assert_eq(errors(report) + warnings(report), "")
      let run = of_kind(drawn(report), "text")[0]
      if anchor is Baseline {
        // On the point, whatever the body: its baseline, and its middle.
        assert_true(close(run.y - 10.0, 30.0))
        assert_true(close(run.x - 10.0 + run.w / 2.0, 50.0))
      }
      baselines.push(hundredths(run.y - 10.0))
    }
    lines.push("\{name}: \{baselines.join(" ")}")
  }
  // The baseline of the first line by `Baseline`, `Bottom` and `Top`.
  inspect(
    lines.join("\n"),
    content=(
      #|text: 30.00 30.00 36.58
      #|descender: 30.00 27.54 36.58
      #|inset: 30.00 25.00 41.58
      #|two lines: 30.00 16.92 36.58
      #|large: 30.00 30.00 43.16
    ),
  )
  // Labels of two sizes stand on one line.
  let report = compile([
    @kit.Canvas(100.0, 60.0, [
      @kit.Canvas::place(
        (50.0, 40.0),
        Text("38", size=Pt(20)),
        anchor=(Right, Baseline),
      ),
      @kit.Canvas::place((52.0, 40.0), "kg", anchor=(Left, Baseline)),
    ]),
  ])
  inspect(
    listing(drawn(report)),
    content=(
      #|p1 text 41.4,50.0 20.0pt "38"
      #|p1 text 62.0,50.0 10.0pt "kg"
    ),
  )
  // A body that is broken at the width of the canvas is measured at that
  // width: its first line is "Tag", not the large word after it, which
  // would be on the first line of a body that is measured without a width.
  let wrapped = compile([
    @kit.Canvas(40.0, 60.0, [
      @kit.Canvas::place(
        (0.0, 20.0),
        Seq(["Tag ", Text("large", size=Pt(20))]),
        anchor=(Left, Baseline),
      ),
    ]),
  ])
  assert_eq(errors(wrapped) + warnings(wrapped), "")
  inspect(
    listing(drawn(wrapped)),
    content=(
      #|p1 text 10.0,30.0 10.0pt "Tag "
      #|p1 text 10.0,49.7 20.0pt "large"
    ),
  )
  let first = of_kind(drawn(wrapped), "text")[0]
  assert_true(close(first.y - 10.0, 20.0))
}

///|
test "canvas: at the end of a page it moves as a whole" {
  // A drawing of 50pt: a frame, a line across its middle and a label on
  // the line.
  let drawing : Array[&IntoContent] = [
    @kit.Canvas::rect((0.0, 0.0), 100.0, 50.0, fill=Luma(230)),
    @kit.Canvas::line((0.0, 25.0), (100.0, 25.0)),
    @kit.Canvas::place((50.0, 25.0), "middle", anchor=(Center, Bottom)),
  ]
  // 40pt of the region's 100pt are left, less the footnote's.
  let before : Array[&IntoContent] = [
    Par(Seq(["Text", Footnote("A note at the foot of the page.")])),
    V(Pt(40)),
  ]
  let canvas = compile([..before, @kit.Canvas(100.0, 50.0, drawing)])
  inspect(errors(canvas) + warnings(canvas), content="")
  inspect(
    listing(drawn(canvas)),
    content=(
      #|p1 text 10.0,16.6 10.0pt "Text"
      #|p1 text 27.8,16.6 10.0pt "1"
      #|p1 line 10.0,99.4 54.0x0.0 0.5 luma(0%)
      #|p1 text 18.5,110.0 8.5pt "1"
      #|p1 text 21.5,110.0 8.5pt "A note at the foot of the page."
      #|p2 box 10.0,10.0 100.0x50.0 luma(90.2%)
      #|p2 line 10.0,35.0 100.0x0.0 1.0 luma(0%)
      #|p2 text 46.1,35.0 10.0pt "middle"
    ),
  )
  // Everything of the canvas is on the second page, and the footnote on
  // the first.
  let all = drawn(canvas)
  let frame = of_kind(all, "box")[0]
  assert_eq(frame.page, 2)
  assert_eq(pt(frame.h), "50.0")
  for d in all {
    if d.text == "middle" || d.kind == "box" {
      assert_eq(d.page, 2)
    }
    if d.text.has_prefix("A note") {
      assert_eq(d.page, 1)
    }
  }
  // The same items in a block of that size that may break (finding S2a):
  // the block is split into what is left of the page and the rest, and its
  // items are placed in its first part, which is not as high as the
  // drawing: the frame is drawn from there in its 50pt, over the footnote
  // and out of the bottom margin (the page ends at 110pt).
  let block = compile(
    [..before, Block(Seq(drawing), width=Pt(100), height=Pt(50))],
  )
  inspect(errors(block) + warnings(block), content="")
  inspect(
    listing(drawn(block)),
    content=(
      #|p1 text 10.0,16.6 10.0pt "Text"
      #|p1 text 27.8,16.6 10.0pt "1"
      #|p1 box 10.0,68.6 100.0x50.0 luma(90.2%)
      #|p1 line 10.0,93.6 100.0x0.0 1.0 luma(0%)
      #|p1 text 46.1,93.6 10.0pt "middle"
      #|p1 line 10.0,99.4 54.0x0.0 0.5 luma(0%)
      #|p1 text 18.5,110.0 8.5pt "1"
      #|p1 text 21.5,110.0 8.5pt "A note at the foot of the page."
    ),
  )
  let split = of_kind(drawn(block), "box")[0]
  let note = drawn(block).filter(d => d.text.has_prefix("A note"))[0]
  assert_eq(split.page, 1)
  assert_true(split.y < note.y && split.y + split.h > note.y)
  assert_true(split.y + split.h > 110.0)
  assert_eq(pages(block), 2)
  // A canvas that is higher than a page fits no page: it is on one page
  // and runs out of it, without a diagnostic, like any unbreakable block.
  let high = compile([
    @kit.Canvas(100.0, 150.0, [
      @kit.Canvas::rect((0.0, 0.0), 100.0, 150.0, fill=Luma(230)),
    ]),
  ])
  inspect(errors(high) + warnings(high), content="")
  inspect(
    listing(drawn(high)),
    content=(
      #|p1 box 10.0,10.0 100.0x150.0 luma(90.2%)
    ),
  )
}

///|
/// The head and the path of the arrow of a compiled canvas that is first
/// on its page, in the coordinates of the canvas: the corners of the head,
/// and the points of the path.
fn arrow_parts(
  report : @doc.CompileReport[@layout.PagedDocument],
) -> (Array[(Double, Double)], Array[(Double, Double)]) raise {
  let shapes = outlines(report)
  let head = shapes.filter(shape => shape.fill != "")[0]
  let path = shapes.filter(shape => shape.fill == "")[0]
  (head.points.map(on_canvas), path.points.map(on_canvas))
}

///|
/// Checks the head of an arrow that arrives at `tip` in the direction
/// `(ux, uy)` (of length 1), `size` long, and the end of its path, `cut`
/// before the tip.
fn check_head(
  head : Array[(Double, Double)],
  end : (Double, Double),
  tip : (Double, Double),
  ux : Double,
  uy : Double,
  size : Double,
  cut : Double,
) -> Unit raise {
  assert_eq(head.length(), 3)
  // The tip is the first corner.
  assert_true(close(head[0].0, tip.0) && close(head[0].1, tip.1))
  let (left, right) = (head[1], head[2])
  // The other side is `size` behind the tip, across the direction, and
  // `size` wide, with the path through its middle.
  let middle = ((left.0 + right.0) / 2.0, (left.1 + right.1) / 2.0)
  assert_true(close(middle.0, tip.0 - size * ux))
  assert_true(close(middle.1, tip.1 - size * uy))
  let across = (left.0 - right.0, left.1 - right.1)
  assert_true(close(across.0 * ux + across.1 * uy, 0.0))
  assert_true(close((across.0 * across.0 + across.1 * across.1).sqrt(), size))
  // The corner after the tip is the one to the left of the direction on
  // the page (y grows downwards): the corners are in one order whatever
  // the direction is.
  assert_true(ux * (left.1 - tip.1) - uy * (left.0 - tip.0) > 0.0)
  // The path ends inside the head, on its axis.
  assert_true(close(end.0, tip.0 - cut * ux) && close(end.1, tip.1 - cut * uy))
}

///|
test "canvas: the head of an arrow points along its path, in the eight directions" {
  let start = (50.0, 30.0)
  let lines : Array[String] = []
  let directions : Array[(String, Double, Double)] = [
    ("east", 1.0, 0.0),
    ("south-east", 1.0, 1.0),
    ("south", 0.0, 1.0),
    ("south-west", -1.0, 1.0),
    ("west", -1.0, 0.0),
    ("north-west", -1.0, -1.0),
    ("north", 0.0, -1.0),
    ("north-east", 1.0, -1.0),
  ]
  for direction in directions {
    let (name, dx, dy) = direction
    let tip = (start.0 + 20.0 * dx, start.1 + 20.0 * dy)
    let report = compile([
      @kit.Canvas(100.0, 60.0, [
        @kit.Canvas::arrow(start, [LineTo(tip)], head=6.0),
      ]),
    ])
    assert_eq(errors(report) + warnings(report), "")
    let (head, path) = arrow_parts(report)
    let length = (dx * dx + dy * dy).sqrt()
    // The path: from the start to 3pt before the tip.
    assert_eq(path.length(), 2)
    assert_true(close(path[0].0, start.0) && close(path[0].1, start.1))
    check_head(head, path[1], tip, dx / length, dy / length, 6.0, 3.0)
    lines.push(
      "\{name}: \{points(head.map(p => (p.0 + 10.0, p.1 + 10.0)))} from \{points([(path[1].0 + 10.0, path[1].1 + 10.0)])}",
    )
  }
  inspect(
    lines.join("\n"),
    content=(
      #|east: (70.00, 30.00) (64.00, 33.00) (64.00, 27.00) from (67.00, 30.00)
      #|south-east: (70.00, 50.00) (63.64, 47.88) (67.88, 43.64) from (67.88, 47.88)
      #|south: (50.00, 50.00) (47.00, 44.00) (53.00, 44.00) from (50.00, 47.00)
      #|south-west: (30.00, 50.00) (32.12, 43.64) (36.36, 47.88) from (32.12, 47.88)
      #|west: (30.00, 30.00) (36.00, 27.00) (36.00, 33.00) from (33.00, 30.00)
      #|north-west: (30.00, 10.00) (36.36, 12.12) (32.12, 16.36) from (32.12, 12.12)
      #|north: (50.00, 10.00) (53.00, 16.00) (47.00, 16.00) from (50.00, 13.00)
      #|north-east: (70.00, 10.00) (67.88, 16.36) (63.64, 12.12) from (67.88, 12.12)
    ),
  )
}

///|
test "canvas: the head of an arrow on a curve, a bend and a short line" {
  let geometry = (
    start : (Double, Double),
    segments : Array[@kit.Segment],
    head : Double,
  ) => {
    let report = compile([
      @kit.Canvas(100.0, 60.0, [@kit.Canvas::arrow(start, segments, head~)]),
    ])
    assert_eq(errors(report) + warnings(report), "")
    arrow_parts(report)
  }
  // A curve back under two boxes: out of the bottom of one, into the
  // bottom of the other. The path arrives from its last control point,
  // straight below the tip: the head points up.
  let (head, path) = geometry(
    (80.0, 20.0),
    [CubicTo((80.0, 50.0), (30.0, 50.0), (30.0, 20.0))],
    6.0,
  )
  // (The frames have a curve as a move and one cubic: four points, the
  // control points as they were given.)
  inspect(
    points(path.map(p => (p.0 + 10.0, p.1 + 10.0))),
    content=(
      #|(80.00, 20.00) (80.00, 50.00) (30.00, 50.00) (30.00, 23.00)
    ),
  )
  check_head(head, path[3], (30.0, 20.0), 0.0, -1.0, 6.0, 3.0)
  // A tangent that is neither along an axis nor along the line between the
  // ends of the curve: from the control point (30, 50) to the tip (60,
  // 10) is the direction (3, -4) / 5.
  let (head, path) = geometry(
    (10.0, 10.0),
    [CubicTo((10.0, 40.0), (30.0, 50.0), (60.0, 10.0))],
    5.0,
  )
  check_head(head, path[3], (60.0, 10.0), 0.6, -0.8, 5.0, 2.5)
  // A quadratic curve arrives from its control point. (The frames have it
  // as a cubic, whose last control point is on that line.)
  let (head, path) = geometry(
    (10.0, 50.0),
    [QuadTo((70.0, 50.0), (70.0, 10.0))],
    6.0,
  )
  check_head(head, path[3], (70.0, 10.0), 0.0, -1.0, 6.0, 3.0)
  // A bend: the head is on the last line.
  let (head, path) = geometry(
    (20.0, 10.0),
    [LineTo((20.0, 40.0)), LineTo((60.0, 40.0))],
    6.0,
  )
  assert_eq(path.length(), 3)
  check_head(head, path[2], (60.0, 40.0), 1.0, 0.0, 6.0, 3.0)
  // A control point on the end: the path arrives from the one before it.
  let (head, path) = geometry(
    (10.0, 30.0),
    [CubicTo((40.0, 30.0), (60.0, 30.0), (60.0, 30.0))],
    6.0,
  )
  check_head(head, path[3], (60.0, 30.0), 1.0, 0.0, 6.0, 3.0)
  // A last line of 4pt with a head of 6pt: the path ends half way along
  // the line, not behind its start.
  let (head, path) = geometry(
    (20.0, 10.0),
    [LineTo((20.0, 40.0)), LineTo((24.0, 40.0))],
    6.0,
  )
  check_head(head, path[2], (24.0, 40.0), 1.0, 0.0, 6.0, 2.0)
  // No head: the path as it is, and a triangle without a size.
  let (head, path) = geometry((10.0, 30.0), [LineTo((60.0, 30.0))], 0.0)
  inspect(
    points(head.map(p => (p.0 + 10.0, p.1 + 10.0))),
    content=(
      #|(60.00, 30.00) (60.00, 30.00) (60.00, 30.00)
    ),
  )
  inspect(
    points(path.map(p => (p.0 + 10.0, p.1 + 10.0))),
    content=(
      #|(10.00, 30.00) (60.00, 30.00)
    ),
  )
}

///|
test "canvas: the paint and the stroke of an arrow, and what is not one" {
  let drawn_arrow = (stroke : Stroke?) => {
    let report = compile([
      @kit.Canvas(100.0, 60.0, [
        @kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, 30.0))], stroke?),
      ]),
    ])
    assert_eq(errors(report) + warnings(report), "")
    outlines(report)
    .map(shape => {
      let dashed = if shape.dashed { " dashed" } else { "" }
      "fill \{shape.fill} stroke \{shape.stroke}\{dashed}"
    })
    .join(" | ")
  }
  // The head is filled in the paint of the stroke, and has no stroke.
  inspect(
    drawn_arrow(None),
    content=(
      #|fill  stroke 1.0 luma(0%) | fill luma(0%) stroke 
    ),
  )
  inspect(
    drawn_arrow(Some(Stroke(paint=Blue, thickness=Pt(0.6)))),
    content=(
      #|fill  stroke 0.6 rgb("#0074d9") | fill rgb("#0074d9") stroke 
    ),
  )
  // A dashed arrow: the path is dashed, the head is filled.
  inspect(
    drawn_arrow(Some(Stroke(paint=Red, dash=Dashed))),
    content=(
      #|fill  stroke 1.0 rgb("#ff4136") dashed | fill rgb("#ff4136") stroke 
    ),
  )
  // A stroke without a paint: black, as the stroke is drawn.
  inspect(
    drawn_arrow(Some(Stroke(thickness=Pt(2)))) +
    " || " +
    drawn_arrow(Some(Stroke(paint=Auto))),
    content=(
      #|fill  stroke 2.0 luma(0%) | fill luma(0%) stroke  || fill  stroke 1.0 luma(0%) | fill luma(0%) stroke 
    ),
  )
  // A rule of the document for the strokes of curves is not seen: the
  // head of an arrow without a paint stays black.
  let ruled = compile([
    SetCurve(stroke=Stroke(paint=Red)),
    @kit.Canvas(100.0, 60.0, [
      @kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, 30.0))]),
    ]),
  ])
  inspect(
    outlines(ruled)
    .map(shape => "fill \{shape.fill} stroke \{shape.stroke}")
    .join(" | "),
    content=(
      #|fill  stroke 1.0 rgb("#ff4136") | fill luma(0%) stroke 
    ),
  )
  // What is not an arrow, each an error at its argument.
  let nan = 0.0 / 0.0
  let failing : Array[(String, @kit.CanvasItem)] = [
    ("no segments", @kit.Canvas::arrow((10.0, 30.0), [])),
    ("no direction", @kit.Canvas::arrow((10.0, 30.0), [LineTo((10.0, 30.0))])),
    (
      "no direction, curve",
      @kit.Canvas::arrow((10.0, 30.0), [
        LineTo((40.0, 30.0)),
        CubicTo((40.0, 30.0), (40.0, 30.0), (40.0, 30.0)),
      ]),
    ),
    (
      "negative head",
      @kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, 30.0))], head=-1.0),
    ),
    ("head", @kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, 30.0))], head=nan)),
    ("start", @kit.Canvas::arrow((nan, 30.0), [LineTo((60.0, 30.0))])),
    ("segments", @kit.Canvas::arrow((10.0, 30.0), [LineTo((60.0, nan))])),
  ]
  let lines : Array[String] = []
  for entry in failing {
    let report = compile([@kit.Canvas(100.0, 60.0, [entry.1])])
    lines.push("\{entry.0}: \{error_place(report)}: \{errors(report)}")
  }
  inspect(
    lines.join("\n"),
    content=(
      #|no segments: Canvas::arrow a1 0: `Canvas::arrow` needs a segment: a path from `start` to where the arrow points
      #|no direction: Canvas::arrow a1 0: the last segment of `Canvas::arrow` ends where it starts: the arrow has no direction
      #|no direction, curve: Canvas::arrow a1 0: the last segment of `Canvas::arrow` ends where it starts: the arrow has no direction
      #|negative head: Canvas::arrow a3 0: the `head` of `Canvas::arrow` must be a finite number of points that is not negative
      #|head: Canvas::arrow a3 0: the `head` of `Canvas::arrow` must be a finite number of points that is not negative
      #|start: Canvas::arrow a0 0: the coordinates of `Canvas::arrow` must be finite numbers of points
      #|segments: Canvas::arrow a1 0: the coordinates of `Canvas::arrow` must be finite numbers of points
    ),
  )
}

///|
test "canvas: in a table cell, in a card, and in callbacks" {
  // A drawing of 40pt by 20pt: a frame and a label in its middle.
  let drawing = () => {
    @kit.Canvas(40.0, 20.0, [
      @kit.Canvas::rect((0.0, 0.0), 40.0, 20.0, fill=Luma(230)),
      @kit.Canvas::place((20.0, 10.0), "mid", anchor=(Center, Horizon)),
    ])
  }
  // Where the label is in its frame: the offsets of its middle from the
  // middle of the frame, which are zero wherever the canvas is.
  let centred = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    assert_eq(errors(report) + warnings(report), "")
    let all = drawn(report)
    let frames = of_kind(all, "box").filter(box => pt(box.w) == "40.0")
    let labels = of_kind(all, "text").filter(run => run.text == "mid")
    assert_eq(frames.length(), labels.length())
    assert_true(frames.length() > 0)
    for i, frame in frames {
      let label = labels[i]
      assert_eq(pt(frame.h), "20.0")
      assert_true(close(label.x + label.w / 2.0, frame.x + 20.0))
      // (The middle of a line of text is half its capitals above its
      // baseline: 3.29pt at 10pt; the text of a heading is larger.)
      let below = label.y - (frame.y + 10.0)
      assert_true(below > 0.3 * label.h && below < 0.36 * label.h)
    }
    frames
    .map(frame => "p\{frame.page} \{pt(frame.x)},\{pt(frame.y)}")
    .join(" ")
  }
  inspect(
    centred(compile([drawing()])),
    content=(
      #|p1 10.0,10.0
    ),
  )
  // In the cell of a table, after a cell of text.
  inspect(
    centred(compile([Table(["cell", drawing()], columns=[Pt(60), Fr(1)])])),
    content=(
      #|p1 75.0,15.0
    ),
  )
  // In a card, in both forms of `Cards`.
  inspect(
    centred(compile([@kit.Cards(["card", drawing()], inset~)])),
    content=(
      #|p1 104.0,14.0
    ),
  )
  inspect(
    centred(compile([@kit.Cards(["card", drawing()], inset~, radius=round)])),
    content=(
      #|p1 104.0,14.0
    ),
  )
  // Built inside callbacks: a show rule and a `Context`.
  let in_callbacks = compile([
    Show(Select::heading()) <| ((it, _) => Seq([it, drawing()])),
    Heading("Head"),
    Context(_ => drawing()),
  ])
  inspect(
    centred(in_callbacks),
    content=(
      #|p1 10.0,37.0 p1 10.0,64.5
    ),
  )
  // As wide as its container: the width from `Layout`, the items from the
  // width. In a pad of 30pt to each side of the region's 180pt.
  let wide = compile([
    Pad(
      Layout((size, _) => {
        @kit.Canvas(size.width, 20.0, [
          @kit.Canvas::rect((0.0, 0.0), size.width, 20.0, fill=Luma(230)),
          @kit.Canvas::place((size.width, 10.0), "end", anchor=(Right, Horizon)),
        ])
      }),
      x=Pt(30),
    ),
  ])
  inspect(errors(wide) + warnings(wide), content="")
  inspect(
    listing(drawn(wide)),
    content=(
      #|p1 box 40.0,10.0 120.0x20.0 luma(90.2%)
      #|p1 text 145.1,23.3 10.0pt "end"
    ),
  )
}

///|
test "canvas: an item with the anchor `Baseline` is a callback, and cannot be built inside one" {
  // Built inside a callback: the error of `Layout`, at the call of the
  // item.
  let line = line_here() + 4
  let inside = compile([
    Context(_ => {
      @kit.Canvas(100.0, 60.0, [
        @kit.Canvas::place((50.0, 30.0), "Tag", anchor=(Left, Baseline)),
      ])
    }),
  ])
  inspect(
    errors(inside),
    content=(
      #|callbacks cannot be created inside a callback
    ),
  )
  inspect(
    error_place(inside),
    content=(
      #|Canvas::place call 0
    ),
  )
  assert_eq(error_origin(inside).start_line, line)
  // Built before and captured: fine, also when it is used twice.
  let early = @kit.Canvas::place((50.0, 30.0), "Tag", anchor=(Left, Baseline))
  let captured = compile([
    Context(_ => {
      Seq([@kit.Canvas(100.0, 40.0, [early]), @kit.Canvas(100.0, 40.0, [early])])
    }),
  ])
  inspect(errors(captured) + warnings(captured), content="")
  inspect(
    lines_of_text(captured),
    content=(
      #|p1 60.0,40.0 "Tag"
      #|p1 60.0,92.0 "Tag"
    ),
  )
  // Inside a callback the baseline is the callback's to measure: the same
  // place, without an item that measures.
  let own = compile([
    Context(cx => {
      let baseline = cx.measure("Tag").baseline
      @kit.Canvas(100.0, 40.0, [
        @kit.Canvas::place((50.0, 30.0 - baseline), "Tag"),
      ])
    }),
  ])
  inspect(errors(own) + warnings(own), content="")
  let run = of_kind(drawn(own), "text")[0]
  let twice = of_kind(drawn(captured), "text")[0]
  assert_true(close(run.x, twice.x) && close(run.y, twice.y))
  // Outside of a box with a size (a page as wide and as high as its
  // content) the body is measured without one, as it is placed there.
  let unbounded = compile(
    [@kit.Canvas::place((50.0, 30.0), "Tag", anchor=(Left, Baseline))],
    setup=[
      SetPage(width=Auto, height=Auto, margin=Sides(all=Pt(10))),
      SetText(size=Pt(10)),
    ],
  )
  inspect(errors(unbounded) + warnings(unbounded), content="")
  inspect(
    lines_of_text(unbounded),
    content=(
      #|p1 60.0,40.0 "Tag"
    ),
  )
}

///|
test "canvas: what is outside of it, and what is not an item" {
  // An item outside the canvas is drawn where it is placed: over what is
  // before, beside and after the canvas. With `clip` it is cut off.
  let items : Array[&IntoContent] = [
    @kit.Canvas::rect((-5.0, -5.0), 20.0, 10.0, fill=Red),
    @kit.Canvas::rect((90.0, 15.0), 30.0, 10.0, fill=Blue),
  ]
  let open = compile([@kit.Canvas(100.0, 20.0, items), "After."])
  inspect(errors(open) + warnings(open), content="")
  inspect(
    listing(drawn(open)),
    content=(
      #|p1 box 5.0,5.0 20.0x10.0 rgb("#ff4136")
      #|p1 box 100.0,25.0 30.0x10.0 rgb("#0074d9")
      #|p1 text 10.0,48.6 10.0pt "After."
    ),
  )
  assert_eq(outlines(open).map(shape => shape.clipped), [false, false])
  let clipped = compile([@kit.Canvas(100.0, 20.0, items, clip=true), "After."])
  inspect(errors(clipped) + warnings(clipped), content="")
  // The items are where they were, in a group that clips to the canvas.
  assert_eq(listing(drawn(clipped)), listing(drawn(open)))
  assert_eq(outlines(clipped).map(shape => shape.clipped), [true, true])
  // Content that is not placed is laid out from the top left corner of
  // the block, as in any block; placed items are over it, wherever they
  // are in the array.
  let flow = compile([
    @kit.Canvas(100.0, 40.0, [
      @kit.Canvas::rect((50.0, 0.0), 10.0, 10.0, fill=Red),
      "First.",
      Par("Second."),
    ]),
  ])
  inspect(errors(flow) + warnings(flow), content="")
  inspect(
    listing(drawn(flow)),
    content=(
      #|p1 box 60.0,10.0 10.0x10.0 rgb("#ff4136")
      #|p1 text 10.0,16.6 10.0pt "First."
      #|p1 text 10.0,35.2 10.0pt "Second."
    ),
  )
  // A rule is not an item: an item is under a key.
  let rule = compile([
    @kit.Canvas(100.0, 40.0, [
      SetText(fill=Red),
      @kit.Canvas::place((0.0, 0.0), "label"),
    ]),
  ])
  inspect(
    errors(rule),
    content=(
      #|rules are only allowed directly in `Document` and `Seq`
    ),
  )
  // A rule in a `Seq` with the items that it is for is one item.
  let grouped = compile([
    @kit.Canvas(100.0, 40.0, [
      Seq([
        SetText(size=Pt(6)),
        @kit.Canvas::place((0.0, 0.0), "small"),
        @kit.Canvas::place((0.0, 20.0), "small too"),
      ]),
      @kit.Canvas::place((50.0, 0.0), "not small"),
    ]),
  ])
  inspect(errors(grouped) + warnings(grouped), content="")
  inspect(
    listing(drawn(grouped)),
    content=(
      #|p1 text 10.0,13.9 6.0pt "small"
      #|p1 text 10.0,33.9 6.0pt "small too"
      #|p1 text 60.0,16.6 10.0pt "not small"
    ),
  )
  // A `Text` around the canvas is the style of its labels.
  let styled = compile([
    Text(
      @kit.Canvas(100.0, 40.0, [@kit.Canvas::place((0.0, 0.0), "label")]),
      size=Pt(7),
      fill=Blue,
    ),
  ])
  inspect(
    listing(drawn(styled)),
    content=(
      #|p1 text 10.0,14.6 7.0pt "label"
    ),
  )
  let label = of_kind(drawn(styled), "text")[0]
  inspect(
    label.fill,
    content=(
      #|rgb("#0074d9")
    ),
  )
  // A size or a coordinate that is not a number, each at its argument.
  let nan = 0.0 / 0.0
  let inf = 1.0 / 0.0
  let failing : Array[(String, &IntoContent)] = [
    ("width", @kit.Canvas(nan, 20.0, [])),
    ("width, negative", @kit.Canvas(-1.0, 20.0, [])),
    ("height", @kit.Canvas(100.0, inf, [])),
    ("height, negative", @kit.Canvas(100.0, -0.5, [])),
    ("place", @kit.Canvas::place((nan, 0.0), "x")),
    ("line start", @kit.Canvas::line((0.0, inf), (1.0, 1.0))),
    ("line end", @kit.Canvas::line((0.0, 0.0), (nan, 1.0))),
    ("rect at", @kit.Canvas::rect((nan, 0.0), 1.0, 1.0)),
    ("rect width", @kit.Canvas::rect((0.0, 0.0), nan, 1.0)),
    ("rect height", @kit.Canvas::rect((0.0, 0.0), 1.0, inf)),
    ("circle center", @kit.Canvas::circle((0.0, nan), 1.0)),
    ("circle radius", @kit.Canvas::circle((0.0, 0.0), nan)),
    ("curve start", @kit.Canvas::curve((nan, 0.0), [LineTo((1.0, 1.0))])),
    (
      "curve segments",
      @kit.Canvas::curve((0.0, 0.0), [QuadTo((1.0, nan), (1.0, 1.0))]),
    ),
  ]
  let lines : Array[String] = []
  for entry in failing {
    let report = compile([entry.1])
    lines.push("\{entry.0}: \{error_place(report)}: \{errors(report)}")
  }
  inspect(
    lines.join("\n"),
    content=(
      #|width: Canvas a0: the `width` of a `Canvas` must be a finite number of points that is not negative
      #|width, negative: Canvas a0: the `width` of a `Canvas` must be a finite number of points that is not negative
      #|height: Canvas a1: the `height` of a `Canvas` must be a finite number of points that is not negative
      #|height, negative: Canvas a1: the `height` of a `Canvas` must be a finite number of points that is not negative
      #|place: Canvas::place a0: the coordinates of `Canvas::place` must be finite numbers of points
      #|line start: Canvas::line a0: the coordinates of `Canvas::line` must be finite numbers of points
      #|line end: Canvas::line a1: the coordinates of `Canvas::line` must be finite numbers of points
      #|rect at: Canvas::rect a0: the coordinates of `Canvas::rect` must be finite numbers of points
      #|rect width: Canvas::rect a1: the sizes of `Canvas::rect` must be finite numbers of points
      #|rect height: Canvas::rect a2: the sizes of `Canvas::rect` must be finite numbers of points
      #|circle center: Canvas::circle a0: the coordinates of `Canvas::circle` must be finite numbers of points
      #|circle radius: Canvas::circle a1: the sizes of `Canvas::circle` must be finite numbers of points
      #|curve start: Canvas::curve a0: the coordinates of `Canvas::curve` must be finite numbers of points
      #|curve segments: Canvas::curve a1: the coordinates of `Canvas::curve` must be finite numbers of points
    ),
  )
}

///|
test "canvas: a drawing in other units is scaled" {
  // A drawing in the units of a picture 200 wide, at 40% of its size: the
  // canvas takes 80pt by 20pt, and its strokes and its text are scaled
  // with it.
  let report = compile([
    Scale(
      @kit.Canvas(200.0, 50.0, [
        @kit.Canvas::rect((0.0, 0.0), 200.0, 50.0, fill=Luma(230)),
        @kit.Canvas::place((100.0, 25.0), "mid", anchor=(Center, Horizon)),
      ]),
      factor=Pct(40),
      reflow=true,
    ),
    "After.",
  ])
  inspect(errors(report) + warnings(report), content="")
  // (The text after the canvas shows the room that it takes: 20pt, where
  // the canvas itself takes 50pt.)
  let after = (report : @doc.CompileReport[@layout.PagedDocument]) => {
    let run = of_kind(drawn(report), "text").filter(run => run.text == "After.")[0]
    pt(run.y)
  }
  inspect(
    after(report),
    content=(
      #|48.6
    ),
  )
  let plain = compile([@kit.Canvas(200.0, 50.0, []), "After."])
  inspect(
    after(plain),
    content=(
      #|78.6
    ),
  )
  // The frame of the drawing, as it is drawn: 80pt by 20pt.
  let scaled : Array[String] = []
  fn walk(frame : @library.Frame, sx : Double, sy : Double) -> Unit {
    for entry in frame.items() {
      match entry.1 {
        Group(group) =>
          walk(
            group.frame,
            sx * group.transform.sx.get(),
            sy * group.transform.sy.get(),
          )
        Shape({ geometry: Rect(size), .. }, _) =>
          scaled.push("\{pt(size.x.to_pt() * sx)}x\{pt(size.y.to_pt() * sy)}")
        _ => ()
      }
    }
  }

  walk(report.unwrap().pages()[0].frame, 1.0, 1.0)
  inspect(
    scaled.join(" "),
    content=(
      #|80.0x20.0
    ),
  )
}

///|
test "canvas: provenance" {
  let own = Emph("own")
  let line = line_here() + 3
  let report = compile([
    @kit.Canvas(100.0, 60.0, [
      @kit.Canvas::rect((10.0, 10.0), 30.0, 20.0, fill=Luma(200)),
      @kit.Canvas::place((50.0, 10.0), "label"),
      @kit.Canvas::place((50.0, 30.0), own),
      "plain",
      @kit.Canvas::place((50.0, 50.0), "based", anchor=(Left, Baseline)),
    ]),
  ])
  inspect(errors(report), content="")
  // A label is the `body` argument of its item, under the key of the
  // item; a description of the caller is at its own call; a string among
  // the items is the `items` argument of the canvas. An item that
  // measures is the same.
  inspect(
    text_args(report),
    content=(
      #|label: Canvas::place a1 1 | own: Emph a0 2 | plain: Canvas a2 3 | based: Canvas::place a1 4
    ),
  )
  // A click on the rectangle: the call of the item that drew it, under
  // its key, not the canvas.
  let box = of_kind(drawn(report), "box")[0]
  guard report.origin_at(1, box.x + 2.0, box.y + 2.0) is Some(origin) else {
    fail("no origin at the rectangle")
  }
  assert_eq(place(origin), "Canvas::rect call 0")
  assert_eq(origin.start_line, line)
  // Items that one line makes are told apart by their keys: by the index,
  // or by the key of the caller.
  let bars = (key : ((Int) -> String)?) => {
    let items : Array[&IntoContent] = []
    for i in 0..<3 {
      items.push(
        @kit.Canvas::rect(
          (20.0 * i.to_double(), 0.0),
          10.0,
          30.0,
          fill=Luma(200),
        ),
      )
    }
    let report = compile([@kit.Canvas(100.0, 60.0, items, key?)])
    let found : Array[String] = []
    for box in of_kind(drawn(report), "box") {
      guard report.origin_at(1, box.x + 2.0, box.y + 2.0) is Some(origin) else {
        fail("no origin at a bar")
      }
      found.push(place(origin))
    }
    found.join(" | ")
  }
  inspect(
    bars(None),
    content=(
      #|Canvas::rect call 0 | Canvas::rect call 1 | Canvas::rect call 2
    ),
  )
  inspect(
    bars(Some(i => ["north", "south", "west"][i])),
    content=(
      #|Canvas::rect call north | Canvas::rect call south | Canvas::rect call west
    ),
  )
  // Under a key of the caller, around the canvas and around an item.
  inspect(
    text_args(
      compile([
        Keyed(
          "figure",
          @kit.Canvas(100.0, 60.0, [
            Keyed("bed", @kit.Canvas::place((0.0, 0.0), "a")),
          ]),
        ),
      ]),
    ),
    content=(
      #|a: Canvas::place a1 figure/0/bed
    ),
  )
  // A selection in a label, with the source: the characters of the
  // literal.
  let labelled = compile([
    @kit.Canvas(100.0, 60.0, [@kit.Canvas::place((0.0, 0.0), "harvest")]),
  ])
  let text = labelled.review_text(title="Test")
  let found = text.feedback(text.find("harvest").unwrap(), "").origins[0]
  inspect(
    "\{place(found.origin)}: tier \{found.tier}",
    content=(
      #|Canvas::place a1 0: tier 2
    ),
  )
  let lines : Array[String] = []
  while lines.length() < found.origin.start_line {
    lines.push("")
  }
  lines[found.origin.start_line - 1] = " ".repeat(found.origin.start_column - 1) +
    "\"harvest\""
  let file = lines.join("\n") + "\n"
  let with_source = labelled.review_text(sources=(name, _) => {
    if name == "doc/kit/canvas_test.mbt" {
      Some(file)
    } else {
      None
    }
  })
  let found = with_source.feedback(with_source.find("harvest").unwrap(), "").origins[0]
  let source = found.source_ranges.map(range => {
    " \{range.text} at \{range.start - found.origin.start_column}"
  })
  inspect(
    "\{place(found.origin)}: tier \{found.tier}\{source.join("")}",
    content=(
      #|Canvas::place a1 0: tier 3 harvest at 1
    ),
  )
  // A key that `Keyed` does not take is an error at `key`.
  let reserved = compile([@kit.Canvas(100.0, 60.0, ["a"], key=_ => "\u{FDD2}x")])
  inspect(
    "\{error_place(reserved)}: \{errors(reserved)}",
    content=(
      #|Canvas a4: the key of `items[0]` starts with a reserved character (U+FDD2)
    ),
  )
}

///|
test "canvas: an error in an argument of an item is at that argument" {
  let paint : @doc.Paint = Value(@doc.Value::str("x"))
  let stroke = Stroke(paint~)
  let radius : Corners[@doc.Length] = Corners(all=Auto)
  let failing : Array[(String, @kit.CanvasItem)] = [
    ("line stroke", @kit.Canvas::line((0.0, 0.0), (9.0, 9.0), stroke~)),
    ("rect fill", @kit.Canvas::rect((0.0, 0.0), 9.0, 9.0, fill=paint)),
    (
      "rect stroke",
      @kit.Canvas::rect((0.0, 0.0), 9.0, 9.0, stroke=Sides(all=stroke)),
    ),
    ("rect radius", @kit.Canvas::rect((0.0, 0.0), 9.0, 9.0, radius~)),
    ("circle fill", @kit.Canvas::circle((0.0, 0.0), 9.0, fill=paint)),
    ("circle stroke", @kit.Canvas::circle((0.0, 0.0), 9.0, stroke~)),
    (
      "curve fill",
      @kit.Canvas::curve((0.0, 0.0), [LineTo((9.0, 9.0))], fill=paint),
    ),
    (
      "curve stroke",
      @kit.Canvas::curve((0.0, 0.0), [LineTo((9.0, 9.0))], stroke~),
    ),
    (
      "arrow stroke",
      @kit.Canvas::arrow((0.0, 0.0), [LineTo((9.0, 9.0))], stroke~),
    ),
  ]
  let places : Array[String] = []
  for entry in failing {
    let report = compile([@kit.Canvas(100.0, 60.0, [entry.1])])
    assert_true(errors(report) != "")
    places.push("\{entry.0}: \{error_place(report)}")
  }
  inspect(
    places.join("\n"),
    content=(
      #|line stroke: Canvas::line a2 0
      #|rect fill: Canvas::rect a3 0
      #|rect stroke: Canvas::rect a4 0
      #|rect radius: Canvas::rect a5 0
      #|circle fill: Canvas::circle a2 0
      #|circle stroke: Canvas::circle a3 0
      #|curve fill: Canvas::curve a2 0
      #|curve stroke: Canvas::curve a3 0
      #|arrow stroke: Canvas::arrow a2 0
    ),
  )
}
