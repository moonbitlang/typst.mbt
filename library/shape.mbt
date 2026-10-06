// Port of `typst-library/src/visualize/shape.rs`: element field types,
// `#[parse]` hooks and the `Shape`/`Geometry` frame items (without the
// kurbo-based bounding boxes).

///|
/// A geometric shape with optional fill and stroke.
pub(all) struct Shape {
  /// The shape's geometry.
  geometry : Geometry
  /// The shape's background fill.
  fill : Paint?
  /// The shape's fill rule.
  fill_rule : FillRule
  /// The shape's border stroke.
  stroke : FixedStroke?
} derive(Eq)

///|
/// A shape's geometry.
pub(all) enum Geometry {
  /// A line to a point (relative to its position).
  Line(Point)
  /// A rectangle with its origin in the topleft corner.
  Rect(Axes[Abs])
  /// A curve consisting of movements, lines, and Bézier segments.
  Curve(Curve)
} derive(Eq)

///|
/// Fill the geometry without a stroke.
pub fn Geometry::filled(self : Geometry, fill : Paint) -> Shape {
  {
    geometry: self,
    fill: Some(fill),
    fill_rule: FillRule::default(),
    stroke: None,
  }
}

///|
/// Stroke the geometry without a fill.
pub fn Geometry::stroked(self : Geometry, stroke : FixedStroke) -> Shape {
  {
    geometry: self,
    fill: None,
    fill_rule: FillRule::default(),
    stroke: Some(stroke),
  }
}

///|
/// Set the geometry's background fill and stroke.
pub fn Geometry::filled_and_stroked(
  self : Geometry,
  fill : Paint,
  stroke : FixedStroke,
) -> Shape {
  {
    geometry: self,
    fill: Some(fill),
    fill_rule: FillRule::default(),
    stroke: Some(stroke),
  }
}

///|
/// A path filling rule.
pub(all) enum FillRule {
  /// Specifies that "inside" is computed by a non-zero sum of signed edge
  /// crossings.
  NonZero
  /// Specifies that "inside" is computed by an odd number of edge crossings.
  EvenOdd
} derive(Eq, Hash, Debug)

///|
pub impl Default for FillRule with fn default() {
  NonZero
}

///|
pub extend FillRule with Default::{default}

///|
pub impl Reflect for FillRule with fn input() {
  Union([
    Value(
      Str("non-zero"),
      "Specifies that \"inside\" is computed by a non-zero sum of signed edge crossings.",
    ),
    Value(
      Str("even-odd"),
      "Specifies that \"inside\" is computed by an odd number of edge crossings.",
    ),
  ])
}

///|
pub impl Reflect for FillRule with fn output() {
  FillRule::input()
}

///|
pub impl Reflect for FillRule with fn castable(v) {
  v is Str("non-zero" | "even-odd")
}

///|
pub extend FillRule with Reflect::{output, input, castable}

///|
pub impl IntoValue for FillRule with fn into_value(self) {
  match self {
    NonZero => Str("non-zero")
    EvenOdd => Str("even-odd")
  }
}

///|
pub impl FromValue for FillRule with fn from_value(v) {
  match v {
    Str("non-zero") => NonZero
    Str("even-odd") => EvenOdd
    v => raise HintedError(FillRule::input().error(v))
  }
}

// SquareElem: `size` sets both `width` and `height`.

///|
fn square_elem_width_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let size : Smart[Length]? = args.named("size")
  let size = size.map(s => s.map(l => (Rel::from_abs(l) : Rel[Length])))
  let size = size.map(s => s.into_value())
  locals.set("size", size)
  match size {
    None => named_as(args, "width", square_elem(), square_elem_width)
    size => size
  }
}

///|
fn square_elem_height_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  // `Smart<Rel<Length>>` into `Sizing` has the same value representation.
  match locals.get("size") {
    None => named_as(args, "height", square_elem(), square_elem_height)
    size => size
  }
}

// CircleElem: `radius` sets both `width` and `height` to its double.

///|
fn circle_elem_width_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let size : Smart[Length]? = args.named("radius")
  let size = size.map(s => {
    s.map(r => (Rel::from_abs(r).times(2.0) : Rel[Length]))
  })
  let size = size.map(s => s.into_value())
  locals.set("size", size)
  match size {
    None => named_as(args, "width", circle_elem(), circle_elem_width)
    size => size
  }
}

///|
fn circle_elem_height_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  match locals.get("size") {
    None => named_as(args, "height", circle_elem(), circle_elem_height)
    size => size
  }
}

// Field defaults of the shape elements.

///|
/// The default inset of shapes: `Sides::splat(Some(Abs::pt(5.0).into()))`.
fn shape_default_inset() -> Value {
  let inset : Rel[Length] = Rel::from_abs(Length::from_abs(Abs::pt(5.0)))
  Sides::splat(Some(inset)).into_value()
}

///|
fn rect_elem_height_default() -> Value {
  Sizing::Auto.into_value()
}

///|
fn rect_elem_inset_default() -> Value {
  shape_default_inset()
}

///|
fn square_elem_height_default() -> Value {
  Sizing::Auto.into_value()
}

///|
fn square_elem_inset_default() -> Value {
  shape_default_inset()
}

///|
fn ellipse_elem_height_default() -> Value {
  Sizing::Auto.into_value()
}

///|
fn ellipse_elem_inset_default() -> Value {
  shape_default_inset()
}

///|
fn circle_elem_height_default() -> Value {
  Sizing::Auto.into_value()
}

///|
fn circle_elem_inset_default() -> Value {
  shape_default_inset()
}
