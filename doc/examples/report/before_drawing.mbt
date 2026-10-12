// helper-lines: kit
//
// The helpers an author wrote for a chart and a diagram before the kit had
// `Canvas` (finding H6 of docs/edsl-ports.md): the shape of the `at`,
// `label`, `segment`, `bar`, `canvas`, `node`, `head` and `arrow` of the
// ports. The width of the drawing is that of the text area, typed in by
// hand (`TEXT_W`), and a label is put on its baseline by an estimate of
// the height of its letters.

///|
using @doc {
  type Align,
  type Curve,
  type CurveCubic,
  type CurveMove,
  type Line,
  type Place,
  type Polygon,
  type Rect,
}

///|
/// `body` with its top left corner at (`x`, `y`) of the drawing.
fn at(x : Double, y : Double, body : &IntoContent) -> Place {
  Place(body, alignment=Both(Left, Top), dx=Pt(x), dy=Pt(y))
}

///|
/// Where a label is anchored: at its start, its middle or its end.
priv enum Anchor {
  Lead
  Mid
  Trail
}

///|
/// A line of text with its baseline at `y`, anchored at `x` like SVG's
/// `text-anchor`. The top of the text is taken to be 0.72 of its size
/// above its baseline; a label that is not anchored at its start is
/// aligned in a box of 180pt.
fn label(
  x : Double,
  y : Double,
  text : String,
  size~ : Double = LABEL,
  fill~ : Paint = ink,
  anchor~ : Anchor = Lead,
) -> Place {
  let body = Text(text, size=Pt(size), fill~)
  let top = y - 0.72 * size
  match anchor {
    Lead => at(x, top, body)
    Mid => at(x - 90, top, Box(Align(Center, body), width=Pt(180)))
    Trail => at(x - 180, top, Box(Align(Right, body), width=Pt(180)))
  }
}

///|
/// A straight line.
fn segment(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  stroke : Stroke,
) -> Place {
  at(0, 0, Line(start=(Pt(x1), Pt(y1)), end_=(Pt(x2), Pt(y2)), stroke~))
}

///|
/// A bar of a chart.
fn bar(x : Double, y : Double, w : Double, h : Double, fill : Paint) -> Place {
  at(x, y, Rect(width=Pt(w), height=Pt(h), fill~, radius=Corners(all=Pt(2))))
}

///|
/// The box that holds a drawing.
fn canvas(height : Double, items : Array[&IntoContent]) -> Block {
  Block(Seq(items), width=Pt(TEXT_W), height=Pt(height))
}

// helper-lines: own
//
// Where the boxes of a diagram are: the kit has no nodes, and the version
// with it computes the same sides where it uses them.

///|
/// A box of a diagram, by its corner and its size.
priv struct Node {
  x : Double
  y : Double
  w : Double
  h : Double
}

///|
fn Node::cx(self : Node) -> Double {
  self.x + self.w / 2
}

///|
fn Node::cy(self : Node) -> Double {
  self.y + self.h / 2
}

// helper-lines: kit

///|
/// A box of a diagram with its text in its middle.
fn node(
  n : Node,
  body : &IntoContent,
  fill : Paint,
  stroke : Sides[Stroke],
) -> Place {
  at(
    n.x,
    n.y,
    Rect(
      width=Pt(n.w),
      height=Pt(n.h),
      fill~,
      stroke~,
      radius=Corners(all=Pt(3)),
      inset=Sides(all=Pt(2)),
      body=Align(Both(Center, Horizon), body),
    ),
  )
}

///|
/// The length and the width of the head of an arrow, in points.
const HEAD : Double = 5.5

///|
/// The head of an arrow with its tip at (`x`, `y`), pointing along (`dx`,
/// `dy`).
fn head(
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
  paint : Paint,
) -> Place {
  let len = (dx * dx + dy * dy).sqrt()
  let (ux, uy) = (dx / len, dy / len)
  let (bx, by) = (x - HEAD * ux, y - HEAD * uy)
  let half = HEAD / 2
  at(
    0,
    0,
    Polygon(
      [
        (Pt(x), Pt(y)),
        (Pt(bx - half * uy), Pt(by + half * ux)),
        (Pt(bx + half * uy), Pt(by - half * ux)),
      ],
      fill=paint,
    ),
  )
}

///|
/// A straight arrow from (`x1`, `y1`) to (`x2`, `y2`). Its line ends
/// inside its head.
fn arrow(
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  paint : Paint,
  dashed~ : Bool = false,
) -> Seq {
  let (dx, dy) = (x2 - x1, y2 - y1)
  let len = (dx * dx + dy * dy).sqrt()
  let cut = HEAD / 2
  Seq([
    segment(
      x1,
      y1,
      x2 - cut * dx / len,
      y2 - cut * dy / len,
      arrow_stroke(paint, dashed~),
    ),
    head(x2, y2, dx, dy, paint),
  ])
}

///|
/// An arrow that leaves (`x1`, `y`) downwards, hangs `sag` under it, and
/// arrives at (`x2`, `y`) from below.
fn arrow_back(
  x1 : Double,
  x2 : Double,
  y : Double,
  sag : Double,
  paint : Paint,
) -> Seq {
  Seq([
    at(
      0,
      0,
      Curve(
        [
          CurveMove((Pt(x1), Pt(y))),
          CurveCubic(
            (Pt(x1), Pt(y + sag)),
            (Pt(x2), Pt(y + sag)),
            (Pt(x2), Pt(y + HEAD / 2)),
          ),
        ],
        stroke=arrow_stroke(paint),
      ),
    ),
    head(x2, y, 0, -1, paint),
  ])
}
