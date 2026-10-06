// Twins of the kit's `Canvas` (docs/edsl-ports.md, section 4 and "As built
// (step 5)"): the Typst functions with the expansions of the element and
// of its items, and the documents that call both with the same arguments.
// What `kit.mbt` says about functions and elements holds here too. Two
// things more:
// - a point is an array of two numbers, a segment an array of its kind
//   (`"line"`, `"quad"`, `"cubic"`) and its points, and the anchor
//   `Baseline` the string `"baseline"`, since Typst has no value for it;
// - the function joins its items (`items.join()`), which makes one
//   sequence of the items of a sequence, where the element keeps a `Seq`
//   among its items as a sequence of its own: the frames are the same and
//   the structure is not, so no document here has an item that is a
//   sequence (every item of the kit is one `place`).

///|
/// The Typst functions of `@kit.Canvas` and of its items, in one binding,
/// so that their definition is one expression of the markup.
///
/// `canvas`: the width, the height, then the items; `clip` is named.
/// `canvas-place`, `canvas-line`, `canvas-rect`, `canvas-circle`,
/// `canvas-curve` and `canvas-arrow` take the arguments of the items in
/// their order, the optional ones by name. Each checks what the item
/// checks, with its message, and passes on only what it was given.
let canvas_typ : String =
  #|#let (canvas, canvas-place, canvas-line, canvas-rect, canvas-circle, canvas-curve, canvas-arrow) = {
  #|  // A coordinate that can be placed, and the messages for one that
  #|  // cannot.
  #|  let finite(v) = not float.is-nan(float(v)) and not float.is-infinite(float(v))
  #|  let finite-point(p) = finite(p.at(0)) and finite(p.at(1))
  #|  let finite-path(start, segments) = finite-point(start) and segments.all(segment => segment.slice(1).all(finite-point))
  #|  let coordinates(item) = "the coordinates of `Canvas::" + item + "` must be finite numbers of points"
  #|  let sizes(item) = "the sizes of `Canvas::" + item + "` must be finite numbers of points"
  #|  // A point as lengths.
  #|  let pt(p) = (p.at(0) * 1pt, p.at(1) * 1pt)
  #|  // The offset that puts a side of a placed body (0: the start, 1: the
  #|  // middle, 2: the end) at `at`: it takes back the share of the
  #|  // container that the alignment adds.
  #|  let offset(at, side) = if side == 0 { at * 1pt } else if side == 1 { at * 1pt - 50% } else { at * 1pt - 100% }
  #|  // The component of a curve that a segment is.
  #|  let component(segment) = {
  #|    let kind = segment.at(0)
  #|    if kind == "line" {
  #|      curve.line(pt(segment.at(1)))
  #|    } else if kind == "quad" {
  #|      curve.quad(pt(segment.at(1)), pt(segment.at(2)))
  #|    } else {
  #|      curve.cubic(pt(segment.at(1)), pt(segment.at(2)), pt(segment.at(3)))
  #|    }
  #|  }
  #|  let components(start, segments) = (curve.move(pt(start)), ..segments.map(component))
  #|
  #|  let canvas(width, height, ..args) = {
  #|    assert(
  #|      finite(width) and width >= 0,
  #|      message: "the `width` of a `Canvas` must be a finite number of points that is not negative",
  #|    )
  #|    assert(
  #|      finite(height) and height >= 0,
  #|      message: "the `height` of a `Canvas` must be a finite number of points that is not negative",
  #|    )
  #|    let items = args.pos()
  #|    block(
  #|      width: width * 1pt,
  #|      height: height * 1pt,
  #|      // One region: the items are placed once.
  #|      breakable: false,
  #|      ..args.named(),
  #|      if items.len() == 0 { [] } else { items.join() },
  #|    )
  #|  }
  #|
  #|  let place-item(at, body, anchor: (left, top)) = {
  #|    assert(finite-point(at), message: coordinates("place"))
  #|    let (x, y) = at
  #|    let (h, v) = anchor
  #|    let dx = offset(x, (left: 0, center: 1, right: 2).at(repr(h)))
  #|    if v == "baseline" {
  #|      // The body is measured in the size of the canvas, as a `place`
  #|      // lays it out, and placed with its top that far above the point.
  #|      return place(left + top, layout(size => {
  #|        let region = (:)
  #|        if size.width.pt() != float.inf { region.insert("width", size.width) }
  #|        if size.height.pt() != float.inf { region.insert("height", size.height) }
  #|        let baseline = measure(body, ..region).baseline
  #|        place(h + top, dx: dx, dy: y * 1pt - baseline, body)
  #|      }))
  #|    }
  #|    place(h + v, dx: dx, dy: offset(y, (top: 0, horizon: 1, bottom: 2).at(repr(v))), body)
  #|  }
  #|
  #|  let line-item(start, end, ..args) = {
  #|    assert(finite-point(start), message: coordinates("line"))
  #|    assert(finite-point(end), message: coordinates("line"))
  #|    place(left + top, line(start: pt(start), end: pt(end), ..args.named()))
  #|  }
  #|
  #|  let rect-item(at, width, height, ..args) = {
  #|    assert(finite-point(at), message: coordinates("rect"))
  #|    assert(finite(width), message: sizes("rect"))
  #|    assert(finite(height), message: sizes("rect"))
  #|    place(
  #|      left + top,
  #|      dx: at.at(0) * 1pt,
  #|      dy: at.at(1) * 1pt,
  #|      rect(width: width * 1pt, height: height * 1pt, ..args.named()),
  #|    )
  #|  }
  #|
  #|  let circle-item(center, radius, ..args) = {
  #|    assert(finite-point(center), message: coordinates("circle"))
  #|    assert(finite(radius), message: sizes("circle"))
  #|    // By the corner of the square around it.
  #|    place(
  #|      left + top,
  #|      dx: (center.at(0) - radius) * 1pt,
  #|      dy: (center.at(1) - radius) * 1pt,
  #|      circle(radius: radius * 1pt, ..args.named()),
  #|    )
  #|  }
  #|
  #|  let curve-item(start, segments, ..args) = {
  #|    assert(finite-point(start), message: coordinates("curve"))
  #|    assert(finite-path(start, segments), message: coordinates("curve"))
  #|    place(left + top, curve(..args.named(), ..components(start, segments)))
  #|  }
  #|
  #|  let arrow-item(start, segments, ..args) = {
  #|    let named = args.named()
  #|    let head = named.at("head", default: 5.5)
  #|    assert(finite-point(start), message: coordinates("arrow"))
  #|    assert(finite-path(start, segments), message: coordinates("arrow"))
  #|    assert(
  #|      finite(head) and head >= 0,
  #|      message: "the `head` of `Canvas::arrow` must be a finite number of points that is not negative",
  #|    )
  #|    assert(
  #|      segments.len() > 0,
  #|      message: "`Canvas::arrow` needs a segment: a path from `start` to where the arrow points",
  #|    )
  #|    let last = segments.last()
  #|    let tip = last.last()
  #|    // The point that the path arrives at its end from: the last control
  #|    // point of the last segment that is not its end, or where that
  #|    // segment starts.
  #|    let from = none
  #|    let k = last.len() - 2
  #|    while from == none and k >= 1 {
  #|      if last.at(k) != tip { from = last.at(k) }
  #|      k -= 1
  #|    }
  #|    let before = if segments.len() > 1 { segments.at(-2).last() } else { start }
  #|    if from == none and before != tip { from = before }
  #|    let dx = if from == none { 0 } else { tip.at(0) - from.at(0) }
  #|    let dy = if from == none { 0 } else { tip.at(1) - from.at(1) }
  #|    let length = calc.sqrt(dx * dx + dy * dy)
  #|    assert(
  #|      length > 0,
  #|      message: "the last segment of `Canvas::arrow` ends where it starts: the arrow has no direction",
  #|    )
  #|    // The direction of the path at its end; the head is as long as
  #|    // `head` along it and as wide across it, and the path ends half of
  #|    // that before the tip (or half way from where it arrives from).
  #|    let ux = dx / length
  #|    let uy = dy / length
  #|    let half = head / 2
  #|    let reach = length / 2
  #|    let cut = if half < reach { half } else { reach }
  #|    let base-x = tip.at(0) - head * ux
  #|    let base-y = tip.at(1) - head * uy
  #|    let across-x = half * uy
  #|    let across-y = half * ux
  #|    let end = (tip.at(0) - cut * ux, tip.at(1) - cut * uy)
  #|    let path = (..segments.slice(0, -1), (..last.slice(0, -1), end))
  #|    // The paint of the stroke, or the paint of a stroke without one.
  #|    let pen = named.at("stroke", default: auto)
  #|    let paint = if pen == auto or pen == none {
  #|      black
  #|    } else {
  #|      let given = stroke(pen).paint
  #|      if given == auto { black } else { given }
  #|    }
  #|    let drawn = (:)
  #|    if "stroke" in named { drawn.insert("stroke", named.stroke) }
  #|    place(
  #|      left + top,
  #|      place(left + top, curve(..drawn, ..components(start, path))) + place(
  #|        left + top,
  #|        polygon(
  #|          fill: paint,
  #|          pt(tip),
  #|          pt((base-x - across-x, base-y + across-y)),
  #|          pt((base-x + across-x, base-y - across-y)),
  #|        ),
  #|      ),
  #|    )
  #|  }
  #|
  #|  (canvas, place-item, line-item, rect-item, circle-item, curve-item, arrow-item)
  #|};

///|
/// The twins of `@kit.Canvas`.
fn kit_canvas() -> Array[Twin] {
  let hair = Stroke(thickness=Pt(0.5), paint=Luma(120))
  [
    // The items that do not measure: lines, rectangles, circles, curves
    // and content by its anchors.
    twin(
      "kit-canvas",
      [
        canvas_typ, page_typ, "#\"Before.\"",
        // A chart: a grid line, three bars, their labels and a value.
         "#canvas(200, 60, canvas-line((40, 0), (40, 50), stroke: 0.5pt + luma(120)), canvas-rect((40, 5), 90, 10, fill: blue), canvas-rect((40, 20), 120.5, 10, fill: luma(200), stroke: 0.5pt + luma(120), radius: 2pt), canvas-rect((40, 35), 30, 10), canvas-place((36, 10), anchor: (right, horizon))[#\"north\"], canvas-place((36, 25), anchor: (right, horizon), emph[#\"south\"]), canvas-place((36, 45), anchor: (right, bottom))[#\"west\"], canvas-place((40, 52), anchor: (center, top))[#\"0\"], canvas-place((134, 6.5), text(size: 7pt)[#\"9.0\"]), canvas-place((165, 25), anchor: (left, horizon))[#\"two\"#linebreak()#\"lines\"], canvas-circle((180, 45), 6, fill: red, stroke: 1.5pt + white), canvas-circle((192.5, 12), 4))",
        // Paths; content that is not placed; items outside a canvas that
        // clips.
         "#canvas(100, 40, clip: true, [#\"In the block.\"], canvas-curve((0, 40), ((\"line\", (20, 15)), (\"line\", (40, 25)), (\"quad\", (60, 0), (80, 20)), (\"cubic\", (85, 30), (95, 30), (100, 10))), stroke: blue), canvas-curve((0, 40), ((\"line\", (20, 15)), (\"line\", (40, 25)), (\"line\", (40, 40))), fill: luma(220)), canvas-rect((90, 30), 30, 20, fill: red), canvas-place((-4, 20), anchor: (left, bottom))[#\"cut\"])",
        // The same items outside one that does not: over what is beside
        // it.
         "#canvas(100, 12, canvas-rect((90, 4), 30, 16, fill: yellow), canvas-place((100, 0), anchor: (center, top))[#\"out\"])",
        // Nothing to draw; in a container; in the cell of a table; under a
        // `text`; one canvas in two places.
         "#canvas(30, 10)", "#pad(x: 20pt, canvas(60, 20, canvas-rect((0, 0), 60, 20, fill: luma(230)), canvas-place((30, 10), anchor: (center, horizon))[#\"pad\"]))",
        "#table(columns: (60pt, 1fr), [#\"cell\"], canvas(40, 20, canvas-rect((0, 0), 40, 20, fill: luma(210)), canvas-place((40, 20), anchor: (right, bottom))[#\"in\"]))",
        "#text(size: 7pt, fill: blue, canvas(80, 12, canvas-place((0, 0))[#\"small and blue\"]))",
        "#let twice = canvas(50, 14, canvas-rect((0, 0), 50, 14, stroke: 0.5pt + luma(120)), canvas-place((25, 7), anchor: (center, horizon))[#\"twice\"]);#twice#twice",
      ],
      () => {
        let twice = @kit.Canvas(50.0, 14.0, [
          @kit.Canvas::rect((0.0, 0.0), 50.0, 14.0, stroke=Sides(all=hair)),
          @kit.Canvas::place((25.0, 7.0), "twice", anchor=(Center, Horizon)),
        ])
        Document([
          Value::none(),
          page(),
          "Before.",
          @kit.Canvas(200.0, 60.0, [
            @kit.Canvas::line((40.0, 0.0), (40.0, 50.0), stroke=hair),
            @kit.Canvas::rect((40.0, 5.0), 90.0, 10.0, fill=Blue),
            @kit.Canvas::rect(
              (40.0, 20.0),
              120.5,
              10.0,
              fill=Luma(200),
              stroke=Sides(all=hair),
              radius=Corners(all=Pt(2)),
            ),
            @kit.Canvas::rect((40.0, 35.0), 30.0, 10.0),
            @kit.Canvas::place((36.0, 10.0), "north", anchor=(Right, Horizon)),
            @kit.Canvas::place(
              (36.0, 25.0),
              Emph("south"),
              anchor=(Right, Horizon),
            ),
            @kit.Canvas::place((36.0, 45.0), "west", anchor=(Right, Bottom)),
            @kit.Canvas::place((40.0, 52.0), "0", anchor=(Center, Top)),
            @kit.Canvas::place((134.0, 6.5), Text("9.0", size=Pt(7))),
            @kit.Canvas::place(
              (165.0, 25.0),
              Seq(["two", Linebreak(), "lines"]),
              anchor=(Left, Horizon),
            ),
            @kit.Canvas::circle(
              (180.0, 45.0),
              6.0,
              fill=Red,
              stroke=Stroke(thickness=Pt(1.5), paint=White),
            ),
            @kit.Canvas::circle((192.5, 12.0), 4.0),
          ]),
          @kit.Canvas(
            100.0,
            40.0,
            [
              "In the block.",
              @kit.Canvas::curve(
                (0.0, 40.0),
                [
                  LineTo((20.0, 15.0)),
                  LineTo((40.0, 25.0)),
                  QuadTo((60.0, 0.0), (80.0, 20.0)),
                  CubicTo((85.0, 30.0), (95.0, 30.0), (100.0, 10.0)),
                ],
                stroke=Stroke(paint=Blue),
              ),
              @kit.Canvas::curve(
                (0.0, 40.0),
                [
                  LineTo((20.0, 15.0)),
                  LineTo((40.0, 25.0)),
                  LineTo((40.0, 40.0)),
                ],
                fill=Luma(220),
              ),
              @kit.Canvas::rect((90.0, 30.0), 30.0, 20.0, fill=Red),
              @kit.Canvas::place((-4.0, 20.0), "cut", anchor=(Left, Bottom)),
            ],
            clip=true,
          ),
          @kit.Canvas(100.0, 12.0, [
            @kit.Canvas::rect((90.0, 4.0), 30.0, 16.0, fill=Yellow),
            @kit.Canvas::place((100.0, 0.0), "out", anchor=(Center, Top)),
          ]),
          @kit.Canvas(30.0, 10.0, []),
          Pad(
            @kit.Canvas(60.0, 20.0, [
              @kit.Canvas::rect((0.0, 0.0), 60.0, 20.0, fill=Luma(230)),
              @kit.Canvas::place((30.0, 10.0), "pad", anchor=(Center, Horizon)),
            ]),
            x=Pt(20),
          ),
          Table(
            [
              "cell",
              @kit.Canvas(40.0, 20.0, [
                @kit.Canvas::rect((0.0, 0.0), 40.0, 20.0, fill=Luma(210)),
                @kit.Canvas::place((40.0, 20.0), "in", anchor=(Right, Bottom)),
              ]),
            ],
            columns=[Pt(60), Fr(1)],
          ),
          Text(
            @kit.Canvas(80.0, 12.0, [
              @kit.Canvas::place((0.0, 0.0), "small and blue"),
            ]),
            size=Pt(7),
            fill=Blue,
          ),
          // (The binding of `twice` in the markup.)
          Value::none(),
          twice,
          twice,
        ])
      },
    ),
    // Arrows: the path, ending in the head, and the head as a polygon
    // whose corners the function computes as the element does.
    twin(
      "kit-canvas-arrows",
      [
        canvas_typ, page_typ,
        // A diagram: three boxes, a straight arrow, a dashed one, a curve
        // back, a bend with a small head, a dotted quadratic curve with a
        // large one.
         "#canvas(216, 90, canvas-rect((0, 10), 40, 24, fill: luma(235), stroke: 0.5pt + luma(120), radius: 3pt), canvas-place((20, 22), anchor: (center, horizon))[#\"parse\"], canvas-rect((60, 10), 40, 24, fill: luma(225), stroke: 0.5pt + luma(120), radius: 3pt), canvas-place((80, 22), anchor: (center, horizon))[#\"check\"], canvas-rect((120, 10), 40, 24, fill: luma(215), stroke: 0.5pt + luma(120), radius: 3pt), canvas-place((140, 22), anchor: (center, horizon))[#\"emit\"], canvas-arrow((40, 22), ((\"line\", (60, 22)),), stroke: 0.5pt + luma(120)), canvas-arrow((100, 22), ((\"line\", (120, 22)),), stroke: stroke(paint: blue, thickness: 0.8pt, dash: \"dashed\")), canvas-arrow((140, 34), ((\"cubic\", (140, 64), (80, 64), (80, 34)),), stroke: stroke(paint: red, thickness: 0.8pt)), canvas-arrow((20, 34), ((\"line\", (20, 70)), (\"line\", (60, 70))), head: 4), canvas-arrow((170, 40), ((\"quad\", (200, 40), (200, 70)),), stroke: stroke(dash: \"dotted\"), head: 8))",
        // The eight directions, and directions that are not along an axis
        // or a diagonal; a last line that is shorter than the head; a
        // curve whose last control point is its end; no head.
         "#canvas(216, 40, canvas-arrow((20, 20), ((\"line\", (36, 20)),)), canvas-arrow((20, 20), ((\"line\", (32, 32)),)), canvas-arrow((20, 20), ((\"line\", (20, 36)),)), canvas-arrow((20, 20), ((\"line\", (8, 32)),)), canvas-arrow((20, 20), ((\"line\", (4, 20)),)), canvas-arrow((20, 20), ((\"line\", (8, 8)),)), canvas-arrow((20, 20), ((\"line\", (20, 4)),)), canvas-arrow((20, 20), ((\"line\", (32, 8)),)), canvas-arrow((60, 5), ((\"line\", (97, 31.5)),), stroke: luma(100)), canvas-arrow((130, 36), ((\"line\", (101.3, 2.9)),), stroke: 1.7pt + green, head: 9.3), canvas-arrow((140, 10), ((\"line\", (140, 30)), (\"line\", (142.5, 31))), head: 6), canvas-arrow((150, 30), ((\"cubic\", (160, 0), (183.7, 12.1), (183.7, 12.1)),), stroke: 0.7pt + purple), canvas-arrow((190, 5), ((\"line\", (210, 35)),), head: 0))",
      ],
      () => {
        let box = (x : Double, shade : Int) => {
          @kit.Canvas::rect(
            (x, 10.0),
            40.0,
            24.0,
            fill=Luma(shade),
            stroke=Sides(all=hair),
            radius=Corners(all=Pt(3)),
          )
        }
        let centre : (@kit.AnchorX, @kit.AnchorY) = (Center, Horizon)
        Document([
          Value::none(),
          page(),
          @kit.Canvas(216.0, 90.0, [
            box(0.0, 235),
            @kit.Canvas::place((20.0, 22.0), "parse", anchor=centre),
            box(60.0, 225),
            @kit.Canvas::place((80.0, 22.0), "check", anchor=centre),
            box(120.0, 215),
            @kit.Canvas::place((140.0, 22.0), "emit", anchor=centre),
            @kit.Canvas::arrow(
              (40.0, 22.0),
              [LineTo((60.0, 22.0))],
              stroke=hair,
            ),
            @kit.Canvas::arrow(
              (100.0, 22.0),
              [LineTo((120.0, 22.0))],
              stroke=Stroke(paint=Blue, thickness=Pt(0.8), dash=Dashed),
            ),
            @kit.Canvas::arrow(
              (140.0, 34.0),
              [CubicTo((140.0, 64.0), (80.0, 64.0), (80.0, 34.0))],
              stroke=Stroke(paint=Red, thickness=Pt(0.8)),
            ),
            @kit.Canvas::arrow(
              (20.0, 34.0),
              [LineTo((20.0, 70.0)), LineTo((60.0, 70.0))],
              head=4.0,
            ),
            @kit.Canvas::arrow(
              (170.0, 40.0),
              [QuadTo((200.0, 40.0), (200.0, 70.0))],
              stroke=Stroke(dash=Dotted),
              head=8.0,
            ),
          ]),
          @kit.Canvas(216.0, 40.0, [
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((36.0, 20.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((32.0, 32.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((20.0, 36.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((8.0, 32.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((4.0, 20.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((8.0, 8.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((20.0, 4.0))]),
            @kit.Canvas::arrow((20.0, 20.0), [LineTo((32.0, 8.0))]),
            @kit.Canvas::arrow(
              (60.0, 5.0),
              [LineTo((97.0, 31.5))],
              stroke=Stroke(paint=Luma(100)),
            ),
            @kit.Canvas::arrow(
              (130.0, 36.0),
              [LineTo((101.3, 2.9))],
              stroke=Stroke(thickness=Pt(1.7), paint=Green),
              head=9.3,
            ),
            @kit.Canvas::arrow(
              (140.0, 10.0),
              [LineTo((140.0, 30.0)), LineTo((142.5, 31.0))],
              head=6.0,
            ),
            @kit.Canvas::arrow(
              (150.0, 30.0),
              [CubicTo((160.0, 0.0), (183.7, 12.1), (183.7, 12.1))],
              stroke=Stroke(thickness=Pt(0.7), paint=Purple),
            ),
            @kit.Canvas::arrow((190.0, 5.0), [LineTo((210.0, 35.0))], head=0.0),
          ]),
        ])
      },
    ),
    // The anchor `Baseline`: the item measures its body in the size of
    // the canvas. And a canvas at the end of a page, which moves as a
    // whole.
    twin(
      "kit-canvas-baseline",
      [
        canvas_typ, page_typ,
        // Bodies of several sizes and kinds on one line.
         "#canvas(200, 40, canvas-line((0, 30), (200, 30), stroke: 0.5pt + luma(120)), canvas-place((50, 30), anchor: (right, \"baseline\"), text(size: 20pt)[#\"38\"]), canvas-place((52, 30), anchor: (left, \"baseline\"))[#\"kg\"], canvas-place((110, 30), anchor: (center, \"baseline\"), block(inset: 4pt, fill: luma(230))[#\"inset\"]), canvas-place((200, 30), anchor: (right, \"baseline\"), text(bottom-edge: \"descender\")[#\"edge\"]))",
        // A body that is broken at the width of the canvas.
         "#canvas(40, 36, canvas-place((0, 12), anchor: (left, \"baseline\"))[#\"Tag \"#text(size: 16pt)[#\"large\"]])",
        // What is left of the page does not hold the canvas.
         "#par[#\"A paragraph with a note\"#footnote[#\"The note at the foot.\"]#\".\"]",
        "#v(20pt)", "#canvas(150, 40, canvas-rect((0, 0), 150, 40, fill: luma(230)), canvas-place((75, 20), anchor: (center, \"baseline\"))[#\"moved\"])",
        "#\"After.\"",
      ],
      () => {
        Document([
          Value::none(),
          page(),
          @kit.Canvas(200.0, 40.0, [
            @kit.Canvas::line((0.0, 30.0), (200.0, 30.0), stroke=hair),
            @kit.Canvas::place(
              (50.0, 30.0),
              Text("38", size=Pt(20)),
              anchor=(Right, Baseline),
            ),
            @kit.Canvas::place((52.0, 30.0), "kg", anchor=(Left, Baseline)),
            @kit.Canvas::place(
              (110.0, 30.0),
              Block("inset", inset=Sides(all=Pt(4)), fill=Luma(230)),
              anchor=(Center, Baseline),
            ),
            @kit.Canvas::place(
              (200.0, 30.0),
              Text("edge", bottom_edge=Descender),
              anchor=(Right, Baseline),
            ),
          ]),
          @kit.Canvas(40.0, 36.0, [
            @kit.Canvas::place(
              (0.0, 12.0),
              Seq(["Tag ", Text("large", size=Pt(16))]),
              anchor=(Left, Baseline),
            ),
          ]),
          Par(
            Seq([
              "A paragraph with a note",
              Footnote("The note at the foot."),
              ".",
            ]),
          ),
          V(Pt(20)),
          @kit.Canvas(150.0, 40.0, [
            @kit.Canvas::rect((0.0, 0.0), 150.0, 40.0, fill=Luma(230)),
            @kit.Canvas::place((75.0, 20.0), "moved", anchor=(Center, Baseline)),
          ]),
          "After.",
        ])
      },
    ),
  ]
}
