// Port of `typst-layout/src/shapes.rs`.

///|
/// Layout the line.
pub fn layout_line(
  elem : @library.LineElem,
  _engine : @library.Engine,
  _locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let resolve = (axes : @library.Axes[@library.Rel[@library.Abs]]) => {
    axes.relative_to(region.size)
  }
  let start = resolve(resolve_axes_rel(elem.start(styles), styles))
  let delta = match elem.end(styles) {
    Some(end) => resolve(resolve_axes_rel(end, styles)).sub_size(start)
    None => {
      let length = elem.length(styles).resolve(styles)
      let angle = elem.angle(styles)
      let x = length.times(angle.cos())
      let y = length.times(angle.sin())
      resolve(@library.Axes::new(x, y))
    }
  }
  let stroke = elem.stroke(styles).resolve(styles).unwrap_or_default()
  let size = start.max(start.add_size(delta)).max(@library.Axes::zero_size())
  if !size.is_finite_size() {
    @library.bail_at(
      elem.pack().span(),
      "cannot create line with infinite length",
    )
  }
  let frame = @library.Frame::soft(size)
  let shape = @library.Geometry::Line(delta.to_point()).stroked(stroke)
  frame.push(start.to_point(), Shape(shape, elem.pack().span()))
  frame
}

///|
/// Layout the curve.
pub fn layout_curve(
  elem : @library.CurveElem,
  _engine : @library.Engine,
  _locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let builder = CurveBuilder::new(region, styles)
  for item in elem.components() {
    let item = item.0
    if @library.CurveMove::of(item) is Some(element) {
      let relative = element.relative(styles)
      let point = builder.resolve_point(element.start(), relative)
      builder.move_(point)
    } else if @library.CurveLine::of(item) is Some(element) {
      let relative = element.relative(styles)
      let point = builder.resolve_point(element.end(), relative)
      builder.line(point)
    } else if @library.CurveQuad::of(item) is Some(element) {
      let relative = element.relative(styles)
      let end = builder.resolve_point(element.end(), relative)
      let control = match element.control() {
        Auto => control_c2q(builder.last_point, builder.last_control_from)
        Custom(Some(p)) => builder.resolve_point(p, relative)
        Custom(None) => end
      }
      builder.quad(control, end)
    } else if @library.CurveCubic::of(item) is Some(element) {
      let relative = element.relative(styles)
      let end = builder.resolve_point(element.end(), relative)
      let c1 = match element.control_start() {
        Some(Custom(p)) => builder.resolve_point(p, relative)
        Some(Auto) => builder.last_control_from
        None => builder.last_point
      }
      let c2 = match element.control_end() {
        Some(p) => builder.resolve_point(p, relative)
        None => end
      }
      builder.cubic(c1, c2, end)
    } else if @library.CurveClose::of(item) is Some(element) {
      builder.close(element.mode(styles))
    }
  }
  let (curve, size) = builder.finish()
  if curve.is_empty() {
    return @library.Frame::soft(size)
  }
  if !size.is_finite_size() {
    @library.bail_at(
      elem.pack().span(),
      "cannot create curve with infinite size",
    )
  }

  // Prepare fill and stroke.
  let fill = elem.fill(styles)
  let fill_rule = elem.fill_rule(styles)
  let stroke = match elem.stroke(styles) {
    Auto if fill is None => Some(@library.FixedStroke::default())
    Auto => None
    Custom(stroke) => stroke.map(s => s.resolve(styles).unwrap_or_default())
  }
  let frame = @library.Frame::soft(size)
  let shape : @library.Shape = {
    geometry: Curve(curve),
    stroke,
    fill,
    fill_rule,
  }
  frame.push(@library.Point::zero(), Shape(shape, elem.pack().span()))
  frame
}

///|
/// Builds a `Curve` from a [CurveElem]'s parts.
priv struct CurveBuilder {
  /// The output curve.
  curve : @library.Curve
  /// The curve's bounds.
  mut size : @library.Axes[@library.Abs]
  /// The region relative to which points are resolved.
  region : @library.LayoutRegion
  /// The styles for the curve.
  styles : @library.StyleChain
  /// The next start point.
  mut start_point : @library.Point
  /// Mirror of the first cubic start control point (for closing).
  mut start_control_into : @library.Point
  /// The point we previously ended on.
  mut last_point : @library.Point
  /// Mirror of the last cubic control point (for auto control points).
  mut last_control_from : @library.Point
  /// Whether a component has been start. This does not mean that something
  /// has been added to `self.curve` yet.
  mut is_started : Bool
  /// Whether anything was added to `self.curve` for the current component.
  mut is_empty : Bool
}

///|
/// Create a new curve builder.
fn CurveBuilder::new(
  region : @library.LayoutRegion,
  styles : @library.StyleChain,
) -> CurveBuilder {
  {
    curve: @library.Curve::new(),
    size: @library.Axes::zero_size(),
    region,
    styles,
    start_point: @library.Point::zero(),
    start_control_into: @library.Point::zero(),
    last_point: @library.Point::zero(),
    last_control_from: @library.Point::zero(),
    is_started: false,
    is_empty: true,
  }
}

///|
/// Finish building, returning the curve and its bounding size.
fn CurveBuilder::finish(
  self : CurveBuilder,
) -> (@library.Curve, @library.Axes[@library.Abs]) {
  (self.curve, self.size)
}

///|
/// Move to a point, starting a new segment.
fn CurveBuilder::move_(self : CurveBuilder, point : @library.Point) -> Unit {
  // Delay calling `curve.move` in case there is another move element before
  // any actual drawing.
  self.expand_bounds(point)
  self.start_point = point
  self.start_control_into = point
  self.last_point = point
  self.last_control_from = point
  self.is_started = true
  self.is_empty = true
}

///|
/// Add a line segment.
fn CurveBuilder::line(self : CurveBuilder, point : @library.Point) -> Unit {
  if self.is_empty {
    self.start_component()
    self.start_control_into = self.start_point
  }
  self.curve.line(point)
  self.expand_bounds(point)
  self.last_point = point
  self.last_control_from = point
}

///|
/// Add a quadratic curve segment.
fn CurveBuilder::quad(
  self : CurveBuilder,
  control : @library.Point,
  end : @library.Point,
) -> Unit {
  let c1 = control_q2c(self.last_point, control)
  let c2 = control_q2c(end, control)
  self.cubic(c1, c2, end)
}

///|
/// Add a cubic curve segment.
fn CurveBuilder::cubic(
  self : CurveBuilder,
  c1 : @library.Point,
  c2 : @library.Point,
  end : @library.Point,
) -> Unit {
  if self.is_empty {
    self.start_component()
    self.start_control_into = mirror_c(self.start_point, c1)
  }
  self.curve.cubic(c1, c2, end)
  let p0 = point_to_kurbo(self.last_point)
  let p1 = point_to_kurbo(c1)
  let p2 = point_to_kurbo(c2)
  let p3 = point_to_kurbo(end)
  let extrema = cubic_bounding_box(p0, p1, p2, p3)
  self.size = {
    x: self.size.x.max(@library.Abs::raw(extrema.x1)),
    y: self.size.y.max(@library.Abs::raw(extrema.y1)),
  }
  self.last_point = end
  self.last_control_from = mirror_c(end, c2)
}

///|
/// Close the curve if it was opened.
fn CurveBuilder::close(self : CurveBuilder, mode : @library.CloseMode) -> Unit {
  if self.is_started && !self.is_empty {
    if mode == Smooth {
      self.cubic(
        self.last_control_from,
        self.start_control_into,
        self.start_point,
      )
    }
    self.curve.close()
    self.last_point = self.start_point
    self.last_control_from = self.start_point
  }
  self.is_started = false
  self.is_empty = true
}

///|
/// Push the initial move component.
fn CurveBuilder::start_component(self : CurveBuilder) -> Unit {
  self.curve.move_(self.start_point)
  self.is_empty = false
  self.is_started = true
}

///|
/// Expand the curve's bounding box.
fn CurveBuilder::expand_bounds(
  self : CurveBuilder,
  point : @library.Point,
) -> Unit {
  self.size = { x: self.size.x.max(point.x), y: self.size.y.max(point.y), }
}

///|
/// Resolve the point relative to the region.
fn CurveBuilder::resolve_point(
  self : CurveBuilder,
  point : @library.Axes[@library.Rel[@library.Length]],
  relative : Bool,
) -> @library.Point {
  let mut p = resolve_axes_rel(point, self.styles)
    .relative_to(self.region.size)
    .to_point()
  if relative {
    p = p + self.last_point
  }
  p
}

///|
/// Convert a cubic control point into a quadratic one.
fn control_c2q(p : @library.Point, c : @library.Point) -> @library.Point {
  c.times(1.5) - p.times(0.5)
}

///|
/// Convert a quadratic control point into a cubic one.
fn control_q2c(p : @library.Point, c : @library.Point) -> @library.Point {
  (p + c.times(2.0)).div_by(3.0)
}

///|
/// Mirror a control point.
fn mirror_c(p : @library.Point, c : @library.Point) -> @library.Point {
  p.times(2.0) - c
}

///|
/// Convert a point to a `kurbo::Point`.
fn point_to_kurbo(point : @library.Point) -> (Double, Double) {
  (point.x.to_raw(), point.y.to_raw())
}

///|
/// Layout the polygon.
pub fn layout_polygon(
  elem : @library.PolygonElem,
  _engine : @library.Engine,
  _locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  let points = elem
    .vertices()
    .map(c => resolve_axes_rel(c, styles).relative_to(region.size).to_point())
  let size = points
    .iter()
    .fold(init=@library.Point::zero(), (max, c) => c.max(max))
    .to_size()
  if !size.is_finite_size() {
    @library.bail_at(
      elem.pack().span(),
      "cannot create polygon with infinite size",
    )
  }
  let frame = @library.Frame::soft(size)

  // Only create a curve if there are more than zero points.
  if points.is_empty() {
    return frame
  }

  // Prepare fill and stroke.
  let fill = elem.fill(styles)
  let fill_rule = elem.fill_rule(styles)
  let stroke = match elem.stroke(styles) {
    Auto if fill is None => Some(@library.FixedStroke::default())
    Auto => None
    Custom(stroke) => stroke.map(s => s.resolve(styles).unwrap_or_default())
  }

  // Construct a closed curve given all points.
  let curve = @library.Curve::new()
  curve.move_(points[0])
  for point in points[1:] {
    curve.line(point)
  }
  curve.close()
  let shape : @library.Shape = {
    geometry: Curve(curve),
    stroke,
    fill,
    fill_rule,
  }
  frame.push(@library.Point::zero(), Shape(shape, elem.pack().span()))
  frame
}

///|
/// Lay out the rectangle.
pub fn layout_rect(
  elem : @library.RectElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  layout_shape(
    engine,
    locator,
    styles,
    region,
    Rect,
    elem.body(styles),
    elem.fill(styles),
    elem.stroke(styles).map(s => resolve_sides_stroke(s, styles)),
    resolve_sides_rel(elem.inset(styles), styles),
    resolve_sides_rel(elem.outset(styles), styles),
    resolve_corners_rel(elem.radius(styles), styles),
    elem.pack().span(),
  )
}

///|
/// Lay out the square.
pub fn layout_square(
  elem : @library.SquareElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  layout_shape(
    engine,
    locator,
    styles,
    region,
    Square,
    elem.body(styles),
    elem.fill(styles),
    elem.stroke(styles).map(s => resolve_sides_stroke(s, styles)),
    resolve_sides_rel(elem.inset(styles), styles),
    resolve_sides_rel(elem.outset(styles), styles),
    resolve_corners_rel(elem.radius(styles), styles),
    elem.pack().span(),
  )
}

///|
/// Lay out the ellipse.
pub fn layout_ellipse(
  elem : @library.EllipseElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  layout_shape(
    engine,
    locator,
    styles,
    region,
    Ellipse,
    elem.body(styles),
    elem.fill(styles),
    elem
    .stroke(styles)
    .map(s => @library.Sides::splat(Some(s.map(s => s.resolve(styles))))),
    resolve_sides_rel(elem.inset(styles), styles),
    resolve_sides_rel(elem.outset(styles), styles),
    @library.Corners::splat(None),
    elem.pack().span(),
  )
}

///|
/// Lay out the circle.
pub fn layout_circle(
  elem : @library.CircleElem,
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
) -> @library.Frame raise @library.SourceError {
  layout_shape(
    engine,
    locator,
    styles,
    region,
    Circle,
    elem.body(styles),
    elem.fill(styles),
    elem
    .stroke(styles)
    .map(s => @library.Sides::splat(Some(s.map(s => s.resolve(styles))))),
    resolve_sides_rel(elem.inset(styles), styles),
    resolve_sides_rel(elem.outset(styles), styles),
    @library.Corners::splat(None),
    elem.pack().span(),
  )
}

///|
/// A category of shape.
priv enum ShapeKind {
  /// A rectangle with equal side lengths.
  Square
  /// A quadrilateral with four right angles.
  Rect
  /// An ellipse with coinciding foci.
  Circle
  /// A curve around two focal points.
  Ellipse
}

///|
/// Whether this shape kind is curvy.
fn ShapeKind::is_round(self : ShapeKind) -> Bool {
  self is (Circle | Ellipse)
}

///|
/// Whether this shape kind has equal side length.
fn ShapeKind::is_quadratic(self : ShapeKind) -> Bool {
  self is (Square | Circle)
}

///|
/// `0.5 - SQRT_2 / 4.0`.
let round_inset : Double = 0.5 - (2.0 : Double).sqrt() / 4.0

///|
/// Layout a shape.
fn layout_shape(
  engine : @library.Engine,
  locator : @library.Locator,
  styles : @library.StyleChain,
  region : @library.LayoutRegion,
  kind : ShapeKind,
  body : @library.Content?,
  fill : @library.Paint?,
  stroke : @library.Smart[@library.Sides[@library.ResolvedStroke??]],
  inset : @library.Sides[@library.Rel[@library.Abs]?],
  outset : @library.Sides[@library.Rel[@library.Abs]?],
  radius : @library.Corners[@library.Rel[@library.Abs]?],
  span : @syntax.Span,
) -> @library.Frame raise @library.SourceError {
  let frame = if body is Some(child) {
    let mut inset = sides_rel_or_zero(inset)
    if kind.is_round() {
      // Apply extra inset to round shapes.
      inset = inset.map(v => {
        ..v,
        rel: v.rel + @library.Ratio::new(round_inset),
      })
    }
    let has_inset = !inset.is_zero()

    // Take the inset, if any, into account.
    let mut pod = region
    if has_inset {
      pod = { ..pod, size: shrink(region.size, inset), }
    }

    // If the shape is quadratic, we first measure it to determine its size
    // and then layout with full expansion to force the aspect ratio and make
    // sure it's really quadratic.
    if kind.is_quadratic() {
      let length = match quadratic_size(pod) {
        Some(length) => length
        None =>
          // Take as much as the child wants, but without overflowing.
          layout_frame(engine, child, locator.relayout(), styles, pod)
          .size()
          .max_by_side()
          .min(pod.size.min_by_side())
      }
      pod = @library.LayoutRegion::new(
        @library.Axes::splat(length),
        @library.Axes::splat(true),
      )
    }

    // Layout the child.
    let frame = layout_frame(engine, child, locator, styles, pod)

    // Apply the inset.
    if has_inset {
      grow(frame, inset)
    }
    frame
  } else {
    // The default size that a shape takes on if it has no child and no
    // forced sizes.
    let default = @library.Axes::new(
      @library.Abs::pt(45.0),
      @library.Abs::pt(30.0),
    ).min(region.size)
    let size = if kind.is_quadratic() {
      @library.Axes::splat(
        match quadratic_size(region) {
          Some(length) => length
          None => default.min_by_side()
        },
      )
    } else {
      // For each dimension, pick the region size if forced, otherwise use
      // the default size (or the region size if the default is too large
      // for the region).
      region.expand.select(region.size, default)
    }
    @library.Frame::soft(size)
  }

  // Prepare stroke.
  let stroke : @library.Sides[@library.FixedStroke?] = match stroke {
    Auto if fill is None =>
      @library.Sides::splat(Some(@library.FixedStroke::default()))
    Auto => @library.Sides::splat(None)
    Custom(strokes) => sides_fixed_stroke(strokes)
  }

  // Add fill and/or stroke.
  if fill is Some(_) || any_stroke(stroke) {
    if kind.is_round() {
      let outset = sides_rel_or_zero(outset).relative_to(frame.size())
      let size = frame.size().add_size(outset.sum_by_axis())
      let pos = @library.Point::new(-outset.left, -outset.top)
      let shape : @library.Shape = {
        geometry: Curve(@library.Curve::ellipse(size)),
        fill,
        stroke: stroke.left,
        fill_rule: @library.FillRule::default(),
      }
      frame.prepend(pos, Shape(shape, span))
    } else {
      fill_and_stroke(
        frame,
        fill,
        stroke,
        sides_rel_or_zero(outset),
        corners_rel_or_zero(radius),
        span,
      )
    }
  }
  frame
}

///|
/// Determines the forced size of a quadratic shape based on the region, if
/// any.
///
/// The size is forced if at least one axis is expanded because `expand` is
/// `true` for axes whose size was manually specified by the user.
fn quadratic_size(region : @library.LayoutRegion) -> @library.Abs? {
  if region.expand.x && region.expand.y {
    // If both `width` and `height` are specified, we choose the smaller one.
    Some(region.size.x.min(region.size.y))
  } else if region.expand.x {
    Some(region.size.x)
  } else if region.expand.y {
    Some(region.size.y)
  } else {
    None
  }
}

///|
/// Upstream `Option<Abs>::min`: `None` is smaller than any `Some`.
fn option_abs_min(a : @library.Abs?, b : @library.Abs?) -> @library.Abs? {
  match (a, b) {
    (Some(a), Some(b)) => Some(a.min(b))
    _ => None
  }
}

///|
/// Creates a new rectangle as a curve.
pub fn clip_rect(
  size : @library.Axes[@library.Abs],
  radius : @library.Corners[@library.Rel[@library.Abs]],
  stroke : @library.Sides[@library.FixedStroke?],
  outset : @library.Sides[@library.Rel[@library.Abs]],
) -> @library.Curve {
  let outset = outset.relative_to(size)
  let size = size.add_size(outset.sum_by_axis())
  let stroke_widths = stroke.map(s => s.map(s => s.thickness.div_by(2.0)))
  let base_radius = size.x.min(size.y).div_by(2.0)
  let corner_max = stroke_widths.map_corners((a, b) => {
    base_radius + option_abs_min(a, b).unwrap_or(@library.Abs::zero())
  })
  let radius = radius
    .zip(corner_max)
    .map(pair => pair.0.relative_to(pair.1.times(2.0)).min(pair.1))
  let corners = corners_control_points(size, radius, stroke, stroke_widths)
  let curve = @library.Curve::new()
  if corners.top_left.arc_inner() {
    curve_arc_move(
      curve,
      corners.top_left.start_inner(),
      corners.top_left.center_inner(),
      corners.top_left.end_inner(),
    )
  } else {
    curve.move_(corners.top_left.center_inner())
  }
  for corner in [corners.top_right, corners.bottom_right, corners.bottom_left] {
    if corner.arc_inner() {
      curve_arc_line(
        curve,
        corner.start_inner(),
        corner.center_inner(),
        corner.end_inner(),
      )
    } else {
      curve.line(corner.center_inner())
    }
  }
  curve.close()
  curve.translate(@library.Point::new(-outset.left, -outset.top))
  curve
}

///|
/// Add a fill and stroke with optional radius and outset to the frame.
pub fn fill_and_stroke(
  frame : @library.Frame,
  fill : @library.Paint?,
  stroke : @library.Sides[@library.FixedStroke?],
  outset : @library.Sides[@library.Rel[@library.Abs]],
  radius : @library.Corners[@library.Rel[@library.Abs]],
  span : @syntax.Span,
) -> Unit {
  let outset = outset.relative_to(frame.size())
  let size = frame.size().add_size(outset.sum_by_axis())
  let pos = @library.Point::new(-outset.left, -outset.top)
  frame.prepend_multiple(
    styled_rect(size, radius, fill, stroke)
    .iter()
    .map(x => (pos, @library.FrameItem::Shape(x, span))),
  )
}

///|
/// Create a styled rectangle with shapes.
/// - use rect primitive for simple rectangles
/// - stroke sides if possible
/// - use fill for sides for best looks
pub fn styled_rect(
  size : @library.Axes[@library.Abs],
  radius : @library.Corners[@library.Rel[@library.Abs]],
  fill : @library.Paint?,
  stroke : @library.Sides[@library.FixedStroke?],
) -> Array[@library.Shape] {
  if stroke.is_uniform() && radius.iter().all(r => r.is_zero()) {
    simple_rect(size, fill, stroke.top)
  } else {
    segmented_rect(size, radius, fill, stroke)
  }
}

///|
/// Use rect primitive for the rectangle
fn simple_rect(
  size : @library.Axes[@library.Abs],
  fill : @library.Paint?,
  stroke : @library.FixedStroke?,
) -> Array[@library.Shape] {
  [
    {
      geometry: Rect(size),
      fill,
      stroke,
      fill_rule: @library.FillRule::default(),
    },
  ]
}

///|
fn corners_control_points(
  size : @library.Axes[@library.Abs],
  radius : @library.Corners[@library.Abs],
  strokes : @library.Sides[@library.FixedStroke?],
  stroke_widths : @library.Sides[@library.Abs?],
) -> @library.Corners[ControlPoints] {
  let corners : @library.Corners[@library.Corner] = {
    top_left: TopLeft,
    top_right: TopRight,
    bottom_right: BottomRight,
    bottom_left: BottomLeft,
  }
  corners.map(corner => {
    radius: radius.get(corner),
    stroke_before: stroke_widths.get(corner.side_ccw()),
    stroke_after: stroke_widths.get(corner.side_cw()),
    corner,
    size,
    same: match
      (strokes.get(corner.side_ccw()), strokes.get(corner.side_cw())) {
      (Some(a), Some(b)) => {
        // Solid strokes can be drawn as `fill_segment`s.
        let solid = match a.dash {
          Some(dash) => dash.array.is_empty()
          None => true
        }

        // For solid strokes the caps are only relevant for the end of the
        // strokes, and they can be filled. For dashed strokes the cap
        // determines how the entire line is drawn, thus there should be
        // two different segments if the cap differs.
        let filled_segment_same = a.paint == b.paint && a.dash == b.dash
        let stroke_segment_same = a.cap == b.cap && a.thickness == b.thickness
        filled_segment_same && (solid || stroke_segment_same)
      }
      (None, None) => true
      _ => false
    },
  })
}

///|
/// Use stroke and fill for the rectangle
fn segmented_rect(
  size : @library.Axes[@library.Abs],
  radius : @library.Corners[@library.Rel[@library.Abs]],
  fill : @library.Paint?,
  strokes : @library.Sides[@library.FixedStroke?],
) -> Array[@library.Shape] {
  let res : Array[@library.Shape] = []
  let stroke_widths = strokes.map(s => s.map(s => s.thickness.div_by(2.0)))
  let base_radius = size.x.abs().min(size.y.abs()).div_by(2.0)
  let corner_max = stroke_widths.map_corners((a, b) => {
    base_radius + option_abs_min(a, b).unwrap_or(@library.Abs::zero())
  })
  let radius = radius
    .zip(corner_max)
    .map(pair => pair.0.relative_to(pair.1.times(2.0)).min(pair.1))
  let corners = corners_control_points(size, radius, strokes, stroke_widths)

  // insert stroked sides below filled sides
  let mut stroke_insert = 0

  // fill shape with inner curve
  if fill is Some(fill) {
    let curve = @library.Curve::new()
    let c = corners.get(TopLeft)
    if c.arc() {
      curve_arc_move(curve, c.start(), c.center(), c.end())
    } else {
      curve.move_(c.center())
    }
    for
      corner in [
        @library.Corner::TopRight,
        @library.Corner::BottomRight,
        @library.Corner::BottomLeft,
      ] {
      let c = corners.get(corner)
      if c.arc() {
        curve_arc_line(curve, c.start(), c.center(), c.end())
      } else {
        curve.line(c.center())
      }
    }
    curve.close()
    res.push({
      geometry: Curve(curve),
      fill: Some(fill),
      fill_rule: @library.FillRule::default(),
      stroke: None,
    })
    stroke_insert += 1
  }
  let current = corners.iter().find_first(c => !c.same).map(c => c.corner)
  if current is Some(current) {
    // multiple segments
    // start at a corner with a change between sides and iterate clockwise
    // all other corners
    let mut current = current
    let mut last = current
    for _ in 0..<4 {
      current = current.next_cw()
      if corners.get(current).same {
        continue
      }
      // create segment
      let start = last
      let end = current
      last = current
      guard strokes.get(start.side_cw()) is Some(stroke) else { continue }
      let start_cap = stroke.cap
      let end_cap = match strokes.get(end.side_ccw()) {
        Some(stroke) => stroke.cap
        None => start_cap
      }
      let (shape, ontop) = segment(
        start, end, start_cap, end_cap, corners, stroke,
      )
      if ontop {
        res.push(shape)
      } else {
        res.insert(stroke_insert, shape)
        stroke_insert += 1
      }
    }
  } else if strokes.top is Some(stroke) {
    // single segment
    let (shape, _) = segment(
      TopLeft,
      TopLeft,
      stroke.cap,
      stroke.cap,
      corners,
      stroke,
    )
    res.push(shape)
  }
  res
}

///|
fn curve_segment(
  start : @library.Corner,
  end : @library.Corner,
  corners : @library.Corners[ControlPoints],
  curve : @library.Curve,
) -> Unit {
  // create start corner
  let c = corners.get(start)
  if start == end || !c.arc() {
    curve.move_(c.end())
  } else {
    curve_arc_move(curve, c.mid(), c.center(), c.end())
  }

  // create corners between start and end
  let mut current = start.next_cw()
  while current != end {
    let c = corners.get(current)
    if c.arc() {
      curve_arc_line(curve, c.start(), c.center(), c.end())
    } else {
      curve.line(c.end())
    }
    current = current.next_cw()
  }

  // create end corner
  let c = corners.get(end)
  if !c.arc() {
    curve.line(c.start())
  } else if start == end {
    curve_arc_line(curve, c.start(), c.center(), c.end())
  } else {
    curve_arc_line(curve, c.start(), c.center(), c.mid())
  }
}

///|
fn fill_corner(corner : ControlPoints) -> Bool {
  corner.stroke_before != corner.stroke_after ||
  corner.radius().to_raw() < corner.stroke_width_before().to_raw()
}

///|
fn fill_corners(
  start : @library.Corner,
  end : @library.Corner,
  corners : @library.Corners[ControlPoints],
) -> Bool {
  if fill_corner(corners.get(start)) {
    return true
  }
  if fill_corner(corners.get(end)) {
    return true
  }
  let mut current = start.next_cw()
  while current != end {
    if fill_corner(corners.get(current)) {
      return true
    }
    current = current.next_cw()
  }
  false
}

///|
/// Returns the shape for the segment and whether the shape should be drawn
/// on top.
fn segment(
  start : @library.Corner,
  end : @library.Corner,
  start_cap : @library.LineCap,
  end_cap : @library.LineCap,
  corners : @library.Corners[ControlPoints],
  stroke : @library.FixedStroke,
) -> (@library.Shape, Bool) {
  let solid = match stroke.dash {
    Some(dash) => dash.array.is_empty()
    None => true
  }
  let use_fill = solid && fill_corners(start, end, corners)
  let shape = if use_fill {
    fill_segment(start, end, start_cap, end_cap, corners, stroke)
  } else {
    stroke_segment(start, end, corners, stroke)
  }
  (shape, use_fill)
}

///|
/// Stroke the sides from `start` to `end` clockwise.
fn stroke_segment(
  start : @library.Corner,
  end : @library.Corner,
  corners : @library.Corners[ControlPoints],
  stroke : @library.FixedStroke,
) -> @library.Shape {
  // Create start corner.
  let curve = @library.Curve::new()
  curve_segment(start, end, corners, curve)
  {
    geometry: Curve(curve),
    stroke: Some(stroke),
    fill: None,
    fill_rule: @library.FillRule::default(),
  }
}

///|
/// Fill the sides from `start` to `end` clockwise.
fn fill_segment(
  start : @library.Corner,
  end : @library.Corner,
  start_cap : @library.LineCap,
  end_cap : @library.LineCap,
  corners : @library.Corners[ControlPoints],
  stroke : @library.FixedStroke,
) -> @library.Shape {
  let curve = @library.Curve::new()

  // create the start corner
  // begin on the inside and finish on the outside
  // no corner if start and end are equal
  // half corner if different
  if start == end {
    let c = corners.get(start)
    curve.move_(c.end_inner())
    curve.line(c.end_outer())
  } else {
    let c = corners.get(start)
    if c.arc_inner() {
      curve_arc_move(curve, c.end_inner(), c.center_inner(), c.mid_inner())
    } else {
      curve.move_(c.end_inner())
    }
    c.start_cap(curve, start_cap)
    if c.arc_outer() {
      curve_arc_line(curve, c.mid_outer(), c.center_outer(), c.end_outer())
    }
  }

  // create the clockwise outside curve for the corners between start and end
  let mut current = start.next_cw()
  while current != end {
    let c = corners.get(current)
    if c.arc_outer() {
      curve_arc_line(curve, c.start_outer(), c.center_outer(), c.end_outer())
    } else {
      curve.line(c.outer())
    }
    current = current.next_cw()
  }

  // create the end corner
  // begin on the outside and finish on the inside
  // full corner if start and end are equal
  // half corner if different
  if start == end {
    let c = corners.get(end)
    if c.arc_outer() {
      curve_arc_line(curve, c.start_outer(), c.center_outer(), c.end_outer())
    } else {
      curve.line(c.outer())
      curve.line(c.end_outer())
    }
    if c.arc_inner() {
      curve_arc_line(curve, c.end_inner(), c.center_inner(), c.start_inner())
    } else {
      curve.line(c.center_inner())
    }
  } else {
    let c = corners.get(end)
    if c.arc_outer() {
      curve_arc_line(curve, c.start_outer(), c.center_outer(), c.mid_outer())
    } else {
      curve.line(c.outer())
    }
    c.end_cap(curve, end_cap)
    if c.arc_inner() {
      curve_arc_line(curve, c.mid_inner(), c.center_inner(), c.start_inner())
    }
  }

  // create the counterclockwise inside curve for the corners between start
  // and end
  let mut current = end.next_ccw()
  while current != start {
    let c = corners.get(current)
    if c.arc_inner() {
      curve_arc_line(curve, c.end_inner(), c.center_inner(), c.start_inner())
    } else {
      curve.line(c.center_inner())
    }
    current = current.next_ccw()
  }
  curve.close()
  {
    geometry: Curve(curve),
    stroke: None,
    fill: Some(stroke.paint),
    fill_rule: @library.FillRule::default(),
  }
}

///|
/// Helper to calculate different control points for the corners.
/// Clockwise orientation from start to end.
/// ```text
/// O-------------------EO  ---   - Z: Zero/Origin ({x: 0, y: 0} for top left corner)
/// |\   ___----'''     |    |    - O: Outer: intersection between the straight outer lines
/// | \ /               |    |    - S_: start
/// |  MO               |    |    - M_: midpoint
/// | /Z\  __-----------E    |    - E_: end
/// |/   \M             |    ro   - r_: radius
/// |    /\             |    |    - middle of the stroke
/// |   /  \            |    |      - arc from S through M to E with center C and radius r
/// |  |    MI--EI-------    |    - outer curve
/// |  |  /  \               |      - arc from SO through MO to EO with center CO and radius ro
/// SO | |    \         CO  ---   - inner curve
/// |  | |     \                    - arc from SI through MI to EI with center CI and radius ri
/// |--S-SI-----CI      C
///      |--ri--|
///    |-------r--------|
/// ```
priv struct ControlPoints {
  radius : @library.Abs
  stroke_after : @library.Abs?
  stroke_before : @library.Abs?
  corner : @library.Corner
  size : @library.Axes[@library.Abs]
  same : Bool
}

///|
/// Move and rotate the point from top-left to the required corner.
fn ControlPoints::rotate(
  self : ControlPoints,
  point : @library.Point,
) -> @library.Point {
  let sx = self.size.x.signum()
  let sy = self.size.y.signum()
  match self.corner {
    TopLeft => { x: point.x.times(sx), y: point.y.times(sy), }
    TopRight => { x: self.size.x - point.y.times(sx), y: point.x.times(sy), }
    BottomRight =>
      {
        x: self.size.x - point.x.times(sx),
        y: self.size.y - point.y.times(sy),
      }
    BottomLeft => { x: point.y.times(sx), y: self.size.y - point.x.times(sy), }
  }
}

///|
/// Whether to use the [ControlPoints::stroke_after] if
/// [ControlPoints::stroke_before] is missing to compute the control points.
/// If the radius is too small, caps other than the [LineCap::Butt] might be
/// misshaped.
fn ControlPoints::reuse_stroke_after_for_cap(
  self : ControlPoints,
) -> @library.Abs? {
  match self.stroke_after {
    Some(s) if s.times(2.0).to_raw() < self.radius.to_raw() => Some(s)
    _ => None
  }
}

///|
/// Either fall back to [ControlPoints::reuse_stroke_after_for_cap] or zero.
fn ControlPoints::stroke_width_before(self : ControlPoints) -> @library.Abs {
  match self.stroke_before {
    Some(s) => s
    None => self.reuse_stroke_after_for_cap().unwrap_or(@library.Abs::zero())
  }
}

///|
/// Whether to use the [ControlPoints::stroke_before] if
/// [ControlPoints::stroke_after] is missing to compute the control points.
/// If the radius is too small, caps other than the [LineCap::Butt] might be
/// misshaped.
fn ControlPoints::reuse_stroke_before_for_cap(
  self : ControlPoints,
) -> @library.Abs? {
  match self.stroke_before {
    Some(s) if s.times(2.0).to_raw() < self.radius.to_raw() => Some(s)
    _ => None
  }
}

///|
/// Either fall back to [ControlPoints::reuse_stroke_before_for_cap] or zero.
fn ControlPoints::stroke_width_after(self : ControlPoints) -> @library.Abs {
  match self.stroke_after {
    Some(s) => s
    None => self.reuse_stroke_before_for_cap().unwrap_or(@library.Abs::zero())
  }
}

///|
/// Outside intersection of the sides.
fn ControlPoints::outer(self : ControlPoints) -> @library.Point {
  self.rotate({ x: -self.stroke_width_before(), y: -self.stroke_width_after(), })
}

///|
/// Center for the outer arc.
fn ControlPoints::center_outer(self : ControlPoints) -> @library.Point {
  let r = self.radius_outer()
  self.rotate({
    x: r - self.stroke_width_before(),
    y: r - self.stroke_width_after(),
  })
}

///|
/// Center for the middle arc.
fn ControlPoints::center(self : ControlPoints) -> @library.Point {
  let r = self.radius()
  self.rotate({ x: r, y: r, })
}

///|
/// Center for the inner arc.
fn ControlPoints::center_inner(self : ControlPoints) -> @library.Point {
  let r = self.radius_inner()
  self.rotate({
    x: self.stroke_width_before() + r,
    y: self.stroke_width_after() + r,
  })
}

///|
/// Radius of the outer arc.
fn ControlPoints::radius_outer(self : ControlPoints) -> @library.Abs {
  self.radius
}

///|
/// Radius of the middle arc.
fn ControlPoints::radius(self : ControlPoints) -> @library.Abs {
  (self.radius - self.stroke_width_before().min(self.stroke_width_after())).max(
    @library.Abs::zero(),
  )
}

///|
/// Radius of the inner arc.
fn ControlPoints::radius_inner(self : ControlPoints) -> @library.Abs {
  (self.radius -
  self.stroke_width_before().max(self.stroke_width_after()).times(2.0)).max(
    @library.Abs::zero(),
  )
}

///|
/// Upstream `Scalar` arithmetic: NaN results become zero.
fn scalar(x : Double) -> Double {
  if x.is_nan() {
    0.0
  } else {
    x
  }
}

///|
/// Upstream `Scalar::max` (`Ord::max`, the second value on ties).
fn scalar_max(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Middle of the corner on the outside of the stroke.
fn ControlPoints::mid_outer(self : ControlPoints) -> @library.Point {
  let c_i = self.center_inner()
  let c_o = self.center_outer()
  let o = self.outer()
  let r = self.radius_outer()

  // https://math.stackexchange.com/a/311956
  // intersection between the line from inner center to outside and the
  // outer arc
  let powi2 = (x : @library.Abs) => {
    @library.Scalar::new(x.to_raw()).powi(2).get()
  }
  let a = scalar(powi2(o.x - c_i.x) + powi2(o.y - c_i.y))
  let b = scalar(
    scalar(scalar(2.0 * (o.x - c_i.x).to_raw()) * (c_i.x - c_o.x).to_raw()) +
    scalar(scalar(2.0 * (o.y - c_i.y).to_raw()) * (c_i.y - c_o.y).to_raw()),
  )
  let c = scalar(scalar(powi2(c_i.x - c_o.x) + powi2(c_i.y - c_o.y)) - powi2(r))
  let disc = scalar_max(
    scalar(scalar(b * b) - scalar(scalar(4.0 * a) * c)),
    0.0,
  )
  let t = scalar(scalar(-b + scalar(disc.sqrt())) / scalar(2.0 * a))
  c_i + (o - c_i).times(t)
}

///|
/// Middle of the corner in the middle of the stroke.
fn ControlPoints::mid(self : ControlPoints) -> @library.Point {
  let center = self.center()
  let outer = self.outer()
  let diff = outer - center
  center + diff.div_by(diff.hypot().to_raw()).times(self.radius().to_raw())
}

///|
/// Middle of the corner on the inside of the stroke.
fn ControlPoints::mid_inner(self : ControlPoints) -> @library.Point {
  let center = self.center_inner()
  let outer = self.outer()
  let diff = outer - center
  center +
  diff.div_by(diff.hypot().to_raw()).times(self.radius_inner().to_raw())
}

///|
/// If an outer arc is required.
fn ControlPoints::arc_outer(self : ControlPoints) -> Bool {
  self.radius_outer().to_raw() > 0.0
}

///|
fn ControlPoints::arc(self : ControlPoints) -> Bool {
  self.radius().to_raw() > 0.0
}

///|
/// If an inner arc is required.
fn ControlPoints::arc_inner(self : ControlPoints) -> Bool {
  self.radius_inner().to_raw() > 0.0
}

///|
/// Start of the corner on the outside of the stroke.
fn ControlPoints::start_outer(self : ControlPoints) -> @library.Point {
  self.rotate({
    x: -self.stroke_width_before(),
    y: self.radius_outer() - self.stroke_width_after(),
  })
}

///|
/// Start of the corner in the center of the stroke.
fn ControlPoints::start(self : ControlPoints) -> @library.Point {
  self.rotate(@library.Point::with_y(self.radius()))
}

///|
/// Start of the corner on the inside of the stroke.
fn ControlPoints::start_inner(self : ControlPoints) -> @library.Point {
  self.rotate({
    x: self.stroke_width_before(),
    y: self.stroke_width_after() + self.radius_inner(),
  })
}

///|
/// End of the corner on the outside of the stroke.
fn ControlPoints::end_outer(self : ControlPoints) -> @library.Point {
  self.rotate({
    x: self.radius_outer() - self.stroke_width_before(),
    y: -self.stroke_width_after(),
  })
}

///|
/// End of the corner in the center of the stroke.
fn ControlPoints::end(self : ControlPoints) -> @library.Point {
  self.rotate(@library.Point::with_x(self.radius()))
}

///|
/// End of the corner on the inside of the stroke.
fn ControlPoints::end_inner(self : ControlPoints) -> @library.Point {
  self.rotate({
    x: self.stroke_width_before() + self.radius_inner(),
    y: self.stroke_width_after(),
  })
}

///|
/// Draw the cap at the beginning of the segment.
///
/// If this corner has a stroke before it, a default "butt" cap is used.
fn ControlPoints::start_cap(
  self : ControlPoints,
  curve : @library.Curve,
  cap_type : @library.LineCap,
) -> Unit {
  // Avoid misshaped caps on small radii.
  let small_radius = self.reuse_stroke_after_for_cap() is None
  if cap_type == Butt ||
    self.stroke_before is Some(_) ||
    (self.radius != @library.Abs::zero() && small_radius) {
    // Just the default cap.
    curve.line(self.mid_outer())
  } else if cap_type == Square {
    let butt_start = self.mid_inner()
    let butt_end = self.mid_outer()
    // Extend by the stroke width.
    let offset_dir = line_normal(butt_start, butt_end)
    let offset = offset_dir.times(self.stroke_width_after().to_raw())
    curve.line(butt_start + offset)
    curve.line(butt_end + offset)
    curve.line(butt_end)
  } else if cap_type == Round {
    let arc_start = self.mid_inner()
    let arc_end = self.mid_outer()
    // We push the center by a little bit to ensure the correct half of the
    // circle gets drawn. If it is perfectly centered the `arc` function just
    // degenerates into a line, which we do not want in this case.
    let offset_dir = -line_normal(arc_start, arc_end)
    let arc_center = (arc_start + arc_end).div_by(2.0) + offset_dir
    curve_arc(curve, arc_start, arc_center, arc_end)
  }
}

///|
/// Draw the cap at the end of the segment.
///
/// If this corner has a stroke before it, a default "butt" cap is used.
fn ControlPoints::end_cap(
  self : ControlPoints,
  curve : @library.Curve,
  cap_type : @library.LineCap,
) -> Unit {
  // Avoid misshaped caps on small radii.
  let small_radius = self.reuse_stroke_before_for_cap() is None
  if cap_type == Butt ||
    self.stroke_after is Some(_) ||
    (self.radius != @library.Abs::zero() && small_radius) {
    // Just the default cap.
    curve.line(self.mid_inner())
  } else if cap_type == Square {
    let butt_start = self.mid_outer()
    let butt_end = self.mid_inner()
    // Extend by the stroke width.
    let offset_dir = line_normal(butt_start, butt_end)
    let offset = offset_dir.times(self.stroke_width_before().to_raw())
    curve.line(butt_start + offset)
    curve.line(butt_end + offset)
    curve.line(butt_end)
  } else if cap_type == Round {
    let arc_start = self.mid_outer()
    let arc_end = self.mid_inner()
    // We push the center by a little bit to ensure the correct half of the
    // circle gets drawn. If it is perfectly centered the `arc` function just
    // degenerates into a line, which we do not want in this case.
    let arc_center_offset = -line_normal(arc_start, arc_end)
    let arc_center = (arc_start + arc_end).div_by(2.0) + arc_center_offset
    curve_arc(curve, arc_start, arc_center, arc_end)
  }
}

///|
/// Computes the normal vector towards the left of the line.
fn line_normal(start : @library.Point, end : @library.Point) -> @library.Point {
  (end - start).rot90ccw().normalized()
}

///|
/// Helper to draw arcs with Bézier curves (upstream `CurveExt::arc`).
fn curve_arc(
  curve : @library.Curve,
  start : @library.Point,
  center : @library.Point,
  end : @library.Point,
) -> Unit {
  let arc = bezier_arc_control(start, center, end)
  curve.cubic(arc.0, arc.1, end)
}

///|
/// Upstream `CurveExt::arc_move`.
fn curve_arc_move(
  curve : @library.Curve,
  start : @library.Point,
  center : @library.Point,
  end : @library.Point,
) -> Unit {
  curve.move_(start)
  curve_arc(curve, start, center, end)
}

///|
/// Upstream `CurveExt::arc_line`.
fn curve_arc_line(
  curve : @library.Curve,
  start : @library.Point,
  center : @library.Point,
  end : @library.Point,
) -> Unit {
  curve.line(start)
  curve_arc(curve, start, center, end)
}

///|
/// Get the control points for a Bézier curve that approximates a circular
/// arc for a start point, an end point and a center of the circle whose arc
/// connects the two.
fn bezier_arc_control(
  start : @library.Point,
  center : @library.Point,
  end : @library.Point,
) -> (@library.Point, @library.Point) {
  // https://stackoverflow.com/a/44829356/1567835
  let a = start - center
  let b = end - center
  let q1 = a.x.to_raw() * a.x.to_raw() + a.y.to_raw() * a.y.to_raw()
  let q2 = q1 + a.x.to_raw() * b.x.to_raw() + a.y.to_raw() * b.y.to_raw()
  let k2 = 4.0 /
    3.0 *
    ((2.0 * q1 * q2).sqrt() - q2) /
    (a.x.to_raw() * b.y.to_raw() - a.y.to_raw() * b.x.to_raw())
  let control_1 = @library.Point::new(
    center.x + a.x - a.y.times(k2),
    center.y + a.y + a.x.times(k2),
  )
  let control_2 = @library.Point::new(
    center.x + b.x + b.y.times(k2),
    center.y + b.y - b.x.times(k2),
  )
  (control_1, control_2)
}
