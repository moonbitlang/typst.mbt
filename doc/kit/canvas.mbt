// `Canvas` (docs/edsl-ports.md, section 4; findings H6, S2a, M4 and T11):
// a drawing surface with a coordinate system of its own, and the items
// that are placed on it.

///|
/// A drawing surface for a chart or a diagram: a box of a fixed size whose
/// items are placed by coordinates.
///
/// ```mbt nocheck
/// Canvas(180.0, 60.0, [
///   Canvas::line((0.0, 50.0), (180.0, 50.0), stroke=axis),
///   Canvas::rect((20.0, 10.0), 30.0, 40.0, fill=Blue),
///   Canvas::place((35.0, 54.0), "beans", anchor=(Center, Top)),
///   Canvas::arrow((60.0, 30.0), [LineTo((120.0, 30.0))], stroke=pen),
/// ])
/// ```
///
/// It is `Block(Seq(items), width=Pt(width), height=Pt(height),
/// breakable=false)`, every item in `Keyed` with its key. What it does that
/// a `Block` of that size does not:
///
/// - **One region, so one coordinate system.** The block is unbreakable. A
///   block with a fixed height that meets the end of a page is split, and
///   what is placed in it is drawn from the top of its first part, which is
///   only as high as what was left of the page: over the footnotes and the
///   margin (finding S2a). A canvas that does not fit the rest of the page
///   moves to the next page as a whole. One that is higher than a page
///   fits no page and leaves it, without a diagnostic, like any unbreakable
///   block.
/// - **The items are told apart.** Items that a loop builds are on one
///   line of the source; each is under a key.
///
/// The coordinate system: the origin is the top left corner of the canvas,
/// x grows to the right and y down, as for `Place` (and in SVG). The unit
/// is the point, and a coordinate is a `Double`: a point is `(x, y)`. There
/// is no parameter for another unit or another direction: a chart's y axis
/// that grows upwards is the range of its scale (`y = v => bottom - (v -
/// lo) / (hi - lo) * (bottom - top)`), and a drawing in other units is
/// `Scale(canvas, factor=Pct(56.7), reflow=true)`, which also scales its
/// strokes and its text.
///
/// The size is fixed, in points. For a canvas as wide as its container,
/// build it in a `Layout`, which gives the width: `Layout((size, _) =>
/// Canvas(size.width, 80.0, chart(size.width)))`. A canvas has no callback
/// of its own, so it can be built there, and in every other callback.
///
/// The items ([CanvasItem]) are made by `Canvas::place`, `Canvas::line`,
/// `Canvas::rect`, `Canvas::circle`, `Canvas::curve` and `Canvas::arrow`.
/// They are drawn in their order, the later over the earlier. An item is
/// content, and `items` holds content: an item under a key of the caller
/// (`Keyed(bed.name, item)`), several as one (`Seq([bar, label])`, what a
/// function of the caller returns for one row of its data), and anything
/// else, which is laid out in the block from its top left corner as in any
/// block, and drawn in its place among the items (an image as the first
/// item is under the drawing). A rule is not an item (a rule goes
/// into a `Seq`): text is styled by a `Text` around the canvas or around
/// the body of an item, or by a rule in a `Seq` with the items it is for.
///
/// What is not here: nodes with names and edges that find their way
/// between them, axes, legends and kinds of charts. A chart is the
/// caller's loop over its data with a scale of its own; `@format.ticks`
/// gives the values of the ticks.
///
/// It does not measure and creates no callback. (An item with the anchor
/// `Baseline` does: see `Canvas::place`.)
///
/// Parameters:
///
/// - `width`, `height`: the size in points; not negative.
/// - `items`: what is drawn.
/// - `clip`: `Block`'s. By default the block's: not clipped. What is
///   placed outside the canvas is drawn there, over what is beside the
///   canvas: half of the stroke of a line on its edge, and the ends of a
///   label that is centred at its side, are outside by design.
///   `clip=true` cuts them off.
/// - `key`: the key of item `i`, for the review loop; by default its index
///   (`"0"`, `"1"`, ..). A key that `Keyed` does not take (one that starts
///   with U+FDD2) is an error at `key`.
///
/// Not parameters: a fill, a stroke, an inset. A panel around a drawing is
/// a `Block` around the canvas, and its background is the first item
/// (`Canvas::rect((0.0, 0.0), width, height, fill=..)`).
///
/// Provenance: the call, for the block. Every item is a call site of its
/// own (see [CanvasItem]): a selection of a bar is the line that drew it,
/// under the key of the item. An item that is a plain string resolves to
/// the `items` argument under its key.
///
/// Twin: the function `canvas` of `doc/twins/kit_canvas.mbt`.
pub struct Canvas {
  priv composite : @doc.Composite
}

///|
/// An item of a [Canvas]: content that is placed at a point of the box
/// that holds it. Every item is one `Place`, with the alignment
/// `Both(Left, Top)` (the anchors of `Canvas::place` have others): it
/// takes no room, so the items of a canvas do not move each other.
///
/// Positions and sizes are numbers of the coordinate system (`Double`, in
/// points). What a shape is drawn in (`stroke`, `fill`, `radius`) has the
/// name and the type of the parameter of the primitive, and is passed on
/// as it is.
///
/// Every item is a call site of its own: what it draws resolves to the
/// call of `Canvas::rect(..)`, not to the canvas, and an error in its
/// `fill` is at that argument. Items that one line of a loop makes are
/// told apart by the keys that the canvas gives them.
///
/// Outside of a canvas an item is a `Place` in the container that it is
/// in, whose origin, size and breaking are that container's.
pub struct CanvasItem {
  priv composite : @doc.Composite
}

///|
/// The side of a body that is at the x coordinate of its point: its left
/// edge, its middle or its right edge. (`Place`'s horizontal alignments
/// that do not depend on the direction of the text.)
pub(all) enum AnchorX {
  Left
  Center
  Right
}

///|
/// The side of a body that is at the y coordinate of its point: its top
/// edge, its middle, its bottom edge (`Place`'s vertical alignments), or
/// the baseline of its first line.
///
/// `Baseline` **measures**: see `Canvas::place`. One line of text with the
/// default edges of text ends at its baseline, so `Bottom` puts it on its
/// baseline without measuring.
pub(all) enum AnchorY {
  Top
  Horizon
  Bottom
  Baseline
}

///|
/// A segment of a path on a canvas, from the point where the path is to
/// the last point of the segment: a straight line, or a quadratic or cubic
/// Bézier curve with its control points first (the components
/// `CurveLine`, `CurveQuad` and `CurveCubic` of `Curve`, in the
/// coordinates of the canvas).
pub(all) enum Segment {
  LineTo((Double, Double))
  QuadTo((Double, Double), (Double, Double))
  CubicTo((Double, Double), (Double, Double), (Double, Double))
}

///|
/// The points of a segment: its control points, then its last point.
fn Segment::points(self : Segment) -> Array[(Double, Double)] {
  match self {
    LineTo(end) => [end]
    QuadTo(control, end) => [control, end]
    CubicTo(first, second, end) => [first, second, end]
  }
}

///|
/// The last point of a segment.
fn Segment::end(self : Segment) -> (Double, Double) {
  match self {
    LineTo(end) | QuadTo(_, end) | CubicTo(_, _, end) => end
  }
}

///|
/// The segment with its last point moved to `end`. The control points
/// that are at the last point, from the last one backwards, move with it:
/// they give the segment no direction there, and left behind they would
/// turn the path back at its end.
fn Segment::ending_at(self : Segment, end : (Double, Double)) -> Segment {
  match self {
    LineTo(_) => LineTo(end)
    QuadTo(control, old) =>
      if same_point(control, old) {
        QuadTo(end, end)
      } else {
        QuadTo(control, end)
      }
    CubicTo(first, second, old) =>
      if !same_point(second, old) {
        CubicTo(first, second, end)
      } else if same_point(first, old) {
        CubicTo(end, end, end)
      } else {
        CubicTo(first, end, end)
      }
  }
}

///|
/// Whether two points are the same point.
fn same_point(a : (Double, Double), b : (Double, Double)) -> Bool {
  a.0 == b.0 && a.1 == b.1
}

///|
/// Whether a coordinate is a number that can be placed.
fn finite(value : Double) -> Bool {
  !(value.is_nan() || value.is_inf())
}

///|
/// Whether the coordinates of a point are.
fn finite_point(point : (Double, Double)) -> Bool {
  finite(point.0) && finite(point.1)
}

///|
/// A point as lengths.
fn lengths(point : (Double, Double)) -> (@doc.Length, @doc.Length) {
  (Pt(point.0), Pt(point.1))
}

///|
/// The alignment of the items that are placed by their top left corner.
fn top_left() -> @doc.Alignment {
  Both(Left, Top)
}

///|
/// The message for a coordinate that is not a number.
fn not_finite(what : String, item : String) -> String {
  "\{what} of `\{item}` must be finite numbers of points"
}

///|
/// The component of a `Curve` that a segment is.
fn Segment::component(self : Segment) -> @doc.Content {
  match self {
    LineTo(end) => @doc.Content(@doc.CurveLine(lengths(end)))
    QuadTo(control, end) =>
      @doc.Content(@doc.CurveQuad(lengths(control), lengths(end)))
    CubicTo(first, second, end) =>
      @doc.Content(
        @doc.CurveCubic(lengths(first), lengths(second), lengths(end)),
      )
  }
}

///|
/// The components of the `Curve` of a path.
fn components(
  start : (Double, Double),
  segments : Array[Segment],
) -> Array[&@doc.IntoContent] {
  let out : Array[&@doc.IntoContent] = [@doc.CurveMove(lengths(start))]
  for segment in segments {
    out.push(segment.component())
  }
  out
}

///|
/// Whether every point of a path is finite.
fn finite_path(start : (Double, Double), segments : Array[Segment]) -> Bool {
  guard finite_point(start) else { return false }
  for segment in segments {
    for point in segment.points() {
      guard finite_point(point) else { return false }
    }
  }
  true
}

///|
#callsite(autofill(loc, args_loc))
pub fn Canvas::Canvas(
  width : Double,
  height : Double,
  items : Array[&@doc.IntoContent],
  clip? : Bool,
  key? : (Int) -> String,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Canvas {
  // The keys of the items. (`key` is a function of the caller: it runs
  // before the hook, where what it builds has its own call sites.)
  let keys = Array::makei(items.length(), k => {
    match key {
      Some(key) => key(k)
      None => k.to_string()
    }
  })
  // The parameters by their index in this declaration, for `site.arg`:
  // width 0, height 1, items 2, clip 3, key 4.
  let composite = @doc.Composite("Canvas", loc, args_loc, site => {
    if !finite(width) || width < 0.0 {
      return site.invalid(
        "the `width` of a `Canvas` must be a finite number of points that is not negative",
        arg=0,
      )
    }
    if !finite(height) || height < 0.0 {
      return site.invalid(
        "the `height` of a `Canvas` must be a finite number of points that is not negative",
        arg=1,
      )
    }
    // A key that `Keyed` does not take is an error at `key`, not at the
    // item that would carry it.
    for k, key in keys {
      if key.has_prefix("\u{FDD2}") {
        return site.invalid(
          "the key of `items[\{k}]` starts with a reserved character (U+FDD2)",
          arg=4,
        )
      }
    }
    // (A copy, and the caller's content converted once: a description does
    // not change when the caller's array does.)
    let children : Array[&@doc.IntoContent] = []
    for k, item in items {
      children.push(@doc.Keyed(keys[k], @doc.Content(item)))
    }
    @doc.Block(
      @doc.Seq(site.arg(2, children)),
      width=site.arg(0, @doc.Length::Pt(width)),
      height=site.arg(1, @doc.Sizing::Pt(height)),
      // One region: the items are placed once.
      breakable=false,
      clip?=site.arg(3, clip),
    )
  })
  { composite, }
}

///|
/// The offset of a `Place` that puts the side `side` of its body (0: the
/// start, 1: the middle, 2: the end) at `at`. The alignment puts that side
/// of the body at that side of the container, which is `side × 50%` of the
/// container: the offset takes that back, in the engine's arithmetic, so
/// the item does not have to know the size of what holds it.
fn offset(at : Double, side : Int) -> @doc.Length {
  match side {
    0 => Pt(at)
    1 => Diff(Pt(at), Pct(50.0))
    _ => Diff(Pt(at), Pct(100.0))
  }
}

///|
/// Content at a point of the canvas: a label, or anything else (a `Prose`,
/// a `Chip`, an `Equation`, a `Rect` with a body, an `Image`).
///
/// ```mbt nocheck
/// Canvas::place((x, bottom + 4.0), Text(name, size=Pt(7)), anchor=(Center, Top))
/// ```
///
/// It is `Place(body, alignment=Both(h, v), dx=.., dy=..)` with the
/// alignment that `anchor` names, and the offsets that put that side of the
/// body at `at`: `Pt(x)` for `Left`, `Pt(x) - 50%` for `Center`, `Pt(x) -
/// 100%` for `Right`, and likewise `Top`, `Horizon` and `Bottom` for `y`.
/// The engine aligns the body in the box that holds it and takes the same
/// share of that box back, so nothing is measured, and the item can be
/// built anywhere, also inside a callback. As in every `Place`, the
/// alignment is also that of the body's own lines: a label of two lines
/// that is anchored at its `Center` has its lines centred.
///
/// - `at`: the point `(x, y)`.
/// - `body`: what is placed. It is laid out in the size of the canvas: a
///   text that is longer than the canvas is wide is broken into lines.
/// - `anchor`: the sides of the body that are at the point,
///   `(Left | Center | Right, Top | Horizon | Bottom | Baseline)`; by
///   default `(Left, Top)`, the corner that `Place` places. `Horizon` of a
///   line of text is the middle between the top of its capitals and its
///   baseline (the default edges of text): a label is centred on a bar
///   with `(Right, Horizon)` at the middle of the bar.
///
/// **With `Baseline` it measures.** The first baseline of the body is not
/// an alignment of the engine: the body is measured (`Size.baseline`) in
/// the size of the canvas and under the alignment that it is placed with,
/// and placed with its top that far above the point. The item is then
/// `Place(Layout(..), alignment=Both(Left, Top))` around that `Place`,
/// and it creates a callback: it cannot be built inside one (a show rule,
/// a `Context`, a `Layout`, so also not for a canvas that is built in a
/// `Layout` for its width). There, use `Bottom` for a line of text, which
/// ends at its baseline, or measure with the callback's own context
/// (`cx.measure(body).baseline`, with the width of the canvas for a body
/// that is broken into lines there) and anchor at `Top`. Nothing else
/// differs: the canvas is one region whatever its
/// items are, and in a box without a size the body is measured without
/// one, as it is placed there.
///
/// The style of text is not a parameter: the body is a `Text(..)`, or the
/// canvas is in one.
///
/// Provenance: the call. A body that is a plain string resolves to the
/// `body` argument, and with the source at hand to the characters of its
/// literal; a description of the caller keeps its own call.
///
/// Twin: the function `canvas-place` of `doc/twins/kit_canvas.mbt`.
#callsite(autofill(loc, args_loc))
pub fn Canvas::place(
  at : (Double, Double),
  body : &@doc.IntoContent,
  anchor? : (AnchorX, AnchorY) = (Left, Top),
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CanvasItem {
  // The parameters by their index in this declaration, for `site.arg`:
  // at 0, body 1, anchor 2.
  let composite = @doc.Composite("Canvas::place", loc, args_loc, site => {
    guard finite_point(at) else {
      return site.invalid(not_finite("the coordinates", "Canvas::place"), arg=0)
    }
    let (x, y) = at
    // (The caller's content converted once: the callback of the measuring
    // form runs whenever the canvas is laid out.)
    let body = @doc.Content(body)
    let (horizontal, dx) : (@doc.Alignment, @doc.Length) = match anchor.0 {
      Left => (Left, offset(x, 0))
      Center => (Center, offset(x, 1))
      Right => (Right, offset(x, 2))
    }
    let (vertical, dy) : (@doc.Alignment, @doc.Length) = match anchor.1 {
      Top => (Top, offset(y, 0))
      Horizon => (Horizon, offset(y, 1))
      Bottom => (Bottom, offset(y, 2))
      Baseline => {
        // What is measured and what is placed is the same description,
        // in the same region and under the same styles: a `Place` lays
        // its body out in the size of its container without stretching
        // it, which is what `measure` does with a width and a height, and
        // it sets its alignment for its body, which an `Align` around
        // what is measured does. (The alignment of the lines of a body
        // does not move its first baseline, but a body can read it: a
        // `Context` in the caller's content.)
        let alignment : @doc.Alignment = Both(horizontal, Top)
        let measured = @doc.Layout((size, cx) => {
          let width : @doc.Length? = if size.width.is_inf() {
            None
          } else {
            Some(Pt(size.width))
          }
          let height : @doc.Length? = if size.height.is_inf() {
            None
          } else {
            Some(Pt(size.height))
          }
          let baseline = cx.measure(
              @doc.Align(alignment, body),
              width?,
              height?,
            ).baseline
          @doc.Place(
            site.arg(1, body),
            alignment~,
            dx~,
            // (A difference of lengths, which the engine takes: it keeps
            // lengths in a unit of its own, so the difference of the
            // numbers of points is not always the same length.)
            dy=Diff(Pt(y), Pt(baseline)),
          )
        })
        // The callback is a block: placed, it takes no room among the
        // items and starts at the origin, where the body is placed in it
        // (the offsets do not depend on the size of what they are in).
        return @doc.Content(@doc.Place(measured, alignment=top_left()))
      }
    }
    @doc.Content(
      @doc.Place(
        site.arg(1, body),
        alignment=Both(horizontal, vertical),
        dx~,
        dy~,
      ),
    )
  })
  { composite, }
}

///|
/// A straight line from `start` to `end_`: `Place(Line(start=.., end_=..,
/// stroke~), alignment=Both(Left, Top))`, the points as they are given.
///
/// - `stroke`: `Line`'s; by default the line's (1pt, black, or what a
///   `SetLine(stroke=..)` of the document sets).
///
/// A line through several points is a `Canvas::curve` of `LineTo`s, which
/// joins them.
///
/// Twin: the function `canvas-line` of `doc/twins/kit_canvas.mbt`.
#callsite(autofill(loc, args_loc))
pub fn Canvas::line(
  start : (Double, Double),
  end_ : (Double, Double),
  stroke? : @doc.Stroke,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CanvasItem {
  // The parameters by their index: start 0, end_ 1, stroke 2.
  let composite = @doc.Composite("Canvas::line", loc, args_loc, site => {
    guard finite_point(start) else {
      return site.invalid(not_finite("the coordinates", "Canvas::line"), arg=0)
    }
    guard finite_point(end_) else {
      return site.invalid(not_finite("the coordinates", "Canvas::line"), arg=1)
    }
    @doc.Place(
      @doc.Line(
        start=site.arg(0, lengths(start)),
        end_=site.arg(1, lengths(end_)),
        stroke?=site.arg(2, stroke),
      ),
      alignment=top_left(),
    )
  })
  { composite, }
}

///|
/// A rectangle with its top left corner at `at`: `Place(Rect(width=..,
/// height=.., fill~, stroke~, radius~), alignment=Both(Left, Top), dx=..,
/// dy=..)`.
///
/// - `width`, `height`: its size in points.
/// - `fill`, `stroke`, `radius`: `Rect`'s; by default the rectangle's (no
///   fill, and then a stroke of 1pt in black; square corners).
///
/// A rectangle with a body or an inset is a `Rect` that is placed:
/// `Canvas::place(at, Rect(.., body=..))`. A box of a diagram with its text
/// in the middle is a `Canvas::rect` and a `Canvas::place` at its centre
/// with the anchor `(Center, Horizon)`.
///
/// Twin: the function `canvas-rect` of `doc/twins/kit_canvas.mbt`.
#callsite(autofill(loc, args_loc))
pub fn Canvas::rect(
  at : (Double, Double),
  width : Double,
  height : Double,
  fill? : @doc.Paint,
  stroke? : @doc.Sides[@doc.Stroke],
  radius? : @doc.Corners[@doc.Length],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CanvasItem {
  // The parameters by their index: at 0, width 1, height 2, fill 3,
  // stroke 4, radius 5.
  let composite = @doc.Composite("Canvas::rect", loc, args_loc, site => {
    guard finite_point(at) else {
      return site.invalid(not_finite("the coordinates", "Canvas::rect"), arg=0)
    }
    guard finite(width) else {
      return site.invalid(not_finite("the sizes", "Canvas::rect"), arg=1)
    }
    guard finite(height) else {
      return site.invalid(not_finite("the sizes", "Canvas::rect"), arg=2)
    }
    @doc.Place(
      @doc.Rect(
        width=site.arg(1, @doc.Length::Pt(width)),
        height=site.arg(2, @doc.Sizing::Pt(height)),
        fill?=site.arg(3, fill),
        stroke?=site.arg(4, stroke),
        radius?=site.arg(5, radius),
      ),
      alignment=top_left(),
      dx=site.arg(0, @doc.Length::Pt(at.0)),
      dy=site.arg(0, @doc.Length::Pt(at.1)),
    )
  })
  { composite, }
}

///|
/// A circle around `center`: `Place(Circle(radius=.., fill~, stroke~),
/// alignment=Both(Left, Top), dx=.., dy=..)`, placed by the corner of the
/// square around it (`center - radius`).
///
/// - `radius`: in points.
/// - `fill`, `stroke`: `Circle`'s; by default the circle's (no fill, and
///   then a stroke of 1pt in black).
///
/// Twin: the function `canvas-circle` of `doc/twins/kit_canvas.mbt`.
#callsite(autofill(loc, args_loc))
pub fn Canvas::circle(
  center : (Double, Double),
  radius : Double,
  fill? : @doc.Paint,
  stroke? : @doc.Stroke,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CanvasItem {
  // The parameters by their index: center 0, radius 1, fill 2, stroke 3.
  let composite = @doc.Composite("Canvas::circle", loc, args_loc, site => {
    guard finite_point(center) else {
      return site.invalid(
        not_finite("the coordinates", "Canvas::circle"),
        arg=0,
      )
    }
    guard finite(radius) else {
      return site.invalid(not_finite("the sizes", "Canvas::circle"), arg=1)
    }
    @doc.Place(
      @doc.Circle(
        radius=site.arg(1, @doc.Length::Pt(radius)),
        fill?=site.arg(2, fill),
        stroke?=site.arg(3, stroke),
      ),
      alignment=top_left(),
      dx=Pt(center.0 - radius),
      dy=Pt(center.1 - radius),
    )
  })
  { composite, }
}

///|
/// A path from `start` through `segments`: `Place(Curve([CurveMove(start),
/// ..], fill~, stroke~), alignment=Both(Left, Top))`, each segment the
/// component of `Curve` that it names, the points as they are given.
///
/// ```mbt nocheck
/// Canvas::curve(points[0], points[1:].map(p => LineTo(p)), stroke=pen)
/// ```
///
/// - `fill`, `stroke`: `Curve`'s; by default the curve's (no fill, and
///   then a stroke of 1pt in black). A path with a fill is filled as if it
///   were closed.
///
/// A path of several parts, a closed one, or one with points that are
/// relative to each other is a `Curve` of `doc`'s own components, placed
/// at the origin: `Canvas::place((0.0, 0.0), Curve([..]))`.
///
/// Twin: the function `canvas-curve` of `doc/twins/kit_canvas.mbt`.
#callsite(autofill(loc, args_loc))
pub fn Canvas::curve(
  start : (Double, Double),
  segments : Array[Segment],
  fill? : @doc.Paint,
  stroke? : @doc.Stroke,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CanvasItem {
  // (A copy: a description does not change when the caller's array does.)
  let segments = segments.copy()
  // The parameters by their index: start 0, segments 1, fill 2, stroke 3.
  let composite = @doc.Composite("Canvas::curve", loc, args_loc, site => {
    guard finite_point(start) else {
      return site.invalid(not_finite("the coordinates", "Canvas::curve"), arg=0)
    }
    guard finite_path(start, segments) else {
      return site.invalid(not_finite("the coordinates", "Canvas::curve"), arg=1)
    }
    @doc.Place(
      @doc.Curve(
        components(start, segments),
        fill?=site.arg(2, fill),
        stroke?=site.arg(3, stroke),
      ),
      alignment=top_left(),
    )
  })
  { composite, }
}

///|
/// The head of an arrow: the three corners of its triangle, and the point
/// where the path of the arrow ends, inside it.
priv struct ArrowHead {
  tip : (Double, Double)
  left : (Double, Double)
  right : (Double, Double)
  end : (Double, Double)
}

///|
/// The head of an arrow whose path arrives at `tip` from `from`: a triangle
/// as long as `size` along the path and as wide across it, with its tip at
/// `tip`. The path ends half of `size` before the tip (or, where `from` is
/// nearer than `size`, half way from `from`), so that its stroke ends
/// inside the head and the point of the triangle is the point of the
/// arrow. `None` if there is no direction: `from` is `tip`, or the two are
/// farther apart than a number can say.
fn arrow_head(
  from : (Double, Double),
  tip : (Double, Double),
  size : Double,
) -> ArrowHead? {
  let dx = tip.0 - from.0
  let dy = tip.1 - from.1
  // The direction of the path at its end. The differences are divided by
  // the larger of them before they are squared, so that neither a very
  // small nor a very large one leaves the range of numbers.
  let scale = if dx.abs() > dy.abs() { dx.abs() } else { dy.abs() }
  guard scale > 0.0 && finite(scale) else { return None }
  let sx = dx / scale
  let sy = dy / scale
  let squares = sx * sx + sy * sy
  let norm = squares.sqrt()
  let ux = sx / norm
  let uy = sy / norm
  let length = scale * norm
  let half = size / 2.0
  let reach = length / 2.0
  let cut = if half < reach { half } else { reach }
  // The middle of the side of the triangle that is across the path.
  let back_x = size * ux
  let back_y = size * uy
  let base_x = tip.0 - back_x
  let base_y = tip.1 - back_y
  let across_x = half * uy
  let across_y = half * ux
  let cut_x = cut * ux
  let cut_y = cut * uy
  Some({
    tip,
    left: (base_x - across_x, base_y + across_y),
    right: (base_x + across_x, base_y - across_y),
    end: (tip.0 - cut_x, tip.1 - cut_y),
  })
}

///|
/// The point that a path arrives at the end of its last segment from: the
/// last control point of that segment that is not its end, or the point
/// where the segment starts. `None` if they are all the end.
fn arriving_from(
  before : (Double, Double),
  last : Segment,
) -> (Double, Double)? {
  let end = last.end()
  let points = last.points()
  // (The last of `points` is the end itself.)
  for k = points.length() - 2; k >= 0; k = k - 1 {
    if !same_point(points[k], end) {
      return Some(points[k])
    }
  }
  if same_point(before, end) {
    None
  } else {
    Some(before)
  }
}

///|
/// An arrow: a path from `start` through `segments` with a head at its
/// end.
///
/// ```mbt nocheck
/// Canvas::arrow(parse.right(), [LineTo(check.left())], stroke=pen)
/// Canvas::arrow(a, [CubicTo((ax, ay + 30.0), (bx, by + 30.0), b)],
///   stroke=Stroke(paint=Blue, dash=Dashed))
/// ```
///
/// It is the `Curve` of `Canvas::curve` and a `Polygon`, each placed at the
/// origin of one `Place`: `Place(Seq([Place(Curve(.., stroke~)),
/// Place(Polygon([tip, left, right], fill=..))]))`, every alignment
/// `Both(Left, Top)`.
///
/// - **The head** is a filled triangle with its tip at the last point of
///   the path, as long as `head` along the path and as wide across it. It
///   points in the direction in which the path arrives: of the last line,
///   or of the tangent at the end of the last curve (from its last control
///   point).
/// - **The path ends inside the head**, half of `head` before the tip, so
///   that the end of its stroke does not show beside the tip. The last
///   point of the last segment is moved back along the direction of
///   arrival, and a control point that is at that point with it, which
///   keeps the direction. (Where the last line, or the last control
///   point, is nearer to the tip than `head`: half way.)
/// - **The paint of the head is the paint of the stroke**, as the stroke
///   was written (`@doc.Stroke::paint`), or black for a stroke without a
///   paint, which is what such a stroke is drawn in unless a rule of the
///   document (`SetCurve(stroke=..)`) says otherwise: an arrow in a colour
///   names it in its `stroke`. The polygon has that fill and no stroke of
///   its own; like every part of an element it is under the rules of the
///   document (`SetPolygon(stroke=..)` gives the heads an outline).
///
/// Parameters:
///
/// - `start`, `segments`: the path, as for `Canvas::curve`. An arrow with
///   a bend is two `LineTo`s; one that curves back is a `CubicTo`.
/// - `stroke`: `Curve`'s, for the path; by default the curve's (1pt,
///   black). Dashed and dotted arrows are `Stroke(dash=Dashed)` and
///   `Stroke(dash=Dotted)`: the stroke is the path's, the head is filled.
/// - `head`: the length and the width of the head in points; 5.5 by
///   default (the element's own; for strokes of about 1pt). Not negative.
///
/// Errors, when the document is compiled: no segments (at `segments`), and
/// a path whose last segment ends where it starts, with its control points
/// there too, which arrives from no direction (at `segments`; also where
/// the two points are so far apart that their difference is not a
/// number).
///
/// What an arrow does not have: a head at its start, heads of other shapes
/// (open, barbed, round), a width of the head that is not its length. Such
/// an arrow is a `Canvas::curve` and a `Polygon` of the caller.
///
/// Twin: the function `canvas-arrow` of `doc/twins/kit_canvas.mbt`.
#callsite(autofill(loc, args_loc))
pub fn Canvas::arrow(
  start : (Double, Double),
  segments : Array[Segment],
  stroke? : @doc.Stroke,
  head? : Double = 5.5,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CanvasItem {
  // (A copy: a description does not change when the caller's array does.)
  let segments = segments.copy()
  // The parameters by their index: start 0, segments 1, stroke 2, head 3.
  let composite = @doc.Composite("Canvas::arrow", loc, args_loc, site => {
    guard finite_point(start) else {
      return site.invalid(not_finite("the coordinates", "Canvas::arrow"), arg=0)
    }
    guard finite_path(start, segments) else {
      return site.invalid(not_finite("the coordinates", "Canvas::arrow"), arg=1)
    }
    guard finite(head) && head >= 0.0 else {
      return site.invalid(
        "the `head` of `Canvas::arrow` must be a finite number of points that is not negative",
        arg=3,
      )
    }
    guard segments.last() is Some(last) else {
      return site.invalid(
        "`Canvas::arrow` needs a segment: a path from `start` to where the arrow points",
        arg=1,
      )
    }
    let before = if segments.length() > 1 {
      segments[segments.length() - 2].end()
    } else {
      start
    }
    guard arriving_from(before, last) is Some(from) &&
      arrow_head(from, last.end(), head) is Some(shape) else {
      return site.invalid(
        "the last segment of `Canvas::arrow` gives the arrow no direction: it ends where it starts, or its ends are farther apart than a number can say",
        arg=1,
      )
    }
    let path = segments.copy()
    path[path.length() - 1] = last.ending_at(shape.end)
    // The paint of the stroke, or the paint of a stroke without one.
    let paint : @doc.Paint = match stroke {
      Some(stroke) => stroke.paint().unwrap_or(Black)
      None => Black
    }
    // One `Place`, like every item: the path and the head are placed in
    // it, both at its origin, which is the origin of the canvas.
    @doc.Place(
      @doc.Seq([
        @doc.Place(
          @doc.Curve(components(start, path), stroke?=site.arg(2, stroke)),
          alignment=top_left(),
        ),
        @doc.Place(
          @doc.Polygon(
            [lengths(shape.tip), lengths(shape.left), lengths(shape.right)],
            fill=site.arg(2, paint),
          ),
          alignment=top_left(),
        ),
      ]),
      alignment=top_left(),
    )
  })
  { composite, }
}

///|
pub impl @doc.IntoContent for Canvas with fn into_content(self) {
  @doc.IntoContent::into_content(self.composite)
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Canvas with @doc.IntoContent::{into_content}

///|
/// Interpolation into the text of `Prose`.
pub impl Show for Canvas with fn output(self, logger) {
  Show::output(self.composite, logger)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Canvas with Show::{to_string, output}

///|
pub impl @debug.Debug for Canvas with fn to_repr(self) {
  @debug.Debug::to_repr(self.composite)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Canvas with @debug.Debug::{to_repr}

///|
pub impl @doc.IntoContent for CanvasItem with fn into_content(self) {
  @doc.IntoContent::into_content(self.composite)
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CanvasItem with @doc.IntoContent::{into_content}

///|
/// Interpolation into the text of `Prose`.
pub impl Show for CanvasItem with fn output(self, logger) {
  Show::output(self.composite, logger)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CanvasItem with Show::{to_string, output}

///|
pub impl @debug.Debug for CanvasItem with fn to_repr(self) {
  @debug.Debug::to_repr(self.composite)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CanvasItem with @debug.Debug::{to_repr}
