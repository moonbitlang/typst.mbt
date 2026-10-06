// Port of `typst-library/src/visualize/curve.rs`: element field types and
// the `Curve` geometry (without the kurbo-based bounding box and hit tests).

///|
/// A curve consisting of movements, lines, and Bézier segments.
pub(all) struct Curve(Array[CurveItem]) derive(Eq, Hash, Default)

///|
/// An item in a curve.
pub(all) enum CurveItem {
  Move(Point)
  Line(Point)
  Cubic(Point, Point, Point)
  Close
} derive(Eq, Hash)

///|
/// Creates an empty curve.
pub fn Curve::new() -> Curve {
  Curve([])
}

///|
/// Creates a curve that describes a rectangle.
pub fn Curve::rect(size : Axes[Abs]) -> Curve {
  let z = Abs::zero()
  let point = Point::new
  let curve = Curve::new()
  curve.move_(point(z, z))
  curve.line(point(size.x, z))
  curve.line(point(size.x, size.y))
  curve.line(point(z, size.y))
  curve.close()
  curve
}

///|
/// Creates a curve that describes an axis-aligned ellipse.
pub fn Curve::ellipse(size : Axes[Abs]) -> Curve {
  // https://stackoverflow.com/a/2007782
  let z = Abs::zero()
  let rx = size.x.div_by(2.0)
  let ry = size.y.div_by(2.0)
  let m = 0.551784
  let mx = rx.times(m)
  let my = ry.times(m)
  let point = (x : Abs, y : Abs) => Point::new(x + rx, y + ry)
  let curve = Curve::new()
  curve.move_(point(-rx, z))
  curve.cubic(point(-rx, -my), point(-mx, -ry), point(z, -ry))
  curve.cubic(point(mx, -ry), point(rx, -my), point(rx, z))
  curve.cubic(point(rx, my), point(mx, ry), point(z, ry))
  curve.cubic(point(-mx, ry), point(-rx, my), point(-rx, z))
  curve
}

///|
/// Push a [`Move`](CurveItem::Move) item.
pub fn Curve::move_(self : Curve, p : Point) -> Unit {
  self.0.push(Move(p))
}

///|
/// Push a [`Line`](CurveItem::Line) item.
pub fn Curve::line(self : Curve, p : Point) -> Unit {
  self.0.push(Line(p))
}

///|
/// Push a [`Cubic`](CurveItem::Cubic) item.
pub fn Curve::cubic(self : Curve, p1 : Point, p2 : Point, p3 : Point) -> Unit {
  self.0.push(Cubic(p1, p2, p3))
}

///|
/// Push a [`Close`](CurveItem::Close) item.
pub fn Curve::close(self : Curve) -> Unit {
  self.0.push(Close)
}

///|
/// Check if the curve is empty.
pub fn Curve::is_empty(self : Curve) -> Bool {
  self.0.is_empty()
}

///|
/// The items of the curve.
pub fn Curve::items(self : Curve) -> Array[CurveItem] {
  self.0
}

///|
/// A copy of the curve (upstream `Clone`; curves are values upstream).
pub fn Curve::copy(self : Curve) -> Curve {
  Curve(self.0.copy())
}

///|
/// Translate all points in this curve by the given offset.
pub fn Curve::translate(self : Curve, offset : Point) -> Unit {
  if offset.is_zero() {
    return
  }
  for i, item in self.0 {
    self.0[i] = match item {
      Move(p) => Move(p + offset)
      Line(p) => Line(p + offset)
      Cubic(p1, p2, p3) => Cubic(p1 + offset, p2 + offset, p3 + offset)
      Close => Close
    }
  }
}

///|
/// A component used for curve creation: one of the curve elements.
pub(all) struct CurveComponent(Content)

///|
pub impl Reflect for CurveComponent with fn input() {
  Content::input()
}

///|
pub impl Reflect for CurveComponent with fn output() {
  Content::output()
}

///|
pub impl Reflect for CurveComponent with fn castable(v) {
  Content::castable(v)
}

///|
pub impl IntoValue for CurveComponent with fn into_value(self) {
  Content(self.0)
}

///|
pub impl FromValue for CurveComponent with fn from_value(v) {
  let content = Content::from_value(v)
  let elem = content.elem()
  if elem == curve_move_elem() ||
    elem == curve_line_elem() ||
    elem == curve_quad_elem() ||
    elem == curve_cubic_elem() ||
    elem == curve_close_elem() {
    CurveComponent(content)
  } else {
    bail("expecting a curve element")
  }
}

///|
/// How to close a curve.
pub(all) enum CloseMode {
  /// Closes the curve with a smooth segment that takes into account the
  /// control point opposite the start point.
  Smooth
  /// Closes the curve with a straight line.
  Straight
} derive(Eq, Hash, Debug)

///|
pub impl Default for CloseMode with fn default() {
  Smooth
}

///|
pub impl Reflect for CloseMode with fn input() {
  Union([
    Value(
      Str("smooth"),
      "Closes the curve with a smooth segment that takes into account the\ncontrol point opposite the start point.",
    ),
    Value(Str("straight"), "Closes the curve with a straight line."),
  ])
}

///|
pub impl Reflect for CloseMode with fn output() {
  CloseMode::input()
}

///|
pub impl Reflect for CloseMode with fn castable(v) {
  v is Str("smooth" | "straight")
}

///|
pub extend CloseMode with Reflect::{output, input, castable}

///|
pub impl IntoValue for CloseMode with fn into_value(self) {
  match self {
    Smooth => Str("smooth")
    Straight => Str("straight")
  }
}

///|
pub impl FromValue for CloseMode with fn from_value(v) {
  match v {
    Str("smooth") => Smooth
    Str("straight") => Straight
    v => raise HintedError(CloseMode::input().error(v))
  }
}
