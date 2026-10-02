// Port of `typst-svg/src/path.rs`: a builder for SVG paths using relative
// coordinates.

///|
/// A builder for SVG path using relative coordinates.
priv struct SvgPathBuilder {
  path : SvgFormatter
  scale : @library.Ratio
  /// The point of the last move, used to close paths with the `Z` command.
  mut last_close_point : @library.Point
  /// The end of the previous draw command, used for relative draw commands.
  mut last_point : @library.Point
}

///|
/// Creates a path builder with an initial `M` command.
fn SvgPathBuilder::with_translate(pos : @library.Point) -> SvgPathBuilder {
  let path = SvgFormatter::new()
  path.push_str("M ")
  path.push_nums([pos.x.to_pt(), pos.y.to_pt()])
  {
    path,
    scale: @library.Ratio::one(),
    last_close_point: pos,
    last_point: @library.Point::zero(),
  }
}

///|
/// Creates a path builder with a scale and an initial `M 0 0` command.
fn SvgPathBuilder::with_scale(scale : @library.Ratio) -> SvgPathBuilder {
  let path = SvgFormatter::new()
  path.push_str("M 0 0")
  {
    path,
    scale,
    last_close_point: @library.Point::zero(),
    last_point: @library.Point::zero(),
  }
}

///|
/// Creates an empty path builder.
fn SvgPathBuilder::empty() -> SvgPathBuilder {
  {
    path: SvgFormatter::new(),
    scale: @library.Ratio::one(),
    last_close_point: @library.Point::zero(),
    last_point: @library.Point::zero(),
  }
}

///|
/// Finish building the path.
fn SvgPathBuilder::finsish(self : SvgPathBuilder) -> String {
  self.path.to_string()
}

///|
fn SvgPathBuilder::map(
  self : SvgPathBuilder,
  pos : @library.Point,
) -> @library.Point {
  (pos - self.last_point).times(self.scale.get())
}

///|
/// Create a rectangle path. The rectangle is created with the top-left
/// corner at (0, 0). The width and height are the size of the rectangle.
fn SvgPathBuilder::rect(
  self : SvgPathBuilder,
  size : @library.Axes[@library.Abs],
) -> Unit {
  self.move_to(@library.Point::zero())
  self.line_to(@library.Point::with_y(size.y))
  self.line_to(size.to_point())
  self.line_to(@library.Point::with_x(size.x))
  self.close()
}

///|
/// Creates an arc path.
fn SvgPathBuilder::arc(
  self : SvgPathBuilder,
  radius : @library.Axes[@library.Abs],
  x_axis_rot : @library.Angle,
  large_arc_flag : UInt,
  sweep_flag : UInt,
  pos : @library.Point,
) -> Unit {
  let radius = self.map(radius.to_point())
  let mapped = self.map(pos)
  let f = self.path
  f.push_str("a ")
  f.push_nums([
    radius.x.to_pt(),
    radius.y.to_pt(),
    x_axis_rot.to_deg(),
    large_arc_flag.to_double(),
    sweep_flag.to_double(),
    mapped.x.to_pt(),
    mapped.y.to_pt(),
  ])
  self.last_point = pos
}

///|
fn SvgPathBuilder::move_to(self : SvgPathBuilder, pos : @library.Point) -> Unit {
  let mapped = self.map(pos)
  if mapped != @library.Point::zero() {
    let f = self.path
    f.push_str("m ")
    f.push_nums([mapped.x.to_pt(), mapped.y.to_pt()])
  }
  self.last_point = pos
  self.last_close_point = pos
}

///|
fn SvgPathBuilder::line_to(self : SvgPathBuilder, pos : @library.Point) -> Unit {
  let mapped = self.map(pos)
  let f = self.path
  let zero = @library.Abs::zero()
  if mapped.x != zero && mapped.y != zero {
    f.push_str("l ")
    f.push_nums([mapped.x.to_pt(), mapped.y.to_pt()])
  } else if mapped.x != zero {
    f.push_str("h ")
    f.push_num(mapped.x.to_pt())
  } else if mapped.y != zero {
    f.push_str("v ")
    f.push_num(mapped.y.to_pt())
  }
  self.last_point = pos
}

///|
fn SvgPathBuilder::curve_to(
  self : SvgPathBuilder,
  p1 : @library.Point,
  p2 : @library.Point,
  end : @library.Point,
) -> Unit {
  let m1 = self.map(p1)
  let m2 = self.map(p2)
  let me = self.map(end)
  let f = self.path
  f.push_str("c ")
  f.push_nums([
    m1.x.to_pt(),
    m1.y.to_pt(),
    m2.x.to_pt(),
    m2.y.to_pt(),
    me.x.to_pt(),
    me.y.to_pt(),
  ])
  self.last_point = end
}

///|
fn SvgPathBuilder::quad_to(
  self : SvgPathBuilder,
  p1 : @library.Point,
  end : @library.Point,
) -> Unit {
  let m1 = self.map(p1)
  let me = self.map(end)
  let f = self.path
  f.push_str("q ")
  f.push_nums([m1.x.to_pt(), m1.y.to_pt(), me.x.to_pt(), me.y.to_pt()])
  self.last_point = end
}

///|
fn SvgPathBuilder::close(self : SvgPathBuilder) -> Unit {
  self.path.push_str("Z ")
  self.last_point = self.last_close_point
}

///|
/// A builder for SVG path. This is used to build the path for a glyph
/// (upstream `impl ttf_parser::OutlineBuilder for SvgPathBuilder`).
priv struct OutlineSink(SvgPathBuilder)

///|
impl @otf.OutlineBuilder for OutlineSink with fn move_to(self, x, y) {
  self.0.move_to(outline_point(x, y))
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn line_to(self, x, y) {
  self.0.line_to(outline_point(x, y))
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn quad_to(self, x1, y1, x, y) {
  self.0.quad_to(outline_point(x1, y1), outline_point(x, y))
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn curve_to(
  self,
  x1,
  y1,
  x2,
  y2,
  x,
  y,
) {
  self.0.curve_to(
    outline_point(x1, y1),
    outline_point(x2, y2),
    outline_point(x, y),
  )
}

///|
impl @otf.OutlineBuilder for OutlineSink with fn close(self) {
  self.0.close()
}

///|
/// Helper to create points.
fn outline_point(x : Float, y : Float) -> @library.Point {
  { x: @library.Abs::pt(x.to_double()), y: @library.Abs::pt(y.to_double()), }
}
